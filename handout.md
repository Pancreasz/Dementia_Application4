# Digital MoCA (Flutter app) — Handout

Continuing this project in a new session? Start here.

*Last updated 2026-08-27, after adding an English administration mode
(language toggle on the home page, English content for every section, and
three real scoring bugs found and fixed from an actual English test session)
on top of the 2026-08-19 clock/orientation/web-target work. All of it is
committed and pushed to `origin/main` in a single commit, `04783fd`.*

## What this project is

A Thai MoCA (Montreal Cognitive Assessment) cognitive-screening app in Flutter,
self-administered in a **web browser** and published to GitHub Pages from
`docs/`. The patient draws, taps, types and **speaks**; the app scores
automatically. Backend scoring (clock + all voice) runs against a local FastAPI
service for now, Azure later.

There are two repos side by side under `D:\moca_ad\`:

| | |
|---|---|
| `Dementia_Application4/` | **This app.** Flutter/Dart. The deliverable. |
| `ad_hw/` | An earlier Electron+React prototype. **Reference only** — its scorers were ported from here, and its `sidecar/asr_server.py` is the model for the backend. Not shipped. |

## Current state

**29 of 30 MoCA points implemented, in Thai or English. 244 tests passing.
`flutter analyze` has no errors** (26 pre-existing warnings/infos in older
code).

The 30th point is Cube copy, administered on paper by the owner's teammates —
deliberately out of scope.

| Section | Points | How |
|---|---|---|
| Trail making | 1 | existing |
| Clock drawing | 3 | existing — **scored by the backend** |
| Naming (animals) | 3 | existing, typed |
| Memory registration + Delayed recall | 5 | existing, image-based |
| Serial 7s | 3 | existing, typed |
| **Digit Span fwd/bwd** | **2** | new — voice |
| **Vigilance** | **1** | new — tap |
| **Sentence Repetition ×2** | **2** | new — voice |
| **Verbal Fluency** | **1** | new — voice, 60 s |
| **Abstraction ×2** | **2** | new — voice |
| **Orientation** | **6** | new — voice |

## English administration mode — added 2026-08-27

The test can now be given in English. Two TH/EN buttons on the home page
(`lib/pages/home.dart`) set `AppLanguage.current` before the patient starts —
nothing switches language mid-session, so every page just reads it once at
build time rather than listening for changes.

**Covers all 10 sections**, not just the nine voice subtests:

| | |
|---|---|
| `lib/moca/app_language.dart` | The switch itself: `AppLanguage.current` (`Language.th`/`Language.en`), the `t(th, en)` helper every page calls inline, plus `sectionLabel`/`categoryLabel` lookup tables for the handful of strings that live outside per-page literals (MoCA section headings, the `SessionTotal.category` values pinned by Thai text in their own tests). |
| `lib/moca/subtest_spec.dart` | Every subtest now carries an English counterpart of each language-dependent field — `instructionEn`, `stimulusAssetEn`, `expectedSentenceEn`, `initialLetterEn` — plus `.instruction`/`.stimulusAssetForLanguage`/`.expectedSentenceForLanguage`/`.initialLetterForLanguage` getters that resolve against the current language. `expectedSequence` (digit span) has no English variant: digits are digits regardless of language, only the narrating audio differs. |
| `lib/moca/subtests.dart` | The English content itself. Verbal fluency asks for the letter **F** (standard English MoCA administration) instead of ก. Sentence repetition's two English targets are tongue-twisters supplied by the project owner: "How can a clam cram in a clean cream can" and "The thirty-three thieves thought that they thrilled the throne." |
| `lib/moca/digit_sequence_player.dart` | `digitAssetFor(digit, language:)` resolves to `eng-digit-N.mp3` in English mode instead of `digit-N.wav` — used both by Vigilance's per-digit taps and Digit Span's stimulus lookup. |
| `lib/moca/session_config.dart` | `SessionConfig.place`/`.province` are now language-aware getters ("Hospital"/"Bangkok" in English, unchanged in Thai) rather than `static const`. |
| `lib/pages/*.dart` (all of them) | Every patient-facing string wrapped in `t('...', '...')`. Two pages needed more than string swaps: `animal.dart`'s naming-test answer key is a language-aware map (`lion`/`camel`/`rhino` vs `สิงโต`/`อูฐ`/`แรด`), and `larksen.dart`'s trail-making checkpoints alternate 1-A-2-B... instead of 1-ก-2-ข... in English mode. |

English audio ships as mp3/m4a (`eng-digit-*.mp3`, `eng-digits-forward/backward.m4a`,
`eng-sentence-1/2.m4a`) alongside the existing Thai wav files in
`assets/moca/audio/` — no pubspec change needed, the folder is already
wildcarded in. `audioplayers`' `AssetSource` plays either format identically.

**Scoring had to change too, not just the UI**, because English speech
doesn't map onto Thai-specific matching logic:

- `scoreAbstraction` (`lib/scoring/abstraction.dart`) takes a `language`
  parameter and picks between two term tables: `vehicle`/`transportation` for
  train–bicycle, `measuring instrument`/`measurement`/`measure` for
  watch–ruler — literal translations of the existing Thai accepted terms.
- `scoreOrientation` (`lib/scoring/orientation.dart`) takes a `language`
  parameter and swaps in English day/month name lists for the `day`/`month`
  items. The year item **also changed shape** — see the bug below.
- `HttpAsrClient.transcribe` now receives `language: 'en'` (via
  `session_controller.dart`, threaded from `AppLanguage.current`) instead of
  always defaulting to `'th'`. This is the one point where the fix is only as
  good as the backend model — see "Confirmed backend limitation" below.

### Three real scoring bugs, found from an actual English test session

The owner ran a live English session immediately after this shipped and hit
three wrong scores. All three are now fixed and covered by regression tests;
none were caught by the initial test suite because there was no real English
speech to test against yet — the same pattern as the 2026-08-18/19 Thai
scoring bugs the console log surfaced.

**1. Digit Span Forward scored 0 for a correct answer.** The patient's
"Two, one, eight, five, four" transcribed correctly, but `extractDigitSequence`
(`lib/scoring/matchers.dart`) only recognized Thai digit words and Arabic
numerals — spelled-out English number words extracted as nothing at all, so
`spoken=''` never equals `expected=21854`.

Fix: added `_englishDigitWords` (zero-nine) and merged it with the existing
Thai table into one `_digitWordEntries` list the scanner checks at every
position, same as it already did for Thai. `_thaiDigitEntries` (the
Thai-only version of that list) is gone — nothing else referenced it.

**2. Orientation's year scored 0 for a correct answer.** The patient
correctly said "two thousand and twenty-six" (2026, Gregorian) — the natural
way an English speaker states the year — but the scorer only ever accepted
the Buddhist Era year (2569), a hard assumption made when English mode was
first built without checking it against a real patient.

Fix: in English mode only, `scoreOrientation`'s `year` item now accepts
*either* the Buddhist Era year or the plain Gregorian year
(`referenceDate.year + 543` OR `referenceDate.year`). Thai mode is unchanged
— still Buddhist-Era-only, per the Thai MoCA form.

**3. Sentence Repetition 2's similarity dropped from a spoken-number
mismatch, not a real error.** The patient repeated the sentence correctly,
but Whisper transcribed "thirty-three" (the sentence's written form) as
digits: "The 33 thieves thought that they thrilled the throne." That
single-token difference cost enough Levenshtein distance against a ~65
character sentence to matter.

Fix: `sentence_repetition.dart` now runs `_spellOutNumbersAsDigits` — a
small English number-word-to-digit converter (compound tens+ones like
"thirty-three" first, then bare tens, then teens, then ones, in that order
so "eight" can't match inside "eighty" and "nine" can't match inside
"nineteen" before the longer words get their turn) — on both the transcript
and the expected sentence before comparing. Digit and word renderings of the
same number now compare equal regardless of which way Whisper happened to
render it.

### Confirmed backend limitation — Whisper doesn't actually understand English

The same live session also produced three failures that are **not**
frontend bugs, and not fixable without backend changes:

- **Verbal fluency transcribed English "F" words as Thai script** (heard:
  "ฟอก ฟิงก์เกอร์ 5 4 ฟีต ฟิคซ์ เฟสบุ๊ค..." — Thai phonetic renderings of
  English words, not English text), so every word was correctly rejected by
  the initial-letter check for not starting with a Latin `f` — the scorer
  behaved correctly against what it was given, but what it was given was
  wrong.
- **Abstraction hallucinated entirely unrelated text** ("Thank you for
  watching, please leave a like...", "Nationman") for short, clear English
  answers like "vehicle" and "measurement".
- **"Hospital" looped six times** in one orientation transcript
  ("Hospitality Hospitality Hospitality...") — the same class of looping
  bug fixed for Thai digit span on 2026-08-18, resurfacing because
  `backend/asr.py`'s `repetition_penalty=1.10` was tuned specifically
  against Thai digit clips.

**Root cause:** the backend's ASR model is `biodatlab/whisper-th-medium-combined`
(`backend/asr.py`), fine-tuned specifically for Thai. Passing
`language='en'` through to it (see above) does not make it a working English
recognizer — the fine-tuning has pulled it away from whatever general
multilingual behavior the base Whisper checkpoint had. **English mode is
demo-quality for voice subtests until the backend gets a real English (or
general multilingual) model** — digit span, sentence repetition and
orientation's day/month/date items score reasonably because they lean on
digits and short fixed phrases the model can still get partially right, but
verbal fluency and abstraction are not currently trustworthy in English.
This was flagged as a risk before it was confirmed; it is now a known,
reproduced limitation rather than a guess.

Fixing this properly means adding a second, general-purpose multilingual
Whisper model to the backend for English sessions (or replacing the Thai
fine-tune with one) — a separate, larger piece of backend work, not done
here.

## Backend wiring — done 2026-08-18

The app used to point at `https://moca-flask-container.azurewebsites.net`, which
is no longer deployed, spelled out separately in `asr_client.dart` and
`clock.dart`. In a real run the clock test and all eight voice subtests failed;
only tap-based Vigilance worked.

**`lib/moca/backend_config.dart` is now the only place the backend's location is
written down.** It defaults to `http://localhost:8000` — the FastAPI backend in
`backend/` — and both call sites derive from it:

- `kTranscribeEndpoint` → `kDefaultAsrEndpoint` in `asr_client.dart`
- `kClockUploadEndpoint` → `clock.dart`
- `kHealthEndpoint` — unused, there so a future pre-flight check does not
  reintroduce a second spelling

Another host needs no code change:

```powershell
flutter run -d windows --dart-define=MOCA_BACKEND_BASE_URL=https://example.net
```

`test/moca/backend_config_test.dart` pins all of it, including that the base URL
carries no trailing slash and that `azurewebsites.net` is gone.

**The app now depends on the local backend actually running.** Nothing is
bundled and nothing falls back, so start it before a session — from `backend/`:

```powershell
..\.venv\Scripts\python.exe -m uvicorn app:app --host 0.0.0.0 --port 8000
```

**The venv is at `Dementia_Application4/.venv`, one level above `backend/`** —
not at `backend/.venv`, which is what the backend README originally documented.
The README has been rewritten for the real layout; that is why every command in
it now says `../.venv/…`. Its dependencies were installed on 2026-08-18 and the
backend's 35 tests pass.

## The web target — done 2026-08-18

**This app is a website, not a desktop app.** It is published from `docs/` to
GitHub Pages. The Windows build has never succeeded (gotcha 7) and no longer
blocks anything.

**The browser microphone works.** It used to be the blocker: `dart:io` and
`path_provider` *compile* for the web and throw only when touched, so the build
succeeded and every voice subtest failed at runtime — no build error, no failing
test, and because a skip suppresses categorisation, **no MoCA category was ever
assigned**. Fixed by splitting the one genuinely platform-specific piece out:

| File | |
|---|---|
| `lib/moca/recording_sink.dart` | conditional export; default io, web when `dart.library.js_interop` exists |
| `lib/moca/recording_sink_io.dart` | temp file via `path_provider`, read then delete |
| `lib/moca/recording_sink_web.dart` | `record_web` hands back a `blob:` URL; read it, then `revokeObjectURL` |

`audio_recorder.dart` now touches neither, and `stop()` uses `AudioRecorder.stop()`'s
own return value (a path on desktop, a `blob:` URL in the browser) instead of
reconstructing a path, which has no browser equivalent. `record_web` implements
the wav encoder over an AudioWorklet, so the existing 16 kHz mono config is
honoured rather than falling back to webm/opus.

Verified in a real headless Chromium against the live backend, not just in
tests: the app renders, `getUserMedia` resolves in a secure context, a recorded
Blob round-trips to `/transcribe` for a 200, and the published `docs/` build
loads under its `/Dementia_Application4/` base path and advances past the splash.

- **A test guards the regression**: `recording_sink_test.dart` fails if anything
  in `lib/moca/` imports `dart:io` or `path_provider` outside a `_io.dart` file.
  Sabotage-checked.
- **`getTemporaryDirectory` is absent from `docs/main.dart.js`** — the proof the
  conditional import really drops the io branch.
- **The microphone needs a secure context.** https or localhost. A page served
  over plain http silently has no microphone at all.

### Backend reachability from a browser

The backend stays local for now; Azure later. Two things had to change for a
browser to reach it, neither of which the desktop build ever needed:

- **CORS.** `backend/app.py` allows exactly `https://pancreasz.github.io` and
  loopback on any port (`flutter run` picks a fresh one each launch).
  Deliberately not `*` and not all of `*.github.io`: both endpoints are
  unauthenticated and take patient audio and drawings. Override with
  `MOCA_ALLOWED_ORIGIN_REGEX`.
- **Private Network Access.** A page on a *public* origin fetching a *private*
  one (localhost) gets an extra Chrome preflight, and Starlette answers it 400
  unless `allow_private_network=True`. This is exactly the published-Pages +
  local-backend arrangement, so without it the published site fails every
  backend-scored subtest while `flutter run -d chrome` works perfectly.

When the backend moves to Azure, the app side is one flag —
`--dart-define=MOCA_BACKEND_BASE_URL=https://…` — and the CORS entry for
`pancreasz.github.io` still needs to exist *on the Azure host*.

## Outstanding Flutter work

The three items that stood here — the backend config, the ASR timeout and the
Skip control — were all done on 2026-08-18. Nothing is queued behind them; the
open items are the human verification below.

For the record, the other two:

- **The ASR timeout is 180 s**, up from 45 s. Whisper-medium int8 on CPU
  plausibly takes 30–120 s, and Verbal Fluency's clip is 60 seconds by clinical
  definition, so 45 s timed out routinely. The ceiling still matters: past it the
  backend is not coming back and the patient belongs on the Retry/Skip screen.
- **The `scoring` and `stimulus` phases now carry a Skip control** (`ข้ามข้อนี้`, a
  deliberately quiet `TextButton` — it is the only control on those screens, sits
  where a patient may idly press, and a stray press abandons the subtest).
  Scoring also states the wait: `อาจใช้เวลาสูงสุดประมาณ 3 นาที`. `skip()` bumps the
  generation counter, so a transcription that returns later cannot overwrite the
  skipped outcome, and it silences playback via the digit player's shared
  `AudioPlayback`. Both paths are covered by tests using a never-returning ASR
  client and a never-returning playback; the scoring one was sabotage-checked
  (remove the button, the test fails).

## Console logging — added 2026-08-18

Every score the app decides prints to the browser console as it is decided.
`lib/moca/score_log.dart` is the only place a transcript is ever read.

```
[MoCA] clock                  2/3  file: drawing_1787050779920.png
[MoCA] digit-span-forward     1/1  heard: "สอง หนึ่ง แปด ห้า สี่"  [spoken=21854 expected=21854]
[MoCA] sentence-repetition-2  0/1  heard: "แมวซ่อนตัวหลังเก้าอี้"  [similarity=0.71]
[MoCA] orientation            SKIPPED (not administered, excluded from total)
```

- **Two call sites only.** `voice_subtest_page.dart` at the `done` phase — the
  one choke point every completed subtest passes through, skips included — and
  `clock.dart` immediately after the response decodes.
- **`debugPrint`, not `print`.** It satisfies `avoid_print`, it is overridable in
  tests, and it survives a release build. That last point is load-bearing:
  `flutter build web -o docs` is a release build, and the strings were confirmed
  present in `docs/main.dart.js` *and* observed arriving in a real Chromium
  console after a live `POST /upload`.
- **A skip prints SKIPPED, never `0/6`.** Same invariant as the scoring: zero
  asserts the patient failed, skipped asserts it was never administered.
- **The clock line prints the raw JSON value and flags a non-int.**
  `predicted_moca_score` must be a JSON integer; a `2.0` throws inside a `try`
  that only catches parse errors and surfaces as "Error parsing server
  response", which points nowhere near the cause. The log names the real type.

**These lines are patient speech, which is health information.** The console is
fine for development and a supervised session. It is not somewhere to leave
transcripts on a shared machine, and if this is ever deployed for unsupervised
use the logging should be behind a flag.

## Fixed: voice subtest screens rendered flush left — 2026-08-19

All nine new subtest screens (`digit-span-forward`, `digit-span-backward`,
`vigilance`, `sentence-repetition-1/2`, `verbal-fluency`, `abstraction-1/2`,
`orientation`) showed their instruction text and buttons pinned to the left
edge instead of centered — reported after a real run at
`http://localhost:*/#/<route>`.

