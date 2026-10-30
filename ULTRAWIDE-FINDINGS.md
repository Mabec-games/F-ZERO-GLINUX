# 21:9 for F-Zero GX: findings (2026-10-30)

Goal: render F-Zero GX at 21:9 with a really widened field of view instead of
stretching the 16:9 picture. Status: **no code was added to
`SupportedLocalGeckoCodes()`**. Nothing could be run against a game here, and
the rule is that a code only goes into the table after it was verified on the
running game.

## Summary

| Question | Result |
| --- | --- |
| Is there a sourced 21:9 code? | **Yes, for GFZE01 (NTSC-U) only.** Two independent pages list the same code (see below). |
| Is there one for GFZP01 (PAL)? | **No source found.** |
| Was the removed "[gamemasterplc]" code invented? | **No.** Its 12 lines are identical to the sourced GFZE01 code. What was wrong: it was applied to GFZP01 with the same addresses, and "no source" in the earlier review was incorrect. |
| Tested on a running game? | **No.** No GFZE01 disc exists on this machine, and the runtime was not built here. |
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

## Why this is not in the table

- It was never run against a game in this project, on any region.
- The addresses are for GFZE01. Region addresses differ here (the Ralf 16:9 fix
  uses `120062BC`/`12008D68` for GFZE01 and `140554A0` for GFZP01), so the same
  lines must not be applied to GFZP01. In the PAL DOL, `0x800554A0` is a
  `cmpwi r30,0x10` in a slot allocator, which confirms that `po` is not the DOL
  base and that PAL offsets cannot be guessed from the US ones.
- It cannot be derived for GFZP01 from the DOL alone: the three words live in
  the runtime-linked module, which is not a file in the PAL disc image.

## What was checked on this machine

- A GFZP01 RVZ exists: `/SSDPlus/F-Zero GX (Europe) (EnFrDeEsIt).zip`
  (contains `F-Zero GX (Europe) (En,Fr,De,Es,It).rvz`). **No GFZE01 image** was
  found (searched the whole disk for `*.rvz`, `*.iso`, `*.gcm`, `*.ciso`, `*.gcz`,
  extracted `GFZE01`/`GFZP01` directories and the `fzero-glinux` user directory).
- The PAL image was decoded with a small private RVZ reader and its DOL
  analyzed statically (SHA-1 `ab98630b653d009acd00699d2215dddb546d6b7f`; sections
  `0x80003100..0x801AAE6C` including BSS). Findings: the DOL has no 16/9 or
  21/9 float constants; the only 4/3 use (`0x80005748`) is an `lfs` feeding
  a call at `0x800738E0` that was not identified. The words the 21:9 code
  writes are not DOL addresses (see above), so the DOL alone does not show them.
- The vendored Dolphin sources (`vendor/dolphin`) are not checked out here and
  the runtime was not built, so nothing could be launched.

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

1. **Test the sourced GFZE01 code** with a US disc: enable the game's 16:9
   Screen Mode, launcher aspect 21:9, apply the 12 lines above as a local
   Gecko code (outside the table), and look at the HUD, the edges of the track
   and split-screen. If it holds, add it to the table for GFZE01 only, keep
   GFZP01 empty and keep it opt-in (not default).
2. **GFZP01**: build the runtime, boot the PAL image, dump memory through the
   `0x800030C8` module, and locate the three float words (look for the vanilla
   16:9 aspect `0x3FE38E39` and 9/16 `0x3F100000` near each other). Verify with
   the game before adding.
3. Compare plain `CustomStretch` against hack + `CustomStretch` on the game.
