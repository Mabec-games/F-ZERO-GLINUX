<p align="center">
  <img src="docs/images/promo.png" alt="F-ZERO GLINUX — futuristic racing on Linux" width="100%">
</p>

<h1 align="center">F-ZERO GLINUX</h1>
<p align="center"><strong>Choose your machine. Set your resolution. Hit the track.</strong><br>F-ZERO GX on Linux, with a controller-friendly launcher.</p>
<p align="center">
  <a href="#choose-your-package">AppImage & Flatpak</a> ·
  <a href="#start-playing">Start playing</a> ·
  <a href="#mods--hd-textures">Mods</a> ·
  <a href="#play-online">Play online</a> ·
  <a href="#build-from-source">Build from source</a> ·
  <a href="#project-status">Project status</a>
</p>

F-ZERO GLINUX brings together a custom launcher, graphics settings and modern
controller options around a Dolphin-derived runtime. The current playable
preview uses **Dolphin JIT** through ModernGekko. Static recompilation remains
experimental; these packages are not a completed static recompilation release.

Bring your own **F-ZERO GX USA (GFZE01)** image in **ISO or RVZ** format. Game
disc contents and personal memory-card saves are not included in the packages.
**WIP, Issues may occur, blame the robots... but if it works its all thanks to me.**

## Built for the starting grid

- **Controller-friendly launcher** with racing artwork, gamepad navigation and clear loading feedback.
- **Six resolution presets:** 480p, Steam Deck-sized 800p, 720p, 1080p, 1440p and 4K.
- **Graphics options:** VSync, FXAA or 4× MSAA, texture filtering and fullscreen.
- **Boost on X:** optional X/Y swap for modern four-button gamepads.
- **Native widescreen:** use GX's own Screen Mode setting, saved on your memory card.
- **Exit confirmation:** Escape opens a prompt; D-pad selects, A confirms and B resumes.
- **Separate user data:** saves and settings survive package updates.
- **Mods:** add HD texture packs and Dolphin graphics mods from any folder.
- **Online play:** host a room and share a 4-word room code; no IP addresses needed.

The current target is the game's normal **60 FPS** operation. Higher internal
resolutions do not add detail to the original textures; an above-60-FPS mode is
not included. Performance and available AA modes depend on your hardware.

<p align="center">
  <img src="docs/images/race-finish.png" alt="A first-place finish in F-ZERO GX" width="100%">
  <br><em>Alright, First place!</em>
</p>

## Mods & HD textures

<p align="center">
  <img src="docs/images/hd-textures.jpg" alt="The Blue Falcon finishing first with the F-ZERO GX HD texture pack" width="100%">
  <br><em>The <a href="https://forums.dolphin-emu.org/Thread-f-zero-gx-hd-ai-05-01-2022">F-ZERO GX HD</a> texture pack running in F-ZERO GLINUX.</em>
</p>

The launcher's **MODS** section supports Dolphin texture packs and graphics mods:

