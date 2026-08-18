"""FastAPI app for the MoCA backend.

Routes only — all inference lives in clock.py and asr.py. Both models load on
background threads at startup so GET /health answers immediately.

Endpoints:
  POST /upload      clock-drawing image  -> {message, filename, predicted_moca_score}
  POST /transcribe  Thai WAV             -> {text, segments} | 503 {detail}
  GET  /health      -> {status, detail, models}
"""

from __future__ import annotations

import io
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from asr import AsrModel, LoadState
from clock import ClockModel

_WEIGHTS_PATH = os.path.join(os.path.dirname(__file__), "moca_densenet.pth")

# Constructed here, not loaded here: these constructors only store config. The
# heavy load happens in start_loading() during the lifespan below, so importing
# this module (in tests) never touches weights or downloads a model. Tests
# monkeypatch these module globals with fakes; routes read them via the
# accessors below so a patched global takes effect.
clock_model = ClockModel(_WEIGHTS_PATH)
asr_model = AsrModel()


def get_clock() -> ClockModel:
    return clock_model


def get_asr() -> AsrModel:
    return asr_model


@asynccontextmanager
async def lifespan(app: FastAPI):
    get_clock().start_loading()
    get_asr().start_loading()
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
    """Transcribe Thai speech. Returns text + faster-whisper segments.

    While the model is still loading (or failed to load) this returns 503 with
    a {detail} body rather than 200 with an empty transcript — an empty
    transcript would be scored as the patient having said nothing.
    """
    asr = get_asr()
    if not asr.is_ready:
        detail = "model not loaded" if asr.state == LoadState.LOADING else asr.detail
        raise HTTPException(status_code=503, detail=detail)

    audio_bytes = await file.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="empty upload")

    try:
        result = asr.transcribe(io.BytesIO(audio_bytes), language=language)
    except Exception as exc:  # noqa: BLE001 - decode/transcode failure -> 4xx
        raise HTTPException(status_code=400, detail=f"could not decode audio: {exc}")

    return result.to_dict()


@app.get("/health")
async def health():
    """Aggregate health. status is 'error' if either model failed, 'loading'
    if either is still loading, else 'ready'. Answers immediately during load.
    """
    clock = get_clock()
    asr = get_asr()
    states = [clock.state, asr.state]
    if LoadState.ERROR in states:
        status = LoadState.ERROR
    elif LoadState.LOADING in states:
        status = LoadState.LOADING
    else:
        status = LoadState.READY

    body = {
        "status": status.value,
        "detail": f"clock: {clock.detail} | asr: {asr.detail}",
        "models": {
            "clock": {"status": clock.state.value, "detail": clock.detail},
            "asr": {"status": asr.state.value, "detail": asr.detail},
        },
    }
    # 200 always: /health must be reachable to *diagnose* a bad load, so a
    # failed load is a 200 body saying "error", not an error status code.
    return JSONResponse(status_code=200, content=body)
