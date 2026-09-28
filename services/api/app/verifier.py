"""Experimental transcript alignment, NEVER an acoustic/tajwid verdict.

A deviation needs two following matching words. Pending partial words and
ambiguous/unanchored speech never become a mistake. All alerts ask for review.
"""
from .corpus import normalize


class SequenceTracker:
    def __init__(self, words: list[dict]):
        self.words = words
        self.cursor = 0
        self.buffer: list[str] = []
        self.partial = ''
        self.holding = False
        self.retry_target: int | None = None

    def reset(self, cursor: int = 0):
        self.cursor = max(0, min(cursor, len(self.words)))
        self.buffer.clear()
        self.partial = ''
        self.holding = False

    def retry(self):
        self.retry_target = min(len(self.words), self.cursor + 3)
        self.reset(max(0, self.cursor - 1))

    def feed(self, fragment: str, final: bool = False) -> list[dict]:
        if self.holding:
            return []
        raw = self.partial + fragment
        pieces = raw.split()
        if raw and not raw[-1].isspace() and not final:
            self.partial = pieces.pop() if pieces else raw
        else:
            self.partial = ''
        self.buffer.extend(w for p in pieces for w in normalize(p).split())
        return self._consume()

    def _consume(self) -> list[dict]:
        events = []
        def matches(token, index):
            word = self.words[index]
            return token in word.get('variants', [word['match']])
        while self.buffer and self.cursor < len(self.words):
            if matches(self.buffer[0], self.cursor):
                self.buffer.pop(0)
                self.cursor += 1
                events.append({'type': 'position', 'cursor': self.cursor})
                if self.retry_target is not None and self.cursor >= self.retry_target:
                    self.retry_target = None
                    events.append({'type': 'retry_aligned'})
                continue
            # Natural repetition of the immediately preceding word is tolerated.
            if self.cursor and matches(self.buffer[0], self.cursor - 1):
                self.buffer.pop(0)
                continue
            # Self-correction before an anchor is not penalized.
            if len(self.buffer) >= 2 and matches(self.buffer[1], self.cursor):
                self.buffer.pop(0)
                continue
            remaining = [w['match'] for w in self.words[self.cursor:]]
            anchored = False
            # A possible replacement followed by two exact expected words.
            if len(remaining) >= 3 and len(self.buffer) >= 3:
                anchored = all(matches(self.buffer[i], self.cursor + i) for i in (1, 2))
            # Or a small omission followed by two exact expected words.
            if len(self.buffer) >= 2:
                anchored |= any(all(matches(self.buffer[i], self.cursor + k + i) for i in (0, 1))
                                for k in range(1, min(4, len(remaining) - 1)))
            if anchored:
                self.holding = True
                events.append({'type': 'review', 'cursor': self.cursor,
                               'word': self.words[self.cursor],
                               'phrase': ' '.join(w['text'] for w in self.words[self.cursor:self.cursor + 4]),
                               'assessment': 'possible_sequence_difference',
                               'confirmed_mistake': False})
                break
            # Never grow indefinitely on conversation/noise. Ask for resync.
            if len(self.buffer) > 12:
                self.buffer.clear()
                self.partial = ''
                self.holding = True
                events.append({'type': 'unclear', 'cursor': self.cursor})
            break
        if self.cursor == len(self.words) and events:
            self.holding = True
            events.append({'type': 'passage_aligned', 'acoustic_assessment': False})
        return events
