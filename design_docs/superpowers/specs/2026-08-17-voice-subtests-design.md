# Voice Subtests for moca_app — Design

*2026-08-17*

## Why this document lives here

Not in `docs/`. That directory is this repo's committed Flutter web build output, served as
GitHub Pages (see commit `38e169c`), and `flutter build web -o docs` would delete anything
else placed there. `design_docs/` mirrors the superpowers convention without colliding with
the build.

## Goal

Take moca_app from 15/30 to 29/30 MoCA points by adding nine subtests, eight of them
voice-scored. The tenth remaining point (Cube copy) belongs to the user's teammates and is
out of scope.

The reference implementation is the sibling project `ad_hw`, an Electron + React app that
already has eight subtests working, with 219 passing JS tests. Where a scorer exists there,
this design ports it rather than reinventing it.

## Constraint set (decided with the user, 2026-08-17)

1. **Existing subtests are not touched.** moca_app already implements Trail, Clock, Naming,
   Serial 7s, and image-based Memory registration + Delayed Recall. Where moca_app and ad_hw
   disagree about a subtest's modality — Naming is typed here and spoken there — moca_app
   wins and the subtest is skipped. Only exit routes of existing pages change.
2. **ASR runs on the Azure Flask backend**, the same host `clock.dart` already uploads to.
   The backend source is not in this repo; the user will supply it. This design defines the
   endpoint contract so the Dart side can be built and tested against a fake in the meantime.
3. **Instructions are on-screen Thai text.** Audio is used only where the subtest is
   impossible without it: the patient must *hear* Digit Span's digits, Vigilance's digit
   stream, and Sentence Repetition's sentences. No instruction narration is ported.
4. **Scoring rescales to published MoCA cutoffs**: ≥26 normal, 18–25 MCI, 10–17 moderate,
   <10 severe. The current /15 bands were never clinically derived and are wrong at /29.
5. **Sentence Repetition and Verbal Fluency ship built but disabled** pending Thai content
   only the user has. They must not block the other eleven points.

## Scope

| id | Pts | Mode | Stimulus | Source |
|---|---|---|---|---|
| `digit-span-forward` | 1 | voice | `digits-forward.mp3` | port of ad_hw |
| `digit-span-backward` | 1 | voice | `digits-backward.mp3` | port of ad_hw |
| `vigilance` | 1 | tap | 29 scheduled `digit-N.mp3` | port of ad_hw |
| `sentence-repetition-1` | 1 | voice | **missing** | new |
| `sentence-repetition-2` | 1 | voice | **missing** | new |
| `verbal-fluency` | 1 | voice (60 s) | none | new |
| `abstraction-1` | 1 | voice | none | port of ad_hw |
| `abstraction-2` | 1 | voice | none | port of ad_hw |
| `orientation` | 6 | voice | none | port of ad_hw |

Total **+14 → 29/30**.

Eleven of the fourteen points are decided by a scorer that is a mechanical translation of
tested JS. Three points — Sentence Repetition and Verbal Fluency — need scorers that exist
nowhere yet. Vigilance sits between the two: its scorer ports directly, but its *playback* is
new work and carries the harder risk of the pair.

## Architecture

Two new directories. Nothing existing is restructured.

```
lib/
  scoring/                    pure Dart — no widgets, no mic, no network
    matchers.dart             normalizeText, keywordMatch,
                              extractDigitSequence, extractNumberSequence
    digit_span.dart
    abstraction.dart
    orientation.dart
    vigilance.dart
    sentence_repetition.dart
    verbal_fluency.dart
    subtest_outcome.dart      {score, maxScore, skipped, transcript, detail}
  moca/                       the engine — the only layer touching hardware or network
    subtest_spec.dart
    subtests.dart             the nine specs
    session_controller.dart   phase machine
    voice_subtest_page.dart   the single screen
    audio_recorder.dart
    audio_player.dart
    digit_sequence_player.dart
    asr_client.dart
    session_config.dart       place, province — see Orientation below
```

`lib/scoring/` is the load-bearing boundary. Every one of the fourteen points is decided by a
pure function there, so `flutter test` covers all of them with no hardware and no network.
`lib/moca/` owns mic, speakers, and HTTP; all three are injected, so controller tests never
open a real microphone. This mirrors ad_hw's dependency-injection arrangement, which is why
its 219 tests can run in CI.

