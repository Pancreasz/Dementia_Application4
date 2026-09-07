"""Multilingual sentence embeddings for POST /similarity.

Backs abstraction scoring (MoCA subtests 11-12). The app is Thai/English, so an
English-only model is not usable here; this loads a multilingual
sentence-transformer and reports cosine similarity between a patient's answer
and each accepted category term.

Like asr.py, the model loads on a *background thread* so /health answers
immediately, and it is never constructed at import time — tests import this
module and must not trigger a model download.

WHAT THIS MODULE DELIBERATELY DOES NOT DO
-----------------------------------------
It does not decide pass/fail. It returns every similarity it computed and lets
the caller apply a threshold. The threshold is an invented, unvalidated number
(see lib/scoring/abstraction.dart), and keeping it out of here means:

  - the three unvalidated numbers in this app all live in lib/scoring/ together,
    rather than one hiding in the backend;
  - the raw similarities can be stored per session, so the threshold can be
    re-chosen later against real answers without re-running any patient.
"""

from __future__ import annotations

import math
import os
import threading
from typing import Dict, List, Sequence

from asr import LoadState, describe_load_failure

# paraphrase-multilingual-MiniLM-L12-v2 rather than LaBSE.
#
# Both are in the multilingual sentence-transformer family the plan names, and
# both cover Thai. MiniLM is ~470 MB against LaBSE's ~1.8 GB, and this process
# already pays a 30-100 s cold start for DenseNet + Whisper on CPU. The
# abstraction task is short-phrase category matching ("ยานพาหนะ" vs an answer
# of a few words), which is well inside what the smaller model handles.
#
# Overridable without a code change, because this choice deserves checking
# against real Thai answers rather than a guess:
DEFAULT_MODEL_NAME = os.environ.get(
    "MOCA_EMBEDDING_MODEL", "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
)

# Where sentence-transformers caches weights. Pinned under backend/models/ so it
# sits beside the CT2 whisper build instead of in the user profile, and an
# offline machine can have the directory pre-populated.
DEFAULT_CACHE_DIR = os.path.join(os.path.dirname(__file__), "models", "embeddings")


def cosine(a: Sequence[float], b: Sequence[float]) -> float:
    """Cosine similarity, clamped to [-1, 1].

    Written out rather than pulled from numpy/sklearn so this module can be unit
    tested with plain lists and no model.

    The clamp guarantees the RANGE, not exactness. Summing products of floats
    and dividing by two square roots lands either side of 1.0 for identical
    vectors — measured 0.9999999999999998 for [0.3, 0.4, 0.5] — so callers get
    a value in [-1, 1] but must not compare it to 1.0 for equality.
    """
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(y * y for y in b))
    # A zero vector has no direction, so it has no similarity to anything. 0.0
    # rather than raising: an empty answer is a real thing a patient does, and
    # it should score 0, not 500 the request.
    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0
    return max(-1.0, min(1.0, dot / (norm_a * norm_b)))


class SimilarityModel:
    """Loads a multilingual sentence-transformer and compares short phrases."""

    def __init__(
        self,
        model_name: str = DEFAULT_MODEL_NAME,
        cache_dir: str = DEFAULT_CACHE_DIR,
        device: str = "cpu",
    ):
        self._model_name = model_name
        self._cache_dir = cache_dir
        self._device = device
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

    @property
    def model_name(self) -> str:
        return self._model_name

    def start_loading(self) -> threading.Thread:
        """Kick off the load on a daemon thread and return it immediately."""
        thread = threading.Thread(target=self._load, name="embedding-load", daemon=True)
        thread.start()
        return thread

    def _load(self) -> None:
        try:
            # Lazily imported for the same reason asr.py imports faster_whisper
            # lazily: importing this module in tests must not pull in torch or
            # reach the network.
            from sentence_transformers import SentenceTransformer

            os.makedirs(self._cache_dir, exist_ok=True)
            model = SentenceTransformer(
                self._model_name,
                cache_folder=self._cache_dir,
                device=self._device,
            )
            with self._lock:
                self._model = model
                self._state = LoadState.READY
                self._detail = "ready"
        except BaseException as exc:  # noqa: BLE001 - report every failure via /health
            with self._lock:
                self._state = LoadState.ERROR
                # Shared with asr.py: the conda SSL_CERT_FILE failure mode costs
                # the same hour to rediscover whichever model download hits it.
                self._detail = describe_load_failure(exc)

    def encode(self, texts: Sequence[str]) -> List[List[float]]:
        """Embed a batch of strings. Caller guarantees the model is READY."""
        if self._model is None:
            raise RuntimeError("encode called before model was ready")
        vectors = self._model.encode(list(texts))
        return [[float(x) for x in vector] for vector in vectors]

    def similarities(self, answer: str, terms: Sequence[str]) -> Dict[str, float]:
        """Cosine similarity between `answer` and each accepted category term.

        Returns EVERY term's score, not just the best one. The maximum is what a
        threshold gets applied to, but the full set is what makes a surprising
        score auditable afterwards — "correct category, low similarity" is a
        scoring artefact and cannot be told apart from a genuine miss without
        seeing the other terms.

        Terms are embedded on every call rather than cached. They are two short
        lists that change only when the source is edited, and caching them would
        add an invalidation bug for a few milliseconds of CPU.
        """
        if not terms:
            return {}
        # One encode() call for the answer and all terms together: the model
        # batches, and this is meaningfully faster than a call per term.
        vectors = self.encode([answer, *terms])
        answer_vector = vectors[0]
        return {
            term: cosine(answer_vector, vector)
            for term, vector in zip(terms, vectors[1:])
        }
