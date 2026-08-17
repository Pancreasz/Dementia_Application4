# Voice subtests — automated verification pass (Task 20)

Date: 2026-08-17
Branch: `feat/voice-subtests`

## Scope and a correction to the brief

The Task 20 brief in `.superpowers/sdd/2026-08-17-voice-subtests/task-20-brief.md`
was written assuming a human operator at the keyboard: it asks the reader to run
`flutter run -d windows`, listen to audio, watch for a microphone indicator, and
click through subtests by hand. None of that is something this pass could do —
there is no way to hear audio, observe a UI, or judge timing "by ear" from here.

So this record does **only** what can be run and observed mechanically:
`flutter analyze`, `flutter test`, `flutter build windows`, and a static check
that every asset path the code references actually exists on disk and is
bundled by `pubspec.yaml`. Every interactive check from the brief is listed,
unperformed, in the "Still requires a human" section below. Nothing in this
document should be read as claiming those checks happened.

## Step 1: `flutter analyze`

Command:
```powershell
$env:PATH = "C:\Users\pumasin.p\dev\flutter\bin;$env:PATH"
flutter analyze
```

Result: **PASS** (no errors; pre-existing lint noise only).

29 issues reported, all in files untouched by the voice-subtests work:
`lib/pages/clock.dart`, `lib/pages/larksen.dart`,
`lib/pages/reorder_images_page.dart`, `lib/pages/roiLobJed.dart`,
`lib/pages/score.dart`, `lib/pages/select_images_page.dart`,
`lib/pages/summary.dart`, `lib/scoring/matchers.dart`, and one unused import in
`test/widget_test.dart`. All are `info`/`warning` level (unused locals,
deprecated `withOpacity`, `avoid_print`, style conventions) — none are errors,
and none are inside `lib/moca/` or any file this project added. The command
exits 1 because `flutter analyze` treats "issues found" as non-zero exit even
when every issue is a warning/info, not because anything is broken.

## Step 2: `flutter test`

Command:
```powershell
flutter test
```

Result: **PASS — 156/156 tests, "All tests passed!"**

Exact count matches the 156/156 baseline stated in the task instructions.
Coverage spans `test/moca/asr_client_test.dart`,
`test/moca/digit_sequence_player_test.dart`, `test/moca/fakes_test.dart`,
`test/moca/join_points_test.dart`, `test/moca/voice_subtest_page_test.dart`,
`test/pages/summary_test.dart`, `test/scoring/*.dart`, and `test/widget_test.dart`.

## Step 3: `flutter build windows`

Command:
```powershell
flutter build windows
```

Result: **FAILED — BLOCKED, not a code defect.**

Output:
```
Building with plugins requires symlink support.

Please enable Developer Mode in your system settings. Run
  start ms-settings:developers
to open settings.
```

