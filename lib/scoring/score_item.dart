import '../moca/app_language.dart';
import '../moca/session_config.dart';
import '../moca/similarity_client.dart';
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
///
/// Async because of abstraction alone: it is the only rule here that consults
/// the backend. Every other scorer returns without awaiting anything, so the
/// Future they produce is already complete. Making the ONE registry async is
/// preferred to letting the session controller special-case abstraction, which
/// would put a second scoring switch in the app.
Future<SubtestOutcome> scoreItem(
  SubtestSpec spec, {
  String transcript = '',
  List<AsrSegment> segments = const [],
  List<int> taps = const [],
  DateTime? referenceDate,
  SimilarityClient? similarity,
}) async {
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
          spec.id, transcript, spec.expectedSentenceForLanguage!);

    case 'verbal-fluency':
      return scoreVerbalFluency(segments,
          initialLetter: spec.initialLetterForLanguage);

    case 'abstraction-1':
    case 'abstraction-2':
      // A missing client is a wiring mistake, not a patient finding. Scoring 0
      // here would assert the patient failed an item the app never actually
      // evaluated, so this throws rather than defaulting.
      if (similarity == null) {
        throw ArgumentError(
            'abstraction needs a SimilarityClient; "${spec.id}" is scored by the backend');
      }
      // Silence is scored without a round trip. Skipping the call is not just
      // an optimisation — see scoreAbstractionFromSimilarities for why the
      // empty string must never reach the model.
      if (transcript.trim().isEmpty) {
        return scoreAbstractionFromSimilarities(
          spec.id,
          transcript,
          categoryScores: const {},
          stimulusScores: const {},
        );
      }

      final terms = acceptedTermsFor(spec.id, language: AppLanguage.current);
      final stimuli = stimulusWordsFor(spec.id, language: AppLanguage.current);
      // One request carrying both lists, then split apart by key. Two requests
      // would double the round trips and, worse, could straddle a backend
      // restart and mix similarities from two different models.
      final result = await similarity.compare(transcript, [...terms, ...stimuli]);
      Map<String, double> pick(List<String> keys) => {
            for (final k in keys)
              if (result.similarities.containsKey(k)) k: result.similarities[k]!,
          };

      return scoreAbstractionFromSimilarities(
        spec.id,
        transcript,
        categoryScores: pick(terms),
        stimulusScores: pick(stimuli),
      );

    case 'orientation':
      return scoreOrientation(
        transcript,
        referenceDate: referenceDate ?? DateTime.now(),
        place: SessionConfig.place,
        province: SessionConfig.province,
        language: AppLanguage.current,
      );

    default:
      // A typo in an id must not silently score a patient zero on a subtest
      // that was never really administered.
      throw ArgumentError('No scorer registered for subtest "${spec.id}"');
  }
}
