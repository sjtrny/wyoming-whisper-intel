# wyoming-whisper-intel

Docker container for wyoming and whisper on intel GPUs. It is built on the intel/oneapi-basekit container.

## Instructions

Minimal docker compose config below

```
services:
  wyoming-whisper:
    image: ghcr.io/sjtrny/wyoming-whisper-intel:release
    devices:
      - "/dev/dri/renderD129:/dev/dri/renderD129:rwm"
    ports:
      - "7891:7891"
    environment:
      ONEAPI_DEVICE_SELECTOR: "level_zero:gpu"
      ZE_ENABLE_PCI_ID_DEVICE_ORDER: "1"
      WHISPER_MODEL: "small"
      WHISPER_LANG: "en"
      WHISPER_BEAM_SIZE: "5"
      WHISPER_HTTP_HOST: "127.0.0.1"
      WHISPER_HTTP_PORT: "8910"
      WYOMING_URI: "tcp://0.0.0.0:7891"
    restart: unless-stopped
```
