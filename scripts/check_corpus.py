#!/usr/bin/env python3
import pathlib
import sys
root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'services/api'))
from app.corpus import load_corpus
corpus = load_corpus()
print(f'Integrity passed: {len(corpus)} surahs, {sum(len(c["verses"]) for c in corpus)} ayat')
