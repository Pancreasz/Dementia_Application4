# Voice Subtests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add nine MoCA subtests to moca_app — eight voice-scored, one tap — taking it from 15/30 to 29/30.

**Architecture:** A pure-Dart `lib/scoring/` library of scorer functions (ported from the sibling `ad_hw` project's tested JS), consumed by a `lib/moca/` engine that owns the microphone, audio playback, and HTTP. One data-driven `VoiceSubtestPage` renders all nine subtests from a spec list. Every hardware and network dependency is injected so unit tests never open a real microphone.

**Tech Stack:** Flutter 3.29.3 / Dart 3.7.2, `record` (microphone), `audioplayers` (playback), `http` (already present). Backend ASR is a Flask `/transcribe` endpoint the user will supply.

**Spec:** `design_docs/superpowers/specs/2026-08-17-voice-subtests-design.md`

## Global Constraints

- **Flutter is not on PATH.** The SDK is at `C:\Users\pumasin.p\dev\flutter\bin`. Every command in this plan assumes you first run, in each new PowerShell session:
  `$env:PATH = "C:\Users\pumasin.p\dev\flutter\bin;$env:PATH"`
- Flutter 3.29.3, Dart 3.7.2. Platform is Windows; shell is PowerShell (`&&` is **not** valid — use `;` or `if ($?) { }`).
- **`flutter test` fails on a clean checkout** (stale `flutter create` counter test). Task 1 fixes this. Do not start Task 2 until the suite is green.
- **Existing subtests are never modified** except for their exit route string. Do not open the test logic in `larksen.dart`, `clock.dart`, `animal.dart`, `roiLobJed.dart`, `select_images_page.dart`, or `reorder_images_page.dart` for any other reason.
- **Skip is not zero.** A skipped subtest carries `maxScore: 0` and is excluded from both sides of the total. A score of 0 asserts the patient failed; skipped asserts it was never administered.
- **The microphone must never open before stimulus playback finishes.** Enforced by a call-order test in Task 16, not by care.
- **No time limits and no on-screen clock** on any subtest except Verbal Fluency, whose 60 seconds is normed against the "≥11 words" cutoff.
- **Orientation's year is Buddhist Era** (Gregorian + 543).
- **Thai has no spaces between words.** Never use `split(' ')` on Thai text. Use substring matching or character scanning.
- Thai text in this plan is test data and instruction copy — copy it verbatim, character for character. All of it was confirmed by the project owner on 2026-08-17; none of it is placeholder. Do not "improve" the wording.
- **`expectedSentence` and `stimulusAsset` must always change together**, as must Verbal Fluency's `instructionTh` and `initialLetter`. Nothing in the type system ties either pair, and a mismatch scores patients against a task they were never set while looking entirely normal.

### Deviation from the spec, decided during planning

The spec names `just_audio` for playback. This plan uses **`audioplayers`** instead: the target platform is Windows desktop, where `audioplayers` has first-party support and `just_audio` relies on a community-maintained federated package. Nothing else about the design changes — playback sits behind the `AudioPlayback` interface in Task 13 either way.

---

### Task 1: Green the test suite

`flutter test` currently fails on the counter test `flutter create` generated, which tests an app that never existed here. Every later task's "tests pass" verification is meaningless until this is gone.

**Files:**
- Modify: `test/widget_test.dart` (replace entirely)

**Interfaces:**
- Consumes: nothing
- Produces: a green `flutter test` baseline

- [ ] **Step 1: Confirm the failure is what this plan claims**

```powershell
$env:PATH = "C:\Users\pumasin.p\dev\flutter\bin;$env:PATH"
cd D:\moca_ad\Dementia_Application4
flutter test
```

Expected: FAIL — `Found 0 widgets with text "0"` in `test/widget_test.dart` line 19.

- [ ] **Step 2: Replace the stale test with one that asserts real behaviour**

Replace the entire contents of `test/widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moca_main/main.dart';

void main() {
  testWidgets('home page shows the test title and a start button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('แบบทดสอบโรคประสาทเสื่อม'), findsOneWidget);
    expect(find.text('เริ่มทำแบบทดสอบ'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the test**

```powershell
flutter test
```

Expected: PASS, `+1: All tests passed!`

- [ ] **Step 4: Commit**

```powershell
git add test/widget_test.dart
git commit -m "test: replace stale counter test with a real home page test"
```

---

### Task 2: Convert the audio assets to WAV

ad_hw's twelve audio files are **AAC in QuickTime containers named `.mp3`** (verified: `ftypqt`, 48 kHz mono). Chromium plays them because it sniffs content rather than extension; a Flutter audio plugin may not. Converting to 16 kHz mono WAV removes the risk entirely and costs nothing — the files are ~10 KB each.

There is no `ffmpeg` on this machine, but ad_hw's Python venv has PyAV 18.1.0, which bundles FFmpeg. No installation is needed.

**Files:**
- Create: `tool/convert_audio.py`
- Create: `assets/moca/audio/*.wav` (14 files, generated)
- Modify: `pubspec.yaml` (assets section)

**Interfaces:**
- Consumes: nothing
- Produces: `assets/moca/audio/digits-forward.wav`, `digits-backward.wav`, `digit-0.wav` … `digit-9.wav`, `sentence-1.wav`, `sentence-2.wav`

- [ ] **Step 1: Write the conversion script**

Create `tool/convert_audio.py`:

```python
"""Convert ad_hw's QuickTime-container audio to 16 kHz mono WAV.

The source files are named .mp3 but are AAC in a QuickTime container. Chromium
sniffs content and plays them; Flutter audio plugins are not guaranteed to.
WAV removes the question. Run with ad_hw's venv, which bundles FFmpeg via PyAV:

  D:/moca_ad/ad_hw/sidecar/.venv/Scripts/python.exe tool/convert_audio.py
"""

import pathlib
import av
from av.audio.resampler import AudioResampler

DST = pathlib.Path("assets/moca/audio")

AD_HW = pathlib.Path("D:/moca_ad/ad_hw/src/renderer/public/moca/audio")
RECORDINGS = pathlib.Path("D:/moca_ad")

# (source file, destination stem). The digit and digit-span stimuli come from
# the ad_hw project; the two sentences were recorded separately. Both sets are
# AAC in QuickTime containers named .mp3, so they convert identically.
SOURCES = (
    [(AD_HW / "digits-forward.mp3", "digits-forward"),
     (AD_HW / "digits-backward.mp3", "digits-backward")]
    + [(AD_HW / f"digit-{d}.mp3", f"digit-{d}") for d in range(10)]
    + [(RECORDINGS / "sentence1.mp3", "sentence-1"),
       (RECORDINGS / "sentence2.mp3", "sentence-2")]
)


def convert(src, stem):
    dst = DST / f"{stem}.wav"

    inp = av.open(str(src))
    stream = inp.streams.audio[0]
    duration_s = float(stream.duration * stream.time_base)

    out = av.open(str(dst), "w", format="wav")
    out_stream = out.add_stream("pcm_s16le", rate=16000, layout="mono")
    resampler = AudioResampler(format="s16", layout="mono", rate=16000)

    for frame in inp.decode(stream):
        for resampled in resampler.resample(frame):
            for packet in out_stream.encode(resampled):
                out.mux(packet)
    for packet in out_stream.encode(None):
        out.mux(packet)

    out.close()
    inp.close()
    return duration_s


def main():
    DST.mkdir(parents=True, exist_ok=True)
    for src, stem in SOURCES:
        duration = convert(src, stem)
        # Durations are printed because the digit files overrun the 1000 ms
        # vigilance slot, and Task 13's player must cut them off. Seeing the
        # real numbers keeps that from being a surprise.
        print(f"{stem:20s} {duration * 1000:7.1f} ms")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run it**

```powershell
cd D:\moca_ad\Dementia_Application4
D:/moca_ad/ad_hw/sidecar/.venv/Scripts/python.exe tool/convert_audio.py
```

Expected: fourteen lines of durations. The `digit-*` files should print between roughly 1000 and 1400 ms — all at or above the 1000 ms vigilance interval, which is exactly why Task 13 cuts the sounding digit off. `sentence-1` should print ~5030 ms and `sentence-2` ~5460 ms; a wildly different number means the wrong file was picked up.

- [ ] **Step 3: Verify the output is real WAV**

```powershell
Get-ChildItem assets\moca\audio\*.wav | Measure-Object | Select-Object Count
[System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes("assets\moca\audio\digit-1.wav")[0..3])
[System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes("assets\moca\audio\sentence-1.wav")[0..3])
```

Expected: `Count: 14`, and `RIFF` twice.

- [ ] **Step 4: Register the assets**

In `pubspec.yaml`, add to the existing `assets:` list, after `- assets/larksen_tutorial.gif`:

```yaml
    - assets/moca/audio/
```

- [ ] **Step 5: Add the runtime packages**

```powershell
flutter pub add record audioplayers
```

This resolves versions against Dart 3.7.2 rather than pinning ones this plan guessed. Expected: `pubspec.yaml` gains both under `dependencies:`.

- [ ] **Step 6: Verify nothing broke**

```powershell
flutter pub get
flutter test
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add tool/convert_audio.py assets/moca/audio pubspec.yaml pubspec.lock
git commit -m "feat: convert MoCA audio to WAV, add record and audioplayers"
```

---

### Task 3: Text matchers

The foundation every voice scorer sits on. Ported from `ad_hw/src/main/scoring/matchers.js`.

`extractNumberSequence` is deliberately **not** ported: its only consumer in ad_hw is Serial 7s, which moca_app already implements as a typed test. Porting it would be dead code.

**Files:**
- Create: `lib/scoring/matchers.dart`
- Test: `test/scoring/matchers_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `String normalizeText(String text)`
  - `bool keywordMatch(String transcript, List<String> acceptedKeywords)`
  - `String extractDigitSequence(String transcript)`

- [ ] **Step 1: Write the failing tests**

Create `test/scoring/matchers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/matchers.dart';

void main() {
  group('normalizeText', () {
    test('trims, lowercases, and collapses whitespace', () {
      expect(normalizeText('  Hello   World  '), 'hello world');
    });
  });

  group('keywordMatch', () {
    test('matches if any accepted keyword appears in the transcript', () {
      expect(keywordMatch('I saw a สิงโต today', ['สิงโต', 'lion']), isTrue);
    });

    test('returns false if no accepted keyword appears', () {
      expect(keywordMatch('I saw a cat', ['สิงโต', 'lion']), isFalse);
    });
  });

  group('extractDigitSequence', () {
    test('extracts numeric digits spoken as numerals', () {
      expect(extractDigitSequence('2 1 8 5 4'), '21854');
    });

    test('extracts digits spoken as Thai number words', () {
      expect(extractDigitSequence('สอง หนึ่ง แปด ห้า สี่'), '21854');
    });

    test('handles a mix of numerals and Thai words', () {
      expect(extractDigitSequence('2 หนึ่ง 8 ห้า 4'), '21854');
    });

    // Thai does not put spaces between words, so whether the recognizer returns
    // "สอง สี่ เจ็ด" or "สองสี่เจ็ด" for the same utterance is arbitrary.
    // Splitting on whitespace scored the second form as nothing at all.
    test('extracts digits from Thai number words with no spaces', () {
      expect(extractDigitSequence('สองสี่เจ็ด'), '247');
    });

    test('extracts a longer run-on sequence', () {
      expect(extractDigitSequence('สองหนึ่งแปดห้าสี่'), '21854');
    });

    test('handles a mix of spaced and run-on words', () {
      expect(extractDigitSequence('สอง สี่เจ็ด'), '247');
    });

    test('reads Thai numerals', () {
      expect(extractDigitSequence('๒๔๗'), '247');
      expect(extractDigitSequence('๒ ๑ ๘ ๕ ๔'), '21854');
    });

    test('mixes Thai numerals, Arabic numerals and words', () {
      expect(extractDigitSequence('๒ 4 เจ็ด'), '247');
    });

    test('ignores a trailing politeness particle', () {
      expect(extractDigitSequence('สองสี่เจ็ดครับ'), '247');
    });

    test('covers every digit word run together', () {
      expect(extractDigitSequence('ศูนย์หนึ่งสองสามสี่ห้าหกเจ็ดแปดเก้า'),
          '0123456789');
    });

    test('still returns nothing for speech containing no digits', () {
      expect(extractDigitSequence('ไม่ทราบ'), '');
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/scoring/matchers_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:moca_main/scoring/matchers.dart'`.

- [ ] **Step 3: Implement**

Create `lib/scoring/matchers.dart`:

```dart
/// Text matching shared by every voice scorer.
///
/// Ported from ad_hw/src/main/scoring/matchers.js.

String normalizeText(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

bool keywordMatch(String transcript, List<String> acceptedKeywords) {
  final normalized = normalizeText(transcript);
  return acceptedKeywords.any((k) => normalized.contains(normalizeText(k)));
}

const _thaiDigitWords = <String, String>{
  'ศูนย์': '0',
  'หนึ่ง': '1',
  'สอง': '2',
  'สาม': '3',
  'สี่': '4',
  'ห้า': '5',
  'หก': '6',
  'เจ็ด': '7',
  'แปด': '8',
  'เก้า': '9',
};

/// Longest first, so a shorter word can never shadow a longer one that starts
/// with the same characters.
final List<MapEntry<String, String>> _thaiDigitEntries =
    _thaiDigitWords.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

/// Thai numerals ๐-๙, in value order.
const _thaiNumerals = '๐๑๒๓๔๕๖๗๘๙';

/// Scans the transcript character by character rather than splitting on
/// whitespace. Thai does not space between words, so whether the recognizer
/// returns "สอง สี่ เจ็ด" or "สองสี่เจ็ด" for the same utterance is arbitrary
/// — and the whitespace-splitting version scored the run-on form as no digits
/// at all, silently marking a correct answer wrong. Scanning handles spaced,
/// run-on and mixed forms identically, plus Thai and Arabic numerals.
String extractDigitSequence(String transcript) {
  final normalized = normalizeText(transcript);
  final digits = StringBuffer();

  var i = 0;
  while (i < normalized.length) {
    final char = normalized[i];

    if (char.compareTo('0') >= 0 && char.compareTo('9') <= 0) {
      digits.write(char);
      i += 1;
      continue;
    }

    final numeral = _thaiNumerals.indexOf(char);
    if (numeral != -1) {
      digits.write(numeral.toString());
      i += 1;
      continue;
    }

    MapEntry<String, String>? word;
    for (final entry in _thaiDigitEntries) {
      if (normalized.startsWith(entry.key, i)) {
        word = entry;
        break;
      }
    }
    if (word != null) {
      digits.write(word.value);
      i += word.key.length;
      continue;
    }

    i += 1;
  }

  return digits.toString();
}
```

- [ ] **Step 4: Run to verify it passes**

```powershell
flutter test test/scoring/matchers_test.dart
```

Expected: PASS, 12 tests.

- [ ] **Step 5: Commit**

```powershell
git add lib/scoring/matchers.dart test/scoring/matchers_test.dart
git commit -m "feat: add Thai-aware text matchers for voice scoring"
```

---

### Task 4: The outcome type

The single result shape every scorer returns and the summary screen reads.

**Files:**
- Create: `lib/scoring/subtest_outcome.dart`
- Test: `test/scoring/subtest_outcome_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `class SubtestOutcome` with fields `subtestId` (String), `score` (int), `maxScore` (int), `skipped` (bool), `transcript` (String), `detail` (Map<String, dynamic>)
  - `SubtestOutcome.skippedFor(String subtestId)` named constructor

- [ ] **Step 1: Write the failing test**

Create `test/scoring/subtest_outcome_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/subtest_outcome.dart';

void main() {
  test('an administered outcome carries its score and max', () {
    const outcome = SubtestOutcome(
      subtestId: 'digit-span-forward',
      score: 1,
      maxScore: 1,
      transcript: 'สองหนึ่งแปดห้าสี่',
    );

    expect(outcome.score, 1);
    expect(outcome.maxScore, 1);
    expect(outcome.skipped, isFalse);
  });

  // A skipped subtest was never administered, so it scores nothing rather than
  // scoring 0 — 0 would assert the patient failed. maxScore 0 keeps it out of
  // both sides of the total.
  test('a skipped outcome scores nothing out of nothing', () {
    final outcome = SubtestOutcome.skippedFor('orientation');

    expect(outcome.skipped, isTrue);
    expect(outcome.score, 0);
    expect(outcome.maxScore, 0);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/scoring/subtest_outcome_test.dart
```

Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implement**

Create `lib/scoring/subtest_outcome.dart`:

```dart
/// The result of one administered (or skipped) subtest.
class SubtestOutcome {
  final String subtestId;
  final int score;
  final int maxScore;
  final bool skipped;
  final String transcript;

  /// Scorer-specific extras kept for human review — matched terms, per-item
  /// correctness, tap latencies. Nothing computes on these; they exist so a
  /// surprising score can be explained after the fact.
  final Map<String, dynamic> detail;

  const SubtestOutcome({
    required this.subtestId,
    required this.score,
    required this.maxScore,
    this.skipped = false,
    this.transcript = '',
    this.detail = const {},
  });

  /// A subtest that was never administered. Deliberately maxScore 0: it is
  /// excluded from both sides of the total rather than counted as a failure.
  factory SubtestOutcome.skippedFor(String subtestId) => SubtestOutcome(
        subtestId: subtestId,
        score: 0,
        maxScore: 0,
        skipped: true,
      );
}
```

- [ ] **Step 4: Run to verify it passes**

```powershell
flutter test test/scoring/subtest_outcome_test.dart
```

Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```powershell
git add lib/scoring/subtest_outcome.dart test/scoring/subtest_outcome_test.dart
git commit -m "feat: add SubtestOutcome with skipped-is-not-zero semantics"
```

---

### Task 5: Digit Span scorer

**Files:**
- Create: `lib/scoring/digit_span.dart`
- Test: `test/scoring/digit_span_test.dart`

**Interfaces:**
- Consumes: `extractDigitSequence` (Task 3), `SubtestOutcome` (Task 4)
- Produces: `SubtestOutcome scoreDigitSpan(String subtestId, String transcript, String expectedSequence)`

- [ ] **Step 1: Write the failing test**

Create `test/scoring/digit_span_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/digit_span.dart';

void main() {
  group('scoreDigitSpan forward', () {
    test('scores 1 for the exact sequence', () {
      final outcome =
          scoreDigitSpan('digit-span-forward', 'สองหนึ่งแปดห้าสี่', '21854');
      expect(outcome.score, 1);
      expect(outcome.maxScore, 1);
    });

    test('scores 0 for a wrong digit', () {
      final outcome =
          scoreDigitSpan('digit-span-forward', 'สองหนึ่งแปดห้าห้า', '21854');
      expect(outcome.score, 0);
    });

    test('scores 0 for silence', () {
      final outcome = scoreDigitSpan('digit-span-forward', '', '21854');
      expect(outcome.score, 0);
    });
  });

  group('scoreDigitSpan backward', () {
    // The patient hears 742 and must say it reversed.
    test('scores 1 for the reversed sequence', () {
      final outcome =
          scoreDigitSpan('digit-span-backward', 'สองสี่เจ็ด', '247');
      expect(outcome.score, 1);
    });

    test('scores 0 when the patient repeats it forward instead', () {
      final outcome =
          scoreDigitSpan('digit-span-backward', 'เจ็ดสี่สอง', '247');
      expect(outcome.score, 0);
    });
  });

  test('records what was heard and what was expected, for review', () {
    final outcome =
        scoreDigitSpan('digit-span-forward', 'สองหนึ่งแปด', '21854');
    expect(outcome.detail['spoken'], '218');
    expect(outcome.detail['expected'], '21854');
    expect(outcome.transcript, 'สองหนึ่งแปด');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/scoring/digit_span_test.dart
```

Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implement**

Create `lib/scoring/digit_span.dart`:

```dart
import 'matchers.dart';
import 'subtest_outcome.dart';

/// One point for repeating the sequence exactly. No partial credit — MoCA
/// scores the item, not the digits.
SubtestOutcome scoreDigitSpan(
  String subtestId,
  String transcript,
  String expectedSequence,
) {
  final spoken = extractDigitSequence(transcript);
  final correct = spoken == expectedSequence;

  return SubtestOutcome(
    subtestId: subtestId,
    score: correct ? 1 : 0,
    maxScore: 1,
    transcript: transcript,
    detail: {'spoken': spoken, 'expected': expectedSequence},
  );
}
```

- [ ] **Step 4: Run to verify it passes**

```powershell
flutter test test/scoring/digit_span_test.dart
```

Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```powershell
git add lib/scoring/digit_span.dart test/scoring/digit_span_test.dart
git commit -m "feat: add Digit Span scorer"
```

---

### Task 6: Abstraction scorer

**Files:**
- Create: `lib/scoring/abstraction.dart`
- Test: `test/scoring/abstraction_test.dart`

**Interfaces:**
- Consumes: `keywordMatch` (Task 3), `SubtestOutcome` (Task 4)
- Produces: `SubtestOutcome scoreAbstraction(String subtestId, String transcript)` — throws `ArgumentError` for an unregistered item id

- [ ] **Step 1: Write the failing test**

Create `test/scoring/abstraction_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/abstraction.dart';
import 'package:moca_main/scoring/subtest_outcome.dart';

void main() {
  group('scoreAbstraction for รถไฟ–จักรยาน', () {
    SubtestOutcome score(String t) => scoreAbstraction('abstraction-1', t);

    test('accepts the category itself', () {
      expect(score('ยานพาหนะ').score, 1);
    });

    test('accepts the shortened form a patient is likelier to say', () {
      expect(score('เป็นพาหนะ').score, 1);
    });

    test('accepts a travel answer, which the instrument allows', () {
      expect(score('ใช้เดินทาง').score, 1);
    });

    // MoCA scores the abstract category, not a shared physical feature.
    test('rejects the concrete answer about wheels', () {
      expect(score('มีล้อเหมือนกัน').score, 0);
    });

    // The reason this scorer has no reject-list: a correct abstract answer is
    // allowed to mention a concrete detail too, and stripping the point for it
    // would take away something the patient earned. Do not "harden" this.
    test('accepts an abstract answer that also mentions a concrete detail', () {
      expect(score('เป็นพาหนะที่มีล้อ').score, 1);
    });

    test('scores nothing when the patient only repeats the two items back', () {
      expect(score('รถไฟกับจักรยาน').score, 0);
    });

    test('scores nothing for no answer', () {
      expect(score('').score, 0);
    });
  });

  group('scoreAbstraction for นาฬิกา–ไม้บรรทัด', () {
    SubtestOutcome score(String t) => scoreAbstraction('abstraction-2', t);

    test('accepts the category itself', () {
      expect(score('เครื่องมือวัด').score, 1);
    });

    test('accepts a bare verb answer', () {
      expect(score('ใช้วัด').score, 1);
    });

    test('rejects the concrete answer about numbers', () {
      expect(score('มีตัวเลขเหมือนกัน').score, 0);
    });

    // ไม้บรรทัด ends in ทัด, not วัด. If it did contain the accepted keyword,
    // a patient parroting the question would score a point for saying nothing.
    test('scores nothing when the patient only repeats the two items back', () {
      expect(score('นาฬิกากับไม้บรรทัด').score, 0);
    });
  });

  group('scoreAbstraction across both items', () {
    test('matches a run-on transcript with no spaces', () {
      expect(scoreAbstraction('abstraction-1', 'ทั้งสองอย่างเป็นยานพาหนะครับ').score, 1);
    });

    test('reports which accepted term matched, for checking real speech', () {
      expect(scoreAbstraction('abstraction-1', 'ยานพาหนะ').detail['matched'],
          'ยานพาหนะ');
    });

    test('reports no match when nothing was accepted', () {
      expect(scoreAbstraction('abstraction-1', 'มีล้อ').detail['matched'], isNull);
    });

    // A typo in a subtest id must not silently score every patient zero on an
    // item that was never really administered, and look like a clinical finding.
    test('throws on an unknown item rather than scoring it wrong', () {
      expect(() => scoreAbstraction('abstraction-9', 'ยานพาหนะ'),
          throwsA(isA<ArgumentError>()));
    });

    test('does not let one item answer score the other', () {
      expect(scoreAbstraction('abstraction-1', 'เครื่องมือวัด').score, 0);
      expect(scoreAbstraction('abstraction-2', 'ยานพาหนะ').score, 0);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/scoring/abstraction_test.dart
```

Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implement**

Create `lib/scoring/abstraction.dart`:

```dart
import 'matchers.dart';
import 'subtest_outcome.dart';

/// One point per pair for naming what the two things have in common, where the
/// similarity has to be an abstract category rather than a shared physical
/// feature: "vehicles" scores, "they both have wheels" does not.
///
/// There is deliberately no reject-list for the concrete answers. It sounds
/// safer than it is — "เป็นพาหนะที่มีล้อ" (vehicles that have wheels) is a
/// correct abstract answer carrying a concrete detail, and a reject-list would
/// strip a point the patient earned. The accepted terms cannot make that
/// mistake, because the answers MoCA rejects share no vocabulary with them.
const _acceptedTerms = <String, List<String>>{
  // รถไฟ (train) and จักรยาน (bicycle). The instrument allows a travel answer
  // as well as the category noun, so "ใช้เดินทาง" scores.
  'abstraction-1': ['ยานพาหนะ', 'พาหนะ', 'ขนส่ง', 'เดินทาง'],
  // นาฬิกา (watch) and ไม้บรรทัด (ruler). วัด is the bare verb "to measure"
  // and is the root of every longer accepted form. Substring matching on it is
  // safe here: ไม้บรรทัด ends in ทัด, not วัด, so a patient who only repeats
  // the question back matches nothing.
  'abstraction-2': ['เครื่องมือวัด', 'เครื่องวัด', 'การวัด', 'วัด'],
};

SubtestOutcome scoreAbstraction(String subtestId, String transcript) {
  final terms = _acceptedTerms[subtestId];
  // A typo in a subtest id would otherwise score every patient zero on an item
  // that was never really administered, and look like a clinical finding.
  if (terms == null) {
    throw ArgumentError('No accepted terms registered for abstraction item "$subtestId"');
  }

  String? matched;
  for (final term in terms) {
    if (keywordMatch(transcript, [term])) {
      matched = term;
      break;
    }
  }

  return SubtestOutcome(
    subtestId: subtestId,
    score: matched != null ? 1 : 0,
    maxScore: 1,
    transcript: transcript,
    detail: {'matched': matched},
  );
}
```

- [ ] **Step 4: Run to verify it passes**

```powershell
flutter test test/scoring/abstraction_test.dart
```

Expected: PASS, 16 tests.

- [ ] **Step 5: Commit**

```powershell
git add lib/scoring/abstraction.dart test/scoring/abstraction_test.dart
git commit -m "feat: add Abstraction scorer with accept-list only"
```

---

### Task 7: Orientation scorer

**Files:**
- Create: `lib/scoring/orientation.dart`
- Create: `lib/moca/session_config.dart`
- Test: `test/scoring/orientation_test.dart`

**Interfaces:**
- Consumes: `keywordMatch` (Task 3), `SubtestOutcome` (Task 4)
- Produces:
  - `SubtestOutcome scoreOrientation(String transcript, {required DateTime referenceDate, required String place, required String province})`
  - `class SessionConfig` with `static const String place`, `static const String province`

- [ ] **Step 1: Write the failing test**

Create `test/scoring/orientation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/orientation.dart';
import 'package:moca_main/scoring/subtest_outcome.dart';

void main() {
  // August 13, 2026 — a Thursday.
  final referenceDate = DateTime(2026, 8, 13);
  const place = 'โรงพยาบาลศิริราช';
  const province = 'กรุงเทพ';

  SubtestOutcome score(String transcript) => scoreOrientation(
        transcript,
        referenceDate: referenceDate,
        place: place,
        province: province,
      );

  test('awards full 6/6 when all six items are stated correctly', () {
    final outcome = score(
        'วันนี้วันพฤหัสบดี เดือนสิงหาคม ปี 2569 วันที่ 13 อยู่ที่โรงพยาบาลศิริราช จังหวัดกรุงเทพ');
    expect(outcome.score, 6);
    expect(outcome.maxScore, 6);
  });

  test('awards partial credit for a partially correct answer', () {
    final outcome = score('วันนี้วันพฤหัสบดี เดือนสิงหาคม');
    expect(outcome.score, 2);
    expect(outcome.detail['day'], isTrue);
    expect(outcome.detail['month'], isTrue);
    expect(outcome.detail['year'], isFalse);
  });

  // Thai MoCA forms use the Buddhist Era, not the Gregorian year.
  test('expects the Buddhist Era year (CE + 543)', () {
    final outcome = score('ปี 2569');
    expect(outcome.detail['year'], isTrue);
  });

  test('rejects the Gregorian year', () {
    final outcome = score('ปี 2026');
    expect(outcome.detail['year'], isFalse);
  });

  test('awards 0/6 for an unrelated answer', () {
    expect(score('ไม่ทราบ').score, 0);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/scoring/orientation_test.dart
```

Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implement the session config**

Create `lib/moca/session_config.dart`:

```dart
/// Where the session is being administered. Orientation scores two of its six
/// points against these, so they are session context rather than test content.
///
/// TODO: replace with a settings screen the operator fills in before a session.
/// Until then these are the defaults, and an Orientation score is only
/// meaningful if they match where the patient actually is.
class SessionConfig {
  static const String place = 'โรงพยาบาลศิริราช';
  static const String province = 'กรุงเทพ';
}
```

- [ ] **Step 4: Implement the scorer**

Create `lib/scoring/orientation.dart`:

```dart
import 'matchers.dart';
import 'subtest_outcome.dart';

const _thaiMonths = [
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

const _thaiDays = [
  'วันจันทร์',
  'วันอังคาร',
  'วันพุธ',
  'วันพฤหัสบดี',
  'วันศุกร์',
  'วันเสาร์',
  'วันอาทิตย์',
];

/// Six independent items, one point each. Note the year is Buddhist Era
/// (Gregorian + 543), as Thai MoCA forms use.
SubtestOutcome scoreOrientation(
  String transcript, {
  required DateTime referenceDate,
  required String place,
  required String province,
}) {
  // Dart's DateTime.weekday is 1 = Monday … 7 = Sunday, which is why _thaiDays
  // starts at Monday rather than Sunday.
  final items = <String, String>{
    'day': _thaiDays[referenceDate.weekday - 1],
    'month': _thaiMonths[referenceDate.month - 1],
    'year': (referenceDate.year + 543).toString(),
    'date': referenceDate.day.toString(),
    'place': place,
    'province': province,
  };

  final detail = <String, dynamic>{};
  var score = 0;
  items.forEach((key, expected) {
    final correct = keywordMatch(transcript, [expected]);
    detail[key] = correct;
    if (correct) score += 1;
  });

  return SubtestOutcome(
    subtestId: 'orientation',
    score: score,
    maxScore: 6,
    transcript: transcript,
    detail: detail,
  );
}
```

- [ ] **Step 5: Run to verify it passes**

```powershell
flutter test test/scoring/orientation_test.dart
```

Expected: PASS, 5 tests.

- [ ] **Step 6: Commit**

```powershell
git add lib/scoring/orientation.dart lib/moca/session_config.dart test/scoring/orientation_test.dart
git commit -m "feat: add Orientation scorer with Buddhist Era year"
```

---

### Task 8: Vigilance scorer

The scorer is a direct port; the risk in this subtest lives entirely in playback (Task 14).

**Files:**
- Create: `lib/scoring/vigilance.dart`
- Test: `test/scoring/vigilance_test.dart`

**Interfaces:**
- Consumes: `SubtestOutcome` (Task 4)
- Produces: `SubtestOutcome scoreVigilance(List<int> taps, {required String sequence, required String target, required int intervalMs})` — `taps` are millisecond offsets from the first digit's onset

- [ ] **Step 1: Write the failing test**

Create `test/scoring/vigilance_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/subtest_outcome.dart';
import 'package:moca_main/scoring/vigilance.dart';

void main() {
  // A short stand-in sequence keeps the arithmetic checkable by eye. The real
  // 29-digit sequence is exercised through the spec test in Task 15.
  //   index: 0    1    2    3    4
  //          5    1    3    1    9
  const sequence = '51319';

  SubtestOutcome score(List<int> taps) => scoreVigilance(
        taps,
        sequence: sequence,
        target: '1',
        intervalMs: 1000,
      );

  // Mid-window, so a tap is unambiguous about which digit it belongs to.
  int inWindow(int index) => index * 1000 + 500;

  test('scores 1 when every target is tapped and nothing else is', () {
    final r = score([inWindow(1), inWindow(3)]);
    expect(r.score, 1);
    expect(r.maxScore, 1);
    expect(r.detail['hits'], 2);
    expect(r.detail['misses'], 0);
    expect(r.detail['falseTaps'], 0);
  });

  test('still scores 1 with a single missed target — the rule allows one error', () {
    final r = score([inWindow(1)]);
    expect(r.score, 1);
    expect(r.detail['misses'], 1);
    expect(r.detail['errors'], 1);
  });

  test('scores 0 once there are two errors', () {
    final r = score([]);
    expect(r.score, 0);
    expect(r.detail['misses'], 2);
    expect(r.detail['errors'], 2);
  });

  test('counts a tap on a non-target digit as a false tap', () {
    final r = score([inWindow(1), inWindow(3), inWindow(4)]);
    expect(r.score, 1);
    expect(r.detail['hits'], 2);
    expect(r.detail['falseTaps'], 1);
  });

  test('scores 0 for one miss plus one false tap', () {
    final r = score([inWindow(1), inWindow(0)]);
    expect(r.score, 0);
    expect(r.detail['errors'], 2);
  });

  // The instrument counts errors per digit, not per hand movement: a patient
  // who double-taps one target has made one mistake about one digit.
  test('counts two taps inside one window as a single event', () {
    final r = score([inWindow(1), inWindow(1) + 100, inWindow(3)]);
    expect(r.score, 1);
    expect(r.detail['hits'], 2);
    expect(r.detail['errors'], 0);
  });

  // The deliberate cost of strict windows, locked in so it can never change
  // silently: a reaction slower than the interval is charged twice.
  test('charges a late tap as both a miss and a false tap', () {
    final r = score([1000 + 1100]);
    expect(r.score, 0);
    expect(r.detail['misses'], 2);
    expect(r.detail['falseTaps'], 1);
    expect(r.detail['errors'], 3);
  });

  test('ignores taps before the first digit or after the last window', () {
    final r = score([-200, inWindow(1), inWindow(3), 5 * 1000 + 10]);
    expect(r.score, 1);
    expect(r.detail['hits'], 2);
    expect(r.detail['falseTaps'], 0);
  });

  test('measures each latency from its own target onset', () {
    final r = score([1000 + 420, 3000 + 610]);
    expect(r.detail['tapLatencies'], [420, 610]);
  });

  test('reports latency for the first tap in a window when there are several', () {
    final r = score([1000 + 300, 1000 + 800, 3000 + 500]);
    expect(r.detail['tapLatencies'], [300, 500]);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/scoring/vigilance_test.dart
```

Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implement**

Create `lib/scoring/vigilance.dart`:

```dart
import 'subtest_outcome.dart';

/// MoCA gives the point for zero or one errors. There is no partial credit —
/// the item is worth 1 and scores 1 or 0.
const _maxErrorsForPoint = 1;

/// [taps] are millisecond offsets measured from the FIRST DIGIT'S onset, not
/// from when playback was requested — the lead-in silence sits in between and
/// a tap during it is not an answer to any digit.
SubtestOutcome scoreVigilance(
  List<int> taps, {
  required String sequence,
  required String target,
  required int intervalMs,
}) {
  final digits = sequence.split('');

  // A tap belongs to the digit whose window it lands in: digit i owns
  // [i * intervalMs, (i + 1) * intervalMs). Taps outside the sequence are
  // dropped rather than charged — the tap control is inert then, so any that
  // arrive are an artefact, not a patient error.
  final firstTapByWindow = <int, int>{};
  for (final tap in taps) {
    if (tap < 0) continue;
    final index = tap ~/ intervalMs;
    if (index >= digits.length) continue;
    // First tap only. A second tap in the same window is the same mistake
    // about the same digit, and the first one is the reaction time.
    firstTapByWindow.putIfAbsent(index, () => tap);
  }

  var hits = 0;
  var misses = 0;
  var falseTaps = 0;
  final tapLatencies = <int>[];

  for (var index = 0; index < digits.length; index++) {
    final tap = firstTapByWindow[index];
    if (digits[index] == target) {
      if (tap == null) {
        misses += 1;
      } else {
        hits += 1;
        // Measured from this target's own onset, so the value is a reaction
        // time rather than a position in the sequence.
        tapLatencies.add(tap - index * intervalMs);
      }
    } else if (tap != null) {
      falseTaps += 1;
    }
  }

  final errors = misses + falseTaps;

  return SubtestOutcome(
    subtestId: 'vigilance',
    score: errors <= _maxErrorsForPoint ? 1 : 0,
    maxScore: 1,
    detail: {
      'errors': errors,
      'hits': hits,
      'misses': misses,
      'falseTaps': falseTaps,
      'tapLatencies': tapLatencies,
    },
  );
}
```

- [ ] **Step 4: Run to verify it passes**

```powershell
flutter test test/scoring/vigilance_test.dart
```

Expected: PASS, 10 tests.

- [ ] **Step 5: Commit**

```powershell
git add lib/scoring/vigilance.dart test/scoring/vigilance_test.dart
git commit -m "feat: add Vigilance window scorer"
```

---

### Task 9: Sentence Repetition scorer

MoCA scores this strictly verbatim: any omission or substitution scores 0. Applied to speech-recognizer output, strict matching fails correct patients on recognizer error rather than on memory, so this uses a normalized character-similarity threshold instead. The threshold is a judgement call and is unvalidated until a real-speech pass has been run.

**Files:**
- Create: `lib/scoring/sentence_repetition.dart`
- Test: `test/scoring/sentence_repetition_test.dart`

**Interfaces:**
- Consumes: `normalizeText` (Task 3), `SubtestOutcome` (Task 4)
- Produces:
  - `SubtestOutcome scoreSentenceRepetition(String subtestId, String transcript, String expectedSentence)`
  - `double similarityRatio(String a, String b)` — 0.0 to 1.0

- [ ] **Step 1: Write the failing test**

Create `test/scoring/sentence_repetition_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/sentence_repetition.dart';

void main() {
  // The real sentence 1, so these tests exercise the length and character mix
  // the scorer actually sees. Thai has no word spaces, which is why the
  // similarity is measured per character rather than per word.
  const sentence = 'ฉันรู้ว่าจอมเป็นคนเดียวที่มาช่วยงานวันนี้';

  group('similarityRatio', () {
    test('is 1.0 for identical strings', () {
      expect(similarityRatio('abc', 'abc'), 1.0);
    });

    test('is 0.0 for a completely different string of the same length', () {
      expect(similarityRatio('abc', 'xyz'), 0.0);
    });

    test('is 1.0 for two empty strings', () {
      expect(similarityRatio('', ''), 1.0);
    });

    test('falls between 0 and 1 for a near match', () {
      final ratio = similarityRatio('abcdefghij', 'abcdefghix');
      expect(ratio, greaterThan(0.8));
      expect(ratio, lessThan(1.0));
    });
  });

  group('scoreSentenceRepetition', () {
    test('scores 1 for a verbatim repetition', () {
      final outcome =
          scoreSentenceRepetition('sentence-repetition-1', sentence, sentence);
      expect(outcome.score, 1);
      expect(outcome.maxScore, 1);
    });

    test('scores 1 despite a single-character recognizer slip', () {
      // One substituted character out of ~40 is recognizer noise, not a
      // patient error, and strict matching would fail a correct answer.
      // ฉ -> ช is a real substitution: the two are visually and acoustically
      // close, which is exactly the confusion a recognizer makes.
      final heard = sentence.replaceRange(0, 1, 'ช');
      expect(heard, isNot(sentence), reason: 'the slip must actually differ');

      final outcome =
          scoreSentenceRepetition('sentence-repetition-1', heard, sentence);
      expect(outcome.score, 1);
    });

    test('scores 0 when a substantial part is missing', () {
      final heard = sentence.substring(0, sentence.length ~/ 2);
      final outcome =
          scoreSentenceRepetition('sentence-repetition-1', heard, sentence);
      expect(outcome.score, 0);
    });

    test('scores 0 for silence', () {
      final outcome =
          scoreSentenceRepetition('sentence-repetition-1', '', sentence);
      expect(outcome.score, 0);
    });

    test('records the similarity it measured, for review', () {
      final outcome =
          scoreSentenceRepetition('sentence-repetition-1', sentence, sentence);
      expect(outcome.detail['similarity'], 1.0);
      expect(outcome.detail['expected'], sentence);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/scoring/sentence_repetition_test.dart
```

Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implement**

Create `lib/scoring/sentence_repetition.dart`:

```dart
import 'dart:math';

import 'matchers.dart';
import 'subtest_outcome.dart';

/// MoCA scores repetition verbatim: any omission or substitution is 0. Against
/// speech-recognizer output, strict equality fails correct patients on
/// recognizer error rather than on memory, so a near-match is accepted.
///
/// 0.9 is a judgement call, not a validated figure. It tolerates roughly one
/// wrong character in ten. Revisit it once real Thai speech has been run
/// through the endpoint — until then, treat this point as provisional.
const _acceptThreshold = 0.9;

/// Levenshtein distance, normalized to a 0..1 similarity.
///
/// Character-level rather than word-level on purpose: Thai does not space
/// between words, so word tokenization is not available here.
double similarityRatio(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1.0;

  final distance = _levenshtein(a, b);
  final longest = max(a.length, b.length);
  return 1.0 - (distance / longest);
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  // Two rows rather than a full matrix: the sentences are short, but there is
  // no reason to allocate length*length when length*2 does.
  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);

  for (var i = 0; i < a.length; i++) {
    current[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final substitution = previous[j] + (a[i] == b[j] ? 0 : 1);
      final insertion = current[j] + 1;
      final deletion = previous[j + 1] + 1;
      current[j + 1] = min(substitution, min(insertion, deletion));
    }
    final swap = previous;
    previous = current;
    current = swap;
  }

  return previous[b.length];
}

SubtestOutcome scoreSentenceRepetition(
  String subtestId,
  String transcript,
  String expectedSentence,
) {
  final similarity =
      similarityRatio(normalizeText(transcript), normalizeText(expectedSentence));

  return SubtestOutcome(
    subtestId: subtestId,
    score: similarity >= _acceptThreshold ? 1 : 0,
    maxScore: 1,
    transcript: transcript,
    detail: {'similarity': similarity, 'expected': expectedSentence},
  );
}
```

- [ ] **Step 4: Run to verify it passes**

```powershell
flutter test test/scoring/sentence_repetition_test.dart
```

Expected: PASS, 9 tests.

- [ ] **Step 5: Commit**

```powershell
git add lib/scoring/sentence_repetition.dart test/scoring/sentence_repetition_test.dart
git commit -m "feat: add Sentence Repetition scorer with similarity threshold"
```

---

### Task 10: Verbal Fluency scorer

The least trustworthy point of the fourteen. Counting distinct Thai words from a 60-second transcript cannot use spacing — the recognizer's Thai spacing is arbitrary, the same fact that broke Digit Span. This scorer therefore ignores orthography entirely and counts distinct **segments**, keying off the patient's own pauses.

**Files:**
- Create: `lib/scoring/asr_segment.dart`
- Create: `lib/scoring/verbal_fluency.dart`
- Test: `test/scoring/verbal_fluency_test.dart`

**Interfaces:**
- Consumes: `normalizeText` (Task 3), `SubtestOutcome` (Task 4)
- Produces:
  - `class AsrSegment { final double start; final double end; final String text; const AsrSegment({required this.start, required this.end, required this.text}); }` — in its own file, with no imports, because both `lib/scoring/` and `lib/moca/` need it and neither should import the other for a data class
  - `SubtestOutcome scoreVerbalFluency(List<AsrSegment> segments, {String? initialLetter})`
  - `const int kFluencyWordThreshold = 11`

- [ ] **Step 1: Write the failing test**

Create `test/scoring/verbal_fluency_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/asr_segment.dart';
import 'package:moca_main/scoring/verbal_fluency.dart';

void main() {
  List<AsrSegment> segments(List<String> words) => [
        for (var i = 0; i < words.length; i++)
          AsrSegment(start: i * 2.0, end: i * 2.0 + 1.0, text: words[i]),
      ];

  test('scores 1 at the 11-word cutoff', () {
    final words = List.generate(11, (i) => 'คำ$i');
    expect(scoreVerbalFluency(segments(words)).score, 1);
  });

  test('scores 0 just below the cutoff', () {
    final words = List.generate(10, (i) => 'คำ$i');
    expect(scoreVerbalFluency(segments(words)).score, 0);
  });

  test('counts a repeated word only once', () {
    final words = List.generate(11, (i) => 'คำ$i') + ['คำ0', 'คำ1'];
    final outcome = scoreVerbalFluency(segments(words));
    expect(outcome.detail['distinctCount'], 11);
  });

  test('ignores empty and whitespace-only segments', () {
    final words = List.generate(11, (i) => 'คำ$i') + ['', '   '];
    expect(scoreVerbalFluency(segments(words)).detail['distinctCount'], 11);
  });

  test('treats segments differing only in case or padding as one word', () {
    final outcome = scoreVerbalFluency(segments(['Cat', ' cat ', 'CAT']));
    expect(outcome.detail['distinctCount'], 1);
  });

  group('with a letter prompt', () {
    test('counts only words starting with the prompt letter', () {
      final outcome = scoreVerbalFluency(
        segments(['กา', 'กิน', 'ขาย', 'กบ']),
        initialLetter: 'ก',
      );
      expect(outcome.detail['distinctCount'], 3);
    });

    test('scores 0 when too few words start with the prompt letter', () {
      final outcome = scoreVerbalFluency(
        segments(List.generate(20, (i) => 'ขคำ$i')),
        initialLetter: 'ก',
      );
      expect(outcome.score, 0);
    });
  });

  test('records the words it counted, so a human can check the score', () {
    final outcome = scoreVerbalFluency(segments(['กา', 'กิน']));
    expect(outcome.detail['words'], ['กา', 'กิน']);
  });

  test('scores 0 for no speech at all', () {
    final outcome = scoreVerbalFluency(<AsrSegment>[]);
    expect(outcome.score, 0);
    expect(outcome.detail['distinctCount'], 0);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/scoring/verbal_fluency_test.dart
```

Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implement the segment type**

Create `lib/scoring/asr_segment.dart`:

```dart
/// One recognized utterance with its timing, as returned by the /transcribe
/// endpoint's `segments` field.
///
/// Deliberately in its own file with no imports: both the scoring library and
/// the ASR client need it, and neither layer should have to import the other
/// for a data class.
class AsrSegment {
  final double start;
  final double end;
  final String text;

  const AsrSegment({
    required this.start,
    required this.end,
    required this.text,
  });
}
```

- [ ] **Step 4: Implement the scorer**

Create `lib/scoring/verbal_fluency.dart`:

```dart
import 'asr_segment.dart';
import 'matchers.dart';
import 'subtest_outcome.dart';

/// The MoCA cutoff: 11 or more words in 60 seconds earns the point.
const int kFluencyWordThreshold = 11;

/// Counts distinct words from segments rather than from the joined transcript.
///
/// This is the whole design of this scorer. Thai does not space between words
/// and the recognizer's spacing is arbitrary, so splitting text on whitespace
/// would count an unpredictable number of "words" for the same speech.
/// Segments key off the patient's own pauses instead, which is what the
/// instrument is actually measuring.
///
/// [initialLetter] filters to words beginning with that letter, for a letter
/// fluency prompt. Pass null for a category prompt, where every word counts.
SubtestOutcome scoreVerbalFluency(
  List<AsrSegment> segments, {
  String? initialLetter,
}) {
  final seen = <String>{};
  final words = <String>[];

  for (final segment in segments) {
    final word = normalizeText(segment.text);
    if (word.isEmpty) continue;
    if (initialLetter != null && !word.startsWith(normalizeText(initialLetter))) {
      continue;
    }
    if (seen.add(word)) words.add(word);
  }

  return SubtestOutcome(
    subtestId: 'verbal-fluency',
    score: words.length >= kFluencyWordThreshold ? 1 : 0,
    maxScore: 1,
    transcript: segments.map((s) => s.text).join(' '),
    detail: {
      'distinctCount': words.length,
      'words': words,
      'threshold': kFluencyWordThreshold,
    },
  );
}
```

- [ ] **Step 5: Run to verify it passes**

```powershell
flutter test test/scoring/verbal_fluency_test.dart
```

Expected: PASS, 9 tests.

- [ ] **Step 6: Commit**

```powershell
git add lib/scoring/asr_segment.dart lib/scoring/verbal_fluency.dart test/scoring/verbal_fluency_test.dart
git commit -m "feat: add Verbal Fluency scorer counting distinct segments"
```

---

### Task 11: ASR client

**Files:**
- Create: `lib/moca/asr_client.dart`
- Test: `test/moca/asr_client_test.dart`

**Interfaces:**
- Consumes: `AsrSegment` (Task 10)
- Produces:
  - `class AsrResult { final String text; final List<AsrSegment> segments; }`
  - `abstract class AsrClient { Future<AsrResult> transcribe(List<int> audioBytes, {String language}); }`
  - `class HttpAsrClient implements AsrClient` — constructor `HttpAsrClient({required Uri endpoint, http.Client? client})`
  - `class FakeAsrClient implements AsrClient` — constructor `FakeAsrClient({String text, List<AsrSegment> segments, Object? throws})`
  - `class AsrException implements Exception`
  - `const String kDefaultAsrEndpoint`

- [ ] **Step 1: Write the failing test**

Create `test/moca/asr_client_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moca_main/moca/asr_client.dart';

void main() {
  test('posts the audio and parses text and segments', () async {
    late http.BaseRequest captured;

    final mock = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'text': 'สองสี่เจ็ด',
          'segments': [
            {'start': 0.0, 'end': 0.5, 'text': 'สอง'},
            {'start': 0.6, 'end': 1.0, 'text': 'สี่เจ็ด'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final client = HttpAsrClient(
      endpoint: Uri.parse('https://example.test/transcribe'),
      client: mock,
    );

    final result = await client.transcribe([1, 2, 3]);

    expect(result.text, 'สองสี่เจ็ด');
    expect(result.segments.length, 2);
    expect(result.segments.first.text, 'สอง');
    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'https://example.test/transcribe');
  });

  test('tolerates a response with no segments field', () async {
    final mock = MockClient((request) async => http.Response(
          jsonEncode({'text': 'ยานพาหนะ'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));

    final client = HttpAsrClient(
      endpoint: Uri.parse('https://example.test/transcribe'),
      client: mock,
    );

    final result = await client.transcribe([1]);
    expect(result.text, 'ยานพาหนะ');
    expect(result.segments, isEmpty);
  });

  // 503 is what the endpoint returns while the model is still loading. It has
  // to surface as a retryable error, not as an empty transcript that would be
  // scored as the patient saying nothing.
  test('throws on 503 rather than returning an empty transcript', () async {
    final mock = MockClient((request) async => http.Response(
          jsonEncode({'detail': 'model not loaded'}),
          503,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));

    final client = HttpAsrClient(
      endpoint: Uri.parse('https://example.test/transcribe'),
      client: mock,
    );

    expect(() => client.transcribe([1]), throwsA(isA<AsrException>()));
  });

  test('throws when the network fails', () async {
    final mock = MockClient((request) async => throw const SocketishError());

    final client = HttpAsrClient(
      endpoint: Uri.parse('https://example.test/transcribe'),
      client: mock,
    );

    expect(() => client.transcribe([1]), throwsA(isA<AsrException>()));
  });

  test('the fake returns what it was given', () async {
    final fake = FakeAsrClient(text: 'ยานพาหนะ');
    expect((await fake.transcribe([])).text, 'ยานพาหนะ');
  });

  test('the fake can be told to fail', () async {
    final fake = FakeAsrClient(throws: const AsrException('offline'));
    expect(() => fake.transcribe([]), throwsA(isA<AsrException>()));
  });
}

class SocketishError implements Exception {
  const SocketishError();
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/moca/asr_client_test.dart
```

Expected: FAIL — URI doesn't exist. (If it instead fails on `package:http/testing.dart`, run `flutter pub add --dev http` — `http` is already a direct dependency, so this should not happen.)

- [ ] **Step 3: Implement**

Create `lib/moca/asr_client.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../scoring/asr_segment.dart';

/// Same host clock.dart already uploads to. Only the path differs.
const String kDefaultAsrEndpoint =
    'https://moca-flask-container.azurewebsites.net/transcribe';

class AsrException implements Exception {
  final String message;
  const AsrException(this.message);
  @override
  String toString() => 'AsrException: $message';
}

class AsrResult {
  final String text;
  final List<AsrSegment> segments;
  const AsrResult({required this.text, this.segments = const []});
}

abstract class AsrClient {
  Future<AsrResult> transcribe(List<int> audioBytes, {String language});
}

class HttpAsrClient implements AsrClient {
  final Uri endpoint;
  final http.Client _client;

  HttpAsrClient({required this.endpoint, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<AsrResult> transcribe(List<int> audioBytes,
      {String language = 'th'}) async {
    final request = http.MultipartRequest('POST', endpoint)
      ..fields['language'] = language
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: 'response.wav',
        contentType: MediaType('audio', 'wav'),
      ));

    http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } catch (e) {
      // Anything the transport throws becomes one type the caller can catch.
      // The screen turns this into Retry / Skip.
      throw AsrException('transcription request failed: $e');
    }

    if (response.statusCode != 200) {
      // 503 means the model is still loading. Surfacing it as an error rather
      // than an empty transcript matters: an empty transcript would be scored
      // as the patient having said nothing.
      throw AsrException(
          'transcription failed with ${response.statusCode}: ${response.body}');
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw AsrException('could not parse transcription response: $e');
    }

    final rawSegments = body['segments'];
    final segments = <AsrSegment>[];
    if (rawSegments is List) {
      for (final s in rawSegments) {
        if (s is! Map) continue;
        segments.add(AsrSegment(
          start: (s['start'] as num?)?.toDouble() ?? 0.0,
          end: (s['end'] as num?)?.toDouble() ?? 0.0,
          text: (s['text'] as String?) ?? '',
        ));
      }
    }

    return AsrResult(
      text: (body['text'] as String?) ?? '',
      segments: segments,
    );
  }
}

/// Used by every test that would otherwise need a network.
class FakeAsrClient implements AsrClient {
  final String text;
  final List<AsrSegment> segments;
  final Object? throws;
  int callCount = 0;

  FakeAsrClient({this.text = '', this.segments = const [], this.throws});

  @override
  Future<AsrResult> transcribe(List<int> audioBytes,
      {String language = 'th'}) async {
    callCount += 1;
    if (throws != null) throw throws!;
    return AsrResult(text: text, segments: segments);
  }
}
```

- [ ] **Step 4: Run to verify it passes**

```powershell
flutter test test/moca/asr_client_test.dart
```

Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```powershell
git add lib/moca/asr_client.dart test/moca/asr_client_test.dart
git commit -m "feat: add ASR client for the /transcribe endpoint"
```

---

### Task 12: Recorder and playback interfaces

Thin wrappers so the session controller can be tested without hardware. The real implementations are verified by hand in Task 20, not by `flutter test` — plugin channels do not exist in the unit test environment.

**Files:**
- Create: `lib/moca/audio_recorder.dart`
- Create: `lib/moca/audio_player.dart`
- Test: `test/moca/fakes_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `abstract class VoiceRecorder { Future<void> start(); Future<List<int>> stop(); Future<void> dispose(); }`
  - `class DeviceVoiceRecorder implements VoiceRecorder`
  - `class FakeVoiceRecorder implements VoiceRecorder` — fields `List<String> calls`, `List<int> bytes`
  - `abstract class AudioPlayback { Future<void> play(String assetPath); Future<void> stop(); Future<void> dispose(); }`
  - `class DeviceAudioPlayback implements AudioPlayback`
  - `class FakeAudioPlayback implements AudioPlayback` — field `List<String> calls`

- [ ] **Step 1: Write the failing test**

Create `test/moca/fakes_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/audio_player.dart';
import 'package:moca_main/moca/audio_recorder.dart';

void main() {
  test('the fake recorder records the calls made to it', () async {
    final recorder = FakeVoiceRecorder(bytes: [1, 2, 3]);

    await recorder.start();
    final bytes = await recorder.stop();

    expect(recorder.calls, ['start', 'stop']);
    expect(bytes, [1, 2, 3]);
  });

  test('the fake playback records which assets it was asked to play', () async {
    final playback = FakeAudioPlayback();

    await playback.play('assets/moca/audio/digits-forward.wav');
    await playback.stop();

    expect(playback.calls,
        ['play:assets/moca/audio/digits-forward.wav', 'stop']);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/moca/fakes_test.dart
```

Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implement the recorder**

Create `lib/moca/audio_recorder.dart`:

```dart
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// The microphone, behind an interface so the session controller can be tested
/// without one.
abstract class VoiceRecorder {
  Future<void> start();

  /// Returns the recorded audio as bytes, ready to POST to /transcribe.
  Future<List<int>> stop();

  Future<void> dispose();
}

class DeviceVoiceRecorder implements VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;

  @override
  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission was refused');
    }

    final dir = await getTemporaryDirectory();
    _path =
        '${dir.path}/moca-${DateTime.now().millisecondsSinceEpoch}.wav';

    // 16 kHz mono PCM: what the endpoint expects, and what the model wants.
    // Recording at a higher rate only to downsample server-side wastes upload
    // time on a connection the patient is waiting on.
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _path!,
    );
  }

  @override
  Future<List<int>> stop() async {
    await _recorder.stop();
    final path = _path;
    if (path == null) return const [];
    final file = File(path);
    if (!await file.exists()) return const [];
    final bytes = await file.readAsBytes();
    // The upload is the only consumer; leaving these behind fills the temp
    // directory over a long session.
    try {
      await file.delete();
    } catch (_) {}
    return bytes;
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

class FakeVoiceRecorder implements VoiceRecorder {
  final List<String> calls = [];
  final List<int> bytes;
  final Object? throwsOnStart;

  FakeVoiceRecorder({this.bytes = const [1], this.throwsOnStart});

  @override
  Future<void> start() async {
    calls.add('start');
    if (throwsOnStart != null) throw throwsOnStart!;
  }

  @override
  Future<List<int>> stop() async {
    calls.add('stop');
    return bytes;
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
  }
}
```

- [ ] **Step 4: Implement the playback**

Create `lib/moca/audio_player.dart`:

```dart
import 'package:audioplayers/audioplayers.dart';

/// Stimulus playback, behind an interface for the same reason as the recorder.
abstract class AudioPlayback {
  /// Resolves when the file has finished playing — not when it starts. The
  /// session controller relies on this: the microphone must not open until
  /// playback is genuinely over.
  Future<void> play(String assetPath);

  Future<void> stop();

  Future<void> dispose();
}

class DeviceAudioPlayback implements AudioPlayback {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(String assetPath) async {
    // audioplayers' AssetSource is rooted at `assets/`, so strip the prefix
    // that pubspec.yaml and the rest of this codebase use.
    final source = assetPath.startsWith('assets/')
        ? assetPath.substring('assets/'.length)
        : assetPath;

    await _player.stop();

    // Subscribe BEFORE starting playback. onPlayerComplete is a broadcast
    // stream, so a file that finishes before the subscription attaches would
    // leave this future pending forever — and the digit files are only about
    // a second long, which is well inside that window.
    //
    // This is load-bearing rather than defensive: the session controller
    // implements "the microphone never opens before playback finishes" by
    // awaiting this future. Its unit tests use FakeAudioPlayback, so no test
    // in the suite can catch a hang here.
    final completed = _player.onPlayerComplete.first;
    await _player.play(AssetSource(source));
    await completed;
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

class FakeAudioPlayback implements AudioPlayback {
  final List<String> calls = [];

  @override
  Future<void> play(String assetPath) async {
    calls.add('play:$assetPath');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
  }
}
```

- [ ] **Step 5: Run to verify it passes**

```powershell
flutter test test/moca/fakes_test.dart
```

Expected: PASS, 2 tests.

- [ ] **Step 6: Commit**

```powershell
git add lib/moca/audio_recorder.dart lib/moca/audio_player.dart test/moca/fakes_test.dart
git commit -m "feat: add recorder and playback interfaces with fakes"
```

---

### Task 13: Digit sequence player

Vigilance's stimulus. The score depends entirely on which one-second window a tap landed in, so this cannot be one long recording — the onsets would become hand-measured estimates needing re-measurement on every re-record.

**Files:**
- Create: `lib/moca/digit_sequence_player.dart`
- Test: `test/moca/digit_sequence_player_test.dart`

**Interfaces:**
- Consumes: `AudioPlayback` (Task 12)
- Produces: `class DigitSequencePlayer` — constructor `DigitSequencePlayer({required AudioPlayback playback})`, methods `Future<void> play(String sequence, {required int intervalMs, int leadInMs = 0, void Function()? onStart})` and `void stop()`

- [ ] **Step 1: Write the failing test**

Create `test/moca/digit_sequence_player_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/audio_player.dart';
import 'package:moca_main/moca/digit_sequence_player.dart';

void main() {
  testWidgets('plays each digit once, in order', (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);

    final done = player.play('513', intervalMs: 1000, leadInMs: 1000);
    await tester.pump(const Duration(milliseconds: 4100));
    await done;

    expect(playback.calls, [
      'play:assets/moca/audio/digit-5.wav',
      'play:assets/moca/audio/digit-1.wav',
      'play:assets/moca/audio/digit-3.wav',
    ]);
  });

  // The origin every tap offset is measured from. It fires at the FIRST
  // DIGIT'S onset, not when play() was called — the lead-in silence sits in
  // between, and a tap during it is not an answer to any digit.
  testWidgets('fires onStart at the first digit, after the lead-in',
      (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);
    var started = false;

    final done =
        player.play('51', intervalMs: 1000, leadInMs: 1000, onStart: () => started = true);

    await tester.pump(const Duration(milliseconds: 500));
    expect(started, isFalse, reason: 'still inside the lead-in');

    await tester.pump(const Duration(milliseconds: 600));
    expect(started, isTrue);

    await tester.pump(const Duration(milliseconds: 2000));
    await done;
  });

  testWidgets('resolves when the last window closes, not when the last sound stops',
      (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);
    var resolved = false;

    player.play('51', intervalMs: 1000, leadInMs: 0).then((_) => resolved = true);

    await tester.pump(const Duration(milliseconds: 1900));
    expect(resolved, isFalse);

    await tester.pump(const Duration(milliseconds: 200));
    expect(resolved, isTrue);
  });

  // A stopped sequence was abandoned, not completed. Resolving would let the
  // caller score a subtest that never finished.
  testWidgets('stop cancels the remaining digits', (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);

    player.play('51319', intervalMs: 1000, leadInMs: 0);
    await tester.pump(const Duration(milliseconds: 1500));
    player.stop();
    await tester.pump(const Duration(milliseconds: 5000));

    expect(playback.calls.where((c) => c.startsWith('play:')).length, 2);
  });

  testWidgets('a second play retires the first', (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);

    player.play('99999', intervalMs: 1000, leadInMs: 0);
    await tester.pump(const Duration(milliseconds: 1500));

    final second = player.play('51', intervalMs: 1000, leadInMs: 0);
    await tester.pump(const Duration(milliseconds: 2100));
    await second;

    final played = playback.calls.where((c) => c.startsWith('play:')).toList();
    expect(played.last, 'assets/moca/audio/digit-1.wav');
    expect(played.where((c) => c.contains('digit-9')).length, 2,
        reason: 'only the two digits that had already sounded');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/moca/digit_sequence_player_test.dart
```

Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implement**

Create `lib/moca/digit_sequence_player.dart`:

```dart
import 'dart:async';

import 'audio_player.dart';

String _assetFor(String digit) => 'assets/moca/audio/digit-$digit.wav';

/// Schedules Vigilance's digit stream.
///
/// Separate from AudioPlayback on purpose. That one plays a file and resolves
/// when it ends; this one schedules many and resolves when the last WINDOW
/// closes, which is a different moment from when the last sound stops.
class DigitSequencePlayer {
  final AudioPlayback playback;

  final List<Timer> _timers = [];
  bool _cancelled = false;

  DigitSequencePlayer({required this.playback});

  Future<void> play(
    String sequence, {
    required int intervalMs,
    int leadInMs = 0,
    void Function()? onStart,
  }) {
    // Retire anything still scheduled from a previous call. This must cancel
    // the timers, not merely drop the references — an emptied list would leave
    // the old sequence sounding and no longer stoppable.
    stop();
    _cancelled = false;

    final digits = sequence.split('');
    final completer = Completer<void>();
    final start = DateTime.now();

    // Every delay is recomputed against one shared start reference. Chaining
    // timers instead lets each one's few milliseconds of lateness carry into
    // the next, which over 29 digits drifts far enough to matter against a
    // 1000 ms window.
    void at(int offsetMs, void Function() fn) {
      final delay = start
          .add(Duration(milliseconds: offsetMs))
          .difference(DateTime.now());
      _timers.add(Timer(delay.isNegative ? Duration.zero : delay, fn));
    }

    for (var index = 0; index < digits.length; index++) {
      at(leadInMs + index * intervalMs, () {
        if (_cancelled) return;
        if (index == 0 && onStart != null) onStart();

        // Cut off whatever is still sounding before this digit starts. The
        // recordings run longer than the 1000 ms interval, so a tail would
        // otherwise bleed over the next digit — worst across the run of three
        // consecutive targets, where the whole point is that the patient hears
        // each one as a separate digit. Owning the boundary here means an
        // over-long file costs audio quality, never scoring accuracy.
        //
        // Deliberately not awaited: awaiting playback would push the next
        // digit's onset out by however long this one runs, which is exactly
        // the drift the shared start reference exists to prevent.
        playback.play(_assetFor(digits[index])).catchError((_) {
          // A digit that fails to sound is a scoring problem, not a crash: it
          // shows up as a miss rather than killing the session mid-sequence.
        });
      });
    }

    at(leadInMs + digits.length * intervalMs, () {
      if (_cancelled) return;
      if (!completer.isCompleted) completer.complete();
    });

    return completer.future;
  }

  /// Deliberately leaves play()'s future unsettled: a stopped sequence was
  /// abandoned, not completed, and resolving would let the caller score a
  /// subtest that never finished. The controller's generation guard retires
  /// that caller.
  void stop() {
    _cancelled = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    playback.stop();
  }
}
```

- [ ] **Step 4: Run to verify it passes**

```powershell
flutter test test/moca/digit_sequence_player_test.dart
```

Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```powershell
git add lib/moca/digit_sequence_player.dart test/moca/digit_sequence_player_test.dart
git commit -m "feat: add digit sequence player with drift-free scheduling"
```

---

### Task 14: Subtest specs

**Files:**
- Create: `lib/moca/subtest_spec.dart`
- Create: `lib/moca/subtests.dart`
- Test: `test/moca/subtests_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `enum ResponseMode { voice, tap }`
  - `class SubtestSpec` with fields `id`, `section`, `instructionTh`, `maxScore`, `responseMode`, `stimulusAsset` (String?), `expectedSequence` (String?), `expectedSentence` (String?), `timeLimitSec` (int?), `enforceTimeLimit` (bool), `sequence` (String?), `target` (String?), `intervalMs` (int), `leadInMs` (int), `initialLetter` (String?)
  - `const List<SubtestSpec> kVoiceSubtests`
  - `const String kVigilanceSequence`

- [ ] **Step 1: Write the failing test**

Create `test/moca/subtests_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/subtest_spec.dart';
import 'package:moca_main/moca/subtests.dart';

void main() {
  test('covers exactly the nine planned subtests, in administration order', () {
    expect(kVoiceSubtests.map((s) => s.id).toList(), [
      'digit-span-forward',
      'digit-span-backward',
      'vigilance',
      'sentence-repetition-1',
      'sentence-repetition-2',
      'verbal-fluency',
      'abstraction-1',
      'abstraction-2',
      'orientation',
    ]);
  });

  test('adds up to 14 points', () {
    final total =
        kVoiceSubtests.fold<int>(0, (sum, s) => sum + s.maxScore);
    expect(total, 14);
  });

  test('every subtest has Thai instruction text', () {
    for (final spec in kVoiceSubtests) {
      expect(spec.instructionTh.trim(), isNotEmpty, reason: spec.id);
    }
  });

  // Only Verbal Fluency has a normed deadline. Enforcing one anywhere else
  // would cut off a slow but correct patient and manufacture a wrong score.
  test('only verbal fluency enforces a time limit', () {
    final enforced =
        kVoiceSubtests.where((s) => s.enforceTimeLimit).map((s) => s.id);
    expect(enforced, ['verbal-fluency']);
  });

  test('verbal fluency is exactly 60 seconds', () {
    final fluency = kVoiceSubtests.firstWhere((s) => s.id == 'verbal-fluency');
    expect(fluency.timeLimitSec, 60);
  });

  test('vigilance is the only tap subtest', () {
    final tap = kVoiceSubtests
        .where((s) => s.responseMode == ResponseMode.tap)
        .map((s) => s.id);
    expect(tap, ['vigilance']);
  });

  // A single wrong digit here changes every score the subtest produces and
  // looks completely normal, so its shape is asserted rather than trusted.
  group('the vigilance sequence', () {
    test('is 29 digits long', () {
      expect(kVigilanceSequence.length, 29);
    });

    test('contains 11 targets', () {
      expect(kVigilanceSequence.split('').where((d) => d == '1').length, 11);
    });

    test('is all digits', () {
      expect(RegExp(r'^\d+$').hasMatch(kVigilanceSequence), isTrue);
    });

    // The structurally important part: three consecutive targets are where a
    // patient tapping perseveratively and one genuinely tracking produce
    // identical output, and the non-target that follows separates them.
    test('has three consecutive targets at positions 18-20', () {
      expect(kVigilanceSequence.substring(18, 21), '111');
      expect(kVigilanceSequence[21], isNot('1'));
    });
  });

  test('digit span expects the sequences from the Thai form', () {
    final forward =
        kVoiceSubtests.firstWhere((s) => s.id == 'digit-span-forward');
    final backward =
        kVoiceSubtests.firstWhere((s) => s.id == 'digit-span-backward');

    expect(forward.expectedSequence, '21854');
    // The patient hears 742 and must say it reversed.
    expect(backward.expectedSequence, '247');
  });

  // Declaring the path rather than leaving it null is the whole point. Null
  // means "this subtest has no stimulus by design", which is true of
  // Abstraction and Orientation — the controller opens the microphone
  // immediately for those. If sentence repetition were null too, the
  // controller could not tell the two apart and would record the patient
  // answering a sentence they never heard.
  test('sentence repetition declares both a stimulus and a sentence', () {
    final items =
        kVoiceSubtests.where((s) => s.id.startsWith('sentence-repetition')).toList();
    expect(items.length, 2);
    for (final spec in items) {
      expect(spec.stimulusAsset, isNotNull, reason: spec.id);
      expect(spec.expectedSentence, isNotNull, reason: spec.id);
      expect(spec.expectedSentence!.trim(), isNotEmpty, reason: spec.id);
    }
  });

  // The scorer compares speech against expectedSentence while the patient
  // hears stimulusAsset. Nothing in the type system ties the two together, so
  // a mismatched pair would score every patient against a sentence they never
  // heard — and look completely normal.
  test('each sentence item pairs its own asset with its own sentence', () {
    final one =
        kVoiceSubtests.firstWhere((s) => s.id == 'sentence-repetition-1');
    final two =
        kVoiceSubtests.firstWhere((s) => s.id == 'sentence-repetition-2');

    expect(one.stimulusAsset, 'assets/moca/audio/sentence-1.wav');
    expect(two.stimulusAsset, 'assets/moca/audio/sentence-2.wav');
    expect(one.expectedSentence, isNot(two.expectedSentence));
  });

  test('subtests with no stimulus by design declare none', () {
    for (final id in ['abstraction-1', 'abstraction-2', 'orientation', 'verbal-fluency']) {
      expect(kVoiceSubtests.firstWhere((s) => s.id == id).stimulusAsset, isNull,
          reason: id);
    }
  });

  test('subtests that need stimulus audio name a wav asset', () {
    final withAudio =
        kVoiceSubtests.where((s) => s.stimulusAsset != null);
    for (final spec in withAudio) {
      expect(spec.stimulusAsset, endsWith('.wav'), reason: spec.id);
      expect(spec.stimulusAsset, startsWith('assets/moca/audio/'),
          reason: spec.id);
    }
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/moca/subtests_test.dart
```

Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implement the spec type**

Create `lib/moca/subtest_spec.dart`:

```dart
enum ResponseMode { voice, tap }

/// One subtest, as data. The engine renders and scores every subtest from one
/// of these, so adding a subtest is an entry in kVoiceSubtests rather than a
/// new screen.
class SubtestSpec {
  final String id;
  final String section;
  final String instructionTh;
  final int maxScore;
  final ResponseMode responseMode;

  /// Played before the microphone opens.
  ///
  /// Null means this subtest has no stimulus BY DESIGN — Abstraction and
  /// Orientation ask their question in the instruction text, so the microphone
  /// opens immediately. A non-null path whose file fails to load is a
  /// different situation entirely: the controller skips that subtest rather
  /// than recording a patient answering a question they never heard.
  final String? stimulusAsset;

  /// Digit Span only.
  final String? expectedSequence;

  /// Sentence Repetition only.
  final String? expectedSentence;

  /// Recorded with the result. Only enforced when [enforceTimeLimit] is true,
  /// which is Verbal Fluency alone — everywhere else this is a budget, not a
  /// deadline, and no clock is shown.
  final int? timeLimitSec;
  final bool enforceTimeLimit;

  /// Vigilance only.
  final String? sequence;
  final String? target;
  final int intervalMs;
  final int leadInMs;

  /// Verbal Fluency only. Null means a category prompt, where every word counts.
  final String? initialLetter;

  const SubtestSpec({
    required this.id,
    required this.section,
    required this.instructionTh,
    required this.maxScore,
    this.responseMode = ResponseMode.voice,
    this.stimulusAsset,
    this.expectedSequence,
    this.expectedSentence,
    this.timeLimitSec,
    this.enforceTimeLimit = false,
    this.sequence,
    this.target,
    this.intervalMs = 1000,
    this.leadInMs = 1000,
    this.initialLetter,
  });
}
```

- [ ] **Step 4: Implement the spec list**

Create `lib/moca/subtests.dart`:

```dart
import 'subtest_spec.dart';

/// Vigilance: the patient taps every time they hear the target digit. Straight
/// from the Thai MoCA-Basic form — 29 digits, 11 of them targets.
///
/// The three consecutive targets at positions 18-20 are the structurally
/// important part: they are where a patient tapping perseveratively and one
/// genuinely tracking produce identical output, and the non-target that
/// follows separates them. A test asserts this shape.
const String kVigilanceSequence = '52139411806215194511141905112';

/// Silence between the instruction and the first digit, so the sequence does
/// not start on the heels of the last syllable. Silence rather than a
/// countdown: a countdown hands the patient a rhythm to lock onto before the
/// task begins.
const int _vigilanceLeadInMs = 1000;

const List<SubtestSpec> kVoiceSubtests = [
  SubtestSpec(
    id: 'digit-span-forward',
    section: 'สมาธิ',
    instructionTh: 'ฟังตัวเลขต่อไปนี้ แล้วพูดทวนตามลำดับ',
    maxScore: 1,
    stimulusAsset: 'assets/moca/audio/digits-forward.wav',
    expectedSequence: '21854',
    timeLimitSec: 7,
  ),
  SubtestSpec(
    id: 'digit-span-backward',
    section: 'สมาธิ',
    instructionTh: 'ฟังตัวเลขต่อไปนี้ แล้วพูดทวนย้อนกลับ',
    maxScore: 1,
    stimulusAsset: 'assets/moca/audio/digits-backward.wav',
    // The patient hears 742 and must say it reversed.
    expectedSequence: '247',
    timeLimitSec: 7,
  ),
  SubtestSpec(
    id: 'vigilance',
    section: 'สมาธิ',
    // Must stay word for word in step with what the screen shows — a patient
    // who reads one instruction and is set another has been given a second
    // task nobody intended, and on this subtest that looks like a deficit.
    instructionTh: 'คุณจะได้ยินตัวเลขหลายตัว ให้แตะที่ปุ่มบนหน้าจอ ทุกครั้งที่ได้ยินเลขหนึ่ง',
    maxScore: 1,
    responseMode: ResponseMode.tap,
    sequence: kVigilanceSequence,
    target: '1',
    intervalMs: 1000,
    leadInMs: _vigilanceLeadInMs,
    // The sequence's own fixed duration, recorded rather than enforced: the
    // subtest ends when the audio ends.
    timeLimitSec: 30,
  ),
  // Sentences and recordings supplied by the user on 2026-08-17. The
  // expectedSentence text and the audio must stay in step: the scorer compares
  // what the patient said against this string, so editing one without
  // re-recording the other silently scores every patient against a sentence
  // they never heard.
  //
  // stimulusAsset is declared rather than left null. Null means "no stimulus
  // by design" (Abstraction, Orientation), where the microphone opens
  // immediately. The controller skips a subtest whose DECLARED stimulus fails
  // to load, which is the safety net if the asset ever fails to bundle.
  SubtestSpec(
    id: 'sentence-repetition-1',
    section: 'ภาษา',
    instructionTh: 'ฟังประโยคต่อไปนี้ แล้วพูดทวนให้เหมือนเดิมทุกคำ',
    maxScore: 1,
    stimulusAsset: 'assets/moca/audio/sentence-1.wav',
    expectedSentence: 'ฉันรู้ว่าจอมเป็นคนเดียวที่มาช่วยงานวันนี้',
    timeLimitSec: 20,
  ),
  SubtestSpec(
    id: 'sentence-repetition-2',
    section: 'ภาษา',
    instructionTh: 'ฟังประโยคต่อไปนี้ แล้วพูดทวนให้เหมือนเดิมทุกคำ',
    maxScore: 1,
    stimulusAsset: 'assets/moca/audio/sentence-2.wav',
    expectedSentence: 'แมวมักจะซ่อนตัวอยู่หลังเก้าอี้เมื่อมีหมาอยู่ในห้อง',
    timeLimitSec: 20,
  ),
  SubtestSpec(
    id: 'verbal-fluency',
    section: 'ภาษา',
    instructionTh: 'บอกคำที่ขึ้นต้นด้วยตัว ก ให้ได้มากที่สุดภายในหนึ่งนาที',
    maxScore: 1,
    // The only normed deadline in the app. 60 seconds is what the "11 or more
    // words" cutoff is measured against, so it is enforced.
    timeLimitSec: 60,
    enforceTimeLimit: true,
    initialLetter: 'ก',
  ),
  SubtestSpec(
    id: 'abstraction-1',
    section: 'ความคิดรวบยอด',
    // The worked example is part of the instruction, not a scored item. Without
    // it, people answer with a shared physical feature and score 0 for
    // misunderstanding the task rather than for failing it.
    instructionTh:
        'บอกว่าของสองสิ่งเหมือนกันอย่างไร ตัวอย่างเช่น กล้วยกับส้ม เป็นผลไม้ทั้งคู่ ทีนี้ รถไฟกับจักรยาน?',
    maxScore: 1,
    timeLimitSec: 30,
  ),
  SubtestSpec(
    id: 'abstraction-2',
    section: 'ความคิดรวบยอด',
    // No example this time — it was given once, and repeating it would prompt
    // the patient toward the kind of answer being measured.
    instructionTh: 'แล้วนาฬิกากับไม้บรรทัดเหมือนกันอย่างไร?',
    maxScore: 1,
    timeLimitSec: 30,
  ),
  SubtestSpec(
    id: 'orientation',
    section: 'การรับรู้เวลาและสถานที่',
    instructionTh: 'บอกวัน เดือน ปี วันที่ สถานที่ และจังหวัดในวันนี้',
    maxScore: 6,
    timeLimitSec: 15,
  ),
];
```

- [ ] **Step 5: Run to verify it passes**

```powershell
flutter test test/moca/subtests_test.dart
```

Expected: PASS, 13 tests.

- [ ] **Step 6: Commit**

```powershell
git add lib/moca/subtest_spec.dart lib/moca/subtests.dart test/moca/subtests_test.dart
git commit -m "feat: add subtest specs with vigilance sequence shape tests"
```

---

### Task 15: Scorer dispatch

One place that maps a subtest id to its scorer, so the controller does not carry a switch.

**Files:**
- Create: `lib/scoring/score_item.dart`
- Test: `test/scoring/score_item_test.dart`

**Interfaces:**
- Consumes: every scorer (Tasks 5–10), `SubtestSpec` (Task 14), `AsrResult` (Task 11)
- Produces: `SubtestOutcome scoreItem(SubtestSpec spec, {String transcript = '', List<AsrSegment> segments = const [], List<int> taps = const [], DateTime? referenceDate})`

- [ ] **Step 1: Write the failing test**

Create `test/scoring/score_item_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/subtest_spec.dart';
import 'package:moca_main/moca/subtests.dart';
import 'package:moca_main/scoring/asr_segment.dart';
import 'package:moca_main/scoring/score_item.dart';

void main() {
  SubtestSpec spec(String id) => kVoiceSubtests.firstWhere((s) => s.id == id);

  test('routes digit span to its scorer', () {
    final outcome = scoreItem(spec('digit-span-forward'),
        transcript: 'สองหนึ่งแปดห้าสี่');
    expect(outcome.score, 1);
  });

  test('routes abstraction to its scorer, per item', () {
    expect(scoreItem(spec('abstraction-1'), transcript: 'ยานพาหนะ').score, 1);
    expect(scoreItem(spec('abstraction-2'), transcript: 'ยานพาหนะ').score, 0);
  });

  test('routes orientation, using the reference date it is given', () {
    final outcome = scoreItem(
      spec('orientation'),
      transcript: 'ปี 2569',
      referenceDate: DateTime(2026, 8, 13),
    );
    expect(outcome.detail['year'], isTrue);
  });

  // Vigilance is the only scorer whose answer is not speech: the transcript is
  // always empty and the response arrives as tap offsets.
  test('routes vigilance, scoring taps rather than speech', () {
    final taps = <int>[];
    final sequence = spec('vigilance').sequence!;
    for (var i = 0; i < sequence.length; i++) {
      if (sequence[i] == '1') taps.add(i * 1000 + 400);
    }

    final outcome = scoreItem(spec('vigilance'), taps: taps);
    expect(outcome.score, 1);
    expect(outcome.detail['hits'], 11);
  });

  test('routes sentence repetition against its expected sentence', () {
    final s = spec('sentence-repetition-1');
    final outcome =
        scoreItem(s, transcript: s.expectedSentence!);
    expect(outcome.score, 1);
  });

  test('routes verbal fluency, counting segments', () {
    final segments = [
      for (var i = 0; i < 11; i++)
        AsrSegment(start: i * 2.0, end: i * 2.0 + 1, text: 'ก$i'),
    ];
    final outcome = scoreItem(spec('verbal-fluency'), segments: segments);
    expect(outcome.score, 1);
  });

  test('throws for a subtest with no scorer registered', () {
    const rogue = SubtestSpec(
      id: 'not-a-subtest',
      section: 'x',
      instructionTh: 'x',
      maxScore: 1,
    );
    expect(() => scoreItem(rogue), throwsA(isA<ArgumentError>()));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/scoring/score_item_test.dart
```

Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implement**

Create `lib/scoring/score_item.dart`:

```dart
import '../moca/session_config.dart';
import '../moca/subtest_spec.dart';
import 'abstraction.dart';
import 'asr_segment.dart';
import 'digit_span.dart';
import 'orientation.dart';
import 'sentence_repetition.dart';
import 'subtest_outcome.dart';
import 'verbal_fluency.dart';

/// Maps a subtest to its scorer. One place, so the session controller does not
/// carry a switch and a new subtest is registered exactly once.
SubtestOutcome scoreItem(
  SubtestSpec spec, {
  String transcript = '',
  List<AsrSegment> segments = const [],
  List<int> taps = const [],
  DateTime? referenceDate,
}) {
  switch (spec.id) {
    case 'digit-span-forward':
    case 'digit-span-backward':
      return scoreDigitSpan(spec.id, transcript, spec.expectedSequence!);

    case 'vigilance':
      // The only scorer whose answer is not speech.
      return scoreVigilance(
        taps,
        sequence: spec.sequence!,
        target: spec.target!,
        intervalMs: spec.intervalMs,
      );

    case 'sentence-repetition-1':
    case 'sentence-repetition-2':
      return scoreSentenceRepetition(
          spec.id, transcript, spec.expectedSentence!);

    case 'verbal-fluency':
      return scoreVerbalFluency(segments, initialLetter: spec.initialLetter);

    case 'abstraction-1':
    case 'abstraction-2':
      return scoreAbstraction(spec.id, transcript);

    case 'orientation':
      return scoreOrientation(
        transcript,
        referenceDate: referenceDate ?? DateTime.now(),
        place: SessionConfig.place,
        province: SessionConfig.province,
      );

    default:
      // A typo in an id must not silently score a patient zero on a subtest
      // that was never really administered.
      throw ArgumentError('No scorer registered for subtest "${spec.id}"');
  }
}
```

- [ ] **Step 4: Run to verify it passes**

```powershell
flutter test test/scoring/score_item_test.dart
```

Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```powershell
git add lib/scoring/score_item.dart test/scoring/score_item_test.dart
git commit -m "feat: add scorer dispatch"
```

---

### Task 16: Session controller

The phase machine. This is where the "microphone never opens before playback ends" invariant is enforced and tested.

**Files:**
- Create: `lib/moca/session_controller.dart`
- Test: `test/moca/session_controller_test.dart`

**Interfaces:**
- Consumes: `SubtestSpec` (14), `AsrClient` (11), `VoiceRecorder`/`AudioPlayback` (12), `DigitSequencePlayer` (13), `scoreItem` (15)
- Produces:
  - `enum SessionPhase { instruction, stimulus, recording, tapping, scoring, error, done }`
  - `class SubtestSessionController extends ChangeNotifier` — constructor `SubtestSessionController({required SubtestSpec spec, required AsrClient asr, required VoiceRecorder recorder, required AudioPlayback playback, DigitSequencePlayer? digitPlayer, DateTime? referenceDate, Future<bool> Function(String)? assetExists})`

`assetExists` defaults to a `rootBundle.load` probe. It is injectable because asset resolution under `flutter test` is not dependable, and a false negative there would make Digit Span skip silently — which would leave the mic-order test passing while asserting nothing at all. Tests pass an explicit function so the outcome is decided by the test, not by the bundle.
  - Methods: `Future<void> begin()`, `Future<void> finishRecording()`, `void recordTap()`, `void retry()`, `SubtestOutcome skip()`
  - Getters: `SessionPhase phase`, `String? error`, `SubtestOutcome? outcome`

- [ ] **Step 1: Write the failing test**

Create `test/moca/session_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/asr_client.dart';
import 'package:moca_main/moca/audio_player.dart';
import 'package:moca_main/moca/audio_recorder.dart';
import 'package:moca_main/moca/session_controller.dart';
import 'package:moca_main/moca/subtest_spec.dart';
import 'package:moca_main/moca/subtests.dart';

void main() {
  SubtestSpec spec(String id) => kVoiceSubtests.firstWhere((s) => s.id == id);

  // Assets "exist" unless a test says otherwise, so asset resolution under
  // flutter test can never decide the outcome of a test about something else.
  SubtestSessionController build(
    SubtestSpec s, {
    AsrClient? asr,
    VoiceRecorder? recorder,
    AudioPlayback? playback,
    Set<String> missingAssets = const {},
  }) =>
      SubtestSessionController(
        spec: s,
        asr: asr ?? FakeAsrClient(text: 'สองหนึ่งแปดห้าสี่'),
        recorder: recorder ?? FakeVoiceRecorder(),
        playback: playback ?? FakeAudioPlayback(),
        assetExists: (path) async => !missingAssets.contains(path),
      );

  test('starts in the instruction phase', () {
    expect(build(spec('abstraction-1')).phase, SessionPhase.instruction);
  });

  // THE invariant. If the microphone opens while the stimulus is still
  // playing, the recognizer transcribes the app's own prompt and the subtest
  // appears to pass while measuring nothing — a failure that looks exactly
  // like success. Asserting literal call order is the only way to catch it.
  test('never opens the microphone before playback has finished', () async {
    final order = <String>[];
    final playback = _RecordingPlayback(order);
    final recorder = _RecordingRecorder(order);

    final controller =
        build(spec('digit-span-forward'), playback: playback, recorder: recorder);
    await controller.begin();

    expect(order, ['play:assets/moca/audio/digits-forward.wav', 'start']);
  });

  test('a subtest with no stimulus opens the microphone directly', () async {
    final playback = FakeAudioPlayback();
    final controller = build(spec('abstraction-1'), playback: playback);

    await controller.begin();

    expect(playback.calls.where((c) => c.startsWith('play:')), isEmpty);
    expect(controller.phase, SessionPhase.recording);
  });

  // The safety net. Every stimulus file ships in the bundle, but a voice
  // subtest whose declared stimulus fails to load must not silently record the
  // patient answering a question they never heard.
  test('skips a voice subtest whose declared stimulus does not exist', () async {
    final s = spec('sentence-repetition-1');
    final recorder = FakeVoiceRecorder();
    final controller = build(s,
        recorder: recorder, missingAssets: {s.stimulusAsset!});

    await controller.begin();

    expect(controller.phase, SessionPhase.done);
    expect(controller.outcome!.skipped, isTrue);
    expect(controller.outcome!.maxScore, 0);
    // The point of the check: the microphone must never open for a subtest
    // whose question the patient was never asked.
    expect(recorder.calls, isEmpty);
  });

  test('runs normally once the stimulus exists', () async {
    final controller = build(spec('sentence-repetition-1'));

    await controller.begin();

    expect(controller.phase, SessionPhase.recording);
  });

  test('transcribes and scores when recording finishes', () async {
    final controller = build(spec('digit-span-forward'));

    await controller.begin();
    await controller.finishRecording();

    expect(controller.phase, SessionPhase.done);
    expect(controller.outcome!.score, 1);
    expect(controller.outcome!.transcript, 'สองหนึ่งแปดห้าสี่');
  });

  test('enters the error phase when transcription fails', () async {
    final controller = build(
      spec('digit-span-forward'),
      asr: FakeAsrClient(throws: const AsrException('offline')),
    );

    await controller.begin();
    await controller.finishRecording();

    expect(controller.phase, SessionPhase.error);
    expect(controller.error, contains('offline'));
    expect(controller.outcome, isNull);
  });

  test('retry returns to the instruction phase and clears the error', () async {
    final controller = build(
      spec('digit-span-forward'),
      asr: FakeAsrClient(throws: const AsrException('offline')),
    );

    await controller.begin();
    await controller.finishRecording();
    controller.retry();

    expect(controller.phase, SessionPhase.instruction);
    expect(controller.error, isNull);
  });

  // Skip asserts the subtest was never administered. 0 would assert the
  // patient failed, and against real MoCA cutoffs that is a fabricated finding.
  test('skip produces an outcome that is excluded from the total', () {
    final controller = build(spec('orientation'));

    final outcome = controller.skip();

    expect(outcome.skipped, isTrue);
    expect(outcome.score, 0);
    expect(outcome.maxScore, 0);
    expect(controller.phase, SessionPhase.done);
  });

  group('tap mode', () {
    testWidgets('runs the digit sequence and scores the taps', (tester) async {
      final controller = build(spec('vigilance'));

      final begun = controller.begin();
      // Lead-in, then 29 digits at 1 s each.
      await tester.pump(const Duration(milliseconds: 1100));
      expect(controller.phase, SessionPhase.tapping);

      await tester.pump(const Duration(milliseconds: 30000));
      await begun;

      expect(controller.phase, SessionPhase.done);
      expect(controller.outcome!.maxScore, 1);
    });

    // A press during the lead-in or after the last window is not an answer to
    // any digit, so it must not become one.
    testWidgets('ignores taps outside the tapping phase', (tester) async {
      final controller = build(spec('vigilance'));

      controller.recordTap();
      final begun = controller.begin();
      controller.recordTap();

      await tester.pump(const Duration(milliseconds: 32000));
      await begun;

      expect(controller.outcome!.detail['hits'], 0);
    });
  });
}

class _RecordingPlayback implements AudioPlayback {
  final List<String> order;
  _RecordingPlayback(this.order);

  @override
  Future<void> play(String assetPath) async => order.add('play:$assetPath');
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _RecordingRecorder implements VoiceRecorder {
  final List<String> order;
  _RecordingRecorder(this.order);

  @override
  Future<void> start() async => order.add('start');
  @override
  Future<List<int>> stop() async => const [1];
  @override
  Future<void> dispose() async {}
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/moca/session_controller_test.dart
```

Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implement**

Create `lib/moca/session_controller.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../scoring/asr_segment.dart';
import '../scoring/score_item.dart';
import '../scoring/subtest_outcome.dart';
import 'asr_client.dart';
import 'audio_player.dart';
import 'audio_recorder.dart';
import 'digit_sequence_player.dart';
import 'subtest_spec.dart';

enum SessionPhase { instruction, stimulus, recording, tapping, scoring, error, done }

/// Drives one subtest: instruction → stimulus → response → score.
class SubtestSessionController extends ChangeNotifier {
  final SubtestSpec spec;
  final AsrClient asr;
  final VoiceRecorder recorder;
  final AudioPlayback playback;
  final DateTime? referenceDate;
  late final DigitSequencePlayer _digitPlayer;

  /// Injectable because asset resolution under `flutter test` is not
  /// dependable, and a false negative would make a subtest skip silently.
  final Future<bool> Function(String) _assetExists;

  SessionPhase _phase = SessionPhase.instruction;
  String? _error;
  SubtestOutcome? _outcome;

  /// Retires an in-flight attempt. Without it, a second begin() leaves the
  /// previous attempt's continuation running and two stimulus streams play
  /// over each other.
  int _generation = 0;

  final List<int> _taps = [];
  DateTime? _sequenceStartedAt;

  SubtestSessionController({
    required this.spec,
    required this.asr,
    required this.recorder,
    required this.playback,
    DigitSequencePlayer? digitPlayer,
    this.referenceDate,
    Future<bool> Function(String)? assetExists,
  }) : _assetExists = assetExists ?? _bundleHasAsset {
    _digitPlayer = digitPlayer ?? DigitSequencePlayer(playback: playback);
  }

  static Future<bool> _bundleHasAsset(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  SessionPhase get phase => _phase;
  String? get error => _error;
  SubtestOutcome? get outcome => _outcome;

  void _setPhase(SessionPhase next) {
    _phase = next;
    notifyListeners();
  }

  Future<void> begin() async {
    _generation += 1;
    final generation = _generation;
    bool abandoned() => _generation != generation;

    _error = null;

    try {
      if (spec.responseMode == ResponseMode.tap) {
        await _runTapSequence(abandoned);
        return;
      }

      final stimulus = spec.stimulusAsset;
      if (stimulus != null) {
        // A voice subtest that declares a stimulus but has no file is not
        // administrable — recording the patient answering a question they
        // never heard would produce a score for nothing. Sentence repetition
        // ships in exactly this state. A null stimulus is different: it means
        // the subtest has no stimulus by design, and the microphone opens
        // immediately.
        if (!await _assetExists(stimulus)) {
          _complete(SubtestOutcome.skippedFor(spec.id));
          return;
        }
        if (abandoned()) return;

        _setPhase(SessionPhase.stimulus);
        await playback.play(stimulus);
        if (abandoned()) return;
      }

      // The microphone opens only here, strictly after playback has finished.
      await recorder.start();
      if (abandoned()) {
        // The microphone opened for a subtest nobody is on any more. Close it
        // rather than leaving the stream live and the recorder unreachable.
        await recorder.stop();
        return;
      }
      _setPhase(SessionPhase.recording);
    } catch (e) {
      if (abandoned()) return;
      _error = e.toString();
      _setPhase(SessionPhase.error);
    }
  }

  Future<void> _runTapSequence(bool Function() abandoned) async {
    _taps.clear();

    await _digitPlayer.play(
      spec.sequence!,
      intervalMs: spec.intervalMs,
      leadInMs: spec.leadInMs,
      onStart: () {
        if (abandoned()) return;
        // The origin every tap offset is measured from. Set at the first
        // digit's onset, not at begin(), because the lead-in sits in between.
        _sequenceStartedAt = DateTime.now();
        _setPhase(SessionPhase.tapping);
      },
    );
    if (abandoned()) return;

    _setPhase(SessionPhase.scoring);
    _complete(scoreItem(spec, taps: List.of(_taps), referenceDate: referenceDate));
  }

  Future<void> finishRecording() async {
    _setPhase(SessionPhase.scoring);
    try {
      final bytes = await recorder.stop();
      final AsrResult result = await asr.transcribe(bytes);
      final List<AsrSegment> segments = result.segments;

      _complete(scoreItem(
        spec,
        transcript: result.text,
        segments: segments,
        referenceDate: referenceDate,
      ));
    } catch (e) {
      _error = e.toString();
      _setPhase(SessionPhase.error);
    }
  }

  /// A no-op outside the tapping phase: a press during the lead-in or after
  /// the last window is not an answer to any digit, so it must not become one.
  void recordTap() {
    if (_phase != SessionPhase.tapping) return;
    final started = _sequenceStartedAt;
    if (started == null) return;
    _taps.add(DateTime.now().difference(started).inMilliseconds);
  }

  void retry() {
    _generation += 1;
    _digitPlayer.stop();
    _error = null;
    _setPhase(SessionPhase.instruction);
  }

  /// A skipped subtest was never administered, so it scores nothing rather
  /// than scoring 0 — 0 would assert the patient failed.
  SubtestOutcome skip() {
    _generation += 1;
    _digitPlayer.stop();
    _error = null;
    final outcome = SubtestOutcome.skippedFor(spec.id);
    _complete(outcome);
    return outcome;
  }

  void _complete(SubtestOutcome outcome) {
    _outcome = outcome;
    _setPhase(SessionPhase.done);
  }

  @override
  void dispose() {
    _digitPlayer.stop();
    recorder.dispose();
    playback.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run to verify it passes**

```powershell
flutter test test/moca/session_controller_test.dart
```

Expected: PASS, 12 tests.

The `assetExists` injection is what keeps these deterministic: no test's result depends on whether `flutter test` resolved a real asset. Do not "simplify" it back to a direct `rootBundle` call — a false negative there would make Digit Span skip silently, and the mic-order test would keep passing while asserting nothing.

- [ ] **Step 5: Commit**

```powershell
git add lib/moca/session_controller.dart test/moca/session_controller_test.dart
git commit -m "feat: add session controller with mic-after-playback invariant"
```

---

### Task 17: The subtest screen

**Files:**
- Create: `lib/moca/voice_subtest_page.dart`
- Test: `test/moca/voice_subtest_page_test.dart`

**Interfaces:**
- Consumes: `SubtestSessionController` (16), `SubtestSpec` (14)
- Produces: `class VoiceSubtestPage extends StatefulWidget` — constructor `VoiceSubtestPage({required SubtestSpec spec, required String nextRoute, SubtestSessionController Function(SubtestSpec)? controllerFactory})`

- [ ] **Step 1: Write the failing test**

Create `test/moca/voice_subtest_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/asr_client.dart';
import 'package:moca_main/moca/audio_player.dart';
import 'package:moca_main/moca/audio_recorder.dart';
import 'package:moca_main/moca/session_controller.dart';
import 'package:moca_main/moca/subtest_spec.dart';
import 'package:moca_main/moca/subtests.dart';
import 'package:moca_main/moca/voice_subtest_page.dart';
import 'package:moca_main/pages/score.dart' as globals;

void main() {
  setUp(globals.voiceOutcomes.clear);

  SubtestSpec spec(String id) => kVoiceSubtests.firstWhere((s) => s.id == id);

  Widget host(SubtestSpec s, {AsrClient? asr}) => MaterialApp(
        home: VoiceSubtestPage(
          spec: s,
          nextRoute: '/next',
          controllerFactory: (spec) => SubtestSessionController(
            spec: spec,
            asr: asr ?? FakeAsrClient(text: 'ยานพาหนะ'),
            recorder: FakeVoiceRecorder(),
            playback: FakeAudioPlayback(),
          ),
        ),
        routes: {'/next': (_) => const Scaffold(body: Text('NEXT PAGE'))},
      );

  testWidgets('shows the Thai instruction text and a start button',
      (tester) async {
    await tester.pumpWidget(host(spec('abstraction-1')));

    expect(find.text(spec('abstraction-1').instructionTh), findsOneWidget);
    expect(find.text('เริ่ม'), findsOneWidget);
  });

  testWidgets('records, scores, and moves to the next route', (tester) async {
    await tester.pumpWidget(host(spec('abstraction-1')));

    await tester.tap(find.text('เริ่ม'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ส่งคำตอบ'));
    await tester.pumpAndSettle();

    expect(find.text('NEXT PAGE'), findsOneWidget);
    expect(globals.voiceOutcomes['abstraction-1']!.score, 1);
  });

  testWidgets('offers retry and skip when transcription fails',
      (tester) async {
    await tester.pumpWidget(
        host(spec('abstraction-1'), asr: FakeAsrClient(throws: const AsrException('offline'))));

    await tester.tap(find.text('เริ่ม'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ส่งคำตอบ'));
    await tester.pumpAndSettle();

    expect(find.text('ลองใหม่'), findsOneWidget);
    expect(find.text('ข้าม'), findsOneWidget);
  });

  testWidgets('skipping records a skipped outcome and advances',
      (tester) async {
    await tester.pumpWidget(
        host(spec('abstraction-1'), asr: FakeAsrClient(throws: const AsrException('offline'))));

    await tester.tap(find.text('เริ่ม'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ส่งคำตอบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ข้าม'));
    await tester.pumpAndSettle();

    expect(find.text('NEXT PAGE'), findsOneWidget);
    expect(globals.voiceOutcomes['abstraction-1']!.skipped, isTrue);
  });

  testWidgets('a tap subtest shows a tap button instead of a mic button',
      (tester) async {
    await tester.pumpWidget(host(spec('vigilance')));

    await tester.tap(find.text('เริ่ม'));
    await tester.pump(const Duration(milliseconds: 1100));

    expect(find.text('เคาะ'), findsOneWidget);
    expect(find.text('ส่งคำตอบ'), findsNothing);

    await tester.pump(const Duration(milliseconds: 30000));
    await tester.pumpAndSettle();
  });
}
```

- [ ] **Step 2: Add the outcome map to score.dart**

Modify `lib/pages/score.dart`, adding at the end of the file:

```dart
// The nine voice/tap subtests record here rather than as individual ints,
// because unlike the original five they can be SKIPPED — a state an int cannot
// represent. summary.dart reads both.
Map<String, SubtestOutcome> voiceOutcomes = {};
```

and at the top, after `library score;`:

```dart
import 'package:moca_main/scoring/subtest_outcome.dart';
```

- [ ] **Step 3: Run to verify it fails**

```powershell
flutter test test/moca/voice_subtest_page_test.dart
```

Expected: FAIL — `voice_subtest_page.dart` URI doesn't exist.

- [ ] **Step 4: Implement**

Create `lib/moca/voice_subtest_page.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../pages/score.dart' as globals;
import 'asr_client.dart';
import 'audio_player.dart';
import 'audio_recorder.dart';
import 'session_controller.dart';
import 'subtest_spec.dart';

/// Renders any of the nine subtests from its spec. There is deliberately one
/// of these rather than nine pages: the record → transcribe → score → advance
/// pipeline exists once.
class VoiceSubtestPage extends StatefulWidget {
  final SubtestSpec spec;
  final String nextRoute;

  /// Injected by tests. Production builds a controller wired to the real
  /// microphone, speakers and endpoint.
  final SubtestSessionController Function(SubtestSpec)? controllerFactory;

  const VoiceSubtestPage({
    super.key,
    required this.spec,
    required this.nextRoute,
    this.controllerFactory,
  });

  @override
  State<VoiceSubtestPage> createState() => _VoiceSubtestPageState();
}

class _VoiceSubtestPageState extends State<VoiceSubtestPage> {
  late final SubtestSessionController _controller;
  Timer? _deadline;

  @override
  void initState() {
    super.initState();
    _controller = (widget.controllerFactory ?? _defaultController)(widget.spec);
    _controller.addListener(_onPhaseChanged);
  }

  SubtestSessionController _defaultController(SubtestSpec spec) =>
      SubtestSessionController(
        spec: spec,
        asr: HttpAsrClient(endpoint: Uri.parse(kDefaultAsrEndpoint)),
        recorder: DeviceVoiceRecorder(),
        playback: DeviceAudioPlayback(),
      );

  void _onPhaseChanged() {
    if (!mounted) return;

    if (_controller.phase == SessionPhase.recording &&
        widget.spec.enforceTimeLimit) {
      // Verbal fluency alone. Its 60 seconds is what the "11 or more words"
      // cutoff is normed against, so it is a real deadline rather than the
      // budget every other subtest carries.
      _deadline?.cancel();
      _deadline = Timer(
        Duration(seconds: widget.spec.timeLimitSec!),
        () {
          if (mounted && _controller.phase == SessionPhase.recording) {
            _controller.finishRecording();
          }
        },
      );
    }

    if (_controller.phase == SessionPhase.done) {
      _deadline?.cancel();
      globals.voiceOutcomes[widget.spec.id] = _controller.outcome!;
      Navigator.pushReplacementNamed(context, widget.nextRoute);
      return;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _controller.removeListener(_onPhaseChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.spec.section),
        backgroundColor: const Color.fromARGB(255, 87, 152, 225),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.spec.instructionTh,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ..._bodyForPhase(),
          ],
        ),
      ),
    );
  }

  List<Widget> _bodyForPhase() {
    switch (_controller.phase) {
      case SessionPhase.instruction:
        return [_button('เริ่ม', _controller.begin)];

      case SessionPhase.stimulus:
        return [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text('กำลังเล่นเสียง กรุณาฟัง'),
        ];

      case SessionPhase.recording:
        return [
          const Icon(Icons.mic, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('กำลังบันทึกเสียง'),
          const SizedBox(height: 24),
          _button('ส่งคำตอบ', _controller.finishRecording),
        ];

      case SessionPhase.tapping:
        return [
          _button('เคาะ', () async => _controller.recordTap()),
        ];

      case SessionPhase.scoring:
        return [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text('กำลังตรวจคำตอบ'),
        ];

      case SessionPhase.error:
        return [
          const Icon(Icons.error_outline, size: 48, color: Colors.orange),
          const SizedBox(height: 12),
          Text('เกิดข้อผิดพลาด: ${_controller.error ?? ''}',
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _button('ลองใหม่', () async => _controller.retry()),
          const SizedBox(height: 12),
          // Skip records that the subtest was never administered, which is not
          // the same as the patient scoring 0.
          _button('ข้าม', () async => _controller.skip()),
        ];

      case SessionPhase.done:
        return [const CircularProgressIndicator()];
    }
  }

  Widget _button(String label, Future<void> Function() onPressed) =>
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          textStyle:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () => onPressed(),
        child: Text(label),
      );
}
```

- [ ] **Step 5: Run to verify it passes**

```powershell
flutter test test/moca/voice_subtest_page_test.dart
```

Expected: PASS, 5 tests.

- [ ] **Step 6: Commit**

```powershell
git add lib/moca/voice_subtest_page.dart lib/pages/score.dart test/moca/voice_subtest_page_test.dart
git commit -m "feat: add the data-driven voice subtest screen"
```

---

### Task 18: Wire the nine screens into the session

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/pages/animal.dart:75` and `:111`
- Modify: `lib/pages/roiLobJed.dart:104`
- Modify: `lib/pages/reorder_images_page.dart:61`
- Modify: `lib/pages/home.dart` (`resetScores`)
- Test: `test/moca/session_flow_test.dart`

**Interfaces:**
- Consumes: `kVoiceSubtests` (14), `VoiceSubtestPage` (17)
- Produces: `Map<String, WidgetBuilder> voiceSubtestRoutes()` in `lib/moca/routes.dart`, and `String routeFor(String subtestId)`

- [ ] **Step 1: Write the failing test**

Create `test/moca/session_flow_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/routes.dart';
import 'package:moca_main/moca/subtests.dart';

void main() {
  test('every subtest has a route', () {
    final routes = voiceSubtestRoutes();
    for (final spec in kVoiceSubtests) {
      expect(routes.containsKey(routeFor(spec.id)), isTrue, reason: spec.id);
    }
  });

  test('routes are derived from ids, so they cannot drift apart', () {
    expect(routeFor('digit-span-forward'), '/digit-span-forward');
    expect(routeFor('orientation'), '/orientation');
  });

  // The order the session runs in. Serial 7s and Delayed Recall are existing
  // pages, so the chain deliberately hands off to and returns from them.
  test('the chain threads through the two existing pages', () {
    expect(nextRouteAfter('vigilance'), '/attention');
    expect(nextRouteAfter('verbal-fluency'), '/abstraction-1');
    expect(nextRouteAfter('abstraction-2'), '/reorderimages');
    expect(nextRouteAfter('orientation'), '/endpage');
  });

  test('the first three run back to back', () {
    expect(nextRouteAfter('digit-span-forward'), '/digit-span-backward');
    expect(nextRouteAfter('digit-span-backward'), '/vigilance');
  });

  test('sentence repetition runs after serial 7s', () {
    expect(nextRouteAfter('sentence-repetition-1'), '/sentence-repetition-2');
    expect(nextRouteAfter('sentence-repetition-2'), '/verbal-fluency');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/moca/session_flow_test.dart
```

Expected: FAIL — `routes.dart` URI doesn't exist.

- [ ] **Step 3: Implement the routing**

Create `lib/moca/routes.dart`:

```dart
import 'package:flutter/material.dart';

import 'subtests.dart';
import 'voice_subtest_page.dart';

/// Routes are derived from subtest ids so the two cannot drift apart.
String routeFor(String subtestId) => '/$subtestId';

/// Where each subtest hands off. Two entries point at existing pages:
/// vigilance hands off to Serial 7s, and abstraction-2 to Delayed Recall.
/// MoCA groups Digit Span and Vigilance with Serial 7s under Attention, and
/// puts Orientation last, after Delayed Recall.
const Map<String, String> _nextRoute = {
  'digit-span-forward': '/digit-span-backward',
  'digit-span-backward': '/vigilance',
  'vigilance': '/attention',
  'sentence-repetition-1': '/sentence-repetition-2',
  'sentence-repetition-2': '/verbal-fluency',
  'verbal-fluency': '/abstraction-1',
  'abstraction-1': '/abstraction-2',
  'abstraction-2': '/reorderimages',
  'orientation': '/endpage',
};

String nextRouteAfter(String subtestId) {
  final next = _nextRoute[subtestId];
  if (next == null) {
    throw ArgumentError('No next route registered for subtest "$subtestId"');
  }
  return next;
}

Map<String, WidgetBuilder> voiceSubtestRoutes() => {
      for (final spec in kVoiceSubtests)
        routeFor(spec.id): (_) => VoiceSubtestPage(
              spec: spec,
              nextRoute: nextRouteAfter(spec.id),
            ),
    };
```

- [ ] **Step 4: Register the routes**

In `lib/main.dart`, add the import:

```dart
import 'package:moca_main/moca/routes.dart';
```

and change the `routes:` map to spread the generated routes in. Replace:

```dart
        '/endpage': (context) => const EndPage(),
      },
```

with:

```dart
        '/endpage': (context) => const EndPage(),
        ...voiceSubtestRoutes(),
      },
```

- [ ] **Step 5: Rewire the three existing pages**

These are the only edits to existing subtest pages. Change the route string and nothing else.

In `lib/pages/animal.dart`, line 75, change `'/attention'` to `'/digit-span-forward'`:

```dart
        Navigator.pushReplacementNamed(context, '/digit-span-forward');
```

and line 111, the same:

```dart
                      Navigator.pushNamed(context, '/digit-span-forward');
```

In `lib/pages/roiLobJed.dart`, line 104, change `'/reorderimages'` to `'/sentence-repetition-1'`:

```dart
                Navigator.pushNamed(context, '/sentence-repetition-1');
```

In `lib/pages/reorder_images_page.dart`, line 61, change `'/endpage'` to `'/orientation'`:

```dart
    Navigator.pushNamed(context, '/orientation');
```

- [ ] **Step 6: Clear the new outcomes on restart**

In `lib/pages/home.dart`, add to `resetScores()`:

```dart
void resetScores() {
  animalScore = 0;
  larkScore = 0;
  clockScore = 0;
  totalScore = 0;
  attentionScore = 0;
  reorderScore = 0;
  voiceOutcomes.clear();
}
```

- [ ] **Step 7: Run the full suite**

```powershell
flutter test
```

Expected: PASS, everything.

- [ ] **Step 8: Commit**

```powershell
git add lib/moca/routes.dart lib/main.dart lib/pages/animal.dart lib/pages/roiLobJed.dart lib/pages/reorder_images_page.dart lib/pages/home.dart test/moca/session_flow_test.dart
git commit -m "feat: wire the nine voice subtests into the session flow"
```

---

### Task 19: Rescale the summary screen

**Files:**
- Create: `lib/scoring/session_total.dart`
- Modify: `lib/pages/summary.dart`
- Test: `test/scoring/session_total_test.dart`

**Interfaces:**
- Consumes: `SubtestOutcome` (4)
- Produces:
  - `class SessionTotal { final int score; final int maxScore; final List<String> skippedIds; bool get isComplete; String? get category; }`
  - `SessionTotal computeSessionTotal({required int larkScore, required int clockScore, required int animalScore, required int attentionScore, required int reorderScore, required Map<String, SubtestOutcome> voiceOutcomes})`

- [ ] **Step 1: Write the failing test**

Create `test/scoring/session_total_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/session_total.dart';
import 'package:moca_main/scoring/subtest_outcome.dart';

void main() {
  SubtestOutcome full(String id, int score, int max) =>
      SubtestOutcome(subtestId: id, score: score, maxScore: max);

  Map<String, SubtestOutcome> perfectVoice() => {
        'digit-span-forward': full('digit-span-forward', 1, 1),
        'digit-span-backward': full('digit-span-backward', 1, 1),
        'vigilance': full('vigilance', 1, 1),
        'sentence-repetition-1': full('sentence-repetition-1', 1, 1),
        'sentence-repetition-2': full('sentence-repetition-2', 1, 1),
        'verbal-fluency': full('verbal-fluency', 1, 1),
        'abstraction-1': full('abstraction-1', 1, 1),
        'abstraction-2': full('abstraction-2', 1, 1),
        'orientation': full('orientation', 6, 6),
      };

  SessionTotal totalWith(Map<String, SubtestOutcome> voice) =>
      computeSessionTotal(
        larkScore: 1,
        clockScore: 3,
        animalScore: 3,
        attentionScore: 3,
        reorderScore: 5,
        voiceOutcomes: voice,
      );

  test('a perfect session is 29 out of 29', () {
    final total = totalWith(perfectVoice());
    expect(total.score, 29);
    expect(total.maxScore, 29);
  });

  // The attainable ceiling is 29, not 30, because Cube copy is not implemented.
  test('a perfect session still clears the normal cutoff', () {
    expect(totalWith(perfectVoice()).category, 'ปกติ');
  });

  test('classifies MCI, moderate and severe on the published cutoffs', () {
    SessionTotal at(int orientationScore, int fluency) {
      final voice = perfectVoice();
      voice['orientation'] = full('orientation', orientationScore, 6);
      voice['verbal-fluency'] = full('verbal-fluency', fluency, 1);
      return totalWith(voice);
    }

    expect(at(1, 0).score, 23);
    expect(at(1, 0).category, 'บกพร่องเล็กน้อย');
    expect(at(0, 0).score, 22);
  });

  // A skipped subtest is excluded from BOTH sides. Counting it as 0/6 would
  // move a healthy patient across a band on a network failure.
  test('a skipped subtest shrinks the denominator, not just the score', () {
    final voice = perfectVoice();
    voice['orientation'] = SubtestOutcome.skippedFor('orientation');

    final total = totalWith(voice);
    expect(total.score, 23);
    expect(total.maxScore, 23);
    expect(total.skippedIds, ['orientation']);
  });

  // Fixed cutoffs are defined against a complete administration and mean
  // nothing against a partial one. Scaling them proportionally would look
  // helpful and be an invention.
  test('no category is assigned when anything was skipped', () {
    final voice = perfectVoice();
    voice['orientation'] = SubtestOutcome.skippedFor('orientation');

    final total = totalWith(voice);
    expect(total.isComplete, isFalse);
    expect(total.category, isNull);
  });

  test('a subtest never reached counts as skipped', () {
    final voice = perfectVoice()..remove('orientation');

    final total = totalWith(voice);
    expect(total.maxScore, 23);
    expect(total.category, isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/scoring/session_total_test.dart
```

Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implement**

Create `lib/scoring/session_total.dart`:

```dart
import '../moca/subtests.dart';
import 'subtest_outcome.dart';

/// The published MoCA cutoffs. These are defined against a complete 30-point
/// administration, which is why a partial session gets no category at all.
const _bands = <int, String>{
  26: 'ปกติ',
  18: 'บกพร่องเล็กน้อย',
  10: 'มีความบกพร่อง',
};

class SessionTotal {
  final int score;

  /// The sum of ADMINISTERED maxScores. A skipped subtest is excluded from
  /// both sides rather than counted as a failure.
  final int maxScore;

  final List<String> skippedIds;

  const SessionTotal({
    required this.score,
    required this.maxScore,
    required this.skippedIds,
  });

  bool get isComplete => skippedIds.isEmpty;

  /// Null when anything was skipped. Fixed cutoffs mean nothing against a
  /// partial administration, and scaling them proportionally would present an
  /// invented category with the same confidence as a real one.
  String? get category {
    if (!isComplete) return null;
    for (final entry in _bands.entries) {
      if (score >= entry.key) return entry.value;
    }
    return 'เสี่ยงสูง';
  }
}

SessionTotal computeSessionTotal({
  required int larkScore,
  required int clockScore,
  required int animalScore,
  required int attentionScore,
  required int reorderScore,
  required Map<String, SubtestOutcome> voiceOutcomes,
}) {
  // The original five always run and cannot be skipped.
  var score = larkScore + clockScore + animalScore + attentionScore + reorderScore;
  var maxScore = 1 + 3 + 3 + 3 + 5;
  final skipped = <String>[];

  for (final spec in kVoiceSubtests) {
    final outcome = voiceOutcomes[spec.id];
    // A subtest never reached is in the same position as one explicitly
    // skipped: it was not administered.
    if (outcome == null || outcome.skipped) {
      skipped.add(spec.id);
      continue;
    }
    score += outcome.score;
    maxScore += outcome.maxScore;
  }

  return SessionTotal(score: score, maxScore: maxScore, skippedIds: skipped);
}
```

- [ ] **Step 4: Run to verify it passes**

```powershell
flutter test test/scoring/session_total_test.dart
```

Expected: PASS, 7 tests.

- [ ] **Step 5: Rewrite summary.dart's scoring section**

In `lib/pages/summary.dart`, replace the `build` method's opening line:

```dart
    final int totalScore = larkScore + clockScore + animalScore + attentionScore + reorderScore;
```

with:

```dart
    final total = computeSessionTotal(
      larkScore: larkScore,
      clockScore: clockScore,
      animalScore: animalScore,
      attentionScore: attentionScore,
      reorderScore: reorderScore,
      voiceOutcomes: voiceOutcomes,
    );
```

Add these imports at the top of the file:

```dart
import 'package:moca_main/moca/subtests.dart';
import 'package:moca_main/scoring/session_total.dart';
```

Replace the result card call with one that handles the no-category case:

```dart
                  _buildResultCard(
                    title: "ผลการทดสอบเบื้องต้น",
                    content: total.category == null
                        ? "ไม่สามารถประเมินได้ เนื่องจากมีแบบทดสอบที่ถูกข้าม"
                        : "คุณเป็น: ${total.category}",
                    contentColor: _getResultColor(total),
                    icon: _getResultIcon(total),
                  ),
```

Replace the criteria card items:

```dart
                  _buildInfoCard(
                    title: "เกณฑ์การประเมิน (เต็ม 30 คะแนน):",
                    items: [
                      "26-30: ปกติ",
                      "18-25: บกพร่องเล็กน้อย",
                      "10-17: มีความบกพร่อง",
                      "0-9: เสี่ยงสูง - ควรเข้าพบปรึกษาแพทย์",
                      // Stated rather than left implicit: the drawing subtest
                      // is administered on paper by a clinician, so every
                      // patient here is scored one point below the scale.
                      "หมายเหตุ: แบบทดสอบนี้ยังไม่รวมข้อวาดรูปทรง (1 คะแนน)",
                    ],
                  ),
```

Replace the scores card call:

```dart
                  _buildScoresCard(
                    title: "คะแนนการทดสอบของคุณ:",
                    items: [
                      "แบบทดสอบลากเส้น: $larkScore/1",
                      "แบบทดสอบนาฬิกา: $clockScore/3",
                      "แบบทดสอบทายชื่อสัตว์: $animalScore/3",
                      "แบบทดสอบลบเลข: $attentionScore/3",
                      "แบบทดสอบความจำ: $reorderScore/5",
                      for (final spec in kVoiceSubtests)
                        "${spec.section} (${spec.id}): "
                            "${voiceOutcomes[spec.id] == null || voiceOutcomes[spec.id]!.skipped ? 'ข้าม' : '${voiceOutcomes[spec.id]!.score}/${spec.maxScore}'}",
                    ],
                    totalScore: "คะแนนรวมทั้งหมด: ${total.score}/${total.maxScore}",
                  ),
```

Finally replace the two helpers at the bottom of the file. Delete `_getResultCategory` entirely (its job now belongs to `SessionTotal.category`) and replace the other two:

```dart
  Color _getResultColor(SessionTotal total) {
    if (!total.isComplete) return Colors.grey.shade700;
    if (total.score >= 26) return Colors.green.shade700;
    if (total.score >= 18) return Colors.orange.shade700;
    if (total.score >= 10) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  IconData _getResultIcon(SessionTotal total) {
    if (!total.isComplete) return Icons.help_outline;
    if (total.score >= 26) return Icons.check_circle;
    if (total.score >= 18) return Icons.info;
    if (total.score >= 10) return Icons.warning;
    return Icons.error;
  }
```

- [ ] **Step 6: Run the full suite and the analyzer**

```powershell
flutter analyze
flutter test
```

Expected: analyzer clean of errors; all tests PASS.

- [ ] **Step 7: Commit**

```powershell
git add lib/scoring/session_total.dart lib/pages/summary.dart test/scoring/session_total_test.dart
git commit -m "feat: rescale summary to MoCA cutoffs with skip-aware totals"
```

---

### Task 20: Manual verification pass

Everything up to here is proven by tests that never touch a microphone, a speaker, or a network. This task is the part no test can cover. Nothing here is a code change unless it uncovers a defect.

**Files:**
- Create: `design_docs/superpowers/plans/2026-08-17-voice-subtests-verification.md`

**Interfaces:**
- Consumes: the whole app
- Produces: a written record of what was verified and what was not

- [ ] **Step 1: Confirm the suite and analyzer are clean**

```powershell
flutter test
flutter analyze
```

Record the test count. Expected: all pass.

- [ ] **Step 2: Launch on Windows**

```powershell
flutter run -d windows
```

- [ ] **Step 3: Verify audio playback actually works**

Walk to Digit Span forward and press เริ่ม. Confirm you HEAR the digits. This is the check that the WAV conversion in Task 2 succeeded end to end — the unit tests use a fake player and prove nothing about real audio.

If nothing plays, the problem is the asset path or `audioplayers` on Windows, not the scoring.

- [ ] **Step 4: Verify Vigilance timing by ear**

Run Vigilance. Listen for: a clear ~1 second silence before the first digit, then digits at a steady one-per-second, with **no** overlap between consecutive digits — particularly across the three consecutive `1`s at positions 18–20, which is where an uncut tail would be audible.

If digits overlap, `DigitSequencePlayer` is not cutting the previous file off. Do not "fix" it by lengthening the interval — the interval defines the scoring windows.

- [ ] **Step 5: Verify the microphone opens and only after playback**

On Digit Span forward, confirm the mic indicator appears only after the digits have finished sounding. If recording starts during playback, the invariant has broken in the real implementation despite the test passing — investigate `DeviceAudioPlayback.play` not awaiting completion.

- [ ] **Step 6: Verify the endpoint failure path**

With the backend not yet implementing `/transcribe`, pressing ส่งคำตอบ should produce the error screen with ลองใหม่ and ข้าม — not a crash, and not a score. Confirm ข้าม advances and that the summary shows ข้าม for that subtest and no category.

This is the expected state until the user supplies the Flask endpoint.

- [ ] **Step 7: Write the verification record**

Create `design_docs/superpowers/plans/2026-08-17-voice-subtests-verification.md` with, for each step above: what was run, what happened, and whether it passed. Explicitly list what is still unverified — real Thai transcription accuracy, the Sentence Repetition similarity threshold, and the Verbal Fluency segment count — since none of those can be checked until `/transcribe` exists.

- [ ] **Step 8: Commit**

```powershell
git add design_docs/superpowers/plans/2026-08-17-voice-subtests-verification.md
git commit -m "docs: record manual verification results for voice subtests"
```

---

### Task 21: Record content status and the remaining dependency

All fourteen points are built with real content. One external dependency remains — the `/transcribe` endpoint. This task makes that unambiguous rather than leaving it in a design document nobody re-reads, and records the two content pairings that no type system enforces.

**Files:**
- Create: `design_docs/CONTENT-STATUS.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: nothing
- Produces: a checklist the user can act on

- [ ] **Step 1: Write the content checklist**

Create `design_docs/CONTENT-STATUS.md`:

```markdown
# Content and configuration status

All 29 implemented points are built and tested. One external dependency
remains before the voice subtests can score anything.

## BLOCKING: the /transcribe endpoint

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

Two pairings are not enforced by any type and must be changed together:

- **`expectedSentence` and its `stimulusAsset`.** The scorer compares speech
  against the text while the patient hears the audio. Editing one without
  re-recording the other scores every patient against a sentence they never
  heard, and looks completely normal.
- **Verbal Fluency's `instructionTh` and `initialLetter`.** A patient told one
  thing and scored on another produces what reads as a cognitive deficit.
  Setting `initialLetter` to null switches to category mode, where every
  distinct word counts.

## Known limitation: Orientation is not configurable at runtime

`session_config.dart` hardcodes place and province. An Orientation score is
only meaningful if they match where the patient actually is, so a deployment to
a second site needs the settings screen described in the TODO there.
```

- [ ] **Step 2: Point at it from the README**

Add to the end of `README.md`:

```markdown
## MoCA subtest coverage

29 of 30 points are implemented. Cube copy is administered on paper.

Voice scoring (13 of those points) requires a `/transcribe` endpoint on the
backend, which is not deployed yet — until it is, those subtests can only be
skipped. Vigilance needs no backend. See
[design_docs/CONTENT-STATUS.md](design_docs/CONTENT-STATUS.md) for the
contract and for the test content that must be changed in pairs.
```

- [ ] **Step 3: Commit**

```powershell
git add design_docs/CONTENT-STATUS.md README.md
git commit -m "docs: list the content still needed to finish the last 3 points"
```

---

## Self-review notes

**Spec coverage.** Every section of the design document maps to a task:
layering → Tasks 3–17; session flow → Task 18; `/transcribe` contract → Task 11;
skip-is-not-zero → Tasks 4, 16, 19; summary rescale → Task 19; phase machine →
Task 16; the four direct-port scorers → Tasks 5–8; the three risky ones →
Tasks 9, 10, 13; testing → carried inside each task; assets → Task 2;
dependencies on the user → Task 21.

**Two things this plan adds that the spec did not specify.** Task 1 (the stale
`flutter create` test fails on a clean checkout, so no later task could claim a
green suite) and Task 2's WAV conversion path via PyAV (the spec flagged the
QuickTime containers as a risk; this resolves it, verified, with no install).

**One deliberate omission.** `extractNumberSequence` from ad_hw's matchers is
not ported. Its only consumer is Serial 7s, which moca_app already implements
as a typed test, so porting it would add dead code and tests that guard nothing.

**Three defects found and fixed during self-review**, recorded because each one
would have shipped as working code:

1. **Sentence Repetition would have recorded the patient anyway.** The first
   draft gave it `stimulusAsset: null` to mean "recording missing". But null
   already means "no stimulus by design" — which is true of Abstraction and
   Orientation, where the controller opens the microphone immediately. The
   controller could not tell the two apart, so it would have skipped the
   missing-file check entirely and recorded a patient answering a sentence
   that never played. Fixed by declaring the path and skipping when the file
   fails to load; the distinction is now pinned by two tests.

2. **A test that would pass while asserting nothing.** With a real asset path
   declared, the existence check runs against `rootBundle` — whose behaviour
   under `flutter test` is not dependable. A false negative there would make
   Digit Span skip silently, and the mic-order test would keep passing having
   exercised no microphone at all. Fixed by injecting `assetExists`, so no
   test's result depends on asset resolution.

3. **A layering inversion.** `AsrSegment` started out inside
   `verbal_fluency.dart`, which forced `lib/moca/asr_client.dart` to import a
   scorer to get at a data class. Moved to its own leaf file.
