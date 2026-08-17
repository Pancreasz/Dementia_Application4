/// One recognized utterance with its timing, as returned by the /transcribe
/// endpoint's `segments` field.
///
/// Deliberately in its own file with no imports: both the scoring library and
/// the ASR client need it, and neither layer should have to import the other
/// for a data class.
class AsrSegment {
  final double start;
  final double end;
  final String text;

  const AsrSegment({
    required this.start,
    required this.end,
    required this.text,
  });
}
