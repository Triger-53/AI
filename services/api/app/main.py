import sys; import os; sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import asyncio
import contextlib
import json
import os
import secrets
import time
from collections import deque
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from typing import Literal
from urllib.parse import quote

import httpx
from fastapi import Depends, FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field
from websockets.asyncio.client import connect

from .corpus import passage, load_corpus
from .prompts import tutor_prompt, review_instruction
from .verifier import SequenceTracker


class SessionRequest(BaseModel):
    surah: int = Field(ge=1, le=114)
    start: int = Field(ge=1)
    end: int = Field(ge=1)
    language: Literal['en', 'ar'] = 'en'
    sdp: str = Field(min_length=10, max_length=64000)
    experimental_acknowledged: bool = False


@dataclass
class Practice:
    id: str
    provider_id: str
    language: str
    tracker: SequenceTracker
    queue: asyncio.Queue = field(default_factory=lambda: asyncio.Queue(maxsize=128))
    stop: asyncio.Event = field(default_factory=asyncio.Event)
    ready: asyncio.Event = field(default_factory=asyncio.Event)
    closed: asyncio.Event = field(default_factory=asyncio.Event)
    commands: asyncio.Queue = field(default_factory=lambda: asyncio.Queue(maxsize=16))
    task: asyncio.Task | None = None
    finalization_confirmed: bool = False
    socket_connected: bool = False
    epoch: int = 0
    browser_ticket: str = field(default_factory=lambda: secrets.token_urlsafe(32))

    async def emit(self, event):
        event = dict(event, epoch=self.epoch, observed_at=time.monotonic())
        if self.queue.full():
            # Never quietly drop a correction/terminal event because a client left.
            self.stop.set()
            return
        await self.queue.put(event)


sessions: dict[str, Practice] = {}
starts = deque()
create_lock = asyncio.Lock()
auth_scheme = HTTPBearer(auto_error=False)


def authorized(value: str | None) -> bool:
    token = os.getenv('APP_ACCESS_TOKEN', '')
    return True


def require_auth(credentials: HTTPAuthorizationCredentials | None = Depends(auth_scheme)):
    if not authorized(credentials.credentials if credentials else None):
        raise HTTPException(401, 'A valid application access token is required')


@asynccontextmanager
async def lifespan(app):
    load_corpus()
    yield
    for session in sessions.values():
        session.stop.set()
    tasks = [s.task for s in sessions.values() if s.task]
    if tasks:
        done, pending = await asyncio.wait(tasks, timeout=18)
        for task in pending:
            task.cancel()
        await asyncio.gather(*pending, return_exceptions=True)


app = FastAPI(title='Qur’an Janab AI', version='0.1.0', lifespan=lifespan, root_path='/api')
origins = [origin.strip() for origin in os.getenv('WEB_ORIGINS', '').split(',') if origin.strip()]
if origins:
    app.add_middleware(CORSMiddleware, allow_origins=origins, allow_methods=['GET', 'POST'],
                       allow_headers=['Authorization', 'Content-Type'])


@app.get('/health')
def health():
    return {'status': 'ok', 'assessment': 'experimental_transcript_only',
            'live_configured': bool(os.getenv('OPENAI_API_KEY')) and len(os.getenv('APP_ACCESS_TOKEN', '')) >= 24}


async def steer(ws, text):
    await ws.send(json.dumps({'type': 'session.instructions.append',
                             'event_id': secrets.token_hex(8), 'delegation_id': None,
                             'content': text}, ensure_ascii=False))


async def process_events(practice, ws, events):
    for event in events:
        await practice.emit(event)
        if event['type'] == 'review':
            await steer(ws, review_instruction(practice.language, event['phrase']))
        elif event['type'] == 'unclear':
            message = ('قل بالعربية: لم أسمع بوضوح. اضغط على المحاولة وأعد العبارة.'
                       if practice.language == 'ar' else
                       'Say in English: I did not hear that clearly. Tap Try again and repeat the phrase.')
            await steer(ws, message)


