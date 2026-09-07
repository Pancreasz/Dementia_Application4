import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/app_language.dart';
import 'package:moca_main/moca/live_session.dart';
import 'package:moca_main/moca/session_record.dart';
import 'package:moca_main/moca/session_store.dart';
import 'package:moca_main/pages/home.dart';
import 'package:moca_main/pages/score.dart' as globals;

/// The resume offer on the home page.
///
/// This is what makes the persistence layer readable as well as writable —
/// without it sessions would be saved faithfully and never handed back.
///
/// The store here is IN-MEMORY, not the real file-backed one. That is not
/// laziness: `testWidgets` runs inside a fake-async zone that never completes
/// real file I/O, so a widget test against the real `SessionStore` hangs rather
/// than fails. The real store's own behaviour — atomic writes, corrupt-file
/// tolerance, resume selection — is covered by `test/moca/session_store_test.dart`,
/// which uses a plain `test` and a temp directory. This file covers only what
/// the page does with what the store returns.
class _FakeStore implements SessionStore {
  final List<SessionRecord> records;
  final Object? throws;

  _FakeStore({this.records = const [], this.throws});

  @override
  Future<SessionRecord?> loadResumable() async {
    if (throws != null) throw throws!;
    for (final record in records) {
      if (!record.completed) return record;
    }
    return null;
  }

  @override
  Future<void> save(SessionRecord record) async {}

  @override
  Future<SessionRecord?> load(String id) async => null;

  @override
  Future<List<SessionRecord>> loadAll() async => records;

  @override
  Future<void> delete(String id) async {}
}

void main() {
  setUp(() {
    LiveSession.clearCurrent();
    globals.voiceOutcomes.clear();
    globals.clockScore = 0;
    AppLanguage.current = Language.en;
  });

  tearDown(() {
    LiveSession.clearCurrent();
    AppLanguage.current = Language.th;
  });

  SessionRecord unfinished({bool completed = false}) => SessionRecord(
        id: 'partial',
        startedAt: DateTime(2026, 9, 7, 14, 30),
        clockScore: 3,
        completed: completed,
      );

  Future<void> pump(WidgetTester tester, SessionStore store) async {
    await tester.pumpWidget(MaterialApp(
      home: HomePage(store: store),
      routes: {'/larksen': (_) => const Scaffold(body: Text('FIRST SUBTEST'))},
    ));
    // initState kicks off the store read; one more pump lands the setState.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('offers nothing when there is no unfinished session',
      (tester) async {
    await pump(tester, _FakeStore());
    expect(find.text('Resume unfinished test'), findsNothing);
    expect(find.text('Start Test'), findsOneWidget);
  });

  testWidgets('offers to resume an unfinished session', (tester) async {
    await pump(tester, _FakeStore(records: [unfinished()]));
    expect(find.text('Resume unfinished test'), findsOneWidget);
  });

  testWidgets('never offers a completed session', (tester) async {
    await pump(tester, _FakeStore(records: [unfinished(completed: true)]));
    expect(find.text('Resume unfinished test'), findsNothing);
  });

  testWidgets('shows when the unfinished session started', (tester) async {
    // So a clinician can tell this patient's session from yesterday's
    // abandoned one.
    await pump(tester, _FakeStore(records: [unfinished()]));
    expect(find.text('Started 2026-09-07 14:30'), findsOneWidget);
  });

  testWidgets('the resume offer sits below Start Test, not above it',
      (tester) async {
    // A stale record from a previous patient must not be the prominent
    // action; starting fresh has to stay the obvious default.
    await pump(tester, _FakeStore(records: [unfinished()]));
    final start = tester.getTopLeft(find.text('Start Test'));
    final resume = tester.getTopLeft(find.text('Resume unfinished test'));
    expect(resume.dy, greaterThan(start.dy));
  });

  testWidgets('resuming restores the scores into the globals', (tester) async {
    final store = _FakeStore(records: [unfinished()]);
    await pump(tester, store);

    await tester.tap(find.text('Resume unfinished test'));
    await tester.pump();
    await tester.pump();

    expect(globals.clockScore, 3);
    expect(LiveSession.current!.record.id, 'partial');
  });

  testWidgets('resuming goes to the first subtest, not a guessed position',
      (tester) async {
    // The record knows what was scored, not where the patient stood. Guessing
    // wrong would re-administer a subtest that already has a score, which is a
    // practice effect on a real assessment.
    await pump(tester, _FakeStore(records: [unfinished()]));

    await tester.tap(find.text('Resume unfinished test'));
    await tester.pump();
    await tester.pump();

    expect(find.text('FIRST SUBTEST'), findsOneWidget);
  });

  testWidgets('a storage failure just means no offer, not an error',
      (tester) async {
    // A missing resume offer is indistinguishable from having nothing to
    // resume, and neither is worth an error dialog on the home screen.
    await pump(tester, _FakeStore(throws: StateError('no storage')));
    expect(find.text('Resume unfinished test'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
