"""Quick integrity checks for the deployable static site."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
chapters = json.loads((root / 'assets/quran.json').read_text())
assert len(chapters) == 114
assert sum(len(c['verses']) for c in chapters) == 6236
for name in ('index.html', 'style.css', 'app.js', 'assets/Amiri-Regular.ttf'):
    assert (root / name).stat().st_size > 0, name
print('Website assets and Qur’an corpus verified')
