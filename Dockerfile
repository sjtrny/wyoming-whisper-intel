# syntax=docker/dockerfile:1
FROM intel/oneapi-basekit:latest

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

# --- base tools ---
RUN apt-get update && apt-get install -y --no-install-recommends \
      git cmake build-essential ca-certificates wget \
      python3 python3-venv python3-pip curl \
      && rm -rf /var/lib/apt/lists/*

# --- build whisper.cpp (Intel oneAPI SYCL) ---
WORKDIR /whisper.cpp
RUN git clone https://github.com/ggerganov/whisper.cpp.git . \
 && git reset --hard v1.7.4 \
 && cmake -B build \
      -DGGML_SYCL=ON \
      -DGGML_SYCL_F16=ON \
      -DCMAKE_C_COMPILER=icx \
      -DCMAKE_CXX_COMPILER=icpx \
 && cmake --build build -j --config Release

# --- wyoming bridge (API client) ---
WORKDIR /
RUN git clone https://github.com/ser/wyoming-whisper-api-client.git \
 && cd wyoming-whisper-api-client \
 && ./script/setup

# Make sure the repo's venv bins are easily reachable when debugging
ENV PATH="/wyoming-whisper-api-client/.venv/bin:${PATH}"

# copy the startup script
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh && mkdir -p /models /var/log/whispercpp

# --- sane GPU defaults ---
ENV ONEAPI_DEVICE_SELECTOR=level_zero:gpu \
    ZE_ENABLE_PCI_ID_DEVICE_ORDER=1

# --- configurable defaults (override in compose) ---
ENV ONEAPI_DEVICE_SELECTOR=level_zero:gpu \
    ZE_ENABLE_PCI_ID_DEVICE_ORDER=1 \
    WHISPER_MODEL=small \
    WHISPER_LANG=en \
    WHISPER_BEAM_SIZE=5 \
    WHISPER_HTTP_HOST=0.0.0.0 \
    WHISPER_HTTP_PORT=8910 \
    WYOMING_URI=tcp://0.0.0.0:7891 \
    MODEL_BASE_URL=https://huggingface.co/ggerganov/whisper.cpp/resolve/main

# Only expose Wyoming port; whisper HTTP stays internal
EXPOSE 7891

# Optional: healthcheck via whisper's internal /describe
HEALTHCHECK --start-period=60s --interval=30s --timeout=5s --retries=5 \
  CMD curl -fsS "http://${WHISPER_HTTP_HOST}:${WHISPER_HTTP_PORT}/" >/dev/null || exit 1

CMD ["/usr/local/bin/start.sh"]
