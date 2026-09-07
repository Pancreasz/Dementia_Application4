"""Speech transcription for POST /transcribe, one model per language.

Thai runs on a CTranslate2 build of `scb10x/typhoon-whisper-large-v3`; English
runs on `Systran/faster-distil-whisper-large-v3`. Both go through
faster-whisper on CPU, and both load on *background threads* so /health answers
immediately instead of hanging on the first request.

Two models rather than one because a Thai fine-tune is not an English
recognizer — see DEFAULT_MODEL_DIR_EN for what that produced when English
requests were served by the Thai model.

This module owns model loading and transcription only. It never constructs a
model at import time — tests import it and must not trigger a multi-GB load.
"""

from __future__ import annotations

import os
import threading
from dataclasses import dataclass, field
from enum import Enum
from typing import List, Optional

# Default location of the CT2 model produced by scripts/convert_model.py.
#
# `scb10x/typhoon-whisper-large-v3` (Thai fine-tune of whisper-large-v3, 32
# encoder + 32 decoder layers, 128 mel bins) replaced
# `biodatlab/whisper-th-medium-combined` on 2026-09-07. It is roughly 3x the
# parameters, so it is slower and needs more RAM — roughly 1.7x per clip, timed
# side by side in backend/README.md. The previous medium build is NOT deleted;
# point MOCA_ASR_MODEL_DIR back at models/whisper-th-ct2 to revert without a
# rebuild.
#
# Both the directory and the compute type are environment-overridable because
# the right trade-off depends on the machine the backend runs on, and that is
# not knowable from here:
#   MOCA_ASR_MODEL_DIR, MOCA_ASR_COMPUTE_TYPE
#
# The checked-in conversion writes float16. Asking CTranslate2 for `int8` at
# load time makes it requantize in memory on the way in — that is supported and
# is what halves the resident footprint, but it is NOT free at load, and it is
# why the load is slower than the file size alone suggests.
#
# STILL THAI-ONLY. This does not fix the English voice subtests documented in
# handout.md ("English mode is demo-quality"): typhoon is fine-tuned on ~11,000
# hours of Thai and is pulled away from the base checkpoint's multilingual
# behaviour in the same way the biodatlab medium model was. English sessions
# need a separate general-multilingual model, which this change does not add.
#
# KNOWN REGRESSION ON SHORT CLIPS. On the generated stimulus audio typhoon drops
# the leading digit of the 3-second `digits-backward.wav` (`สี่สอง` for 742) and
# returns an empty transcript for the ~1-second single-digit clips. Reproduced
# under four decoding configurations including faster-whisper's own defaults, so
# it is the model rather than the options below. Those clips are TTS stimulus and
# are never transcribed in a real session, but a patient's digit-span answer is
# the same *length*, and `scoreDigitSpan` compares for exact equality. See
# design_docs/CONTENT-STATUS.md item j.
DEFAULT_MODEL_DIR = os.environ.get(
    "MOCA_ASR_MODEL_DIR",
    os.path.join(os.path.dirname(__file__), "models", "typhoon-large-v3-ct2"),
)
DEFAULT_COMPUTE_TYPE = os.environ.get("MOCA_ASR_COMPUTE_TYPE", "int8")

# The ENGLISH model, added 2026-09-08. `Systran/faster-distil-whisper-large-v3`
# — an English-only distillation of whisper-large-v3 with two decoder layers
# instead of thirty-two.
#
# WHY A SECOND MODEL RATHER THAN ONE MULTILINGUAL ONE
# --------------------------------------------------
# Both Thai models this backend has used — biodatlab's medium and typhoon — are
# Thai fine-tunes, and fine-tuning pulled them away from whatever multilingual
# behaviour the base checkpoint had. handout.md records what that produced in
# English: fluency answers transcribed into Thai script, abstraction
# hallucinating "Thank you for watching, please leave a like", "Hospital"
# looping six times. Passing language='en' to a Thai fine-tune does not make it
# an English recognizer, and English mode has been demo-quality since.
#
# So `language` now selects the model, not just a decoding hint. The Thai model
# keeps Thai, where it is genuinely better than a general checkpoint.
#
# THIS MODEL CANNOT DO THAI. distil-whisper is English-only — its own model card
# says `language: en`. It is deliberately never asked to: [pick_model] routes by
# language and nothing falls back across the split. A fallback is exactly how
# the current bug reads to a clinician, which is to say invisibly.
DEFAULT_MODEL_DIR_EN = os.environ.get(
    "MOCA_ASR_MODEL_DIR_EN",
    # Where the checkpoint was downloaded: the repo root, one level above
    # backend/. A container needs it inside the build context instead — see
    # the Dockerfile.
    os.path.join(os.path.dirname(os.path.dirname(__file__)), "systran-whisper"),
)

