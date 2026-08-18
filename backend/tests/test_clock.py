"""Unit tests for the clock scorer that don't need the real forward pass."""

from __future__ import annotations

import io
import os

import pytest
import torch
from PIL import Image

import clock
from clock import ClockModel, LoadState, build_model

_WEIGHTS = os.path.join(os.path.dirname(__file__), "..", "moca_densenet.pth")


def _png_bytes(size=(16, 16), color=(255, 255, 255)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", size, color).save(buf, format="PNG")
    return buf.getvalue()


def test_build_model_head_matches_weights_shape():
    model = build_model()
    assert model.classifier.weight.shape == (clock.NUM_CLASSES, 1024)
    assert model.classifier.bias.shape == (clock.NUM_CLASSES,)


def test_predict_returns_int_in_range(monkeypatch):
    m = ClockModel("unused")
    # Inject a stub forward so no weights load is needed. argmax here is 2.
    m._model = lambda t: torch.tensor([[0.1, 0.2, 5.0, 0.3]])
    m._state = LoadState.READY

    out = m.predict(_png_bytes())
    assert isinstance(out, int) and not isinstance(out, bool)
    assert 0 <= out <= 3
    assert out == 2


def test_predict_rejects_non_image():
    m = ClockModel("unused")
    m._model = lambda t: torch.zeros((1, 4))
    m._state = LoadState.READY
    with pytest.raises(ValueError):
        m.predict(b"this is not a png")


@pytest.mark.skipif(
    not os.path.exists(_WEIGHTS),
    reason="weights not restored (scripts/restore_weights.py)",
)
def test_real_weights_load_strict_into_architecture():
    # The load-bearing architecture check: the recovered state_dict must load
    # into densenet121 + Linear(1024,4) with strict=True (no missing/extra keys).
    m = ClockModel(_WEIGHTS)
    m.load()
    assert m.is_ready
    assert m.state == LoadState.READY
