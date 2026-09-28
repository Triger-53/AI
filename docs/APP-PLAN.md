# Qur’an Janab AI — Complete App Plan

Version 1.0 • 28 September 2026 • Planning specification, not a built or benchmarked app

## 1. Product decision

Build an installable mobile Qur’an recitation tutor. Start with Android, prepare the shared code for iOS, and use GPT-Live 1 as the conversational voice model. The learner chooses a surah and range, recites, receives an early interruption for a sufficiently verified mistake, hears a concise correction in English or Arabic, retries, and continues from the correct position.

The visual direction is a bright, quiet, white Qur’an reader with large Arabic text, restrained emerald accents, and warm neutral surfaces. The reader is the main experience. The assistant supports it with short spoken guidance and compact correction panels.

This is a practice assistant inspired by the attentive teaching interaction with a Janab. It must not claim the qualifications, religious authority, or comprehensive perceptual judgment of a human teacher.

### Assumptions chosen for this plan

- Android first, with a Flutter mobile application and a server backend. iOS follows after the audio pipeline has been proven on phones.
- Product name: Qur’an Janab AI. Repository name can remain whatever the owner chooses.
- Initial assessed recitation: one explicitly selected, teacher-reviewed Hafs profile. The exact transmission path and permitted rule alternatives are recorded before pronunciation assessment launches. Other readings remain outside assessment until supported.
- Explanations: English or Modern Standard Arabic only. Qur’an examples remain Arabic in either setting.
- Online live tutoring; offline reading and previously downloaded permitted reference recordings.
- Highest priority: trustworthy interruption and recovery. Exact tajwīd assessment is a separate validation milestone.
- No model training from scratch in the first release. A specialist acoustic checker may be added when evidence shows it is necessary.

## 2. Verified model choice and limits

The official GPT-Live 1 model page documents `gpt-live-1` as a full-duplex audio model: it can listen while speaking and delegate work to a backend. The Live documentation supports custom application workflows and supplied text context. [S1–S4]

Use the OpenAI API for the mobile app. Do not assume a ChatGPT voice session or subscription grants the app API access. Confirm the developer account can create the intended Live session before implementing around it. Published documentation is not proof of this account’s access.

Use **one conversational model**, GPT-Live 1, with an application-owned verifier and controller. Begin with deterministic reference matching and the Live transcript. A second general conversational model is unnecessary for routine correction. A dedicated acoustic model becomes a separate optional dependency for validated phoneme and tajwīd checking; it must be selected through evaluation, not claimed as already available or accurate.

Full duplex establishes simultaneous listening and speaking. It does not establish Qur’an error accuracy, exact phoneme timing, or a guaranteed interruption latency. The retrieved documentation provides no Qur’an-specific benchmark sufficient to make those promises.

If Live access is unavailable, build the reader and replay-based test harness and keep the voice adapter replaceable. A Realtime prototype would need a separate capability assessment and must not be presented as having identical full-duplex behavior.

## 3. User journeys

### First use

1. Choose explanation language: English or العربية. Save this choice.
2. Choose “I read from the Qur’an” or “I recite from memory.”
3. Confirm supported recitation profile. Explain unsupported profiles before assessment begins.
4. Grant microphone permission when starting a listening activity.
5. Run a brief microphone check for clipping, excessive noise, and the active audio route.
6. Explain: “When I hear a clear mistake, I’ll ask you to pause, help you correct it, and listen again.”
7. Start a short practice session. Account creation can wait until the learner wants cross-device history.

### Daily practice

Home → Continue last practice / Choose passage → Surah and ayah range → Mode and correction setting → Start → Recite → Correct and retry as needed → Session review.

Passage selection supports surah search by Arabic or English name, surah number, and ayah range. Add Juz and page selection once the selected Mushaf’s mappings are verified. Range selection always resolves to canonical verse IDs; page numbers are edition-specific.

### Correction cycle

1. Identify a plausible deviation while the student is speaking.
2. Check position, audio quality, error evidence, and whether the learner already self-corrected.
3. On confirmation, issue an immediate local cue and briefly say “Pause, please” or “توقّف قليلًا، من فضلك”.
4. Hold the reader at the affected passage. Underline the word or show a marker for an omission.
5. Explain one issue, usually in one sentence. Present exact expected text from the corpus.
6. Offer a reviewed reference recording of the word in phrase context or the full ayah.
7. Ask the learner to repeat a short phrase beginning before the error.
8. Reassess the retry; resume only after the checkpoint is resolved or the learner explicitly chooses to continue.

