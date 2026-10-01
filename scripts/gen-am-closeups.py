# -*- coding: utf-8 -*-
"""GENERATE scripts/am-closeups.json — the close-up spec am-closeup-export.rb reads.

    python scripts/gen-am-closeups.py [--csv PATH] [--check]

Two inputs, one output, so neither input is ever edited twice:

    shot-list.csv            the scoper's list: every shot's id, title, steps,
                             priority, variants and the prose for camera,
                             section, explode and callouts. The ONE source for
                             those words. It lives in the WhisperRoomQuote
                             forge folder (read here, never written).
    am-closeups-poses.json   the machine pose for each shot that has been
                             posed (parts, moves, ghosts, section, camera,
                             anchors). Hand-edited, in this repo.

    -> am-closeups.json      every shot in the CSV, its prose, its pose or
                             status "unposed", plus the rig settings and the
                             CSV's path and sha256 (so a stale spec is visible).

--check validates without writing: every pose names a shot the CSV has, every
selector names a role the pose stages, every regex compiles, every scale class
exists, every variant name is filename-safe, and pilot_variants exist.

The CSV path defaults to <Claude>/WhisperRoomQuote/.forge/scoper/am-closeups/
shot-list.csv, resolved from this repo's own location (laptop or desktop).
"""
import csv
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
POSES = os.path.join(HERE, 'am-closeups-poses.json')
OUT = os.path.join(HERE, 'am-closeups.json')


def default_csv():
    # scripts/ -> Sketchup/ (laptop) or Sketchup/WhisperRoom-SketchUp/ (desktop)
    up = os.path.dirname(HERE)
    for claude in (os.path.dirname(up), os.path.dirname(os.path.dirname(up))):
        p = os.path.join(claude, 'WhisperRoomQuote', '.forge', 'scoper', 'am-closeups', 'shot-list.csv')
        if os.path.isfile(p):
            return p
    return None


SAFE = re.compile(r'^[A-Za-z0-9][A-Za-z0-9 ._-]*$')


def selectors(obj):
    """Every dict under obj that names a 'part' (a selector)."""
    if isinstance(obj, dict):
        if 'part' in obj:
            yield obj
        for k, v in obj.items():
            if not str(k).startswith('_'):
                yield from selectors(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from selectors(v)


def regexes(obj):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k in ('match', 'find', 'within', 'keep') and isinstance(v, str):
                yield v
            elif not str(k).startswith('_'):
                yield from regexes(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from regexes(v)


def validate(rows, poses):
    errs = []
    rig = poses.get('rig', {})
    classes = rig.get('scale_classes', {})
    ids = {r['id'] for r in rows}
    for sid, pose in poses.get('poses', {}).items():
        if sid not in ids:
            errs.append('%s: posed but not in the CSV' % sid)
        variants = pose.get('variants') or {}
        if not variants:
            errs.append('%s: no variants' % sid)
        for pv in pose.get('pilot_variants', []):
            if pv not in variants:
                errs.append('%s: pilot variant %r is not a variant' % (sid, pv))
        base = pose.get('base') or {}
        for vn, var in variants.items():
            if not SAFE.match(vn):
                errs.append('%s: variant name %r is not filename-safe' % (sid, vn))
            if var.get('blocked'):
                continue
            merged = dict((k, v) for k, v in base.items() if not k.startswith('_'))
            merged.update((k, v) for k, v in var.items() if not k.startswith('_'))
            parts = merged.get('parts') or []
            if not parts:
                errs.append('%s:%s: no parts' % (sid, vn))
            roles = []
            for p in parts:
                if not p.get('role'):
                    errs.append('%s:%s: a part has no role' % (sid, vn))
                if not p.get('sources'):
                    errs.append('%s:%s: part %s has no sources' % (sid, vn, p.get('role')))
                for s in p.get('sources') or []:
                    if not any(k in s for k in ('def', 'file', 'find')):
                        errs.append('%s:%s: part %s has a source with no def/file/find' % (sid, vn, p.get('role')))
                    near = s.get('near')
                    if near and near.get('role') not in roles:
                        errs.append('%s:%s: part %s is near %r, which is not staged before it'
                                    % (sid, vn, p.get('role'), near.get('role')))
                roles.append(p.get('role'))
            for sel in selectors({k: v for k, v in merged.items() if k != 'parts'}):
                if sel['part'] not in roles:
                    errs.append('%s:%s: selector names role %r; staged roles are %s'
                                % (sid, vn, sel['part'], roles))
            for rx in regexes(merged):
                try:
                    re.compile(rx)
                except re.error as e:
                    errs.append('%s:%s: bad regex %r: %s' % (sid, vn, rx, e))
            sc = merged.get('scale')
            if isinstance(sc, str) and sc not in classes:
                errs.append('%s:%s: scale class %r not in %s' % (sid, vn, sc, sorted(classes)))
            if not merged.get('anchors'):
                errs.append('%s:%s: no anchors (the app has nothing to draw callouts at)' % (sid, vn))
    return errs


def main(argv):
    path = None
    check = '--check' in argv
    if '--csv' in argv:
        path = argv[argv.index('--csv') + 1]
    path = path or default_csv()
    if not path or not os.path.isfile(path):
        print('shot-list.csv not found; pass --csv PATH', file=sys.stderr)
        return 2
    raw = open(path, 'rb').read()
    rows = list(csv.DictReader(raw.decode('utf-8-sig').splitlines()))
    poses = json.load(open(POSES, encoding='utf-8'))
    errs = validate(rows, poses)
    for e in errs:
        print('ERROR ' + e, file=sys.stderr)
    if errs:
        return 1

    shots = {}
    for r in rows:
        pose = poses['poses'].get(r['id'])
        status = 'posed' if pose else ('blocked' if r.get('blocked_by') else 'unposed')
        shots[r['id']] = {
            'title': r['title'], 'group': r['group'], 'priority': r['priority'],
            'steps': r['steps'], 'booth_variants': r['booth_variants'],
            'variants_text': r['variants'], 'images': int(r['images'] or 0),
            'prose': {k: r[k] for k in ('show', 'ghost', 'hide', 'camera', 'projection',
                                         'section', 'explode', 'annotations')},
            'existing_source': r['existing_source'], 'blocked_by': r['blocked_by'],
            'video_qr': r['video_qr'], 'status': status, 'pose': pose,
        }
    doc = {
        '_generated': 'by scripts/gen-am-closeups.py. Do not edit; edit am-closeups-poses.json '
                      'or the shot list and re-run.',
        'version': 1,
        'source': {'csv': path.replace('\\', '/'), 'csv_sha256': hashlib.sha256(raw).hexdigest(),
                   'poses': 'scripts/am-closeups-poses.json'},
        'rig': poses['rig'],
        'shots': shots,
    }
    posed = [k for k, v in shots.items() if v['pose']]
    pilot = sum(len(v['pose'].get('pilot_variants', [])) for v in shots.values() if v['pose'])
    print('%d shots in the CSV, %d posed (%s), %d pilot image(s)'
          % (len(shots), len(posed), ', '.join(sorted(posed)), pilot))
    if check:
        print('check: OK (nothing written)')
        return 0
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(doc, f, indent=1, ensure_ascii=False)
        f.write('\n')
    print('wrote ' + OUT)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
