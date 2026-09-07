/// Timestamped raw events for one session.
///
/// WHY RAW EVENTS AND NOT METRICS
/// ------------------------------
/// The obvious version of this file stores "mean tap latency: 512 ms". It is
/// smaller, it is what the analysis page displays, and it is a trap: none of
/// the measurements the analysis page wants are validated, so all of them will
/// need recomputing once real sessions exist. A stored mean cannot be
/// recomputed into a variance, an error position, or a within-task trend. A
/// stored list of tap timestamps can be recomputed into any of them.
///
/// So this file stores *what happened and when*, and derives nothing. Every
/// metric named in the improvement plan — latency variance, error position
/// across the 29 digits, time-to-first-keypress, clustering vs. switching,
/// rising latency across the five serial 7s — is a function of these events.
///
/// WHAT IT DELIBERATELY DOES NOT STORE
/// -----------------------------------
/// No wall-clock time per event. Each event carries an offset in milliseconds
/// from [TraceLog.startedAt], which is recorded once. Offsets are what every
/// measurement actually needs, they stay correct across a device clock change
/// mid-session, and they do not scatter precise timestamps of a patient's
/// behaviour through the file.
library;

/// One thing that happened, and when.
class TraceEvent {
  /// Which subtest it belongs to. Session-level events (a session starting, a
  /// page being left) use [sessionScope] rather than a subtest id.
  final String subtestId;

  /// What happened. Free-form by design — a new subtest can record a kind of
  /// event no one anticipated without a schema migration. The constants on
  /// [TraceEventType] are the ones currently emitted.
  final String type;

  /// Milliseconds since [TraceLog.startedAt]. Never negative in practice; not
  /// asserted, because a clock adjustment mid-session is a data oddity to
  /// record, not a crash to cause in front of a patient.
  final int atMs;

  /// Event-specific payload. Kept small and literal: the digit that sounded,
  /// the key that was pressed, the phase that was entered. Nothing derived.
  final Map<String, dynamic> data;

  const TraceEvent({
    required this.subtestId,
    required this.type,
    required this.atMs,
    this.data = const {},
  });

  Map<String, dynamic> toJson() => {
        'subtestId': subtestId,
        'type': type,
        'atMs': atMs,
        if (data.isNotEmpty) 'data': data,
      };

  factory TraceEvent.fromJson(Map<String, dynamic> json) => TraceEvent(
        subtestId: (json['subtestId'] as String?) ?? '',
        type: (json['type'] as String?) ?? '',
        atMs: (json['atMs'] as num?)?.toInt() ?? 0,
        data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  @override
  String toString() => 'TraceEvent($subtestId, $type, ${atMs}ms, $data)';
}

/// The scope used for events that belong to the session rather than a subtest.
const String sessionScope = '__session__';

/// The event kinds currently emitted.
///
/// Names, not an enum, so that persisted traces stay readable and a build that
/// does not know a newer event type can still load and display it rather than
/// failing to parse the session.
abstract final class TraceEventType {
  /// A subtest's instruction screen was shown.
  static const instructionShown = 'instruction-shown';

  /// The patient pressed start.
  static const started = 'started';

  /// Stimulus audio began / finished. The gap between `stimulusEnd` and the
  /// first response event is the initiation latency several subtests want.
  static const stimulusStart = 'stimulus-start';
  static const stimulusEnd = 'stimulus-end';

  /// The microphone opened / closed.
  static const recordingStart = 'recording-start';
  static const recordingEnd = 'recording-end';

  /// One digit of a tap sequence sounded. `data` carries {'digit': '1',
  /// 'index': 17, 'isTarget': true} — enough to reconstruct error position
  /// across the 29 digits, which is the vigilance-decrement measure.
  static const digitPlayed = 'digit-played';

  /// The patient tapped. Vigilance's misses-vs-false-taps split is this event
  /// against `digitPlayed`, computed later rather than stored.
  static const tap = 'tap';

  /// A naming item's picture appeared. `data` carries {'itemIndex': 0,
  /// 'target': 'อูฐ'}. This is the origin every typing latency is measured
  /// from — time-to-first-key is the first [keyPressed] after it.
  static const itemShown = 'item-shown';

  /// One key on the in-app keyboard, with the character and how long the
  /// answer was afterwards: {'key': 'อ', 'length': 1}. Inter-key intervals are
  /// the differences between consecutive events, computed later; storing an
  /// interval instead of a timestamp would make a variance impossible to
  /// recover.
  static const keyPressed = 'key-pressed';

  /// Backspace. A separate type rather than a [keyPressed] with a special key
  /// value, so self-correction is countable without inspecting payloads.
  static const keyDeleted = 'key-deleted';

  /// An answer was submitted: {'itemIndex', 'answer', 'target', 'correct'}.
  static const submitted = 'submitted';

  /// Scoring began / finished, and what it produced. The `scored` event's
  /// `data` carries the subtest's score and maxScore so a trace is
  /// self-contained for review even in isolation.
  static const scoringStart = 'scoring-start';
  static const scored = 'scored';

  /// The patient (or clinician) retried or skipped. Both are real behaviour
  /// worth keeping: a subtest retried three times is not the same as one
  /// answered first time, even at the same score.
  static const retried = 'retried';
  static const skipped = 'skipped';

  /// Something failed — usually the backend. Recorded so a 0 that came from an
  /// outage is distinguishable afterwards from a 0 the patient earned.
  static const failed = 'failed';
}

/// An append-only log of events for one session.
class TraceLog {
  /// When the session began. The single wall-clock time in the whole trace;
  /// every event is an offset from it.
  final DateTime startedAt;

  final List<TraceEvent> _events;

  TraceLog({DateTime? startedAt, List<TraceEvent>? events})
      : startedAt = startedAt ?? DateTime.now(),
        _events = List.of(events ?? const []);

  /// Unmodifiable so nothing can rewrite history in place. Append-only is the
  /// point: an event that turned out to be inconvenient is still evidence.
  List<TraceEvent> get events => List.unmodifiable(_events);

  int get length => _events.length;
  bool get isEmpty => _events.isEmpty;

  /// Records an event at the current offset from [startedAt].
  ///
  /// Returns the event so a caller can log or assert on it without re-deriving
  /// the offset — and so tests can check the offset without a second clock read.
  TraceEvent add(
    String subtestId,
    String type, {
    Map<String, dynamic> data = const {},
    DateTime? at,
  }) {
    final event = TraceEvent(
      subtestId: subtestId,
      type: type,
      atMs: (at ?? DateTime.now()).difference(startedAt).inMilliseconds,
      data: data,
    );
    _events.add(event);
    return event;
  }

  /// Every event for one subtest, in the order it happened.
  List<TraceEvent> forSubtest(String subtestId) =>
      _events.where((e) => e.subtestId == subtestId).toList(growable: false);

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toIso8601String(),
        'events': [for (final e in _events) e.toJson()],
      };

  factory TraceLog.fromJson(Map<String, dynamic> json) => TraceLog(
        // A record with an unparseable start time still loads, using the epoch.
        // The offsets between events — which is what every measurement uses —
        // survive intact either way.
        startedAt: DateTime.tryParse((json['startedAt'] as String?) ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        events: [
          for (final e in (json['events'] as List?) ?? const [])
            if (e is Map) TraceEvent.fromJson(e.cast<String, dynamic>()),
        ],
      );
}
