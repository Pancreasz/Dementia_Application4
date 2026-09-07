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

  **Listen to what the script produces.** Item **k** below is a case where the
  file was correct, every automated check passed, and the patient still heard
  the wrong sequence. No test in this repo can hear.

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

**g. ~~`transcript` and `detail` on `SubtestOutcome` are written but never
read.~~ FIXED.** `lib/pages/analysis.dart` is the review surface, computed in
`lib/analysis/domain_analysis.dart` and reached between the last subtest and
the score (`nextRouteAfter('orientation')` is now `/analysis`, which continues
to `/endpage`). It shows, per MoCA domain, a three-level status **taken from
the points and from nothing else**, with the stored measurements beneath it as
description: the sentence-repetition similarity against its threshold, the
abstraction similarity map and which of the three failure shapes it was, digit
span's transposition-vs-omission, vigilance's misses and false taps counted
separately with their positions, orientation's per-field results, and the
delayed-recall arrangement.

`DomainAnalysis.status` is a function of `score` and `maxScore` and cannot see
an observation — that separation is the whole point and there is a test on it
(*"full marks stay full marks however bad the measurements look"*). Three tones
exist: descriptive, **caution** (a statement about the app — an unvalidated
threshold, an ASR artefact, a known defect — never about the patient), and
**not captured**, which is shown rather than left blank because an absent
measurement and an absent finding are different claims.

Two capture gaps were closed to make it work, both raw rather than derived:
`scoreVigilance` now records `missPositions`/`falseTapPositions` alongside the
counts, and the delayed-recall page records the arrangement the patient
produced instead of discarding it the moment the count was taken.

**Naming now has the in-app keyboard** (`lib/moca/naming_keyboard.dart`), which
does two jobs. It captures keystrokes — `itemShown`, `keyPressed`, `keyDeleted`,
`submitted`, all raw with offsets — so the analysis page can report
time-to-first-key, mid-word stalls, corrections, the answer actually given, and
whether a wrong answer was one or two characters from the target. It is also a
*controlled input surface*: the page no longer contains a `TextField` at all,
because the system keyboard brings autocorrect and Thai word prediction with
it, and prediction can supply the very word the subtest is testing.

The confound is handled the way the plan requires: **time-to-first-key is
reported in absolute terms, inter-key intervals never are.** A slow typist and
a hesitant one are indistinguishable in absolute terms, so every interval is
compared against that patient's own median across all three animals, and the
page says so in as many words. The keyboard is a fixed logical key size in a
fixed alphabetical order, which makes layout constant across patients — but not
across *devices*, since logical pixels are not millimetres and a narrower
screen wraps the rows differently. Cross-patient timing comparison needs the
same hardware; within-patient comparison, which is what the page actually does,
does not.

What is still not captured, and says so on the page: trail-making move times
and per-subtraction timing on Serial 7s.

**k. Digit Span Backward played "4 2" instead of "7 4 2". FIXED.** Reported by
the project owner on 2026-09-07 from listening to the running app. The stimulus
file was never wrong — all three digits are in `digits-backward.wav`, and the 7
is the loudest sample in it. It is *short*: เจ็ด is a closed syllable and that
recording runs **120 ms**, against 190–390 ms for most digits (only หก, at
110 ms, is shorter). `build_sequences.py` placed it 80 ms into the file, so the
entire first digit lived inside the first 200 ms of playback — precisely the
window a browser spends buffering after `play()` is called on an undecoded
source. Digit Span Backward is scored on exact equality, so **every patient
scored 0 on it**, and the app looked like it was working.

Two changes, because one of them is the cause and the other is insurance:

- `DeviceAudioPlayback.play` now calls `setSource` and awaits it before
  `resume()`, so decoding finishes before any sound is due. Vigilance never had
  this bug because `DigitSequencePlayer` already split load from start for a
  related reason; this brings the one-shot path in line.
- `build_sequences.py` prepends **500 ms of silence** to the digit-span files
  only. Not to Vigilance: its taps are bucketed by `offset ~/ intervalMs` from
  the first digit's onset, so leading silence in the file would shift every
  digit off the grid the scorer assumes and charge every tap to the wrong
  digit. Vigilance takes its lead-in from `SubtestSpec.leadInMs` instead, which
  delays the start without moving the digits relative to each other.

`digits-forward.wav` and `digits-backward.wav` (and their `eng-` counterparts)
were regenerated and are 500 ms longer; `vigilance.wav` rebuilt byte-identical,
which is the check that the change was confined where it was meant to be.

Still open: **nobody has confirmed by ear that the fix works**, and the 120 ms
recording of เจ็ด is short enough that it may still be hard for an elderly
patient to catch even when it plays cleanly. If it is, the answer is to
re-record `digit-7.wav`, which needs the original speaker.

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
sessions possible without re-running a patient.

