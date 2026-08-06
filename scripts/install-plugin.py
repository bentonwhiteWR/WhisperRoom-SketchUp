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


def main():
    if not os.path.isdir(ROOT):
        sys.exit('No SketchUp folder at %s — is SketchUp installed for this user?' % ROOT)

    targets = []
    for entry in sorted(os.listdir(ROOT)):
        plugins = os.path.join(ROOT, entry, 'SketchUp', 'Plugins')
        if os.path.isdir(plugins):
            targets.append((entry, plugins))
    if not targets:
        sys.exit('No Plugins folders found under %s' % ROOT)

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
    print('NOTE: wr_tools/main.rb hard-codes the scripts folder as')
    print('   %s' % SRC.replace('\\', '/'))
    print('If this repo lives elsewhere on this machine, edit SCRIPTS_DIR in')
    print('wr_tools/main.rb before installing.')


if __name__ == '__main__':
    main()