**Root cause:** `Scaffold.body` does not center its child — it positions the
child at the top-left of the available area. A `Column` with no stretching
ancestor sizes its own width to its widest child, not to the full screen
width, so `mainAxisAlignment: MainAxisAlignment.center` was only ever
centering content *within* that narrow column, which itself sat flush left.
One fix point because all nine routes share `lib/moca/voice_subtest_page.dart`.

**Fix:** wrapped the body's `Padding` in a `Center` and added
`mainAxisSize: MainAxisSize.min` to the `Column` so it doesn't try to expand
to fill the now-unbounded width `Center` offers it.

## README rewritten — 2026-08-19

The top-level `README.md` was still the stock `flutter create` boilerplate
and claimed `/transcribe` "is not deployed yet" (false since 2026-08-18). It
now has real run instructions: putting Flutter on `PATH`, `flutter pub get`,
starting the backend first, `flutter run -d chrome`, overriding the backend
host via `--dart-define=MOCA_BACKEND_BASE_URL=...`, running tests, and a
condensed backend env-setup section (venv location, `requirements-dev.txt`
vs. the heavier `requirements-convert.txt` for ASR, `/health` check) that
links to `backend/README.md` for the full CORS/latency/validation detail
rather than duplicating it.

## Fixed: clock drawing scored 0/3 regardless of quality — 2026-08-19