New packages: `record` (microphone; Windows, Android, web) and `just_audio` (playback with
the scheduling precision Vigilance needs). `http` and `permission_handler` are already
present.

### Why one engine rather than nine pages

moca_app's existing convention is one hand-written page per subtest, mutating a global in
`score.dart` and hardcoding `Navigator.pushNamed` to the next. Followed literally, nine new
subtests would mean nine copies of record → upload → transcribe → score → navigate, and nine
copies of Thai digit parsing. The engine keeps that pipeline in one place and makes each
subtest a data entry.

The cost, accepted deliberately: moca_app will have two architectural styles side by side —
hand-rolled pages for the original five, a data-driven engine for the new nine. Unifying them
was considered and rejected, because rewriting working demo-ready code carries regression risk
for zero point gain.

## Session flow

MoCA groups Digit Span and Vigilance with Serial 7s under Attention, and places Orientation
last, after Delayed Recall. Matching that order requires changing the exit route of three
existing pages — one string each. No test logic in those files is modified.

```
home → larksen → clock → selectimages (registration) → animal
     → digit-fwd → digit-bwd → vigilance          NEW
     → attention (serial 7s, existing)
     → sent-rep-1 → sent-rep-2 → fluency          NEW
     → abstraction-1 → abstraction-2              NEW
     → reorderimages (delayed recall, existing)
     → orientation                                NEW
     → endpage
```

Complete list of edits to existing files:

| File | Edit |
|---|---|
| `lib/pages/animal.dart` | 2 route strings → `/digit-span-forward` |
| `lib/pages/roiLobJed.dart` | 1 route string → `/sentence-repetition-1` |
| `lib/pages/reorder_images_page.dart` | 1 route string → `/orientation` |
| `lib/main.dart` | 9 new routes |
| `lib/pages/score.dart` | new outcome map |
| `lib/pages/home.dart` | `resetScores()` clears it |
| `lib/pages/summary.dart` | new rows, rescaled thresholds |
| `pubspec.yaml` | 2 packages, audio assets |

A clinical side effect worth recording: this places nine subtests between registration and
delayed recall instead of two. The current delay is short enough that recall is easier than
the instrument intends; the new ordering corrects that without any change to either memory
page.

## The `/transcribe` contract

Deliberately shaped like ad_hw's `sidecar/asr_server.py` so that implementing it in Flask is a
transliteration of working code rather than a new design.

```
POST /transcribe          multipart/form-data
  file:      audio/wav, 16 kHz mono PCM
  language:  "th"

200  {"text": "สองสี่เจ็ด",
      "segments": [{"start": 1.2, "end": 1.8, "text": "..."}, ...]}
503  {"detail": "model not loaded"}
```

`segments` is faster-whisper's own segment list, which the model produces regardless — the
sidecar currently joins and discards it. Verbal Fluency needs it (see below); every other
scorer ignores it. Specifying it now is free and adding it later is not.

`AsrClient` is an interface with two implementations: `HttpAsrClient`, pointing at the same
base URL `clock.dart` uses, and `FakeAsrClient` for tests.

## Skip is not zero

ad_hw distinguishes these and this design keeps the distinction: a score of 0 asserts the
patient failed; skipped asserts the subtest was never administered. A skipped subtest carries
`maxScore: 0` and is excluded from **both** sides of the total.

This matters more here than it did in ad_hw, because the summary now uses real MoCA cutoffs.
A skipped Orientation silently recorded as 0/6 would move a healthy patient from "normal" to
"MCI" — a fabricated clinical finding produced by a network timeout.

`SubtestOutcome.skipped` carries it, held in a new `Map<String, SubtestOutcome>` in
`score.dart` alongside the existing `int` globals so nothing currently reading those breaks.

## Summary screen

`summary.dart` currently shows five rows and four bands calibrated to a 15-point total. Both
change.

Rows: the five existing ones, plus nine new ones reading from the outcome map. A skipped
subtest renders as "ข้าม" (skipped) rather than 0, so the screen never displays a fabricated
failure.

Bands, replacing the current /15 boundaries with the published MoCA cutoffs:

