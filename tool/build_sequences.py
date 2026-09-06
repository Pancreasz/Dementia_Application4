"""Lay the per-digit recordings out into one merged file per stimulus sequence.

Digit Span and Vigilance used to be streamed a file at a time: one play() call
per digit, 1000 ms apart, through a single shared audio element. That only ever
made a sound when each fetch and decode finished inside the 1000 ms slot. On
desktop it did; on a mobile browser it usually did not, so most digits were cut
off by the next digit's stop() before they were audible. Merging ahead of time
replaces 29 races against the network with a single fetch, and moves the timing
into the file, where it is sample-accurate.

Each digit is trimmed to its speech and placed at a fixed onset inside its own
slot, so digit i starts at exactly i * SLOT_MS. Vigilance scoring buckets taps
by `offset ~/ intervalMs`, and that arithmetic is only true if the file really
does put the digits on that grid.

Run with the project venv:

  ./.venv/Scripts/python.exe tool/build_sequences.py
"""

import pathlib
import re
import wave

import av
import numpy as np
from av.audio.resampler import AudioResampler

AUDIO = pathlib.Path("assets/moca/audio")
SUBTESTS = pathlib.Path("lib/moca/subtests.dart")

SLOT_MS = 1000
"""One digit per second, the rate the MoCA is administered at. Vigilance scores
against this same number on the Dart side (SubtestSpec.intervalMs)."""

ONSET_MS = 80
"""Where the speech starts inside its slot. Non-zero so a digit does not begin
on the exact instant the previous slot ends, which reads as clipped."""

HEAD_MS, TAIL_MS = 30, 150
"""Kept either side of the detected speech, so the natural attack and decay
survive the trim. A Thai digit's final consonant lives in that tail."""

OUT_RATE = 16000
"""Speech, and what the recogniser already works at. A third the size of the
48 kHz sources, which is the difference that matters over a mobile link."""

# Heard order, which is not always the scored order: Digit Span Backward plays
# 742 and the patient is scored on saying 247. Keep these in step with
# kVoiceSubtests[].expectedSequence in lib/moca/subtests.dart.
FORWARD = "21854"
BACKWARD = "742"


def read_wav(path):
    with wave.open(str(path)) as w:
        assert w.getnchannels() == 1 and w.getsampwidth() == 2, path
        return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16), w.getframerate()


def speech_bounds(samples, rate):
    """First and last sample of actual speech, by RMS envelope.

    Peak-based detection picks up isolated clicks in the room tone; averaging
    over a window ignores them.
    """
    window = max(1, rate // 100)
    usable = len(samples) - len(samples) % window
    frames = samples[:usable].astype(np.float32).reshape(-1, window)
    rms = np.sqrt((frames**2).mean(axis=1))
    loud = np.flatnonzero(rms > rms.max() * 0.02)
    if not len(loud):
        raise ValueError("no speech found")
    return loud[0] * window, min((loud[-1] + 1) * window, len(samples))


def slot_for(digit_path, rate):
    """One digit, trimmed and padded out to exactly SLOT_MS."""
    samples, src_rate = read_wav(digit_path)
    assert src_rate == rate, f"{digit_path} is {src_rate} Hz, expected {rate}"

    start, end = speech_bounds(samples, rate)
    start = max(0, start - HEAD_MS * rate // 1000)
    end = min(len(samples), end + TAIL_MS * rate // 1000)
    speech = samples[start:end]

    slot = np.zeros(SLOT_MS * rate // 1000, dtype=np.int16)
    offset = ONSET_MS * rate // 1000
    if offset + len(speech) > len(slot):
        raise ValueError(
            f"{digit_path.name}: {len(speech) * 1000 // rate} ms of speech "
            f"does not fit a {SLOT_MS} ms slot"
        )
    slot[offset:offset + len(speech)] = speech
    return slot


def resample(samples, src_rate):
    frame = av.AudioFrame.from_ndarray(samples.reshape(1, -1), format="s16", layout="mono")
    frame.rate = src_rate
    resampler = AudioResampler(format="s16", layout="mono", rate=OUT_RATE)
    out = [f.to_ndarray().reshape(-1) for f in resampler.resample(frame)]
    out += [f.to_ndarray().reshape(-1) for f in resampler.resample(None)]
    return np.concatenate(out) if out else np.zeros(0, dtype=np.int16)


def build(sequence, prefix, stem):
    digits = [AUDIO / f"{prefix}digit-{d}.wav" for d in sequence]
    _, rate = read_wav(digits[0])
    track = np.concatenate([slot_for(p, rate) for p in digits])
    track = resample(track, rate)

    dst = AUDIO / f"{prefix}{stem}.wav"
    with wave.open(str(dst), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(OUT_RATE)
        w.writeframes(track.tobytes())
    print(f"{dst.name:26s} {len(sequence):2d} digits  {len(track) / OUT_RATE:6.2f} s  "
          f"{dst.stat().st_size // 1024:5d} KB")


def vigilance_sequence():
    """Read from the Dart source so the audio cannot drift from the scoring.

    The sequence is 29 digits with a deliberate run of three consecutive
    targets in it. Retyping it here would be one transposition away from an
    audio file that no longer matches what the scorer expects.
    """
    match = re.search(r"kVigilanceSequence\s*=\s*'(\d+)'", SUBTESTS.read_text(encoding="utf-8"))
    if not match:
        raise SystemExit(f"kVigilanceSequence not found in {SUBTESTS}")
    return match.group(1)


def main():
    vigilance = vigilance_sequence()
    for prefix in ("", "eng-"):
        build(FORWARD, prefix, "digits-forward")
        build(BACKWARD, prefix, "digits-backward")
        build(vigilance, prefix, "vigilance")


if __name__ == "__main__":
    main()
