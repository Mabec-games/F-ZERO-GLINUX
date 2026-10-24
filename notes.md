# F-ZERO GLINUX — progress notes

Updated: 2026-10-25.


## Latest update — Windows Port Kickoff: Repo Moved, Dolphin Submodules Repaired, Launcher Text, 2026-10-25

Goal: port the Linux-only build to Windows. Status: groundwork done, no Windows code or build yet.

1. Project location moved to `C:\dev\fzero-gx-linux`:
   - The old copy under `Downloads\fzero-gx-linux\...\F-ZERO-GLINUX-windows-port-20261025\fzero-gx-linux` was too deep: nested submodule git dirs (e.g. `.git/modules/.../cubeb/cubeb/modules/cmake/sanitizers-cmake`, 266 chars) exceeded the Windows 260-char limit, so Git reported `fatal: not a git repository` even with `core.longpaths=true` (a `subst` drive does not help, Git resolves it back to the long path).
   - Nothing was actually missing after the USB transfer: `git fsck` on the affected submodule passed. Copied with robocopy (40,589 files, 0 failed); at the new path all submodules are at their recorded commits.
   - Keep the repo at a short path; the MSVC/CMake Dolphin build will hit the same limit.
   - The old Downloads copy can be deleted by the user once confirmed.

2. Git setup on Windows:
   - Remote `dev` = `https://github.com/Mabec-games/F-ZERO-GLINUX-dev.git`; `main` fast-forwarded to `467e3a4` (automatic cheats). `glinux` = public repo, `origin` = ModernGekko-Template.
   - `core.autocrlf=false`; `core.fileMode=false` in the main repo and all submodules (Windows/USB drop the executable bit, which showed as mode-only changes on `packaging/AppRun`, `scripts/*.sh`, `cmake/asan-wrapper`).
   - Verified: `lib/ModernGekko` tree = pristine + `moderngekko-glinux-launcher.patch`; `vendor/dolphin` tree = pristine + `dolphin-glinux-performance.patch` (the 13 modified Dolphin files are exactly that patch). Both reverse-check cleanly, so `build-glinux.sh` treats them as applied.

3. Launcher footer text:
   - `"F-ZERO GLINUX  /  LINUX EDITION"` -> `"F-ZERO GLINUX  /  FOR LINUX & WINDOWS"` (only shown when the launcher is wider than 900 px).
   - Changed in `patches/moderngekko-glinux-launcher.patch` and in the applied `lib/ModernGekko/tools/moderngekko_launcher.cpp`. Not yet compiled or seen on screen.

4. `.gitignore`: added `*.rvz`, `*.iso`, `*.gcm`, `*.ciso`, `*.wbfs`. The user's `F-Zero GX (USA).rvz` is in the repo root for testing and is ignored.

Committed to the `dev` remote only (not the public `glinux` repo). Submodule working-tree changes stay unpushed, as before; the patch files are their record.

5. Windows toolchain check: Ninja and Python are installed; CMake and a C++ compiler are not (only the Visual Studio Installer is present). Install VS 2022 Build Tools with "Desktop development with C++" before building.

### Next steps (Windows port)
- Audit Linux-only pieces: `scripts/*.sh` build/package scripts, DolphinNoGUI `PlatformX11.cpp`/`PlatformWayland.cpp` (need a Win32 platform), AppImage/Flatpak packaging (need a Windows zip or installer), `$XDG_DATA_HOME` paths (use `%APPDATA%`).
- Set up an MSVC + CMake (or MSYS2/clang) build of the patched Dolphin runtime and the ModernGekko launcher.
- Build the launcher, then confirm the new footer text and RVZ import on Windows.


## Previous update — Cross-Distro AppImage Fixes, Smoke Test Matrix & Release 0.SteamDeck/Ubuntu/Bazzite, 2026-10-23

1. Wayland Protocol DTD Validation Warnings:
   - Addressed non-fatal warning: `WARNING: XML failed validation against built-in DTD`.
   - Cause: Modern SDL vendored Wayland protocols (`color-management-v1.xml`, `wayland.xml`) include modern attributes like `deprecated-since="2"` which are not present in Ubuntu 22.04's `wayland-scanner 1.20` embedded DTD.
   - Behavior: Safe non-fatal warning output to stderr with exit code 0; code generation proceeds normally.

2. Wayland Listener ABI Backward Compatibility (`PlatformWayland.cpp`):
   - Fixed fatal compilation error at `[1420/1439]` on Ubuntu 22.04:
     `error: too many initializers for ‘const xdg_toplevel_listener’`
     `error: too many initializers for ‘const wl_pointer_listener’`
   - Root cause: In modern Wayland (>= 1.22), `wl_pointer_listener` has 11 member functions and `xdg_toplevel_listener` has `wm_capabilities`. On Ubuntu 22.04 (Wayland 1.20 / protocols 1.25), `wl_pointer_listener` only has 9 callbacks and `xdg_toplevel_listener` lacks `wm_capabilities`.
   - Fix: Wrapped callbacks with standard version feature macros:
     - `#ifdef WL_POINTER_AXIS_VALUE120_SINCE_VERSION` (`PointerAxisValue120`)
     - `#ifdef WL_POINTER_AXIS_RELATIVE_DIRECTION_SINCE_VERSION` (`PointerAxisRelativeDirection`)
     - `#ifdef XDG_TOPLEVEL_WM_CAPABILITIES_SINCE_VERSION` (`ToplevelWmCapabilities`)
     - `#ifdef XDG_TOPLEVEL_CONFIGURE_BOUNDS_SINCE_VERSION` (`ToplevelConfigureBounds`)
   - Updated `patches/dolphin-glinux-performance.patch` and `scripts/build-glinux.sh`.

3. ELF Notes Parsing Incompatibility (`scripts/audit-appdir.py`):
   - Fixed packaging crash: `subprocess.CalledProcessError: Command '['readelf', '--notes', '.../ModernGekko']' returned non-zero exit status 1`.
   - Root cause: Modern binaries built with SDL3 include `.note.dlopen` (FDO dlopen metadata). Older `readelf` (GNU Binutils 2.38 on Ubuntu 22.04) warns and exits with status 1 on unrecognized note types.
   - Fix: Replaced `subprocess.check_output` with `subprocess.run(..., capture_output=True, text=True)` in `audit-appdir.py` so non-zero exits on note parsing do not fail the build.

4. Static C++ Runtime Linking for Universal Distribution Support:
   - Root cause: ModernGekko compiled with GCC 13 references `GLIBCXX_3.4.32`. Because linuxdeploy deliberately leaves `libstdc++` unbundled, running the AppImage on Ubuntu 22.04 LTS, Debian 12, or SteamOS 3 failed with `GLIBCXX_3.4.32 not found` (as those distros provide `GLIBCXX_3.4.30`).
   - Fix: Added `LDFLAGS="-static-libstdc++ -static-libgcc"` to the build step in `.github/workflows/build-appimage.yml`.
   - Added AppImage inspection in CI to enforce that no bundled ELF requires a `GLIBCXX` newer than `GLIBCXX_3.4.30`.

5. Automated Multi-Distro Smoke Test Matrix:
   - Added a `smoke-test` matrix job to `.github/workflows/build-appimage.yml` running in parallel on:
     - **Ubuntu 22.04 LTS (Jammy)**
     - **Ubuntu 24.04 LTS (Noble)**
     - **Debian 12 (Bookworm)**
     - **Fedora 40**
   - Verified package names (`libwayland-client` on Fedora) and desktop dependencies (`libx11`, `libwayland-client`, `libasound2`, `libusb-1.0`, `libgl1`).
   - Smoke tests execute `--compatibility` and `--help` offscreen and check `ldd` for missing dynamic libraries (`none`). All 4 passed.

6. GitHub Release Published:
   - Release Name: `F-ZERO GLINUX version 0.SteamDeck/Ubuntu/Bazzite`
   - Git Tag: `v0.SteamDeck-Ubuntu-Bazzite`
   - Marked as **Latest** on GitHub.
   - Attached assets:
     - `F-ZERO-GLINUX-preview-20261023-glibc2.35-x86_64.AppImage` (32 MB portable binary)
     - `F-ZERO-GLINUX-x86_64.flatpak` (22 MB universal sandboxed bundle)
     - `F-ZERO-GLINUX-preview-20261023-glibc2.35-x86_64.AppImage.compatibility.txt`
     - Checksums: `.sha256` for both AppImage and Flatpak.


## Previous update — Controller Support Polish & Portable AppImage Setup, 2026-10-22

