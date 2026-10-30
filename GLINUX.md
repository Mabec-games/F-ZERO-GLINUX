# F-ZERO GLINUX

Linux recompilation of F-Zero GX, targeting an AppImage release.
This checkout is based on ModernGekko-Template. The upstream README describes
its generic pipeline; this file records the game-specific bring-up.

## Current verification

- Linux x86-64 compiler check passed on CachyOS.
- DolRecomp built successfully.
- Local GFZE01 revision 0 RVZ converted to `iso/GFZE01.iso`.
- Disc extracted to `extracted/GFZE01`.
- main.dol SHA-1: `421c88106697d3275a3fc26fb7a01bf6d816b271`.
- Fourteen on-disc REL files identified. The main module assembled at runtime
  still requires investigation.
- ModernGekko runtime and native main.dol module built successfully.
- Dolphin disc verification reported "Problems Found: No."
- A 25-second headless smoke test loaded the native module and executed it.
  The test ended at its deliberate timeout (exit 124). Shutdown counters:
  `native=129116929`, `fallback=0`, `hook_fb=72589303`, `smc_failed=0`.
  `fallback=0` does not mean interpreter-free execution: `hook_fb` counts
  instruction fallback hooks within native dispatches; some have fast paths,
  so this is not a count of full interpreter calls.
- User visual test reached racing: roughly 10–30 FPS in gameplay, menus appeared
  locked at 60 FPS. Audio played but slowed/stuttered alongside gameplay.
  This establishes initial visual/audio operation, not performance or correctness.
  Precise controller behavior, complete races, save/load and high FPS remain
  unverified.
- User JIT comparison completed a full race at approximately 60 FPS, with
  nearly perfect audio by their assessment. Screenshot shows 59.9 FPS on the
  results screen. This strongly implicates the native CPU path; shader-cache
  warm-up remains a possible difference between the two runs.

## Reproduce the runtime build

```sh
bash scripts/build-glinux.sh
```

The script sets the title to F-ZERO GLINUX, uses the `fzero-glinux` user directory
name, and selects GameCube controller profiles. It uses four build jobs by
default; override with `JOBS=8` if desired.

If system Wayland protocol definitions are missing, it supplies the three XML
paths from vendored SDL.
The performance patch described below is also applied to the vendored runtime.

After a successful build, create the native module with:

```sh
lib/ModernGekko/build/moderngekko-port build extracted/GFZE01 \
  --backend c --toolchain gcc --output build/modules
```

The template's extraction target invokes a Wii tool setup unnecessarily for
GameCube. The existing extraction was performed directly with DolRecomp:

```sh
lib/DolRecomp/build/dolrecomp extract iso/GFZE01.iso extracted/GFZE01
```

Do not repeat extraction over a modified game tree.

## Release goals

High refresh rate rendering must preserve original simulation speed, physics,
race timers and input behavior. Selectable output/internal resolution and an
accurate, configurable controller interface are required.

The AppImage launcher must offer these display presets, in the requested order:

| Label | Output dimensions | Intended use |
| --- | --- | --- |
| 480p — Original | 640 × 480 | Original presentation target; native EFB scale |
| 800p — Steam Deck | 1280 × 800 | Deck screen; preserve aspect ratio with bars as needed |
| 720p | 1280 × 720 | HD |
| 1080p | 1920 × 1080 | Full HD |
| 1080p Ultrawide | 2560 × 1080 | Full HD Ultrawide (21:9) |
| 1440p | 2560 × 1440 | QHD |
| 1440p Ultrawide | 3440 × 1440 | QHD Ultrawide (21:9) |
| 4K | 3840 × 2160 | UHD |
| 4K Ultrawide | 5120 × 2160 | UHD / 5K2K Ultrawide (21:9) |

These are output dimensions, not claims about the original EFB dimensions.
Internal render scaling must be defined separately and exposed accurately.
Do not stretch 4:3 or 16:9 content to 16:10 for the Steam Deck preset.

Requested anti-aliasing choices: Off, FXAA, and 4× MSAA. Verify the runtime
postprocessing path for FXAA and the graphics backend's supported sample counts
for MSAA. Unavailable modes must be clearly disabled. These choices are
requirements, not implemented features yet.

The AppImage is the final delivery format. Reaching a race, measuring native
execution coverage, validating saves/audio/input, and implementing image import
come before release packaging. Disc files and generated game code stay local.

