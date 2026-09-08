"""What the clock weights file is supposed to be, and how to say what it isn't.

Deliberately importless beyond the stdlib: `scripts/restore_weights.py` runs
before anyone has a reason to trust that torch is installed, and importing
`clock` just to read three constants would drag torchvision in with it.

The size and hash describe one specific file — the blob recovered from git
history in `restore_weights.py`. Anything else pointed at by
`MOCA_CLOCK_WEIGHTS` is somebody's own checkpoint and is none of this module's
business; [is_canonical] is how callers tell the two apart before quoting a
mismatch at the user.
"""

from __future__ import annotations

import hashlib
import os

BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
WEIGHTS_PATH = os.path.join(BACKEND_DIR, "moca_densenet.pth")
EXPECTED_BYTES = 28440806
EXPECTED_SHA256 = "1c064caefc06db83bf84001811e5d3d96f3c2d9bae054921df76ca5536d65dbc"

RESTORE_COMMAND = "python scripts/restore_weights.py  (from backend/)"


def sha256_of(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_canonical(path: str) -> bool:
    """True if `path` is the repo's own weights file, not a custom checkpoint."""
    return os.path.abspath(path) == os.path.abspath(WEIGHTS_PATH)


def describe_problem(path: str, *, check_hash: bool = True) -> str:
    """Why the file at `path` is not the weights file. Empty string if it is.

    `check_hash=False` skips the 28 MB read for callers that only want to know
    whether the file is plausibly whole — the size alone catches the partial
    restore that motivated this module, and it catches it instantly.
    """
    if not os.path.exists(path):
        return "missing"
    size = os.path.getsize(path)
    if size != EXPECTED_BYTES:
        return f"{size} bytes on disk, expected {EXPECTED_BYTES}"
    if check_hash:
        actual = sha256_of(path)
        if actual != EXPECTED_SHA256:
            return f"sha256 starts {actual[:12]}, expected {EXPECTED_SHA256[:12]}"
    return ""


def load_failure_hint(path: str) -> str:
    """A sentence naming the real problem, for a weights load that just failed.

    Returns "" when there is nothing useful to add — a custom checkpoint, or a
    canonical file that is byte-correct and failed for some other reason. In
    that case the underlying exception is the whole story and inventing a hint
    would point the reader away from it.
    """
    if not is_canonical(path):
        return ""
    problem = describe_problem(path, check_hash=False)
    if not problem:
        return ""
    if problem == "missing":
        return f"the weights file was never restored: {RESTORE_COMMAND}"
    return (
        f"this is not a model file, it is an incomplete restore ({problem}): "
        f"{RESTORE_COMMAND}"
    )
