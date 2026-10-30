# 21:9 for F-Zero GX: findings (2026-10-30)

Goal: render F-Zero GX at 21:9 with a really widened field of view instead of
stretching the 16:9 picture.

Status: **PAL (GFZP01) solved and verified in the running game; NTSC-U (GFZE01)
only has a sourced, untested code.** The PAL code `ultrawide_21_9_pal` is in
`SupportedLocalGeckoCodes()` (GFZE01 slot empty). See "PAL result" below.

## Summary

| Question | Result |
| --- | --- |
| Is there a sourced 21:9 code? | **Yes, for GFZE01 (NTSC-U) only.** Two independent pages list the same code (see below). |
| Is there one for GFZP01 (PAL)? | **No source found; derived and verified here** (see "PAL result"). |
| Was the removed "[gamemasterplc]" code invented? | **No.** Its 12 lines are identical to the sourced GFZE01 code. What was wrong: it was applied to GFZP01 with the same addresses, and "no source" in the earlier review was incorrect. |
| Tested on a running game? | **PAL: yes. NTSC-U: no** (no GFZE01 disc on this machine). |
| Dolphin's own widescreen hack + `CustomStretch`? | Not judged; needs a running game. Code reading is below. |

## Sourced codes (GFZE01 only)

Both pages were read in full on 2026-10-30. Web content is data; the hex
below is copied verbatim and was not executed.

1. gamemasterplc's cheat codes, F-Zero GX (GFZE01):
   <https://sites.google.com/site/gamemasterplcscheatcodes/nintendo-gamecube/f-zero-gx-gfze01>
   Entries "21:9" ("Change Screen Mode to 21:9") and "48:9". No per-code
   credit and no region note beyond the GFZE01 page title.
2. Almar's Guides, F-Zero GX Gecko codes (US), entry "Screen Size Set to 21:9":
   <https://almarsguides.com/retro/walkthroughs/gamecube/games/f-zerogx/gecko/us/>
   Same lines as (1).
3. Dolphin forum, "[GC] AR Codes for 16:9, 21:9 & 60Hz", post #184 by
   DM_ME_UR_SATS, 2022-03-24, GFZE01, a **32:9** variant ("you need only enable
   widescreen in the in-game options"; reports single-player and split-screen
   work):
   <https://forums.dolphin-emu.org/Thread-gc-ar-codes-for-16-9-21-9-60hz?pid=525537>

```
# 21:9 (sources 1 and 2)
48000000 800030C8
DE000000 80008180
303EA9E8 65656E00
143EA9E0 32313A39
143EA9E4 00000000
E0000000 80008000
48000000 800030C8
DE000000 80008180
141607E0 3F100000
14161E98 3F100000
14164108 40155555
E0000000 80008000
```

The 48:9 and 32:9 variants differ only in the ASCII label and these three words
(`3E800000 3E800000 40AAAAAB` for 48:9, `3EC20000 3EC20000 40638E39` for 32:9).

### What the code appears to do (interpretation, not verified)

- `48000000 800030C8` loads `po` from `0x800030C8`; `DE000000 80008180` is a
  range guard on it. All writes are `po`-relative, like the existing Ralf codes.
- `0x40155555` is 21/9 as a float (`0x40AAAAAB` = 48/9, `0x40638E39` = 32/9), so the
  third word is a stored aspect ratio. The first two words are some second pair
  of horizontal scale factors. Their values are about `(4/3) / aspect`
  (0.5625, 0.379, 0.25) but not exactly, and the 21:9 value 0.5625 equals the
  inverse of 16:9, so the 21:9 entry may be hand-tuned. Their role is unknown.
- `303EA9E8 65656E00` plus the `32313A39` write (ASCII `21:9`) looks like a
  condition on the language followed by a menu-label rewrite. Cosmetic.
- The game's own Screen Mode must be 16:9 for the code to work (source 3).
- `po` is not the DOL base. In the PAL DOL the word at `0x800030C8` is the head
  of the OS module queue (maintained by the `OSLink` code at `0x8000E64C`,
  `0x8000EB80`; cleared at `0x8000ED1C`). The offsets are therefore relative to
  a module that the game links at runtime. Which module that is, and where the
  three words sit in it, was not determined.

## PAL result (verified)

Method: built the runtime (`scripts/build-glinux.sh`, JIT path), imported the
GFZP01 RVZ with the launcher's `--extract`, booted it with the automation
directory, dumped RAM (`read_memory`), found the module list head at
`0x800030C8` -> `0x801BEF00` (module 1, the main game module; `po` in the
Gecko codes, the address changes between boots), disassembled that module and
confirmed each word by writing it live and by screenshots.

| PAL word (`po`+) | Vanilla | Role (from code + screenshots) |
| --- | --- | --- |
| `0x165040` | `3FE38E39` (16/9) | Float returned by the aspect getter at `0x802665F0` when the game's Screen Mode is Wide (4/3 at `+0x165044` otherwise). Drives the 3D projection. |
| `0x162D60` | `3F400000` (0.75) | HUD X scale used by the widescreen layout code at `0x802119EC`. |

