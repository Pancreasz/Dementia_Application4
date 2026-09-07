import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/app_language.dart';
import 'package:moca_main/moca/event_trace.dart';
import 'package:moca_main/moca/live_session.dart';
import 'package:moca_main/moca/naming_keyboard.dart';
import 'package:moca_main/moca/session_record.dart';
import 'package:moca_main/moca/session_store.dart';
import 'package:moca_main/pages/animal.dart';
import 'package:moca_main/pages/score.dart' as globals;

/// In-memory, because `testWidgets` runs in a fake-async zone that never
/// completes real file I/O — a widget test against the real SessionStore hangs
/// rather than fails. Same reason as `home_resume_test.dart`.
class _FakeStore implements SessionStore {
  @override
  Future<void> save(SessionRecord record) async {}
  @override
  Future<SessionRecord?> load(String id) async => null;
  @override
  Future<List<SessionRecord>> loadAll() async => const [];
  @override
  Future<SessionRecord?> loadResumable() async => null;
  @override
  Future<void> delete(String id) async {}
}

void main() {
  setUp(() {
    LiveSession.clearCurrent();
    globals.animalScore = 0;
    AppLanguage.current = Language.th;
  });

  tearDown(() {
    LiveSession.clearCurrent();
    AppLanguage.current = Language.th;
  });

  group('the keyboard itself', () {
    testWidgets('offers the whole Thai alphabet, not just the answers',
        (tester) async {
      // A keyboard holding only the letters of สิงโต / อูฐ / แรด would turn
      // naming into a puzzle over a tiny search space, which is a different
      // task with a different difficulty.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NamingKeyboard(onCharacter: (_) {}, onBackspace: () {}),
          ),
        ),
      ));
      expect(kThaiConsonants, hasLength(44));
      for (final consonant in ['ก', 'ฮ', 'ฃ', 'ฅ']) {
        expect(find.text(consonant), findsOneWidget, reason: consonant);
      }
      // Marks render with a dotted circle so a bare diacritic has something
      // to attach to.
      expect(find.text('◌ิ'), findsOneWidget);
    });

    testWidgets('switches to the Latin alphabet in English mode',
        (tester) async {
      AppLanguage.current = Language.en;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NamingKeyboard(onCharacter: (_) {}, onBackspace: () {}),
          ),
        ),
      ));
      expect(find.text('a'), findsOneWidget);
      expect(find.text('z'), findsOneWidget);
      expect(find.text('ก'), findsNothing);
    });

    testWidgets('every key is the same size, so layout is not a variable',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NamingKeyboard(onCharacter: (_) {}, onBackspace: () {}),
          ),
        ),
      ));
      final first = tester.getSize(find.ancestor(
        of: find.text('ก'),
        matching: find.byType(SizedBox),
      ).first);
      final last = tester.getSize(find.ancestor(
        of: find.text('ฮ'),
        matching: find.byType(SizedBox),
      ).first);
      expect(first, last);
      expect(first.width, keyWidth);
    });
  });

  group('the standard layout', () {
    Future<List<String>> typed(
      WidgetTester tester,
      Future<void> Function(WidgetTester) actions, {
      Language language = Language.th,
    }) async {
      AppLanguage.current = language;
      final out = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NamingKeyboard(
              layout: NamingKeyboardLayout.standard,
              onCharacter: out.add,
              onBackspace: () {},
            ),
          ),
        ),
      ));
      await actions(tester);
      return out;
    }

    testWidgets('prints both legends, shifted above unshifted', (tester) async {
      await typed(tester, (t) async {});
      // 6 on Kedmanee: ุ unshifted, ู with shift. Both are combining marks, so
      // both are drawn on a dotted circle.
      final base = tester.getTopLeft(find.text('◌ุ'));
      final upper = tester.getTopLeft(find.text('◌ู'));
      expect(upper.dy, lessThan(base.dy),
          reason: 'the shifted character belongs on top, as on a real keycap');
      // Same key, so the same column.
      expect((upper.dx - base.dx).abs(), lessThan(standardKeyWidth));
    });

    testWidgets('types the unshifted character by default', (tester) async {
      final out = await typed(tester, (t) async {
        await t.tap(find.text('ก'));
        await t.pump();
      });
      expect(out, ['ก']);
    });

    testWidgets('shift types the character printed on top', (tester) async {
      // อูฐ needs shift+6 for ู, so this is not a hypothetical: one of the
      // three test words is untypeable without shift.
      final out = await typed(tester, (t) async {
        await t.tap(find.byIcon(Icons.arrow_upward));
        await t.pump();
        await t.tap(find.text('◌ุ'));
        await t.pump();
      });
      expect(out, ['ู']);
    });

    testWidgets('shift releases itself after one key', (tester) async {
      final out = await typed(tester, (t) async {
        await t.tap(find.byIcon(Icons.arrow_upward));
        await t.pump();
        await t.tap(find.text('ด'));
        await t.pump();
        await t.tap(find.text('ด'));
        await t.pump();
      });
      // shift+f is โ; the second press is the plain key again.
      expect(out, ['โ', 'ด']);
    });

    testWidgets('all three Thai animal names are typeable on it',
        (tester) async {
      final available = {
        for (final row in kThaiStandardRows)
          for (final cap in row) ...[cap.base, if (cap.shifted != null) cap.shifted!],
      };
      for (final word in ['สิงโต', 'อูฐ', 'แรด']) {
        for (final character in word.split('')) {
          expect(available, contains(character),
              reason: '$character of $word is not on the Kedmanee layout');
        }
      }
    });

    testWidgets('uses QWERTY with capitals in English mode', (tester) async {
      final out = await typed(tester, (t) async {
        await t.tap(find.byIcon(Icons.arrow_upward));
        await t.pump();
        await t.tap(find.text('q'));
        await t.pump();
      }, language: Language.en);
      expect(out, ['Q']);
      expect(find.text('Q'), findsOneWidget);
    });

    testWidgets('draws standing vowels without a dotted circle', (tester) async {
      // เ แ โ ใ ไ sit on the line like a consonant. Printing them as ◌เ was a
      // real bug in the first version of this keyboard.
      expect(keyLabel('เ'), 'เ');
      expect(keyLabel('ๆ'), 'ๆ');
      // Combining marks do get one, because a bare diacritic has nothing to
      // attach to.
      expect(keyLabel('ิ'), '◌ิ');
      expect(keyLabel('่'), '◌่');
    });
  });

  group('the naming page', () {
    Future<void> open(WidgetTester tester) async {
      await LiveSession.start(store: _FakeStore());
      await tester.pumpWidget(MaterialApp(
        home: const AnimalMocaTestPage(),
        routes: {'/digit-span-forward': (_) => const Scaffold(body: Text('NEXT'))},
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();
    }

    Future<void> press(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.text(key));
      await tester.pumpAndSettle();
      await tester.tap(find.text(key));
      await tester.pumpAndSettle();
    }

    testWidgets('never opens a system text field', (tester) async {
      // The whole reason this keyboard exists: a TextField here would bring
      // autocorrect and Thai word prediction with it, and prediction can
      // supply the exact word being tested.
      await open(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(EditableText), findsNothing);
    });

    testWidgets('typed characters appear in the answer box', (tester) async {
      await open(tester);
      await press(tester, 'ก');
      await press(tester, 'ข');
      expect(find.text('กข'), findsOneWidget);
    });

    testWidgets('backspace removes the last character', (tester) async {
      await open(tester);
      await press(tester, 'ก');
      await press(tester, 'ข');
      await tester.ensureVisible(find.byIcon(Icons.backspace_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pumpAndSettle();
      expect(find.text('ก'), findsWidgets); // the key is still on screen
      expect(find.text('กข'), findsNothing);
    });

    testWidgets('records a key event per keystroke, not a finished string',
        (tester) async {
      await open(tester);
      await press(tester, 'ก');
      await press(tester, 'ข');

      final events = LiveSession.current!.trace.forSubtest('naming');
      final keys =
          events.where((e) => e.type == TraceEventType.keyPressed).toList();
      expect(keys, hasLength(2));
      expect(keys.first.data['key'], 'ก');
      expect(keys.last.data['key'], 'ข');
      // Offsets, so an inter-key interval is recoverable later. A stored
      // interval could never be turned back into a variance.
      expect(keys.last.atMs, greaterThanOrEqualTo(keys.first.atMs));
    });

    testWidgets('marks when each picture appeared, to time retrieval from',
        (tester) async {
      await open(tester);
      final shown = LiveSession.current!.trace
          .forSubtest('naming')
          .where((e) => e.type == TraceEventType.itemShown);
      expect(shown, hasLength(1));
      expect(shown.first.data['itemIndex'], 0);
      expect(shown.first.data['target'], isNotEmpty);
    });

    testWidgets('backspace is a distinct event from a keystroke',
        (tester) async {
      await open(tester);
      await press(tester, 'ก');
      await tester.ensureVisible(find.byIcon(Icons.backspace_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pumpAndSettle();

      final events = LiveSession.current!.trace.forSubtest('naming');
      expect(events.where((e) => e.type == TraceEventType.keyDeleted),
          hasLength(1));
    });

    testWidgets('backspace on an empty answer records nothing', (tester) async {
      await open(tester);
      await tester.ensureVisible(find.byIcon(Icons.backspace_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pumpAndSettle();
      expect(
          LiveSession.current!.trace
              .forSubtest('naming')
              .where((e) => e.type == TraceEventType.keyDeleted),
          isEmpty);
    });

    testWidgets('keeps the answer that was given, not just whether it matched',
        (tester) async {
      // "camle" and a blank are both wrong and are not the same finding;
      // nothing can separate them from a score of 2/3.
      await open(tester);
      await press(tester, 'ก');
      await tester.ensureVisible(find.text('ส่งคำตอบ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ส่งคำตอบ'));
      await tester.pumpAndSettle();

      final submitted = LiveSession.current!.trace
          .forSubtest('naming')
          .where((e) => e.type == TraceEventType.submitted)
          .toList();
      expect(submitted, hasLength(1));
      expect(submitted.first.data['answer'], 'ก');
      expect(submitted.first.data['correct'], false);
      expect(submitted.first.data['target'], isNotEmpty);
    });

    testWidgets('offers both layouts and starts on the alphabetical one',
        (tester) async {
      await open(tester);
      expect(find.text('เรียงตามตัวอักษร'), findsOneWidget);
      expect(find.text('แป้นพิมพ์ปกติ (เกษมณี)'), findsOneWidget);
      // The alphabetical grid puts every character on screen at once; Kedmanee
      // hides half of them behind shift. ฐ is shift+[ on Kedmanee, so its
      // presence as a plain key means the grid is showing.
      expect(find.text('ฐ'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
    });

    testWidgets('switching layout swaps the keys and is recorded',
        (tester) async {
      await open(tester);
      await tester.ensureVisible(find.text('แป้นพิมพ์ปกติ (เกษมณี)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('แป้นพิมพ์ปกติ (เกษมณี)'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

      final changes = LiveSession.current!.trace
          .forSubtest('naming')
          .where((e) => e.type == 'keyboard-layout')
          .toList();
      expect(changes, hasLength(1));
      expect(changes.single.data['layout'], 'standard');
    });

    testWidgets('records which layout each item was typed on', (tester) async {
      // Without this a session that switched layouts would produce a
      // within-patient typing baseline built from two different tasks, and
      // nothing would say so.
      await open(tester);
      final shown = LiveSession.current!.trace
          .forSubtest('naming')
          .firstWhere((e) => e.type == TraceEventType.itemShown);
      expect(shown.data['layout'], 'alphabetical');
    });

    testWidgets('shows the next picture and marks it', (tester) async {
      await open(tester);
      await tester.ensureVisible(find.text('ส่งคำตอบ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ส่งคำตอบ'));
      await tester.pumpAndSettle();

      final shown = LiveSession.current!.trace
          .forSubtest('naming')
          .where((e) => e.type == TraceEventType.itemShown)
          .toList();
      expect(shown, hasLength(2));
      expect(shown.last.data['itemIndex'], 1);
    });
  });
}