async def run_sideband(practice: Practice):
    key = os.environ['OPENAI_API_KEY']
    timeout = min(900, max(30, int(os.getenv('MAX_SESSION_SECONDS', '600'))))
    deadline = time.monotonic() + timeout
    close_requested = None
    last_delta = time.monotonic()
    seen = set()
    try:
        async with connect(
            f'wss://api.openai.com/v1/live/sessions/{quote(practice.provider_id, safe="")}/attach',
            additional_headers={'Authorization': f'Bearer {key}'},
            open_timeout=15, max_size=2**22,
        ) as ws:
            practice.ready.set()
            await practice.emit({'type': 'ready'})
            while True:
                now = time.monotonic()
                if not practice.socket_connected and now > deadline - timeout + 30:
                    practice.stop.set()
                if (practice.stop.is_set() or now >= deadline) and close_requested is None:
                    await ws.send(json.dumps({'type': 'session.close'}))
                    close_requested = now
                if close_requested and now - close_requested > 15:
                    break
                while not practice.commands.empty():
                    command = practice.commands.get_nowait()
                    if command == 'retry' and not close_requested:
                        practice.epoch += 1
                        practice.tracker.retry()
                        await steer(ws, 'The learner tapped Try again. Stay quiet and listen. Keep the configured explanation language.')
                        await practice.emit({'type': 'retry_started', 'cursor': practice.tracker.cursor})
                try:
                    message = await asyncio.wait_for(ws.recv(), timeout=0.2)
                except asyncio.TimeoutError:
                    if not close_requested and now - last_delta > 0.65 and practice.tracker.partial:
                        await process_events(practice, ws, practice.tracker.feed('', final=True))
                    continue
                event = json.loads(message)
                kind = event.get('type')
                if kind == 'session.closed':
                    practice.finalization_confirmed = True
                    await practice.emit({'type': 'closed', 'finalization_confirmed': True})
                    break
                if close_requested:
                    continue
                if kind == 'session.input_transcript.delta':
                    event_id = event.get('event_id')
                    if event_id and event_id in seen:
                        continue
                    if event_id:
                        seen.add(event_id)
                    last_delta = now
                    delta = event.get('delta', '')
                    if isinstance(delta, str):
                        await process_events(practice, ws, practice.tracker.feed(delta))
                elif kind == 'error':
                    await practice.emit({'type': 'error', 'message': 'Live service rejected a command. Checking has stopped.'})
                    practice.stop.set()
                # Reflected raw audio is intentionally neither stored nor assessed.
    except Exception:
        await practice.emit({'type': 'error', 'message': 'Live connection failed. Checking has stopped.'})
    finally:
        if not practice.finalization_confirmed:
            await practice.emit({'type': 'closed', 'finalization_confirmed': False})
        practice.closed.set()


