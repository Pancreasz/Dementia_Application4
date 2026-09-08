"""What the backend says when the clock weights file is not a weights file.

The failure this pins came from a real clone on 2026-09-09: `/health` reported

    clock model load failed: RuntimeError('PytorchStreamReader failed reading
    zip archive: failed finding central directory. This is an internal miniz
    error ... your checkpoint file is corrupted.')

The checkpoint was not corrupted. `moca_densenet.pth` is gitignored and gets
written by `scripts/restore_weights.py`, which streamed git's output straight
into the destination — so an interrupted run left a *partial* file under the
real name, and torch reported that as a broken model. Every test here is about
naming the partial restore instead.
"""

from __future__ import annotations

import os

import pytest

import weights_manifest as wm
from clock import ClockModel, LoadState

_REAL_WEIGHTS = wm.WEIGHTS_PATH


def _fake_weights(tmp_path, monkeypatch, contents: bytes) -> str:
    """A file at a path the manifest has been told is the canonical one."""
    path = tmp_path / "moca_densenet.pth"
    path.write_bytes(contents)
    monkeypatch.setattr(wm, "WEIGHTS_PATH", str(path))
    return str(path)


def test_missing_file_is_named_missing(tmp_path, monkeypatch):
    path = str(tmp_path / "moca_densenet.pth")
    monkeypatch.setattr(wm, "WEIGHTS_PATH", path)
    assert wm.describe_problem(path) == "missing"


def test_partial_file_reports_both_sizes(tmp_path, monkeypatch):
    path = _fake_weights(tmp_path, monkeypatch, b"x" * 100000)
    problem = wm.describe_problem(path)
    # Both numbers matter: one shows the file is short, the other shows by how
    # much, which is what tells a reader it was interrupted rather than swapped.
    assert "100000" in problem
    assert str(wm.EXPECTED_BYTES) in problem


def test_right_size_wrong_bytes_is_caught_by_the_hash(tmp_path, monkeypatch):
    # A size check alone would pass this. PowerShell's `>` re-encoding a binary
    # stream is the way to get a plausible-looking file that is not the model.
    path = _fake_weights(tmp_path, monkeypatch, b"x" * wm.EXPECTED_BYTES)
    assert "sha256" in wm.describe_problem(path)
    assert wm.describe_problem(path, check_hash=False) == ""


def test_a_custom_checkpoint_gets_no_hint(tmp_path, monkeypatch):
    # MOCA_CLOCK_WEIGHTS pointing elsewhere is somebody's own model. Telling
    # them to re-run restore_weights.py would send them to the wrong place.
    _fake_weights(tmp_path, monkeypatch, b"x" * 10)
    other = tmp_path / "someone-elses.pth"
    other.write_bytes(b"x" * 10)
    assert wm.load_failure_hint(str(other)) == ""


def test_hint_for_a_missing_file_names_the_restore_script(tmp_path, monkeypatch):
    path = str(tmp_path / "moca_densenet.pth")
    monkeypatch.setattr(wm, "WEIGHTS_PATH", path)
    assert "restore_weights.py" in wm.load_failure_hint(path)


def test_hint_for_a_partial_file_says_it_is_not_a_model(tmp_path, monkeypatch):
    path = _fake_weights(tmp_path, monkeypatch, b"x" * 100000)
    hint = wm.load_failure_hint(path)
    assert "incomplete restore" in hint
    assert "restore_weights.py" in hint


@pytest.mark.skipif(
    not os.path.exists(_REAL_WEIGHTS),
    reason="weights not restored (scripts/restore_weights.py)",
)
def test_the_real_file_has_no_problem_and_no_hint():
    # Also the guard on the constants themselves: if the recovered blob ever
    # changes, this fails here rather than telling every future clone that its
    # correct file is broken.
    assert wm.describe_problem(_REAL_WEIGHTS) == ""
    assert wm.load_failure_hint(_REAL_WEIGHTS) == ""


def test_clock_health_detail_explains_a_partial_restore(tmp_path, monkeypatch):
    # End to end: this is the string that reaches /health, and the whole point
    # of the change. torch's miniz wording must not be the headline.
    path = _fake_weights(tmp_path, monkeypatch, b"x" * 100000)
    model = ClockModel(path)
    model.load()

    assert model.state == LoadState.ERROR
    assert "incomplete restore" in model.detail
    assert "restore_weights.py" in model.detail
    assert "miniz" not in model.detail


def test_clock_health_detail_keeps_the_raw_error_when_nothing_else_fits(tmp_path):
    # A file that is not the canonical one still has to report *something*
    # usable — the underlying exception, unedited.
    path = tmp_path / "custom.pth"
    path.write_bytes(b"not a torch archive")
    model = ClockModel(str(path))
    model.load()

    assert model.state == LoadState.ERROR
    assert "clock model load failed:" in model.detail
