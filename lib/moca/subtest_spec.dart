import 'app_language.dart';

enum ResponseMode { voice, tap }

/// One subtest, as data. The engine renders and scores every subtest from one
/// of these, so adding a subtest is an entry in kVoiceSubtests rather than a
/// new screen.
class SubtestSpec {
  final String id;
  final String section;
  final String instructionTh;

  /// English administration of [instructionTh]. Required — every subtest is
  /// English-mode capable, so there is no "falls back to Thai" case to hide
  /// a missing translation behind.
  final String instructionEn;
  final int maxScore;
  final ResponseMode responseMode;

  /// Played before the microphone opens.
  ///
  /// Null means this subtest has no stimulus BY DESIGN — Abstraction and
  /// Orientation ask their question in the instruction text, so the microphone
  /// opens immediately. A non-null path whose file fails to load is a
  /// different situation entirely: the controller skips that subtest rather
  /// than recording a patient answering a question they never heard.
  final String? stimulusAsset;

  /// English-mode counterpart to [stimulusAsset]. Null wherever
  /// [stimulusAsset] is null, for the same "no stimulus by design" reason.
  final String? stimulusAssetEn;

  /// Digit Span only. Digits are read the same regardless of language, so
  /// there is no English variant — only the narrating audio differs.
  final String? expectedSequence;

  /// Sentence Repetition only.
  final String? expectedSentence;

  /// English-mode counterpart to [expectedSentence].
  final String? expectedSentenceEn;

  /// Recorded with the result. Only enforced when [enforceTimeLimit] is true,
  /// which is Verbal Fluency alone — everywhere else this is a budget, not a
  /// deadline, and no clock is shown.
  final int? timeLimitSec;
  final bool enforceTimeLimit;

  /// Vigilance only.
  final String? sequence;
  final String? target;
  final int intervalMs;
  final int leadInMs;

  /// Verbal Fluency only. Null means a category prompt, where every word counts.
  final String? initialLetter;

  /// English-mode counterpart to [initialLetter]. The standard English MoCA
  /// administration asks for the letter F rather than ก.
  final String? initialLetterEn;

  const SubtestSpec({
    required this.id,
    required this.section,
    required this.instructionTh,
    required this.instructionEn,
    required this.maxScore,
    this.responseMode = ResponseMode.voice,
    this.stimulusAsset,
    this.stimulusAssetEn,
    this.expectedSequence,
    this.expectedSentence,
    this.expectedSentenceEn,
    this.timeLimitSec,
    this.enforceTimeLimit = false,
    this.sequence,
    this.target,
    this.intervalMs = 1000,
    this.leadInMs = 1000,
    this.initialLetter,
    this.initialLetterEn,
  });

  /// The instruction text for the session's current language.
  String get instruction => AppLanguage.isEnglish ? instructionEn : instructionTh;

  /// The stimulus asset for the session's current language. Still null
  /// wherever the language-specific field is null — "no stimulus by design"
  /// does not change with language.
  String? get stimulusAssetForLanguage =>
      AppLanguage.isEnglish ? stimulusAssetEn : stimulusAsset;

  /// The expected sentence for the session's current language.
  String? get expectedSentenceForLanguage =>
      AppLanguage.isEnglish ? expectedSentenceEn : expectedSentence;

  /// The verbal fluency initial letter for the session's current language.
  String? get initialLetterForLanguage =>
      AppLanguage.isEnglish ? initialLetterEn : initialLetter;
}
