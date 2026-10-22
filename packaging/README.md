# F-ZERO GLINUX AppImage preview

Build from the project directory:

```sh
bash scripts/build-glinux.sh
bash scripts/package-appimage.sh
```

The resulting `dist/F-ZERO-GLINUX-*-x86_64.AppImage` contains the launcher,
runner, shaders, artwork, fonts when available, dependency libraries and notices.
It contains no game image, extracted game, native game module or personal save.
This preview uses Dolphin JIT. Import your own **F-ZERO GX USA (GFZE01)** ISO/RVZ
using the launcher. Other regions are not enabled in this preview.

Run normally by making it executable and opening it. If FUSE is unavailable:

```sh
./F-ZERO-GLINUX-preview-20261022-glibc2.44-x86_64.AppImage --appimage-extract-and-run
```

Saves, configuration and imported files go in
`${XDG_DATA_HOME:-$HOME/.local/share}/fzero-glinux` and survive AppImage updates.
Use `GLINUX_USER_DIR=/absolute/path` or `--user-dir /absolute/path` to choose
another profile. The AppImage never automatically copies the development save.
To deliberately use the existing development profile on this machine:

```sh
GLINUX_USER_DIR="$PWD/build/visual-user" ./dist/F-ZERO-GLINUX-preview-20261022-glibc2.44-x86_64.AppImage
```

That profile already points to this machine's extracted game. New machines must
import their own game. The AppImage does not need this checkout for a fresh import.

## Compatibility status

The project owner has confirmed this AppImage works on the development machine.
This does not expand the ABI/CPU compatibility stated below.

**This local preview is not a general cross-distribution release.** Its ELF audit
requires **glibc 2.44+** and reports **x86-64-v3 (AVX2-class)** requirements.
Arch/CachyOS is the packaging host, not proof of compatibility with every Arch
installation. Debian and Bazzite have not been tested, and any installation with
older glibc cannot run these binaries. The AppRun checks glibc before launching.
View the adjacent `.compatibility.txt` report, or run `--compatibility`.

The AppImage bundles non-base dependencies but uses the host's graphics drivers,
X11/XWayland or Wayland, audio server and controller permissions. The entry point
selects native Wayland only when no DISPLAY exists; `--wayland` / `--x11` overrides
remain available. Controller operation in Steam Deck Gaming Mode and live netplay
still need physical-device testing. The separate quit window needs compositor
focus testing, particularly under Gamescope.

For a wider release, rebuild the **whole executable and dependency set** inside
an older baseline distribution, with a generic x86-64 CPU target. Repackaging
these CachyOS binaries inside a Debian container would not lower their ABI floor.
The baseline's compiler must also support the project's C++23 requirements.
No container runtime or network downloads were available in this build session,
so no Debian/Bazzite build or boot test is claimed.

Before declaring support, test on each target distro:

1. Launch with FUSE and with `--appimage-extract-and-run`.
2. Import an ISO/RVZ into a new profile and boot without the development checkout.
3. Complete a race with Vulkan, audio, USB gamepad, X/Y swap and selected resolution.
4. Test Escape, D-pad/A/B quit confirmation in windowed/fullscreen modes.
5. Close and reopen; confirm settings and memory-card data persist.
6. On Bazzite/Steam Deck, repeat in Desktop Mode and Gaming Mode.

References: [AppImage build compatibility guidance](https://docs.appimage.org/reference/best-practices.html)
and [FUSE fallback documentation](https://docs.appimage.org/user-guide/troubleshooting/fuse.html).

## Reproducibility and packaging details

`linuxdeploy` deploys libraries before `audit-appdir.py` records actual GLIBC
requirements from each ELF's version-needs table and CPU property notes. The
output includes a SHA-256 checksum, compatibility report and source-revision /
license notices. `GLINUX_BUILD_DIR` selects a separately built binary directory;
`GLINUX_VERSION` sets the output version. `GLINUX_APPIMAGE_RUNTIME` can select a
pinned type-2 runtime. By default the script reuses the installed linuxdeploy
AppImage runtime, which allows packaging without downloading another runtime.

The older workspace-level `tools/package-appimage.sh` is only a staging scaffold.
Use this project's `scripts/package-appimage.sh` for the working packaging path.
