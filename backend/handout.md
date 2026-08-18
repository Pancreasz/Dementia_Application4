# MoCA Backend — Handout

Picking this up cold? Start here. Nothing in this directory is built yet — this
document is the complete brief.

*Written 2026-08-18, after the original backend source was lost.*

## What this is

The Flutter app (`Dementia_Application4/`) is a Thai MoCA cognitive screening
tool. It needs an HTTP backend for two things it cannot do on-device:

1. **`/upload`** — scores a clock-drawing image with a DenseNet model.
2. **`/transcribe`** — transcribes Thai speech for eight voice-scored subtests.

The original backend was a Flask service deployed to
`https://moca-flask-container.azurewebsites.net`. **Its source code is gone.**
Only the deployed URL (still referenced in the app) and the clock model weights
survived. `/transcribe` never existed — it is new work.

**Why the backend now lives inside the app repo:** it got separated from the app
once and was lost. Keeping it here versions the HTTP contract together with its
client, in one history, so that cannot happen again.

## Current state

| Piece | State |
|---|---|
| `/upload` endpoint | **Not built.** Contract is fixed by the app — see below. |
| `/transcribe` endpoint | **Not built.** Contract already specified. |
| Clock model weights | **Recovered** — `moca_densenet.pth`, 28,440,806 bytes |
| Clock preprocessing | **UNKNOWN** — see the warning below. This is the main risk. |
| Clock validation images | **Provided** — `clock_0.png` … `clock_3.png`, one per score |
| ASR model | Chosen, not downloaded: `biodatlab/whisper-th-medium-combined` |
| Reference implementation | `ad_hw/sidecar/asr_server.py` — a *working* ASR service |

**The old Azure service is no longer deployed.** The owner confirmed this: the URL
still appears in `clock.dart` only because it was live when that code was written.
So both endpoints are down right now, and **the clock test's 3 points are already
broken in the shipped app** — this is not a future risk, it is the current state.

Until `/transcribe` exists, **13 of the app's 29 points cannot score.** They reach
an error screen and can only be skipped. Vigilance (1 point) is tap-based and is
the only voice-section point that works today.

That makes both endpoints equally load-bearing. `/transcribe` unblocks more points,
but `/upload` is a regression from something that used to work.

---

## The contracts — these are fixed, not proposals

### `POST /upload`

Pinned by `lib/pages/clock.dart`. You do not get to redesign this without
changing the app.

Request: `multipart/form-data`, single field **`file`**, a PNG.

Response `200`:

```json
{"message": "...", "filename": "...", "predicted_moca_score": 2}
```

**Three things that will crash the app if you get them wrong:**

- `predicted_moca_score` **must be a JSON integer**, 0–3. `clock.dart:51` does
  `clockScore = predictedScore` where `clockScore` is a Dart `int`. Returning
  `2.0` or `"2"` throws at runtime, inside a `try` that only catches JSON parse
  errors — so it surfaces to the user as a misleading "Error parsing server
  response".
- `message` and `filename` **must be strings**. They are read as
  `responseData['message'] ?? 'No message'` into a `final String`. A non-string
  throws the same way.
- Any non-200 status is shown to the user with its raw status and body. Keep
  error bodies short and free of anything sensitive.

### `POST /transcribe`

Specified in
`design_docs/superpowers/specs/2026-08-17-voice-subtests-design.md`.

Request: `multipart/form-data`, field **`file`** (WAV, 16 kHz mono PCM), field
**`language`** (string, `"th"`).

Response `200`:

```json
{
  "text": "สองสี่เจ็ด",
  "segments": [{"start": 0.0, "end": 0.5, "text": "สอง"}]
}
```

Response `503` while the model is still loading:

```json
{"detail": "model not loaded"}
```

**`segments` is not optional decoration.** Verbal Fluency scores by counting
*distinct segments*, not by splitting text. Thai has no spaces between words and
the recognizer's spacing is arbitrary, so splitting text would count an
unpredictable number of "words" for identical speech. Segments key off the
patient's own pauses instead. faster-whisper produces them natively — just do not
discard them the way the reference implementation does.

The client tolerates a missing or malformed `segments` field, since only one
scorer reads it. It **throws** if `text` is missing — an empty transcript would be
scored as the patient having said nothing, which is a wrong score rather than a
visible error.

### `GET /health`

```json
{"status": "loading" | "ready" | "error", "detail": "..."}
```

Load the model on a background thread so `/health` answers immediately. Copy this
pattern from `ad_hw/sidecar/asr_server.py` — it exists because a synchronous load
makes the first request hang for around ten seconds with no way to diagnose it.

---

## The clock model — read this before writing any inference code

`moca_densenet.pth` is a **PyTorch** `state_dict`. Verified by inspecting all 727
tensors:

- `features.conv0.weight` is `(64, 3, 7, 7)` — torchvision DenseNet stem,
  3-channel RGB, channels-first
