#!/usr/bin/env bash
# First visual test of the existing build, with isolated saves and logs.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
runner="$root/lib/ModernGekko/build/moderngekko-run"
cpu_mode="${GLINUX_CPU:-native}"
case "$cpu_mode" in
    native) export MODERNGEKKO_STATICRECOMP=1 ;;
    jit) export MODERNGEKKO_STATICRECOMP=0 ;;
    *) echo "GLINUX_CPU must be native or jit." >&2; exit 2 ;;
esac
active="$root/build/modules/GFZE01/active-module.txt"
if [[ ! -x "$runner" || ! -f "$active" ]]; then
    echo "Build the runtime and game module before running this test." >&2
    exit 1
fi
module="$(cat "$active")"
if [[ ! -f "$module" ]]; then
    echo "Native module not found: $module" >&2
    exit 1
fi
user_dir="$root/build/visual-user"
mkdir -p "$user_dir" "$root/build/logs"
if [[ ! -f "$user_dir/config.ini" ]]; then
    cat > "$user_dir/config.ini" <<'CONFIG'
[Video]
resolution=640x528
backend=Vulkan
fullscreen=false
show_fps_in_title=true
[Input]
CONFIG
fi
log="$root/build/logs/visual-$cpu_mode-$(date +%Y%m%d-%H%M%S)-$$.log"
if [[ "${GLINUX_PROFILE:-0}" == 1 ]]; then
    export STATICRECOMP_DISPATCH_SAMPLES=1
    export STATICRECOMP_TRACE_FILE="${log%.log}-dispatch.csv"
    echo "Native dispatch/fallback sampling enabled."
fi
echo "F-ZERO GLINUX — first visual test"
echo "CPU mode: $cpu_mode"
if [[ "$cpu_mode" == jit ]]; then
    echo "Diagnostic Dolphin JIT comparison; this is not recompiled CPU execution."
fi
echo "Log: $log"
echo "Test saves/config: $user_dir"
echo "Close the game window or press Ctrl+C here to stop."
"$runner" --game "$root/extracted/GFZE01" --module "$module" \
    --user-dir "$user_dir" --no-mods "$@" 2>&1 | (trap '' INT; exec tee "$log")
