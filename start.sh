#!/usr/bin/env bash
set -euo pipefail

# --- config from env (with defaults) ---
: "${WHISPER_MODEL:=small}"              # small | medium | large-v2 | large-v3
: "${WHISPER_LANG:=en}"
: "${WHISPER_BEAM_SIZE:=5}"
: "${WHISPER_HTTP_HOST:=127.0.0.1}"
: "${WHISPER_HTTP_PORT:=8910}"
: "${WYOMING_URI:=tcp://0.0.0.0:7891}"
: "${MODEL_BASE_URL:=https://huggingface.co/ggerganov/whisper.cpp/resolve/main}"

MODELS_DIR=/models
MODEL_FILE="ggml-${WHISPER_MODEL}.bin"
MODEL_PATH="${MODELS_DIR}/${MODEL_FILE}"

mkdir -p "${MODELS_DIR}"

# ensure model exists (download if missing) — quick and dirty
if [[ ! -s "${MODEL_PATH}" ]]; then
  echo "[start] downloading ${MODEL_FILE} ..."
  tmp="$(mktemp)"
  wget -L -O "${tmp}" "${MODEL_BASE_URL}/${MODEL_FILE}"
  mv "${tmp}" "${MODEL_PATH}"
fi

# oneAPI runtime libs (avoid libsvml.so errors)
export LD_LIBRARY_PATH="/opt/intel/oneapi/compiler/latest/lib:/opt/intel/oneapi/compiler/latest/linux/lib:/opt/intel/oneapi/compiler/latest/linux/compiler/lib/intel64_lin:/opt/intel/oneapi/tbb/latest/lib/intel64/gcc4.8:/opt/intel/oneapi/mkl/latest/lib:${LD_LIBRARY_PATH:-}"

# 1) start whisper.cpp in the background (NO readiness wait)
 /whisper.cpp/build/bin/whisper-server \
  -m "${MODEL_PATH}" \
  --host "${WHISPER_HTTP_HOST}" \
  --port "${WHISPER_HTTP_PORT}" \
  -l "${WHISPER_LANG}" \
  -bs "${WHISPER_BEAM_SIZE}" \
  --suppress-nst &
WHISPER_PID=$!

# 2) immediately start the Wyoming bridge in the foreground
cd /wyoming-whisper-api-client
source .venv/bin/activate
exec ./script/run \
  --uri "${WYOMING_URI}" \
  --api "http://${WHISPER_HTTP_HOST}:${WHISPER_HTTP_PORT}/inference"
