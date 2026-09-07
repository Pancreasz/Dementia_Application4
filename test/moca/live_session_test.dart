import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/event_trace.dart';
import 'package:moca_main/moca/live_session.dart';
import 'package:moca_main/moca/session_store.dart';
import 'package:moca_main/pages/score.dart' as globals;
import 'package:moca_main/scoring/subtest_outcome.dart';

void main() {
  late Directory temp;
  late SessionStore store;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('moca_live_session_test');
    store = SessionStore(directory: () async => temp);
    LiveSession.clearCurrent();
    globals.larkScore = 0;
    globals.clockScore = 0;
    globals.animalScore = 0;
    globals.attentionScore = 0;
    globals.reorderScore = 0;
    globals.correctOrder.clear();
    globals.voiceOutcomes.clear();
  });

  tearDown(() {
    LiveSession.clearCurrent();
    temp.deleteSync(recursive: true);
  });

  test('no session exists until one is explicitly started', () {
    // Reading `current` must never create a session, or a stray page would
    // look like an assessment.
    expect(LiveSession.current, isNull);
  });

  test('starting writes the session immediately', () async {
    // A session abandoned after one subtest should still leave a record.
    final session = await LiveSession.start(store: store);
    expect(LiveSession.current, same(session));
    expect((await store.load(session.record.id)), isNotNull);
  });

  test('recording an outcome saves it and the globals together', () async {
    final session = await LiveSession.start(store: store);
    globals.clockScore = 3;
    await session.recordOutcome(const SubtestOutcome(
      subtestId: 'abstraction-1',
      score: 1,
      maxScore: 1,
      transcript: 'เป็นยานพาหนะ',
    ));

    final saved = (await store.load(session.record.id))!;
    expect(saved.clockScore, 3);
    expect(saved.voiceOutcomes['abstraction-1']!.score, 1);
    // The outcome also reaches the globals the existing pages read.
    expect(globals.voiceOutcomes['abstraction-1']!.score, 1);
  });

  test('a skipped outcome is traced as skipped, not scored', () async {
    final session = await LiveSession.start(store: store);
    await session.recordOutcome(SubtestOutcome.skippedFor('orientation'));
    final types = session.trace
        .forSubtest('orientation')
        .map((e) => e.type)
        .toList();
    expect(types, contains(TraceEventType.skipped));
    expect(types, isNot(contains(TraceEventType.scored)));
  });

  test('the five original scores are picked up from the globals', () async {
    // They are written straight to globals by their own pages, so syncing is
    // all this has to do.
    final session = await LiveSession.start(store: store);
    globals.larkScore = 1;
    globals.animalScore = 3;
    globals.correctOrder.addAll(['img1', 'img2']);
    await session.recordScores();

    final saved = (await store.load(session.record.id))!;
    expect(saved.larkScore, 1);
    expect(saved.animalScore, 3);
    expect(saved.correctOrder, ['img1', 'img2']);
  });

  group('resuming after a closed tab', () {
    test('restores the scores into the globals', () async {
      final first = await LiveSession.start(store: store);
      globals.clockScore = 2;
      globals.animalScore = 3;
      await first.recordScores();

      // Simulate the tab closing: the globals go, the stored record stays.
      LiveSession.clearCurrent();
      globals.clockScore = 0;
      globals.animalScore = 0;

      final resumed = await LiveSession.resumeOrStart(store: store);
      expect(resumed.record.id, first.record.id);
      expect(globals.clockScore, 2);
      expect(globals.animalScore, 3);
    });

    test('restores voice outcomes too', () async {
      final first = await LiveSession.start(store: store);
      await first.recordOutcome(const SubtestOutcome(
          subtestId: 'abstraction-1', score: 1, maxScore: 1));

      LiveSession.clearCurrent();
      globals.voiceOutcomes.clear();

      await LiveSession.resumeOrStart(store: store);
      expect(globals.voiceOutcomes['abstraction-1']!.score, 1);
    });

    test('starts fresh when nothing is stored', () async {
      final session = await LiveSession.resumeOrStart(store: store);
      expect(session.record.completed, isFalse);
      expect(session.trace.events.map((e) => e.type),
          contains(TraceEventType.started));
    });

    test('starts fresh rather than resuming a completed session', () async {
      final first = await LiveSession.start(store: store);
      await first.complete();
      LiveSession.clearCurrent();

      final second = await LiveSession.resumeOrStart(store: store);
      expect(second.record.id, isNot(first.record.id));
    });

    test('marks the resumed session so the interruption is visible', () async {
      await LiveSession.start(store: store);
      LiveSession.clearCurrent();
      final resumed = await LiveSession.resumeOrStart(store: store);
      expect(resumed.trace.events.map((e) => e.type), contains('resumed'));
    });
  });

  test('completing marks the record finished', () async {
    final session = await LiveSession.start(store: store);
    await session.complete();
    final saved = (await store.load(session.record.id))!;
    expect(saved.completed, isTrue);
  });

  test('clearing the current session does not delete what was stored',
      () async {
    // The record is evidence; leaving a screen must not throw it away.
    final session = await LiveSession.start(store: store);
    final id = session.record.id;
    LiveSession.clearCurrent();
    expect(await store.load(id), isNotNull);
  });

  test('a failing store does not take down the session', () async {
    // Losing persistence is a degradation; losing the patient's session in
    // front of them is what this class exists to prevent.
    final session = await LiveSession.start(store: _ExplodingStore());
    await session.recordOutcome(const SubtestOutcome(
        subtestId: 'abstraction-1', score: 1, maxScore: 1));
    expect(session.record.voiceOutcomes['abstraction-1']!.score, 1);
  });
}

class _ExplodingStore implements SessionStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('disk full');
}
