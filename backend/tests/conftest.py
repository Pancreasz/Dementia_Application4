"""Shared fakes so tests never load real weights or download a model.

The handout's rule: monkeypatch the model loaders. These fakes stand in for
ClockModel and AsrModel and are swapped onto the app's module globals by the
fixtures in test_app.py.
"""

from __future__ import annotations

import sys
from pathlib import Path

# Make the backend modules importable when pytest runs from the repo root.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from asr import LoadState, Transcription  # noqa: E402


class FakeClock:
    def __init__(self, *, score=2, raises=None, state=LoadState.READY, detail="ready"):
        self._score = score
        self._raises = raises
        self.state = state
        self.detail = detail

    @property
    def is_ready(self):
        return self.state == LoadState.READY

    def start_loading(self):
        return None

    def predict(self, image_bytes):
        if self._raises is not None:
            raise self._raises
        return self._score


class FakeAsr:
    def __init__(self, *, result=None, raises=None, state=LoadState.READY, detail="ready"):
        self._result = result or Transcription(text="", segments=[])
        self._raises = raises
        self.state = state
        self.detail = detail

    @property
    def is_ready(self):
        return self.state == LoadState.READY

    def start_loading(self):
        return None

    def transcribe(self, audio, language="th"):
        if self._raises is not None:
            raise self._raises
        return self._result
