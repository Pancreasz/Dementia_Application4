# Content and configuration status

All 29 implemented points are built and tested with final content, confirmed
by the project owner on 2026-08-17. Nothing described here is placeholder.
One external dependency remains before the voice subtests can score anything.

## Blocking: the /transcribe endpoint

Until the Flask backend implements it, all thirteen voice-scored points reach
their error screen and can only be skipped. Vigilance (1 point) is unaffected —
it is tap-based and needs no speech recognition.

The contract is in
`design_docs/superpowers/specs/2026-08-17-voice-subtests-design.md`. The
reference implementation to port is `ad_hw/sidecar/asr_server.py`, which
already works.

One addition beyond that reference: the response must include `segments`
(faster-whisper produces them and the sidecar currently discards them), because
Verbal Fluency counts distinct segments rather than splitting text — Thai has
no spaces between words, so text splitting cannot count words reliably.

## Supplied and in place — change only if the form changes

Confirmed by the project owner on 2026-08-17.

| Item | Value | Lives in |
|---|---|---|
| Sentence 1 | ฉันรู้ว่าจอมเป็นคนเดียวที่มาช่วยงานวันนี้ | `lib/moca/subtests.dart` + `assets/moca/audio/sentence-1.wav` |
| Sentence 2 | แมวมักจะซ่อนตัวอยู่หลังเก้าอี้เมื่อมีหมาอยู่ในห้อง | `lib/moca/subtests.dart` + `assets/moca/audio/sentence-2.wav` |
| Fluency prompt | letter ก, cutoff ≥11 words in 60 s | `lib/moca/subtests.dart` |
| Orientation place | โรงพยาบาลศิริราช | `lib/moca/session_config.dart` |
| Orientation province | กรุงเทพ | `lib/moca/session_config.dart` |
| Digit Span | 21854 forward, 247 backward | `lib/moca/subtests.dart` |
| Vigilance | 29-digit sequence | `lib/moca/subtests.dart` |
| Abstraction | both pairs | `lib/moca/subtests.dart` |

Two pairings are not enforced by any type and must be changed together:

- **`expectedSentence` and its `stimulusAsset`.** The scorer compares speech
  against the text while the patient hears the audio. Editing one without
  re-recording the other scores every patient against a sentence they never
  heard, and looks completely normal.
- **Verbal Fluency's `instructionTh` and `initialLetter`.** A patient told one
  thing and scored on another produces what reads as a cognitive deficit.
  Setting `initialLetter` to null switches to category mode, where every
  distinct word counts.

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

**f. The web build compiles but the voice chain does not run there.**
`DeviceVoiceRecorder.start()` (`lib/moca/audio_recorder.dart:27`) calls
`getTemporaryDirectory()` unconditionally, and `path_provider` has no web
implementation (`pubspec.lock` has `record_web` and `audioplayers_web` but
no `path_provider_web`). On web every voice subtest throws
`MissingPluginException`, is skipped, and therefore **no category is ever
assigned**. Anyone regenerating `docs/` via `flutter build web -o docs`
must guard that call behind `kIsWeb` first, or state that web is
legacy-only.

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
