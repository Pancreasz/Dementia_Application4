"""FastAPI app for the MoCA backend.

Routes only — all inference lives in clock.py, asr.py and embeddings.py. Every
model loads on a background thread at startup so GET /health answers
immediately.

Endpoints:
  POST /upload      clock-drawing image  -> {message, filename, predicted_moca_score}
  POST /transcribe  Thai WAV             -> {text, segments} | 503 {detail}
  POST /similarity  answer + terms       -> {similarities, best_term, best_score} | 503
  GET  /health      -> {status, detail, models}
"""

from __future__ import annotations

import io
import os
from contextlib import asynccontextmanager
from typing import List

from fastapi import Body, FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from asr import DEFAULT_MODEL_DIR_EN, AsrModel, LoadState, is_english
from clock import ClockModel
from embeddings import SimilarityModel

_WEIGHTS_PATH = os.path.join(os.path.dirname(__file__), "moca_densenet.pth")

# Constructed here, not loaded here: these constructors only store config. The
# heavy load happens in start_loading() during the lifespan below, so importing
# this module (in tests) never touches weights or downloads a model. Tests
# monkeypatch these module globals with fakes; routes read them via the
# accessors below so a patched global takes effect.
clock_model = ClockModel(_WEIGHTS_PATH)
asr_model = AsrModel(
    label="asr-th",
    download_hint="python scripts/convert_model.py  (from backend/)",
)
asr_model_en = AsrModel(
    model_dir=DEFAULT_MODEL_DIR_EN,
    label="asr-en",
    download_hint=(
        "huggingface-cli download Systran/faster-distil-whisper-large-v3 "
        "--local-dir ../systran-whisper"
    ),
)
similarity_model = SimilarityModel()


def get_clock() -> ClockModel:
    return clock_model


def get_asr() -> AsrModel:
    return asr_model


def get_asr_en() -> AsrModel:
    return asr_model_en


def asr_for(language: str) -> AsrModel:
    """The model that serves [language].

    Deliberately without a fallback. Serving an English request from the Thai
    model is what the app did until 2026-09-08, and handout.md records the
    result: English fluency answers transcribed into Thai script, abstraction
    hallucinating unrelated sentences, "Hospital" looping six times. Every one
    of those was scored as a patient finding. If the English model is not
    loaded, /transcribe answers 503 and the subtest lands on Retry/Skip, which
    is a subtest that was not administered rather than one the patient failed.
    """
    return get_asr_en() if is_english(language) else get_asr()


def get_similarity() -> SimilarityModel:
    return similarity_model


@asynccontextmanager
async def lifespan(app: FastAPI):
    get_clock().start_loading()
    get_asr().start_loading()
    # Fourth model on the cold-start bill, and the reason to watch RAM: two
    # large-v3-class ASR models are resident at once, roughly 1.5 GB each as
    # int8. Loaded eagerly rather than on first English request so /health can
    # report honestly before a session starts — a lazily-loaded model is
    # "ready" right up until the moment a patient needs it. A deployment that
    # only ever administers in Thai can skip it with
    # MOCA_ASR_MODEL_DIR_EN pointed at nothing; English then 503s, which is the
    # correct answer for a language this backend cannot transcribe.
    get_asr_en().start_loading()
    # The smallest of the four (~470 MB), and it loads in parallel with the
    # others, so it extends startup by less than it costs on its own.
    get_similarity().start_loading()
    yield


app = FastAPI(title="MoCA backend", lifespan=lifespan)

# Which browser origins may talk to this service.
#
# The Flutter *web* build fetches from a browser, so both endpoints are
# cross-origin. The desktop build is not affected — it is not subject to the
# same-origin policy — which is why none of this was needed until the app was
# retargeted at the web.
#
# Two origins are in play:
#   - http://localhost:<random>  `flutter run -d chrome` picks a fresh port each
#                                launch, hence a regex rather than a fixed list.
#   - https://pancreasz.github.io  the published GitHub Pages build (docs/).
#
# Deliberately NOT "*", and deliberately not all of *.github.io: both endpoints
# are unauthenticated and accept patient audio and clock drawings, so any page
# the clinician happens to have open must not be able to read a response from
# this service.
#
# When the backend moves to Azure this stops mattering for the hosted case, but
# leave it: the local backend remains how development is done. Override without
# editing code by setting MOCA_ALLOWED_ORIGIN_REGEX.
_DEFAULT_ORIGIN_REGEX = (
    r"^(https://pancreasz\.github\.io|http://(localhost|127\.0\.0\.1)(:\d+)?)$"
)
ALLOWED_ORIGIN_REGEX = os.environ.get(
    "MOCA_ALLOWED_ORIGIN_REGEX", _DEFAULT_ORIGIN_REGEX
)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=ALLOWED_ORIGIN_REGEX,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
    # Chrome's Private Network Access. A page served from a *public* origin
    # (https://pancreasz.github.io) that fetches a *private* one (localhost)
    # sends an extra preflight carrying
    # `Access-Control-Request-Private-Network: true`, and Chrome drops the
    # request unless the reply grants it. Starlette defaults this to False and
    # answers 400 "Disallowed CORS private-network".
    #
    # This is exactly the published-Pages-frontend + local-backend arrangement,
    # so without it every backend-scored subtest fails on the published site
    # while working perfectly under `flutter run -d chrome`.
    #
    # Only ever granted to an origin ALLOWED_ORIGIN_REGEX already accepted —
    # Starlette checks the origin first, so this cannot widen access on its own.
    allow_private_network=True,
)


