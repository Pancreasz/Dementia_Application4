import 'subtest_outcome.dart';

/// MoCA gives the point for zero or one errors. There is no partial credit —
/// the item is worth 1 and scores 1 or 0.
const _maxErrorsForPoint = 1;

/// [taps] are millisecond offsets measured from the FIRST DIGIT'S onset, not
/// from when playback was requested — the lead-in silence sits in between and
/// a tap during it is not an answer to any digit.
SubtestOutcome scoreVigilance(
  List<int> taps, {
  required String sequence,
  required String target,
  required int intervalMs,
}) {
  final digits = sequence.split('');

  // A tap belongs to the digit whose window it lands in: digit i owns
  // [i * intervalMs, (i + 1) * intervalMs). Taps outside the sequence are
  // dropped rather than charged — the tap control is inert then, so any that
  // arrive are an artefact, not a patient error.
  final firstTapByWindow = <int, int>{};
  for (final tap in taps) {
    if (tap < 0) continue;
    final index = tap ~/ intervalMs;
    if (index >= digits.length) continue;
    // First tap only. A second tap in the same window is the same mistake
    // about the same digit, and the first one is the reaction time.
    firstTapByWindow.putIfAbsent(index, () => tap);
  }

  var hits = 0;
  var misses = 0;
  var falseTaps = 0;
  final tapLatencies = <int>[];

  for (var index = 0; index < digits.length; index++) {
    final tap = firstTapByWindow[index];
    if (digits[index] == target) {
      if (tap == null) {
        misses += 1;
      } else {
        hits += 1;
        // Measured from this target's own onset, so the value is a reaction
        // time rather than a position in the sequence.
        tapLatencies.add(tap - index * intervalMs);
      }
    } else if (tap != null) {
      falseTaps += 1;
    }
  }

  final errors = misses + falseTaps;

  return SubtestOutcome(
    subtestId: 'vigilance',
    score: errors <= _maxErrorsForPoint ? 1 : 0,
    maxScore: 1,
    detail: {
      'errors': errors,
      'hits': hits,
      'misses': misses,
      'falseTaps': falseTaps,
      'tapLatencies': tapLatencies,
    },
  );
}