The importer must accept both `.rvz` and `.iso` files, including case-insensitive
extensions. Detect the format from file contents as well as validating the disc
ID and executable hash. Preserve the original image. Convert RVZ into temporary
local staging when required; ISO can go directly to extraction. The first local
test already exercised RVZ conversion followed by ISO extraction.

Current logs are local in `build/logs/`: `configure.log`, `compile.log`,
`verify-image.log`, `extract.log`, `recompile.log`, and `smoke.log`.

## First visual test

For the early graphical launcher with USB gamepad selection:

```sh
bash scripts/play-glinux.sh
```

This defaults to JIT, shares the existing `build/visual-user` saves/configuration,
and points the launcher at the extracted game. Select the pad under **Controller
profile**, use **Replace with generated GameCube profile** to apply the selection
if a profile already exists, then click Play. Devices must be recognized by SDL
as gamepads. The launcher supports refreshing its device list when controllers
are connected. Physical input and calibration still require user testing.

The existing launcher is preliminary: the requested final resolution labels
and anti-aliasing controls are not implemented yet.
`patches/moderngekko-glinux-launcher.patch` adds an explicit user-directory option
so the launcher and runner use the same saves and controller settings.

```sh
bash scripts/test-glinux.sh
```

This uses the already built module, Vulkan, a window, and native EFB scale.
It keeps test saves/configuration in `build/visual-user` and timestamps the
terminal log under `build/logs`. It preserves existing test settings.
The internal 640×528 EFB setting is not a final launcher resolution label.

For an OpenGL comparison: `bash scripts/test-glinux.sh --graphics OGL`.
For native Wayland: `bash scripts/test-glinux.sh --wayland`.

For a diagnostic comparison with Dolphin's JIT CPU path, keeping the same
graphics configuration and save directory:

```sh
GLINUX_CPU=jit bash scripts/test-glinux.sh
```

For the native module path: `GLINUX_CPU=native bash scripts/test-glinux.sh`.
The script labels the selected CPU mode in the terminal and log filename.
JIT mode is a performance diagnostic, not the finished recompilation.
Compare the same course, machine and race segment after shader warm-up.
Close the window normally to retain final shutdown counters.

Native race profiling:

```sh
GLINUX_PROFILE=1 bash scripts/test-glinux.sh
```

This enables existing dispatch sampling and an added sample of fallback-hook
addresses/opcodes every 4096 hook events, printed on shutdown. These are event
counts, not CPU-time measurements, and include fast-path hook handling.
The runtime patch is in the nested Dolphin submodule. A sparse dispatch trace
is written alongside the terminal log. No code translation or timing semantics
are changed.

### First performance patch

The user's native race profile showed approximately 82% of sampled fallback-hook
events at four `mfibat0u` instructions. A narrow supervisor-mode fast path reads
Dolphin's current IBAT0U value without full CPU-state copies and an interpreter
round trip. It retains the existing hook cycle-charge convention and performance
monitor updates. User-mode exceptions and lockstep use the original route.

`patches/dolphin-glinux-performance.patch` preserves both the sampling addition
and this optimization. `scripts/build-glinux.sh` applies it to an unpatched
checkout or verifies it is already applied; conflicts stop the build.

The fast path is enabled by default. `GLINUX_FAST_IBAT_READ=0` restores the
original handling for comparisons. `GLINUX_VERIFY_IBAT_READ=1` checks one in
65536 eligible reads against the full interpreter route, including registers,
PC and cycle charge, and aborts on disagreement. This is diagnostic validation,
not a complete game correctness test.

Validation: the runtime rebuilt successfully. A 25-second headless run completed
3,579 sampled interpreter comparisons without disagreement and reported
234,593,947 handled IBAT reads, with zero failed code-chunk verifications.
Race FPS and audio improvement still require the user's visual retest.

The inherited keyboard defaults are Return (Start), X (A), Z (B), and arrow
keys (main stick). Their availability depends on the input backend; verify input
before proceeding with gameplay. Native Wayland keyboard behavior and gamepad
mapping have not been tested here.

First record whether the title screen appears, menus respond, audio works,
and a race starts. Then verify a complete race and save/load. Do not infer
playability or high-FPS support from the previous headless test.

## Starting revisions

- Template: `c2553a99584b2045dbe46a70e1570994dae8beef`
- DolRecomp: `1bec3554ecc4817cf78319ca3d8a0669477f29fa`
- ModernGekko: `edd460adad0e82b56909af1d793642c83b6d31c8`
## Launcher controls (2026-10-21)

