import 'matchers.dart';
import 'subtest_outcome.dart';

/// One point per pair for naming what the two things have in common, where the
/// similarity has to be an abstract category rather than a shared physical
/// feature: "vehicles" scores, "they both have wheels" does not.
///
/// There is deliberately no reject-list for the concrete answers. It sounds
/// safer than it is — "เป็นพาหนะที่มีล้อ" (vehicles that have wheels) is a
/// correct abstract answer carrying a concrete detail, and a reject-list would
/// strip a point the patient earned. The accepted terms cannot make that
/// mistake, because the answers MoCA rejects share no vocabulary with them.
const _acceptedTerms = <String, List<String>>{
  // รถไฟ (train) and จักรยาน (bicycle). The instrument allows a travel answer
  // as well as the category noun, so "ใช้เดินทาง" scores.
  'abstraction-1': ['ยานพาหนะ', 'พาหนะ', 'ขนส่ง', 'เดินทาง'],
  // นาฬิกา (watch) and ไม้บรรทัด (ruler). วัด is the bare verb "to measure"
  // and is the root of every longer accepted form. Substring matching on it is
  // safe here: ไม้บรรทัด ends in ทัด, not วัด, so a patient who only repeats
  // the question back matches nothing.
  'abstraction-2': ['เครื่องมือวัด', 'เครื่องวัด', 'การวัด', 'วัด'],
};

SubtestOutcome scoreAbstraction(String subtestId, String transcript) {
  final terms = _acceptedTerms[subtestId];
  // A typo in a subtest id would otherwise score every patient zero on an item
  // that was never really administered, and look like a clinical finding.
  if (terms == null) {
    throw ArgumentError('No accepted terms registered for abstraction item "$subtestId"');
  }

  String? matched;
  for (final term in terms) {
    if (keywordMatch(transcript, [term])) {
      matched = term;
      break;
    }
  }

  return SubtestOutcome(
    subtestId: subtestId,
    score: matched != null ? 1 : 0,
    maxScore: 1,
    transcript: transcript,
    detail: {'matched': matched},
  );
}