- `features.*` naming throughout, i.e. `torchvision.models.densenet121`
- `classifier.weight` is `(4, 1024)` and `classifier.bias` is `(4,)` — a
  **single** `Linear(1024 -> 4)`

So: `densenet121` with its classifier replaced by `Linear(1024, 4)`. Four classes
= clock scores 0, 1, 2, 3.

### The training script we have does NOT match these weights

The project owner supplied a training script. **It produced a different model.**
It is Keras/TensorFlow:

| | The script | `moca_densenet.pth` |
|---|---|---|
| Framework | TensorFlow / Keras | PyTorch |
| Head | GAP -> `Dense(1024, relu)` -> Dropout -> `Dense(4)` | single `Linear(1024, 4)` |
| A 1024x1024 tensor | must exist | **none exists** — all 727 were searched |
| Layout | channels-last `(224,224,3)` | channels-first `(64,3,7,7)` |

Do not treat that script as the source of truth for preprocessing. Two things
from it are still probably right, because they corroborate the weights:

- **224x224** input (`IMG_SIZE = (224, 224)`), which is conventional for DenseNet
  anyway.
- **Class index == score.** The script encodes labels with `LabelEncoder` over
  directory names, which sorts alphabetically, so folders `0,1,2,3` map index 0 to
  score 0. Assume the PyTorch run followed the same convention.

### What to implement, and how to flag it

Use the torchvision default transform:

```python
transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),                      # scales to [0,1]
    transforms.Normalize(mean=[0.485, 0.456, 0.406],
                         std=[0.229, 0.224, 0.225]),
])
```

**Put this in one clearly-marked place, with a comment saying it is assumed and
not verified.** If it is wrong the model returns confident nonsense rather than an
error — a fabricated clinical score. That is the exact failure mode this project
is built to avoid.

Note that the Keras script fed **raw 0–255** values with no rescaling
(`np.array(img)` and a bare `ImageDataGenerator()`). If the standard transform
gives obviously wrong predictions, that is the first alternative to try:
`ToTensor()` without `Normalize`, or a `*255` scaling.

### How to validate — you have labelled images, use them

`clock_0.png` through `clock_3.png` sit in this directory. The filename is the
known correct score: `clock_2.png` should predict `2`.

**Do this before writing the endpoint.** A throwaway script that loads the
`state_dict` into `torchvision.models.densenet121(num_classes=4)` and runs those
four images tells you in minutes whether the preprocessing assumption holds.

Try these in order and record which fits:

| # | Transform | Rationale |
|---|---|---|
| 1 | Resize 224, `ToTensor()`, ImageNet `Normalize` | torchvision default; most likely for a PyTorch fine-tune |
| 2 | Resize 224, `ToTensor()` only (values in [0,1]) | if the run skipped normalization |
| 3 | Resize 224, `ToTensor()`, then `*255` (raw 0–255) | what the Keras script did — no rescaling at all |

**Interpreting the result honestly:** four images across four classes means a
random model scores 4/4 by luck about 0.4% of the time, so 4/4 is meaningful
evidence — but it is four images, not a test set. It tells you the preprocessing
is *plausible*, not that the model is accurate. If two transforms both score 4/4,
prefer #1 and say so in a comment.

If none of them gets 4/4, stop and report it rather than shipping the closest fit.
A transform that scores 2/4 is not "mostly right" — it is a model returning
confident nonsense, and it will look entirely normal in production.

---

## The ASR model

**`biodatlab/whisper-th-medium-combined`** — a Thai fine-tune of Whisper-medium.

| | |
|---|---|
| Format | `transformers` safetensors, **not** CTranslate2 |
| Size | 1.63 GB, fp16 |
| Architecture | whisper, 24 encoder layers, d_model 1024 (i.e. medium) |

**Convert it to CTranslate2 int8.** This is the agreed approach:

```bash
pip install transformers torch    # conversion only, not runtime
ct2-transformers-converter \
  --model biodatlab/whisper-th-medium-combined \
  --quantization int8 \
  --output_dir backend/models/whisper-th-ct2
```

- Around 800 MB instead of 1.63 GB
- Several times faster on CPU
- Runtime then needs only `ctranslate2` and `faster_whisper`, both already
  installed
- The same artifact deploys to Azure later, unchanged

Then load it with `faster_whisper.WhisperModel("backend/models/whisper-th-ct2",
device="cpu", compute_type="int8")`.

`backend/models/` must be gitignored — it is 800 MB of derived data. Provide a
setup script so a fresh clone can regenerate it.

### Latency — plan for this, it is not a detail

Whisper-medium int8 on CPU will plausibly take **30–120 seconds** for a
60-second clip. Verbal Fluency's recording is **exactly 60 seconds** by clinical
definition — it is not a case that might happen to be short.

Consequences already being handled on the Flutter side:

- The client's request timeout was 45 s and is being raised to around 180 s.
- The scoring screen is getting a Skip control, because a three-minute spinner
  with no escape looks like a frozen app.