The app can ask someone to stop; it cannot physically stop their speech. If they continue, keep listening, preserve the checkpoint, avoid repeated overlapping commands, and explain once they pause.

## 4. Practice modes

| Mode | Reader | Tutor behavior |
|---|---|---|
| Read and improve | Full selected text | Follow position and correct supported errors |
| Hifz practice | Text hidden; reveal controls available | Prompt only after a confirmed mistake or requested hint |
| Repeat after reference | Short reviewed audio and matching text | Listen to the student’s retry after playback |
| Review difficult passages | Saved practice queue | Revisit previous confirmed issues |
| Quiet review | Visible or hidden text | Defer feedback until pause or end of passage |

Correction timing options: Immediate, At a pause, and End of passage. Immediate is the default requested experience. Timing selection does not lower the evidence threshold. A strict mode may cover more validated categories but must not punish uncertainty.

## 5. Language policy

Store `explanation_language: en | ar` and the source of that preference. A stated language preference overrides any inferred language signal.

- If the learner selected English or says they understand English only, all teaching explanations, prompts, summaries, and interface help remain English.
- The Arabic recitation stream must never be used as evidence that the person understands Arabic explanations.
- An English explanation may include the exact Arabic word being taught and reference recitation; this is not a language switch.
- If no explicit choice exists, use the app’s selected interface language, falling back to English. Offer a language choice instead of guessing proficiency.
- Change languages only after a clear user instruction or UI action; persist the change and invalidate queued speech in the previous language.
- Use one sentence of guidance at a time. No unsolicited translations into other languages.

Example English response: “Pause, please. Repeat the highlighted phrase after the example.”

Example Arabic response: “توقّف قليلًا، من فضلك. أَعِد العبارة المحدّدة بعد المثال.”

For an acoustically uncertain segment: “I didn’t hear that clearly. Please repeat the highlighted phrase.” Do not label it wrong or reduce a score.

## 6. Authoritative Qur’an context

Supply the chosen passage to the system on every session. Model memory is never the source of the expected Qur’an text.

Maintain an immutable, versioned canonical corpus: source, license notice, content checksum, reading profile, surah ID, ayah ID, ordered word IDs, exact display text, and edition-specific metadata. Tanzil is a candidate text source with published redistribution and attribution conditions. Quran Foundation documents verse, word, script, and audio fields. Availability of an audio URL does not establish redistribution or training rights. [S6–S7]

Do not modify the displayed canonical text to simplify matching. Keep any permitted search or matching representation separately, with reversible mappings to original word IDs. Review source terms before distributing derived representations. Distinguish vowel marks needed for assessment from ornaments and stop marks; stripping all diacritics would erase real pronunciation distinctions.

### Context supplied to the tutor

- Session ID and context revision.
- Explanation language and learner’s stated language restriction.
- Practice mode and correction timing.
- Supported reading profile and reviewed ruleset version.
- Selected surah and ayah range.
- Exact canonical text for the active passage.
- Last confirmed position, current uncertainty span, and resume checkpoint.
- Nearby preceding and following ayat when needed for sequence tracking.
- Approved correction facts and available reference audio IDs.

Short surahs can be supplied in full. Long selections use a rolling window, initially around the active ayah and neighboring ayat. The exact number of ayat is token-budgeted, not fixed; some ayat are long. Preload the next context before the learner reaches it. Do not paste the whole Qur’an into every session.

Keep passage state on the server and client. Re-supply necessary context after reconnects or context transitions. Treat acknowledgments as delivery signals, not proof the model understood or spoke the correct content. Live’s context events have documented size limits and timeline behavior; implement against those limits. [S3]

Handle isti‘adhah, opening basmalah conventions, ayah numbering, deliberate repetitions, mid-ayah starts, breath pauses, and requested skips explicitly. These are state transitions, not automatic errors.

## 7. Recitation verification architecture

### Layer A — Canonical sequence tracker

