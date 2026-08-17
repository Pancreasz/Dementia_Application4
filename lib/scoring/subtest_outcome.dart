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
}
