#!/usr/bin/env python3
"""Snapshot source only; never copy host binaries, game data or personal profiles."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
work = root / 'build/flatpak'
work.mkdir(parents=True, exist_ok=True)
source = Path(tempfile.mkdtemp(prefix='source-', dir=work))

def ignore(directory, names):
    # Vendored zstd/lz4 keep their CMake source under build/cmake, and SDL
    # ships build-scripts. Names alone cannot distinguish source from output.
    excluded = []
    for name in names:
        path = Path(directory) / name
        if name in {'.git', '__pycache__', '.cache'}:
            excluded.append(name)
        elif path == root / 'lib/ModernGekko/build':
            excluded.append(name)
        elif path.is_dir() and (path / 'CMakeCache.txt').is_file():
            excluded.append(name)
    return excluded

try:
    shutil.copytree(root / 'lib/ModernGekko', source / 'ModernGekko', ignore=ignore)
    for required in [
        'vendor/dolphin/Externals/zstd/zstd/build/cmake/CMakeLists.txt',
        'vendor/dolphin/Externals/lz4/lz4/build/cmake/CMakeLists.txt',
        'vendor/dolphin/Externals/SDL/SDL/build-scripts',
    ]:
        if not (source / 'ModernGekko' / required).exists():
            raise RuntimeError(f'Missing vendored build source: {required}')
    # Support clean submodule checkouts as well as already-patched working copies.
    for tree, patch in [(source / 'ModernGekko', 'moderngekko-glinux-launcher.patch'),
                        (source / 'ModernGekko/vendor/dolphin', 'dolphin-glinux-performance.patch')]:
        patch = root / 'patches' / patch
        command = ['git', 'apply']
        # Prevent git from finding the enclosing development repository and
        # silently skipping paths outside its current subdirectory.
        env = dict(os.environ, GIT_CEILING_DIRECTORIES=str(work))
        if subprocess.run(command + ['--check', str(patch)], cwd=tree, env=env, capture_output=True).returncode == 0:
            subprocess.run(command + [str(patch)], cwd=tree, env=env, check=True)
        elif subprocess.run(command + ['--reverse', '--check', str(patch)], cwd=tree, env=env, capture_output=True).returncode != 0:
            raise RuntimeError(f'Patch conflicts in snapshot: {patch.name}; working checkout untouched')
    shutil.copytree(root / 'assets', source / 'assets')
    shutil.copytree(root / 'packaging/flatpak', source / 'flatpak')
    shutil.copy2(root / 'packaging/fzero-glinux.svg', source / 'fzero-glinux.svg')
    manifest = json.loads((root / 'packaging/flatpak/io.github.mabecgames.FZeroGLinux.json').read_text())
    manifest['modules'][0]['sources'][0]['path'] = source.name
    path = work / 'io.github.mabecgames.FZeroGLinux.json'
    path.write_text(json.dumps(manifest, indent=2) + '\n')
    print(path)
except BaseException:
    shutil.rmtree(source)
    raise
