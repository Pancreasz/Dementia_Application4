"""Convert the Thai Whisper checkpoint to CTranslate2 int8.

One-time step. Downloads `biodatlab/whisper-th-medium-combined` (1.63 GB fp16
transformers safetensors) and converts it to a ~800 MB CT2 int8 model that
faster-whisper loads at runtime. The output (backend/models/) is gitignored.

Needs the conversion-only deps (not runtime):
    pip install -r requirements-convert.txt

Run:  python scripts/convert_model.py     (from the backend/ directory)

Equivalent to:
    ct2-transformers-converter \
      --model biodatlab/whisper-th-medium-combined \
      --quantization int8 \
      --output_dir backend/models/whisper-th-ct2
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(BACKEND_DIR, "models", "whisper-th-ct2")
SRC_MODEL = "biodatlab/whisper-th-medium-combined"


def _converter_cmd():
    """Locate ct2-transformers-converter next to the running interpreter first
    (so it works without the venv's Scripts dir on PATH), then fall back to PATH.
    """
    scripts_dir = os.path.dirname(sys.executable)
    for name in ("ct2-transformers-converter.exe", "ct2-transformers-converter"):
        candidate = os.path.join(scripts_dir, name)
        if os.path.exists(candidate):
            return [candidate]
    on_path = shutil.which("ct2-transformers-converter")
    if on_path:
        return [on_path]
    return None


def main():
    if os.path.isdir(OUTPUT_DIR) and os.listdir(OUTPUT_DIR):
        print(f"CT2 model already present at {OUTPUT_DIR}; nothing to do.")
        return

    base = _converter_cmd()
    if base is None:
        sys.exit(
            "ct2-transformers-converter not found. Install conversion deps:\n"
            "  pip install -r requirements-convert.txt"
        )

    os.makedirs(os.path.dirname(OUTPUT_DIR), exist_ok=True)
    cmd = base + [
        "--model", SRC_MODEL,
        "--quantization", "int8",
        "--output_dir", OUTPUT_DIR,
    ]
    print("Running:", " ".join(cmd))
    subprocess.run(cmd, check=True)
    print(f"done: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
