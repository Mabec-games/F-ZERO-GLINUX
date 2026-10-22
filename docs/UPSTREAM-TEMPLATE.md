# ModernGekko-Template

A template for building a static-recompilation pipeline for GameCube and Wii games, built on:

- [DolRecomp](https://github.com/ExpansionPak/DolRecomp) - static recompiler that turns a GameCube/Wii DOL into portable C or optimized native LLVM objects.
- [ModernGekko](https://github.com/ExpansionPak/ModernGekko) - the runtime the recompiled C links against (built on a Dolphin-derived core for video/audio/HLE).

Both are pulled in as git submodules under `lib/`. Everything is handled through the top-level `Makefile`. This repo has no game-specific code of its own, so it's a starting point for standing up a recompilation project for any GameCube or Wii title you own.

## Using This Template

Click **Use this template** on GitHub (or fork/clone it directly) to create your own project repo. Nothing in the `Makefile` or submodule setup needs to change to point it at a different game, just pass a different `ISO=` the first time you run it. Rename the repo to whatever fits your project.

## Dependencies

CMake, Ninja, and pkg-config, plus a C11/C++23 toolchain. DolRecomp and ModernGekko both build on macOS, Linux, and Windows; this repo's `Makefile` doesn't do anything platform-specific itself, it just drives the same CMake builds each submodule supports natively. `TOOLCHAIN` (see below) follows the compiler used to build ModernGekko.

### Linux

Ubuntu/Debian, matching what `lib/ModernGekko/vendor/dolphin`'s own CI installs for its NoGUI build (`.github/workflows/build.yml`):

```
sudo apt-get install -y ninja-build build-essential pkg-config cmake \
  libevdev-dev libudev-dev libgtk-3-dev libsystemd-dev \
  libbluetooth-dev libasound2-dev libpulse-dev libgl1-mesa-dev \
  libxrandr-dev libxi-dev
```

`build-essential` pulls in GCC, the default toolchain on Linux.

### macOS

Via Homebrew:

```
brew install cmake ninja pkg-config
```

Xcode's command line tools are also required (AppleClang 14.0.3+; verified on AppleClang 17).

### Windows

Visual Studio 2022 (or the standalone Build Tools) with the "Desktop development with C++" workload, for the MSVC toolchain, plus CMake and Ninja on `PATH` (installable via winget/Chocolatey or their own installers). No external package manager is needed beyond that. Dolphin's Windows dependency tree (FFmpeg, SDL, etc.) is vendored as prebuilt binaries/source under `lib/ModernGekko/vendor/dolphin/Externals/`, unlike Linux where system `-dev` packages are expected.

## Getting the Source

```
git clone --recurse-submodules https://github.com/<your-org>/<your-repo>.git
cd <your-repo>
```

If you already cloned without `--recurse-submodules`, `make` will fetch them for you on first run. To do it manually instead:

```
git submodule update --init --recursive
```

Run the build check at any time with:

```
make check
```

It verifies CMake, Ninja, Git, Python, working C11/C++23 compilers, and a
64-bit target with 8-byte pointers. If the source submodules are absent, it
offers to fetch them. Use `make check FETCH=1` for a non-interactive fetch,
or `make check BACKEND=llvm` to validate LLVM 19/20 as well.

> [!NOTE]
> `lib/ModernGekko` vendors a large chunk of Dolphin's dependency tree (SDL, fmt, imgui, Vulkan headers, etc.), so the first submodule sync takes a while and pulls a few hundred MB.

## Recompile and Run

Bring your own legally-owned ISO, no game data is included in or downloaded by this repository. Works with any GameCube or Wii disc; there is no default game, so `ISO=` (or an already-extracted `GAME=`) is required. Point `ISO` at a dump and run:

```
make run ISO=/path/to/Your\ Game.iso
```

This builds DolRecomp and ModernGekko, extracts the ISO, recompiles `main.dol` to C, compiles the result into a native module, and launches the game in a window.

For the optimized LLVM backend:

```
make llvm-run ISO=/path/to/Your\ Game.iso
```

`make llvm` builds the module without launching it. DolRecomp emits native
objects, and RecompCore's module template discovers the generated object
manifest and links every object into the game module automatically. LLVM is
only needed while building; the resulting game module has no LLVM runtime
dependency.

Each game gets its own directory under `extracted/<slug>/`, where `<slug>` is derived from the ISO's filename, so multiple games coexist without clobbering each other. `ISO` is only needed the first time per game, once extracted, run it again by slug instead:

```
make run ISO=iso/Your\ Game.iso        # first time for a new game
make run GAME=Your-Game-Slug           # afterwards
```

Drop ISOs under `iso/` at the repo root (gitignored) for a stable local path.

To just build the tools without touching a game, or to produce the compiled module without launching it:

```
make tools
make recompile ISO=/path/to/game.iso
```

`moderngekko-port` caches compiled modules by DOL hash and toolchain identity, so re-running `recompile`/`run` after the first build is cheap, it hits cache instead of recompiling.

> [!NOTE]
> Wii ISOs need [Wiimms ISO Tools](https://wit.wiimm.de/) (`wit`) for extraction, `make` downloads it automatically into `extern/wit` on first use. GameCube extraction is built into DolRecomp directly and doesn't need this.

## Makefile Targets

Run `make help` (or just `make`, the default target) for this list:

| Target       | Description                                                |
|--------------|--------------------------------------------------------------|
| `check`      | Validate build tools, compilers, architecture, and sources  |
| `tools`      | Build DolRecomp and ModernGekko                             |
| `extract`    | Extract a GameCube/Wii ISO into `extracted/<slug>/`         |
| `recompile`  | Recompile + compile a runnable module                       |
| `run`        | Recompile (if needed) and launch the game                   |
| `llvm`       | Build an optimized LLVM object module                       |
| `llvm-run`   | Build an LLVM object module and launch the game             |
| `clean`      | Remove all build output                                     |

## Variables

| Variable           | Default                                    | Description                                              |
|--------------------|--------------------------------------------|----------------------------------------------------------|
| `ISO`              | *(none)*                                   | Path to a game ISO. Required the first time per game, also determines that game's slug. |
| `GAME`             | *(none)*                                   | Select an already-extracted game by slug instead of `ISO=`. Required if `ISO` isn't given. |
| `JOBS`             | detected CPU count                         | Parallel build jobs passed to CMake/Ninja.                |
| `CMAKE_BUILD_TYPE` | `Release`                                  | Passed to both submodule builds.                          |
| `BUILD_TESTING`    | `OFF`                                      | Build developer test targets alongside production tools. |
| `BACKEND`          | `c`                                        | Generated-code backend: `c` or `llvm`.                    |
| `LLVM_DIR`         | *(CMake discovery)*                        | Optional path to LLVM 19/20's CMake package.              |
| `RUN_ARGS`         | *(empty)*                                  | Extra flags forwarded to `moderngekko-run` via `make run`, e.g. `--headless`, `--graphics Vulkan`. |
| `TOOLCHAIN`        | `auto`                                      | Compiler for the per-game module: `auto`, `clang`, `gcc`, or `msvc`. See "Toolchain" below. |

For example, to force a debug build with extra runner flags:

```
CMAKE_BUILD_TYPE=Debug make run ISO=/path/to/game.iso RUN_ARGS="--headless"
```

## LLVM Backend

DolRecomp supports LLVM 19 and 20. If it is installed outside CMake's normal
search path, point the template at its package directory:

```
make llvm GAME=Your-Game-Slug LLVM_DIR=/usr/lib/llvm-19/lib/cmake/llvm
make llvm-run GAME=Your-Game-Slug LLVM_DIR=/usr/lib/llvm-19/lib/cmake/llvm
```

The portable C backend remains the default and is always available:

```
make recompile GAME=Your-Game-Slug BACKEND=c
```

## Toolchain

The default `TOOLCHAIN=auto` follows the compiler used to build `moderngekko-port`.
This keeps an MSVC build on MSVC and an MSYS2/MinGW build on GCC or Clang instead
of assuming that Visual Studio's `cl` is available.

Override it either way with `TOOLCHAIN=`:

```
make run ISO=/path/to/game.iso TOOLCHAIN=clang   # try clang on Linux anyway
make run ISO=/path/to/game.iso TOOLCHAIN=auto    # let moderngekko-port pick
```

Module builds are cached by DOL hash *and* toolchain identity, so switching `TOOLCHAIN` between runs produces a separate cache entry rather than clobbering a previous build.

## Controller Input

ModernGekko has no in-app controller configuration UI (same as Dolphin's NoGUI frontend it's built on), bindings come from `Config/GCPadNew.ini` / `Config/WiimoteNew.ini` in ModernGekko's user directory (`~/.local/share/moderngekko/Config/` by default), which nothing in this pipeline creates for you. Without one, GameCube pad input silently does nothing. You'll need to hand-author or copy in a working ini, Dolphin's ini format and key names are stable and documented by the project itself.

## Cleaning Up

```
make clean           # everything below
make clean-extracted # extracted disc + compiled modules only, keeps built tools
make clean-tools     # DolRecomp/ModernGekko build trees only
```

## License

DolRecomp and ModernGekko are each distributed under their own upstream licenses (see `lib/DolRecomp/LICENSE` and `lib/ModernGekko/LICENSE`, the latter GPL-3.0-or-later due to its Dolphin-derived runtime). No Nintendo disc image, extracted game data, keys, or copyrighted assets are part of this repository, bring your own legally-owned dump.
