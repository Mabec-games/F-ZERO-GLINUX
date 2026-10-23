#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$(uname -m)" == x86_64 ]] || { echo "This recipe currently targets x86_64 only." >&2; exit 2; }
mode="${1:-build}"
case "$mode" in build|--prepare-only) ;; *) echo "Usage: $0 [--prepare-only]" >&2; exit 2 ;; esac
for tool in flatpak flatpak-builder python3 git; do
    command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 1; }
done
jobs="${JOBS:-4}"
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || { echo "JOBS must be positive." >&2; exit 2; }
if [[ "$mode" != --prepare-only ]]; then
    for ref in org.freedesktop.Sdk//26.08 org.freedesktop.Platform//26.08; do
        if ! flatpak info "$ref" >/dev/null 2>&1; then
            echo "Missing $ref. Install the matching SDK/runtime first:" >&2
            echo "flatpak install --user flathub org.freedesktop.Sdk//26.08 org.freedesktop.Platform//26.08" >&2
            exit 1
        fi
    done
    # Detect nested-sandbox restrictions before copying sources or compiling.
    flatpak run --command=true org.freedesktop.Sdk//26.08
fi
manifest="$(python3 "$root/scripts/prepare-flatpak.py")"
flatpak-builder --show-manifest "$manifest" >/dev/null
if [[ "$mode" == --prepare-only ]]; then
    echo "Prepared and parsed: $manifest"
    exit 0
fi
mkdir -p "$root/dist"
output="${GLINUX_FLATPAK_OUTPUT:-$root/dist/F-ZERO-GLINUX-x86_64.flatpak}"
flatpak-builder --user --force-clean --disable-rofiles-fuse --jobs="$jobs" \
    --state-dir="$root/build/flatpak/state" --repo="$root/build/flatpak/repo" \
    "$root/build/flatpak/app" "$manifest" 2>&1 | tee "$root/build/flatpak/build.log"
# Verify startup against Platform, not merely the larger SDK library set.
flatpak build --runtime "$root/build/flatpak/app" /app/bin/ModernGekko --help
flatpak build --runtime "$root/build/flatpak/app" /app/bin/moderngekko-run --help
flatpak build-bundle "$root/build/flatpak/repo" \
    "$output" io.github.mabecgames.FZeroGLinux \
    --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo
printf 'Built: %s\nInstall: flatpak install --user %q\nRun: flatpak run io.github.mabecgames.FZeroGLinux\n' \
    "$output" "$output"
