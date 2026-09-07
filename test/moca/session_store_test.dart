import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/event_trace.dart';
import 'package:moca_main/moca/session_record.dart';
import 'package:moca_main/moca/session_store.dart';
import 'package:moca_main/scoring/subtest_outcome.dart';

void main() {
  late Directory temp;
  late SessionStore store;

  setUp(() {
    // The real store uses getApplicationDocumentsDirectory(), which
    // `flutter test` cannot resolve — hence the injectable directory.
    temp = Directory.systemTemp.createTempSync('moca_session_test');
    store = SessionStore(directory: () async => temp);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  SessionRecord sample({String id = 's1', bool completed = false}) {
    final start = DateTime(2026, 9, 7, 9, 0);
    final trace = TraceLog(startedAt: start)
      ..add('vigilance', TraceEventType.tap,
          at: start.add(const Duration(milliseconds: 1450)));
    return SessionRecord(
      id: id,
      startedAt: start,
      larkScore: 1,
      clockScore: 3,
      animalScore: 2,
      attentionScore: 3,
      reorderScore: 4,
      correctOrder: const ['img1', 'img2'],
      voiceOutcomes: {
        'abstraction-1': const SubtestOutcome(
          subtestId: 'abstraction-1',
          score: 1,
          maxScore: 1,
          transcript: 'เป็นยานพาหนะ',
          detail: {'best_category_similarity': 0.963, 'reason': 'category-match'},
        ),
        'orientation': SubtestOutcome.skippedFor('orientation'),
      },
      trace: trace,
      completed: completed,
    );
  }

  group('round trip', () {
    test('saves and loads every score', () async {
      await store.save(sample());
      final loaded = (await store.load('s1'))!;
      expect(loaded.larkScore, 1);
      expect(loaded.clockScore, 3);
      expect(loaded.animalScore, 2);
      expect(loaded.attentionScore, 3);
      expect(loaded.reorderScore, 4);
      expect(loaded.correctOrder, ['img1', 'img2']);
    });

    test('keeps a skipped subtest skipped, not scored zero', () async {
      // A skipped subtest is excluded from both sides of the total. Loading it
      // back as a plain 0/1 would silently convert "not administered" into
      // "failed" — the exact misreading the outcome type exists to prevent.
      await store.save(sample());
      final loaded = (await store.load('s1'))!;
      final orientation = loaded.voiceOutcomes['orientation']!;
      expect(orientation.skipped, isTrue);
      expect(orientation.maxScore, 0);
    });

    test('keeps the transcript and the scoring detail', () async {
      // Storing transcripts is what closes the review-surface gap blocking
      // validation of the unvalidated thresholds.
      await store.save(sample());
      final loaded = (await store.load('s1'))!;
      final abstraction = loaded.voiceOutcomes['abstraction-1']!;
      expect(abstraction.transcript, 'เป็นยานพาหนะ');
      expect(abstraction.detail['best_category_similarity'], 0.963);
      expect(abstraction.detail['reason'], 'category-match');
    });

    test('keeps the raw event trace', () async {
      await store.save(sample());
      final loaded = (await store.load('s1'))!;
      expect(loaded.trace.length, 1);
      expect(loaded.trace.events.first.atMs, 1450);
    });

    test('records the schema version', () async {
      await store.save(sample());
      final loaded = (await store.load('s1'))!;
      expect(loaded.startedAt, DateTime(2026, 9, 7, 9, 0));
      // Written so a future build can tell an old record from a corrupt one.
      expect(SessionRecord.schemaVersion, 1);
    });
  });

  group('durability', () {
    test('a second save replaces the first', () async {
      await store.save(sample());
      await store.save(sample().copyWith(larkScore: 0));
      expect((await store.load('s1'))!.larkScore, 0);
      expect((await store.loadAll()).length, 1);
    });

    test('leaves no temporary file behind', () async {
      // The write goes to a .tmp and is renamed over the target, so a crash
      // mid-write leaves one complete record rather than a half-written file.
      await store.save(sample());
      final leftovers =
          temp.listSync().where((e) => e.path.endsWith('.tmp')).toList();
      expect(leftovers, isEmpty);
    });

    test('loading a session that was never saved returns null', () async {
      expect(await store.load('nope'), isNull);
    });

    test('one corrupt file does not hide the others', () async {
      await store.save(sample(id: 'good'));
      File('${temp.path}/corrupt.json').writeAsStringSync('{not json');
      final all = await store.loadAll();
      expect(all.map((r) => r.id), ['good']);
    });

    test('a stray .tmp file is not loaded as a session', () async {
      await store.save(sample(id: 'good'));
      File('${temp.path}/half.json.tmp').writeAsStringSync('{"id":"half"}');
      expect((await store.loadAll()).map((r) => r.id), ['good']);
    });
  });

  group('resuming', () {
    test('offers the most recent unfinished session', () async {
      await store.save(sample(id: 'old')
          .copyWith(updatedAt: DateTime(2026, 9, 7, 9, 5)));
      await store.save(sample(id: 'new')
          .copyWith(updatedAt: DateTime(2026, 9, 7, 9, 30)));
      expect((await store.loadResumable())!.id, 'new');
    });

    test('never offers a completed session', () async {
      // Reopening the app after finishing must not drop the clinician back
      // into an assessment that is already done.
      await store.save(sample(id: 'done', completed: true));
      expect(await store.loadResumable(), isNull);
    });

    test('skips completed sessions to find an unfinished one', () async {
      await store.save(sample(id: 'done', completed: true)
          .copyWith(updatedAt: DateTime(2026, 9, 7, 10, 0)));
      await store.save(sample(id: 'partial')
          .copyWith(updatedAt: DateTime(2026, 9, 7, 9, 0)));
      expect((await store.loadResumable())!.id, 'partial');
    });

    test('returns null when nothing is stored', () async {
      expect(await store.loadResumable(), isNull);
      expect(await store.loadAll(), isEmpty);
    });
  });

  group('deleting', () {
    test('removes one session and leaves the rest', () async {
      await store.save(sample(id: 'a'));
      await store.save(sample(id: 'b'));
      await store.delete('a');
      expect((await store.loadAll()).map((r) => r.id), ['b']);
    });

    test('deleting something that is not there is not an error', () async {
      await store.delete('never-existed');
    });
  });

  group('SessionRecord', () {
    test('a fresh session is not complete and has an id', () {
      final record = SessionRecord.startNow(now: DateTime(2026, 9, 7, 9, 0));
      expect(record.completed, isFalse);
      expect(record.id, isNotEmpty);
      // The id is derived from the start time only — nothing about the patient
      // is needed to name a record.
      expect(record.id, contains('2026'));
    });

    test('loads a record with fields missing rather than throwing', () {
      // A stored session is the only copy of an assessment; a partly
      // unreadable one should yield what it can.
      final record = SessionRecord.fromJson({'id': 'x'});
      expect(record.id, 'x');
      expect(record.larkScore, 0);
      expect(record.voiceOutcomes, isEmpty);
      expect(record.trace.isEmpty, isTrue);
    });

    test('a damaged outcome cannot invent a score', () {
      // Missing score against missing maxScore is the "not administered"
      // shape, which is excluded from the total — not a failure.
      final outcome = SubtestOutcome.fromJson({'subtestId': 'x'});
      expect(outcome.score, 0);
      expect(outcome.maxScore, 0);
    });
  });
}
