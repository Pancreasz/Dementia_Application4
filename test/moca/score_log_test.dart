import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/score_log.dart';
import 'package:moca_main/scoring/subtest_outcome.dart';

void main() {
  late List<String> lines;
  late DebugPrintCallback original;

  setUp(() {
    lines = [];
    original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => lines.add(message ?? '');
  });

  tearDown(() => debugPrint = original);

  group('voice subtests', () {
    test('prints what the patient said alongside the score', () {
      logSubtestOutcome(const SubtestOutcome(
        subtestId: 'sentence-repetition-1',
        score: 1,
        maxScore: 1,
        transcript: 'ฉันรู้ว่าจอมเป็นคนเดียวที่มาช่วยงานวันนี้',
      ));

      expect(lines, hasLength(1));
      expect(lines.single, contains('sentence-repetition-1'));
      expect(lines.single, contains('1/1'));
      // The whole point: the transcript is otherwise written and never read.
      expect(lines.single,
          contains('heard: "ฉันรู้ว่าจอมเป็นคนเดียวที่มาช่วยงานวันนี้"'));
    });

    test('prints a wrong answer just as fully as a right one', () {
      // A 0 is exactly when someone needs to see what was actually heard —
      // it distinguishes a real deficit from a recognizer failure.
      logSubtestOutcome(const SubtestOutcome(
        subtestId: 'digit-span-forward',
        score: 0,
        maxScore: 1,
        transcript: 'สอง หนึ่ง แปด',
        detail: {'spoken': '218', 'expected': '21854'},
      ));

      expect(lines.single, contains('0/1'));
      expect(lines.single, contains('heard: "สอง หนึ่ง แปด"'));
      expect(lines.single, contains('spoken=218'));
      expect(lines.single, contains('expected=21854'));
    });

    test('a skip is reported as never administered, not as zero', () {
      logSubtestOutcome(SubtestOutcome.skippedFor('orientation'));

      final line = lines.single;
      expect(line, contains('orientation'));
      expect(line, contains('SKIPPED'));
      // Printing "0/6" here would read as the patient having failed all six.
      expect(line, isNot(contains('0/6')));
      expect(line, isNot(contains('0/0')));
    });

    test('a tap subtest with no transcript omits the heard clause', () {
      logSubtestOutcome(const SubtestOutcome(
        subtestId: 'vigilance',
        score: 1,
        maxScore: 1,
        detail: {'hits': 5, 'falseTaps': 0},
      ));

      expect(lines.single, contains('1/1'));
      expect(lines.single, contains('hits=5'));
      expect(lines.single, isNot(contains('heard:')));
    });
  });

  group('clock', () {
    test('prints the score the backend returned', () {
      logClockScore(2, filename: 'drawing_1.png');

      expect(lines.single, contains('clock'));
      expect(lines.single, contains('2'));
      expect(lines.single, contains('drawing_1.png'));
    });

    test('flags a non-int score, which is the crash-the-app case', () {
      // clock.dart assigns predicted_moca_score straight to a Dart int, so a
      // 2.0 throws inside a try that only catches JSON errors and surfaces as
      // "Error parsing server response" — a message that points nowhere near
      // the real cause.
      logClockScore(2.0);

      expect(lines.single, contains('expected an int'));
      expect(lines.single, contains('double'));
    });

    test('a well-formed int score is not flagged', () {
      logClockScore(3);
      expect(lines.single, isNot(contains('expected an int')));
    });
  });

  test('every line carries the [MoCA] tag so it is greppable in a busy console',
      () {
    logClockScore(1);
    logSubtestOutcome(const SubtestOutcome(
        subtestId: 'abstraction-1', score: 1, maxScore: 1));
    logSubtestOutcome(SubtestOutcome.skippedFor('verbal-fluency'));

    expect(lines, hasLength(3));
    expect(lines.every((l) => l.startsWith('[MoCA]')), isTrue);
  });
}
