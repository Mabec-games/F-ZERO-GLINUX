#!/usr/bin/env bash
# Build the Dolphin-derived runtime with the project's Linux configuration.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

jobs="${JOBS:-4}"
if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
    echo "JOBS must be a positive integer." >&2
    exit 2
fi

runtime_source="$root/lib/ModernGekko/vendor/dolphin"
runtime_patch="$root/patches/dolphin-glinux-performance.patch"
if git -C "$runtime_source" apply --check "$runtime_patch" 2>/dev/null; then
    git -C "$runtime_source" apply "$runtime_patch"
elif ! git -C "$runtime_source" apply --reverse --check "$runtime_patch" 2>/dev/null; then
    echo "Runtime patch conflicts with this checkout; existing changes were preserved." >&2
    exit 1
fi

launcher_source="$root/lib/ModernGekko"
launcher_patch="$root/patches/moderngekko-glinux-launcher.patch"
if git -C "$launcher_source" apply --check "$launcher_patch" 2>/dev/null; then
    git -C "$launcher_source" apply "$launcher_patch"
elif ! git -C "$launcher_source" apply --reverse --check "$launcher_patch" 2>/dev/null; then
    echo "Launcher patch conflicts with this checkout; existing changes were preserved." >&2
    exit 1
fi

protocols="$root/lib/ModernGekko/vendor/dolphin/Externals/SDL/SDL/wayland-protocols"
protocol_args=(
    "-DMODERNGEKKO_XDG_SHELL_XML=$protocols/xdg-shell.xml"
    "-DMODERNGEKKO_XDG_DECORATION_XML=$protocols/xdg-decoration-unstable-v1.xml"
    "-DMODERNGEKKO_IDLE_INHIBIT_XML=$protocols/idle-inhibit-unstable-v1.xml"
)

cmake -S lib/ModernGekko -B lib/ModernGekko/build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF \
    -DDOLRECOMP_ENABLE_LLVM=OFF \
    "-DMODERNGEKKO_FRONTEND_NAME=F-ZERO GLINUX" \
    "-DMODERNGEKKO_DEFAULT_WINDOW_TITLE=F-ZERO GLINUX" \
    -DMODERNGEKKO_USER_DIRECTORY_NAME=fzero-glinux \
    -DMODERNGEKKO_GAMECUBE_CONTROLLERS=ON \
    -DMODERNGEKKO_REQUIRED_DISC_ID="GFZE01,GFZP01" \
    ${GLINUX_CMAKE_ARGS:-} \
    "${protocol_args[@]}"
cmake --build lib/ModernGekko/build --target moderngekko-port moderngekko-launcher -j"$jobs"

mkdir -p lib/ModernGekko/build/Assets
cp assets/launcher/*.png lib/ModernGekko/build/Assets/
