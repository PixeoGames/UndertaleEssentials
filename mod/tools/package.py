# Undertale Framerate Mod. Copyright (C) 2026 Pixeo.
# Free software under the GNU GPL version 3 or later: see LICENSE.
"""Builds the tester package: dist/UndertaleFramerateMod-<version>/ and a .zip of it.

    python mod/tools/package.py [--game DIR]

Contains Install.bat, Uninstall.bat and READ ME.txt, and in files/ the installer script, the patch
(only the bytes the mod changes, no game files) and the mod's source. Never includes Undertale's own files or decompiled game code.
"""
import argparse
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.dirname(HERE)
ROOT = os.path.dirname(MOD)
VERSION = '0.1-test'
NAME = f'UndertaleFramerateMod-{VERSION}'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--game', default=ROOT, help='folder containing the original data.win')
    a = ap.parse_args()

    release = os.path.join(ROOT, 'work', 'builds', 'release.win')
    subprocess.run([sys.executable, os.path.join(HERE, 'build.py'), '--game', a.game, '--out', release], check=True)

    # top level: only what a player needs to look at; everything else goes in files/
    out = os.path.join(ROOT, 'dist', NAME)
    if os.path.isdir(out):
        shutil.rmtree(out)
    files = os.path.join(out, 'files')
    os.makedirs(files)
    subprocess.run([sys.executable, os.path.join(HERE, 'make_patch.py'), os.path.join(a.game, 'data.win'), release,
                    os.path.join(files, 'data_framerate.patch')], check=True)

    inst = os.path.join(MOD, 'installer')
    for f in ('Install.bat', 'Uninstall.bat', 'READ ME.txt'):
        shutil.copy2(os.path.join(inst, f), os.path.join(out, f))
    shutil.copy2(os.path.join(inst, 'install.ps1'), os.path.join(files, 'install.ps1'))

    # source: the mod itself, without generated code (decompiled game code) or caches
    src = os.path.join(files, 'source', 'mod')
    shutil.copytree(MOD, src, ignore=shutil.ignore_patterns('gen', '__pycache__', '*.pyc', '*.patch'))
    shutil.copy2(os.path.join(ROOT, 'LICENSE'), os.path.join(files, 'source', 'LICENSE'))

    zip_base = os.path.join(ROOT, 'dist', NAME)
    if os.path.exists(zip_base + '.zip'):
        os.remove(zip_base + '.zip')
    shutil.make_archive(zip_base, 'zip', os.path.join(ROOT, 'dist'), NAME)
    print('package:', out)
    print('zip:    ', zip_base + '.zip')


if __name__ == '__main__':
    main()
