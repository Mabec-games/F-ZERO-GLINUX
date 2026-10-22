#!/usr/bin/env bash
# Package the built JIT preview, without game images, modules or personal saves.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
build="${GLINUX_BUILD_DIR:-$root/lib/ModernGekko/build}"
deploy="$(command -v "${LINUXDEPLOY:-linuxdeploy}")"
for name in ModernGekko moderngekko-run; do
    [[ -x "$build/$name" ]] || { echo "Build first: bash scripts/build-glinux.sh" >&2; exit 1; }
done
mkdir -p "$root/build" "$root/dist"
work="$(mktemp -d "$root/build/appimage.XXXXXX")"
appdir="$work/AppDir"
mkdir -p "$appdir/usr/bin" "$appdir/usr/share/fzero-glinux" "$appdir/usr/share/licenses/fzero-glinux"
cp "$build/ModernGekko" "$build/moderngekko-run" "$appdir/usr/bin/"
cp -a "$build/Sys" "$appdir/usr/bin/Sys"
cp -a "$root/assets/launcher" "$appdir/usr/bin/Assets"
cp "$root/lib/ModernGekko/LICENSE" "$appdir/usr/share/licenses/fzero-glinux/ModernGekko.txt"
cp "$root/lib/ModernGekko/vendor/dolphin/COPYING" "$appdir/usr/share/licenses/fzero-glinux/Dolphin.txt"
if [[ -f /usr/share/fonts/noto/NotoSans-Regular.ttf && -f /usr/share/licenses/noto-fonts/LICENSE ]]; then
    cp /usr/share/fonts/noto/NotoSans-Regular.ttf "$appdir/usr/bin/Assets/"
    cp /usr/share/licenses/noto-fonts/LICENSE "$appdir/usr/share/licenses/fzero-glinux/NotoSans.txt"
fi
export APPIMAGE_EXTRACT_AND_RUN=1
# Deploy first, then audit the complete library set before creating the image.
"$deploy" --appdir "$appdir" \
    --executable "$appdir/usr/bin/ModernGekko" --executable "$appdir/usr/bin/moderngekko-run" \
    --desktop-file "$root/packaging/fzero-glinux.desktop" \
    --icon-file "$root/packaging/fzero-glinux.svg" --custom-apprun "$root/packaging/AppRun"
python3 "$root/scripts/collect-appimage-licenses.py" "$root" "$appdir"
python3 "$root/scripts/audit-appdir.py" "$appdir"
minimum="$(cat "$appdir/usr/share/fzero-glinux/minimum-glibc")"
version="${GLINUX_VERSION:-preview-$(date +%Y%m%d)}"
export LDAI_OUTPUT="${GLINUX_APPIMAGE_OUTPUT:-$root/dist/F-ZERO-GLINUX-$version-glibc$minimum-x86_64.AppImage}"
export LINUXDEPLOY_OUTPUT_VERSION="$version"
# Reuse the installed linuxdeploy AppImage runtime for offline packaging.
# A release builder may supply a separately pinned runtime instead.
if [[ -n "${GLINUX_APPIMAGE_RUNTIME:-}" ]]; then
    export LDAI_RUNTIME_FILE="$(realpath "$GLINUX_APPIMAGE_RUNTIME")"
else
    offset="$("$deploy" --appimage-offset)"
    [[ "$offset" =~ ^[0-9]+$ ]] || { echo "Set GLINUX_APPIMAGE_RUNTIME to a type-2 runtime." >&2; exit 1; }
    dd if="$deploy" of="$work/runtime-x86_64" bs=1 count="$offset" status=none
    export LDAI_RUNTIME_FILE="$work/runtime-x86_64"
fi
"$deploy" --appdir "$appdir" --custom-apprun "$root/packaging/AppRun" --output appimage
cp "$appdir/usr/share/fzero-glinux/COMPATIBILITY.txt" "$LDAI_OUTPUT.compatibility.txt"
(cd "$root/dist" && sha256sum "$(basename "$LDAI_OUTPUT")" > "$(basename "$LDAI_OUTPUT").sha256")
printf '%s\n' "$appdir" > "$root/build/latest-appdir.txt"
printf 'AppImage: %s\nStaging: %s\n' "$LDAI_OUTPUT" "$appdir"