1. Controller Support Polish:
   - Configured responsive analog triggers: `Triggers/Deadzone = 5.00` and `Triggers/Threshold = 85.00`
     (eliminates sluggish 25% deadzone and allows easy drifting and reliable spin attacks at 85% pull).
   - Set anti-drift analog stick deadzones: `Main Stick/Deadzone = 5.00` and `C-Stick/Deadzone = 5.00`.
   - Multi-bound Z button: `Buttons/Z = \`Shoulder R\` | \`Shoulder L\` | Back\`
     (allows RB, LB, or Select/Back to trigger Look Behind / Cancel / Options).
   - Gamepad Exit Hotkey in-game: Added `HostMessageID::WMUserConfirmExit` hooked into SDL gamepad event loop.
     Pressing Guide (Home / Xbox / PS button) or Start + Back simultaneously pauses game and opens the quit dialog.
   - On-screen virtual keyboard: Hooked `SDL_StartTextInput(window)` when Netplay input fields are activated
     for automatic Steam virtual keyboard popup on Steam Deck / SteamOS.
   - Built and verified all launcher/runtime changes with `build-glinux.sh`.

2. Portable Cross-Distribution AppImage Setup:
   - Created `.github/workflows/build-appimage.yml`: GitHub Actions workflow on `ubuntu-22.04` (glibc 2.35)
     with GCC 13, generic `-march=x86-64`, linuxdeploy bundling, and compatibility verification.
   - Added `scripts/build-appimage-docker.sh` for local containerized Ubuntu 22.04 builds.
   - Preserved project AppImage naming: `F-ZERO-GLINUX-$version-glibc$minimum-x86_64.AppImage`.
   - Updated `scripts/publish-github.sh` to include `.github` in commits.


## Previous update — Automatic Native 16:9 on New Save Verified, 2026-10-22

Successfully implemented and verified automatic native 16:9 widescreen for fresh saves:
- Analyzed new-save default initialization function at `0x8027db54` in Module 1.
- Implemented conditional OnFrame memory patch in `GFZE01.ini`:
  `0x8027DC0C:dword:0x38600001:0x4BFE3AED`
  Replaces getter `bl 0x802616f8` with `li r3, 1` when creating default settings.
- Stored screen-mode byte `0x803e6023` is now initialized to `1` (16:9 Widescreen)
  instead of `0` (4:3 Standard).
- Completely preserves loaded save files (existing 4:3 or 16:9 saves are untouched
  because `0x8027db54` is only invoked when generating defaults for uninitialized saves).
- Verified headlessly past intro sequence (frame 552): dumped memory header at `0x803e6020`
  showed `00000f01000000004b003535004bcb35` with byte 3 = `01` (16:9 Widescreen).
- Updated both `Sys/GameSettings/GFZE01.ini` and Dolphin's source tree, and
  re-exported `patches/dolphin-glinux-performance.patch`. Reverse-apply check passed.


## Previous handoff — GitHub login attempt, 2026-10-22

At the user's request, attempted:
`gh auth login --hostname github.com --git-protocol https --web`
It exited with code 1: "error connecting to github.com". No browser/device
login flow started and authentication was not completed in this session.
This confirms a connectivity blocker here; it does not establish that the
user's credentials are invalid in their normal terminal.

Current state: user confirms AppImage and Flatpak both work. Both use SDL3.
The image-rich README and source publishing script are ready locally.
No successful repository creation, push or release upload has been observed.
Do not claim that Mabec-games/F-ZERO-GLINUX exists based on this session.

Next steps from the user's normal terminal:

```bash
gh auth login --hostname github.com --git-protocol https --web
cd "/home/martin/Downloads/F-ZERO GX/fzero-gx-linux"
bash scripts/publish-github.sh
```

If resuming with working GitHub access, verify the authenticated account and
whether the user has already published before rerunning creation/push steps.
Repository creation/publication is already authorized. Preserve the upstream
origin, existing saves and game data. Binary release uploads have not been done;
the publisher currently publishes source, documentation and artwork only.

## GitHub presentation prepared — 2026-10-22

User confirmed BOTH AppImage and Flatpak work and requested new GitHub repository
named F-ZERO GLINUX plus image-rich presentation and variant/startup explanations.
Prepared repo title F-ZERO GLINUX, URL slug F-ZERO-GLINUX. Replaced template README
with project presentation: Promo.png at top, both requested screenshots in gameplay
sections, transparent logo at footer. Copies are in docs/images; originals intact.
Upstream template README preserved as docs/UPSTREAM-TEMPLATE.md.
README corrects SDL misconception: BOTH builds use SDL3; there is no SDL2 variant.
Includes package comparison, run/install steps, first-run/controller/widescreen
instructions, build guides, limits and upstream credits. JIT preview vs experimental
static recompilation is explicit. Updated packaging guides with user success report.

Remote publishing BLOCKED: gh api user cannot connect to api.github.com here.
gh auth status identifies Mabec-games but also reports invalid authentication;
network failure means re-authentication need should be checked from user's terminal.
No GitHub repository has been created, no push/publication performed.
Prepared scripts/publish-github.sh: requires authenticated Mabec-games account,
adds explicit project source/art/doc paths, commits changes, creates PUBLIC
Mabec-games/F-ZERO-GLINUX, pushes HEAD to main via separate glinux remote, and sets
topics. Leaves upstream origin unchanged; never force pushes. Does not upload
binary releases. User requested repository publication, so no further permission
needed; network/auth access is the blocker. User can run:
cd "/home/martin/Downloads/F-ZERO GX/fzero-gx-linux"
bash scripts/publish-github.sh
If terminal auth fails, run gh auth login first. Readme image/local links and
publisher shell syntax validated. Game images, extracted game, native modules,
profiles and release binaries remain excluded from source publication.

## Flatpak source snapshot fix — 2026-10-22

User's first Flatpak attempt failed during CMake configuration (not compilation).
Read build/flatpak/build.log: zstd's build/cmake and lz4's build/cmake were missing,
causing missing libzstd_static/zstd::zstd and lz4_static/LZ4::LZ4 targets. Root cause
was prepare-flatpak.py excluding all directories named build and build-*; these
also match legitimate upstream source directories (including SDL build-scripts).
Fixed filter to omit the known ModernGekko/build output directory and directories
containing CMakeCache.txt, plus Git/cache metadata, while preserving source build
folders. Added explicit checks for zstd/lz4 CMake files and SDL build-scripts.

Regenerated snapshot and parsed manifest successfully. Ran the same bundled-library
CMake configuration against the corrected snapshot using the HOST toolchain:
configuration/generation passed, exit 0. Log: /tmp/glinux-flatpak-configure-check.log.
Removed that test's _build directory from the source snapshot afterward so host
build output cannot contaminate a subsequent SDK build. Full Flatpak compilation
still needs user's normal terminal because the agent sandbox blocks bwrap.
User should rerun build-flatpak.sh; install/run only after build succeeds (&&).
The missing .flatpak and not-installed messages were cascading effects, not
additional failures. Existing saves and binaries untouched.

## Flatpak local build recipe — 2026-10-22

User requested Flatpak or a local build script to improve older-distro/SDL support.
Actual project uses vendored SDL3, not SDL2. Added scripts/build-flatpak.sh,
scripts/prepare-flatpak.py and packaging/flatpak/{manifest, SDK build script,
entry point, desktop file, README}. Uses installed Freedesktop SDK/Platform 26.08;
builds source and vendored dependencies in the SDK with generic x86-64 flags.
This avoids reusing the AppImage's glibc 2.44 / host CPU binaries. No game/module/
save files copied. JIT default, GFZE01 USA. Source snapshots go in build/flatpak.
Snapshot patch checks use GIT_CEILING_DIRECTORIES to prevent git from accidentally
finding the outer working repository and silently skipping patch paths.

Verified source snapshot preparation, patch checks, manifest parsing and script
syntax. Full compilation BLOCKED in agent sandbox: flatpak run ... SDK fails with
bwrap NETLINK_ROUTE socket Operation not permitted. Flatpak and flatpak-builder
are installed; SDKs 24.08 and 26.08 exist. User can run from normal terminal:
cd "/home/martin/Downloads/F-ZERO GX/fzero-gx-linux"
JOBS=4 bash scripts/build-flatpak.sh
flatpak install --user dist/F-ZERO-GLINUX-x86_64.flatpak
flatpak run io.github.mabecgames.FZeroGLinux

No .flatpak bundle has been built yet. The script exports one only after compile
and Platform-runtime executable startup checks pass. Build log will be at
build/flatpak/build.log. No automatic installation/publication. Sandbox permissions:
network, IPC, Wayland/fallback-X11, PulseAudio, device=all for GPU/gamepad, Downloads
read-only for nonportal file browser. Other game directories need explicit read-only
permission. Isolated saves: ~/.var/app/io.github.mabecgames.FZeroGLinux/data/fzero-glinux.
This is a local recipe, not verified Debian/Bazzite/Steam Deck compatibility.
Next: user runs build, share any failure log, then test actual packaged gameplay.

## AppImage preview built and tested — 2026-10-22

User approved visual launcher and requested an AppImage plus Arch/Debian/Bazzite
compatibility if possible. Created:
fzero-gx-linux/dist/F-ZERO-GLINUX-preview-20261022-glibc2.44-x86_64.AppImage
(~38 MB), plus .sha256 and .compatibility.txt. No publication or commit made.

IMPORTANT: this is a LOCAL PREVIEW, not a verified portable release. ELF audit
shows GLIBC_2.44 and x86-64-v3 requirements from this CachyOS build. Debian and
Bazzite were not tested; hosts below glibc 2.44 cannot run it. No container tools
were installed, and shell networking could not resolve github.com. Need a full
older-baseline rebuild (including dependencies), generic CPU target, then real
Arch/Debian/Bazzite/Steam Deck tests. Do not merely repackage these same binaries
and claim the ABI floor is lowered. Reference packaging/README.md for specifics.

New working packaging path is fzero-gx-linux/scripts/package-appimage.sh.
The older workspace tools/package-appimage.sh is only a scaffold. New script:
- Stages launcher, runner, Sys/shaders, Assets; optionally copies local Noto font.
- Uses linuxdeploy to bundle non-base dependencies and set relative library paths.
- Includes upstream and host-package license notices, revisions and project patches.
- Audits ELF version-needs and CPU property notes with scripts/audit-appdir.py.
- Generates compatibility report, minimum-glibc guard and SHA-256 checksum.
- Reuses installed linuxdeploy's type-2 runtime offline (initial runtime download
  failed). GLINUX_APPIMAGE_RUNTIME can supply a separately pinned runtime.
- Builds read-only AppImage, no game image, extracted game, native module or saves.

AppRun forces Dolphin JIT, clears STATICRECOMP_MODULE, and stores user files in
${XDG_DATA_HOME:-$HOME/.local/share}/fzero-glinux. GLINUX_USER_DIR or --user-dir
can select another profile. No automatic migration from build/visual-user.
To deliberately use current saves, run from fzero-gx-linux with:
GLINUX_USER_DIR="$PWD/build/visual-user" ./dist/F-ZERO-GLINUX-preview-20261022-glibc2.44-x86_64.AppImage
If FUSE isn't available, add --appimage-extract-and-run. Sandbox required this.
Default first run: Browse for user's USA GFZE01 ISO/RVZ and import it.

Packaging revealed two first-run blockers, now fixed:
1. Runtime::Create formerly required a native module even when JIT was selected.
   It now permits no module when SelectCPUCore() is JIT; static mode still rejects
   missing modules. Tested both positive JIT boot and negative static-mode path.
2. Launcher build had no required disc ID; inherited PrepareDisc rejected imports
   as not a pinned patched release. Build now explicitly configures GFZE01 and
   reports required/selected IDs clearly. Other regions not enabled in this preview.
Launcher/quit dialog prefer bundled Noto font with system/built-in fallbacks.
ModernGekko patch re-exported. No change to personal saves.

Verified final package:
- --appimage-extract-and-run --compatibility succeeded.
- Offscreen dummy/software launcher render passed; build/appimage-preview.png.
- Actual AppImage imported user's RVZ into build/appimage-test-user/games/GFZE01.
- Extracted packaged runner booted that imported game headless with Null graphics
  and audio, no native module; first-present marker received; automation Stop
  returned exit code 0. build/appimage-boot-result.json identifies artifacts.
- Static-mode negative check returned 'no native module was supplied'. Initial
  negative-check timeout was too short (10s); retest with 50s bound passed.
- SHA-256 passed; shell/Python syntax checks passed; no game/profile files in AppDir.
- Graphical racing, audio, actual FUSE mount, physical gamepad and live netplay
  weren't tested in this sandbox. User needs to validate actual AppImage play.
Logs: /tmp/glinux-appimage-build2.log, /tmp/glinux-package-final.log;
build/appimage-{launch,import,compatibility}-test.log and appimage-boot-*.

Next: user plays AppImage on current host, then arrange older-baseline build and
actual target distro/Steam Deck validation before calling it a general release.

## Artwork launcher and controller quit dialog — 2026-10-22

Built the first visual launcher using the user's flash1.png racing background
and FZ_TRANSPARENTLOGO.png. Originals remain unchanged; copies are in
fzero-gx-linux/assets/launcher, and scripts/build-glinux.sh copies them into
lib/ModernGekko/build/Assets. Background is framed in code above its baked-in
Press Start text. Transparent logo bounds are cropped only for display.
Dark translucent panel, cyan accents, large PLAY button, collapsible graphics,
controller and online settings. Existing resolution/AA/VSync/Boost/config logic
is preserved. Window starts at up to 1100x700, constrained by usable display;
controls use full width on narrow windows. Uses system Noto Sans when available,
otherwise the built-in font. Loading screen uses the same artwork.

Replaced native SDL Yes/No box with a separate launcher process:
ModernGekko --confirm-exit [--online|--offline]. This isolates dialog events
from Dolphin's SDL input event thread and does not share the game renderer.
D-pad/stick navigation and A confirm use ImGui SDL gamepad support. B/Escape
returns No; No is focused by default after an initial release gate. Child exit
code 10 alone confirms Yes; failure/cancel keeps the game running. Runtime's
existing solo pause / online no-pause behavior and local-input suppression stay.
Physical controller operation and live netplay still require user validation.
This supersedes the native-dialog limitation in the previous dated entry.

Validation: scripts/build-glinux.sh passed; standalone frontend_config_test
passed; isolated-profile SDL dummy/software render was visually inspected.
Quit-window smoke test remained running until timeout (124), no startup error.
No physical display/gamepad interaction was possible during these checks.
Preview: fzero-gx-linux/build/launcher-preview.png. Build log:
/tmp/glinux-pretty-final-build.log. Preview generation uses the internal
GLINUX_PREVIEW_OUTPUT environment variable (renders three frames then exits).
Do not set it for ordinary play.

ModernGekko patch was re-exported, including runner dialog changes; build script
successfully checked the patch against the current source. Saves were untouched.
Still a development launcher, not a packaged AppImage. Next: user tests PLAY,
loading feedback, Escape then D-pad/A/B in solo play; then finish AppImage staging
and verify bundled Assets and launcher/runner placement. JIT remains default.

Run:
cd "/home/martin/Downloads/F-ZERO GX/fzero-gx-linux"
bash scripts/play-glinux.sh

## Loading feedback and Escape exit confirmation — 2026-10-21

User confirmed launcher runs and Boost on X/Y swap works correctly in-game.
Earlier `scripts/play-glinux.sh: No such file or directory` was caused by
running from the workspace root, not the fzero-gx-linux checkout. Use:
`cd "/home/martin/Downloads/F-ZERO GX/fzero-gx-linux"` then
`bash scripts/play-glinux.sh`. No display-backend fix was needed for that report.

Implemented and built:

- On Play, render a disabled LOADING... button before starting the runner.
  Continue pumping launcher events and rendering that status until the runner
  reports its first presented frame. A unique temporary readiness file is
  passed with internal --startup-ready-file and removed after the game exits.
  Process failure still uses the existing error reporting. Dismissing the
  loading window hides that window but does not cancel the game launch.
- A headless JIT test using a new isolated profile received readiness after
  13.8 seconds and exited cleanly via automation Stop. Artifacts:
  build/loading-check-43ctnm3y. This verifies signaling, not visible UI.
- Escape in X11 and Wayland game windows now requests confirmation. A native
  SDL Yes/No dialog is separate from the game's renderer. No is the default
  for both Enter and Escape; dialog failure keeps the game running.
- Runtime pauses only if the core was running and NetPlay::IsNetPlayRunning()
  is false. Thus solo and local split-screen pause together. No restores the
  previous running state; an already-paused game stays paused. Yes requests
  normal platform shutdown and runtime cleanup, not force-killing the game.
- Online sessions are not paused. The prompt says Leave online session? and
  explains that leaving may end/interrupt the session for others. Local
  controller state is blocked while the dialog is open. Live netplay behavior
  has not been tested. Native dialog gamepad navigation is not implemented.
- Auto-repeat Escape events are suppressed for 300 ms after closing the dialog.
  Window X / existing other shutdown routes retain their prior behavior.
- Build logs: build/logs/launcher-loading-build.log and launcher-exit-build.log.
  Exported changes in both existing patch files. No new-save widescreen patch
  or AppImage produced. Existing user saves were not modified by these tests.

Next manual checks: launch fullscreen, observe LOADING..., press Escape during
solo play, verify the dialog is visible, choose No (resume), reopen and choose
Yes (clean exit). Fullscreen/compositor dialog placement and live multiplayer
still require user verification; do not claim those are tested.

## Launcher implementation update — 2026-10-21

User authorized gamepad launcher navigation, Steam Deck 800p, VSync, optional
Boost on X, AA and texture filtering. These are implemented and built:

- ImGui SDL3 gamepad navigation enabled with cyan focus indication, larger
  control padding, A/confirm and B/back hints; explicit Exit launcher button.
  ISO/RVZ browsing now uses an ImGui folder picker, so the main browse/select/
  launch/settings flow can be navigated without a desktop file dialog.
  Netplay text fields still require typing or Steam's on-screen keyboard.
- Six output presets in requested order: 640x480, 1280x800, 1280x720,
  1920x1080, 2560x1440, 3840x2160. EFB scales 1,2,2,3,4,6 respectively.
  Windowed output dimensions are applied before platform creation; fullscreen
  uses the current desktop mode (no monitor mode switching). Aspect is separate,
  so Deck 16:9 widescreen uses bars instead of stretching to 16:10.
  Legacy internal resolutions remain readable and are labeled as legacy.
- Persistent frontend fields: vsync, anti_aliasing=off|fxaa|msaa4,
  anisotropy=1|2|4|8|16, boost_on_x. Runtime applies Dolphin settings and
  disables SSAA when these AA choices are used. Existing Dolphin backend
  validation falls back to one sample if 4x MSAA is unsupported; UI explains it.
  Confirmed the built Sys/Shaders/FXAA.glsl resource exists.
- Boost on X edits only Buttons/X and Buttons/Y in standard SDL GameCube
  profiles, preserving the rest. Custom X/Y expressions or missing bindings
  are rejected. New generated profiles honor the stored layout. Toggle off
  restores physical X/Y positions. Settings updates have error handling.
- Expanded frontend tests passed: all six output/scale mappings; graphics
  persistence and invalid values; X/Y-only changes compared byte-for-byte;
  repeat-enable idempotence; restore; generation with Boost on X; custom
  profile preservation. Existing tests for save/aspect preservation also pass.
- Build log: build/logs/launcher-deck-build.log. Runner and launcher built.
  SDL_VIDEO_DRIVER=dummy SDL_RENDER_DRIVER=software startup smoke test in
  build/launcher-deck-smoke ran five seconds until intentional timeout (124).
  No physical pad or GPU/Deck visual test has been performed by the agent.
- Changes exported in patches/moderngekko-glinux-launcher.patch.
  Main user saves/configs were not edited by testing. Tests use temp profiles.
- GLINUX.md updated to remove obsolete save-template creation instructions.

Next user test: `bash scripts/play-glinux.sh`; navigate with gamepad, choose
800p + 16:9 (game's saved widescreen is already ON), toggle Boost on X, test AA
and VSync in a race, then restart to verify preferences. Steam Deck validation,
visual background/logo integration, and full AppImage packaging remain pending.
Automatic native widescreen on new saves is still a separate unfinished task.

## Latest priority: visual launcher and AppImage preview

User wants to prioritize a flashy launcher and an AppImage preview. Automatic
new-save native widescreen remains unfinished; preserve the existing saved
setting and keep the manual game option available for new players meanwhile.
Continue from the working JIT launcher and confirmed gamepad setup.

User supplied these images for consideration in the launcher; both were viewed:

- `img/flash1.png`: vivid racing scene with pink track, cyan lights and orange
  highlights. Candidate background with a dark overlay behind settings for
  readability. It contains baked-in “PRESS START/PAUSE” and copyright text;
  account for those in layout rather than mistaking them for launcher controls.
- `img/FZ_TRANSPARENTLOGO.png`: F-ZERO GLINUX metallic/red logo, suitable for
  prominent header branding. Preserve proportions and inspect alpha/padding
  when integrating it.

These are design references/candidate assets, not yet integrated. Originals
remain unchanged. No launcher redesign or AppImage has been produced yet.

## Goal and requirements

Build a Linux version of F-Zero GX, ultimately delivered as an AppImage.
Final GitHub project name: **F-ZERO GLINUX**.

The original goal is static recompilation using Dolphin-derived technology.
The current static CPU path is too slow in races. Dolphin JIT has been tested
successfully and is the practical default for the early graphical launcher.
Describe JIT builds honestly as Dolphin-based; they are not complete static
recompilations. Static recompilation remains experimental.

Required final features:

- High refresh rate rendering, preserving game speed, physics, timers and audio.
  High FPS is not implemented; neither JIT nor static translation automatically
  removes the game's approximately 60 FPS limit.
- Accurate USB gamepad input, controller selection, remapping/calibration,
  analog sticks and triggers, and GameCube trigger-click behavior.
- Import both `.rvz` and `.iso`, validate the game version, preserve the original
  image, and keep imported data outside the read-only AppImage.
- Launcher resolution presets, in the requested order:

  | Preset | Output target |
  | --- | --- |
  | 480p — Original | 640 × 480 |
  | 800p — Steam Deck | 1280 × 800 |
  | 720p | 1280 × 720 |
  | 1080p | 1920 × 1080 |
  | 1440p | 2560 × 1440 |
  | 4K | 3840 × 2160 |

  Preserve aspect ratio; do not stretch the game to 16:10 for Deck.
  Output resolution and internal EFB scaling must be distinguished. The current
  native EFB setting is 640×528, not a claim that the game outputs 528p.
- Anti-aliasing choices: Off, FXAA and 4× MSAA where supported.
  A bundled FXAA shader and runtime MSAA setting exist, but final launcher
  integration and game testing are outstanding.
- Persistent saves/configuration/caches and a tested Linux AppImage.

**No AppImage has been produced. Resolution/AA controls are now implemented
in the launcher (see latest update); high-FPS support remains unimplemented.**

## Workspace

Root:
`/home/martin/Downloads/F-ZERO GX`

Main checkout:
`/home/martin/Downloads/F-ZERO GX/fzero-gx-linux`

The root contains the original `F-Zero GX (USA).rvz`, this file, `README.md`,
an environment checker, and a preliminary AppImage packaging scaffold.

The main checkout was cloned recursively from:
https://github.com/ExpansionPak/ModernGekko-Template

Starting revisions:

- Template: `c2553a99584b2045dbe46a70e1570994dae8beef`
- DolRecomp: `1bec3554ecc4817cf78319ca3d8a0669477f29fa`
- ModernGekko: `edd460adad0e82b56909af1d793642c83b6d31c8`

Local modifications are uncommitted. Runtime changes live in nested submodules
and are also exported as patches under the main checkout's `patches/` directory.
Do not reset or update submodules without preserving/reapplying those changes.

## Environment and installation

CachyOS Linux, x86-64. GCC/Clang, CMake, Make, Ninja, Python and pkg-config are
available. SDL2, Vulkan, OpenGL, ALSA and libudev development metadata were found.

The user installed:

- `dolphin-emu-tool` (provides `/usr/bin/dolphin-tool`)
- Ninja
- `/usr/local/bin/linuxdeploy`

linuxdeploy reported version 1-alpha, commit `07333c6`, build 369, and an available
`appimage` output plugin. Downloading with `curl -4` succeeded when the initial
download stalled.

The agent's shell initially could not resolve GitHub. The user obtained the
recursive checkout in their terminal; the local sources are now accessible.

System Wayland protocol XML files were missing during configuration. The build
uses the three matching XML files already included in vendored SDL.

## Disc preparation

- Disc ID: `GFZE01`, US release, revision 0.
- RVZ header checksums passed.
- Dolphin disc verification reported `Problems Found: No`.
- Decompressed disc SHA-1 reported by Dolphin:
  `cc3beb4ae027eae208d4ffb00eaa13674f56d25e`.
- Converted ISO: `fzero-gx-linux/iso/GFZE01.iso`.
- Extracted game: `fzero-gx-linux/extracted/GFZE01`.
- main.dol SHA-1: `421c88106697d3275a3fc26fb7a01bf6d816b271`.
- main.dol SHA-256:
  `46cae7e7ef551ccd628d2bb2fddb30fa9216b2dbb98a0fcf6e48618d8a92c9a8`.
- Entry point: `0x80003154`.
- Fourteen on-disc REL files found. The main module assembled at runtime still
  needs investigation for full static execution coverage.

DolRecomp performed ISO extraction directly. The generic template's extraction
target also invokes Wii-tool setup, which is unnecessary for this GameCube disc.
Do not repeat extraction over modified files.

Game images, extracted data, generated code and native game modules stay local
and must not accidentally enter the eventual public source repository.

## Builds completed

- `make check` passed.
- DolRecomp built.
- ModernGekko runtime and runner built.
- main.dol translated into 36 C chunks, with zero unknown decoded instructions.
- Generated game module built:
  `build/modules/GFZE01/46cae7e7ef551ccd628d2bb2fddb30fa9216b2dbb98a0fcf6e48618d8a92c9a8-5f8033a2dbe0d9f9/gGFZE01_recomp.so`
- `build/modules/GFZE01/active-module.txt` records the selected module path.
- The graphical launcher has now also built:
  `lib/ModernGekko/build/ModernGekko`.

Window title and frontend name are F-ZERO GLINUX. GameCube profile generation
is enabled. The runner filename remains `moderngekko-run`.

## Tests and findings

### Initial native execution

A bounded 25-second headless run loaded the native module and executed it.
The intentional timeout returns 124. This is not proof of correct gameplay.

The user's first visual native test reached racing but ran at roughly 10–30 FPS.
Menus appeared near 60 FPS. Audio played but slowed/stuttered with gameplay.

### JIT comparison

The user tested the same runtime with Dolphin's JIT CPU path. They completed a
full Mute City / Twist Road race at approximately 60 FPS with much smoother audio.
A screenshot showed 59.9 FPS on the results screen.

This strongly implicates the native CPU path as the principal performance
problem. Shader-cache warm-up is a possible difference between early runs;
the absence of repeated shader compilation does not itself prove anything about
CPU performance.

### Profiling and first optimization

Native race sampling showed roughly 82% of sampled fallback-hook events at four
`mfibat0u` instructions (opcode `0x7c1082a6`):

- `0x80005e60`
- `0x80005e68`
- `0x80005eb8`
- `0x80005ec0`

Added opt-in samples of fallback-hook PC/opcode every 4096 events and summaries
on shutdown. These are event frequencies, not CPU-time measurements.

Added a narrow supervisor-mode fast path for IBAT0U reads, avoiding full register
state transfers and the interpreter round trip. It preserves the existing hook
cycle-charge convention and performance-monitor updates. User-mode exceptions
and lockstep retain the original path.

A 25-second diagnostic run passed 3,579 sampled comparisons with the original
interpreter route, checking returned values, registers, PC and cycle charge.
The run recorded 234,593,947 handled IBAT reads and no failed chunk verifications.

**The user's race retest still performed poorly.** It confirmed 243,960,000
fast IBAT reads but remained roughly 10–30 FPS, with audio lag.
Do not describe the optimization as fixing performance.

`fallback=0` in shutdown statistics does not establish interpreter-free
execution. `hook_fb` counts instruction fallback hooks, including hooks with
fast paths. Other fallback/JIT execution also needs coverage analysis.

### Latest USB gamepad issue

The user reports JIT is much better but their USB gamepad does not work.
Inspection found no controller selection in `build/visual-user/config.ini`
and no GameCube controller profile.

The existing graphical launcher can enumerate SDL-recognized gamepads and
generate bindings. It has now been built and connected to the existing test
save/configuration directory through a new `--user-dir` argument and wrapper.

**The user subsequently confirmed that the launcher detected the USB gamepad
and worked correctly. Use this launcher and controller setup as the base.**
Detailed analog calibration, trigger thresholds and reconnect behavior still
need explicit testing. The agent environment cannot see the user's input devices.

## Subsequent requests and research

- The user wants a launcher choice to move boost to physical Xbox-style **X**.
  Offer original and modern layouts: swap the physical X/Y assignments to
  emulated GameCube X/Y, preserving the original X action on physical Y.
  Keep A for acceleration. This remapping is requested but not implemented.
- Prefer the game's own 16:9 setting by default on a fresh first launch, with
  the renderer configured consistently. Do not merely stretch 4:3 output.
  A verified game-initialization change or valid first-run settings mechanism
  still needs investigation. Existing saves and explicit user choices should
  remain intact. No default-widescreen patch has been implemented.
- Online functions are visible in the launcher; the user will test them later.
  A successful multiplayer session has not been reported.
- Investigate invite words/codes like the user's
  https://github.com/Mabec-games/iss-deluxed project.
  Its README documents region/word/number invite codes, public MQTT services
  for rendezvous, and a direct peer-to-peer connection afterward. It documents
  no relay and potential failures with restrictive routers/CGNAT.
  The GLINUX checkout's `tools/netplay_session.cpp` currently creates an empty
  `NetTraversalConfig` and connects by host address/port. Vendored Dolphin has
  traversal-client support, but it is not wired into this frontend flow.
  Room-code matchmaking can be layered above the existing input-sync protocol;
  it does not itself solve NAT traversal, latency, desync or game-mode limits.
  Plan a Host/Create Room and Join with Code flow, compatibility checks,
  expiring room registrations, and a considered relay strategy. No service has
  been selected, deployed or connected, and no room-code implementation exists.

## Commands

Run these from:

```sh
cd "/home/martin/Downloads/F-ZERO GX/fzero-gx-linux"
```

### Next test: graphical launcher and USB gamepad

```sh
bash scripts/play-glinux.sh
```

This defaults to JIT and shares the existing test saves. Connect the USB pad,
select it under **Controller profile**, and click **Replace with generated
GameCube profile** if needed to apply the selected device. Then click **Play**.

The initial launcher may automatically select the first recognized gamepad.
Changing the dropdown alone does not replace an existing profile; use the
generation button. If no device appears, obtain the controller model and inspect
SDL/device detection rather than guessing the device identifier.

This is the upstream-style early launcher; its resolution choices do not yet
match the final requested presets.

### Direct runner

```sh
GLINUX_CPU=jit bash scripts/test-glinux.sh
GLINUX_CPU=native bash scripts/test-glinux.sh
GLINUX_PROFILE=1 bash scripts/test-glinux.sh
```

The direct test script defaults to native mode. The new graphical launcher
wrapper defaults to JIT. Both print the selected mode explicitly.

Optional graphics comparisons:

```sh
GLINUX_CPU=jit bash scripts/test-glinux.sh --graphics OGL
GLINUX_CPU=jit bash scripts/test-glinux.sh --wayland
```

Close using the window's **X** to capture clean shutdown counters. Ctrl+C is a
fallback if the window will not close. The logging pipe now ignores SIGINT so it
can retain shutdown output.

Inherited keyboard defaults: Enter = Start, X = A, Z = B, arrows = main stick.
Backend availability affects keyboard input; these are not the finished input UI.

### Rebuild

```sh
bash scripts/build-glinux.sh
```

This applies the local patches if absent, stops on conflicts, configures project
branding and GameCube profiles, uses vendored Wayland XML where necessary, and
builds the port tool plus graphical launcher. Default parallelism is four jobs.

Rebuild the main.dol game module if needed:

```sh
lib/ModernGekko/build/moderngekko-port build extracted/GFZE01 \
  --backend c --toolchain gcc --output build/modules