@app.post("/upload")
async def upload(file: UploadFile = File(...)):
    """Score a clock-drawing PNG.

    Contract pinned by lib/pages/clock.dart. Three fields, and the app crashes
    (inside a try that only catches JSON errors) if the types are wrong:
      - predicted_moca_score MUST be a JSON int in 0..3
      - message and filename MUST be strings
    """
    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="empty upload")

    clock = get_clock()
    try:
        score = clock.predict(image_bytes)  # int 0..3, or raises
    except ValueError:
        # Not a decodable image / empty body -> 4xx, never 500.
        raise HTTPException(status_code=400, detail="uploaded file is not a valid image")
    except RuntimeError:
        # Weights missing or failed to load. Short, non-sensitive body: the app
        # shows non-200 bodies to the user verbatim.
        raise HTTPException(status_code=503, detail="clock model unavailable")

    # int() and str() make the crash-the-app contract explicit at the boundary.
    return {
        "message": "clock scored",
        "filename": str(file.filename or "upload.png"),
        "predicted_moca_score": int(score),
    }


@app.post("/transcribe")
async def transcribe(file: UploadFile = File(...), language: str = Form("th")):
    """Transcribe speech. Returns text + faster-whisper segments.

    `language` SELECTS THE MODEL, it is not just a decoding hint: Thai goes to
    the Thai fine-tune, English to the English one. See `asr_for`.

    While the chosen model is still loading (or failed to load) this returns
    503 with a {detail} body rather than 200 with an empty transcript — an
    empty transcript would be scored as the patient having said nothing.
    """
    asr = asr_for(language)
    if not asr.is_ready:
        detail = (
            f"{asr.label}: model not loaded"
            if asr.state == LoadState.LOADING
            else asr.detail
        )
        raise HTTPException(status_code=503, detail=detail)

    audio_bytes = await file.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="empty upload")

    try:
        result = asr.transcribe(io.BytesIO(audio_bytes), language=language)
    except Exception as exc:  # noqa: BLE001 - decode/transcode failure -> 4xx
        raise HTTPException(status_code=400, detail=f"could not decode audio: {exc}")

    return result.to_dict()


@app.post("/similarity")
async def similarity(
    answer: str = Body(..., embed=True),
    terms: List[str] = Body(..., embed=True),
):
    """Cosine similarity between a patient's answer and each accepted term.

    Backs abstraction scoring. Returns every similarity computed, plus the best
    term and score for convenience — the caller applies the threshold, because
    the threshold is an unvalidated number that belongs beside the app's other
    two in lib/scoring/ rather than buried here.

    503 while the model is loading or failed, matching /transcribe: a 200 with
    all-zero similarities would be scored as the patient having answered wrongly.
    """
    model = get_similarity()
    if not model.is_ready:
        detail = "model not loaded" if model.state == LoadState.LOADING else model.detail
        raise HTTPException(status_code=503, detail=detail)

    # An empty term list would make best_term meaningless and always score 0.
    # That is a caller bug (a subtest id with no registered terms), not a patient
    # finding, so it is a 400 rather than a silent zero.
    if not terms:
        raise HTTPException(status_code=400, detail="no accepted terms supplied")

    try:
        scores = model.similarities(answer, terms)
    except Exception as exc:  # noqa: BLE001 - encode failure -> 400, never 500
        raise HTTPException(status_code=400, detail=f"could not embed answer: {exc}")

    # An empty answer embeds to a zero vector and scores 0.0 against everything;
    # max() over that is still well defined, so no special case is needed here.
    best_term = max(scores, key=lambda term: scores[term])
    return {
        "similarities": scores,
        "best_term": best_term,
        "best_score": scores[best_term],
        # Echoed so a stored session records WHICH model produced the numbers.
        # Changing the model changes every similarity, and without this the old
        # scores would be indistinguishable from the new ones on review.
        "model": model.model_name,
    }


@app.get("/health")
async def health():
    """Aggregate health. status is 'error' if any model failed, 'loading'
    if any is still loading, else 'ready'. Answers immediately during load.
    """
    clock = get_clock()
    asr = get_asr()
    asr_en = get_asr_en()
    embed = get_similarity()
    states = [clock.state, asr.state, asr_en.state, embed.state]
    if LoadState.ERROR in states:
        status = LoadState.ERROR
    elif LoadState.LOADING in states:
        status = LoadState.LOADING
    else:
        status = LoadState.READY

    body = {
        "status": status.value,
        "detail": (
            f"clock: {clock.detail} | asr: {asr.detail} | "
            f"asr_en: {asr_en.detail} | similarity: {embed.detail}"
        ),
        "models": {
            "clock": {"status": clock.state.value, "detail": clock.detail},
            # Kept as "asr" rather than renamed to "asr_th": /health is read by
            # people and by whatever they have scripted against it, and the key
            # that was already there should keep meaning what it meant.
            "asr": {"status": asr.state.value, "detail": asr.detail},
            "asr_en": {"status": asr_en.state.value, "detail": asr_en.detail},
            "similarity": {"status": embed.state.value, "detail": embed.detail},
        },
    }
    # 200 always: /health must be reachable to *diagnose* a bad load, so a
    # failed load is a 200 body saying "error", not an error status code.
    return JSONResponse(status_code=200, content=body)
