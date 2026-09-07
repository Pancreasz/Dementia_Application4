import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/activities.dart';
import 'package:moca_main/moca/app_language.dart';
import 'package:moca_main/pages/activities.dart';

void main() {
  tearDown(() => AppLanguage.current = Language.th);

  group('the content itself', () {
    test('every domain has activities in both languages', () {
      for (final domain in kActivityDomains) {
        expect(domain.activitiesTh, isNotEmpty, reason: domain.id);
        expect(domain.activitiesEn, isNotEmpty, reason: domain.id);
        expect(domain.nameTh, isNotEmpty, reason: domain.id);
        expect(domain.nameEn, isNotEmpty, reason: domain.id);
      }
    });

    test('domain ids are unique', () {
      final ids = kActivityDomains.map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('covers the six MoCA domains', () {
      expect(
        kActivityDomains.map((d) => d.id),
        containsAll([
          'visuospatial-executive',
          'naming-language',
          'attention',
          'memory',
          'abstraction-reasoning',
          'orientation',
        ]),
      );
    });

    test('a domain can be looked up by id', () {
      expect(domainById('memory')!.nameEn, 'Memory');
      expect(domainById('not-a-domain'), isNull);
    });
  });

  // The most important test on this page. Practising trail-making, digit span,
  // serial 7s or letter fluency contaminates the patient's own follow-up
  // screening: practice effects make a repeat MoCA uninterpretable against its
  // norms. An app that scores a patient and then hands them practice at the
  // same tasks can invalidate their next assessment.
  //
  // If this test fails, an activity was added that resembles a subtest. That is
  // a bug, not an enhancement — remove the activity rather than the assertion.
  group('no MoCA-like task is ever recommended', () {
    // Matched against the English text; the Thai list is checked separately by
    // its own terms below.
    const forbiddenEn = [
      'trail',
      'digit span',
      'serial 7',
      'subtract',
      'count backward',
      'counting backward',
      'memorise a list',
      'memorize a list',
      'clock drawing',
      'draw a clock',
    ];

    test('English activities contain no subtest-like practice', () {
      for (final domain in kActivityDomains) {
        for (final activity in domain.activitiesEn) {
          final lower = activity.toLowerCase();
          for (final banned in forbiddenEn) {
            expect(lower, isNot(contains(banned)),
                reason: '"$activity" in ${domain.id} resembles a MoCA subtest');
          }
        }
      }
    });

    test('Thai activities contain no subtest-like practice', () {
      const forbiddenTh = [
        'ลากเส้น', // trail making
        'ลบเลข', // serial subtraction
        'ทวนตัวเลข', // digit span
        'วาดนาฬิกา', // clock drawing
      ];
      for (final domain in kActivityDomains) {
        for (final activity in domain.activitiesTh) {
          for (final banned in forbiddenTh) {
            expect(activity, isNot(contains(banned)),
                reason: '"$activity" in ${domain.id} resembles a MoCA subtest');
          }
        }
      }
    });

    test('letter-based word games are excluded from the language domain', () {
      // Verbal fluency is "words beginning with ก", so a word game based on
      // initial letters IS that subtest. The word-games activity therefore has
      // to carry its exclusion in the text — "word games" on its own would
      // read as permission to play exactly the wrong kind.
      AppLanguage.current = Language.en;
      final language = domainById('naming-language')!;
      final wordGames = language.activitiesEn
          .where((a) => a.toLowerCase().contains('word game'));
      expect(wordGames, isNotEmpty);
      for (final activity in wordGames) {
        expect(activity.toLowerCase(), contains('not based on initial letters'));
      }
      // And the reason is stated on the page, not just silently applied.
      expect(language.note, contains('deliberately left'));
    });
  });

  group('the page does not overclaim', () {
    test('no activity promises an improvement', () {
      AppLanguage.current = Language.en;
      const promises = ['improve your score', 'will improve', 'cures', 'prevents'];
      for (final domain in kActivityDomains) {
        for (final activity in domain.activitiesEn) {
          for (final promise in promises) {
            expect(activity.toLowerCase(), isNot(contains(promise)),
                reason: domain.id);
          }
        }
      }
    });

    test('memory is framed as compensation, not repair', () {
      AppLanguage.current = Language.en;
      final memory = domainById('memory')!;
      expect(memory.note, contains('not exercises that repair memory'));
    });

    test('the general recommendations lead with physical activity', () {
      // The strongest single recommendation on the page. A list that buries it
      // gets the strength of the evidence backwards.
      AppLanguage.current = Language.en;
      expect(generalRecommendations.first.toLowerCase(),
          contains('physical activity'));
      expect(generalRecommendations.first, contains('strongest'));
    });

    test('the required framing states all three things', () {
      AppLanguage.current = Language.en;
      final text = requiredFraming.join(' ').toLowerCase();
      expect(text, contains('not treatment'));
      expect(text, contains('screening'));
      expect(text, contains('doctor'));
    });

    test('the framing exists in Thai too', () {
      AppLanguage.current = Language.th;
      expect(requiredFraming.length, 3);
      for (final line in requiredFraming) {
        expect(line, isNotEmpty);
      }
    });
  });

  group('the page renders', () {
    Future<void> pump(WidgetTester tester) =>
        tester.pumpWidget(const MaterialApp(home: ActivitiesPage()));

    testWidgets('shows the disclaimer above the activities', (tester) async {
      // A reader who stops halfway down the page must still have read it.
      AppLanguage.current = Language.en;
      await pump(tester);

      final framing = tester.getTopLeft(find.text('• ${requiredFraming.first}'));
      final firstDomain =
          tester.getTopLeft(find.text(kActivityDomains.first.nameEn));
      expect(framing.dy, lessThan(firstDomain.dy));
    });

    testWidgets('shows every domain', (tester) async {
      AppLanguage.current = Language.en;
      await pump(tester);
      for (final domain in kActivityDomains) {
        await tester.scrollUntilVisible(find.text(domain.nameEn), 200);
        expect(find.text(domain.nameEn), findsOneWidget);
      }
    });

    testWidgets('shows the general recommendations', (tester) async {
      AppLanguage.current = Language.en;
      await pump(tester);
      expect(find.text('For everyone'), findsOneWidget);
    });

    testWidgets('renders in Thai by default', (tester) async {
      AppLanguage.current = Language.th;
      await pump(tester);
      expect(find.text('กิจกรรมที่ช่วยกระตุ้นสมอง'), findsOneWidget);
    });

    testWidgets('is identical whatever the patient scored', (tester) async {
      // Not personalised, deliberately: highlighting "your weak domains" turns
      // a screening result into a prescription the evidence does not support.
      // The page takes no score input at all, which is what this asserts.
      AppLanguage.current = Language.en;
      await pump(tester);
      expect(find.byType(ActivitiesPage), findsOneWidget);
      for (final domain in kActivityDomains) {
        await tester.scrollUntilVisible(find.text(domain.nameEn), 200);
        expect(find.text(domain.nameEn), findsOneWidget);
      }
    });
  });
}
