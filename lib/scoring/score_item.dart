import '../moca/session_config.dart';
import '../moca/subtest_spec.dart';
import 'abstraction.dart';
import 'asr_segment.dart';
import 'digit_span.dart';
import 'orientation.dart';
import 'sentence_repetition.dart';
import 'subtest_outcome.dart';
import 'verbal_fluency.dart';
import 'vigilance.dart';

/// Maps a subtest to its scorer. One place, so the session controller does not
/// carry a switch and a new subtest is registered exactly once.
SubtestOutcome scoreItem(
  SubtestSpec spec, {
  String transcript = '',
  List<AsrSegment> segments = const [],
  List<int> taps = const [],
  DateTime? referenceDate,
}) {
  switch (spec.id) {
    case 'digit-span-forward':
    case 'digit-span-backward':
      return scoreDigitSpan(spec.id, transcript, spec.expectedSequence!);

    case 'vigilance':
      // The only scorer whose answer is not speech.
      return scoreVigilance(
        taps,
        sequence: spec.sequence!,
        target: spec.target!,
        intervalMs: spec.intervalMs,
      );

    case 'sentence-repetition-1':
    case 'sentence-repetition-2':
      return scoreSentenceRepetition(
          spec.id, transcript, spec.expectedSentence!);

    case 'verbal-fluency':
      return scoreVerbalFluency(segments, initialLetter: spec.initialLetter);

    case 'abstraction-1':
    case 'abstraction-2':
      return scoreAbstraction(spec.id, transcript);

    case 'orientation':
      return scoreOrientation(
        transcript,
        referenceDate: referenceDate ?? DateTime.now(),
        place: SessionConfig.place,
        province: SessionConfig.province,
      );

    default:
      // A typo in an id must not silently score a patient zero on a subtest
      // that was never really administered.
      throw ArgumentError('No scorer registered for subtest "${spec.id}"');
  }
}
