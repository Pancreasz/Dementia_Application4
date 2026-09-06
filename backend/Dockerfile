# syntax=docker/dockerfile:1
FROM python:3.14-slim

WORKDIR /app

# Thread arenas (OpenMP/MKL) each cost real RSS on top of the tensors
# themselves — torch and ctranslate2 both spin up worker-thread pools sized
# to the host's CPU count by default, which adds up fast on a small
# container. Pin them to 1 since this app serves one request at a time
# anyway (see CMD: no --workers flag).
ENV OMP_NUM_THREADS=1 \
    MKL_NUM_THREADS=1

# libgomp1: OpenMP runtime torch/torchvision need on Linux; not in the slim base.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# CPU-only torch/torchvision first, from PyTorch's own CPU wheel index. Plain
# PyPI wheels for torch on Linux pull in the full CUDA runtime (~2GB) that
# neither Azure Container Apps' CPU tier nor this app's CPU-only inference
# path (see clock.py, asr.py) ever uses.
RUN pip install --no-cache-dir \
    --index-url https://download.pytorch.org/whl/cpu \
    torch==2.13.0 torchvision==0.28.0

# Remaining runtime deps. torch/torchvision are already installed at the
# pinned version above, so this step does not re-fetch them from PyPI.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Routes + inference code. Tests, scripts, and dev-only requirements files
# are excluded via .dockerignore.
COPY app.py asr.py clock.py ./

# Model artifacts. Both are gitignored (backend/.gitignore) and must already
# exist in this build context before running `docker build`:
#   moca_densenet.pth       <- python scripts/restore_weights.py
#   models/whisper-th-ct2/  <- python scripts/convert_model.py
#                              (must include tokenizer.json — that script
#                              writes it; without it faster-whisper fetches
#                              the tokenizer from huggingface.co at every
#                              container start instead of staying offline)
COPY moca_densenet.pth ./
COPY models/ ./models/

EXPOSE 8000

# Liveness only: GET /health always returns HTTP 200, even mid-load or after
# a failed model load (see app.py) — it exists to be reachable for diagnosis,
# not to gate readiness. This confirms the process is up. If your platform's
# probes need true readiness, point them at /health and check the
# {"status": "ready"} field in the body rather than the status code alone.
#
# Some hosts (Render, Heroku-style PaaS) assign the listen port at runtime
# via $PORT instead of a fixed one — default to 8000 (what Azure/local
# docker run expect) when it's unset.
HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
    CMD python -c "import os,urllib.request,sys; port=os.environ.get('PORT','8000'); sys.exit(0 if urllib.request.urlopen(f'http://localhost:{port}/health').status==200 else 1)"

CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]
