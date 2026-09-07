import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/event_trace.dart';

void main() {
  group('TraceEvent', () {
    test('survives a round trip through JSON', () {
      const event = TraceEvent(
        subtestId: 'vigilance',
        type: TraceEventType.tap,
        atMs: 4231,
        data: {'sinceSequenceStartMs': 1200},
      );
      final restored = TraceEvent.fromJson(event.toJson());
      expect(restored.subtestId, 'vigilance');
      expect(restored.type, TraceEventType.tap);
      expect(restored.atMs, 4231);
      expect(restored.data['sinceSequenceStartMs'], 1200);
    });

    test('omits an empty data map rather than storing {}', () {
      const event =
          TraceEvent(subtestId: 'x', type: 'started', atMs: 0);
      expect(event.toJson().containsKey('data'), isFalse);
    });

    test('loads an event written by a build that knew fewer fields', () {
      // A stored trace is the only copy of what happened. Missing fields must
      // degrade, not throw.
      final restored = TraceEvent.fromJson({'type': 'tap'});
      expect(restored.type, 'tap');
      expect(restored.atMs, 0);
      expect(restored.data, isEmpty);
    });

    test('keeps an event type it does not recognise', () {
      // Types are strings, not an enum, so an older build can still read a
      // trace containing a newer event rather than failing to parse it.
      final restored =
          TraceEvent.fromJson({'type': 'something-invented-later', 'atMs': 5});
      expect(restored.type, 'something-invented-later');
    });
  });

  group('TraceLog', () {
    test('records offsets from the session start, not wall clock', () {
      final start = DateTime(2026, 9, 7, 10, 0, 0);
      final log = TraceLog(startedAt: start);
      final event = log.add('vigilance', TraceEventType.tap,
          at: start.add(const Duration(milliseconds: 1500)));
      expect(event.atMs, 1500);
    });

    test('appends in order', () {
      final start = DateTime(2026, 9, 7);
      final log = TraceLog(startedAt: start);
      log.add('a', 'first', at: start);
      log.add('a', 'second', at: start.add(const Duration(seconds: 1)));
      expect(log.events.map((e) => e.type), ['first', 'second']);
    });

    test('is append-only from the outside', () {
      // An event that turned out to be inconvenient is still evidence.
      final log = TraceLog(startedAt: DateTime(2026, 9, 7));
      log.add('a', 'first');
      expect(() => log.events.clear(), throwsUnsupportedError);
    });

    test('filters events by subtest', () {
      final start = DateTime(2026, 9, 7);
      final log = TraceLog(startedAt: start);
      log.add('vigilance', 'tap', at: start);
      log.add('abstraction-1', 'started', at: start);
      log.add('vigilance', 'tap', at: start);
      expect(log.forSubtest('vigilance').length, 2);
      expect(log.forSubtest('abstraction-1').length, 1);
    });

    test('survives a round trip through JSON', () {
      final start = DateTime(2026, 9, 7, 14, 30);
      final log = TraceLog(startedAt: start);
      log.add('vigilance', TraceEventType.digitPlayed,
          at: start, data: {'index': 17, 'isTarget': true});
      log.add('vigilance', TraceEventType.tap,
          at: start.add(const Duration(milliseconds: 400)));

      final restored = TraceLog.fromJson(log.toJson());
      expect(restored.startedAt, start);
      expect(restored.length, 2);
      expect(restored.events[0].data['index'], 17);
      expect(restored.events[1].atMs, 400);
    });

    test('an unparseable start time still yields usable offsets', () {
      // The offsets BETWEEN events are what every measurement uses, so they
      // must survive a damaged start time.
      final restored = TraceLog.fromJson({
        'startedAt': 'not a date',
        'events': [
          {'subtestId': 'a', 'type': 'tap', 'atMs': 100},
          {'subtestId': 'a', 'type': 'tap', 'atMs': 350},
        ],
      });
      expect(restored.length, 2);
      expect(restored.events[1].atMs - restored.events[0].atMs, 250);
    });

    test('drops malformed events rather than failing the whole log', () {
      final restored = TraceLog.fromJson({
        'startedAt': DateTime(2026, 9, 7).toIso8601String(),
        'events': [
          {'subtestId': 'a', 'type': 'tap', 'atMs': 1},
          'not an event',
          {'subtestId': 'a', 'type': 'tap', 'atMs': 2},
        ],
      });
      expect(restored.length, 2);
    });

    test('an absent events list loads as an empty log', () {
      final restored = TraceLog.fromJson({'startedAt': '2026-09-07T00:00:00.000'});
      expect(restored.isEmpty, isTrue);
    });
  });

  group('what the stored trace has to support', () {
    // These assert that the RAW events needed by the improvement plan's
    // measurements are recoverable. They deliberately compute the metrics here,
    // in the test, rather than anywhere in lib/ — the point of storing raw
    // events is that the metrics are not fixed at capture time.
    late TraceLog log;
    final start = DateTime(2026, 9, 7);

    setUp(() {
      log = TraceLog(startedAt: start);
      // A vigilance run: 5 digits, targets at 1 and 3, tapped at 1 only.
      for (var i = 0; i < 5; i++) {
        log.add('vigilance', TraceEventType.digitPlayed,
            at: start.add(Duration(milliseconds: i * 1000)),
            data: {'index': i, 'isTarget': i == 1 || i == 3});
      }
      log.add('vigilance', TraceEventType.tap,
          at: start.add(const Duration(milliseconds: 1450)));
    });

    test('misses and false taps can be counted separately', () {
      // Currently the score sums them into one error count, which makes
      // inattention and impulsivity indistinguishable.
      final digits = log
          .forSubtest('vigilance')
          .where((e) => e.type == TraceEventType.digitPlayed);
      final targets = digits.where((e) => e.data['isTarget'] == true).length;
      final taps = log
          .forSubtest('vigilance')
          .where((e) => e.type == TraceEventType.tap)
          .length;
      expect(targets, 2);
      expect(taps, 1);
      // One target went untapped: a miss, with no false taps.
      expect(targets - taps, 1);
    });

    test('error position across the sequence can be recovered', () {
      // The vigilance-decrement measure: whether errors cluster in the last
      // third. Needs each digit's index, which is why digitPlayed carries one.
      final indices = log
          .forSubtest('vigilance')
          .where((e) => e.type == TraceEventType.digitPlayed)
          .map((e) => e.data['index'])
          .toList();
      expect(indices, [0, 1, 2, 3, 4]);
    });

    test('tap latency from its own target onset can be recomputed', () {
      final events = log.forSubtest('vigilance');
      final target = events.firstWhere(
          (e) => e.type == TraceEventType.digitPlayed && e.data['index'] == 1);
      final tap = events.firstWhere((e) => e.type == TraceEventType.tap);
      // 1450 ms into the sequence, against a target that sounded at 1000 ms.
      expect(tap.atMs - target.atMs, 450);
    });
  });
}
