"""Restore the clock model weights from git history.

`moca_densenet.pth` (28 MB) is gitignored and not committed, so a fresh clone
does not have it on disk. It survives as a git blob from before commit
`ee15387` ("model delete"). This restores it to backend/moca_densenet.pth.

Run:  python scripts/restore_weights.py     (from the backend/ directory)

WHY THIS WRITES A .part FILE FIRST
----------------------------------
The first version streamed `git cat-file` straight into the destination, so it
opened (and therefore truncated) the real file before knowing whether git would
produce anything. Any interruption — a shallow clone where the blob is missing,
a killed process, a full disk — left a partial file sitting at the destination
under the right name. `torch.load` then failed on it with

    PytorchStreamReader failed reading zip archive: failed finding central
    directory. This is an internal miniz error.

which says nothing about the actual problem and sounds like a corrupt *model*
rather than a half-written download. That reached a person cloning the repo on
2026-09-09. Staging in `.part` and only renaming after the bytes verify means a
failed restore leaves the destination exactly as it was — absent, so the loader
can say "not restored" instead of guessing at a corrupt archive.

The same trap catches anyone who runs the git command by hand: in PowerShell,
`git cat-file blob ... > moca_densenet.pth` re-encodes the binary stream as text
and produces a file of the wrong size. Hence the hash check, not just a size
check — a size that happens to match is not proof the bytes are right.
"""

from __future__ import annotations

import os
import subprocess
import sys

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BACKEND_DIR)
from weights_manifest import (  # noqa: E402
    EXPECTED_BYTES,
    WEIGHTS_PATH,
    describe_problem,
)

DEST = WEIGHTS_PATH
PART = DEST + ".part"
BLOB = "68dd66d:backend/moca_densenet.pth"


def main():
    problem = describe_problem(DEST)
    if not problem:
        print(f"already present and verified: {DEST} ({EXPECTED_BYTES} bytes)")
        return
    if problem != "missing":
        # Say this out loud. A wrong file already on disk is the case that
        # produces the confusing miniz error, and the person running this needs
        # to know it was replaced rather than merely topped up.
        print(f"existing file is unusable ({problem}) - replacing it")

    print(f"restoring {DEST} from git blob {BLOB} ...")
    try:
        with open(PART, "wb") as out:
            subprocess.run(
                ["git", "cat-file", "blob", BLOB],
                cwd=BACKEND_DIR,
                stdout=out,
                check=True,
            )
    except (subprocess.CalledProcessError, OSError) as exc:
        _discard_part()
        sys.exit(
            f"git could not read the blob ({exc}).\n"
            "If this is a shallow clone, the old commit holding the weights was "
            "never fetched: run `git fetch --unshallow` and try again."
        )

    problem = describe_problem(PART)
    if problem:
        _discard_part()
        sys.exit(
            f"restored bytes are wrong ({problem}) - nothing was written to "
            f"{DEST}. Re-run this script; if it keeps happening, check for a "
            "full disk or an interrupted git process."
        )

    os.replace(PART, DEST)  # atomic: the destination is never partially written
    print(f"done: {DEST} ({EXPECTED_BYTES} bytes, sha256 verified)")


def _discard_part():
    try:
        os.remove(PART)
    except OSError:
        pass


if __name__ == "__main__":
    main()