Track the most plausible location using recent speech evidence and the chosen range. Maintain alternative positions when wording repeats. Support substitutions, omissions, insertions, repetitions, restarts, and neighboring-ayah jumps. Never mark an unfinished expected word as omitted merely because it has not arrived yet.

Live transcript fragments can support the initial alignment prototype. They are not phoneme measurements. Their timestamps are approximate fragment intervals, and delivery may be uneven. [S3]

### Layer B — Acoustic evidence

For detailed pronunciation and tajwīd, use the actual incoming audio. A recognizer can transcribe the expected word even when it was pronounced incorrectly. Supplying the reference makes location tracking easier but can also bias recognition toward the correct text; evaluate this failure explicitly.

Evaluate a specialist streaming phoneme or acoustic model only after collecting permissioned, teacher-annotated examples. Candidate model selection, licenses, supported Arabic varieties, runtime cost, and mobile/server performance remain implementation research items. Do not advertise this layer as complete in an early Live-only prototype.

Madd duration is evaluated relative to the learner’s pace and the selected rule profile. It cannot be assessed with one fixed millisecond value for every reciter. Shortening often becomes detectable only when the sound ends; excess length requires enough elapsed evidence. Articulation and nasalization require relevant acoustic evidence, not transcript spelling.

### Layer C — Application decision gate

Confirm only when audio is assessable, location is sufficiently stable, the category is validated, the evidence is current, and no self-correction has superseded the event. Confidence thresholds must be calibrated on held-out audio. A model’s verbal “95% sure” is not a calibrated probability.

### Layer D — Spoken teaching

GPT-Live receives the approved error type, exact expected span, explanation language, and next action. It gives a concise explanation. Use reviewed templates for common corrections and licensed, reviewed recordings for Qur’an demonstrations. Do not rely on generated voice as the canonical recitation exemplar until independently approved.

### Release scope by error type

| Category | Initial approach | Release condition |
|---|---|---|
| Wrong word / wrong ayah sequence | Streaming sequence alignment | Teacher-labeled accuracy and false-interruption gates passed |
| Omitted word | Alignment plus enough following evidence | Distinguish omission from pause and restart |
| Repeated word | Position tracker | Permit intentional repetition and recovery |
| Unclear audio | Quality detection | Ask to repeat; no penalty |
| Vowel, letter, shaddah | Acoustic assessment | Per-category validation; not transcript-only |
| Madd, ghunnah, articulation | Dedicated acoustics plus rules | Research milestone and teacher review |
| Waqf / continuation | Reviewed contextual rules | Supported reading and interpretation boundaries defined |

## 8. Interruption timing

All numbers below are proposed engineering targets, not measured product results or provider guarantees.

Define five separate timestamps: earliest acoustically diagnosable point, checker decision, client receipt, cue playback start, and explanation playback start. Also record word onset, but do not pretend every error is detectable at onset.

| Measurement | Initial target on supported devices and good network |
|---|---|
| Client receives confirmation → visual/haptic cue | p95 under 50 ms |
| Client receives confirmation → cached pause cue starts | p95 under 100 ms |
| Diagnosable point → first user-perceived cue | Investigate 250–700 ms median; p95 below 1,200 ms |
| Confirmed decision → useful generated explanation begins | Investigate 0.5–1.5 seconds median; report p95 separately |

These are deliberately separate. Fast local playback does not imply 50 ms end-to-end mistake detection. Measure Android speaker, wired audio, and Bluetooth separately; buffering and route changes can dominate latency. If a category cannot meet the target without excessive false interruptions, defer it to a pause.

Design the hot path without waiting for a complete ayah, end-of-turn silence, a database write, or a general reasoning call for each audio frame. Preload reference text and cue audio. Run checking continuously. Persist results asynchronously. Use a monotonic clock and measured clock mappings; never subtract unsynchronized device and server wall clocks.

Measure p50, p95, and p99 alongside false interruptions. Publish measured conditions and performance only after trials.

## 9. Audio and session control

Proposed transport: native microphone capture and WebRTC audio to GPT-Live, with server session setup and authorized server controls. OpenAI’s Live WebRTC guide documents server-created sessions using SDP negotiation; reuse its current protocol, not legacy Realtime event names. [S5]

