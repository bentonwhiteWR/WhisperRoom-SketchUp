# -*- coding: utf-8 -*-
"""Install the WhisperRoom Tools plugin into every SketchUp on this machine.

    python install-plugin.py

Copies wr_tools.rb, wr_tools/ AND every script in this folder into each SketchUp
Plugins folder, then restart SketchUp — the WhisperRoom menu and toolbar appear
under Extensions.

WHY THE SCRIPTS ARE BUNDLED NOW, AND WHY THAT DOES NOT BREAK LIVE EDITING

The plugin used to install wr_tools alone and read scripts/ live out of the git
checkout. Fine on a machine with the repo; useless to a teammate, who got a
panel with nothing in it.

So the scripts are copied in as well, and wr_tools/main.rb resolves its scripts
folder in this order:

    WR_SCRIPTS_DIR env var -> the repo checkout -> the bundled copy

The bundled copy is LAST. On a machine with the repo, the repo still wins, so
editing a script there takes effect on the next run with no reinstall. On a
machine without one, the bundled copy is used and everything works. Reverse that
order and every edit would silently do nothing until this script was re-run,
which is a miserable thing to debug.

RE-RUN THIS after pulling changes if you want the bundled copy refreshed. On
your own machine you rarely need to: the repo wins anyway.
"""
import os
import shutil
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
SRC = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.environ.get('APPDATA', ''), 'SketchUp')

# Libraries other scripts `load`, and the generated booth data. They travel with
# the scripts because the scripts load them; they just never show in the panel,
# which is wr_tools' SKIP list's job, not this script's.
SKIP_COPY = {'install-plugin.py'}


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


def copy_scripts(dst):
    """Every .rb in scripts/ into <plugin>/wr_tools/scripts/.

    Stale files are cleared first. A script deleted from the repo but left in
    the bundle would keep appearing in a teammate's panel and keep working,
    which is how two people end up running different code from the same button.
    """
    if os.path.isdir(dst):
        shutil.rmtree(dst, ignore_errors=True)
    os.makedirs(dst, exist_ok=True)
    n = 0
    for f in sorted(os.listdir(SRC)):
        if f in SKIP_COPY or not f.lower().endswith('.rb'):
            continue
        if not os.path.isfile(os.path.join(SRC, f)):
            continue
        shutil.copy2(os.path.join(SRC, f), dst)
        n += 1
    return n


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
            src_f = os.path.join(SRC, 'wr_tools', f)
            if os.path.isfile(src_f):
                shutil.copy2(src_f, dst)
        n = copy_scripts(os.path.join(dst, 'scripts'))
        print('installed -> %-40s  %d scripts bundled' % (name, n))

    print('')
    print('Restart SketchUp. Menu: Extensions > WhisperRoom')
    print('')
    print('Scripts folder resolution, in order:')
    print('   WR_SCRIPTS_DIR  ->  the repo checkout  ->  the bundled copy')
    print('This machine\'s repo scripts folder is')
    print('   %s' % SRC.replace('\\', '/'))
    print('so edits there take effect immediately, with no reinstall. A machine')
    print('without the repo falls back to the bundled copy and still works.')


if __name__ == '__main__':
    main()
