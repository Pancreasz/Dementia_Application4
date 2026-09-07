import '../scoring/subtest_outcome.dart';
import 'event_trace.dart';

/// Everything one MoCA session produced, in a form that can be written to disk.
///
/// This is the type that fixes the first item on the README's limitations list.
/// Scores currently live in module-level globals in `lib/pages/score.dart`, so
/// closing the tab loses the session silently — today that costs a score, and
/// with timing traces and an analysis page it would cost considerably more. The
/// analysis page is also the screen a patient is most likely to sit on, which
/// is exactly when a phone locks.
///
/// [SessionStore] persists this; `score.dart` keeps the globals as the live
/// working copy so no existing page has to change how it reads a score.
class SessionRecord {
  /// Identifies this session in storage. Not derived from anything about the
  /// patient — a timestamp-based id, so nothing identifying is needed to name
  /// a record.
  final String id;

  final DateTime startedAt;

  /// Last time anything was written. Used to pick the session to resume when
  /// more than one is on disk.
  final DateTime updatedAt;

  /// The five original subtests, which always run and cannot be skipped.
  final int larkScore;
  final int clockScore;
  final int animalScore;
  final int attentionScore;
  final int reorderScore;

  /// The delayed-recall ordering the patient produced.
  final List<String> correctOrder;

  /// The nine voice/tap subtests, which can be skipped — a state an int cannot
  /// represent, which is why these are outcomes rather than ints.
  final Map<String, SubtestOutcome> voiceOutcomes;

  /// Raw timestamped events. Empty on a session recorded before tracing
  /// existed, which is why nothing here requires it to be populated.
  final TraceLog trace;

  /// False until the patient reaches the end. A record that was interrupted is
  /// still worth keeping and still worth resuming, but it must not be presented
  /// as a finished assessment — `SessionTotal.category` already refuses to band
  /// a partial administration, and this carries the same fact at the top level.
  final bool completed;

  SessionRecord({
    required this.id,
    required this.startedAt,
    DateTime? updatedAt,
    this.larkScore = 0,
    this.clockScore = 0,
    this.animalScore = 0,
    this.attentionScore = 0,
    this.reorderScore = 0,
    this.correctOrder = const [],
    this.voiceOutcomes = const {},
    TraceLog? trace,
    this.completed = false,
  })  : updatedAt = updatedAt ?? startedAt,
        trace = trace ?? TraceLog(startedAt: startedAt);

  /// A fresh session. The id is the start time in ISO form with separators
  /// stripped, which sorts chronologically as a plain string.
  factory SessionRecord.startNow({DateTime? now}) {
    final at = now ?? DateTime.now();
    return SessionRecord(
      id: at.toIso8601String().replaceAll(RegExp(r'[:.\-]'), ''),
      startedAt: at,
      trace: TraceLog(startedAt: at),
    );
  }

  SessionRecord copyWith({
    int? larkScore,
    int? clockScore,
    int? animalScore,
    int? attentionScore,
    int? reorderScore,
    List<String>? correctOrder,
    Map<String, SubtestOutcome>? voiceOutcomes,
    TraceLog? trace,
    bool? completed,
    DateTime? updatedAt,
  }) =>
      SessionRecord(
        id: id,
        startedAt: startedAt,
        updatedAt: updatedAt ?? DateTime.now(),
        larkScore: larkScore ?? this.larkScore,
        clockScore: clockScore ?? this.clockScore,
        animalScore: animalScore ?? this.animalScore,
        attentionScore: attentionScore ?? this.attentionScore,
        reorderScore: reorderScore ?? this.reorderScore,
        correctOrder: correctOrder ?? this.correctOrder,
        voiceOutcomes: voiceOutcomes ?? this.voiceOutcomes,
        trace: trace ?? this.trace,
        completed: completed ?? this.completed,
      );

  Map<String, dynamic> toJson() => {
        'version': schemaVersion,
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'larkScore': larkScore,
        'clockScore': clockScore,
        'animalScore': animalScore,
        'attentionScore': attentionScore,
        'reorderScore': reorderScore,
        'correctOrder': correctOrder,
        'voiceOutcomes': {
          for (final e in voiceOutcomes.entries) e.key: e.value.toJson(),
        },
        'trace': trace.toJson(),
        'completed': completed,
      };

  /// Bumped when the shape changes incompatibly. Stored so a future build can
  /// tell an old record from a corrupt one instead of guessing.
  static const int schemaVersion = 1;

  /// Rebuilds a record from storage.
  ///
  /// Every field is tolerant of being missing. A stored session is the only
  /// copy of a patient's assessment, so a record that is partly unreadable
  /// should yield what it can rather than throw the whole thing away.
  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    final started =
        DateTime.tryParse((json['startedAt'] as String?) ?? '') ?? DateTime.now();
    return SessionRecord(
      id: (json['id'] as String?) ?? '',
      startedAt: started,
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ?? started,
      larkScore: (json['larkScore'] as num?)?.toInt() ?? 0,
      clockScore: (json['clockScore'] as num?)?.toInt() ?? 0,
      animalScore: (json['animalScore'] as num?)?.toInt() ?? 0,
      attentionScore: (json['attentionScore'] as num?)?.toInt() ?? 0,
      reorderScore: (json['reorderScore'] as num?)?.toInt() ?? 0,
      correctOrder: [
        for (final v in (json['correctOrder'] as List?) ?? const [])
          if (v is String) v,
      ],
      voiceOutcomes: {
        for (final e in ((json['voiceOutcomes'] as Map?) ?? const {}).entries)
          if (e.key is String && e.value is Map)
            e.key as String:
                SubtestOutcome.fromJson((e.value as Map).cast<String, dynamic>()),
      },
      trace: json['trace'] is Map
          ? TraceLog.fromJson((json['trace'] as Map).cast<String, dynamic>())
          : TraceLog(startedAt: started),
      completed: (json['completed'] as bool?) ?? false,
    );
  }
}