1. Download a mod, for example the
   [F-ZERO GX HD texture pack](https://forums.dolphin-emu.org/Thread-f-zero-gx-hd-ai-05-01-2022)
   from the Dolphin forums, and unpack it anywhere.
2. Open **MODS**, choose **Add mod folder…** and pick the mod's folder.
3. Start the game.

The launcher detects the mod type on its own: texture packs contain `.dds`/`.png`
files, graphics mods a `metadata.json`. Each mod can be switched on or off, and your
files stay where you put them. Mods only change what your own screen shows, so they
also work in online play. Mods are made by their own authors and are not included
with F-ZERO GLINUX.

## Play online

<p align="center">
  <img src="docs/images/online-split-screen.jpg" alt="A two-player online VS Battle in split screen at 59.9 FPS" width="100%">
  <br><em>Two players racing online, at full speed.</em>
</p>

Open **PLAY ONLINE** in the launcher. One player chooses **Host a room** and gets a
4-word room code such as `FALCON-PICO-SAMURAI-ZERO`; the others paste that code and
choose **Join room**. No IP addresses to share. Then pick **VS Battle** in the game.

Online play is built on Dolphin netplay, so it currently works like local
multiplayer:

- **Split screen for up to 4 players.** Every player sees the same shared
  split-screen picture, not their own full-screen view. Separate full-screen views
  per player are a goal for a later version.
- **VS Battle only.** Grand Prix and Time Attack have a single player.
- **No CPU racers** in VS Battle.
- The slowest machine sets the pace for everyone, so a quick connection and
  similar hardware give the smoothest races.

## Choose your package

**Both packages use SDL3. There is no SDL2 variant in this repository.** SDL is
used for controller input and the launcher; AppImage and Flatpak are packaging
formats, not different SDL versions. Neither package needs a separate host SDL2
installation. Both use the same launcher and Dolphin JIT gameplay backend.

| | AppImage | Flatpak |
|---|---|---|
| Start | Make executable, then open the file | Install once, then open from your app menu |
| Dependencies | Bundled libraries plus the host's base system | Application built inside a matching Freedesktop SDK; uses its Platform runtime |
| Current compatibility | Local preview requires **glibc 2.44+ and x86-64-v3** | Avoids that host-glibc dependency by using Freedesktop **26.08** |
| Best fit | Compatible, recent Linux systems; portable single-file launch | The preferred candidate for older distros and Bazzite testing |
| Game import | Browse to your own ISO/RVZ | Put the ISO/RVZ in Downloads, which the sandbox can read |
| Save location | `~/.local/share/fzero-glinux` by default | `~/.var/app/io.github.mabecgames.FZeroGLinux/data/fzero-glinux` |

Both builds have been confirmed working by the project owner on the development
machine. This is **not** a claim that every Arch, Debian, Bazzite or Steam Deck
configuration has been tested. Flatpak still needs a supported host kernel,
Flatpak installation and compatible graphics drivers. Its runtime may be
downloaded the first time you install the application.

The two packages keep separate profiles. Switching package formats does not
automatically transfer your saves.

## Start playing

The filenames below refer to the current preview artifacts. When building locally,
find them in `dist/`. See [Releases](https://github.com/Mabec-games/F-ZERO-GLINUX/releases)
for any published downloads; source publication does not automatically publish binaries.

### AppImage

```bash
chmod +x F-ZERO-GLINUX-preview-20261022-glibc2.44-x86_64.AppImage
./F-ZERO-GLINUX-preview-20261022-glibc2.44-x86_64.AppImage
```

If FUSE is unavailable, run:

```bash
./F-ZERO-GLINUX-preview-20261022-glibc2.44-x86_64.AppImage --appimage-extract-and-run
```

This particular AppImage cannot run on hosts with glibc older than 2.44.
See [AppImage packaging and compatibility](packaging/README.md).

### Flatpak

With Flatpak and the Flathub remote available:

```bash
flatpak install --user ./F-ZERO-GLINUX-x86_64.flatpak
flatpak run io.github.mabecgames.FZeroGLinux
```

The app also appears in your desktop application menu after installation.
This is a locally distributed bundle, not a Flathub store listing. To configure
the runtime source if needed:

```bash
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

### First launch

1. Select **Browse for ISO / RVZ** and import your USA game image. For Flatpak, use Downloads.
2. Open **Controller**, choose your gamepad and optionally enable **Boost on X**.
3. Choose your graphics settings, then press **PLAY**. The loading screen stays visible while the game starts.
4. Create your own player name in-game. For widescreen, enable the game's native Screen Mode option and select the matching 16:9 display setting in the launcher.

To exit a race, press **Escape**, then use the D-pad and A/B on the confirmation
window. Offline play pauses while the prompt is open; an online session keeps
running. A controller shortcut to *open* this prompt is not currently documented
as supported—Steam Deck users can map a button to Escape through Steam Input.

<p align="center">
  <img src="docs/images/machine-settings.png" alt="Pico and the Wild Goose on the machine settings screen" width="85%">
  <br><em>Fine-tune your machine before the race.</em>
</p>

## Build from source

```bash
git clone --recurse-submodules https://github.com/Mabec-games/F-ZERO-GLINUX.git
cd F-ZERO-GLINUX
```

The project pins upstream submodules and carries its changes as patches. The
build scripts apply those patches; generated game modules are not committed.

**Flatpak:** install `flatpak`, `flatpak-builder`, Python 3 and Git, then:

```bash
flatpak install --user flathub org.freedesktop.Sdk//26.08 org.freedesktop.Platform//26.08
JOBS=4 bash scripts/build-flatpak.sh
```

This compiles inside the SDK rather than reusing host binaries. See the
[Flatpak build guide](packaging/flatpak/README.md) for permissions and troubleshooting.

**AppImage:** with a C++23 toolchain, CMake, Ninja and the development dependencies
installed, build the runtime and package it using `linuxdeploy`:

```bash
bash scripts/build-glinux.sh
bash scripts/package-appimage.sh
```

See the [AppImage build guide](packaging/README.md) and
[upstream template's dependency notes](docs/UPSTREAM-TEMPLATE.md). Building on a
newer host can raise the resulting AppImage's minimum system requirements.

## Project status

| Area | Status |
|---|---|
| AppImage and Flatpak | Working on the project owner's development machine |
| JIT gameplay | Playable; smooth 60 FPS reported on that machine |
| Static recompilation | Experimental; performance work remains |
| Native widescreen | In-game setting; remembered in the player's save |
| Steam Deck / Bazzite / Debian | Target testing remains; 800p preset is available |
| Online play | Working between two machines with 4-word room codes; split screen, up to 4 players |
| Mods | HD texture packs and Dolphin graphics mods from any folder |

Report problems with your package type, distro, graphics backend, GPU and gamepad,
along with the relevant log. 

## Credits

Project presentation and Linux launcher work by **Mabec Games**.

Built on [ModernGekko](https://github.com/ExpansionPak/ModernGekko),
[DolRecomp](https://github.com/ExpansionPak/DolRecomp) and
[Dolphin](https://github.com/dolphin-emu/dolphin), starting from
[ModernGekko-Template](https://github.com/ExpansionPak/ModernGekko-Template).
Upstream components retain their respective licenses and attribution; see their
submodules and the notices included with packaged builds. F-ZERO GX, its imagery
and related trademarks belong to their respective owners. This is an independent
fan project, not an official Nintendo or SEGA release.

<p align="center">
  <img src="docs/images/logo.png" alt="F-ZERO GLINUX" width="460">
  <br><strong>See you on the starting grid.</strong>
</p>
