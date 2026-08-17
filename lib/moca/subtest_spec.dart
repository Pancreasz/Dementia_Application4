enum ResponseMode { voice, tap }

/// One subtest, as data. The engine renders and scores every subtest from one
/// of these, so adding a subtest is an entry in kVoiceSubtests rather than a
/// new screen.
class SubtestSpec {
  final String id;
  final String section;
  final String instructionTh;
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

  /// Digit Span only.
  final String? expectedSequence;

  /// Sentence Repetition only.
  final String? expectedSentence;

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

  const SubtestSpec({
    required this.id,
    required this.section,
    required this.instructionTh,
    required this.maxScore,
    this.responseMode = ResponseMode.voice,
    this.stimulusAsset,
    this.expectedSequence,
    this.expectedSentence,
    this.timeLimitSec,
    this.enforceTimeLimit = false,
    this.sequence,
    this.target,
    this.intervalMs = 1000,
    this.leadInMs = 1000,
    this.initialLetter,
  });
}
