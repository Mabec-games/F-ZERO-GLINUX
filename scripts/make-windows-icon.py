#!/usr/bin/env python3
"""Render packaging/fzero-glinux.svg into a multi-size Windows .ico.

The SVG is the project icon used by the AppImage and Flatpak. It holds only a
rounded rectangle and straight-edged paths, so this small rasteriser (standard
library only) is enough; rerun it after changing the SVG:

    python scripts/make-windows-icon.py
"""
import re
import struct
import sys
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "packaging" / "fzero-glinux.svg"
OUTPUT = ROOT / "packaging" / "windows" / "fzero-glinux.ico"
SIZES = (16, 24, 32, 48, 64, 128, 256)
SUPERSAMPLE = 4


def parse_colour(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def parse_path(data):
    """Polygon for an SVG path made of M/L/H/V/Z commands (absolute or relative)."""
    tokens = re.findall(r"[MmLlHhVvZz]|-?\d*\.?\d+", data)
    points, x, y, command, i = [], 0.0, 0.0, None, 0
    while i < len(tokens):
        if tokens[i].isalpha():
            command = tokens[i]
            i += 1
            if command in "Zz":
                continue
        relative = command.islower()
        kind = command.upper()
        if kind in "ML":
            dx, dy = float(tokens[i]), float(tokens[i + 1])
            i += 2
            x, y = (x + dx, y + dy) if relative else (dx, dy)
            # Pairs after a moveto are implicit linetos.
            command = "l" if relative else "L"
        elif kind == "H":
            x = x + float(tokens[i]) if relative else float(tokens[i])
            i += 1
        elif kind == "V":
            y = y + float(tokens[i]) if relative else float(tokens[i])
            i += 1
        else:
            raise ValueError(f"unsupported path command {command!r}")
        points.append((x, y))
    return points


def inside_polygon(px, py, polygon):
    inside = False
    for (x1, y1), (x2, y2) in zip(polygon, polygon[1:] + polygon[:1]):
        if (y1 > py) != (y2 > py) and px < x1 + (py - y1) * (x2 - x1) / (y2 - y1):
            inside = not inside
    return inside


def inside_rounded_rect(px, py, width, height, radius):
    cx = min(max(px, radius), width - radius)
    cy = min(max(py, radius), height - radius)
    return 0 <= px <= width and 0 <= py <= height and (px - cx) ** 2 + (py - cy) ** 2 <= radius ** 2


def load_shapes():
    svg = ET.parse(SOURCE).getroot()
    view = [float(v) for v in svg.get("viewBox").split()]
    shapes = []
    for element in svg:
        tag = element.tag.rsplit("}", 1)[-1]
        colour = parse_colour(element.get("fill"))
        if tag == "rect":
            w, h, r = (float(element.get(k, 0)) for k in ("width", "height", "rx"))
            shapes.append((colour, lambda x, y, w=w, h=h, r=r: inside_rounded_rect(x, y, w, h, r)))
        elif tag == "path":
            polygon = parse_path(element.get("d"))
            shapes.append((colour, lambda x, y, p=polygon: inside_polygon(x, y, p)))
    return view[2], shapes


def render(size, extent, shapes):
    rows = []
    step = extent / (size * SUPERSAMPLE)
    for row in range(size):
        line = bytearray()
        for column in range(size):
            totals, covered = [0, 0, 0], 0
            for sy in range(SUPERSAMPLE):
                for sx in range(SUPERSAMPLE):
                    x = (column * SUPERSAMPLE + sx + 0.5) * step
                    y = (row * SUPERSAMPLE + sy + 0.5) * step
                    colour = None
                    for fill, contains in shapes:  # later shapes paint over earlier ones
                        if contains(x, y):
                            colour = fill
                    if colour:
                        covered += 1
                        for channel in range(3):
                            totals[channel] += colour[channel]
            if covered:
                line += bytes(t // covered for t in totals) + bytes([255 * covered // SUPERSAMPLE ** 2])
            else:
                line += bytes(4)
        rows.append(bytes(line))
    return rows


def png(size, rows):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    raw = b"".join(b"\0" + row for row in rows)
    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def main():
    extent, shapes = load_shapes()
    images = [png(size, render(size, extent, shapes)) for size in SIZES]
    directory = struct.pack("<HHH", 0, 1, len(images))
    offset = 6 + 16 * len(images)
    for size, image in zip(SIZES, images):
        dimension = 0 if size >= 256 else size
        directory += struct.pack("<BBBBHHII", dimension, dimension, 0, 0, 1, 32, len(image), offset)
        offset += len(image)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(directory + b"".join(images))
    print(f"wrote {OUTPUT.relative_to(ROOT)} ({', '.join(map(str, SIZES))} px)")


if __name__ == "__main__":
    sys.exit(main())
