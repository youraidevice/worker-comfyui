#!/usr/bin/env bash
set -euo pipefail

MODE="${RUN_MODE:-serverless}"   # serverless | pod

echo "[entrypoint] RUN_MODE=${MODE}"
python /app/sync_from_s3.py || true

# Link folders into ComfyUI's layout
COMFY_ROOT="/comfyui"
mkdir -p "$COMFY_ROOT/models" "$COMFY_ROOT/custom_nodes" /app/workflows
[[ -d "${MODEL_DIR:-/workspace/models}"        ]] && ln -sfn "${MODEL_DIR:-/workspace/models}"        "$COMFY_ROOT/models"
[[ -d "${CUSTOM_NODES_DIR:-/workspace/custom_nodes}" ]] && ln -sfn "${CUSTOM_NODES_DIR:-/workspace/custom_nodes}" "$COMFY_ROOT/custom_nodes"
[[ -d "${WORKFLOW_DIR:-/workspace/workflows}"  ]] && ln -sfn "${WORKFLOW_DIR:-/workspace/workflows}"  /app/workflows

[[ "${S3_FORCE_PATH_STYLE:-false}" == "true" ]] && export AWS_S3_FORCE_PATH_STYLE=true

if [[ "$MODE" == "serverless" ]]; then
  echo "[entrypoint] launching ComfyUI (bg) + RunPod serverless loop…"
  /opt/venv/bin/python /comfyui/main.py --listen 0.0.0.0 --port 8188 --enable-cors-header "*" &
  exec /opt/venv/bin/python -m runpod
else
  echo "[entrypoint] launching ComfyUI (pod/interactive)…"
  exec /opt/venv/bin/python /comfyui/main.py --listen 0.0.0.0 --port 8188 --enable-cors-header "*"
fi
