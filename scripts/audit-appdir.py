#!/usr/bin/env python3
"""Record the actual ELF ABI floor of this build, rather than guessing by distro."""
from pathlib import Path
import re
import subprocess
import sys

appdir = Path(sys.argv[1]).resolve()
versions = set()
rows = []
for path in sorted((appdir / 'usr').rglob('*')):
    if path.is_symlink() or not path.is_file():
        continue
    with path.open('rb') as f:
        if f.read(4) != b'\x7fELF':
            continue
    info_proc = subprocess.run(['readelf', '--version-info', str(path)], capture_output=True, text=True)
    info = info_proc.stdout
    # Only requirements, not versions that a bundled library exports.
    needs = info.split("Version needs section", 1)[-1] if 'Version needs section' in info else ''
    required = set(re.findall(r'\bGLIBC_(\d+\.\d+(?:\.\d+)?)\b', needs))
    versions.update(required)
    floor = max(required, key=lambda s: tuple(map(int, s.split('.')))) if required else 'none'
    notes_proc = subprocess.run(['readelf', '--notes', str(path)], capture_output=True, text=True)
    notes = notes_proc.stdout
    isa = '; '.join(line.strip() for line in notes.splitlines() if 'ISA needed:' in line or 'ISA used:' in line)
    rows.append(f'{path.relative_to(appdir)}: glibc {floor}' + (f'; {isa}' if isa else ''))
minimum = max(versions, key=lambda s: tuple(map(int, s.split('.')))) if versions else '2.35'
out = appdir / 'usr/share/fzero-glinux'
(out / 'minimum-glibc').write_text(minimum + '\n')
report = f'''F-ZERO GLINUX — local JIT preview
Architecture: x86_64 (this local build may require x86-64-v3 / AVX2; see inventory)
Minimum required host glibc: {minimum}
Bundled non-base libraries: see ELF inventory below.
Host still supplies graphics drivers, display/audio servers and device access.

This is NOT a verified cross-distribution release.
CachyOS/Arch: packaging host; offscreen smoke tests only until user validation.
Debian and Bazzite: not tested; glibc below {minimum} is incompatible.
A build on an older baseline is required to lower this requirement.
ISA requirements below can impose additional CPU restrictions.

No ISO/RVZ, extracted game, native game module or personal saves are included.
Import your own USA game (GFZE01), ISO or RVZ, in the launcher. CPU execution uses Dolphin JIT.
Data: $XDG_DATA_HOME/fzero-glinux (default ~/.local/share/fzero-glinux).
Override data location with GLINUX_USER_DIR, or explicit --user-dir PATH.
If FUSE is unavailable: ./F-ZERO-GLINUX-....AppImage --appimage-extract-and-run

ELF inventory:
''' + '\n'.join(rows) + '\n'
(out / 'COMPATIBILITY.txt').write_text(report)
print(f'Audited {len(rows)} ELF files; required glibc >= {minimum}')
