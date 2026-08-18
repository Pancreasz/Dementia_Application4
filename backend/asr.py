"""Thai speech transcription for POST /transcribe.

A CTranslate2 int8 build of `biodatlab/whisper-th-medium-combined`, run through
faster-whisper on CPU. The model is loaded on a *background thread* so /health
answers immediately instead of hanging ~10 s on the first request.

This module owns model loading and transcription only. It never constructs the
model at import time — tests import it and must not trigger an 800 MB load.
"""

from __future__ import annotations

import os
import threading
from dataclasses import dataclass, field
from enum import Enum
from typing import List, Optional

# Default location of the CT2 int8 model produced by scripts/convert_model.py.
DEFAULT_MODEL_DIR = os.path.join(os.path.dirname(__file__), "models", "whisper-th-ct2")


class LoadState(str, Enum):
    LOADING = "loading"
    READY = "ready"
    ERROR = "error"


@dataclass
class Segment:
    start: float
    end: float
    text: str

    def to_dict(self) -> dict:
        return {"start": self.start, "end": self.end, "text": self.text}


@dataclass
class Transcription:
    text: str
    segments: List[Segment] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {"text": self.text, "segments": [s.to_dict() for s in self.segments]}


def describe_load_failure(exc: BaseException) -> str:
    """Turn a model-load exception into a diagnosable /health detail.

    The costly-to-rediscover case (inherited from the reference sidecar): conda's
    openssl activation can point SSL_CERT_FILE at a path missing the `Library/`
    segment Windows needs, breaking all Python HTTPS. The symptom is a bare
    FileNotFoundError with no useful filename during a model download. Name that
    cause explicitly rather than surfacing the raw error.
    """
    cert_file = os.environ.get("SSL_CERT_FILE")
    if isinstance(exc, FileNotFoundError) and cert_file and not os.path.exists(cert_file):
        return (
            f"model load failed and SSL_CERT_FILE points at a missing file "
            f"({cert_file}). This is usually conda's openssl activation dropping "
            f"the 'Library/' path segment and breaking Python HTTPS. Unset "
            f"SSL_CERT_FILE or point it at a real CA bundle, then retry. "
            f"Original error: {exc!r}"
        )
    return f"model load failed: {exc!r}"


class AsrModel:
    """Loads the Whisper CT2 model in the background and transcribes WAV bytes."""

    def __init__(
        self,
        model_dir: str = DEFAULT_MODEL_DIR,
        device: str = "cpu",
        compute_type: str = "int8",
    ):
        self._model_dir = model_dir
        self._device = device
        self._compute_type = compute_type
        self._model = None
        self._state = LoadState.LOADING
        self._detail = "model not loaded"
        self._lock = threading.Lock()

    @property
    def state(self) -> LoadState:
        return self._state

    @property
    def detail(self) -> str:
        return self._detail

    @property
    def is_ready(self) -> bool:
        return self._state == LoadState.READY

    def start_loading(self) -> threading.Thread:
        """Kick off the load on a daemon thread and return it immediately."""
        thread = threading.Thread(target=self._load, name="asr-load", daemon=True)
        thread.start()
        return thread

    def _load(self) -> None:
        try:
            # Imported lazily so importing this module (in tests) never pulls in
            # ctranslate2 or triggers a download.
            from faster_whisper import WhisperModel

            model = WhisperModel(
                self._model_dir, device=self._device, compute_type=self._compute_type
            )
            with self._lock:
                self._model = model
                self._state = LoadState.READY
                self._detail = "ready"
        except BaseException as exc:  # noqa: BLE001 - report every failure via /health
            with self._lock:
                self._state = LoadState.ERROR
                self._detail = describe_load_failure(exc)

    def transcribe(self, audio, language: str = "th") -> Transcription:
        """Transcribe audio. Caller guarantees the model is READY.

        `audio` is anything faster-whisper accepts: a path, or a binary
        file-like object (faster-whisper decodes it with PyAV, so the uploaded
        WAV bytes can be passed as BytesIO without a temp file).

        Keeps faster-whisper's own segments — Verbal Fluency counts distinct
        segments, so they are not joined or discarded.
        """
        if self._model is None:
            raise RuntimeError("transcribe called before model was ready")

        segments_iter, _info = self._model.transcribe(audio, language=language)

        segments: List[Segment] = []
        parts: List[str] = []
        for seg in segments_iter:
            text = seg.text
            segments.append(
                Segment(start=float(seg.start), end=float(seg.end), text=text)
            )
            parts.append(text)

        return Transcription(text="".join(parts).strip(), segments=segments)