Every clock submission scored 0-1 no matter how good the drawing, but
`test_model.py` (loading the sample `clock_0..3.png` files directly) scored
all four correctly. The model and preprocessing were never the problem.

**Root cause:** in `lib/pages/clock.dart`, the `RepaintBoundary` used to
capture the drawing (`saveCanvas` → `boundary.toImage()`) wraps only the
`CustomPaint`/`LinePainter`, which painted *only the line strokes* on a fully
transparent canvas. The white background visible on screen comes from the
parent `Container`'s `BoxDecoration`, which sits **outside** the
`RepaintBoundary`. So every uploaded PNG had a transparent background, not a
white one. The backend's `Image.open(bytes).convert("RGB")` doesn't composite
transparency onto white — it keeps the raw channel values, which for an
untouched Flutter canvas pixel are `(0,0,0,0)`. The background silently
became **black**, nothing like the white-background photos the model was
trained on (and that `test_model.py`/`clock_0..3.png` test against).

**Fix:** `LinePainter.paint()` now draws an opaque white background rect
before the strokes, so it's captured in the same layer:
```dart
canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
```

**Test:** `test/pages/clock_test.dart` renders `LinePainter` in a
`RepaintBoundary` and asserts the captured background pixel is opaque white,
not transparent. Had to route the capture through `tester.runAsync` —
`toImage()` never resolves inside `testWidgets`' fake-async zone (same class
of gotcha as #5 below). Sabotage-checked.

