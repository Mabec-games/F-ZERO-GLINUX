#!/usr/bin/env python3
"""Make the app icons from the F-ZERO logo.

Writes packaging/fzero-glinux.png (512 px square, used by the AppImage and
Flatpak) and packaging/windows/fzero-glinux.ico (16-256 px, embedded in the
Windows launcher and runner). The logo is wide, so it is centred on a
transparent square at full width. Needs Pillow; rerun after changing the logo:

    python scripts/make-windows-icon.py [path/to/logo.png]
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "packaging" / "fzero-glinux-logo.png"
PNG = ROOT / "packaging" / "fzero-glinux.png"
ICO = ROOT / "packaging" / "windows" / "fzero-glinux.ico"
SIZES = (16, 24, 32, 48, 64, 128, 256)


def square(logo, side):
    logo = logo.crop(logo.getbbox())
    height = round(logo.height * side / logo.width)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    resized = logo.resize((side, height), Image.LANCZOS)
    canvas.paste(resized, (0, (side - height) // 2), resized)
    return canvas


def main():
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else SOURCE
    logo = Image.open(source).convert("RGBA")
    square(logo, 512).save(PNG)
    # Each size is resized from the logo itself, not from the 512 px square.
    images = [square(logo, size) for size in SIZES]
    ICO.parent.mkdir(parents=True, exist_ok=True)
    images[-1].save(ICO, sizes=[(s, s) for s in SIZES], append_images=images[:-1])
    print(f"wrote {PNG.relative_to(ROOT)} and {ICO.relative_to(ROOT)}")


if __name__ == "__main__":
    sys.exit(main())
