#!/usr/bin/env bash
# Launch the newly packaged AppImage for testing.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

appimage="$(ls -t dist/F-ZERO-GLINUX-*.AppImage 2>/dev/null | head -n1 || true)"
if [[ -z "$appimage" || ! -x "$appimage" ]]; then
    echo "No AppImage found in dist/. Package one with: bash scripts/package-appimage.sh" >&2
    exit 1
fi

echo "=========================================="
echo " Launching F-ZERO GLINUX AppImage"
echo " Image: $appimage"
echo "=========================================="

profile="$root/build/visual-user"
if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
    profile="$1"
    shift
fi
echo "User data profile: $profile"
echo

# Export profile and run
export GLINUX_USER_DIR="$profile"

# If FUSE isn't permitted or active, fall back to extract-and-run
if ! "$appimage" --help >/dev/null 2>&1; then
    exec "$appimage" --appimage-extract-and-run "$@"
else
    exec "$appimage" "$@"
fi