## Scoring bugs found by the console log — 2026-08-18

The first real session with logging turned on produced three scoring bugs in one
screen. All three would have looked like patient deficits.

### Fixed: verbal fluency scored 0 for a good answer

A patient listed fourteen valid `ก` words and scored `distinctCount: 0`. Two
independent causes:

- **The scorer counted one word per ASR segment.** faster-whisper returns
  *phrases*: the entire 60-second answer arrived as a single segment, so the
  whole string was tested as if it were one word. It now splits on whitespace
  within each segment.
- **`startsWith('ก')` is wrong for Thai.** Leading vowels are written *before*
  the consonant they follow, so `"ไก่".startsWith("ก")` is false for a word that
  plainly begins with the ก sound. Same for แก้ว, เก้าอี้, โกรธ, ใกล้. Matching now
  skips `เแโใไ` before comparing.

Remaining weakness, tested and documented rather than solved: if the recognizer
returns run-on Thai with no spaces there is nothing to split on, and the answer
counts as one word. That **under**-counts, failing a good patient rather than
passing a poor one — the safer direction, but not safe. A real fix needs a Thai
word segmenter (PyThaiNLP) server-side.

### Fixed: digit span was slow *and* wrong, from one root cause

`digits-forward.wav` is 7.8 seconds. It was taking **144–174 seconds** and
returning the sequence four times over.

