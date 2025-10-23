# ---------- Stage 1: Base ----------
ARG BASE_IMAGE=nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04
FROM ${BASE_IMAGE} AS base

ARG COMFYUI_VERSION=latest
ARG CUDA_VERSION_FOR_COMFY
ARG ENABLE_PYTORCH_UPGRADE=false
ARG PYTORCH_INDEX_URL

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_PREFER_BINARY=1
ENV PYTHONUNBUFFERED=1
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 \
    python3.12-venv \
    python3-pip \
    git \
    wget \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ffmpeg \
 && ln -sf /usr/bin/python3.12 /usr/bin/python \
 && ln -sf /usr/bin/pip3 /usr/bin/pip \
 && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# uv + venv
RUN wget -qO- https://astral.sh/uv/install.sh | sh \
 && ln -s /root/.local/bin/uv /usr/local/bin/uv \
 && ln -s /root/.local/bin/uvx /usr/local/bin/uvx \
 && uv venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# awscli for runtime S3 syncs
RUN uv pip install --no-cache-dir awscli

# comfy-cli + ComfyUI (installs into /comfyui/ComfyUI)
RUN uv pip install comfy-cli pip setuptools wheel
RUN if [ -n "${CUDA_VERSION_FOR_COMFY}" ]; then \
      /usr/bin/yes | comfy --workspace /comfyui install --version "${COMFYUI_VERSION}" --cuda-version "${CUDA_VERSION_FOR_COMFY}" --nvidia; \
    else \
      /usr/bin/yes | comfy --workspace /comfyui install --version "${COMFYUI_VERSION}" --nvidia; \
    fi

# Optional: PyTorch upgrade (usually unnecessary)
RUN if [ "$ENABLE_PYTORCH_UPGRADE" = "true" ]; then \
      uv pip install --force-reinstall torch torchvision torchaudio --index-url ${PYTORCH_INDEX_URL}; \
    fi

# Handler deps
RUN uv pip install runpod requests websocket-client

# ---------- Stage 2: Final (no model downloads) ----------
FROM base AS final

# (No COPY from downloader; models will be mounted or S3-synced at runtime)

WORKDIR /app
# If you don't have test_input.json, remove it from this COPY line.
COPY handler.py /app/
COPY sync_from_s3.py /app/sync_from_s3.py
COPY entrypoint.sh   /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Start: sync from S3 (optional) → launch ComfyUI → run serverless handler
CMD ["/app/entrypoint.sh"]