# Decoding options, measured against the four stimulus clips on 2026-08-18 after
# a real session produced both a 0/1 digit span the patient answered correctly
# and multi-minute waits.
#
# CARRIED OVER TO A DIFFERENT MODEL, 2026-09-07. Everything below was measured
# against `biodatlab/whisper-th-medium-combined`. The switch to typhoon
# large-v3 was re-checked against the same clips and neither pathology returned
# — digit span transcribes once, not four times, and no clip hit the ladder —
# so the settings are kept unchanged. The *reasoning* still refers to
# measurements taken on the old model; treat the numbers as history and the
# behaviour as re-verified.
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


# Serializes the ASR model loads. Shared by every AsrModel by default, which is
# the point: it is not protecting shared state, it is protecting RAM.
#
# Measured on 2026-09-08, the first time two of these were configured at once:
# both started loading in parallel and the Thai one died with
# `RuntimeError('mkl_malloc: failed to allocate memory')`, leaving /health
# reporting asr=error, asr_en=ready — a backend that had silently lost Thai.
#
# The peak is the conversion, not the resident model. Typhoon ships float16 and
# `compute_type="int8"` requantizes it in memory on the way in, so for a moment
# both the 3.1 GB float16 copy and the 1.5 GB int8 copy are live; the English
# model is doing the same thing beside it. Loading them one at a time makes the
# peak the largest single model instead of the sum, at the cost of a slower
# start — and /health already reports `loading` honestly until it finishes.
#
# Converting typhoon straight to int8 on disk removes the requantization peak
# as well; see MOCA_CONVERT_QUANTIZATION in scripts/convert_model.py.
_LOAD_LOCK = threading.Lock()


def is_english(language: str) -> bool:
    """Whether [language] should be served by the English model.

    Prefix-matched so 'en', 'en-US' and 'eng' all route the same way. Anything
    else — including an empty or unknown code — routes to Thai, which is what
    the app sends by default and what every stimulus in the repo is recorded in.
    """
    return (language or "").strip().lower().startswith("en")


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
        compute_type: str = DEFAULT_COMPUTE_TYPE,
        temperature: float = DEFAULT_TEMPERATURE,
        repetition_penalty: float = DEFAULT_REPETITION_PENALTY,
        label: str = "asr",
        load_lock: Optional[threading.Lock] = None,
    ):
        # Names this instance in /health and in load-failure details. With two
        # models running, "model load failed" without a label sends whoever
        # reads it to the wrong directory.
        self.label = label
        self._load_lock = load_lock or _LOAD_LOCK
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
        thread = threading.Thread(
            target=self._load, name=f"{self.label}-load", daemon=True
        )
        thread.start()
        return thread

    def _load(self) -> None:
        try:
            # Imported lazily so importing this module (in tests) never pulls in
            # ctranslate2 or triggers a download.
            from faster_whisper import WhisperModel

            # Named before the generic loader error, which reports a missing
            # directory as an unhelpful RuntimeError about a missing model.bin.
            # With two models configured, "which directory?" is the first
            # question anyone reading /health will have.
            if not os.path.isdir(self._model_dir):
                raise FileNotFoundError(
                    f"no model directory at {self._model_dir}"
                )

            # One model converts at a time. See _LOAD_LOCK — this is about RAM,
            # not about shared state.
            with self._load_lock:
                model = WhisperModel(
                    self._model_dir,
                    device=self._device,
                    compute_type=self._compute_type,
                )
            with self._lock:
                self._model = model
                self._state = LoadState.READY
                self._detail = "ready"
        except BaseException as exc:  # noqa: BLE001 - report every failure via /health
            with self._lock:
                self._state = LoadState.ERROR
                self._detail = f"{self.label}: {describe_load_failure(exc)}"

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