For acoustic verification, branch timestamped capture audio to a verifier using a shared native capture pipeline. Do not open two competing microphone capture sessions. Prove the selected Flutter/native media integration can expose clean frames without breaking echo cancellation; if it cannot, change the media implementation before adding features.

- Keep microphone capture active during tutor speech for full duplex, except when the learner pauses or privacy controls disable it.
- Use echo cancellation and output reference tagging so the tutor’s voice is not assessed as the learner.
- Exercise care with noise processing: it can alter subtle sounds needed for pronunciation assessment.
- One playback coordinator arbitrates pause cues, GPT-Live output, and reference recordings.
- A local cached pause cue is the fastest predictable speech path after a confirmed event reaches the phone. Duck or suppress Live output while it plays; avoid two voices at once.
- While the learner is actively reciting, prefer an application-controlled output gate so spontaneous model chatter cannot bypass the correction policy. Normal conversation and questions use a separate dialogue state.
- Do not assume generated captions arrive early enough to filter all speech before playback. Verify the timing; rely on reviewed local cues for the critical interruption.
- Student questions can interrupt explanations. Cancel obsolete playback and preserve the practice checkpoint.
- No filler acknowledgments such as “mm-hmm” during recitation. Keep encouragement for natural breaks.

### Application states

Ready → Connecting → Listening → Verifying → Correcting → Awaiting retry → Listening.

Additional states: Paused, Unclear audio, Reconnecting, Ended. “Verifying” is internal unless it takes long enough to need a visible status. Do not flash the UI for every hypothesis.

Give every correction a unique event ID and a session epoch. Surah changes, restarts, and reconnects increment the epoch; reject late results from older epochs. Enforce one active correction, idempotent processing, and cancellation on self-correction. A gap in audio is an unassessed interval, not evidence the passage was correct.

## 10. Interface and experience specification

### Visual system

- Primary background: white `#FFFFFF`.
- Reading surface: warm white `#FCFBF7`.
- Main text: deep charcoal `#192B25`.
- Primary action: deep emerald `#165D48`.
- Gentle highlight: pale sage `#EDF5EF`.
- Correction surface: pale warm amber `#FFF3DF`, paired with dark text and an explicit label.
- Warm metallic accent `#A08043` only for decoration, never small essential text without contrast validation.
- Use a licensed Qur’an font tested against every supported glyph and diacritic; select the exact font after full-corpus rendering checks.
- Arabic reading text approximately 30–36 logical pixels on a typical phone, adjustable; UI text about 16. Generous line height so marks never collide.
- Spacing based on an 8-point system; 20–24 point reader margins where screen width permits; controls at least 48 logical pixels tall.
- No decorative animation over sacred text. Reduced-motion preference respected. Optional haptics and silent cues.

### Screens

| Screen | Primary content | Main action |
|---|---|---|
| Welcome | Language and simple tutoring promise | Begin |
| Home | Continue card, choose passage, recent practice | Continue reciting |
| Passage picker | Search, surah list, ayah range | Practice this passage |
| Session setup | Mode, feedback language, correction timing, audio check | Start listening |
| Live reader | Selected passage, stable word focus, connection and listening state | Pause |
| Correction panel | Exact affected span, one explanation, reference and retry | Try again |
| Session review | Confirmed issues, resolved retries, unclear segments separately | Practice again |
| Progress | Recitation history and passages needing review | Review passage |
| Settings | Language, reading profile, text size, voice, audio retention, account | Save preference |

### Live screen composition

Top: back/pause navigation, surah title, selected ayah range, compact language control. Center: Qur’an text with ayah markers, clear whitespace, and a subtle current-span highlight. Bottom: listening state, a small audio activity indicator, pause, hint, and end-session actions.

Highlighting indicates estimated position, not proof of correctness. Words become “reviewed” only when supported checking has finished. Retain normal text contrast even for previously read words. Do not auto-scroll while the learner manually explores the page; show “Return to current ayah.”

During correction, reserve space for a compact bottom panel rather than shifting the text. In Hifz mode, reveal only the necessary phrase unless the learner requests more. Keep canonical Qur’an text visually distinct from translations and teaching explanations.

Arabic interface direction is RTL. English interface direction is LTR; the Qur’an region remains RTL. Isolate verse references and mixed-language fragments so punctuation and numbers remain readable. Screen-reader labels include surah, ayah, word, and action context. Do not rely on color alone or announce every word update.