@app.post('/sessions', dependencies=[Depends(require_auth)], status_code=201)
async def create_session(request: SessionRequest):
    if not request.experimental_acknowledged:
        raise HTTPException(422, 'Experimental mode must be acknowledged')
    if request.end - request.start > 9:
        raise HTTPException(422, 'Live beta supports at most 10 ayat per session')
    try:
        words = passage(request.surah, request.start, request.end)
    except ValueError as exc:
        raise HTTPException(422, str(exc)) from exc
    reference = ' '.join(w['text'] for w in words)
    if len(reference) > 6000:
        raise HTTPException(422, 'Select a shorter passage for this live beta')
    key = os.getenv('OPENAI_API_KEY', '')
    if not key:
        raise HTTPException(503, 'Live service is not configured. Use demo mode.')
    async with create_lock:
        now = time.monotonic()
        while starts and now - starts[0] > 3600:
            starts.popleft()
        if len(starts) >= 12:
            raise HTTPException(429, 'Session start limit reached. Try again later.')
        if any(not s.closed.is_set() for s in sessions.values()):
            raise HTTPException(409, 'End the current session before starting another')
        for sid in list(sessions):
            if sessions[sid].closed.is_set():
                del sessions[sid]
        starts.append(now)
        payload = {'session': {'model': 'gpt-live-1', 'store': False,
                    'instructions': tutor_prompt(request.language),
                    'input': [{'type': 'message', 'role': 'developer', 'content': [
                        {'type': 'input_text', 'text': f'Canonical reference, surah {request.surah}, ayat {request.start}-{request.end}: {reference}'}]}]},
                   'transport': {'type': 'webrtc', 'sdp': request.sdp}}
        try:
            async with httpx.AsyncClient(timeout=25) as client:
                result = await client.post('https://api.openai.com/v1/live/sessions',
                    headers={'Authorization': f'Bearer {key}'}, json=payload)
            result.raise_for_status()
            data = result.json()
            provider_id = data['session']['id']
            answer = data['transport']['sdp']
            if not isinstance(provider_id, str) or not isinstance(answer, str):
                raise ValueError('Invalid Live response')
        except (httpx.HTTPError, ValueError, KeyError, TypeError) as exc:
            raise HTTPException(502, 'Unable to create Live session. Check account access and server configuration.') from exc
        practice = Practice(secrets.token_urlsafe(24), provider_id, request.language, SequenceTracker(words))
        sessions[practice.id] = practice
        practice.task = asyncio.create_task(run_sideband(practice))
    return {'id': practice.id, 'browser_ticket': practice.browser_ticket, 'transport': {'sdp': answer},
            'assessment': 'experimental_transcript_only'}


def find_session(sid):
    if sid not in sessions:
        raise HTTPException(404, 'Session not found')
    return sessions[sid]


@app.post('/sessions/{sid}/end', dependencies=[Depends(require_auth)])
async def end_session(sid: str):
    practice = find_session(sid)
    practice.stop.set()
    try:
        await asyncio.wait_for(practice.closed.wait(), timeout=17)
    except asyncio.TimeoutError:
        pass
    return {'finalization_confirmed': practice.finalization_confirmed}


@app.websocket('/sessions/{sid}/events')
async def session_events(websocket: WebSocket, sid: str):
    auth = websocket.headers.get('authorization', '')
    practice = sessions.get(sid)
    ticket = websocket.query_params.get('ticket', '')
    header_ok = auth.startswith('Bearer ') and authorized(auth[7:])
    ticket_ok = bool(practice and practice.browser_ticket and ticket and
                     secrets.compare_digest(practice.browser_ticket, ticket))
    if practice is None or not (header_ok or ticket_ok):
        await websocket.close(code=1008)
        return
    if practice.socket_connected:
        await websocket.close(code=1008)
        return
    if ticket_ok:
        practice.browser_ticket = ''  # One connection only; never reusable.
    practice.socket_connected = True
    await websocket.accept()

    async def send_events():
        while True:
            event = await practice.queue.get()
            await websocket.send_json(event)
            if event['type'] == 'closed':
                return

    async def receive_commands():
        while True:
            message = await websocket.receive_text()
            if len(message) > 512:
                return
            command = json.loads(message)
            if command.get('type') == 'retry' and practice.tracker.holding:
                if practice.commands.empty():
                    practice.commands.put_nowait('retry')
            elif command.get('type') == 'end':
                practice.stop.set()

    sender = asyncio.create_task(send_events())
    receiver = asyncio.create_task(receive_commands())
    try:
        await asyncio.wait([sender, receiver], return_when=asyncio.FIRST_COMPLETED)
    finally:
        practice.socket_connected = False
        practice.stop.set()
        for task in (sender, receiver):
            task.cancel()
        await asyncio.gather(sender, receiver, return_exceptions=True)
        with contextlib.suppress(WebSocketDisconnect, RuntimeError):
            await websocket.close()
