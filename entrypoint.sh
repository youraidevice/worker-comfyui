#!/usr/bin/env bash
set -euo pipefail

echo "[entrypoint] syncing from S3 (RunPod volume via S3 API)…"
python /app/sync_from_s3.py || true

# Link folders into ComfyUI's layout
COMFY_ROOT="/comfyui"  # you installed ComfyUI here
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

# Force path-style for RunPod S3 if requested
if [[ "${S3_FORCE_PATH_STYLE:-false}" == "true" ]]; then
  export AWS_S3_FORCE_PATH_STYLE=true
fi

echo "[entrypoint] launching ComfyUI…"
/opt/venv/bin/python /comfyui/main.py --listen 0.0.0.0 --port 8188 --enable-cors-header "*" &

echo "[entrypoint] starting RunPod serverless loop…"
exec /opt/venv/bin/python -m runpod