### Session review

Show practice time, selected range, assessed portions, confirmed mistakes, successful retries, and an actionable review queue. Do not invent an overall “tajwīd 98%” score for unvalidated categories. Separate “unclear audio,” “not assessed,” and “confirmed issue.” Let the learner dispute a correction and optionally submit the relevant clip for human review.

## 11. Proposed implementation stack

These are engineering recommendations, not commitments to untested versions.

| Component | Proposal | Why |
|---|---|---|
| Mobile UI | Flutter / Dart | Shared Android and iOS interface with native integration [S8] |
| Native audio | Platform audio modules plus compatible WebRTC integration | Control capture, playback, focus, routes, echo cancellation |
| Application API | Python / FastAPI | Session orchestration and integration with future acoustic work |
| Live voice | OpenAI GPT-Live 1 | Full-duplex conversational teaching |
| Reference store | Versioned canonical corpus plus SQLite cache | Reliable offline reader and exact IDs |
| User data | PostgreSQL | Preferences, checkpoints, confirmed events, progress |
| Optional audio storage | Encrypted object storage | Consent-based replay and review |
| Live coordination | In-process initially; Redis when scale requires it | Session state and expiring coordination |
| Telemetry | Structured event tracing | Measure audio, decision, and playback latency |
| Build automation | Repository CI | Repeatable checks and Android build artifacts |

Choose exact dependency versions at implementation, pin them, and keep native audio proof-of-concept ahead of full UI construction. No GPU requirement for the phone is assumed. A specialist server model’s hardware requirements are unknown until selection and testing.

## 12. Repository layout and contracts

Proposed directories:

- `apps/mobile/`: screens, design system, local persistence, localization, Android/iOS projects.
- `packages/audio_bridge/`: platform capture and playback integration.
- `services/api/`: account/session endpoints, Live adapter, quota control.
- `services/verifier/`: sequence tracking, evidence gate, optional acoustic adapters.
- `data/quran/`: source manifest, checksums, licenses, canonical importer.
- `data/rules/`: versioned teacher-reviewed assessment rules.
- `contracts/`: application JSON schemas and event definitions.
- `evals/`: permissioned fixtures, replay runner, teacher labels, metrics.
- `docs/`: setup, architecture, user flows, privacy, release criteria.
- `infra/`: backend deployment and development configuration.
- `.github/workflows/`: tests and Android builds once a GitHub repository is connected.

Keep API secrets, signing keys, private audio, and personal data out of Git. Include `.env.example`, dependency locks, migrations, a README, and a clear attribution manifest.

### Core records

`LearnerPreferences`: explanation language, UI language, reading profile, feedback mode, recording consent.

`PracticeSession`: selected range, corpus version, model configuration, mode, epoch, checkpoint, started/ended timestamps, assessed intervals, usage.

`CorrectionEvent`: event ID, session/epoch, word IDs, error category, expected span reference, observed evidence reference, confidence calibration version, timestamps, disposition, retry outcome.

`AudioAsset`: source, rights status, reading profile, exact span, reviewed boundaries, checksum. Do not store a guessed word clip merely by trimming silence automatically.

### Proposed application API, not OpenAI endpoint names

- `POST /practice-sessions`: validate range and preferences, create session and media negotiation.
- `POST /practice-sessions/{id}/pause`: stop local capture through client action and update state; close idle paid sessions as appropriate.
- `POST /practice-sessions/{id}/resume`: restore checkpoint and create fresh media if needed.
- `POST /practice-sessions/{id}/end`: terminate voice billing and persist summary.
- `GET /quran/manifest`, `GET /quran/passages`: versioned reference access.
- `GET /practice-history`, `GET /review-queue`.
- `POST /corrections/{id}/feedback`: disputed correction or reviewed outcome.
- Authenticated session event stream for position, error confirmation, retry result, network state, and usage.

The server constructs trusted context from validated IDs. User text and model output cannot silently replace corpus data, rules, or authoritative checkpoints.

## 13. Voice behavior contract

Keep the actual Live prompt short. Put detailed validation rules in application code and backend instructions. OpenAI’s prompting guidance separates conversational behavior from detailed backend workflows. [S4]

