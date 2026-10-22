# Local Flatpak build

This is a source-build recipe, not a wrapper around the CachyOS AppImage.
It uses the installed Freedesktop SDK/Platform **26.08**, compiles the vendored
SDL3 and other libraries, and targets generic x86-64 rather than the host CPU.
The application uses **SDL3**, so installing SDL2 on a target machine is unnecessary.

From the project directory:

```sh
JOBS=4 bash scripts/build-flatpak.sh
flatpak install --user dist/F-ZERO-GLINUX-x86_64.flatpak
flatpak run io.github.mabecgames.FZeroGLinux
```

Required host tools: flatpak, flatpak-builder, Python 3 and Git. SDK/Platform 26.08
are already installed on this development machine. On another build machine:

```sh
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.freedesktop.Sdk//26.08 org.freedesktop.Platform//26.08
```

The script snapshots local sources, applies project patches if necessary, parses
the manifest, builds in the SDK and exports a single-file bundle. It does not
install the resulting application automatically. Build output is logged in
`build/flatpak/build.log`; snapshots and the local repository stay under
`build/flatpak`. Source snapshots omit generated CMake build directories and Git metadata, while
preserving upstream build/cmake and build-scripts source directories. Only
runtime source, launcher assets and packaging files are copied: no ISO/RVZ,
extracted game, native module or save is included. `--prepare-only` snapshots and
validates the manifest without starting a sandbox. Keep source modifications
consistent with the checked-in project patches; conflicting snapshots stop safely.

JIT remains the CPU backend. Import your own USA GFZE01 ISO or RVZ. Save/config
storage is isolated from the AppImage and development profiles:
`~/.var/app/io.github.mabecgames.FZeroGLinux/data/fzero-glinux`.

## Sandbox permissions

The local manifest grants network for netplay, Wayland with X11 fallback,
PulseAudio for audio, IPC for X11, device access for GPU/gamepads, and **read-only
Downloads access** for the current built-in file browser (which is not a portal).
It does not expose the whole home directory. Copy your ISO/RVZ into Downloads,
or grant an additional read-only directory for one launch:

```sh
flatpak run --filesystem=/absolute/path/to/games:ro io.github.mabecgames.FZeroGLinux
```

`--device=all` is deliberately broad for this local controller preview; narrower
input/USB portal permissions can be evaluated before publication. No permission
changes are applied to an installed application by the build script itself.

## Validation and limitations

**Update:** after correcting source snapshot filtering, the project owner
confirmed the Flatpak build and application work on the development machine.
Cross-distribution and Steam Deck testing remain open. The notes below record
the agent environment limitation during initial setup.

Source preparation, forward/reverse patch checks, shell/Python syntax and
`flatpak-builder --show-manifest` passed in the development session. Actual SDK
execution was blocked by the agent environment:
`bwrap: loopback: Failed to create NETLINK_ROUTE socket: Operation not permitted`.
Compilation and game operation could not be verified inside that agent session;
they were subsequently confirmed working by the project owner. Run the script
from the normal desktop terminal; if it fails, retain `build/flatpak/build.log`.
The script checks both executables start against the Platform runtime after the
build, rather than checking only the larger SDK.

Flatpak supplies userspace libraries independently of the host distro's glibc,
which addresses the AppImage's main portability problem. A supported host kernel,
Flatpak installation and compatible graphics drivers are still required. Debian,
Arch, Bazzite and Steam Deck need actual launch/controller/fullscreen testing;
this recipe alone does not certify support. Consumers need the Platform runtime
(downloaded at installation), but not the SDK or compiler. App ID is a local
project identifier; nothing has been uploaded to Flathub.

References: [Flatpak runtime/SDK and build instructions](https://docs.flatpak.org/en/latest/first-build.html)
and [sandbox permissions](https://docs.flatpak.org/en/latest/sandbox-permissions.html).
