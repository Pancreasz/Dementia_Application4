"""Convert ad_hw's QuickTime-container audio to 16 kHz mono WAV.

The source files are named .mp3 but are AAC in a QuickTime container. Chromium
sniffs content and plays them; Flutter audio plugins are not guaranteed to.
WAV removes the question. Run with ad_hw's venv, which bundles FFmpeg via PyAV:

  D:/moca_ad/ad_hw/sidecar/.venv/Scripts/python.exe tool/convert_audio.py
"""

import pathlib
import av
from av.audio.resampler import AudioResampler

DST = pathlib.Path("assets/moca/audio")

AD_HW = pathlib.Path("D:/moca_ad/ad_hw/src/renderer/public/moca/audio")
RECORDINGS = pathlib.Path("D:/moca_ad")

# (source file, destination stem). The digit and digit-span stimuli come from
# the ad_hw project; the two sentences were recorded separately. Both sets are
# AAC in QuickTime containers named .mp3, so they convert identically.
SOURCES = (
    [(AD_HW / "digits-forward.mp3", "digits-forward"),
     (AD_HW / "digits-backward.mp3", "digits-backward")]
    + [(AD_HW / f"digit-{d}.mp3", f"digit-{d}") for d in range(10)]
    + [(RECORDINGS / "sentence1.mp3", "sentence-1"),
       (RECORDINGS / "sentence2.mp3", "sentence-2")]
)


def convert(src, stem):
    dst = DST / f"{stem}.wav"

    inp = av.open(str(src))
    stream = inp.streams.audio[0]
    duration_s = float(stream.duration * stream.time_base)

    out = av.open(str(dst), "w", format="wav")
    out_stream = out.add_stream("pcm_s16le", rate=16000, layout="mono")
    resampler = AudioResampler(format="s16", layout="mono", rate=16000)

    for frame in inp.decode(stream):
        for resampled in resampler.resample(frame):
            for packet in out_stream.encode(resampled):
                out.mux(packet)
    for packet in out_stream.encode(None):
        out.mux(packet)

    out.close()
    inp.close()
    return duration_s


def main():
    DST.mkdir(parents=True, exist_ok=True)
    for src, stem in SOURCES:
        duration = convert(src, stem)
        # Durations are printed because the digit files overrun the 1000 ms
        # vigilance slot, and Task 13's player must cut them off. Seeing the
        # real numbers keeps that from being a surprise.
        print(f"{stem:20s} {duration * 1000:7.1f} ms")


if __name__ == "__main__":
    main()