- **The slowness was faster-whisper's temperature ladder.** It defaults to
  retrying a decode at (0.0, 0.2, 0.4, 0.6, 0.8, 1.0) whenever the output trips
  its compression-ratio or logprob threshold. Isolated spoken digits separated
  by pauses trip it every time, so every digit span paid for up to six full
  decodes. `temperature=0` took the same clip to ~15 s.
- **The wrong answer was looping.** With the ladder gone the model still emitted
  "21854" four times for a clip containing it once — confirmed against the
  waveform, which has exactly five speech bursts. `scoreDigitSpan` compares for
  exact equality, so the looped transcript scored a correct patient 0.
  `repetition_penalty=1.10` removed the loop outright.

Live through the backend now: **13.6 s, transcript exactly `21854`**. Both
options live in `backend/asr.py` and are overridable via `MOCA_ASR_TEMPERATURE`
and `MOCA_ASR_REPETITION_PENALTY`.

**Residual risk — verbal fluency.** A repetition penalty discourages repeated
tokens, and a Thai letter-fluency answer legitimately repeats a prefix
(`กระหนก กระจู กระเจี้ยว กระจอก`). Fluency is also the one subtest whose
transcription was already good, so this can only hurt it. Needs checking against
a real 60-second fluency recording; back it out with
`MOCA_ASR_REPETITION_PENALTY=1.0` if it bites.

### Fixed: sentence repetition was decided by recognizer whitespace

The new decoding options changed where the recognizer puts spaces in every clip
(`…ช่วยงานวันนี้` became `…ช่วยงาน วันนี้`). Each stray space is an edit against a
~50-character sentence, and the 0.90 threshold has only 0.10 of headroom, so
whitespace alone could decide the point. `sentence_repetition.dart` now strips
whitespace before comparing rather than collapsing it — Thai has no word spaces,
so the recognizer's are arbitrary by the file's own reasoning.

### Fixed: orientation lost points a patient answered correctly — 2026-08-19

Real sessions (with console logging on) surfaced three separate ways
orientation under-scored a correct answer. All three are the same root shape:
Thai has multiple valid spoken forms for the same thing, ASR renders a
different one from take to take of the *same* answer, and the old matcher
only recognized one of them.

- **`day` failed on whitespace.** Expected is `วันอังคาร` (one token); ASR
  sometimes renders it `วัน อังคาร`, and `keywordMatch` was a bare `contains`
  with no whitespace stripping. Fixed: `keywordMatch` (`matchers.dart`) now
  strips all whitespace before comparing, not just collapses it — the same
  fix `sentence_repetition.dart` already had. This also benefits
  `abstraction.dart`, which shares `keywordMatch`.
- **`date` only matched Arabic digits.** A patient saying "nineteen" as the
  Thai compound word `สิบเก้า` (never as digits) always failed, because
  `_numberStated` only recognized literal `19`. Fixed: `thaiCompoundNumberWords`
  / `thaiCompoundNumberStated` in `matchers.dart` generate and match the
  correct Thai reading for 10-31 (handles the `ยี่สิบ`-not-`สองสิบ` irregular
  at 20, and both `เอ็ด`/`หนึ่ง` endings). **Deliberately not extended below
  10** — see the collision note below.
- **`year` only matched Arabic digits, same as date.** A patient can say the
  Buddhist Era year digit-by-digit (`สอง ห้า หก เก้า`) or as one compound
  number (`สองพันห้าร้อยหกสิบเก้า`); the old code recognized neither, only
  literal `2569`. Fixed: `thaiDigitByDigitWords` / `thaiFullNumberWordVariants`
  / `thaiFullNumberStated` in `matchers.dart` cover both, for any 0-9999 value.

**A real collision the year fix could have introduced, now guarded and
tested:** the year's own compound reading can contain a teen date as a literal
substring — 2569 read as `...หกสิบเก้า` (sixty-nine) has `สิบเก้า` (nineteen)
sitting inside it as the tail. Without a guard, a date of 19 would get false
credit purely from the year's own text, even if the patient never separately
stated the date. `_precededByDecadeMultiplier` in `matchers.dart` rejects a
teen match that's immediately preceded by another digit word (which means
it's actually part of a bigger decade number, not a standalone teen), while
still accepting a genuine standalone occurrence elsewhere in the same
transcript. This is also why single-digit dates (1-9) are still digits-only:
a bare digit word like `เก้า` (9) is *itself* the suffix of every
`สิบX`/`ยี่สิบX` teen/twenty word, and the year is routinely read
digit-by-digit right there in the same answer — matching it unguarded would
let the year's last digit falsely satisfy an unrelated single-digit date.