All three thresholds are now **visible** on the analysis page (**g**), each
next to the similarity or count it was applied to, and a score that fell within
0.05 of its threshold is labelled there as an artefact of the threshold rather
than a finding about the patient. Visible is not validated — the numbers are
still guesses — but a clinician can now see which decisions they made, which is
the precondition for ever replacing them with measured ones. Sentence
repetition's threshold moved from a private constant into
`kSentenceSimilarityThreshold` and into every outcome's `detail`, so the page
states the number a score was actually measured against rather than repeating
it in its own text where it could drift.

**h. `SessionConfig.place`/`.province` cannot be injected.**
`lib/scoring/score_item.dart` reads the statics directly
(`SessionConfig.place`, `SessionConfig.province`), so the values cannot be
overridden per session even in a test. Whoever builds the settings screen
must change `scoreItem`'s signature, not just `session_config.dart`.

**j. The ASR model changed on 2026-09-07 and the swap is only partly
characterised.** `backend/asr.py` now defaults to
`scb10x/typhoon-whisper-large-v3` (Thai fine-tune of whisper-large-v3, CT2
float16 on disk, loaded as int8) in place of
`biodatlab/whisper-th-medium-combined`. What was actually measured, on the four
generated stimulus clips — **which are TTS, not patient speech, and are never
sent to `/transcribe` in a real session** — is in the table below. Read it as a
proxy, not as validation; item **g2**'s point stands that nothing here has been
checked against a real voice.

| | typhoon large-v3 | whisper-th medium |
|---|---|---|
| Load (warm) | 12.7 s | 2.4 s |
| `digits-forward.wav` | `สองหนึ่งแปดห้าสี่` ✓ | `สอง หนึ่ง แปด ห้า สี่` ✓ |
| `digits-backward.wav` | `สี่สอง` — **dropped the leading 7** | `เจ็ด สี่ สอง` ✓ |
| `sentence-1.wav` | exact ✓ | exact ✓ |
| `sentence-2.wav` | exact ✓ | `มี` for `หมา` ✗ |
| Per short clip | 19–27 s | 11–18 s |

So it is **not a uniform improvement**: better on sentence repetition, worse on
one digit clip, and consistently ~1.7x slower. Still inside the client's 180 s
timeout, and the two pathologies `DEFAULT_TEMPERATURE` and
`DEFAULT_REPETITION_PENALTY` were introduced to fix (the temperature ladder and
digit looping) did not return, so those settings carry over unchanged.

**The dropped digit is the model, not the decoding options.** `สี่สอง` came back
identically under all four of: as-shipped, no repetition penalty, faster-whisper
defaults (temperature ladder on), and no-speech/logprob thresholds disabled.
There is no setting to turn back. On the isolated ~1-second `digit-N.wav`
stimuli it is worse still: typhoon returns **empty** for `digit-2` and
`digit-4`, and hallucinates `"TODAY"` for `digit-7`, where the medium model's
2026-08-18 smoke test at least got 2/7/0 right.

**Narrowed by item k below.** The digit typhoon dropped is a **120 ms**
recording of เจ็ด — the shortest-but-one digit in the Thai set, and short
enough that the app's own playback was losing it too. So this is evidence that
typhoon is weaker on *very short* utterances than the medium model, not that it
drops leading digits generally: the first digit of `digits-forward.wav`
(สอง, 340 ms) came through fine on both. The measurements above were taken
against the pre-fix files, which had no lead-in silence; that changes the
audio's length but not the speech in it.

**This is the risk to watch, and it is not yet measured where it counts.** Every
clip above is TTS stimulus. But a patient's *real* digit-span answer is also a
short utterance — three to five digits, two or three seconds, the exact length
where typhoon is dropping and blanking here. Digit span is scored on exact
equality (`scoreDigitSpan`), so one dropped leading digit is the whole point.
Before this model is trusted for a real session, record a human saying "เจ็ด สี่
สอง" and check it comes back with all three digits. If it does not, revert with
`MOCA_ASR_MODEL_DIR` — the medium build is still on disk.

Two further things follow that are not done:

- **Nothing scores worse today because of the dropped digit** — that clip is
  what the patient *hears*, not what is transcribed. But it is the only
  same-input comparison available, and it points the wrong way.
- **English is not fixed.** Typhoon is trained on ~11,000 hours of Thai and is
  a Thai-only fine-tune, exactly like the model it replaced. Every English
  finding in `handout.md` ("English mode is demo-quality") still holds. If
  English mode matters, this change was not the fix for it.
- **Both models are still on disk** (`models/whisper-th-ct2`, 739 MB, and
  `models/typhoon-large-v3-ct2`, 2.9 GB). Reverting is
  `MOCA_ASR_MODEL_DIR=models/whisper-th-ct2` with no rebuild; `COPY models/` in
  the Dockerfile takes both unless one is pruned first.

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
