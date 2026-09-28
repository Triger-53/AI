# Build status — 28 September 2026

## Implemented

Flutter UI source; full offline text; English/Arabic preferences; Hifz mode;
demo interactions; local practice history; native WebRTC integration code;
FastAPI Live session broker; server-side transcript tracker; review and retry;
time/start limits; authentication; close/finalization handling; tests; setup scripts.

## Verified in this workspace

- 18 Python tests pass, including a mocked provider session integration.
- Corpus integrity: 114 surahs, 6,236 ayat, fixed SHA-256 and sequential IDs.
- Python syntax and Dart syntax parse successfully.
- Exact Flutter plugin versions were found in the official pub.dev package API.
- Bundled Amiri font has cmap coverage for every non-whitespace character in
  the corpus and chapter names. This does not verify on-device shaping/layout.
- No credentials, private recordings, or transcripts are bundled.

## Not verified

- Flutter analyzer, Flutter widget tests, Android compilation, or iOS compilation.
  Flutter/Android SDKs are unavailable here; official SDK endpoints timed out.
- Real GPT-Live account access, protocol round trip, or audio on a physical device.
- Output gating, microphone cancellation, echo suppression, Bluetooth routing,
  background interruptions, and actual end-to-end latency on phones.
- Scholarly assessment accuracy. All live checks are experimental transcript
  checks; no tajwid or detailed acoustic grading is implemented.
- Hosted backend operation or app-store release.

The native scaffold generator and GitHub Actions workflow are provided but not
executed here. A successful Dart syntax parse is not a successful Flutter build.

## Known prototype constraints

- One personal user / one worker. Shared-token auth is not a multi-user identity system.
- Live selections are limited to 10 ayat and 6,000 text characters.
- Only adjacent repetition and simple self-correction are handled; repeated
  verse ambiguity, arbitrary restarts, spoken introductions, and Qira’at require
  a more capable sequence tracker.
- Only transcript comparison is available; no phoneme timing or acoustic model.
- Generated explanations are requested in the chosen language; model adherence
  has not been evaluated. Reference recitation recordings are not bundled.
- A pause closes Live; resuming restarts the selected range.
- App state is not a durable server database. A server crash can leave provider
  session finalization unconfirmed. Check provider usage and spend limits.
- Hypotheses received late around retry boundaries need device-level evaluation.
- Amiri is bundled with its OFL license. On-device shaping, diacritic spacing,
  line wrapping, and visual accessibility still require native review.

## GitHub

The authenticated GitHub account exposed zero repositories. The `Quran` repository
was not accessible through the connector. Source was committed locally and
packaged; no GitHub repository was created or updated.