**Still not perfect, by design of the approach, not oversight:**
`place`/`province` are still bare substring (`keywordMatch`) against one
fixed hospital/province string each — a synonym or abbreviation still fails.
There is no bound on every way a number could be phrased beyond the two
Thai forms now covered. This is the ceiling of matching free-form ASR
transcripts against a fixed vocabulary: closing one gap finds the next one,
because Whisper's rendering of the same spoken number is non-deterministic
across takes. Log every surprising score (see Console logging below) rather
than assuming a low score means a bad answer.

## Architecture as built

- **Two new directories**, and the boundary is load-bearing:
  - `lib/scoring/` — **pure Dart**. No widgets, no mic, no network. Every one of
    the 14 new points is decided by a pure function here, which is why they are all
    unit-tested with no hardware.
  - `lib/moca/` — the engine. The only layer touching microphone, speakers or HTTP,
    and all three are injected so tests never open a real mic.
- **One data-driven screen.** `voice_subtest_page.dart` renders all nine new
  subtests from a `SubtestSpec` in `lib/moca/subtests.dart`. Adding a subtest is a
  data entry, not a new page.
- **The original five pages are untouched** apart from four exit-route strings.
  That was a deliberate constraint from the owner.
- **`SubtestSessionController`** drives instruction → stimulus → response → score,
  with a generation counter retiring abandoned attempts.

Existing scores still live in `int` globals in `lib/pages/score.dart`; the nine new
ones live in a `Map<String, SubtestOutcome>` alongside them, because unlike the old
five they can be **skipped**, which an `int` cannot represent.

## Non-negotiable invariants — a test enforces each

- **The microphone must never open before stimulus playback finishes.** Otherwise
  the recognizer transcribes the app's own prompt and Digit Span appears to pass
  while measuring nothing — a failure that looks exactly like success. Enforced by
  a literal call-order test in `session_controller_test.dart`, which was
  sabotage-checked (drop the `await`, the test fails).
- **Skip is not zero.** A skipped subtest carries `maxScore: 0` and is excluded
  from *both* sides of the total. Zero asserts the patient failed; skipped asserts
  it was never administered. Counting a skipped Orientation as 0/6 would drag a
  healthy patient into "MCI" on a network failure.
- **No category is assigned when anything was skipped.** Published MoCA cutoffs
  (≥26 / 18–25 / 10–17 / <10) are defined against a complete administration.
  Scaling them to a partial denominator would be an invention presented with the
  confidence of a real finding.
- **No time limits and no on-screen clock anywhere except Verbal Fluency's 60 s**,
  which is normed against its "≥11 words" cutoff.
- **Thai has no spaces between words.** Never `split(' ')` on Thai. Use substring
  matching or character scanning. And never bare `contains` for *numbers* — see
  gotcha 4.
- **Orientation's year is Buddhist Era** (Gregorian + 543).

## Gotchas — do not re-debug these

1. **Flutter is not on PATH.** It lives at `C:\Users\pumasin.p\dev\flutter\bin`.
   Every PowerShell session needs
   `$env:PATH = "C:\Users\pumasin.p\dev\flutter\bin;$env:PATH"` first.
   Shell is PowerShell: `&&` is a parse error, use `;`.
2. **`build/` is tracked and permanently dirty** with pre-existing artifacts that
   are not yours. **Never `git add -A` or `git add .`** — always name paths.
3. **`docs/` is NOT documentation.** It is the committed Flutter web build served
   as GitHub Pages at <https://pancreasz.github.io/Dementia_Application4/>. Real
   docs live in **`design_docs/`**. Regenerating it is now a normal step rather
   than an accident to avoid — but **run it from PowerShell, not Git Bash**:

   ```powershell
   flutter build web -o docs --base-href "/Dementia_Application4/"
   ```

   Git Bash's MSYS path conversion rewrites `/Dementia_Application4/` into
   `C:/Program Files/Git/Dementia_Application4/` and the build refuses it. The
   base href is not optional: a project page is served under `/<repo>/`, and
   without it every asset 404s.
4. **`keywordMatch` is bare `String.contains` and is unsafe for numbers.** This
   caused a real Critical bug: Orientation's date (1–2 digits) matched inside the
   Buddhist-Era year (4 digits), so `"2569".contains("6")` awarded the date point
   free on the 6th of any month, and scored *wrong* answers as correct. Fixed with
   digit-boundary matching in `orientation.dart` (`_numberStated`). **The same bug
   still exists upstream in `ad_hw/src/main/scoring/orientation.js`.**
5. **`DateTime.now()` is not fake-time-aware under `flutter_test`.** `fake_async`
   intercepts `Timer`/`Future.delayed` and `package:clock`, but not raw
   `DateTime.now()` — and both `digit_sequence_player.dart` and
   `session_controller.recordTap()` use it. So `tester.pump()` cannot aim a
   Vigilance tap at a scoring window; the test uses a real
   `tester.runAsync(Future.delayed(...))`. Production is unaffected.
6. **The Vigilance tap test uses a real 2.5 s wall-clock wait** with ~500 ms of
   slack. If CI ever goes intermittently red on *"a tap inside a target window is
   scored as a hit"*, that is why. The fix is to inject a clock, not to widen the
   wait.
