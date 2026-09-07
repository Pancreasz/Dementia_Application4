# Content and configuration status

All 29 implemented points are built and tested with final content, confirmed
by the project owner on 2026-08-17. Nothing described here is placeholder.

*Status refreshed 2026-09-07.*

## No longer blocking: the /transcribe endpoint

This document previously recorded `/transcribe` as unbuilt, which made thirteen
voice-scored points unscoreable. **That is resolved** — the endpoint is
implemented in `backend/app.py` (inference in `backend/asr.py`) and every point
now administers and scores end to end. The contract it was built against is in
`design_docs/superpowers/specs/2026-08-17-voice-subtests-design.md`.

The response includes `segments`, which faster-whisper produces and the
`ad_hw` sidecar discarded. They are still required, though not for the original
reason: Verbal Fluency now counts distinct whitespace-separated tokens *across*
segments rather than counting segments themselves, because the recognizer
returns phrases and a whole 60-second answer arrived as a single segment. See
`backend/CONTEXT.md`.

What remains unverified is not plumbing but accuracy: the clock preprocessing
transform and the ASR scoring thresholds. Both fail by returning a confident
wrong number rather than an error.

## Supplied and in place — change only if the form changes

Confirmed by the project owner on 2026-08-17.

| Item | Value | Lives in |
|---|---|---|
| Sentence 1 | ฉันรู้ว่าจอมเป็นคนเดียวที่มาช่วยงานวันนี้ | `lib/moca/subtests.dart` + `assets/moca/audio/sentence-1.wav` |
| Sentence 2 | แมวมักจะซ่อนตัวอยู่หลังเก้าอี้เมื่อมีหมาอยู่ในห้อง | `lib/moca/subtests.dart` + `assets/moca/audio/sentence-2.wav` |
| Fluency prompt | letter ก, cutoff ≥11 words in 60 s | `lib/moca/subtests.dart` |
| Orientation place | โรงพยาบาลศิริราช | `lib/moca/session_config.dart` |
| Orientation province | กรุงเทพ | `lib/moca/session_config.dart` |
| Digit Span | 21854 forward, 247 backward (heard as 742) | `lib/moca/subtests.dart` + generated `digits-forward.wav` / `digits-backward.wav` |
| Vigilance | 29-digit sequence | `lib/moca/subtests.dart` + generated `vigilance.wav` |
| Abstraction | both pairs | `lib/moca/subtests.dart` |

Three pairings are not enforced by any type and must be changed together:

- **`expectedSentence` and its `stimulusAsset`.** The scorer compares speech
  against the text while the patient hears the audio. Editing one without
  re-recording the other scores every patient against a sentence they never
  heard, and looks completely normal.
- **Verbal Fluency's `instructionTh` and `initialLetter`.** A patient told one
  thing and scored on another produces what reads as a cognitive deficit.
  Setting `initialLetter` to null switches to category mode, where every
  distinct word counts.
- **The digit sequences and their generated audio.** `kVigilanceSequence` and
  Digit Span's `expectedSequence` values are the *scoring* side; the files the
  patient actually hears are built from them by `tool/build_sequences.py`.
  Change a sequence without re-running that script and the patient hears the old
  digits while the scorer expects the new ones. Note the backward case is
  deliberately not a copy: the patient hears **742** and is scored on **247**,
  so the heard order lives in the script and the scored order in
  `subtests.dart`.

  ```bash
  ./.venv/Scripts/python.exe tool/build_sequences.py
  ```

## Known limitations

**a. Windows build unverified.** `flutter build windows` fails on this
machine with "Building with plugins requires symlink support. Please enable
Developer Mode." Confirmed via the registry
(`HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock` has no
`AllowDevelopmentWithoutDevLicense`). This is an environment precondition
Flutter enforces, not a code defect — but it means the `record`/`audioplayers`
Windows plugin link has never been proven to compile. Fix: run
`start ms-settings:developers`, enable Developer Mode, then re-run
`flutter build windows`. Details in
`design_docs/superpowers/plans/2026-08-17-voice-subtests-verification.md`.

**b. Back-gesture re-entry.** No pop guards exist on the pre-existing pages.
From the end screen a back-press lands on a live, still-submittable Delayed
Recall page; a further press reaches Serial 7s, whose resubmission re-enters
the whole voice chain. This predates this work — the existing pages already
mixed `pushNamed`/`pushReplacementNamed` this way — and fixing it means
editing working subtests, so it was deliberately left alone. The new voice
subtest screen does have a `PopScope(canPop: false)` guard.

**c. ASR failure discards captured audio.** Retry re-administers the whole
subtest rather than re-uploading the audio already captured. Clinical cost:
replaying Digit Span carries a practice effect, and a second 60-second Verbal
Fluency trial is contaminated against the ≥11-word norm. Fixing it properly
means separating "retry transcription" from "retry administration".

**d. Orientation's place/province are compile-time constants** in
`lib/moca/session_config.dart`. A deployment to a second site needs the
settings screen the `TODO` there describes, or two of Orientation's six
points are wrong for every patient.

**e. Nothing is persisted.** All scores live in module-level globals in
`lib/pages/score.dart` (`animalScore`, `larkScore`, `clockScore`,
`totalScore`, `attentionScore`, `reorderScore`, `correctOrder`,
`voiceOutcomes`). An app kill, OS process kill, or crash loses the entire
session — including the five pre-existing subtests — with no trace. For a
screening instrument administered once per patient this is the
highest-consequence property of the app.

**f. ~~The web build compiles but the voice chain does not run there.~~
FIXED.** `DeviceVoiceRecorder` no longer calls `getTemporaryDirectory()`
directly; `lib/moca/recording_sink.dart` picks a file target on native and a
Blob on web, so voice subtests run in the browser. Web is now the primary
target — the published build in `docs/` is what patients use.

**g. `transcript` and `detail` on `SubtestOutcome` are written but never
read** — no consumer anywhere in `lib/` outside `subtest_outcome.dart`
itself. The design justifies shipping two unvalidated thresholds
(Sentence Repetition's 0.9 similarity, Verbal Fluency's segment count) by
saying the transcript is "stored for review". There is no review surface:
the data dies with the process. Either build one, or treat those
thresholds as unvalidatable in the field.

**h. `SessionConfig.place`/`.province` cannot be injected.**
`lib/scoring/score_item.dart` reads the statics directly
(`SessionConfig.place`, `SessionConfig.province`), so the values cannot be
overridden per session even in a test. Whoever builds the settings screen
must change `scoreItem`'s signature, not just `session_config.dart`.

**i. The Orientation date bug fixed in this branch also exists upstream**
in the reference project at `ad_hw/src/main/scoring/orientation.js`
(`date: String(referenceDate.getDate())` with the same unbounded
`keywordMatch`). Port the fix there, and re-examine any Orientation
scores already collected from that app.

## Not yet verified by a human

`design_docs/superpowers/plans/2026-08-17-voice-subtests-verification.md`
has a "Still requires a human — not verified" section covering everything
that needs a person at a keyboard with speakers, a microphone, and eyes on
the running app. The single highest-stakes item there: **nobody has
confirmed the recordings actually say what their paired text claims.** A
crossed sentence pair would score every patient against something they never
heard, and no automated test can catch it.