| Total | Category |
|---|---|
| ≥26 | ปกติ (normal) |
| 18–25 | บกพร่องเล็กน้อย (MCI) |
| 10–17 | มีความบกพร่อง (moderate) |
| <10 | เสี่ยงสูง (severe) |

The attainable ceiling is 29, not 30, because Cube copy is not implemented. A patient answering
everything correctly scores 29, which clears the ≥26 cutoff, so the missing point cannot by
itself push anyone across a band. It does mean every patient is scored one point below the
instrument's scale, and the screen states this rather than leaving it implicit.

If any subtest was skipped, the denominator shown is the sum of administered `maxScore` values,
not a constant. Displaying "24/29" when five points were never administered would understate
the patient by exactly the amount the network failed.

That has a consequence for the bands, and the honest answer is to suppress them: fixed cutoffs
are defined against a complete 30-point administration and mean nothing against a 23-point one.
When any subtest is skipped, the screen shows the score and the list of skipped subtests, and
states that no category can be assigned. Scaling the cutoffs proportionally would look more
helpful and would be an invention — a category presented with the same confidence as a real one
but derived from nothing.

## Phase machine

Ported from `useSubtestSession.js`:

```
instruction → stimulus → recording → scoring → (next | done)
                      ↘ tapping  ↗              ↘ error → Retry | Skip
```

Two invariants carried over verbatim, both of which exist because ad_hw hit the failure:

- **The mic must never open before stimulus playback finishes.** Otherwise the recognizer
  transcribes the app's own prompt, and Digit Span appears to pass while measuring nothing.
  This is a failure that looks exactly like success, so it is enforced by a test asserting
  literal call order rather than by care.
- **A generation counter retires abandoned attempts.** Without it, pressing Start twice leaves
  the previous attempt's timers running and two digit streams play over each other.

## Scorers

### Direct ports — no design decisions

**Digit Span** (2 pts). `extractDigitSequence` compared to `21854` forward and `247` backward.
The extractor scans character by character rather than splitting on whitespace, because Thai
does not space between words and Whisper returns `สองสี่เจ็ด` or `สอง สี่ เจ็ด` for the same
utterance arbitrarily. The whitespace version scored the run-on form as zero digits, silently
marking correct answers wrong. A test pins this case.

**Abstraction** (2 pts). Accept-lists per item, no reject-list. This is deliberate:
`เป็นพาหนะที่มีล้อ` ("vehicles that have wheels") is a correct abstract answer carrying a
concrete detail, and a reject-list for "wheels" would strip a point the patient earned. The
answers MoCA rejects share no vocabulary with the ones it accepts, so the accept-list cannot
make that mistake. A test pins this case; it must not be "hardened" by adding rejections.

**Orientation** (6 pts). Six independent keyword checks — day, month, year, date, place,
province. The year is **Buddhist Era** (Gregorian + 543), as Thai MoCA forms use.

`place` and `province` are session context, not fixed test content. ad_hw hardcodes them in
`SessionRunner.jsx` and lists a settings screen as unfinished work. This design puts them in
`lib/moca/session_config.dart` with a `TODO`, so wiring a settings screen later touches one
file.

**Vigilance** (1 pt). Window scoring: digit *i* owns `[i × 1000ms, (i+1) × 1000ms)`. First tap
per window only — a second tap is the same mistake about the same digit. One point for zero or
one errors, where errors = misses + false taps. Taps outside the sequence are dropped rather
than charged. The scorer is a straight port; the risk is entirely in playback (below).

### New work — real risk

**Vigilance playback.** The score depends entirely on which one-second window a tap landed in,
so the stimulus cannot be one long recording; the onsets would become hand-measured estimates
needing re-measurement on every re-record. Ten digit files are preloaded into `just_audio`
players and each of the 29 onsets is fired at an absolute offset from a single `Stopwatch` —
**not** `Timer.periodic`, which drifts measurably over 29 seconds.

The files run 1088–1344 ms against a 1000 ms interval, so the player must silence the sounding
digit the moment the next one starts; an over-long file must lose its own tail rather than
smear into its neighbour. Their lead-in is ~21 ms, which is the end that matters — leading
silence would be scored as the patient's reaction time and nothing can detect it.

