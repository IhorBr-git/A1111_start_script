#!/bin/bash

# -- Installation & Start Script ---
# Base image: runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04
# This script installs and launches AUTOMATIC1111 Stable Diffusion WebUI
# on RunPod with no additional extensions or modifications.
# Follows official A1111 Linux installation instructions.

set -e

WEBUI_DIR="/workspace/stable-diffusion-webui"

# ---- Install system dependencies (Debian-based) ----
echo "Installing system dependencies..."
apt-get update && apt-get install -y --no-install-recommends \
    wget git python3 python3-venv libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# ---- Clone A1111 (skip if already present for pod restarts) ----
if [ ! -d "$WEBUI_DIR" ]; then
    echo "Cloning AUTOMATIC1111 Stable Diffusion WebUI..."
    git clone -b dev https://github.com/AUTOMATIC1111/stable-diffusion-webui.git "$WEBUI_DIR"
else
    echo "WebUI already exists, pulling latest changes..."
    cd "$WEBUI_DIR" && git pull
fi

# ---- Configure webui-user.sh ----
# python_cmd set to python3.11 as per A1111 docs for newer systems
echo "Configuring webui-user.sh..."
cat > "$WEBUI_DIR/webui-user.sh" << 'EOF'
#!/bin/bash
python_cmd="python3.11"
# Stability-AI repos were made private (Dec 2025) — use community mirrors
export STABLE_DIFFUSION_REPO="https://github.com/w-e-w/stablediffusion.git"
export COMMANDLINE_ARGS="--listen --port 3000 --xformers --enable-insecure-extension-access --no-half-vae --api"
EOF

# ---- Pre-create venv and fix Python 3.11 build dependencies ----
echo "Setting up Python venv..."
if [ ! -d "$WEBUI_DIR/venv" ]; then
    python3.11 -m venv "$WEBUI_DIR/venv"
fi
echo "Installing build dependencies in venv..."
"$WEBUI_DIR/venv/bin/pip" install --upgrade pip wheel
# Pin setuptools to 69.5.1 — newer versions break pkg_resources imports needed by CLIP
"$WEBUI_DIR/venv/bin/pip" install "setuptools==69.5.1"
# Pre-install CLIP without build isolation to use the venv's setuptools
echo "Pre-installing CLIP..."
"$WEBUI_DIR/venv/bin/pip" install --no-build-isolation https://github.com/openai/CLIP/archive/d50d76daa670286dd6cacf3bcd80b5e4823fc8e1.zip

# ---- Clean up ----
echo "Cleaning up..."
rm -f /workspace/install_script.sh

# ---- Start services ----
echo "Starting RunPod handler and A1111 WebUI..."
/start.sh &
cd "$WEBUI_DIR" && bash webui.sh -f
