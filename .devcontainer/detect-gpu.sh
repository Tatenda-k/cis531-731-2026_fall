#!/usr/bin/env bash
# Detects whether an NVIDIA GPU is usable on the host (or via the Docker
# runtime) and writes the base-image build args docker-compose should use.
# Run automatically by devcontainer.json's initializeCommand, on the host,
# before the container image is built.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

GPU_IMAGE="pytorch/pytorch:2.2.1-cuda12.1-cudnn8-runtime"
CPU_IMAGE="python:3.10-slim-bookworm"

has_gpu=false

if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    has_gpu=true
elif docker info 2>/dev/null | grep -qi "nvidia"; then
    has_gpu=true
fi

if [ "$has_gpu" = true ]; then
    echo "BASE_IMAGE=$GPU_IMAGE" > "$ENV_FILE"
    echo "BASE_TYPE=gpu" >> "$ENV_FILE"
    echo "[detect-gpu] NVIDIA GPU detected -> using $GPU_IMAGE"
else
    echo "BASE_IMAGE=$CPU_IMAGE" > "$ENV_FILE"
    echo "BASE_TYPE=cpu" >> "$ENV_FILE"
    echo "[detect-gpu] No GPU detected -> using $CPU_IMAGE"
fi
