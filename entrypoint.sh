#!/usr/bin/env bash
set -euo pipefail

MODE="${RUN_MODE:-serverless}"   # serverless | pod
PORT="${PORT:-8188}"

echo "[entrypoint] RUN_MODE=${MODE}"
python /app/sync_from_s3.py || true

# ComfyUI root installed by comfy-cli
COMFY_ROOT="/comfyui/ComfyUI"

# Ensure dirs exist
mkdir -p "$COMFY_ROOT/models" "$COMFY_ROOT/custom_nodes" /app/workflows

# Link mounted dirs (if present) into ComfyUI
[[ -d "${MODEL_DIR:-/workspace/models}"         ]] && ln -sfn "${MODEL_DIR:-/workspace/models}"         "$COMFY_ROOT/models"
[[ -d "${CUSTOM_NODES_DIR:-/workspace/custom_nodes}" ]] && ln -sfn "${CUSTOM_NODES_DIR:-/workspace/custom_nodes}" "$COMFY_ROOT/custom_nodes"
[[ -d "${WORKFLOW_DIR:-/workspace/workflows}"   ]] && ln -sfn "${WORKFLOW_DIR:-/workspace/workflows}"   /app/workflows

# Some tooling respects this env var for path-style S3
[[ "${S3_FORCE_PATH_STYLE:-false}" == "true" ]] && export AWS_S3_FORCE_PATH_STYLE=true

# Start ComfyUI
if [[ "$MODE" == "serverless" ]]; then
  echo "[entrypoint] launching ComfyUI (bg) + runpod worker"
  /opt/venv/bin/python "$COMFY_ROOT/main.py" --listen 0.0.0.0 --port "$PORT" --enable-cors-header "*" &
  # your handler.py calls runpod.serverless.start(...)
  exec /opt/venv/bin/python /app/handler.py
else
  echo "[entrypoint] launching ComfyUI (pod/interactive)"
  exec /opt/venv/bin/python "$COMFY_ROOT/main.py" --listen 0.0.0.0 --port "$PORT" --enable-cors-header "*"
fi
