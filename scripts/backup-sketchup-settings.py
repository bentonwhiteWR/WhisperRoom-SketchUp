# -*- coding: utf-8 -*-
"""Copy SketchUp's preferences, keyboard shortcuts and templates into the repo.

    python backup-sketchup-settings.py            # back up into sketchup-settings/
    python backup-sketchup-settings.py --restore  # copy them back onto this machine

WHAT SKETCHUP ACTUALLY KEEPS, AND WHERE

Not the registry, despite what a lot of advice says. On Windows 2023/2024 it is
all in one file per version:

    %APPDATA%\\SketchUp\\SketchUp <year>\\SketchUp\\SharedPreferences.json

Preferences AND keyboard shortcuts, the latter as flat numbered entries under
"Windows Only" > "Settings" — Num_Shortcuts, then Shortcut_1 .. Shortcut_N, each
a single string. Templates are .skp files in the Templates folder beside it.

WHAT THIS DELIBERATELY DOES NOT COPY

  login_session.dat   the signed-in session. A credential. Never in a repo.
  WebCache-*/         browser cache, large and worthless.
  Plugins/            already in this repo as scripts/, and install-plugin.py
                      writes it. Copying it too would give two sources of truth.
  Classifications/    the stock IFC files, identical on every install.

RESTORING ONTO A NEW MACHINE overwrites SharedPreferences.json, so it takes
whatever preferences that machine had with it. SketchUp must be CLOSED — it
rewrites the file on exit and would put the old settings straight back.
"""
import json
import os
import shutil
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(REPO, 'sketchup-settings')
ROOT = os.path.join(os.environ.get('APPDATA', ''), 'SketchUp')

PREFS = 'SharedPreferences.json'
FOLDERS = ['Templates']          # Styles/Materials/Components are empty here

# SketchUp's OWN shortcuts export, from
# Window > Preferences > Shortcuts > Export. A UTF-16 INI with an [Accelerator]
# section and lines like "0 0 0 I selectImageIglooTool:".
#
# THIS IS THE ONE TO RESTORE FROM. Import it through the same dialog and
# SketchUp applies it properly. Copying SharedPreferences.json works too, but it
# takes every other preference with it and needs SketchUp closed — a blunt
# instrument where this is a scalpel.
#
# Drop the exported file anywhere below and this picks it up; it is looked for
# next to the repo and in Downloads.
ACCEL = 'Preferences.dat'
ACCEL_HINTS = [
    os.path.join(os.environ.get('USERPROFILE', ''), 'Downloads', ACCEL),
    os.path.join(REPO, ACCEL),
]


def versions():
    if not os.path.isdir(ROOT):
        return []
    return [d for d in sorted(os.listdir(ROOT))
            if d.lower().startswith('sketchup ')
            and os.path.isdir(os.path.join(ROOT, d, 'SketchUp'))]


def shortcut_list(prefs_path):
    """The shortcuts as readable lines, so they diff and can be read in a PR.

    The JSON keeps them as Shortcut_1..Shortcut_N in no useful order — 10 sorts
    before 2 — so they are numbered properly here. This file is a REPORT, not a
    restore source; restoring uses the JSON.
    """
    try:
        with open(prefs_path, encoding='utf-8') as f:
            d = json.load(f)
        s = d.get('Windows Only', {}).get('Settings', {})
        n = int(s.get('Num_Shortcuts', 0))
        return [s.get('Shortcut_%d' % i, '') for i in range(1, n + 1)]
    except Exception as e:
        print('  could not read shortcuts: %s' % e)
        return []


