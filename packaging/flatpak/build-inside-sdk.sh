#!/usr/bin/env bash
set -euo pipefail
# All compilers, headers and libraries below come from the SDK or vendored source.
protocols="$PWD/ModernGekko/vendor/dolphin/Externals/SDL/SDL/wayland-protocols"
cmake -S ModernGekko -B _build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/app \
    '-DCMAKE_C_FLAGS=-march=x86-64 -mtune=generic' \
    '-DCMAKE_CXX_FLAGS=-march=x86-64 -mtune=generic' \
    -DBUILD_TESTING=OFF -DDOLRECOMP_ENABLE_LLVM=OFF \
    -DUSE_SYSTEM_LIBS=OFF -DUSE_SYSTEM_Iconv=ON \
    '-DMODERNGEKKO_FRONTEND_NAME=F-ZERO GLINUX' \
    '-DMODERNGEKKO_DEFAULT_WINDOW_TITLE=F-ZERO GLINUX' \
    -DMODERNGEKKO_USER_DIRECTORY_NAME=fzero-glinux \
    -DMODERNGEKKO_REQUIRED_DISC_ID=GFZE01 \
    -DMODERNGEKKO_GAMECUBE_CONTROLLERS=ON \
    "-DMODERNGEKKO_XDG_SHELL_XML=$protocols/xdg-shell.xml" \
    "-DMODERNGEKKO_XDG_DECORATION_XML=$protocols/xdg-decoration-unstable-v1.xml" \
    "-DMODERNGEKKO_IDLE_INHIBIT_XML=$protocols/idle-inhibit-unstable-v1.xml"
cmake --build _build --target moderngekko-launcher --parallel "${FLATPAK_BUILDER_N_JOBS:-4}"
install -Dm755 _build/ModernGekko /app/bin/ModernGekko
install -Dm755 _build/moderngekko-run /app/bin/moderngekko-run
cp -a _build/Sys /app/bin/Sys
cp -a assets/launcher /app/bin/Assets
install -Dm755 flatpak/fzero-glinux /app/bin/fzero-glinux
install -Dm644 flatpak/io.github.mabecgames.FZeroGLinux.desktop /app/share/applications/io.github.mabecgames.FZeroGLinux.desktop
install -Dm644 fzero-glinux.svg /app/share/icons/hicolor/scalable/apps/io.github.mabecgames.FZeroGLinux.svg
install -Dm644 ModernGekko/LICENSE /app/share/licenses/fzero-glinux/ModernGekko.txt
install -Dm644 ModernGekko/vendor/dolphin/COPYING /app/share/licenses/fzero-glinux/Dolphin.txt
# Fail packaging if a newly introduced shared dependency cannot resolve in SDK.
for binary in /app/bin/ModernGekko /app/bin/moderngekko-run; do
    deps="$(ldd "$binary")"
    printf '%s\n' "$deps"
    if [[ "$deps" == *'not found'* ]]; then exit 1; fi
done