7. **`flutter build windows` has never succeeded** (Developer Mode, then
   `Visual Studio 16 2019 could not find any instance`). **This no longer
   matters** — the target is the web, and `flutter build web` works. Left here
   only so nobody re-investigates it thinking it blocks something.
8. **`expectedSentence` and `stimulusAsset` must always change together**, as must
   Verbal Fluency's `instructionTh` and `initialLetter`. Nothing in the type system
   ties either pair, and a mismatch scores every patient against a task they were
   never set, while looking entirely normal.
9. **A `RepaintBoundary` only captures its own subtree's paint output, not an
   ancestor's `BoxDecoration`.** This is exactly what caused the clock 0/3 bug
   above: put the background inside whatever the boundary wraps (a
   `canvas.drawRect` in the `CustomPainter`, here), never rely on a parent
   `Container`'s decoration showing up in a `toImage()` capture.
10. **`RenderRepaintBoundary.toImage()` never resolves inside `testWidgets`'
    fake-async zone.** Same family as gotcha 5 — real rasterization needs the
    real event loop. Wrap the call in `tester.runAsync(() async { ... })` or
    the test hangs for the full 10-minute timeout with no error, just silence.
11. **Dart identifiers are ASCII-only — Thai text right after a bare `$var`
    interpolation does NOT get swallowed into the identifier.** `'$tensWordเอ็ด'`
    parses correctly as `tensWord` followed by literal `เอ็ด`; braces
    (`'${tensWord}เอ็ด'`) are unnecessary and `flutter analyze` will flag them.
    Unlike some Unicode-identifier languages, Dart won't merge Thai characters
    into a preceding ASCII variable name.

## The backend

Rebuilt from scratch in **`backend/`** — FastAPI, serving `/upload` (clock
DenseNet), `/transcribe` (Thai Whisper), and `/health`. It has its own
`backend/handout.md`, `README.md`, `CONTEXT.md` and ADRs; read those before
touching it.

Two things a Flutter-side session should know:

- **`/upload`'s contract is pinned by `clock.dart`.** `predicted_moca_score` must
  be a JSON **integer** — it is assigned straight to a Dart `int`, and a `2.0` or
  `"2"` throws inside a `try` that only catches JSON parse errors, surfacing as a
  misleading "Error parsing server response".
- **The clock model's preprocessing was assumed; it has now been checked once.**
  The original PyTorch training script is permanently lost.
  `backend/scripts/validate_clock.py` was run on 2026-08-18 and the transform
  `clock.py` actually uses at runtime — Resize + ToTensor + ImageNet Normalize —
  scored **4/4** on `clock_0..3.png`. The two rival candidates scored 3/4 and
  1/4, so the choice is not arbitrary. `/upload` was then exercised live and
  returned 3 for `clock_3.png` and 0 for `clock_0.png`, as bare JSON integers.

  **Four images means "plausible", not "accurate"** — the script says so itself.
  This rules out the preprocessing being flatly wrong; it does not establish the
  model's accuracy, which needs a real test set. Do not quote 4/4 as an accuracy
  figure.

## Verification still owed

Nothing below can be settled by the test suite.

1. **The stimulus recordings — now machine-checked, still not heard by a human.**
   On 2026-08-18 all four were pushed through the live `/transcribe` endpoint and
   compared against what the specs claim. Three match:

   | File | Spec claims | ASR heard | |
   |---|---|---|---|
   | `digits-forward.wav` | `21854` | `21854` (+ tail, see below) | ✔ |
   | `digits-backward.wav` | patient hears `742`, says `247` | `742` | ✔ |
   | `sentence-1.wav` | `ฉันรู้ว่าจอมเป็นคนเดียวที่มาช่วยงานวันนี้` | identical | ✔ exact |
   | `sentence-2.wav` | `แมวมักจะซ่อนตัวอยู่หลังเก้าอี้เมื่อมีหมาอยู่ในห้อง` | same minus `จะ` | ✘ off by one word |

   This rules out the catastrophic case — a *crossed* pair, where a file is
   matched to the wrong subtest entirely. It does not rule out a subtle one, and
   an ASR transcript is not an ear: a recognizer that drops a word and a
   recording that never contained it are indistinguishable from here.

   **`sentence-2.wav`: does the recording actually say `จะ`?** Either the
   recording omits it or Whisper dropped it — `จะ` is short and unstressed, so
   both are plausible. It does not currently change a score: 2 characters out of
   50 is a 0.96 similarity against the 0.90 threshold, so a patient repeating
   what they heard still scores 1. But it **halves the margin**, from 5 tolerable
   characters to 3. Resolve it by ear, then either re-record or drop `จะ` from
   `expectedSentence`.

   **Still needs headphones**, for the reason above and for item 2.
2. **Vigilance timing by ear** — a ~1 s silence, then digits at a steady
   one-per-second with *no overlap*, especially across the three consecutive target
   `1`s at positions 18–20.
3. **A full session end to end**, all 17 hops, including that Delayed Recall
   advances to Orientation (that join point is covered only by a source-literal
   check, not a driven UI test).
4. ~~The Windows build~~ — no longer relevant; the target is the web, which
   *has* been driven in a real browser. See "The web target".
