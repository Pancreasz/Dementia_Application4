import '../moca/subtests.dart';
import 'subtest_outcome.dart';

/// The published MoCA cutoffs. These are defined against a complete 30-point
/// administration, which is why a partial session gets no category at all.
const _bands = <int, String>{
  26: 'ปกติ',
  18: 'บกพร่องเล็กน้อย',
  10: 'มีความบกพร่อง',
};

class SessionTotal {
  final int score;

  /// The sum of ADMINISTERED maxScores. A skipped subtest is excluded from
  /// both sides rather than counted as a failure.
  final int maxScore;

  final List<String> skippedIds;

  const SessionTotal({
    required this.score,
    required this.maxScore,
    required this.skippedIds,
  });

  bool get isComplete => skippedIds.isEmpty;

  /// Null when anything was skipped. Fixed cutoffs mean nothing against a
  /// partial administration, and scaling them proportionally would present an
  /// invented category with the same confidence as a real one.
  String? get category {
    if (!isComplete) return null;
    for (final entry in _bands.entries) {
      if (score >= entry.key) return entry.value;
    }
    return 'เสี่ยงสูง';
  }
}

SessionTotal computeSessionTotal({
  required int larkScore,
  required int clockScore,
  required int animalScore,
  required int attentionScore,
  required int reorderScore,
  required Map<String, SubtestOutcome> voiceOutcomes,
}) {
  // The original five always run and cannot be skipped.
  var score = larkScore + clockScore + animalScore + attentionScore + reorderScore;
  var maxScore = 1 + 3 + 3 + 3 + 5;
  final skipped = <String>[];

  for (final spec in kVoiceSubtests) {
    final outcome = voiceOutcomes[spec.id];
    // A subtest never reached is in the same position as one explicitly
    // skipped: it was not administered.
    if (outcome == null || outcome.skipped) {
      skipped.add(spec.id);
      continue;
    }
    score += outcome.score;
    maxScore += outcome.maxScore;
  }

  return SessionTotal(score: score, maxScore: maxScore, skippedIds: skipped);
}