A 1000 ms silent lead-in precedes the first digit. Silence rather than a countdown: a countdown
hands the patient a rhythm to lock onto before the task begins.

**Verbal Fluency** (1 pt, ≥11 distinct words in exactly 60 seconds). The least trustworthy
point of the fourteen.

Counting distinct Thai words from a 60-second transcript cannot use orthography — Whisper's
Thai spacing is arbitrary, which is the same fact that broke Digit Span. This design therefore
ignores spacing entirely and counts distinct `/transcribe` **segments**, keying off the
patient's own acoustic pauses between words rather than the recognizer's spacing decisions.
Segments are trimmed, filtered against the prompt (letter or category), and deduplicated.

The full transcript and the segment list are both stored so a human can verify the count. The
threshold should be treated as unvalidated until a real-speech pass has been run.

This is also the only subtest in the app with a normed deadline. Sixty seconds is not a design
choice — it is what the "≥11 words" cutoff is normed against.

**Sentence Repetition** (2 pts). MoCA scores this strictly verbatim: any omission or
substitution scores 0. Applied to ASR output, strict matching fails correct patients on
recognizer error rather than on memory. This design uses normalized comparison with a
character-level similarity threshold and stores the transcript for review.

Both the sentences and their recordings are missing from every repo involved. The subtest ships
built and unit-tested against placeholder content, and skips itself when its audio file is
absent, so it cannot block the other eleven points.

## Time limits

Verbal fluency's 60 seconds is enforced. **No other subtest has a time limit and no clock is
shown anywhere.** `timeLimitSec` on the other specs is a budget recorded with the result, not a
deadline — nothing enforces it. Cutting off a slow but correct patient would manufacture a
wrong score.

## Testing

Direct translation of ad_hw's `.test.js` files to `flutter test`.

- **Scorer unit tests** — every scorer, no mic, no network, no widgets. Must include the
  run-on `สองสี่เจ็ด` case and the `เป็นพาหนะที่มีล้อ` case, both of which pin decisions that
  look wrong until you know why.
- **Session controller tests** with fake recorder, player, and ASR client, asserting literal
  call order, so "the mic never opens before playback ends" is enforced by a test.
- **Vigilance window tests** — synthetic tap offsets, no audio.
- **Spec-shape test** on the 29-digit sequence `52139411806215194511141905112`. A single wrong
  digit changes every score the subtest produces and looks completely normal. The three
  consecutive targets at positions 18–20 are the structurally important part: they are where a
  patient tapping perseveratively and one genuinely tracking produce identical output.

**Out of reach of any test:** real Thai ASR accuracy. That needs a manual pass once the
endpoint is live. Until then the fluency and sentence-repetition thresholds are unvalidated,
and this document should not be read as claiming otherwise.

## Assets

Copied from `ad_hw/src/renderer/public/moca/audio/` into `assets/moca/audio/`:
`digits-forward.mp3`, `digits-backward.mp3`, `digit-0.mp3` … `digit-9.mp3` (12 files).

These files are **QuickTime containers named `.mp3`** — all of them. Chromium plays them
because it sniffs content rather than extension. Flutter's `just_audio` must be verified
against them early; if it rejects them, they need remuxing, and that is a task-zero risk rather
than a late surprise.

Sentence Repetition's stimulus files do not exist and are not copied.

## Dependencies on the user

1. The Flask backend repo, to add `/transcribe`.
2. Two Thai sentences for Sentence Repetition, plus recordings of them.
3. The Verbal Fluency prompt (which letter or category the Thai form specifies).
4. `place` and `province` values for Orientation.

Items 2 and 3 block 3 of the 14 points. Items 1 and 4 block verification but not construction.

## Out of scope

- Cube copy (1 pt) — the user's teammates own the pen/Wacom subtests.
- Rewriting the five existing subtests into the engine.
- A settings screen for place/province.
- Any biomarker or process-data layer. ad_hw captures `responseMs` and tap latencies; this
  design records outcomes but builds nothing on top of them.

## Note on rights

This work adds MoCA-derived material to moca_app: digit sequences, Thai instruction text, and
audio recordings. The MoCA is copyrighted by MoCA Test Inc. The user was informed of this in
the ad_hw project and chose to proceed; it is recorded here so it is not a surprise later.
