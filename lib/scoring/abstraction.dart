import '../moca/app_language.dart';
import 'subtest_outcome.dart';

/// One point per pair for naming what the two things have in common, where the
/// similarity has to be an abstract category rather than a shared physical
/// feature: "vehicles" scores, "they both have wheels" does not.
///
/// SCORED BY EMBEDDING SIMILARITY, NOT SUBSTRING MATCH
/// ---------------------------------------------------
/// This used to score 1 if the transcript *contained* an accepted term. That
/// tested vocabulary overlap with a hand-written list, not abstraction: a
/// patient who said "vehicle" against a list holding "transportation" scored 0
/// for a correct abstract answer. The answer is now embedded by the backend and
/// compared against the accepted category terms.
///
/// There is deliberately no reject-list for the concrete answers. It sounds
/// safer than it is — "เป็นพาหนะที่มีล้อ" (vehicles that have wheels) is a
/// correct abstract answer carrying a concrete detail, and a reject-list would
/// strip a point the patient earned.
const _acceptedTermsTh = <String, List<String>>{
  // รถไฟ (train) and จักรยาน (bicycle). The instrument allows a travel answer
  // as well as the category noun, so "ใช้เดินทาง" scores.
  'abstraction-1': ['ยานพาหนะ', 'พาหนะ', 'ขนส่ง', 'เดินทาง'],
  // นาฬิกา (watch) and ไม้บรรทัด (ruler). วัด is the bare verb "to measure"
  // and is the root of every longer accepted form.
  'abstraction-2': ['เครื่องมือวัด', 'เครื่องวัด', 'การวัด', 'วัด'],
};

/// English equivalents of the Thai terms above: train/bicycle -> vehicle
/// (transportation), watch/ruler -> measuring instrument (measurement).
///
/// 'travel' and 'getting around' mirror the Thai list's structure rather than
/// widening it — the Thai side already carries both the category noun
/// (ยานพาหนะ) and the travel verb (เดินทาง), and the English list originally
/// carried only nouns. Measured on 2026-09-07, that asymmetry cost the correct
/// answer "both are used for getting around" its point: 0.193 against the
/// noun-only list, 0.477 with the verb forms restored.
const _acceptedTermsEn = <String, List<String>>{
  'abstraction-1': [
    'vehicle',
    'vehicles',
    'transportation',
    'transport',
    'travel',
    'getting around',
  ],
  'abstraction-2': [
    'measuring instrument',
    'measuring device',
    'measurement',
    'measure',
  ],
};

/// The two things the patient was asked to compare.
///
/// NOT what the answer is scored against — scoring against these is the trap
/// the whole design avoids, because it inverts the clinical logic. MoCA scores
/// abstraction, not association: "they both have wheels" and "you ride them"
/// are supposed to fail, and they are semantically *near* the stimuli, while
/// the correct category answer is further away. Measured on 2026-09-07,
/// scoring against the stimuli ranks the worst possible answer highest —
/// "รถไฟกับจักรยาน" (just repeating the question back) scored 0.737 against
/// the stimuli where the correct "เป็นยานพาหนะ" scored 0.511.
///
/// They are embedded anyway, and used only as a GUARD: see [_isStimulusEcho].
const _stimulusWordsTh = <String, List<String>>{
  'abstraction-1': ['รถไฟ', 'จักรยาน'],
  'abstraction-2': ['นาฬิกา', 'ไม้บรรทัด'],
};

const _stimulusWordsEn = <String, List<String>>{
  'abstraction-1': ['train', 'bicycle'],
  'abstraction-2': ['watch', 'ruler'],
};

/// UNVALIDATED. The third invented number in this app, alongside sentence
/// repetition's 0.90 and verbal fluency's 11 words.
///
/// Chosen on 2026-09-07 against 25 hand-written answers — not patient data — so
/// this is a starting point for review, not a measured cutoff. What that
/// exercise actually showed, recorded here because it is the thing most likely
/// to be assumed away later:
///
///   NO SINGLE THRESHOLD SEPARATES BOTH LANGUAGES on those cases. Thai's
///   best-scoring *wrong* answer ("มีล้อทั้งคู่", they both have wheels) reached
///   0.547, above English's weakest *correct* answer ("both are used for
///   getting around") at 0.477. 0.55 therefore sits inside a known overlap: it
///   rejects the Thai concrete answer by 0.003 and rejects a correct English
///   one outright.
///
/// Two per-language thresholds would fit those 25 cases. That is not done here:
/// it would double the number of invented constants to fit invented data, and
/// the honest position is one documented number whose failure boundary is
/// written down. Settling it needs real sessions, which is what storing the
/// full similarity map below is for.
///
/// Overridable at build time without a code change:
///   flutter run --dart-define=MOCA_ABSTRACTION_THRESHOLD=0.6
///
/// Read as a String and parsed because Dart has no `double.fromEnvironment` —
/// only String, int and bool. An unparseable value falls back to the default
/// rather than throwing at startup: a typo in a build flag must not take the
/// whole app down mid-clinic, and 0.55 is the documented behaviour anyway.
final double kAbstractionSimilarityThreshold = double.tryParse(
      const String.fromEnvironment('MOCA_ABSTRACTION_THRESHOLD'),
    ) ??
    0.55;

