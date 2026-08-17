import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/pages/score.dart';
import 'package:moca_main/pages/summary.dart';
import 'package:moca_main/scoring/subtest_outcome.dart';

void main() {
  setUp(() {
    larkScore = 1;
    clockScore = 3;
    animalScore = 3;
    attentionScore = 3;
    reorderScore = 5;
    voiceOutcomes = {
      'digit-span-forward':
          const SubtestOutcome(subtestId: 'digit-span-forward', score: 1, maxScore: 1),
      'digit-span-backward':
          const SubtestOutcome(subtestId: 'digit-span-backward', score: 1, maxScore: 1),
      'vigilance': const SubtestOutcome(subtestId: 'vigilance', score: 1, maxScore: 1),
      'sentence-repetition-1':
          const SubtestOutcome(subtestId: 'sentence-repetition-1', score: 1, maxScore: 1),
      'sentence-repetition-2':
          const SubtestOutcome(subtestId: 'sentence-repetition-2', score: 1, maxScore: 1),
      'verbal-fluency': const SubtestOutcome(subtestId: 'verbal-fluency', score: 1, maxScore: 1),
      'abstraction-1': const SubtestOutcome(subtestId: 'abstraction-1', score: 1, maxScore: 1),
      'abstraction-2': const SubtestOutcome(subtestId: 'abstraction-2', score: 1, maxScore: 1),
      'orientation': const SubtestOutcome(subtestId: 'orientation', score: 6, maxScore: 6),
    };
  });

  tearDown(() {
    larkScore = 0;
    clockScore = 0;
    animalScore = 0;
    attentionScore = 0;
    reorderScore = 0;
    voiceOutcomes = {};
  });

  testWidgets('shows the category text when the session is complete',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: EndPage()));

    expect(find.text('คุณเป็น: ปกติ'), findsOneWidget);
    expect(find.textContaining('ไม่สามารถประเมินได้'), findsNothing);
  });

  testWidgets('shows the no-category message when a subtest was skipped',
      (WidgetTester tester) async {
    voiceOutcomes['orientation'] = SubtestOutcome.skippedFor('orientation');

    await tester.pumpWidget(const MaterialApp(home: EndPage()));

    expect(
      find.text('ไม่สามารถประเมินได้ เนื่องจากมีแบบทดสอบที่ถูกข้าม'),
      findsOneWidget,
    );
    expect(find.textContaining('คุณเป็น:'), findsNothing);
  });
}
