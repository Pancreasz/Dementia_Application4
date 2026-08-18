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

## Not yet verified by a human

`design_docs/superpowers/plans/2026-08-17-voice-subtests-verification.md`
has a "Still requires a human — not verified" section covering everything
that needs a person at a keyboard with speakers, a microphone, and eyes on
the running app. The single highest-stakes item there: **nobody has
confirmed the recordings actually say what their paired text claims.** A
crossed sentence pair would score every patient against something they never
heard, and no automated test can catch it.
