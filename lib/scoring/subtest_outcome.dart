/// The result of one administered (or skipped) subtest.
class SubtestOutcome {
  final String subtestId;
  final int score;
  final int maxScore;
  final bool skipped;
  final String transcript;

  /// Scorer-specific extras kept for human review — matched terms, per-item
  /// correctness, tap latencies. Nothing computes on these; they exist so a
  /// surprising score can be explained after the fact.
  final Map<String, dynamic> detail;

  const SubtestOutcome({
    required this.subtestId,
    required this.score,
    required this.maxScore,
    this.skipped = false,
    this.transcript = '',
    this.detail = const {},
  });

  /// A subtest that was never administered. Deliberately maxScore 0: it is
  /// excluded from both sides of the total rather than counted as a failure.
  factory SubtestOutcome.skippedFor(String subtestId) => SubtestOutcome(
        subtestId: subtestId,
        score: 0,
        maxScore: 0,
        skipped: true,
      );

  Map<String, dynamic> toJson() => {
        'subtestId': subtestId,
        'score': score,
        'maxScore': maxScore,
        'skipped': skipped,
        'transcript': transcript,
        // Written out whole. `detail` is where the transcript-adjacent evidence
        // lives — matched terms, per-item correctness, tap latencies, and now
        // the full abstraction similarity map — and it is exactly the material
        // that makes a surprising score checkable later. Dropping it on save
        // would leave a stored session that can be re-totalled but not reviewed.
        'detail': detail,
      };

  /// Rebuilds an outcome from storage.
  ///
  /// Tolerant of missing fields rather than throwing: a stored session written
  /// by an older build must still load. The defaults are chosen so a damaged
  /// record cannot invent a score — a missing `score` reads as 0 against a
  /// missing `maxScore` of 0, which is the "not administered" shape, not a
  /// failure.
  factory SubtestOutcome.fromJson(Map<String, dynamic> json) => SubtestOutcome(
        subtestId: (json['subtestId'] as String?) ?? '',
        score: (json['score'] as num?)?.toInt() ?? 0,
        maxScore: (json['maxScore'] as num?)?.toInt() ?? 0,
        skipped: (json['skipped'] as bool?) ?? false,
        transcript: (json['transcript'] as String?) ?? '',
        detail: (json['detail'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}
