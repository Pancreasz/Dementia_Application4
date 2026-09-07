import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/analysis/domain_analysis.dart';
import 'package:moca_main/moca/app_language.dart';
import 'package:moca_main/moca/session_record.dart';
import 'package:moca_main/pages/activities.dart';
import 'package:moca_main/pages/analysis.dart';
import 'package:moca_main/scoring/subtest_outcome.dart';

void main() {
  setUp(() => AppLanguage.current = Language.en);
  tearDown(() => AppLanguage.current = Language.th);

  SessionRecord record({
    int larkScore = 1,
    int clockScore = 3,
    int animalScore = 3,
    int attentionScore = 3,
    int reorderScore = 5,
    Map<String, SubtestOutcome> voiceOutcomes = const {},
  }) =>
      SessionRecord(
        id: 'test',
        startedAt: DateTime(2026, 9, 7),
        larkScore: larkScore,
        clockScore: clockScore,
        animalScore: animalScore,
        attentionScore: attentionScore,
        reorderScore: reorderScore,
        voiceOutcomes: voiceOutcomes,
      );

  Future<void> pump(WidgetTester tester, SessionRecord r) async {
    await tester.pumpWidget(MaterialApp(
      home: AnalysisPage(record: r),
      routes: {
        '/endpage': (_) => const Scaffold(body: Text('SCORE PAGE')),
        '/activities': (_) => const ActivitiesPage(),
      },
    ));
    await tester.pump();
  }

  testWidgets('the framing is shown before any domain', (tester) async {
    await pump(tester, record());
    for (final line in analysisFraming) {
      expect(find.text('• $line'), findsOneWidget);
    }
    // Above the first domain card, not a footnote — a reader who stops
    // halfway down the page has still read it.
    final framing = tester.getTopLeft(find.text('• ${analysisFraming.first}'));
    final firstDomain = tester.getTopLeft(find.text('Visuospatial / Executive'));
    expect(framing.dy, lessThan(firstDomain.dy));
  });

  testWidgets('every MoCA domain gets a card', (tester) async {
    await pump(tester, record());
    for (final name in [
      'Visuospatial / Executive',
      'Naming',
      'Attention',
      'Language',
      'Abstraction',
      'Delayed recall',
      'Orientation',
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('the points are stated under the level', (tester) async {
    await pump(tester, record(larkScore: 1, clockScore: 2));
    expect(find.text('Scored 3 out of 4'), findsOneWidget);
  });

  testWidgets('a domain with nothing administered says so instead of scoring it',
      (tester) async {
    await pump(tester, record());
    // No voice outcomes were supplied, so Language was never administered.
    expect(find.text('None of this area was administered'), findsWidgets);
    expect(find.text('Not administered'), findsWidgets);
  });

  testWidgets('full marks and no points read as different labels', (tester) async {
    await pump(tester, record(animalScore: 3, reorderScore: 0));
    expect(find.text('Full marks'), findsWidgets);
    expect(find.text('No points'), findsWidgets);
  });

  testWidgets('skipped subtests are named, not silently dropped', (tester) async {
    await pump(tester, record(voiceOutcomes: {
      'abstraction-1': const SubtestOutcome(
          subtestId: 'abstraction-1', score: 1, maxScore: 1),
      'abstraction-2': SubtestOutcome.skippedFor('abstraction-2'),
    }));
    expect(find.textContaining('Skipped: Watch and ruler'), findsOneWidget);
  });

  testWidgets('an observation from the stored detail reaches the screen',
      (tester) async {
    await pump(tester, record(clockScore: 2));
    expect(find.textContaining('the hands were not set'), findsOneWidget);
  });

  testWidgets('the total score is reached from here, not shown here',
      (tester) async {
    // The ordering is the whole reason this page comes first: the number is
    // what gets remembered, and seen first it turns everything else into
    // commentary on a verdict already delivered.
    await pump(tester, record());
    expect(find.text('SCORE PAGE'), findsNothing);

    // Below the fold: the button sits under all seven domains, which is the
    // point — the detail is not something to scroll past on the way to a number.
    await tester.ensureVisible(find.text('See the total score'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See the total score'));
    await tester.pumpAndSettle();
    expect(find.text('SCORE PAGE'), findsOneWidget);
  });

  testWidgets('each domain links into the activities for that area',
      (tester) async {
    await pump(tester, record());
    final link = find.text('Activities that engage this area');
    expect(link, findsNWidgets(7));

    await tester.tap(link.first);
    await tester.pumpAndSettle();
    // Arrived at the activities page, with every domain still present — the
    // link focuses one, it does not filter the page down to it.
    expect(find.text('Visuospatial / Executive'), findsOneWidget);
    expect(find.text('Orientation'), findsOneWidget);
  });

  testWidgets('renders in Thai as well', (tester) async {
    AppLanguage.current = Language.th;
    await pump(tester, record());
    expect(find.text('ผลแยกตามด้าน'), findsOneWidget);
    expect(find.text('สมาธิ'), findsOneWidget);
  });
}
