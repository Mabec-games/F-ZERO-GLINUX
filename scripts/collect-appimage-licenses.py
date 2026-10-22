#!/usr/bin/env python3
"""Include upstream notices and host package notices for bundled libraries."""
from pathlib import Path
import shutil
import subprocess
import sys
root, appdir = map(Path, sys.argv[1:])
out = appdir / 'usr/share/licenses/fzero-glinux'
source = root / 'lib/ModernGekko'
for path in source.rglob('*'):
    relative = path.relative_to(source)
    if 'build' in relative.parts or '.git' in relative.parts or not path.is_file():
        continue
    if path.name.lower().startswith(('license', 'copying', 'copyright', 'notice')):
        dest = out / 'upstream' / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)
packages = set()
if shutil.which('pacman'):
    for lib in (appdir / 'usr/lib').glob('*'):
        for system in [Path('/usr/lib') / lib.name, Path('/usr/lib/pulseaudio') / lib.name]:
            if system.is_file():
                result = subprocess.run(['pacman', '-Qqo', str(system)], capture_output=True, text=True)
                if result.returncode == 0:
                    packages.update(result.stdout.splitlines())
    for package in sorted(packages):
        notice = Path('/usr/share/licenses') / package
        if notice.is_dir():
            shutil.copytree(notice, out / 'host-packages' / package, dirs_exist_ok=True)
    common = Path('/usr/share/licenses/common')
    if common.is_dir():
        shutil.copytree(common, out / 'common', dirs_exist_ok=True)
    (out / 'host-packages.txt').write_text('\n'.join(sorted(packages)) + '\n')
provenance = []
for path in [root, source, source / 'vendor/dolphin']:
    revision = subprocess.check_output(['git', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip()
    provenance.append(f'{path.relative_to(root) or "."}: {revision} (plus project patches)')
(out / 'BUILD-SOURCE.txt').write_text('\n'.join(provenance) + '\nSee project patches and scripts for local modifications.\n')
shutil.copytree(root / 'patches', out / 'project-patches', dirs_exist_ok=True)
