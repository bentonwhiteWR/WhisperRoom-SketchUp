# -*- coding: utf-8 -*-
"""REPORT which documented external paths resolve on THIS machine. Read-only.

    python check-doc-paths.py            # scan the standard docs, print a table
    python check-doc-paths.py --all      # exit 0 even when paths are missing

Exit 0 when every checked path resolves, 1 when any is missing (--all forces 0).

WHY THIS EXISTS
---------------
Benton works across a laptop and a desktop with different drives mapped, and
the docs' path tables cannot be true on both machines at once. The Researcher's
31 Aug 2026 audit (.forge/researcher/proposal-image-step-timing.md par.4) found
every warm-start target of CLAUDE.md's path table missing on the desktop --
build-v2.js, the prior client configs, the Desktop\\WhisperRoom folder, the
shipped proposal packs -- so a fresh agent follows a dead path and hunts,
silently, for minutes, every session.

This script turns that hunt into one command. It reads the path-like strings
OUT OF THE DOCS THEMSELVES (so it cannot drift from them), resolves the
<CLAUDE> machine split the way CLAUDE.md says to, and prints EXISTS or MISSING
for each, with the doc and line it came from.

IT FIXES NOTHING, BY DESIGN. A path missing HERE may be alive on the other
machine; deleting or "correcting" it would destroy working instructions.
Report only -- the rewrite is a human decision (GOAL.md item 5).

WHAT IT SCANS
-------------
CLAUDE.md, reference/*.md, skills/*/SKILL.md, relative to the repo root this
script sits in. Three path shapes are recognised:

    C:\\...              absolute Windows paths (and P:\\ etc.)
    <CLAUDE>\\...        expanded against whichever machine root exists
    ...\\X               CLAUDE.md's table continuation rows -> <CLAUDE>\\X

Placeholder segments (<Client>, <client-slug>, <name>, ...) cannot be checked
literally; the deepest literal parent is checked instead and the row says so.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# The <CLAUDE> split, verbatim from CLAUDE.md's machine note: resolve it once
# to whichever root exists, then read every doc path against it.
CLAUDE_ROOTS = [
    ('laptop',  r'C:\Users\bento\Documents\Claude'),
    ('desktop', r'C:\Users\bento\OneDrive\Documents\Claude'),
]

DOC_GLOBS = ['CLAUDE.md', 'README.md',
             os.path.join('reference', '*.md'),
             os.path.join('skills', '*', 'SKILL.md')]

# A backslash Windows path (C:\..., P:\...), a <CLAUDE>-relative path, or a
# `...\X` continuation row. Forward-slash examples like C:/.../scripts/<name>.rb
# are deliberately NOT matched: they are illustrative, not locations.
#
# Paths in these docs live almost entirely inside `code spans`, and real ones
# contain spaces ("WhisperRoom Proposals", "Program Files") -- so code spans
# are read WHOLE (spaces allowed), and only the bare text outside them falls
# back to the no-spaces regex.
PREFIX_RE = re.compile(r'^(?:[A-Za-z]:\\|<CLAUDE>\\|\.\.\.\\)')
BARE_RE = re.compile(r'(?:[A-Za-z]:\\|<CLAUDE>\\|\.\.\.\\)[^\s`"\'|*?]+')
SPAN_RE = re.compile(r'`([^`]+)`')

PLACEHOLDER_RE = re.compile(r'<(?!CLAUDE>)[^>\\]+>')  # <Client>, <slug>, <year>...


def paths_in(line):
    """Every path-like string on a doc line, code spans read whole."""
    out = []
    for span in SPAN_RE.findall(line):
        if PREFIX_RE.match(span.strip()):
            out.append(span.strip())
    rest = SPAN_RE.sub(' ', line)
    out.extend(m.group(0) for m in BARE_RE.finditer(rest))
    return out


def docs():
    import glob
    out = []
    for g in DOC_GLOBS:
        out.extend(sorted(glob.glob(os.path.join(ROOT, g))))
    return out


def claude_root():
    for name, p in CLAUDE_ROOTS:
        if os.path.isdir(p):
            return name, p
    return None, None


def clean(raw):
    """Strip the markdown that clings to a matched path."""
    s = raw.rstrip('.,;:)')
    while s.endswith('**') or s.endswith('`'):
        s = s[:-2] if s.endswith('**') else s[:-1]
    return s.rstrip('.,;:)')


def check_one(path):
    """(status, checked_path). Placeholders check the deepest literal parent."""
    if PLACEHOLDER_RE.search(path):
        parts = path.split('\\')
        lit = []
        for p in parts:
            if PLACEHOLDER_RE.search(p):
                break
            lit.append(p)
        parent = '\\'.join(lit)
        if not parent or not lit[0].endswith(':'):
            return 'UNCHECKABLE', path
        tag = 'PARENT-EXISTS' if os.path.exists(parent) else 'PARENT-MISSING'
        return tag, parent
    return ('EXISTS' if os.path.exists(path) else 'MISSING'), path


def main(argv):
    force_zero = '--all' in argv
    root_name, root = claude_root()
    print('check-doc-paths -- which documented paths resolve on THIS machine')
    print('  repo: %s' % ROOT)
    if root:
        print('  <CLAUDE> resolves to the %s root: %s' % (root_name, root))
    else:
        print('  <CLAUDE> DOES NOT RESOLVE: neither machine root exists here')
        print('  (checked: %s)' % ' and '.join(p for _, p in CLAUDE_ROOTS))
    print('  This REPORTS only. A path missing here may be alive on the other')
    print('  machine -- do not delete doc entries on this evidence alone.')
    print('')

    missing = 0
    total = 0
    for doc in docs():
        rel = os.path.relpath(doc, ROOT)
        rows = []
        seen = set()
        for ln, line in enumerate(open(doc, encoding='utf-8'), 1):
            for raw in paths_in(line):
                raw = clean(raw)
                if len(raw) < 4:
                    continue
                path = raw
                note = ''
                if path.startswith('<CLAUDE>\\') or path.startswith('...\\'):
                    if not root:
                        rows.append((ln, raw, 'UNCHECKABLE (<CLAUDE> unresolved)', ''))
                        continue
                    tail = path.split('\\', 1)[1]
                    path = os.path.join(root, tail)
                    if raw.startswith('...\\'):
                        # '...' is prose shorthand: in CLAUDE.md's table it
                        # means <CLAUDE>, but elsewhere it can abbreviate a
                        # DEEPER folder. Say which expansion was checked.
                        note = " ('...' expanded against <CLAUDE>; the doc may mean a deeper folder)"
                status, checked = check_one(path)
                key = (status, checked)
                if key in seen:
                    continue
                seen.add(key)
                if checked != path:
                    note += ' (checked %s)' % checked
                rows.append((ln, raw, status, note))
        if not rows:
            continue
        print('%s' % rel)
        for ln, raw, status, note in rows:
            total += 1
            if 'MISSING' in status or 'UNCHECKABLE' in status:
                missing += 1
            print('  %-15s L%-5d %s%s' % (status, ln, raw, note))
        print('')

    print('%d path reference(s) checked, %d missing/uncheckable on this machine.'
          % (total, missing))
    if missing:
        print('Missing here is NOT proof a doc entry is wrong -- the other')
        print('machine may hold it. Flag suspects to Benton; edit nothing.')
    return 0 if (force_zero or missing == 0) else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