def backup():
    vs = versions()
    if not vs:
        sys.exit('No SketchUp profile found under %s' % ROOT)
    for v in vs:
        src = os.path.join(ROOT, v, 'SketchUp')
        out = os.path.join(DEST, v)
        os.makedirs(out, exist_ok=True)

        p = os.path.join(src, PREFS)
        if os.path.isfile(p):
            shutil.copy2(p, out)
            sc = shortcut_list(p)
            with open(os.path.join(out, 'shortcuts.txt'), 'w', encoding='utf-8') as f:
                f.write('%s — %d keyboard shortcuts\n' % (v, len(sc)))
                f.write('Read-only report. Restoring uses %s.\n\n' % PREFS)
                for i, line in enumerate(sc, 1):
                    f.write('%3d  %s\n' % (i, line))
            print('%-16s %s  + shortcuts.txt (%d)' % (v, PREFS, len(sc)))

        for folder in FOLDERS:
            s = os.path.join(src, folder)
            if not os.path.isdir(s):
                continue
            d = os.path.join(out, folder)
            if os.path.isdir(d):
                shutil.rmtree(d, ignore_errors=True)
            shutil.copytree(s, d)
            files = [f for _r, _d, fs in os.walk(d) for f in fs]
            size = sum(os.path.getsize(os.path.join(r, f))
                       for r, _d, fs in os.walk(d) for f in fs)
            print('%-16s %-12s %d file(s), %.1f MB' % ('', folder, len(files), size / 1e6))

    # SketchUp's own shortcuts export, if it has been made.
    found = next((p for p in ACCEL_HINTS if os.path.isfile(p)), None)
    if found:
        os.makedirs(DEST, exist_ok=True)
        shutil.copy2(found, os.path.join(DEST, ACCEL))
        n = accel_count(found)
        print('%-16s %s  (%s accelerators, SketchUp\'s own export)'
              % ('', ACCEL, n if n is not None else '?'))
    else:
        print('')
        print('NO %s FOUND — worth making one:' % ACCEL)
        print('  Window > Preferences > Shortcuts > Export, save it to Downloads,')
        print('  and re-run. It imports back through the same dialog, which is a')
        print('  cleaner restore than overwriting every preference at once.')

    print('')
    print('-> %s' % DEST.replace('\\', '/'))
    print('Commit it. login_session.dat, WebCache and Plugins are excluded by design.')


def accel_count(path):
    """Count= out of the [Accelerator] file. UTF-16, so decode before reading."""
    try:
        with open(path, 'rb') as f:
            text = f.read().decode('utf-16', errors='replace')
        for line in text.splitlines():
            if line.lower().startswith('count='):
                return int(line.split('=', 1)[1].strip())
    except Exception:
        return None
    return None


def restore():
    if not os.path.isdir(DEST):
        sys.exit('Nothing to restore from: %s' % DEST)
    print('SketchUp must be CLOSED. It rewrites SharedPreferences.json on exit')
    print('and will otherwise put the old settings straight back.')
    print('')
    acc = os.path.join(DEST, ACCEL)
    if os.path.isfile(acc):
        print('FOR SHORTCUTS ONLY, prefer SketchUp\'s own importer — no need to close it:')
        print('  Window > Preferences > Shortcuts > Import')
        print('  %s' % acc.replace('\\', '/'))
        print('')
    for v in sorted(os.listdir(DEST)):
        src = os.path.join(DEST, v)
        dst = os.path.join(ROOT, v, 'SketchUp')
        if not os.path.isdir(dst):
            print('%-16s no such SketchUp on this machine, skipped' % v)
            continue
        p = os.path.join(src, PREFS)
        if os.path.isfile(p):
            shutil.copy2(p, dst)
            print('%-16s %s restored' % (v, PREFS))
        for folder in FOLDERS:
            s = os.path.join(src, folder)
            if not os.path.isdir(s):
                continue
            d = os.path.join(dst, folder)
            os.makedirs(d, exist_ok=True)
            for f in os.listdir(s):
                shutil.copy2(os.path.join(s, f), d)
            print('%-16s %s restored (%d file(s))' % ('', folder, len(os.listdir(s))))


if __name__ == '__main__':
    restore() if '--restore' in sys.argv else backup()
