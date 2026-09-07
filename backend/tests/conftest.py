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
    def __init__(
        self,
        *,
        result=None,
        raises=None,
        state=LoadState.READY,
        detail="ready",
        label="asr",
    ):
        self._result = result or Transcription(text="", segments=[])
        self._raises = raises
        self.state = state
        self.detail = detail
        self.label = label
        # Records what the route actually asked for, so a test can prove which
        # of the two models served a request rather than inferring it.
        self.calls = []

    @property
    def is_ready(self):
        return self.state == LoadState.READY

    def start_loading(self):
        return None

    def transcribe(self, audio, language="th"):
        self.calls.append(language)
        if self._raises is not None:
            raise self._raises
        return self._result


class FakeSimilarity:
    """Stands in for SimilarityModel so no test downloads 470 MB of weights."""

    def __init__(
        self,
        *,
        scores=None,
        raises=None,
        state=LoadState.READY,
        detail="ready",
        model_name="fake-embedding-model",
    ):
        self._scores = scores if scores is not None else {}
        self._raises = raises
        self.state = state
        self.detail = detail
        self.model_name = model_name
        self.last_answer = None
        self.last_terms = None

    @property
    def is_ready(self):
        return self.state == LoadState.READY

    def start_loading(self):
        return None

    def similarities(self, answer, terms):
        self.last_answer = answer
        self.last_terms = list(terms)
        if self._raises is not None:
            raise self._raises
        # Default: every requested term scores 0.0 unless the test named it.
        # Explicit rather than omitted, so a route that drops terms is visible.
        return {term: self._scores.get(term, 0.0) for term in terms}
