import 'package:flutter/foundation.dart';

import '../scoring/subtest_outcome.dart';

/// Console output for every score the app decides, as it decides it.
///
/// This is the only place a transcript is ever read. `SubtestOutcome.transcript`
/// and `.detail` are recorded by the scorers "for review", but until now there
/// was no review surface at all and the data died with the process — which also
/// left the two unvalidated similarity thresholds impossible to check against a
/// real patient. One line per subtest in the browser console is not a review
/// screen, but it is the difference between a surprising score being explicable
/// and being a mystery.
///
/// **These lines contain patient speech.** They are health information. The
/// browser console is fine for development and for a supervised session; it is
/// not somewhere to leave transcripts on a shared machine.
///
/// `debugPrint` rather than `print`: it satisfies `avoid_print`, it is
/// overridable in tests, and it survives a release build — which matters,
/// because `flutter build web -o docs` is a release build and these lines are
/// meant to appear on the published site too.
const String _tag = '[MoCA]';

/// Called when the clock backend answers. [rawScore] is the decoded JSON value
/// rather than an `int` on purpose: `/upload`'s contract says
/// `predicted_moca_score` must be a JSON integer, and a `2.0` or `"2"` throws
/// inside a `try` that only catches parse errors, surfacing as a misleading
/// "Error parsing server response". Printing the runtime type turns that into a
/// one-glance diagnosis.
void logClockScore(Object? rawScore, {String? filename}) {
  final type = rawScore.runtimeType;
  final suffix = rawScore is int ? '' : '  <-- expected an int, got $type';
  // Padded exactly as a subtest id is, so clock and voice lines form one
  // readable column in a console that also carries framework noise.
  debugPrint(
    '$_tag ${_pad('clock', 21)}  ${rawScore ?? '?'}/3'
    '${filename == null ? '' : '  file: $filename'}$suffix',
  );
}

/// Called once per subtest, the moment its outcome is decided — including
/// skips, which is why this takes the outcome rather than a score.
void logSubtestOutcome(SubtestOutcome outcome) {
  final id = _pad(outcome.subtestId, 21);

  if (outcome.skipped) {
    // Not "0". A skip asserts the subtest was never administered; a zero
    // asserts the patient failed it.
    debugPrint('$_tag $id  SKIPPED (not administered, excluded from total)');
    return;
  }

  final buffer = StringBuffer('$_tag $id  ${outcome.score}/${outcome.maxScore}');

  final heard = outcome.transcript.trim();
  if (heard.isNotEmpty) {
    buffer.write('  heard: "$heard"');
  }

  if (outcome.detail.isNotEmpty) {
    final pairs =
        outcome.detail.entries.map((e) => '${e.key}=${e.value}').join(' ');
    buffer.write('  [$pairs]');
  }

  debugPrint(buffer.toString());
}

String _pad(String value, int width) =>
    value.length >= width ? value : value.padRight(width);
