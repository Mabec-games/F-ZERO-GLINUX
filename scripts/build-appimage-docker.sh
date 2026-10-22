#!/usr/bin/env bash
# Build the portable cross-distribution AppImage locally inside an Ubuntu 22.04 container.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

container_engine=""
if command -v podman >/dev/null 2>&1; then
    container_engine="podman"
elif command -v docker >/dev/null 2>&1; then
    container_engine="docker"
else
    echo "Error: Neither podman nor docker found. Install Docker or push to GitHub to use GitHub Actions." >&2
    exit 1
fi

echo "Using container engine: $container_engine"
echo "Building portable Ubuntu 22.04 AppImage..."

$container_engine run --rm -it \
    -v "$root":/workspace \
    -w /workspace \
    ubuntu:22.04 bash -c '
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y software-properties-common curl git
add-apt-repository -y ppa:ubuntu-toolchain-r/test
apt-get update
apt-get install -y \
    gcc-13 g++-13 ninja-build cmake pkg-config \
    libgl1-mesa-dev libvulkan-dev libasound2-dev libpulse-dev libudev-dev libevdev-dev libsystemd-dev \
    libx11-dev libxext-dev libxrandr-dev libxi-dev libwayland-dev wayland-protocols libxkbcommon-dev \
    libcurl4-openssl-dev libbluetooth-dev libenet-dev libhidapi-dev \
    liblz4-dev libzstd-dev zlib1g-dev libfmt-dev libxxhash-dev \
    libbz2-dev libusb-1.0-0-dev libpugixml-dev fonts-noto-core libfuse2 file

export CC=gcc-13
export CXX=g++-13
export JOBS=$(nproc)
export GLINUX_CMAKE_ARGS="-DCMAKE_C_FLAGS=-march=x86-64 -DCMAKE_CXX_FLAGS=-march=x86-64"

bash scripts/build-glinux.sh

curl -sLO https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
chmod +x linuxdeploy-x86_64.AppImage
export LINUXDEPLOY="$(realpath linuxdeploy-x86_64.AppImage)"

bash scripts/package-appimage.sh
'

echo "Build complete. Artifacts in dist/:"
ls -la "$root/dist"