If you can make transcription faster, that is real user value. Options if it
proves too slow: a smaller Thai model, GPU hosting, or streaming partial results.

---

## Environment

Machine is Windows. **Python 3.14.6.**

An existing virtualenv at `ad_hw/sidecar/.venv` already contains much of what you
need. Reuse it or build a fresh one.

| Already installed | Version |
|---|---|
| `ctranslate2` | 4.8.1 |
| `faster_whisper` | 1.2.1 |
| `av` (PyAV, bundles FFmpeg) | 18.1.0 |
| `fastapi` / `uvicorn` | 0.141.1 / 0.52.2 |
| `onnxruntime`, `tokenizers`, `huggingface_hub`, `numpy` | — |

| Still needed | Note |
|---|---|
| `torch`, `torchvision` | For the clock model. **cp314 wheels exist** (torch 2.13.0, torchvision 0.28.0), so Python 3.14 is fine. |
| `pillow` | Image loading. cp314 wheels exist. |
| `transformers` | Conversion step only, not runtime. Pure Python. |
| `python-multipart` | FastAPI multipart form parsing. |

**Framework: FastAPI, not Flask.** The original service's name is the only trace
of Flask left, nothing depends on it, `fastapi` and `uvicorn` are already
installed, and `ad_hw/sidecar/asr_server.py` is a working reference. The Flutter
client does not care which framework serves the endpoints.

## Suggested structure

```
backend/
  app.py                  FastAPI routes only — no inference logic
  asr.py                  Whisper CT2 load + transcribe
  clock.py                DenseNet load + predict (preprocessing lives here)
  models/                 gitignored — CT2 output
  moca_densenet.pth       committed (28 MB)
  requirements.txt
  scripts/convert_model.py
  tests/
```

Three modules rather than one file, so `asr.py` and `clock.py` are independently
testable without HTTP and `app.py` owns only request and response shape. That
same separation is what made the app's Dart scorers testable.

## Testing

Follow `ad_hw/sidecar/test_asr_server.py`: **monkeypatch the model loaders** so
tests never download 800 MB or run inference. Worth pinning:

- `/upload` returns `predicted_moca_score` as an **`int`**, and `message` and
  `filename` as **strings** — the three crash-the-app cases above.
- `/upload` validates or clamps the class index into 0–3.
- `/transcribe` returns `segments` as a list of `{start, end, text}`.
- `/transcribe` returns **503**, not 200 with an empty text, while loading.
- `/health` answers immediately during loading, and reports `error` with a
  diagnosable `detail` when a load fails.
- A malformed upload (not an image, empty body) returns 4xx, not 500.

## Gotchas inherited from the reference implementation

These cost real debugging time in `ad_hw`. Do not rediscover them.

1. **`SSL_CERT_FILE` can be broken by conda.** Conda's `openssl_activate.sh` may
   set it to a path missing the `Library/` segment Windows needs, which breaks all
   Python HTTPS and shows up as a model download failing with a bare
   `FileNotFoundError` and no filename. `asr_server.py` has a
   `describe_load_failure()` helper that names this cause explicitly in `/health`.
   Copy it.
2. **Python HTTP probes against a localhost service need
   `httpx.Client(trust_env=False)`.** Otherwise httpx picks up a Windows registry
   proxy that has no localhost bypass and cannot reach `127.0.0.1`, producing a
   convincing but false "the server is hung".
3. **Do not construct the model at import time.** Tests import the module, and a
   module-level constructor triggers a multi-hundred-megabyte download during test
   collection.

## What the Flutter side is doing (not your job)

So you know where the seam is:

- The backend base URL is moving into one file, `lib/moca/backend_config.dart`,
  so both `/upload` and `/transcribe` derive from it. Pointing the app at
  `http://localhost:8000` now and at Azure later becomes a one-line edit.
- The ASR request timeout is being raised from 45 s toward 180 s.
- The scoring and stimulus screens are getting a Skip control.

**Target for now: localhost, CPU.** Azure is planned later, which is exactly why
the CT2 int8 route matters — it is the same artifact either way.

## Answered by the project owner (2026-08-18)

1. **Is the old Azure container still deployed?** — **No.** It is gone. The URL
   survives in `clock.dart` only because the service was live when that code was
   written. Both endpoints must be rebuilt; nothing is still serving.
2. **Are there clock images with known scores?** — **Yes**, four of them, in this
   directory: `clock_0.png` … `clock_3.png`, filename = correct score. Use them as
   described in "How to validate" above.
3. **Does the PyTorch training script still exist?** — **No, permanently lost.**
   The preprocessing cannot be recovered from source and must be established
   empirically against those four images. That is why the validation step is not
   optional.

## Still open

- **Only four validation images exist.** They are enough to sanity-check the
  preprocessing, not enough to characterise accuracy. If more labelled clock
  drawings can be found, they would upgrade `/upload` from "plausible" to
  "measured".
