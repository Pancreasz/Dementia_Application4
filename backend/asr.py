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

# Decoding options, measured against the four stimulus clips on 2026-08-18 after
# a real session produced both a 0/1 digit span the patient answered correctly
# and multi-minute waits.
#
# temperature=0
#   faster-whisper defaults to a fallback LADDER (0.0, 0.2, 0.4, 0.6, 0.8, 1.0):
#   a decode that trips the compression-ratio or logprob threshold is re-run at
#   each step, so a clip the model hallucinates on costs up to SIX full decodes.
#   Isolated spoken digits separated by pauses hallucinate reliably, so digit
#   span paid the full penalty every time: `digits-forward.wav` took **144-174 s
#   for 7.8 seconds of audio**. Pinning the temperature removed the ladder and
#   took the same clip to ~15 s. This is the entire cause of "digit span takes
#   very long".
#
# repetition_penalty=1.10
#   With the ladder gone the model still looped, emitting "21854" four times for
#   a clip containing it once (confirmed against the waveform: five speech
#   bursts, not twenty). `scoreDigitSpan` compares for exact equality, so a
#   looped transcript scores a correct patient 0. The penalty removed the loop
#   outright: `digits-forward.wav` now transcribes as exactly "21854" in ~10 s.
#
# Both are overridable without a code change, because the residual risk below
# needs real-patient audio to settle rather than a guess:
#   MOCA_ASR_TEMPERATURE, MOCA_ASR_REPETITION_PENALTY
#
# RESIDUAL RISK — verbal fluency. A repetition penalty discourages repeated
# tokens, and a Thai letter-fluency answer legitimately repeats a prefix
# ("กระหนก กระจู กระเจี้ยว กระจอก"). Verbal fluency is also the one subtest whose
# transcription was already good, so this setting can only hurt it. 1.10 rather
# than 1.15 (identical on every clip tested) to keep the nudge as small as
# works. Needs checking against a real 60-second fluency recording.
DEFAULT_TEMPERATURE = float(os.environ.get("MOCA_ASR_TEMPERATURE", "0"))
DEFAULT_REPETITION_PENALTY = float(
    os.environ.get("MOCA_ASR_REPETITION_PENALTY", "1.10")
)


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
        temperature: float = DEFAULT_TEMPERATURE,
        repetition_penalty: float = DEFAULT_REPETITION_PENALTY,
    ):
        self._model_dir = model_dir
        self._device = device
        self._compute_type = compute_type
        self._temperature = temperature
        self._repetition_penalty = repetition_penalty
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

        Keeps faster-whisper's own segments. They are phrases rather than
        words — the Flutter scorer splits them further — so they are not joined
        or discarded here.

        See DEFAULT_TEMPERATURE / DEFAULT_REPETITION_PENALTY above for why the
        decoding options are not left at faster-whisper's defaults.
        """
        if self._model is None:
            raise RuntimeError("transcribe called before model was ready")

        segments_iter, _info = self._model.transcribe(
            audio,
            language=language,
            temperature=self._temperature,
            repetition_penalty=self._repetition_penalty,
        )

        segments: List[Segment] = []
        parts: List[str] = []
        for seg in segments_iter:
            text = seg.text
            segments.append(
                Segment(start=float(seg.start), end=float(seg.end), text=text)
            )
            parts.append(text)

        return Transcription(text="".join(parts).strip(), segments=segments)