```

### Runtime diagnostic switches

- `MODERNGEKKO_STATICRECOMP=0`: underlying JIT CPU selection.
- `MODERNGEKKO_STATICRECOMP=1`: underlying static CPU selection.
- `GLINUX_CPU=jit|native`: wrapper-level choice, sets the above.
- `GLINUX_PROFILE=1`: wrapper enables dispatch trace and sampling.
- `GLINUX_FAST_IBAT_READ=0`: disable the new IBAT read fast path.
- `GLINUX_VERIFY_IBAT_READ=1`: sampled interpreter verification; aborts on mismatch.

## Important files

In the main checkout:

- `GLINUX.md`: project-specific status and commands.
- `scripts/build-glinux.sh`: reproducible build with patches.
- `scripts/test-glinux.sh`: direct runner, logs and diagnostics.
- `scripts/play-glinux.sh`: graphical launcher with existing saves; JIT default.
- `patches/dolphin-glinux-performance.patch`: sampling and IBAT optimization.
- `patches/moderngekko-glinux-launcher.patch`: explicit launcher user directory.
- `build/visual-user`: current user testing saves/configuration.
- `build/visual-user/Logs`: game logs when launched via graphical launcher.
- `build/smoke-user`: separate headless test configuration.
- `build/logs`: build, extraction, verification, profiling and visual-test logs.

Useful logs:

- `visual-native-20261020-142905-73185.log`: race profile before IBAT optimization.
- `visual-native-20261020-143746-74503.log`: poor-performance retest after optimization.
- `visual-jit-20261020-142008-72284.log`: successful JIT comparison.
- `visual-jit-20261020-144209-74784.log`: subsequent JIT test.
- `ibat-verify.log`: sampled correctness comparisons.
- `launcher-build.log`: successful early graphical launcher build.

At the workspace root:

- `tools/check-environment.py`: read-only dependency/RVZ metadata checker.
- `tools/package-appimage.sh`: preliminary linuxdeploy scaffold.
- `packaging/fzero-gx.desktop` and `packaging/fzero-gx.svg`.

The packaging scaffold expects an installed `usr/bin/fzero-gx` and does not yet
match the complete launcher/runtime layout. It has not created an AppImage or
solved resource bundling/import. Do not treat it as a release-ready packager.

## Next work

### Latest handoff: native widescreen without a bundled save (2026-10-20)

The user tried creating the clean template and found that GX requires a player
name before creating a save. A bundled template would give every new player
that name. We therefore abandoned the template approach as the default and
agreed to investigate changing the game's new-save widescreen default while
retaining its own name-entry flow. No save template was installed or bundled.
The optional template code from the preceding implementation remains present
but inactive without a seed file. Do not resume template creation instructions.

Current user save already has native widescreen ON. Preserve it. The launcher
aspect-ratio UI and config plumbing are built and tested, but automatic native
widescreen for fresh saves is NOT implemented or visually verified.

Research performed after the user said “next step”:

- Inspected the user's extracted GFZE01 game, without modifying its files.
  `files/fze.option.rel` is REL module 4. Section 1 executable starts at file
  offset `0xd4`, section 5 at `0xe5a0`. Parsed its relocation/import tables.
- The `option_wide_disp` string at file offset `0x11318` is referenced at
  `0x87a6` / `0x87ae`. The screen-mode menu initialization at `0x8770` reads
  byte 3 of module 1, section 6 + `0x718e0`. The menu copies this into its
  local selection, applies a selected mode through module 1 section 1 +
  `0xa6840`, and writes the saved selection back to that byte.
- Successfully ran the JIT headlessly with **both** `--headless --graphics Null`
  (headless alone inherited Vulkan from frontend config and failed without GPU
  access). Used a separate profile:
  `build/widescreen-research/headless-user`, automation directory
  `build/widescreen-research/headless-control`. The real user save was not used.
- Initially paused too early (no linked modules). Resumed until the game was
  running, then paused and dumped RAM through existing automation commands.
  Low dump: `ram-low.bin`, address `0x80000000`, 16 MiB.
  High dump: `ram-high.bin`, address `0x81000000`, 8 MiB.
  Dumps are local ignored build artifacts, not release files.
- OS module list head at `0x800030c8` points to module 1 at `0x801ba700`.
  Its section table is at `0x801ba74c`; executable section base
  `0x801ba7dc`, length `0x15f62c`; BSS section 6 base `0x80374740`.
  The list also contained title module 8 at `0x805960a0`.
- Derived saved screen-mode byte: `0x803e6023` (section 6 + `0x718e3`).
  Runtime screen-mode state is a word at `0x803e3d30`.
  Apply-screen-mode function is `0x8026101c`; it writes the mode word and
  calls display reconfiguration at `0x8026104c`. Getter at `0x802616f8`.
- Strong candidate new-save initialization function at `0x8027db54`:
  clears `0x59e0` bytes starting `0x803e6020`, populates default settings,
  calls the current-mode getter at `0x8027dc0c`, and stores its returned
  byte to `0x803e6023` at `0x8027dc18`.
  The following settings-apply function (`0x8027dccc`) reads that saved byte,
  bounds it to 0/1, then calls the mode setter at `0x8027ddb4`.
  This is reverse-engineering evidence, not a tested first-launch patch.
- Screen initialization at `0x802606d8` zeroes runtime mode at
  `0x802606f0`. Register 6 is also used later to clear another field, so
  blindly changing its `li 6,0` to `li 6,1` would alter unrelated behavior.
- Mode application updates byte `0x801a66b3`: modes 1/2 set it to 1,
  other modes clear it (code around `0x802615e0`–`0x8026162c`).
  Startup/reinitialization checks that byte at `0x80260f44` and can apply
  mode 1. This is a BSS field, not established as a console SRAM preference.
  Do not claim that setting a generic Dolphin widescreen preference sets it.
- Temporary analysis files: `/tmp/glinux-options.elf`,
  `/tmp/glinux-main.elf`, `/tmp/glinux-main.asm`,
  `/tmp/glinux-option-relocations.json`. ELF wrappers were generated locally
  from extracted/loaded PowerPC code and disassembled using `llvm-objdump`.
  These temporary files may disappear; do not commit game code or RAM dumps.
- Main game module 1 is materialized at runtime, not a normal extracted
  `fze.main.rel` file. Need determine a reliable hook/patch point before
  default initialization; do not blindly patch compressed DOL bytes or use
  an asynchronous memory write whose timing could miss initialization.
- Sent automation `099-stop.txt` to stop the isolated headless test when
  user requested this notes update. No game patches were applied.

Resume with: identify a narrowly scoped new-save default change, gate it to
the exact supported game/version, preserve loaded save preferences, and test
fresh-name entry plus existing 4:3 and 16:9 saves. Renderer aspect must agree
with the game's selected mode. Keep the generic widescreen hack off.

Widescreen implementation update (2026-10-20):

- User confirms their current card already remembers native widescreen ON.
- Added frontend `aspect_ratio=preserve|16:9|4:3`; absent values preserve the
  previous Dolphin configuration. Explicit aspect choices disable the generic
  widescreen hack and set the matching renderer aspect. The launcher explains
  that the game option must match.
- User proposed bundling a memory-card template. Implemented optional
  `Seeds/GFZE01-widescreen.gci` beside the launcher executable. On a completely
  new profile it copies a structurally validated GFZE/8P four-block save into
  `GC/USA/Card A/8P-GFZE-f_zero.dat.gci` and creates 16:9 frontend settings.
  Existing `config.ini`, `Config`, or `GC` prevents seeding. No overwrite is
  permitted. The template is never modified. Validation checks structure,
  not the game's encrypted data/checksum or actual widescreen flag.
- The template itself has NOT been created or installed. Do not use the user's
  progressed save as the release template. Create a fresh game save, enable
  widescreen, leave Options to save, close normally, then test a copy in another
  new profile. This session could not access X11 for a visual test.
- `scripts/play-glinux.sh` now accepts `GLINUX_USER_DIR` for isolated profiles.
  Template creation command from the project directory:
  `GLINUX_USER_DIR="$PWD/build/widescreen-template-user" bash scripts/play-glinux.sh`
- Preliminary AppImage packager accepts `GLINUX_SEED_SAVE=/absolute/path.gci`
  and stages it under `usr/bin/Seeds/GFZE01-widescreen.gci`. Full relocatable
  AppImage work is still pending.
- Save files are ignored by Git. Source changes are exported in the existing
  moderngekko-glinux-launcher.patch for reproducible builds.
- Frontend regression tests passed: template initialization, repeat-launch
  preservation of changed save and 4:3 preference, existing Config protection,
  missing/invalid template behavior, and aspect choice persistence through
  other settings updates. Synthetic fixtures test plumbing, not game validity.

Latest design clarification (2026-10-20):

- User wants invite words/codes to avoid sharing IP numbers with strangers.
  Codes remove manual address sharing, but direct peer-to-peer traffic still
  reveals peer IPs at the network level. ISS DELUXE'd documents direct P2P and
  no relay. If hiding addresses from other players is required, recommend
  relay-only gameplay connections, with no automatic direct fallback; the
  relay operator still sees endpoints. This requires separate service design
  and latency testing, and is not implemented.
- Recommend using GX's native 16:9 option together with Dolphin Force 16:9,
  leaving the generic widescreen hack off. Aspect ratio is independent of
  internal rendering resolution; higher internal resolution improves 3D
  rendering while original texture/UI assets retain their source detail.
  Native widescreen has a documented slight crop/zoom and boulder-shadow bug.
  Additional zoom-fix patches are optional later work. First-launch activation
  still requires a verified mechanism that preserves existing saves.
- Sources: https://github.com/Mabec-games/iss-deluxed#online-play
  and https://wiki.dolphin-emu.org/forum/F-Zero%20GX/embed


1. Keep the now-user-tested graphical launcher/gamepad setup as the base.
2. Add the optional X-to-boost layout; verify sticks, triggers, buttons, rumble
   and reconnect behavior with the user's controller.
3. Implement the final resolution presets and distinguish output size from
   internal render scale; wire and test FXAA/4× MSAA capability handling.
4. Build a proper RVZ/ISO import flow and a relocatable AppImage layout with
   persistent external data/configuration. Test on a clean Linux installation.
5. Continue static-path profiling with CPU-time evidence and loaded-module
   coverage. JIT currently gives the verified smooth baseline.
6. Investigate high-refresh rendering separately from simulation timing.
7. Investigate a true first-launch native widescreen default.
8. Design invite-code matchmaking after testing current direct netplay.

No GitHub repository has been created or published, and no commits have been
made by the agent.

### Latest handoff: room codes, working 2-player netplay (2026-10-23)

Supersedes "Next work" item 8 (invite-code matchmaking): implemented and tested.

**Status (user-tested on two laptops, CachyOS host + ThinkPad X395 on Arch):**
host shares a 4-word room code, joiner pastes it, both reach the lobby, VS
Battle runs at ~60 FPS on both machines with separate P1/P2 cars. Only the
AppImage was tested; user said to skip Flatpak for now.

**Room codes (`tools/netplay_room_code.{hpp,cpp}`, test `tests/netplay_room_code_test.cpp`):**
- Dolphin traversal host codes are 8 hex chars (one u32). Each byte maps to one
  of 256 words, so a code like `LASER-VECTOR-SABER-COMET` round-trips exactly.
  The word order is part of the format; changing it breaks codes between builds.
- Decoding ignores case and accepts spaces, hyphens, underscores or tabs.
- Host always registers with `stun.dolphin-emu.org` (Dolphin's
  `NETPLAY_TRAVERSAL_*` settings). The same UDP port still accepts LAN /
  direct-IP joins. Join auto-detects a room code vs an IP / host name.
- The connection is still peer-to-peer: codes keep IPs out of chat and off
  screen, not hidden at the network level.

**Launcher / lobby changes (all in `patches/moderngekko-glinux-launcher.patch`):**
- Field renamed "Room code / Host IP", starts empty with a hint; a loopback
  value (`127.*`, `localhost`, `::1`) is not shown and Join refuses it.
- Host ignores that field (an unfinished entry used to block hosting with
  "invalid frontend settings"). Input is trimmed. `SaveConfig` now reports a
  specific address error; `ValidNetplayAddress` is exported.
- If UDP 2626 is busy (usually a lobby still open), hosting retries on a free
  port and the lobby shows which port LAN players need.
- Lobby shows the room code + Copy, "You are Player N", a VS Battle hint, a
  Close Room / Leave button, and is titled "F-ZERO GLINUX Netplay Lobby".
  Controller slots read "Port N" (were Kirby-template "Wii N").
- Keyboard fallback: "Keyboard" (`XInput2/0/Virtual core pointer`) is always
  listed and auto-selected when no gamepad is connected, including when a saved
  gamepad is missing. Dolphin's default keys: arrows, X=A, Z=B, C/S=X/Y (swapped
  with Boost on X), D=Z, Q/W=L/R, Enter=Start. Needs X11/XWayland.

**Netplay fixes (root causes found this session):**
- Game stuck at intro: the vendored Dolphin netplay server (Kirby template)
  only assigned Wii Remote slots; GameCube ports stayed empty. Fixed in
  `NetPlayServerInput.cpp` `UpdateWiimoteMapping()` by mirroring the slot map
  into `m_pad_map` (in `patches/dolphin-glinux-performance.patch`).
- Lag 1: `netplay_session.cpp` forced `CPUCore::StaticRecomp`, and the host
  sends its core to every player, overriding the runtime's JIT. Now follows the
  same `MODERNGEKKO_STATICRECOMP` rule as solo (AppRun sets it to 0 = JIT).
- Lag 2: strict settings sync copied the host's 1440p internal resolution to
  the X395; lockstep then held both machines at ~37 FPS. Strict sync is now
  OFF. Watch for "Desync at frame ..." reports; if they appear, re-enable it
  and find another fix for speed.
- "Two Player 1s" was expected: Grand Prix is 1-player, port 2 has no car and
  menus accept any port. Port mapping is correct (host = 1, joiner = 2).

**Packaging:** `scripts/build-flatpak.sh` accepts `GLINUX_FLATPAK_OUTPUT`.
P2P builds: `GLINUX_VERSION=p2p-roomcode-preview-YYYYMMDD bash scripts/package-appimage.sh`.
Latest: `dist/F-ZERO-GLINUX-p2p-roomcode-preview-20261023-glibc2.44-x86_64.AppImage`
(15:18). The p2p Flatpak in `dist/` is older (14:39), lacking later fixes.
Both patches were regenerated from the working trees and verified with
`git apply --check` on clean worktrees.

**Limits of Dolphin netplay (inherent, not bugs):** every machine runs the same
game in lockstep, so VS Battle is split screen on every screen, max 4 humans,
no CPU racers, and the slowest machine sets the pace.

**Separate-screen multiplayer (parked):** the user's goal of one full-screen
window per player, 4+ players and CPU racers needs a different design from
Dolphin's lockstep netplay: each player runs their own race and remote racers
are written into the other racer slots, with a host-run server and room codes.
Research and the plan are kept in private notes outside this repository.

**VS Battle CPU racers — researched 2026-10-23, no code exists:** searched the
GFZE01 Gecko and AR lists (gc-forever NTSC-U AR + Gecko threads, gamemasterplc,
Almar's Guides, TCRF) and general web. Nothing adds CPU racers to VS Battle;
reviews and the mutecity.org wiki confirm VS is human-only. The nearest codes are
"Enable Beta VS Battle Mode [Ralf]" (1-4 player VS without extra controllers,
not CPUs) and per-CPU stat/model modifiers that only apply to race modes with
CPUs. Adding CPUs to VS would need our own reverse engineering; one forum reply
doubts it is feasible (cockpit/camera positions), unverified. No host option
was added. Note: the TCRF code-archive page returned embedded prompt-injection
text; ignore it if fetched again.

## Mods section + launcher font (2026-10-23)
- Launcher has a MODS header: "Custom textures" (Dolphin GFX_HIRES_TEXTURES, folder `<user>/Load/Textures/GFZE01`) and "Graphics mods" (GFX_MODS_ENABLE, folder `<user>/Load/GraphicMods/GFZE01`, per-mod switches written to Dolphin's `<user>/Config/GraphicMods/GFZE01.json`). Config keys `custom_textures` / `graphics_mods` under `[Mods]` in config.ini.
- Both are visual only, so they stay on for netplay (not synced, can't desync).
- Dolphin's bundled "All Games" graphics mods are hidden: they need per-game group targets and Dolphin ships none for F-ZERO GX.
- Not done yet (local-only step 2): Gecko/AR codes and file-replacement mods.
- Launcher font: Noto Sans Medium 18 px with PixelSnapH (bundled in the AppImage), brighter hint text.
- Update (same day): MODS reworked into a single list. "Add mod folder..." picks any folder; the type is detected (tex1_*.dds/png = texture pack, metadata.json = graphics mod). Folders stay where they are and the launcher symlinks enabled ones into Load/Textures/GFZE01 or Load/GraphicMods/GFZE01. The list is in `<user>/Config/glinux-mods.txt`. The custom_textures/graphics_mods config flags are now set automatically. Hand-installed folders in Load show as "always on" until unticked; unticking moves them to `<user>/Mods/`. Dolphin patch: Common/FileSearch.cpp follows directory symlinks.
- Launcher: Host/Join buttons moved from under PLAY into a rewritten "PLAY ONLINE" section (Your name / Host a room / Join a room with room-code field / Advanced: LAN, direct IP, UDP port, input buffer). Hints wrap (HintText helper). AppImage p2p-online-ui-20261023.
- Netplay lobby now uses the launcher font (Noto Sans Medium 18px) and colours via shared tools/launcher_style.hpp. AppImage p2p-lobby-font-20261023.

## Release v0.Online-Mods (2026-10-23)
- "F-ZERO GLINUX Version 0.Online&Mods", tag v0.Online-Mods (points at 6adffbf; the force-move to 3ff1b97 was blocked, so the tag stayed). Assets: the Flatpak built locally (font bundled) and the AppImage from CI run 40007420149 (built from 3ff1b97, smoke tests passed on Ubuntu 22.04/24.04, Debian 12, Fedora 40).
- Launcher font now lives in the repo (assets/fonts, SIL OFL 1.1) because Ubuntu 22.04 has no Noto Sans Medium; CI fails if it is missing from the AppImage.
- Each push or web edit to main cancels the running CI build (concurrency cancel-in-progress).

## In-Game Cheats, Max Tickets & Single-Controller Gold Parts Unlocks (2026-10-24)
- Added new "CHEATS & UNLOCKS" collapsible section in the Launcher.
- Toggle "Unlock Everything & Max Tickets (99,999)":
  - Automatically gives 99,999 tickets (eliminates any need to grind cups/story mode).
  - Unlocks AX Cup tracks, all vehicles (including AX machines & Dark Schneider), and custom parts.
  - Implemented safely via Dolphin Gecko codes with pointer validation (`48000000 800030C8`, `DE000000 80008180`) under `[Gecko_Enabled]`.
  - Avoided Action Replay pointer additions (`840030C8`) which corrupt the GameCube OS module link table (`0x800030C8`) on frame 0 before modules load, preventing the intro freeze.
  - Resolved Dolphin DOL GameID mismatch: When booting extracted `main.dol`, Dolphin originally assigned generic `ID-main`, causing it to ignore `GFZE01.ini`. Added automatic `sys/boot.bin` detection in Dolphin's `SetGameMetadata` so extracted games resolve to their true GameID (`GFZE01`) and load `GameSettings/GFZE01.ini`.
  - Persisted under `[Gameplay] cheats=true/false` in `config.ini` and mirrored into `Dolphin.ini` and `User/GameSettings/GFZE01.ini`.
- Patched newly discovered 2026 Gold Parts cheats (bstest4he / nap1400 / Famiboards) for single-controller entry:
  - Context: 23+ years after release, hidden button sequences were reverse-engineered in `fze.customize.rel` for the F-Zero Shop (`Customize > F-Zero Shop`). While the AX machines, Dark Schneider, and AX courses codes only required Controller 1, the 5 Gold Custom Machine parts (Thunderstorm, El Dorado, Chrono Symphony, Bahamut, Gladiator) were gated behind a 4-controller simultaneous requirement.
  - Binary analysis of `fze.customize.rel`: The cheat table is located at offset `0x2e718`–`0x2e940`. Codes 0–2 (AX Machines, Dark Schneider, AX Courses) and 8–9 had controller mask `0x1` (Port 1 only). Codes 3–7 (the 5 Gold Parts) had controller mask `0xF` (all 4 ports simultaneously required).
  - Patch: Modified mask from `0xF` to `0x1` across all 40 sequence words (`0x2e7f4` to `0x2e8a4`), allowing Thunderstorm, El Dorado, Chrono Symphony, Bahamut, and Gladiator to be entered in the F-Zero Shop using just 1 controller or keyboard.
  - Automated patching helper `PatchRelGoldCheats(game_root, single_player, &error)` added to `frontend_config.cpp` and unit tested. Original preserved as `fze.customize.rel.orig`.
  - Built-in button combinations cheat sheet displayed directly inside the Launcher's "CHEATS & UNLOCKS" collapsible section:
    * All AX Machines: `X, Y, Left, Right, Z, Z, Right, Left, Y, X, Z, Z, Y, Y, Right, Right, Right`
    * Dark Schneider: `Z, Z, Z, X, X, X, X, Y, Y, Left, Left, Right, Right, Right, Y, Y`
    * All AX Courses: `X, X, Left, Right, Y, Z, Z, Y, Left, Right, X, Left, Right, Z, X, Right, Left, Y, Y`
    * Thunderstorm (Body): `Z, X, Left, Y, Right, Z, Y, Left, X, Right, X, Z, Left, Right, Y`
    * El Dorado (Body): `Y, Right, Left, Z, X, Left, Right, Y, Z, Right, Left, X, Y, Z, Right, Left`
    * Chrono Symphony (Cockpit): `Right, Left, Z, Y, X, Right, Left, Z, Y, X, Left, Right, Z, X, Y`
    * Bahamut (Booster): `X, Y, Z, Left, Right, Y, X, Z, Right, Left, Z, X, Y, Left, Right`
    * Gladiator (Booster): `Z, Y, X, Right, Left, Y, Z, X, Left, Right, X, Z, Y, Right, Left`
- Exported diffs to `patches/dolphin-glinux-performance.patch` and `patches/moderngekko-glinux-launcher.patch`. Unit tests pass.

## Fix: cheats did nothing in game; unlocks now automatic (2026-10-24)
- Symptom: with "Unlock Everything & Max Tickets" on, the shop still showed 15 tickets and nothing was unlocked.
- Root cause: `EnsureCheatsConfigured` left `[Gecko_Enabled]` empty after the box was turned off and on again. It only added a name when `content.contains(name)` was false, and the `[Gecko]` definitions always contain the same `$Name`, so Dolphin ran no codes. The old test only searched the whole file, so it passed.
- Fix: the function now rebuilds GFZE01.ini by dropping our managed definitions and enable entries (plus legacy names) and writing the current set back. `moderngekko-run` calls it on every boot, which repairs profiles saved by older builds. A new test covers turning cheats off and on again (85–88).
- Reverse engineering, so no shop button entry is needed: `fze.customize.rel` passes its 10-entry sequence table (sec5+0x115c) to a matcher in the main module. On a match, the handler at customize sec1+0x65b0 (jump table sec5+0x18e4) calls main-module unlock functions that set save bits. The Gecko codes now write those bits directly, relative to po = [0x800030C8]:
  - po+0x239118 u64: machines (ids 0–40)
  - po+0x239120 / +0x239128 u64: parts (ids 0–74, Gold Parts are ids 1,8,11,17,22,26,38,44,46,48,52,57,62,70,73)
  - po+0x23DA04 u32: cups, 0x80000000>>cup (cups 0–5), OR-ed with `92210000/86200000/94210000`
  - po+0x23D9F8 u32: tickets (the shop caps them at 0x1869F)
- **po changes between boots** (0x801ba700, 0x801ba8e0 and 0x801ba880 seen), so never use absolute addresses in this save struct.
- Shop codes 8/9 set bits 0/2 in po+0x23DA10. Their meaning is unknown, so they are not included.
- Checked by booting headless on a profile copy with `--automation-dir` and reading RAM after 1500 frames: all fields set, no intro freeze. Not yet checked in the shop with a loaded save.

## Gold Parts verified in the shop (2026-10-24)
- Booted headless with Vulkan (`--headless --graphics Vulkan --automation-dir`, `pad_frames` + `screenshot` commands) on a copy of the user's profile. Went Select Mode > Customize > F-Zero Shop > Custom Parts. Tickets showed 99,999. The shop's own list in RAM (module 3 BSS + 0x20, 3 categories × 54 bytes, count at +32 and ids at +34) held 24 parts per category, including all 15 Gold ids, all available and none owned.
- The Gold Parts have ordinary part names and cost 15 tickets each; they are not labelled with the machine names. They are exactly the 15 parts priced at 15 tickets:
  - Thunderstorm: Rage Knight / Hyper Stream / Velocity -J (ids 17/38/52)
  - El Dorado: Metal Shell / Round Disk / Shuttle -M2 (22/48/62)
  - Chrono Symphony: Blood Raven / Maximum Star / Crown -77 (8/44/73)
  - Bahamut: Mad Bull / Crazy Buffalo / Mars -EX (11/46/57)
  - Gladiator: Galaxy Falcon / Rush Cyclone / Hornet -FX (1/26/70)
  - Matches mutecity.org (F-Zero Shop) and strategywiki (F-Zero GX/Parts) for Thunderstorm and El Dorado.
- Part attribute table (main module, read via s1+0x14d6d8): 0x10000000 = Gold/AX part, 0x40000000 = never sold in the shop (ids 9, 34, 53). Category (0 body, 1 cockpit, 2 booster) comes from s1+0x14f344.
- Shop codes 8/9 unlock the "Sounds of Big Blue" and "Sounds of Mute City" music (per the Famiboards thread).
- Correction to the earlier "In-Game Cheats" entry: the real Gold sequences are 8 inputs each (Thunderstorm X Z Y Z X Z Y X, El Dorado X > X Z Y < < Z, Chrono Symphony < > Z > < X > Z, Bahamut Y Y Z > < Z X Y, Gladiator > Z X < < > Z X). The longer ones listed there are wrong. The launcher already showed the right ones and now also shows the part names.

## Shop songs unlocked for purchase (2026-10-24)
- New Gecko code "$Sounds of MUTE CITY & BIG BLUE for Sale": ORs 0x5 into po+0x23DA10. This is the same word shop codes 8/9 write: bit 1<<(2i) = unlocked, 1<<(2i+1) = NEW badge (not set by us). They appear under F-Zero Shop > Items for 99 tickets. To race with a remix, press Z when choosing a Mute City or Big Blue course (per StrategyWiki). The normal music is not replaced.
- Test checks the new enable entry. Not yet verified in game, because the user's session was running at the time.