Confirmed independently that Windows Developer Mode is off on this machine:
`HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock` has no
`AllowDevelopmentWithoutDevLicense` value, which is the same signal Flutter's
tooling checks. This is a machine/environment configuration gap, not a defect
in the plugin registration code — but per the task brief, this build is exactly
the check that would catch a genuinely broken `record`/`audioplayers` Windows
link (the earlier `flutter pub add` symlink error from this project's history),
and **that check did not run to completion here**. The generated Windows
plugin registrant files (`windows/flutter/generated_plugin_registrant.cc` etc.)
have not been proven to actually compile and link on this machine.

This should be treated as an open item: someone with permission to flip
Developer Mode (`start ms-settings:developers`) needs to re-run
`flutter build windows` before the Windows build target can be called verified.
No source change is implicated by this failure — it is purely an
environment/tooling precondition Flutter itself enforces for symlink-based
plugin resolution.

## Step 4: Asset existence check

The docs are not authoritative for which files must exist — the code is. Every
`assets/moca/audio/...` path was extracted from `lib/moca/subtests.dart` and
from `lib/moca/digit_sequence_player.dart`'s `_assetFor(digit)` builder
(`assets/moca/audio/digit-$digit.wav` for each distinct digit appearing in
`kVigilanceSequence`), then tested for existence on disk.

`kVigilanceSequence = '52139411806215194511141905112'` (29 characters). Its
distinct digits are `0,1,2,3,4,5,6,8,9` — note `7` does not occur in the
sequence at all, so `digit-7.wav` is not referenced by any code path (it exists
on disk anyway, unused — not a dangling reference, just extra).

Full reference list and result:

| Path referenced | Referenced from | Exists on disk |
|---|---|---|
| `assets/moca/audio/digits-forward.wav` | `subtests.dart` (`digit-span-forward`) | Yes |
| `assets/moca/audio/digits-backward.wav` | `subtests.dart` (`digit-span-backward`) | Yes |
| `assets/moca/audio/sentence-1.wav` | `subtests.dart` (`sentence-repetition-1`) | Yes |
| `assets/moca/audio/sentence-2.wav` | `subtests.dart` (`sentence-repetition-2`) | Yes |
| `assets/moca/audio/digit-0.wav` | `digit_sequence_player.dart` (`_assetFor`) | Yes |
| `assets/moca/audio/digit-1.wav` | `digit_sequence_player.dart` (`_assetFor`) | Yes |
| `assets/moca/audio/digit-2.wav` | `digit_sequence_player.dart` (`_assetFor`) | Yes |
| `assets/moca/audio/digit-3.wav` | `digit_sequence_player.dart` (`_assetFor`) | Yes |
| `assets/moca/audio/digit-4.wav` | `digit_sequence_player.dart` (`_assetFor`) | Yes |
| `assets/moca/audio/digit-5.wav` | `digit_sequence_player.dart` (`_assetFor`) | Yes |
| `assets/moca/audio/digit-6.wav` | `digit_sequence_player.dart` (`_assetFor`) | Yes |
| `assets/moca/audio/digit-8.wav` | `digit_sequence_player.dart` (`_assetFor`) | Yes |
| `assets/moca/audio/digit-9.wav` | `digit_sequence_player.dart` (`_assetFor`) | Yes |

**Result: PASS — no dangling references.** Every path the code can construct
resolves to a real file.

## Step 5: `pubspec.yaml` bundles the asset directory

`pubspec.yaml`'s `flutter.assets` list (line 89) includes:

```yaml
    - assets/moca/audio/
```

This is a directory entry, so every file placed under `assets/moca/audio/` at
build time — including all 13 files verified above — is bundled into the app.
**Result: PASS.**

---

## Still requires a human — not verified

None of the following were performed. They require a person at a keyboard with
working speakers, a microphone, and eyes on the running app. Treat every item
below as open until someone runs it and updates this document.

- **Audio actually plays on Windows.** Whether Digit Span's stimulus audio is
  audible when `เริ่ม` is pressed has not been confirmed. `flutter build
  windows` did not even complete (see Step 3), so this is doubly unverified —
  the build that would run this audio hasn't been produced yet.
- **Vigilance timing by ear.** Whether there is a clean ~1 second silence
  before the first digit, a steady one-digit-per-second cadence, and — most
  importantly — **no audible overlap between consecutive digits**, especially
  across the three consecutive target `1`s at sequence positions 18-20, has
  not been listened to. `DigitSequencePlayer`'s cutoff-on-next-digit logic is
  covered by fake-player unit tests only; those prove scheduling math, not
  that real audio hardware/`audioplayers` actually stops the prior file's tail
  in time.
- **Microphone opens only after stimulus playback finishes.** Whether the mic
  indicator on Digit Span (and the other voice subtests) visibly appears only
  once playback has completed — not during — has not been observed on a real
  device. This is the invariant `DeviceAudioPlayback.play` awaiting completion
  is supposed to guarantee; it is unit-tested against a fake, not observed
  against real playback latency.
- **Each stimulus recording actually says what its paired text claims.**
  Nobody has listened to confirm that `sentence-1.wav` speaks
  `ฉันรู้ว่าจอมเป็นคนเดียวที่มาช่วยงานวันนี้` (the `expectedSentence` for
  `sentence-repetition-1`), that `sentence-2.wav` likewise matches
  `แมวมักจะซ่อนตัวอยู่หลังเก้าอี้เมื่อมีหมาอยู่ในห้อง`, and that
  `digits-forward.wav` says "2-1-8-5-4" and `digits-backward.wav` says "7-4-2".
  No automated check can confirm this — a crossed pair between text and audio
  would score every patient against something they never heard while looking
  entirely normal in every existing test.
- **The full session runs end to end through all 17 hops**, including that
  Delayed Recall correctly advances to Orientation. This join point is
  currently proven only by a source-literal check
  (`test/moca/join_points_test.dart`'s route-string assertion), not by a
  driven UI test that actually walks the full session. Nobody has pressed
  through the app from start to summary.
- **The `/transcribe` endpoint failure path** — that it shows `ลองใหม่` and
  `ข้าม` rather than crashing, and that pressing `ข้าม` advances and produces
  a summary row reading "ข้าม" with no category assigned — has not been
  observed in a running app. This is covered by widget tests that inject a
  failing fake ASR client, but the failure path against a real (or genuinely
  absent) `/transcribe` backend has not been exercised.

## Also unverifiable until `/transcribe` exists

Per the brief, these depend on the Flask `/transcribe` endpoint the app does
not yet have deployed, so none of the following can be checked regardless of
who is at the keyboard:

- Real Thai transcription accuracy against actual speech.
- The Sentence Repetition similarity threshold's behavior against real ASR
  output (only synthetic strings have been tested).
- The Verbal Fluency segment count against real ASR `segments` output (only
  fake segment lists have been tested).

## Summary

| Check | Method | Result |
|---|---|---|
| `flutter analyze` | automated | PASS (pre-existing lint noise only) |
| `flutter test` | automated | PASS — 156/156 |
| `flutter build windows` | automated | **FAILED** — Developer Mode disabled on this machine, symlink support unavailable; build never reached compilation |
| Asset references resolve to real files | automated (code-derived) | PASS — 13/13 |
| `pubspec.yaml` bundles the asset directory | automated | PASS |
| Everything under "Still requires a human" | not performed | **UNVERIFIED** |