Proposed prompt outline:

> You are Qur’an Janab AI, a calm Qur’an practice assistant. Teach in the application’s selected explanation language: English or Arabic. Arabic recitation does not change that language. Use only supplied canonical text for the expected passage. Keep corrections short and specific. Do not claim an uncertain segment is wrong.
>
> Backchannel policy: Remain quiet while the learner recites. No filler sounds, praise, or finishing their ayah unasked.
>
> Interruption policy: In recitation mode, interrupt only for a current correction approved by the application. Give one concise correction and ask for the defined retry phrase. If the learner asks a question or asks you to stop, respond to that request and preserve the practice position.
>
> Delegation policy: Request canonical context, reference playback, or validation when needed. Do not invent Qur’an text, pronunciation evidence, scores, or a new assessment rule. Do not advance the authoritative checkpoint yourself.

Prompting alone is not enforcement. Validate event references, language, state transitions, and allowed output behavior in application code. A Live-generated suspicion can be sent for verification; it is not automatically a confirmed mistake.

## 14. Privacy, operational behavior, and cost

- Keep the OpenAI API key on the server; authenticate and rate-limit session creation.
- Show microphone and connection state clearly. Pause stops microphone capture; merely muting remote input is insufficient for a privacy promise.
- Default to no retained raw audio in our app. Keep only a short in-memory buffer needed for live processing and discard it when the session ends. Explain separately that provider processing/retention depends on the configured service terms.
- Saving replay clips and contributing training data are separate opt-in choices. Provide export and deletion controls. Establish age-appropriate account and guardian flows before a children’s release.
- Encrypt transport and stored data. Protect per-user session ownership, quotas, signed media access, and deletion workflows.
- Set per-user session limits and overall spend caps. Never let an unauthenticated client create unlimited paid sessions.
- On network failure, show “Live checking paused.” Reading can continue locally, but do not claim the disconnected segment was assessed. Resume from a confirmed checkpoint with the learner’s agreement.
- On calls, audio route changes, denied permissions, or app backgrounding, transition explicitly and resume only when audio capture is valid.

The retrieved model page lists GPT-Live 1 at **USD 0.05 per minute of voice session duration**, with backend model and tool usage charged separately. [S1] Illustrative voice-only arithmetic:

| Usage | Voice session cost |
|---|---:|
| 10 minutes | $0.50 |
| 30 minutes | $1.50 |
| 60 minutes | $3.00 |
| 30 minutes daily for 30 days | $45.00 per user |
| 100 users × 10 minutes × 30 days | $1,500.00 |

These exclude verifier inference, other models/tools, hosting, storage, bandwidth, taxes, and exchange rates. Recheck prices before purchase. Silence in a running session should not be assumed free. Pause/idle behavior must close or suspend billing according to the actual API lifecycle, not merely silence the speaker. Track initialization and reconnect charges under the current transport rules. [S5]

## 15. Evaluation and release gates

Build a streaming replay harness before launching interruption features. Preserve actual timing, overlap, and packet gaps. Split train/tuning/test audio by speaker and recording session; evaluate unseen passages and devices. Use permissioned audio from fluent reciters and learners, not only synthetic errors.

Annotate with qualified Qur’an teachers: expected location, actual deviation, earliest diagnosable point, acceptable variations, uncertainty, and appropriate correction. Resolve disagreements rather than treating one unreviewed label as absolute ground truth.

Cover quiet and noisy rooms, different speaking rates, adults and children where consent permits, a range of voices and accents, phone speaker echo, Bluetooth, coughing, pauses, self-corrections, repeated phrases, mid-ayah starts, and disconnected segments.

### Proposed initial launch gates

- Zero corpus changes or verse-ID mapping failures in automated integrity checks.
- Zero language switches caused only by Arabic recitation in the language regression suite.
- Every correction resolves to a valid canonical span and current session epoch.
- For each enabled error category: target precision at least 98%, with confidence intervals and sample counts reported. A small test set is not enough to establish the target.
- Track recall separately; proposed initial target at least 90% for clearly annotated word/sequence errors. Do not hide misses by reporting only precision.
- Proposed false-interruption rate below one per 30 minutes of correct recitation, measured across supported conditions; publish stratified results so poor groups are visible.
- Zero duplicate corrections for the same live event, zero tutor-echo-as-learner errors in the defined regression suite, and reliable cancellation of stale events.
- Meet measured latency goals under a documented device and network matrix, or narrow the supported mode before release.
- Disable any tajwīd category that has not met its own teacher-reviewed assessment gate.

