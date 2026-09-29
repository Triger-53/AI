import asyncio
import pytest
from starlette.websockets import WebSocketDisconnect
from fastapi.testclient import TestClient
from app import main
from app.prompts import tutor_prompt, review_instruction

TOKEN = 'development-test-token-that-is-long-enough'


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv('APP_ACCESS_TOKEN', TOKEN)
    monkeypatch.delenv('OPENAI_API_KEY', raising=False)
    main.sessions.clear()
    main.starts.clear()
    with TestClient(main.app) as client:
        yield client


def request(**kwargs):
    return dict(surah=1, start=1, end=7, language='en', sdp='v=0\r\n' + 'test' * 10,
                experimental_acknowledged=True, **kwargs)


def test_missing_auth_fails_closed(client):
    assert client.post('/sessions', json=request()).status_code == 401


def test_missing_key_does_not_fake_live_success(client):
    r = client.post('/sessions', json=request(), headers={'Authorization': f'Bearer {TOKEN}'})
    assert r.status_code == 503


def test_range_and_language_validation(client):
    data = request()
    data['end'] = 8
    assert client.post('/sessions', json=data, headers={'Authorization': f'Bearer {TOKEN}'}).status_code == 422
    data = request()
    data['language'] = 'hi'
    assert client.post('/sessions', json=data, headers={'Authorization': f'Bearer {TOKEN}'}).status_code == 422


def test_acknowledgment_required(client):
    data = request()
    data['experimental_acknowledged'] = False
    assert client.post('/sessions', json=data, headers={'Authorization': f'Bearer {TOKEN}'}).status_code == 422


def test_language_policy_is_explicit():
    assert 'English' in tutor_prompt('en')
    assert 'Arabic recitation NEVER changes' in tutor_prompt('en')
    assert 'Modern Standard Arabic' in tutor_prompt('ar')
    assert 'Say in English' in review_instruction('en', 'قل هو الله')


def test_live_payload_and_stop(client, monkeypatch):
    captured = {}
    monkeypatch.setenv('OPENAI_API_KEY', 'test-key-not-real')

    class Response:
        def raise_for_status(self): pass
        def json(self): return {'session': {'id': 'live_test'}, 'transport': {'sdp': 'answer'}}

    class Provider:
        def __init__(self, **kwargs): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *args): pass
        async def post(self, url, **kwargs):
            captured.update(kwargs)
            return Response()

    async def fake_sideband(practice):
        practice.ready.set()
        await practice.stop.wait()
        practice.finalization_confirmed = True
        practice.closed.set()

    monkeypatch.setattr(main.httpx, 'AsyncClient', Provider)
    monkeypatch.setattr(main, 'run_sideband', fake_sideband)
    headers = {'Authorization': f'Bearer {TOKEN}'}
    response = client.post('/sessions', json=request(), headers=headers)
    assert response.status_code == 201
    assert 'test-key-not-real' not in response.text
    payload = captured['json']
    assert payload['session']['model'] == 'gpt-live-1'
    assert payload['session']['store'] is False
    assert 'بِسۡمِ' in payload['session']['input'][0]['content'][0]['text']
    assert client.post('/sessions', json=request(), headers=headers).status_code == 409
    sid = response.json()['id']
    ticket = response.json()['browser_ticket']
    assert len(ticket) >= 24
    assert ticket != TOKEN
    assert 'test-key-not-real' not in ticket
    assert client.post(f'/sessions/{sid}/end', headers=headers).json()['finalization_confirmed']


def test_browser_event_ticket_is_single_use(client):
    from app.verifier import SequenceTracker
    from app.corpus import passage
    practice = main.Practice('browser-test', 'provider-test', 'en', SequenceTracker(passage(1, 1, 1)))
    main.sessions[practice.id] = practice
    with client.websocket_connect(f'/sessions/browser-test/events?ticket={practice.browser_ticket}') as ws:
        assert practice.browser_ticket == ''
        ws.send_text('{"type":"end"}')
    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect('/sessions/browser-test/events?ticket=invalid'):
            pass


def test_websocket_rejects_missing_auth(client):
    from starlette.websockets import WebSocketDisconnect
    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect('/sessions/nonexistent/events'):
            pass