List<String> acceptedTermsFor(String subtestId, {Language? language}) {
  final lang = language ?? AppLanguage.current;
  final terms = (lang == Language.en ? _acceptedTermsEn : _acceptedTermsTh)[subtestId];
  // A typo in a subtest id would otherwise score every patient zero on an item
  // that was never really administered, and look like a clinical finding.
  if (terms == null) {
    throw ArgumentError('No accepted terms registered for abstraction item "$subtestId"');
  }
  return terms;
}

List<String> stimulusWordsFor(String subtestId, {Language? language}) {
  final lang = language ?? AppLanguage.current;
  final words =
      (lang == Language.en ? _stimulusWordsEn : _stimulusWordsTh)[subtestId];
  if (words == null) {
    throw ArgumentError('No stimulus words registered for abstraction item "$subtestId"');
  }
  return words;
}

/// True when the answer sits closer to the two stimulus words than to any
/// accepted category term — the signature of "a train and a bicycle", an answer
/// that restates the question without attempting abstraction.
///
/// This is the one legitimate use of stimulus distance. It is comparative, so
/// it needs no second threshold, and it only ever takes a point AWAY from an
/// answer the category similarity was about to pass. Measured on 2026-09-07 it
/// caught every stimulus-echo case in both languages (Thai -0.327 and -0.452,
/// English -0.105 and -0.187 category-minus-stimulus) and changed no other
/// verdict.
bool _isStimulusEcho(double bestCategory, double bestStimulus) =>
    bestStimulus >= bestCategory;

/// Scores an abstraction item from similarities the backend already computed.
///
/// Pure and synchronous by design: the network call lives in the caller, so
/// every scoring rule here is testable without a backend or a model.
///
/// [categoryScores] maps each accepted term to its cosine similarity with the
/// patient's answer; [stimulusScores] does the same for the two stimulus words.
SubtestOutcome scoreAbstractionFromSimilarities(
  String subtestId,
  String transcript, {
  required Map<String, double> categoryScores,
  required Map<String, double> stimulusScores,
  // Resolved inside rather than defaulted in the signature: the constant is
  // `final` (it parses a --dart-define), and Dart requires default parameter
  // values to be `const`.
  double? threshold,
}) {
  final cutoff = threshold ?? kAbstractionSimilarityThreshold;
  // Silence is scored 0 without consulting the model at all.
  //
  // Not an optimisation. The empty string does NOT embed to a zero vector —
  // measured 2026-09-07, it scored 0.42-0.49 against the English accepted
  // terms, which is above two of the concrete wrong answers and within 0.06 of
  // this threshold. A patient who said nothing would have been scored on the
  // model's opinion of the empty string. `detail.reason` records this as a
  // non-response rather than a wrong answer, which the analysis page needs to
  // tell apart.
  if (transcript.trim().isEmpty) {
    return SubtestOutcome(
      subtestId: subtestId,
      score: 0,
      maxScore: 1,
      transcript: transcript,
      detail: const {'reason': 'no-response', 'matched': null},
    );
  }

  double bestOf(Map<String, double> scores) => scores.values.isEmpty
      ? 0.0
      : scores.values.reduce((a, b) => a > b ? a : b);

  final bestCategory = bestOf(categoryScores);
  final bestStimulus = bestOf(stimulusScores);
  String? bestTerm;
  for (final entry in categoryScores.entries) {
    if (entry.value == bestCategory) {
      bestTerm = entry.key;
      break;
    }
  }

  final echo = _isStimulusEcho(bestCategory, bestStimulus);
  final passed = bestCategory >= cutoff && !echo;

  return SubtestOutcome(
    subtestId: subtestId,
    score: passed ? 1 : 0,
    maxScore: 1,
    transcript: transcript,
    // The FULL similarity map is kept, not just the maximum. Three reasons,
    // all of them about being able to check this later:
    //   - "correct category, low similarity" is a scoring artefact and cannot
    //     be told from a genuine miss without seeing every term's score;
    //   - the threshold above is unvalidated and will need re-choosing against
    //     real answers, which is impossible from a stored pass/fail;
    //   - `reason` names WHICH rule failed, so a stimulus echo is not filed as
    //     the same failure as a concrete answer.
    detail: {
      'matched': passed ? bestTerm : null,
      'reason': passed
          ? 'category-match'
          : echo
              ? 'stimulus-echo'
              : 'below-threshold',
      'best_term': bestTerm,
      'best_category_similarity': bestCategory,
      'best_stimulus_similarity': bestStimulus,
      'threshold': cutoff,
      'category_similarities': categoryScores,
      'stimulus_similarities': stimulusScores,
    },
  );
}
