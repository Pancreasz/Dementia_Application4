import 'dart:async';

import 'app_language.dart';
import 'audio_player.dart';

/// Vigilance's whole digit stream, as one file.
///
/// The per-digit recordings it is built from are still in the assets directory,
/// but nothing plays them: they are source material for the build script.
///
/// Built by `tool/build_sequences.py`, which lays each digit out at exactly
/// intervalMs so scoring's `offset ~/ intervalMs` bucketing lines up with what
/// the patient actually heard. Regenerate it after editing kVigilanceSequence.
String vigilanceAssetFor({Language language = Language.th}) =>
    language == Language.en
        ? 'assets/moca/audio/eng-vigilance.wav'
        : 'assets/moca/audio/vigilance.wav';

/// Plays Vigilance's digit stream and reports when the last tap WINDOW closes,
/// which is a different moment from when the last sound stops.
///
/// Separate from a plain AudioPlayback.play() for that reason, and because the
/// sequence's start has to be observed rather than assumed — see [play].
class DigitSequencePlayer {
  final AudioPlayback playback;
  final Language language;

  final List<Timer> _timers = [];
  bool _cancelled = false;

  DigitSequencePlayer({required this.playback, this.language = Language.th});

  /// Plays the merged stimulus for [sequence] and resolves once every digit's
  /// window has closed.
  ///
  /// [sequence] is not used to pick files — one file holds them all — only to
  /// count how many windows there are.
  ///
  /// This used to schedule one play() per digit, 1000 ms apart, through a
  /// single shared player, each call stopping the last. Because the recordings
  /// run longer than the interval, that made every digit depend on its fetch
  /// and decode finishing inside 1000 ms; on mobile browsers it usually did
  /// not, so digits were cut off before they were audible and the failures
  /// were invisible. The merged file makes it one fetch, and puts the spacing
  /// in the audio instead of in a row of timers racing the network.
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

    final completer = Completer<void>();

    // Started now so the fetch and decode overlap the lead-in silence rather
    // than delaying the first digit. A failure here surfaces when start() is
    // awaited below; swallowing it now would only lose the reason.
    final loaded = playback.load(vigilanceAssetFor(language: language));

    _timers.add(Timer(Duration(milliseconds: leadInMs), () async {
      if (_cancelled) return;
      try {
        await loaded;
        if (_cancelled) return;
        await playback.start();
      } catch (_) {
        // A stimulus that will not sound is not something this player can
        // recover from, and throwing out of a timer callback would take the
        // session with it. The subtest is left to time out, which the
        // controller already treats as unadministered.
        return;
      }
      if (_cancelled) return;

      // Only now is there a sound to measure taps against. Every window is
      // timed from here rather than from play(), so a slow start shifts the
      // digits and their windows together instead of pulling them apart.
      onStart?.call();

      _timers.add(Timer(Duration(milliseconds: sequence.length * intervalMs), () {
        if (_cancelled) return;
        if (!completer.isCompleted) completer.complete();
      }));
    }));

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