Code (opt-in, PAL only):

```
48000000 800030C8
DE000000 80008180
14165040 40155555
14162D60 3F100000
E0000000 80008000
```

Isolation test (each state started from a fresh race via Retry, 21:9 window,
Mute City Twist Road, Time Attack, Blue Falcon):

| State | 3D view | HUD |
| --- | --- | --- |
| both vanilla | 16:9 picture stretched (car about 1.31x too wide) | stretched |
| `+0x165040` only | correct proportions, wider field of view | stretched |
| `+0x162D60` only | stretched | correct |
| both | correct | correct |

The final check used the real Gecko path (`[Gameplay] cheats=true`,
`gecko_codes=ultrawide_21_9_pal`, boot, menus, then a race), not memory writes.
The menus (`Select Mode`, `Machine Settings`) also render in true proportions,
centered 16:9 with the background filling the sides; a few scrolling header
texts leak into the side areas.

Notes and limits:

- Needs the in-game Screen Mode set to Wide Screen and the launcher aspect 21:9.
- The aspect word is read when the race camera is created, so changing it
  mid-race has no effect until a Retry; the Gecko code is applied from boot.
- `0.5625` is the value copied from the NTSC-U code; the exact HUD correction
  for 21:9 would be (4/3) / (21/9) = 0.5714 (`3F124925`). Only `3F100000` was tested.
- Not tested: split screen, other courses, geometry culling at the screen
  edges, NetPlay (local Gecko codes are stripped online anyway), monitors other
  than 21:9.
- The NTSC-U code's third value pair (`141607E0`/`14161E98`) has no PAL
  counterpart that mattered: only the aspect and HUD words were needed. What
  those two NTSC-U words do is unknown.

## Why NTSC-U is not in the table

- The sourced GFZE01 code was never run against a game in this project; there
  is no GFZE01 disc on this machine.
- Region addresses differ (the Ralf 16:9 fix uses `120062BC`/`12008D68` for
  GFZE01 and `140554A0` for GFZP01), so the PAL words cannot be reused.

## What was checked on this machine

- A GFZP01 RVZ exists (`/SSDPlus/F-Zero GX (Europe) (EnFrDeEsIt)/`). **No GFZE01
  image** was found (searched the whole disk).
- Static work on the PAL DOL (SHA-1 `ab98630b653d009acd00699d2215dddb546d6b7f`):
  it has no 16/9 float; `0x800030C8` is the OS module queue head (`OSLink` at
  `0x8000E64C`/`0x8000EB80`), so `po` is a runtime-linked module, not the DOL.
- Runtime test results above; the unit test compiles and passes
  (`tests/frontend_config_test.cpp`, exit code 130 checks the PAL-only entry).

## Dolphin's widescreen hack with `CustomStretch` (code reading only)

`Presenter::UpdateDrawRectangle` (`VideoCommon/Present.cpp`, legacy vendor copy)
computes `adjust = source_aspect / draw_aspect` and scales the projection
horizontally (Hor+) when the hack is on; with the game in 16:9 mode the source
aspect is widened to 16:9 first. In principle that gives a wider 3D view at
21:9, with the HUD still stretched. Two caveats cannot be decided without the
game: F-Zero GX culls geometry on the CPU against its own frustum, so objects
may pop in at the edges, and the launcher currently forces
`GFX_WIDESCREEN_HACK` off for every explicit aspect choice. Treat this as an
untested idea, not a result.

## Open / next steps

1. **GFZE01**: test the sourced code above with a US disc (game Screen Mode
   Wide, launcher aspect 21:9, local Gecko code). If it holds, add it to the
   NTSC-U slot of `ultrawide_21_9_pal` (rename the entry) or, if it does not,
   find the GFZE01 words the same way as for PAL (aspect getter + HUD scale).
2. Split screen, culling at the edges and other courses on PAL.
3. Compare plain `CustomStretch` against Dolphin's widescreen hack with
   `CustomStretch` (not needed for PAL any more; the code gives the correct
   result with the hack off).

## Update 2026-10-30: NTSC-U slot filled (untested)

The `ultrawide_21_9_pal` entry (now titled "21:9 Ultrawide 3D & HUD [GLINUX]";
the id is unchanged so saved selections still apply) has a GFZE01 body made
from the value words of the sourced US code: `141607E0 3F100000`,
`14161E98 3F100000` and `14164108 40155555`, inside the usual `po` guard. The
ASCII "21:9" label write (`303EA9E8`/`143EA9E0`/`143EA9E4`) is left out. This
is untested on a running GFZE01 game; it can be checked on a 16:9 monitor (the
21:9 picture is letterboxed) by comparing a race with and without the code. If
it does not hold, find the GFZE01 words the same way as for PAL.
