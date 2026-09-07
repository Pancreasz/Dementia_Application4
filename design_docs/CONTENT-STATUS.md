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

**e. ~~Nothing is persisted.~~ FIXED (partly).** Scores still live in the
module-level globals in `lib/pages/score.dart` — every page reads them
directly and that has not changed — but they are now mirrored into a durable
`SessionRecord` and written after every subtest. `lib/moca/session_store.dart`
picks a JSON file under the documents directory on native and localStorage on
web, the same conditional-import split as `recording_sink.dart`;
`lib/moca/live_session.dart` is what the pages call. An unfinished session is
offered for resume on next launch, which restores the globals.

All eleven scoring screens now persist at their own boundary: the five original
subtests call `LiveSession.recordScores()` where they set their score, the nine
voice/tap subtests go through `recordOutcome`, and the results page calls
`complete()`. An unfinished session is offered on the home page below "start
test", labelled with its start time; resuming restores the globals and returns
to the FIRST subtest rather than guessing where the patient stood — the record
knows what was scored, not which screen was open, and guessing wrong would
re-administer a subtest that already has a score.

Two things remain true and are worth stating plainly:

- **The globals are still the live copy.** `LiveSession.syncFromGlobals` is
  what keeps the two in step. Every screen that writes a score now calls it,
  but nothing enforces that — a screen added later that writes a global and
  navigates away will not be saved, and nothing will fail to say so.
  Replacing the globals outright is still the correct end state.
- **The web store is localStorage**, which a browser may clear and which a
  private window may refuse outright. Writes fail silently by design — losing
  persistence must not take down a session in progress — so a failed save is
  invisible to the clinician.

**f. ~~The web build compiles but the voice chain does not run there.~~
FIXED.** `DeviceVoiceRecorder` no longer calls `getTemporaryDirectory()`
directly; `lib/moca/recording_sink.dart` picks a file target on native and a
Blob on web, so voice subtests run in the browser. Web is now the primary
target — the published build in `docs/` is what patients use.

**g. `transcript` and `detail` on `SubtestOutcome` are written but never
read.** Half-addressed. They now survive the process — `SubtestOutcome.toJson`
writes both, and item **e** persists the record — so the data no longer dies
when the tab closes. What still does not exist is a **review surface**: nothing
in the app displays a transcript, a similarity, or a raw event trace back to a
human. Until something does, the three unvalidated thresholds below remain
unvalidatable in practice, because nobody can see what they decided.

**g2. Three unvalidated thresholds, now.** Tracked together because the count
went up rather than down:

| Number | Where | Status |
|---|---|---|
| Sentence repetition similarity ≥ 0.90 | `lib/scoring/sentence_repetition.dart` | Unvalidated |
| Verbal fluency ≥ 11 words in 60 s | `lib/scoring/verbal_fluency.dart` | Unvalidated |
| Abstraction embedding similarity ≥ 0.55 | `lib/scoring/abstraction.dart` | Unvalidated, **and known to sit inside a measured overlap** |

The third is new, and it is the worst-characterised of the three, so the
measurement behind it is written down rather than left implied. Against 25
hand-written answers on 2026-09-07 (not patient data), **no single threshold
separated both languages**: Thai's best-scoring wrong answer ("มีล้อทั้งคู่",
they both have wheels) reached 0.547, above English's weakest correct answer
("both are used for getting around") at 0.477. 0.55 therefore rejects the Thai
concrete answer by 0.003 and rejects a correct English answer outright. Two
per-language thresholds would fit those 25 cases and were deliberately not
adopted — that fits invented data with a second invented constant.

Mitigating this, abstraction stores the **full similarity map** for every
answer (each accepted term and each stimulus word), plus the threshold applied
and which rule failed. That is what makes re-choosing the number from real
sessions possible without re-running a patient. It is also exactly the material
the missing review surface in **g** would display.

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
