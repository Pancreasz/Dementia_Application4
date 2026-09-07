"""Convert the Thai Whisper checkpoint to CTranslate2.

One-time step. Downloads `scb10x/typhoon-whisper-large-v3` (5.8 GB fp32
transformers safetensors) and converts it to a ~3.1 GB CT2 float16 model that
faster-whisper loads at runtime. The output (backend/models/) is gitignored.

Every knob is an environment variable because reverting is a real operation
here, not a hypothetical: the previous model
(`biodatlab/whisper-th-medium-combined` → `models/whisper-th-ct2`) is a third of
the size and was the default until 2026-09-07. To rebuild it:

    MOCA_CONVERT_MODEL=biodatlab/whisper-th-medium-combined \
    MOCA_CONVERT_OUTPUT=whisper-th-ct2 \
    MOCA_CONVERT_QUANTIZATION=int8 \
    python scripts/convert_model.py

`MOCA_CONVERT_MODEL` also accepts a local directory, so an already-downloaded
checkpoint can be converted without a second trip to the Hub.

On quantization: float16 is written rather than int8 because `asr.py` requests
`int8` at *load* time and CTranslate2 requantizes in memory on the way in. That
keeps one artifact on disk that can be loaded either way — useful while the
speed/accuracy trade-off of a large-v3 model on CPU is still being settled.
Converting straight to int8 halves the disk footprint and shortens the load,
at the cost of pinning the choice: set `MOCA_CONVERT_QUANTIZATION=int8`.

Also writes tokenizer.json into the output dir if the converter did not. Older
ct2-transformers-converter builds do not produce one, and faster-whisper's
WhisperModel silently falls back to fetching it from the Hugging Face Hub
whenever it is missing locally. Without this step /transcribe keeps working
today but quietly requires live network access to huggingface.co on every
container start, defeating a container image that is supposed to be
self-contained.

The tokenizer is fetched from SRC_MODEL, not from `openai/whisper-tiny`. This
file previously used whisper-tiny on the reasoning that "the multilingual
tokenizer is identical across Whisper sizes" — true for v1 and v2, and NOT true
for large-v3, which added `<|yue|>` and carries 51866 tokens against the older
51865. Substituting the tiny tokenizer under a large-v3 model shifts every
special-token id by one and produces confident garbage rather than an error.
whisper-tiny remains only as a last-resort fallback for a SRC_MODEL that ships
no tokenizer of its own.

Needs the conversion-only deps (not runtime):
    pip install -r requirements-convert.txt

Run:  python scripts/convert_model.py     (from the backend/ directory)

Equivalent to:
    ct2-transformers-converter \
      --model scb10x/typhoon-whisper-large-v3 \
      --quantization float16 \
      --output_dir backend/models/typhoon-large-v3-ct2
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_MODEL = os.environ.get("MOCA_CONVERT_MODEL", "scb10x/typhoon-whisper-large-v3")
QUANTIZATION = os.environ.get("MOCA_CONVERT_QUANTIZATION", "float16")
OUTPUT_DIR = os.path.join(
    BACKEND_DIR,
    "models",
    os.environ.get("MOCA_CONVERT_OUTPUT", "typhoon-large-v3-ct2"),
)


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
        print(f"CT2 model already present at {OUTPUT_DIR}.")
        if not os.path.isfile(os.path.join(OUTPUT_DIR, "tokenizer.json")):
            _write_tokenizer(OUTPUT_DIR)
        else:
            print("tokenizer.json already present; nothing to do.")
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
        "--quantization", QUANTIZATION,
        "--output_dir", OUTPUT_DIR,
    ]
    print("Running:", " ".join(cmd))
    subprocess.run(cmd, check=True)
    print(f"done: {OUTPUT_DIR}")

    _write_tokenizer(OUTPUT_DIR)


def _write_tokenizer(output_dir: str) -> None:
    """Save tokenizer.json into output_dir so faster-whisper never needs to
    fetch it from the Hugging Face Hub at model-load time. See module
    docstring for why this file must exist locally.
    """
    from tokenizers import Tokenizer

    dest = os.path.join(output_dir, "tokenizer.json")
    for source in (SRC_MODEL, "openai/whisper-tiny"):
        try:
            print(f"fetching Whisper tokenizer from {source} -> {dest} ...")
            Tokenizer.from_pretrained(source).save(dest)
            print(f"done: {dest}")
            return
        except Exception as exc:  # noqa: BLE001 - try the fallback, then report
            print(f"  could not load a tokenizer from {source}: {exc!r}")
    sys.exit(
        f"no tokenizer written to {dest}. faster-whisper will fetch one from the "
        f"Hub at every start, so the image is not self-contained."
    )


if __name__ == "__main__":
    main()
