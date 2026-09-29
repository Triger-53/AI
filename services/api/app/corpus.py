"""Immutable display text. Normalization is only for approximate sequence tracking."""
import hashlib
import json
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / 'assets'


def normalize(text: str) -> str:
    text = unicodedata.normalize('NFKC', text)
    text = ''.join(c for c in text if unicodedata.category(c) != 'Mn' and c != 'ـ')
    text = text.translate(str.maketrans('أإآٱى', 'ااااي'))
    return ''.join(c if c.isalpha() else ' ' for c in text).strip()


def load_corpus() -> list[dict]:
    raw = (ASSETS / 'quran.json').read_bytes()
    manifest = json.loads((ASSETS / 'corpus-manifest.json').read_text())
    if hashlib.sha256(raw).hexdigest() != manifest['sha256']:
        raise RuntimeError('Corpus checksum mismatch; refusing to serve altered text')
    chapters = json.loads(raw)
    assert len(chapters) == 114
    assert sum(len(c['verses']) for c in chapters) == 6236
    for index, chapter in enumerate(chapters, 1):
        assert chapter['id'] == index
        assert chapter['total_verses'] == len(chapter['verses'])
        assert [v['id'] for v in chapter['verses']] == list(range(1, len(chapter['verses']) + 1))
    return chapters


CORPUS = None


def passage(surah: int, start: int, end: int) -> list[dict]:
    global CORPUS
    if CORPUS is None:
        CORPUS = load_corpus()
    if not 1 <= surah <= 114:
        raise ValueError('Invalid surah')
    chapter = CORPUS[surah - 1]
    if not 1 <= start <= end <= len(chapter['verses']):
        raise ValueError('Invalid ayah range')
    words = []
    for verse in chapter['verses'][start - 1:end]:
        for position, text in enumerate(verse['text'].split(), 1):
            words.append({'id': f'{surah}:{verse["id"]}:{position}',
                          'ayah': verse['id'], 'text': text, 'match': normalize(text),
                          'variants': list({normalize(text), normalize(text.replace('\u0670', 'ا'))})})
    return words
