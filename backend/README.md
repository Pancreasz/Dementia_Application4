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
models/           gitignored — CT2 output of scripts/convert_model.py,
                  including tokenizer.json (fetched by that script so
                  faster-whisper never needs Hugging Face Hub access at
                  model-load time — a missing tokenizer.json makes /transcribe
                  silently require internet on every restart, see the
                  script's docstring)
moca_densenet.pth gitignored — restore via scripts/restore_weights.py
scripts/          restore_weights, convert_model, validate_clock
tests/            monkeypatched — no weights load, no downloads
```

## Setup from a fresh clone (Windows, Python 3.14)

> **Where the venv lives on this machine.** It is at
> `Dementia_Application4/.venv` — one level *above* `backend/` — not
> `backend/.venv`. Every command below is written for that layout and is meant
> to be run from `backend/`, which is why they all say `../.venv/…`. On a
> genuinely fresh clone you may of course create `backend/.venv` instead and
> drop the `../`.

```bash
cd backend
python -m venv ../.venv
../.venv/Scripts/python.exe -m pip install -r requirements-dev.txt
../.venv/Scripts/python.exe scripts/restore_weights.py
```

That is enough to run `/upload` and the full test suite.

> **If `/health` says the clock model failed to load, read the detail, not the
> exception.** `moca_densenet.pth` is gitignored, so the only thing that puts it
> on disk is the script above. Since 2026-09-09 a run that dies partway leaves
> the destination untouched (it stages a `.part` file and verifies size *and*
> sha256 before renaming), and `/health` names a short file as an *incomplete
> restore* rather than reporting torch's `PytorchStreamReader … internal miniz
> error`, which reads as a corrupt model and is not. Re-running the script fixes
> it. Two ways to get a bad file anyway: a **shallow clone**, where the old
> commit holding the blob was never fetched (`git fetch --unshallow`), and
> running the `git cat-file` by hand in **PowerShell**, where `>` re-encodes the
> binary stream as text — that one produces a file of the wrong size, which is
> why the check is a hash and not just a byte count.

`/transcribe` needs the ASR model, which is a separate, heavier step (≈5.8 GB download → ≈3.1 GB
float16):

```bash
../.venv/Scripts/python.exe -m pip install -r requirements-convert.txt
../.venv/Scripts/python.exe scripts/convert_model.py
```

That builds the **Thai** model, `scb10x/typhoon-whisper-large-v3`, in place of
`biodatlab/whisper-th-medium-combined` since 2026-09-07. The old one is a third
of the size and still builds — see `scripts/convert_model.py`'s docstring for
the environment variables that rebuild it, and set
`MOCA_ASR_MODEL_DIR=models/whisper-th-ct2` to run against it.

### The English model

Since 2026-09-08 `language` **selects the model**, it is not just a decoding
hint. English goes to `Systran/faster-distil-whisper-large-v3`, expected at
`systran-whisper/` in the repo root (one level above `backend/`) and
overridable with `MOCA_ASR_MODEL_DIR_EN`. Download it with:

```bash
huggingface-cli download Systran/faster-distil-whisper-large-v3 \
  --local-dir ../systran-whisper
```

There is deliberately **no fallback between the two**. A Thai fine-tune is not
an English recognizer — `handout.md` records what serving English from it
produced — so if the English model is missing, English `/transcribe` answers
503 and the subtest records as *not administered* rather than being scored on
hallucinated text.

`/health` lists both as `asr` (Thai) and `asr_en`. **On a fresh clone both are
expected to report `no model directory at …` until you run the two steps above**
— neither checkpoint is committed, and a gigabytes-sized download is not
something a clone should do behind your back. The message quotes the command
that fetches the missing one, so `/health` is enough on its own to tell you what
is left to do.

> **Memory.** Two large-v3-class models are resident at once. They load one at
> a time, but the steady state is roughly 2.5 GB for the pair plus ~0.5 GB for
> the embedding model. On a 15.6 GB workstation with ~2 GB free the second load
> failed with `mkl_malloc: failed to allocate memory` — `/health` then reports
> one ASR model ready and the other in error, which is the shape to look for.
> A Thai-only deployment can point `MOCA_ASR_MODEL_DIR_EN` at nothing and save
> the whole English footprint.

## Run

```bash
../.venv/Scripts/python.exe -m uvicorn app:app --host 0.0.0.0 --port 8000
```

Point the app at it by setting the base URL to `http://localhost:8000`
(the Flutter side centralises this in `lib/moca/backend_config.dart`).

## Browser access (CORS + Private Network Access)

The Flutter **web** build calls this service from a browser, so both endpoints
are cross-origin. Allowed origins:

- `https://pancreasz.github.io` — the published GitHub Pages build
- `http://localhost:<any>` / `http://127.0.0.1:<any>` — `flutter run -d chrome`

Deliberately not `*`, and not all of `*.github.io`: `/upload` and `/transcribe`
are unauthenticated and accept patient drawings and audio. Override without
editing code:

```bash
set MOCA_ALLOWED_ORIGIN_REGEX=^https://your\.host$
```

`allow_private_network=True` is also set. Chrome sends an extra preflight when a
*public* page (github.io) fetches a *private* address (localhost), and Starlette
answers it `400 Disallowed CORS private-network` by default — which breaks the
published site while leaving `flutter run -d chrome` working, a confusing pair of
symptoms.

## Test

```bash
../.venv/Scripts/python.exe -m pytest -q
```

Tests monkeypatch the model loaders, so they never download the ASR model or run
real inference. They pin the crash-the-app response types, the 503-while-loading
behaviour, and that malformed uploads are 4xx not 500.

## Validate clock preprocessing

The clock preprocessing transform is **assumed, not verified** — the original
training script is lost. Before trusting `/upload`, confirm it against the four
labelled images:

```bash
../.venv/Scripts/python.exe scripts/validate_clock.py
```

It runs the three candidate transforms against `clock_0..3.png` and reports which
scores 4/4. If none does, it exits non-zero — do not ship the closest fit.

## Latency (ASR)

Whisper on CPU is tens of seconds for a 60 s clip; Verbal Fluency's recording is
exactly 60 s. The Flutter client's timeout is raised toward 180 s and the
scoring screen has a Skip control. Faster transcription (smaller model, GPU,
streaming) is real user value if pursued later.

Measured on this machine, same clips, both models, CPU, `compute_type="int8"`:

| | typhoon large-v3 (current) | whisper-th medium (previous) |
|---|---|---|
| Load, cold / warm | 17.1 s / 12.7 s | — / 2.4 s |
| Short clip (8 s audio) | 19–21 s | 11–12 s |
| Sentence clip | 25–27 s | 14–18 s |
| `vigilance.wav` (29 digits) | 40 s | — |

Short clips still pay Whisper's fixed 30 s-window decode cost, which is why an
8-second clip is not proportionally faster than a 30-second one. Everything here
is well inside the 180 s client timeout, but the current model is roughly 1.7x
the previous one per clip — budget for that on slower hardware. The earlier
figure of "load 37–102 s" was the medium model on a cold disk cache; the loads
above were taken back to back on a warm one and are not comparable to it.

Accuracy on those same clips is **mixed, not uniformly better** — see
`design_docs/CONTENT-STATUS.md` item **j** for the side-by-side.

The English model is faster on both counts: **load 8.5 s**, and **15 s per
clip** against typhoon's 19–27 s. distil-large-v3 has two decoder layers rather
than thirty-two, which is where that comes from.

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
