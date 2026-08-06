# -*- coding: utf-8 -*-
"""Install the WhisperRoom Tools plugin into every SketchUp on this machine.

    python install-plugin.py

Copies wr_tools.rb + wr_tools/ into each SketchUp Plugins folder. Run it once per
machine, then restart SketchUp — the WhisperRoom menu and toolbar appear under
Extensions. Re-run it after pulling changes to wr_tools itself; everything else
in scripts/ is read live and needs no reinstall.
"""
import os, shutil, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
SRC = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.environ.get('APPDATA', ''), 'SketchUp')


def installed_versions():
    """SketchUp versions present in Program Files, e.g. ['SketchUp 2024'].

    A freshly installed SketchUp has no %APPDATA%\\SketchUp profile until its
    first launch, so we can't rely on that folder existing.
    """
    out = []
    for base in (os.environ.get('ProgramFiles', ''),
                 os.environ.get('ProgramFiles(x86)', '')):
        root = os.path.join(base, 'SketchUp')
        if os.path.isdir(root):
            for entry in sorted(os.listdir(root)):
                if os.path.isfile(os.path.join(root, entry, 'SketchUp.exe')):
                    out.append(entry)
    return out


def main():
    targets = []
    if os.path.isdir(ROOT):
        for entry in sorted(os.listdir(ROOT)):
            plugins = os.path.join(ROOT, entry, 'SketchUp', 'Plugins')
            if os.path.isdir(plugins):
                targets.append((entry, plugins))

    if not targets:
        # SketchUp installed but never launched — create the profile folder it
        # would create itself on first run.
        versions = installed_versions()
        if not versions:
            sys.exit('No SketchUp found in Program Files and no profile at %s.' % ROOT)
        for v in versions:
            plugins = os.path.join(ROOT, v, 'SketchUp', 'Plugins')
            os.makedirs(plugins, exist_ok=True)
            targets.append((v + ' (created profile folder)', plugins))

    for name, plugins in targets:
        shutil.copy2(os.path.join(SRC, 'wr_tools.rb'), plugins)
        dst = os.path.join(plugins, 'wr_tools')
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(os.path.join(SRC, 'wr_tools')):
            shutil.copy2(os.path.join(SRC, 'wr_tools', f), dst)
        print('installed -> %s' % name)

    print('')
    print('Restart SketchUp. Menu: Extensions > WhisperRoom')
    print('')
    print('wr_tools/main.rb finds the scripts folder itself from a candidate list.')
    print('This repo\'s scripts folder is')
    print('   %s' % SRC.replace('\\', '/'))
    print('If that is not one of the candidates, set the WR_SCRIPTS_DIR environment')
    print('variable to it, or add it to CANDIDATES in wr_tools/main.rb.')


if __name__ == '__main__':
    main()
