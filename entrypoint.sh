#!/usr/bin/env bash
set -euo pipefail

echo "[entrypoint] syncing from S3 (RunPod volume via S3 API)…"
python /app/sync_from_s3.py || true

# Symlink into ComfyUI expected locations
COMFY_ROOT="/app/ComfyUI"
mkdir -p "$COMFY_ROOT/models" "$COMFY_ROOT/custom_nodes" /app/workflows

if [[ -d "${MODEL_DIR:-/workspace/models}" ]]; then
  ln -sfn "${MODEL_DIR:-/workspace/models}" "$COMFY_ROOT/models"
fi
if [[ -d "${CUSTOM_NODES_DIR:-/workspace/custom_nodes}" ]]; then
  ln -sfn "${CUSTOM_NODES_DIR:-/workspace/custom_nodes}" "$COMFY_ROOT/custom_nodes"
fi
if [[ -d "${WORKFLOW_DIR:-/workspace/workflows}" ]]; then
  ln -sfn "${WORKFLOW_DIR:-/workspace/workflows}" /app/workflows
fi

echo "[entrypoint] launching ComfyUI…"
if [[ -f "/app/main.py" ]]; then
  python /app/main.py --listen 0.0.0.0 --port 8188 --enable-cors-header "*" &
else
  python /app/ComfyUI/main.py --listen 0.0.0.0 --port 8188 --enable-cors-header "*" &
fi

echo "[entrypoint] starting RunPod serverless loop…"
exec python -m runpod
