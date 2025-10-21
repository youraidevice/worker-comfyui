import os, subprocess, pathlib

def sync(prefix_env, dst_env, label):
    src = os.getenv(prefix_env, "").strip()
    dst = os.getenv(dst_env, "").strip()
    endpoint = os.getenv("BUCKET_ENDPOINT_URL", "").strip()
    region = os.getenv("BUCKET_REGION", os.getenv("AWS_DEFAULT_REGION", "")).strip()

    if not src or not dst:
        print(f"[sync] {label}: skipped (missing {prefix_env} or {dst_env})")
        return

    pathlib.Path(dst).mkdir(parents=True, exist_ok=True)
    print(f"[sync] {label}: {src}  ->  {dst}")

    # aws cli respects AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
    cmd = [
        "aws", "s3", "sync", src, dst,
        "--endpoint-url", endpoint,
        "--region", region
    ]
    # Path-style addressing is needed for RunPod S3
    if os.getenv("S3_FORCE_PATH_STYLE", "false").lower() == "true":
        cmd += ["--no-verify-ssl"] if endpoint.startswith("http://") else []
        # awscli doesn’t have a direct flag; env var does the job:
        os.environ["AWS_S3_FORCE_PATH_STYLE"] = "true"

    # Retry a couple times for big model sets
    attempts = 3
    for i in range(1, attempts+1):
        print(f"[sync] {label}: attempt {i}/{attempts}")
        rc = subprocess.call(cmd)
        if rc == 0:
            print(f"[sync] {label}: OK")
            return
        print(f"[sync] {label}: failed (rc={rc}), retrying...")

    print(f"[sync] {label}: gave up after {attempts} attempts (continuing startup)")

if __name__ == "__main__":
    sync("S3_MODELS_URI",       "MODEL_DIR",        "models")
    sync("S3_CUSTOM_NODES_URI", "CUSTOM_NODES_DIR", "custom_nodes")
    sync("S3_WORKFLOWS_URI",    "WORKFLOW_DIR",     "workflows")
