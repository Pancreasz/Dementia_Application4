"""Clock-drawing scorer for POST /upload.

A torchvision DenseNet-121 whose classifier is replaced by ``Linear(1024, 4)``.
The four output classes are the MoCA clock scores 0, 1, 2, 3, and the class
index equals the score (the training script encoded labels with a LabelEncoder
over the directory names "0","1","2","3", which sort into that order).

This module owns *all* inference and preprocessing. ``app.py`` only turns its
result into an HTTP response. The model is never constructed at import time:
importing this module for tests must not touch the weights file.
"""

from __future__ import annotations

import io
import threading
from enum import Enum
from typing import Optional

import torch
import torch.nn as nn
from PIL import Image
from torchvision import models, transforms

NUM_CLASSES = 4  # clock scores 0..3


class LoadState(str, Enum):
    LOADING = "loading"
    READY = "ready"
    ERROR = "error"
_IMG_SIZE = 224  # DenseNet convention; corroborated by the lost Keras script.

# ---------------------------------------------------------------------------
# ASSUMED, NOT VERIFIED — the single source of truth for clock preprocessing.
#
# The original PyTorch training script is permanently lost, so the transform
# below is an assumption, validated only against the four labelled images
# clock_0..3.png (see scripts/validate_clock.py). If it is wrong the model
# returns a *confident* wrong score rather than an error — the exact failure
# this project exists to avoid — so treat any change here as clinical.
#
# This is transform #1 from the handout: torchvision default (ImageNet
# normalization), the most likely choice for a PyTorch fine-tune. If the four
# images ever stop scoring 4/4, the alternatives, in order, are:
#   #2  ToTensor() only (values in [0,1], no Normalize)
#   #3  ToTensor() then *255 (raw 0..255, what the Keras script fed)
# ---------------------------------------------------------------------------
PREPROCESS = transforms.Compose(
    [
        transforms.Resize((_IMG_SIZE, _IMG_SIZE)),
        transforms.ToTensor(),  # -> [0,1], channels-first, 3-channel
        transforms.Normalize(
            mean=[0.485, 0.456, 0.406],
            std=[0.229, 0.224, 0.225],
        ),
    ]
)


def build_model() -> nn.Module:
    """DenseNet-121 with the classifier swapped for a single Linear(1024, 4).

    Matches the recovered state_dict exactly: `features.*` stem + a single
    `classifier` of shape (4, 1024). No hidden Dense(1024) layer exists in the
    weights, so none is added here.
    """
    model = models.densenet121(weights=None)
    model.classifier = nn.Linear(model.classifier.in_features, NUM_CLASSES)
    return model


class ClockModel:
    """Loads the DenseNet weights once and scores PNG bytes.

    Thread-safe lazy load: `load()` may be called from a background thread at
    startup while `/health` answers on the main thread.
    """

    def __init__(self, weights_path: str):
        self._weights_path = weights_path
        self._model: Optional[nn.Module] = None
        self._state = LoadState.LOADING
        self._detail = "model not loaded"
        self._lock = threading.Lock()

    @property
    def is_ready(self) -> bool:
        return self._state == LoadState.READY

    @property
    def state(self) -> LoadState:
        return self._state

    @property
    def detail(self) -> str:
        return self._detail

    def start_loading(self) -> threading.Thread:
        """Kick off the load on a daemon thread and return it immediately."""
        thread = threading.Thread(target=self.load, name="clock-load", daemon=True)
        thread.start()
        return thread

    def load(self) -> None:
        try:
            with self._lock:
                if self._model is not None:
                    return
                model = build_model()
                state_dict = torch.load(self._weights_path, map_location="cpu")
                model.load_state_dict(state_dict)
                model.eval()
                self._model = model
                self._state = LoadState.READY
                self._detail = "ready"
        except BaseException as exc:  # noqa: BLE001 - report via /health, not a crash
            with self._lock:
                self._state = LoadState.ERROR
                self._detail = f"clock model load failed: {exc!r}"

    def predict(self, image_bytes: bytes) -> int:
        """Return a clock score in 0..3 for a PNG/JPEG byte string.

        Raises ValueError if the bytes are not a decodable image, so the caller
        can answer 4xx instead of 500.
        """
        if self._model is None:
            self.load()
        if self._model is None:
            # Load was attempted and failed; surface the diagnosable detail.
            raise RuntimeError(self._detail)

        try:
            image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        except Exception as exc:  # not an image, empty body, truncated upload
            raise ValueError(f"not a decodable image: {exc}") from exc

        tensor = PREPROCESS(image).unsqueeze(0)  # (1, 3, 224, 224)
        with torch.no_grad():
            logits = self._model(tensor)
            index = int(torch.argmax(logits, dim=1).item())

        # argmax over 4 classes is already in range; clamp defensively so a
        # future model change can never hand the app an out-of-contract score.
        return max(0, min(NUM_CLASSES - 1, index))