5. **Whisper hallucinates a tail on the digit clips, and `scoreDigitSpan` uses
   exact equality.** Transcribing `digits-forward.wav` twice gave `21854` followed
   by *different* invented digits each time (`...หก สี่ สิบ สอง...` once,
   `...สอง หนึ่ง แปด ห้า สี่...` the other). That is Whisper filling trailing
   silence, and it is well documented for this model family. `digit_span.dart`
   scores `spoken == expectedSequence`, so **one hallucinated digit appended to a
   correct answer scores a correct patient 0.** Observed on the stimulus file, not
   yet on a patient recording — a real response is shorter and less padded, so it
   may not reproduce. Worth deliberately testing with a real 2-second answer before
   trusting either Digit Span point.

`design_docs/superpowers/plans/2026-08-17-voice-subtests-verification.md` has the
complete list under "Still requires a human — not verified".

## Known limitations

Full detail in **`design_docs/CONTENT-STATUS.md`**. The ones that bite:

- **Nothing is persisted.** Every score lives in module-level globals. An app kill,
  crash, or force-quit during a slow transcription loses the entire session,
  including the five original subtests. For an instrument administered once per
  patient this is the highest-consequence property of the app.
- **Nothing is persisted — and on the web that is worse.** A tab close, a
  refresh, or a crash loses the whole session. A browser makes all three far
  likelier than a desktop app does, and there is no "are you sure" guard.
- **Back-gesture re-entry.** From the end screen a back-press lands on a live,
  still-submittable Delayed Recall page; a further press reaches Serial 7s, whose
  resubmission re-enters the whole voice chain. Pre-existing — the old pages already
  mixed `pushNamed`/`pushReplacementNamed` this way — and left alone deliberately.
  The new voice screen has a `PopScope` guard.
- **ASR failure re-administers rather than re-uploads.** Retry replays the whole
  subtest, which carries a practice effect on Digit Span and contaminates a second
  60-second fluency trial against the ≥11-word norm.
- **`transcript` and `detail` are now printed, but still not persisted.**
  `lib/moca/score_log.dart` writes one line per score to the browser console as
  it is decided, which is what makes a surprising score explicable and lets the
  two unvalidated similarity thresholds be checked against real speech. It is
  still not a review surface: close the tab and it is gone, and nothing
  aggregates across patients.
- **`SessionConfig.place`/`.province` cannot be injected.** `scoreItem` reads the
  statics directly, so a settings screen must change `scoreItem`'s signature, not
  just `session_config.dart`.
- **English mode is not clinically trustworthy yet for voice subtests that
  need real English speech recognition.** See "Confirmed backend limitation"
  above — the backend's ASR model is Thai-only under the hood regardless of
  the `language` flag sent to it. Digit span, sentence repetition and most of
  orientation hold up reasonably (they lean on digits/short fixed phrases);
  verbal fluency and abstraction do not.

## Key documents

| Doc | What it covers |
|---|---|
| `design_docs/superpowers/specs/2026-08-17-voice-subtests-design.md` | The design and the `/transcribe` contract |
| `design_docs/superpowers/plans/2026-08-17-voice-subtests.md` | The 21-task implementation plan |
| `design_docs/superpowers/plans/2026-08-17-voice-subtests-verification.md` | What was and was not verified |
| `design_docs/CONTENT-STATUS.md` | Test content, pairings, known limitations |
| `backend/handout.md` | The backend brief |

## Knowledge graph — added 2026-08-19

`graphify-out/` (gitignored, local-only, regenerate with `/graphify` — see
`~/.claude/skills/graphify`) holds a queryable knowledge graph over `lib/`,
`backend/`, and `test/` — 777 nodes, 996 edges, 61 communities. `docs/` and the
native platform folders (`ios/android/macos/linux/web`) were deliberately
excluded: they pushed the raw corpus to 8.3M words with no useful signal
(`docs/` is the compiled web build, see gotcha 3). Open `graphify-out/graph.html`
in a browser, or read `graphify-out/GRAPH_REPORT.md` for the god nodes,
surprising connections, and per-community breakdown. `graphify query "<question>"`
answers questions from the existing graph without rebuilding it.

## How to run

```powershell
$env:PATH = "C:\Users\pumasin.p\dev\flutter\bin;$env:PATH"
flutter test                     # 244 tests, ~15 s
flutter test --reporter expanded # use this, not the default, when you need a
                                  # reliable line-per-test log to grep or
                                  # pipe through `tail` — the default compact
                                  # reporter overwrites lines with \r and some
                                  # silently vanish when captured to a file
flutter analyze     # no errors; 26 pre-existing warnings/infos
flutter run -d windows   # see gotcha 7 — has never built
```

## Git state

On `main`, **working tree is clean and pushed** — `main` and `origin/main`
match, at `04783fd` ("added eng version"), which carries the entire English
mode plus the three scoring bug fixes above. Earlier
clock/orientation/backend-wiring/web-target work from 2026-08-19 is in
`67a8daa` and `ec4be44` beneath it. `docs/` still carries its usual
pre-existing build drift (see gotcha 2/3) but nothing is staged or dirty
right now. **`docs/` has not been rebuilt since `04783fd` landed** — the
published GitHub Pages site does not yet include English mode; run the
`flutter build web -o docs --base-href "/Dementia_Application4/"` command
under gotcha 3 before expecting it live. Still true: never `git add -A`/`git
add .` (gotcha 2) — name paths explicitly when you do commit next.