Metrics include event precision/recall, false interruptions per hour, position alignment error, repeat-request rate, retry resolution, teacher agreement, p50/p95/p99 latency, reconnect recovery, battery/thermal behavior, and actual cost per completed minute of practice.

Passing a benchmark is evidence for the tested scope, not proof that every future recitation is correct.

## 16. Delivery roadmap

| Phase | Deliverable | Exit gate |
|---|---|---|
| 0 — Feasibility | Account access test, native duplex audio spike, reference/context injection, measured cue path | Real phone can listen, receive intervention, and resume without echo-driven false triggers |
| 1 — Reader foundation | White reader, surah/range picker, language policy, verified corpus, offline access | Corpus and accessibility checks passed |
| 2 — Listening prototype | Live sessions, position tracking, correction controller, replay harness | Clearly labeled experimental accuracy with measured latency |
| 3 — Word/sequence beta | Validated mistakes, retries, Hifz, review queue, network recovery | Teacher-reviewed word/sequence gates passed |
| 4 — Pronunciation research | Acoustic model evaluation and reviewed tajwīd rules | Each individual category meets its own release criteria |
| 5 — Production | Quotas, privacy controls, Android release, monitoring, iOS validation | Device tests, billing tests, recovery tests, and content review passed |

Do not assign a guaranteed delivery date before Phase 0. Reader and UI work is ordinary application engineering; validated recitation assessment is the uncertainty that controls the schedule.

### First end-to-end slice

Start with Al-Fatihah and a small set of short surahs, English/Arabic explanations, visible/hidden text, supported word-sequence errors, one reference voice with cleared rights, and retry recovery. Reading can offer the complete verified corpus earlier than the assessment engine supports it. Expand assessed coverage only after testing the additional material.

## 17. How development works in this workspace

The repository can contain all mobile code, server code, schemas, instructions, and test fixtures. This workspace can be used to write and inspect those files and run available command-line checks. Actual builds depend on installing the required SDKs and having network access to dependencies. Native microphone, audio routing, and interruption timing must be tested on real phones; a rendered screen preview cannot validate them.

Android delivery uses a built APK for direct testing and an appropriately signed distribution build for release. iOS requires a compatible Apple build environment and signing. Flutter documents Android and iOS support; confirm its current toolchain requirements when setting up builds. [S8]

GitHub repository creation and push are separate operations requiring confirmed write access. This plan does not claim that a repository, live app, API session, or hosted service has been created. A persistent backend is required for production voice sessions; the editing workspace is not the production server.

## 18. Decisions to confirm during implementation

The plan proceeds with Android first and the assumptions above. Before assessed launch, settle: exact reading profile and teacher review process; corpus/font/recording licenses; developer-account Live access; monthly voice budget; target phones; initial learner age group; and whether raw clips are retained at all. These are release dependencies, not reasons to postpone the code skeleton and UI foundation.

## Sources

Checked 28 September 2026. Official technical documentation establishes the cited capabilities; the app architecture, UI, timelines, latency targets, and release gates are proposed engineering decisions.

- **S1 — GPT-Live 1 model and pricing:** https://developers.openai.com/api/docs/models/gpt-live-1
- **S2 — Getting started with GPT-Live:** https://developers.openai.com/api/docs/guides/live
- **S3 — Session context, transcript intervals, and lifecycle:** https://developers.openai.com/api/docs/guides/live-conversations
- **S4 — Prompting and custom delegation:** https://developers.openai.com/api/docs/guides/live-prompting and https://developers.openai.com/api/docs/guides/live-delegation
- **S5 — WebRTC connection and initialization:** https://developers.openai.com/api/docs/guides/voice-webrtc
- **S6 — Tanzil text license:** https://tanzil.net/docs/Text_License
- **S7 — Quran Foundation content field reference:** https://api-docs.quran.foundation/docs/api/field-reference/
- **S8 — Flutter supported platforms:** https://docs.flutter.dev/reference/supported-platforms
