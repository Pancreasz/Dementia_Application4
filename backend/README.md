# MoCA Backend

HTTP service for the Thai MoCA app. Two scoring endpoints the app can't run
on-device, plus a health check.

| Endpoint | Purpose | Contract pinned by |
|---|---|---|
| `POST /upload` | Score a clock drawing (0–3) | `lib/pages/clock.dart` |
| `POST /transcribe` | Transcribe Thai speech | `lib/moca/asr_client.dart` |
| `GET /health` | Model load status | this repo |

Framework is **FastAPI**, not Flask — see [ADR 0001](docs/adr/0001-fastapi-over-flask.md).
Domain terms are in [CONTEXT.md](CONTEXT.md).

## Layout

```
app.py            FastAPI routes only — no inference
clock.py          DenseNet load + predict (preprocessing lives here)
asr.py            Whisper CT2 load + transcribe
models/           gitignored — CT2 int8 output of scripts/convert_model.py
moca_densenet.pth gitignored — restore via scripts/restore_weights.py
scripts/          restore_weights, convert_model, validate_clock
tests/            monkeypatched — no weights load, no downloads
```

## Setup from a fresh clone (Windows, Python 3.14)

```bash
cd backend
python -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements-dev.txt
.venv/Scripts/python.exe scripts/restore_weights.py
```

That is enough to run `/upload` and the full test suite. `/transcribe` needs the
ASR model, which is a separate, heavier step (≈1.6 GB download → ≈800 MB int8):

```bash
.venv/Scripts/python.exe -m pip install -r requirements-convert.txt
.venv/Scripts/python.exe scripts/convert_model.py
```

## Run

```bash
.venv/Scripts/python.exe -m uvicorn app:app --host 0.0.0.0 --port 8000
```

Point the app at it by setting the base URL to `http://localhost:8000`
(the Flutter side centralises this in `lib/moca/backend_config.dart`).

## Test

```bash
.venv/Scripts/python.exe -m pytest -q
```

Tests monkeypatch the model loaders, so they never download the ASR model or run
real inference. They pin the crash-the-app response types, the 503-while-loading
behaviour, and that malformed uploads are 4xx not 500.

## Validate clock preprocessing

The clock preprocessing transform is **assumed, not verified** — the original
training script is lost. Before trusting `/upload`, confirm it against the four
labelled images:

```bash
.venv/Scripts/python.exe scripts/validate_clock.py
```

It runs the three candidate transforms against `clock_0..3.png` and reports which
scores 4/4. If none does, it exits non-zero — do not ship the closest fit.

## Latency (ASR)

Whisper-medium int8 on CPU is ≈30–120 s for a 60 s clip; Verbal Fluency's
recording is exactly 60 s. The Flutter client's timeout is raised toward 180 s
and the scoring screen has a Skip control. Faster transcription (smaller model,
GPU, streaming) is real user value if pursued later.

Measured on this machine (2026-08-18, CPU, int8): model **load 37–102 s**
(warm disk cache vs cold — it is a one-time startup cost, and `/health` reports
`loading` until it finishes), and **≈12 s per short clip** (short clips still pay
Whisper's fixed 30 s-window decode cost). Well within the 180 s client timeout.

## ASR accuracy is NOT validated

The model transcribes Thai and returns correct segment structure, verified
end-to-end. It is **not** verified for scoring accuracy. A smoke test on the
isolated 1-second `digit-N.wav` *stimulus* files (not patient responses) got the
right digit word for 2/7/0 but misread 5 (`ฮ่า` for `ห้า`) and repeated words
(`สอง สอง`) — expected behaviour for Whisper on sub-second clips, and not
representative of the real scoring input. Per the voice-subtests design doc, the
Verbal Fluency and Sentence Repetition thresholds stay **unvalidated until a
manual real-speech pass** is run against real patient audio. Do not read the
smoke test as an accuracy claim.