Run `bash scripts/play-glinux.sh` to use the JIT launcher with existing saves.

- D-pad / left stick navigates, A confirms, B backs out of menus, and right
  stick scrolls. A visible cyan focus outline marks the selected control.
  An in-launcher folder browser supports ISO/RVZ selection with the gamepad.
  Netplay text fields still need keyboard input (or the Steam keyboard).
- Output presets: 480p, 800p Steam Deck, 720p, 1080p, 1080p Ultrawide, 1440p, 1440p Ultrawide, 4K, 4K Ultrawide. Windowed
  dimensions follow the preset; fullscreen uses the desktop's current mode.
  The 800p preset requests 1280x800 with 2x internal EFB rendering. Use 16:9
  display aspect with the game's widescreen setting for correct proportions
  and letterboxing on the Deck. Ultrawide presets pair with the 21:9 aspect ratio, which stretches the
  game's 16:9 picture sideways; no verified 21:9 camera code exists yet. Existing legacy render-scale values still load.
- VSync On/Off; anti-aliasing Off/FXAA/4x MSAA; anisotropic filtering
  1x/2x/4x/8x/16x. Unsupported MSAA falls back to Off in Dolphin. FXAA's shader
  is included in the built Sys/Shaders resources. Graphics apply at game launch.
- Boost on X swaps only GameCube X/Y bindings on generated SDL profiles.
  A, sticks, triggers, rumble and other bindings are retained. Unsupported
  custom X/Y expressions are rejected instead of being overwritten. Generate
  a standard controller profile first if none exists. Subsequent profile
  generation respects the saved Boost on X selection.
- Settings persist across launches. Exit launcher is accessible by gamepad.

Build and frontend regression tests passed. A software/dummy SDL startup smoke
check ran until its intentional timeout. This does not validate actual GPU
rendering or physical controller/Steam Deck operation; those require user tests.
The background/logo redesign and a complete AppImage remain outstanding.

## Native widescreen status

Match the launcher's 16:9/4:3 display setting to GX's own saved Screen Mode.
Explicit aspect choices disable Dolphin's generic widescreen hack. Existing
saves are not edited. Automatic native widescreen for a new save remains
unfinished. The save-template approach was abandoned because it also copies
the player name; optional template code remains inactive without a seed file.
Do not create or bundle a named save as the first-launch solution.

## Starting and exiting the game

Play shows a disabled **LOADING...** status until the runner presents its first
frame. Escape in the game opens a separate Yes/No confirmation dialog. **No**
(and Escape in that dialog) resumes solo play; **Yes** exits through normal
runtime shutdown. Local split-screen pauses too. Online play keeps running
while a **Leave online session?** warning is shown. Exiting may interrupt the
session for others. An already-paused game remains paused when choosing No.

These changes built successfully; readiness signaling passed a headless test.
Fullscreen dialog placement and online-session behavior need manual testing.


### Visual launcher (2026-10-22)

The build script installs the racing artwork and logo from `assets/launcher`
beside the launcher in `Assets`. Start with `bash scripts/play-glinux.sh`.
Graphics, controller and online settings expand individually. PLAY shows loading
feedback while the game starts. Escape in-game opens a separate quit window:
D-pad selects, A confirms, B/Escape resumes. No is the default. Solo play pauses;
online play continues. Physical gamepad and netplay validation is still pending
for this new quit window. AppImage packaging remains a separate next step.


### AppImage preview (2026-10-22)

Build with `bash scripts/build-glinux.sh`, then `bash scripts/package-appimage.sh`.
The working package and SHA-256 checksum are in `dist/`. It launches Dolphin JIT
without needing a game-derived native module. Import your USA (GFZE01) ISO/RVZ;
game data and personal saves are not included. Writable data defaults to
`~/.local/share/fzero-glinux` (respects XDG_DATA_HOME / GLINUX_USER_DIR).

This locally built preview requires glibc 2.44 and x86-64-v3. Debian/Bazzite
compatibility is not established. An older-baseline rebuild and target-device
checks are required before a broad release. See [packaging details](packaging/README.md)
and the compatibility report next to the AppImage. FUSE-free execution uses
`--appimage-extract-and-run`. Older sections describing packaging as wholly
unfinished are superseded by this preview; distribution validation remains open.
