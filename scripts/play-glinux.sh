#!/usr/bin/env bash
# Early launcher with controller selection and the existing test saves.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
launcher="$root/lib/ModernGekko/build/ModernGekko"
active="$root/build/modules/GFZE01/active-module.txt"
if [[ ! -x "$launcher" || ! -f "$active" ]]; then
    echo "Build the launcher and game module first: bash scripts/build-glinux.sh" >&2
    exit 1
fi
module="$(cat "$active")"
if [[ ! -f "$module" ]]; then
    echo "Native module not found: $module" >&2
    exit 1
fi
export STATICRECOMP_MODULE="$(realpath "$module")"
case "${GLINUX_CPU:-jit}" in
    jit) export MODERNGEKKO_STATICRECOMP=0 ;;
    native) export MODERNGEKKO_STATICRECOMP=1 ;;
    *) echo "GLINUX_CPU must be jit or native." >&2; exit 2 ;;
esac
user_dir="${GLINUX_USER_DIR:-$root/build/visual-user}"
mkdir -p "$user_dir"
printf '%s\n' "$root/extracted/GFZE01" > "$user_dir/default-game.txt"
echo "F-ZERO GLINUX launcher — CPU: ${GLINUX_CPU:-jit}"
echo "Select your USB gamepad under Controller, then click Play."
echo "Game logs: $user_dir/Logs/"
exec "$launcher" --user-dir "$user_dir" "$@"
