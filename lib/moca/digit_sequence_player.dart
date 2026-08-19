import 'dart:async';

import 'app_language.dart';
import 'audio_player.dart';

/// The per-digit stimulus file for one language. English narration ships as
/// mp3, Thai as wav — the extension follows the file the audio was actually
/// supplied in, not a fixed format.
String digitAssetFor(String digit, {Language language = Language.th}) =>
    language == Language.en
        ? 'assets/moca/audio/eng-digit-$digit.mp3'
        : 'assets/moca/audio/digit-$digit.wav';

/// Schedules Vigilance's digit stream.
///
/// Separate from AudioPlayback on purpose. That one plays a file and resolves
/// when it ends; this one schedules many and resolves when the last WINDOW
/// closes, which is a different moment from when the last sound stops.
class DigitSequencePlayer {
  final AudioPlayback playback;
  final Language language;

  final List<Timer> _timers = [];
  bool _cancelled = false;

  DigitSequencePlayer({required this.playback, this.language = Language.th});

  Future<void> play(
    String sequence, {
    required int intervalMs,
    int leadInMs = 0,
    void Function()? onStart,
  }) {
    // Retire anything still scheduled from a previous call. This must cancel
    // the timers, not merely drop the references — an emptied list would leave
    // the old sequence sounding and no longer stoppable.
    stop();
    _cancelled = false;

    final digits = sequence.split('');
    final completer = Completer<void>();
    final start = DateTime.now();

    // Every delay is recomputed against one shared start reference. Chaining
    // timers instead lets each one's few milliseconds of lateness carry into
    // the next, which over 29 digits drifts far enough to matter against a
    // 1000 ms window.
    void at(int offsetMs, void Function() fn) {
      final delay = start
          .add(Duration(milliseconds: offsetMs))
          .difference(DateTime.now());
      _timers.add(Timer(delay.isNegative ? Duration.zero : delay, fn));
    }

    for (var index = 0; index < digits.length; index++) {
      at(leadInMs + index * intervalMs, () {
        if (_cancelled) return;
        if (index == 0 && onStart != null) onStart();

        // Cut off whatever is still sounding before this digit starts. The
        // recordings run longer than the 1000 ms interval, so a tail would
        // otherwise bleed over the next digit — worst across the run of three
        // consecutive targets, where the whole point is that the patient hears
        // each one as a separate digit. Owning the boundary here means an
        // over-long file costs audio quality, never scoring accuracy.
        //
        // Deliberately not awaited: awaiting playback would push the next
        // digit's onset out by however long this one runs, which is exactly
        // the drift the shared start reference exists to prevent.
        playback.play(digitAssetFor(digits[index], language: language)).catchError((_) {
          // A digit that fails to sound is a scoring problem, not a crash: it
          // shows up as a miss rather than killing the session mid-sequence.
        });
      });
    }

    at(leadInMs + digits.length * intervalMs, () {
      if (_cancelled) return;
      if (!completer.isCompleted) completer.complete();
    });

    return completer.future;
  }

  /// Deliberately leaves play()'s future unsettled: a stopped sequence was
  /// abandoned, not completed, and resolving would let the caller score a
  /// subtest that never finished. The controller's generation guard retires
  /// that caller.
  void stop() {
    _cancelled = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    playback.stop();
  }
}
