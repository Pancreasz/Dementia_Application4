"""Restore the clock model weights from git history.

`moca_densenet.pth` (28 MB) is gitignored and not committed, so a fresh clone
does not have it on disk. It survives as a git blob from before commit
`ee15387` ("model delete"). This restores it to backend/moca_densenet.pth.

Run:  python scripts/restore_weights.py     (from the backend/ directory)
"""

from __future__ import annotations

import os
import subprocess
import sys

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(BACKEND_DIR, "moca_densenet.pth")
BLOB = "68dd66d:backend/moca_densenet.pth"
EXPECTED_BYTES = 28440806


def main():
    if os.path.exists(DEST) and os.path.getsize(DEST) == EXPECTED_BYTES:
        print(f"already present: {DEST} ({EXPECTED_BYTES} bytes)")
        return

    print(f"restoring {DEST} from git blob {BLOB} ...")
    with open(DEST, "wb") as out:
        subprocess.run(
            ["git", "cat-file", "blob", BLOB],
            cwd=BACKEND_DIR,
            stdout=out,
            check=True,
        )

    size = os.path.getsize(DEST)
    if size != EXPECTED_BYTES:
        sys.exit(f"restored file is {size} bytes, expected {EXPECTED_BYTES}")
    print(f"done: {DEST} ({size} bytes)")


if __name__ == "__main__":
    main()
