"""Manual end-to-end check for /transcribe against the real CT2 model.

Loads the model, waits until ready, transcribes one or more WAV files, and
writes UTF-8 JSON to stdout (and to a file if --out is given). Console piping on
Windows mangles Thai; the JSON file is the source of truth.

Run (from backend/):
    python scripts/smoke_transcribe.py ../assets/moca/audio/digit-2.wav
    python scripts/smoke_transcribe.py            # defaults to a few digits
"""

from __future__ import annotations

import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from asr import AsrModel  # noqa: E402

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULTS = [
    os.path.join(BACKEND_DIR, "..", "assets", "moca", "audio", f"digit-{d}.wav")
    for d in (2, 7, 5, 0)
]


def main(argv):
    out_path = None
    if "--out" in argv:
        i = argv.index("--out")
        out_path = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    wavs = argv or DEFAULTS

    m = AsrModel()
    t0 = time.time()
    m.start_loading()
    while m.state.value == "loading" and time.time() - t0 < 300:
        time.sleep(0.5)
    load_secs = round(time.time() - t0, 1)

    report = {"load_state": m.state.value, "load_seconds": load_secs, "results": []}
    if m.is_ready:
        for wav in wavs:
            t1 = time.time()
            r = m.transcribe(wav, language="th")
            report["results"].append(
                {
                    "file": os.path.basename(wav),
                    "text": r.text,
                    "segments": [s.to_dict() for s in r.segments],
                    "transcribe_seconds": round(time.time() - t1, 2),
                }
            )
    else:
        report["detail"] = m.detail

    blob = json.dumps(report, ensure_ascii=False, indent=2)
    sys.stdout.buffer.write(blob.encode("utf-8"))
    sys.stdout.buffer.write(b"\n")
    if out_path:
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(blob)


if __name__ == "__main__":
    main(sys.argv[1:])
