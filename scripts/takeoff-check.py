# -*- coding: utf-8 -*-
"""Validate a take-off file, emit the lock file and the review sheet.

    python takeoff-check.py clients/<job>/takeoff.json
    python takeoff-check.py clients/<job>/takeoff.json --html [out.html]
    python takeoff-check.py --selftest

Pure Python, no SketchUp. Exit 0 = every invariant holds and
<takeoff>.lock.json was written next to the input. Exit 1 = at least one
invariant failed, each failure printed BY NAME, and no lock file is written
(a stale lock from an earlier good run is deleted, so the builder can never
build from numbers the checker has since rejected). Exit 2 = usage.

WHY THIS EXISTS — the 31 Aug 2026 failure, made structurally hard to repeat:

  1. The pen chains on the UIC job closed arithmetically — 10" + 17'3" + 10"
     = 18'11", exactly — and nothing checked that they closed. Reading 17'3"
     as the room width instead of the clear width BETWEEN the two heaters is
     ~8 feet wrong, and the dialog's closure check cannot catch it because a
     consistently wrong width still closes. Here the chain arithmetic is
     RECORDED in the file (a run's `parts` list) and REQUIRED to sum to the
     run's value, so transcribing 17'3" as the wall-to-wall width cannot
     validate.
  2. Placement numbers cannot be invented silently. Every dimension is a
     {v, src} pair; a door with no position fails by name; a value that had
     to be assumed is legal only as an explicit {"assumed": ..., "reason":
     ...} and is carried into the lock file flagged, so the builder can put
     an ASSUMED note in the model at the feature itself.

The format is normative in reference/takeoff-format.md; the worked example is
clients/uic-daley-library/takeoff.json (the real 31 Aug job). The builder —
scripts/build-takeoff.rb — consumes ONLY the lock file, so the dimension
grammar lives in exactly two places: parseLen in scripts/build-room.html and
parse_len here. The two are held identical by the shared vectors in
scripts/takeoff-vectors.json (run --selftest; open scripts/takeoff-vectors.html
for the JS side).
"""
import io
import json
import math
import os
import re
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
sys.stderr.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))

TOL = 0.02          # polygon closure, inches — matches WR_BuildRoom::TOL
PART_TOL = 0.001    # parts are stated numbers; a mismatch is a transcription
                    # error, not noise, so the tolerance is float dust only
DIR = {'E': (1, 0), 'W': (-1, 0), 'N': (0, 1), 'S': (0, -1)}
SRC_KINDS = ('pen', 'plan-vector', 'stated', 'assumed', 'default')
FEATURE_TYPES = ('heater', 'bulkhead', 'window')
HOUSE = {'thick': 4.0, 'door_h': 80.0, 'sill': 48.0}


# ---------------------------------------------------------------- grammar --

def parse_len(s):
    """Inches from a dimension string. The same grammar as parseLen in
    scripts/build-room.html:194 — 150, 150", 12'6", 12'-6", 12' 6 1/2",
    12.5', 12 1/2 all parse, and A BARE NUMBER IS INCHES. Returns None where
    the JS returns NaN. Held identical by scripts/takeoff-vectors.json."""
    if isinstance(s, (int, float)):
        return float(s) if math.isfinite(s) else None
    t = str(s).strip().lower()
    t = re.sub(r"[′’]", "'", t)
    t = re.sub(r'[″“”]', '"', t)
    t = re.sub(r'\s*(?:ft|feet|foot)\b', "'", t)
    t = re.sub(r'\s*(?:in|inch|inches)\b', '"', t)
    t = re.sub(r"'\s*-\s*", "' ", t).strip()
    if not t:
        return None
    feet, inch, seen = 0.0, 0.0, False
    m = re.match(r"^([0-9]*\.?[0-9]+)\s*'", t)
    if m:
        feet, seen = float(m.group(1)), True
        t = t[m.end():].strip()
    if t:
        m = re.match(r'^([0-9]*\.?[0-9]+)?\s*(?:([0-9]+)\s*/\s*([0-9]+))?\s*"?$', t)
        if not m or (m.group(1) is None and m.group(2) is None):
            return None
        try:
            inch = (float(m.group(1)) if m.group(1) else 0.0) + \
                   (float(m.group(2)) / float(m.group(3)) if m.group(2) else 0.0)
        except ZeroDivisionError:
            # JS gets Infinity from 3/0 and fails the isFinite gate; match it.
            return None
        seen = True
    if not seen:
        return None
    v = feet * 12.0 + inch
    return v if math.isfinite(v) else None


def arch(n):
    """12'-6" from 150.0 — same display rule as the dialog."""
    neg = n < 0
    n = abs(n)
    f = int(n // 12)
    i = round((n - f * 12) * 10) / 10
    if i >= 12:
        f, i = f + 1, i - 12
    s = ('%g' % i) if i % 1 else str(int(i))
    return ('-' if neg else '') + "%d'-%s\"" % (f, s)


# ------------------------------------------------------------- validation --

class Check:
    """Collects failures by name. One instance per file."""

    def __init__(self):
        self.errors = []     # invariant failures — any one blocks the lock
        self.assumed = []    # the ASSUMED/DEFAULT inventory
        self.infos = []      # passing checks worth printing (chains closed…)

    def fail(self, name, msg):
        self.errors.append((name, msg))

    def ok(self, name, msg):
        self.infos.append((name, msg))

    def flag(self, path, kind, value_in, reason):
        self.assumed.append({'path': path, 'kind': kind,
                             'value_in': value_in, 'reason': reason})


def norm_value(ck, path, obj, required=True, allow_default=False):
    """A {v, src} / {assumed, reason} object -> normalized dict or None.

    Returns {'in': float, 'src': str, 'flag': None|'assumed'|'default',
             'reason': str|None, 'parts': [floats]|None, 'note': str|None}.
    Every failure is recorded by name; None means the value is unusable.
    """
    if obj is None:
        if required:
            ck.fail(path, 'missing — measure it, or mark it assumed with a reason')
        return None
    if isinstance(obj, (int, float, str)):
        ck.fail(path, 'bare value %r has no src — every dimension is a {v, src} pair'
                % (obj,))
        return None
    if 'assumed' in obj:
        v = parse_len(obj['assumed'])
        if v is None:
            ck.fail(path, 'assumed value %r does not parse' % (obj['assumed'],))
            return None
        reason = str(obj.get('reason', '')).strip()
        if not reason:
            ck.fail(path, 'assumed with no reason — a recorded assumption is legal, '
                          'a silent one is not')
            return None
        ck.flag(path, 'assumed', v, reason)
        return {'in': v, 'src': 'assumed', 'flag': 'assumed', 'reason': reason,
                'parts': None, 'note': obj.get('note')}
    if 'v' not in obj:
        ck.fail(path, 'no v and no assumed — nothing to build from')
        return None
    v = parse_len(obj['v'])
    if v is None:
        ck.fail(path, 'value %r does not parse (grammar: 150, 150", 12\'6", '
                      '12\'-6", 12\' 6 1/2", 12.5\'; bare number = inches)'
                % (obj['v'],))
        return None
    src = str(obj.get('src', '')).strip()
    kind = src.split(' ', 1)[0] if src else ''
    if kind not in SRC_KINDS:
        ck.fail(path, 'src %r missing or not one of %s — where did this number '
                      'come from?' % (src, '/'.join(SRC_KINDS)))
        return None
    flag = None
    reason = obj.get('reason') or obj.get('note')
    if kind == 'assumed':
        if not (reason and str(reason).strip()):
            ck.fail(path, 'src "assumed" with no reason')
            return None
        flag = 'assumed'
        ck.flag(path, 'assumed', v, str(reason))
    elif kind == 'default':
        if not (reason and str(reason).strip()):
            ck.fail(path, 'src "default" must name the default it uses '
                          '(note or reason)')
            return None
        flag = 'default'
        ck.flag(path, 'default', v, str(reason))
    parts = None
    if 'parts' in obj:
        parts = []
        bad = False
        for k, p in enumerate(obj['parts']):
            pv = parse_len(p)
            if pv is None:
                ck.fail('%s parts[%d]' % (path, k), 'part %r does not parse' % (p,))
                bad = True
            else:
                parts.append(pv)
        if not bad:
            total = sum(parts)
            if abs(total - v) > PART_TOL:
                ck.fail('%s parts' % path,
                        'parts %s sum to %s but v is %s — the chain does not '
                        'close; one of these numbers is transcribed wrong'
                        % (' + '.join(arch(p) for p in parts),
                           arch(total), arch(v)))
            else:
                ck.ok('%s parts' % path,
                      '%s = %s — chain closes exactly'
                      % (' + '.join(arch(p) for p in parts), arch(v)))
    return {'in': v, 'src': src, 'flag': flag,
            'reason': str(reason) if reason else None,
            'parts': parts, 'note': obj.get('note')}


def polygon(runs):
    """[(x, y)] interior vertices from normalized runs, or None if a direction
    is bad. Closure is the caller's check — same walk as WR_BuildRoom.polygon."""
    pts = [(0.0, 0.0)]
    x = y = 0.0
    for r in runs:
        d = DIR.get(r['d'])
        if d is None:
            return None
        x += d[0] * r['in']
        y += d[1] * r['in']
        pts.append((x, y))
    return pts


def check_room(ck, room, idx):
    """Validate one room; returns the normalized lock dict (some fields may be
    None when the room is failing — the lock is only written on exit 0)."""
    name = str(room.get('name', '')).strip() or 'room %d' % idx
    out = {'name': name}

    runs_in = room.get('runs') or []
    if len(runs_in) < 3:
        ck.fail('%s runs' % name, 'a room needs at least 3 wall runs, got %d'
                % len(runs_in))
    runs = []
    for i, r in enumerate(runs_in):
        path = '%s run %d' % (name, i)
        d = str(r.get('d', '')).strip().upper()
        if d not in DIR:
            ck.fail(path, 'direction %r is not one of E/S/W/N' % (r.get('d'),))
            continue
        nv = norm_value(ck, path, r)
        if nv is None:
            continue
        if nv['in'] <= 0:
            ck.fail(path, 'run length must be positive, got %s' % arch(nv['in']))
            continue
        nv['d'] = d
        runs.append(nv)
    out['runs'] = runs

    # Polygon closure — the same invariant the dialog enforces, now at intake.
    # Opposite chains stating the same span (window wall vs door wall) are
    # runs of the same polygon, so their agreement IS this check.
    if len(runs) == len(runs_in) and runs:
        pts = polygon(runs)
        ex, ey = pts[-1]
        if abs(ex) > TOL or abs(ey) > TOL:
            ck.fail('%s polygon' % name,
                    'the runs do not close — out by %s east-west and %s '
                    'north-south. A chain that does not close means a wall '
                    'face was misread; fix the take-off, do not build'
                    % (arch(abs(ex)), arch(abs(ey))))
            pts = None
        else:
            ck.ok('%s polygon' % name, '%d runs, closes to %.2f"'
                  % (len(runs), math.hypot(ex, ey)))
        out['polygon'] = [[round(x, 4), round(y, 4)] for x, y in pts[:-1]] \
            if pts else None
    else:
        out['polygon'] = None

    # Ceiling — mandatory. The constraint that disqualifies a booth fastest.
    ceil = norm_value(ck, '%s ceiling' % name, room.get('ceiling'))
    out['ceiling'] = ceil

    # Doors. `at` must be measured or explicitly assumed — a door with no
    # position at all fails by name (the dialog invented at:36" here once).
    doors = []
    for j, d in enumerate(room.get('doors') or []):
        path = '%s door %d' % (name, j)
        run_i = d.get('run')
        if not (isinstance(run_i, int) and 0 <= run_i < len(runs)):
            ck.fail(path, 'run %r is not an index into the %d runs'
                    % (run_i, len(runs)))
            continue
        w = norm_value(ck, '%s width' % path, d.get('w'))
        if 'at' not in d or d.get('at') is None:
            ck.fail('%s at' % path,
                    'no position on run %d. Measure corner -> near jamb, or '
                    'mark it assumed with a reason.' % run_i)
            continue
        at = norm_value(ck, '%s at' % path, d.get('at'))
        h = norm_value(ck, '%s height' % path, d.get('h'), required=False)
        if h is None and not ck_has_error(ck, '%s height' % path):
            # No height given at all: the house default, loudly.
            h = {'in': HOUSE['door_h'], 'src': 'default', 'flag': 'default',
                 'reason': 'standard leaf, not measured', 'parts': None,
                 'note': None}
            ck.flag('%s height' % path, 'default', h['in'], h['reason'])
        if w is None or at is None or h is None:
            continue
        run_len = runs[run_i]['in']
        if w['in'] <= 0:
            ck.fail('%s width' % path, 'must be positive')
            continue
        # The corner rule. wall_run cannot cut an opening that touches a
        # corner (the mitre owns the corner), and the silent version of this
        # failure — leaf drawn, wall solid — is the defect this replaces.
        if at['in'] < TOL or at['in'] + w['in'] > run_len - TOL:
            ck.fail(path,
                    'touches the corner of run %d (at %s + width %s vs run '
                    '%s) — the wall cut cannot reach a corner; move it or '
                    'shrink it' % (run_i, arch(at['in']), arch(w['in']),
                                   arch(run_len)))
            continue
        doors.append({'run': run_i, 'at_in': at['in'], 'at_src': at['src'],
                      'at_flag': at['flag'], 'at_reason': at['reason'],
                      'w_in': w['in'], 'w_src': w['src'], 'w_flag': w['flag'],
                      'h_in': h['in'], 'h_src': h['src'], 'h_flag': h['flag'],
                      'h_reason': h['reason'],
                      'hinge': 'far' if d.get('hinge') == 'far' else 'near'})
    # Door overlap on a shared run.
    spans = {}
    for dd in doors:
        spans.setdefault(dd['run'], []).append((dd['at_in'],
                                                dd['at_in'] + dd['w_in']))
    for run_i, ss in spans.items():
        ss.sort()
        for (a0, a1), (b0, b1) in zip(ss, ss[1:]):
            if b0 < a1 - TOL:
                ck.fail('%s doors' % name,
                        'two doors on run %d overlap (%s..%s and %s..%s)'
                        % (run_i, arch(a0), arch(a1), arch(b0), arch(b1)))
    out['doors'] = doors

    # Features: flagged massing, not furniture. Their job is to occupy
    # footprint so booth-fit math is honest.
    feats = []
    for j, f in enumerate(room.get('features') or []):
        t = str(f.get('type', '')).strip()
        path = '%s feature %d (%s)' % (name, j, t or '?')
        if t not in FEATURE_TYPES:
            ck.fail(path, 'type %r is not one of %s' % (t, '/'.join(FEATURE_TYPES)))
            continue
        run_i = f.get('run')
        if not (isinstance(run_i, int) and 0 <= run_i < len(runs)):
            ck.fail(path, 'run %r is not an index into the %d runs'
                    % (run_i, len(runs)))
            continue
        ff = {'type': t, 'run': run_i, 'note': f.get('note')}
        ok = True
        for key, req in (('from', True),
                         ('length' if t != 'window' else 'width', True),
                         ('depth', t == 'heater'),
                         ('head', t == 'bulkhead'),
                         ('sill', False)):
            if not req and key not in f:
                continue
            nv = norm_value(ck, '%s %s' % (path, key), f.get(key), required=req)
            if nv is None:
                ok = req and False or ok if not req else False
                if req:
                    ok = False
                continue
            ff[key + '_in'] = nv['in']
            ff[key + '_flag'] = nv['flag']
        if not ok:
            continue
        run_len = runs[run_i]['in'] if run_i < len(runs) else 0
        span_key = 'length_in' if t != 'window' else 'width_in'
        if ff.get('from_in', 0) + ff.get(span_key, 0) > run_len + TOL:
            ck.fail(path, 'from %s + %s %s overruns run %d (%s)'
                    % (arch(ff.get('from_in', 0)), span_key.replace('_in', ''),
                       arch(ff.get(span_key, 0)), run_i, arch(run_len)))
            continue
        feats.append(ff)
    out['features'] = feats

    for key in ('thick', 'sill'):
        nv = norm_value(ck, '%s %s' % (name, key), room.get(key), required=False)
        out[key + '_in'] = nv['in'] if nv else HOUSE[key]

    org = room.get('origin')
    if org is not None:
        if (isinstance(org, list) and len(org) == 2
                and all(isinstance(v, (int, float)) for v in org)):
            out['origin'] = [float(org[0]), float(org[1])]
        else:
            ck.fail('%s origin' % name, 'origin must be [x, y] in inches, got %r'
                    % (org,))
    out['notes'] = [str(n) for n in (room.get('notes') or [])]
    return out


def ck_has_error(ck, path):
    return any(n == path for n, _ in ck.errors)


def check_file(data, path='takeoff.json'):
    """The whole file -> (Check, lock dict)."""
    ck = Check()
    if not isinstance(data, dict):
        ck.fail(path, 'top level must be an object')
        return ck, None
    job = str(data.get('job', '')).strip()
    if not job:
        ck.fail('job', 'missing — name the job (the clients/<job>/ folder)')
    rooms_in = data.get('rooms')
    if not rooms_in:
        ck.fail('rooms', 'no rooms — nothing to check')
        return ck, None
    names = set()
    rooms = []
    for i, room in enumerate(rooms_in):
        r = check_room(ck, room, i)
        if r['name'] in names:
            ck.fail(r['name'], 'duplicate room name — names must be unique, '
                               'they are how the model is read back')
        names.add(r['name'])
        rooms.append(r)
    lock = {
        'format': 1,
        'job': job,
        'title': data.get('title'),
        'source': os.path.basename(path),
        'anchor': data.get('anchor'),
        'sources': data.get('sources'),
        'interpretations': data.get('interpretations'),
        'rooms': rooms,
        'assumed_inventory': ck.assumed,
    }
    return ck, lock


# ---------------------------------------------------------------- reports --

def print_report(ck, lock, path):
    print('')
    print('TAKE-OFF CHECK  %s' % path)
    print('')
    for name, msg in ck.infos:
        print('  ok    %-28s %s' % (name, msg))
    for name, msg in ck.errors:
        print('  FAIL  %-28s %s' % (name, msg))
    print('')
    if ck.assumed:
        print('  ASSUMED / DEFAULT — %d value(s), confirm before quoting:' % len(ck.assumed))
        for a in ck.assumed:
            print('    %s %s — %s (%s)' % (a['kind'].upper(), a['path'],
                                           arch(a['value_in']), a['reason']))
    else:
        print('  ASSUMED / DEFAULT — none. Every value is measured or stated.')
    print('')
    if ck.errors:
        print('  %d invariant(s) failed — no lock file written; nothing builds '
              'until these are fixed by name.' % len(ck.errors))
    else:
        n = sum(len(r.get('doors') or []) for r in lock['rooms'])
        print('  %d room(s), %d door(s) — valid. Lock file written.' %
              (len(lock['rooms']), n))
    print('')


# ------------------------------------------------------------ review html --

def _svg_room(room):
    """A to-scale SVG plan of one room: polygon, doors, features, and a chain
    row per run (parts inside, overall outside). 1 unit = 1 inch."""
    poly = room.get('polygon')
    if not poly:
        return ('<p style="padding:30px;color:var(--bad)" class="mono">'
                'polygon does not close — nothing to draw</p>')
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    # Model y is north-up; SVG y is down. Flip.
    def P(x, y):
        return (x, (y1 - y))
    m = max(56.0, (x1 - x0) * 0.28)
    vb = '%.1f %.1f %.1f %.1f' % (x0 - m, -m, (x1 - x0) + 2 * m, (y1 - y0) + 2 * m)
    out = ['<svg viewBox="%s" role="img" aria-label="Plan of %s">' % (vb, esc(room['name']))]
    d = ' '.join('%s%.1f,%.1f' % ('M' if i == 0 else 'L', *P(*p))
                 for i, p in enumerate(poly)) + ' Z'
    out.append('<path d="%s" fill="var(--solid)" stroke="var(--ink)" '
               'stroke-width="1.6"/>' % d)

    pts = poly + [poly[0]]
    cx, cy = (x0 + x1) / 2.0, (y1 + min(ys)) / 2.0

    def run_geom(i):
        ax, ay = pts[i]
        bx, by = pts[i + 1]
        ux, uy = bx - ax, by - ay
        ln = math.hypot(ux, uy) or 1.0
        ux, uy = ux / ln, uy / ln
        nx, ny = -uy, ux
        mx, my = (ax + bx) / 2.0, (ay + by) / 2.0
        if (mx - cx) * nx + (my - (y0 + y1) / 2.0) * ny < 0:
            nx, ny = -nx, -ny
        return (ax, ay), (ux, uy), (nx, ny), ln

    for i, r in enumerate(room['runs']):
        if i + 1 >= len(pts):
            break
        (ax, ay), (ux, uy), (nx, ny), ln = run_geom(i)
        rows = [(18.0, r['parts'], 6.5)] if r.get('parts') else []
        rows.append((18.0 + (16.0 if r.get('parts') else 0.0), [r['in']], 8.0))
        for off, vals, fs in rows:
            cur = 0.0
            j0x, j0y = ax + nx * off, ay + ny * off
            jex, jey = ax + ux * ln + nx * off, ay + uy * ln + ny * off
            sx0, sy0 = P(j0x, j0y)
            sx1, sy1 = P(jex, jey)
            out.append('<path d="M%.1f,%.1f L%.1f,%.1f" stroke="var(--accent)" '
                       'stroke-width=".7" fill="none"/>' % (sx0, sy0, sx1, sy1))
            for v in vals:
                tx = ax + ux * (cur + v / 2.0) + nx * (off + fs)
                ty = ay + uy * (cur + v / 2.0) + ny * (off + fs)
                stx, sty = P(tx, ty)
                rot = ''
                if abs(uy) > 0.5:
                    rot = ' transform="rotate(-90 %.1f %.1f)"' % (stx, sty)
                out.append('<text x="%.1f" y="%.1f" font-size="%g" '
                           'fill="var(--accent)" text-anchor="middle"%s>%s</text>'
                           % (stx, sty, fs, rot, esc(arch(v))))
                cur += v
    for dd in room.get('doors') or []:
        i = dd['run']
        if i + 1 >= len(pts):
            continue
        (ax, ay), (ux, uy), (nx, ny), ln = run_geom(i)
        j0 = (ax + ux * dd['at_in'], ay + uy * dd['at_in'])
        j1 = (ax + ux * (dd['at_in'] + dd['w_in']), ay + uy * (dd['at_in'] + dd['w_in']))
        s0, s1 = P(*j0), P(*j1)
        out.append('<path d="M%.1f,%.1f L%.1f,%.1f" stroke="var(--accent)" '
                   'stroke-width="3.4" fill="none"/>' % (s0[0], s0[1], s1[0], s1[1]))
        lab = arch(dd['w_in']) + (' ASSUMED at' if dd['at_flag'] else '')
        mx, my = P((j0[0] + j1[0]) / 2 - nx * 8, (j0[1] + j1[1]) / 2 - ny * 8)
        out.append('<text x="%.1f" y="%.1f" font-size="6.5" fill="var(--%s)" '
                   'text-anchor="middle">%s</text>'
                   % (mx, my, 'warn' if dd['at_flag'] else 'ink-2', esc(lab)))
    for f in room.get('features') or []:
        i = f['run']
        if i + 1 >= len(pts):
            continue
        (ax, ay), (ux, uy), (nx, ny), ln = run_geom(i)
        span = f.get('length_in', f.get('width_in', 0.0))
        dep = f.get('depth_in', 4.0)
        c0 = (ax + ux * f.get('from_in', 0.0), ay + uy * f.get('from_in', 0.0))
        pts4 = [c0, (c0[0] + ux * span, c0[1] + uy * span),
                (c0[0] + ux * span - nx * dep, c0[1] + uy * span - ny * dep),
                (c0[0] - nx * dep, c0[1] - ny * dep)]
        d4 = ' '.join('%s%.1f,%.1f' % ('M' if k == 0 else 'L', *P(*p))
                      for k, p in enumerate(pts4)) + ' Z'
        dash = ' stroke-dasharray="5 4"' if f['type'] == 'bulkhead' else ''
        out.append('<path d="%s" fill="none" stroke="var(--ink-2)" '
                   'stroke-width=".8"%s/>' % (d4, dash))
        mx, my = P(c0[0] + ux * span / 2 - nx * (dep + 5),
                   c0[1] + uy * span / 2 - ny * (dep + 5))
        out.append('<text x="%.1f" y="%.1f" font-size="6.5" fill="var(--ink-2)" '
                   'text-anchor="middle">%s</text>' % (mx, my, esc(f['type'])))
    out.append('</svg>')
    return '\n'.join(out)


def esc(s):
    return (str(s).replace('&', '&amp;').replace('<', '&lt;')
            .replace('>', '&gt;').replace('"', '&quot;'))


CSS = """
  :root{--bg:#f2f3f5;--card:#fff;--ink:#14181c;--ink-2:#626c75;--ink-3:#949ea6;
    --rule:#dfe3e7;--accent:#ee6216;--ok:#2c6e49;--bad:#b03027;--warn:#9a6a00;
    --warn-bg:#fdf4e0;--solid:#e3e8ec;--field:#fff;}
  @media (prefers-color-scheme:dark){:root{--bg:#1b1e21;--card:#23272b;--ink:#e6eaed;
    --ink-2:#98a2aa;--ink-3:#6d777e;--rule:#32383d;--accent:#ff7a33;--ok:#63b98a;
    --bad:#e8705f;--warn:#e0b45a;--warn-bg:#2c2820;--solid:#2c3237;--field:#191c1f;}}
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--ink);
    font-family:"Segoe UI",system-ui,sans-serif;font-size:13px;line-height:1.45;
    -webkit-font-smoothing:antialiased}
  .mono,.lab,.arch,.tag,td,th{font-family:Consolas,ui-monospace,monospace}
  .wrap{max-width:980px;margin:0 auto;padding:18px 18px 60px}
  header{padding:4px 0 12px;border-bottom:1px solid var(--rule);margin-bottom:16px}
  header b{font-size:16px;font-weight:650}
  header span{color:var(--ink-3);margin-left:8px;font-size:12px}
  .srcline{margin-top:4px;font-size:11.5px;color:var(--ink-2);font-family:Consolas,monospace}
  .lab{font-size:9.5px;letter-spacing:.13em;text-transform:uppercase;color:var(--ink-3);
    display:block;margin-bottom:6px}
  .tag{font-size:9.5px;letter-spacing:.11em;padding:1px 7px;border-radius:2px;color:#fff}
  .cl{border:1px solid var(--rule);border-radius:5px;padding:10px 12px;background:var(--card);
    margin-bottom:10px}
  .cl.good{border-color:var(--ok)} .cl.good .tag{background:var(--ok)}
  .cl.bad{border-color:var(--bad)} .cl.bad .tag{background:var(--bad)}
  .cl.warn{border-color:var(--warn)} .cl.warn .tag{background:var(--warn)}
  .cl p{margin:7px 0 0;font-size:11.5px;color:var(--ink-2)}
  .cl .mono{color:var(--ink)}
  .b{display:inline-block;font-family:Consolas,monospace;font-size:9px;letter-spacing:.08em;
    padding:0 5px;border-radius:2px;vertical-align:1px;margin-left:6px}
  .b.pen{background:var(--solid);color:var(--ink-2);border:1px solid var(--rule)}
  .b.vec{background:transparent;color:var(--ok);border:1px solid var(--ok)}
  .b.asm{background:var(--warn-bg);color:var(--warn);border:1px solid var(--warn);font-weight:700}
  .b.def{background:transparent;color:var(--bad);border:1px solid var(--bad)}
  section.room{border:1px solid var(--rule);border-radius:6px;background:var(--card);
    margin-bottom:18px;overflow:hidden}
  .room h2{margin:0;padding:10px 14px;font-size:13px;font-weight:650;
    border-bottom:1px solid var(--rule);display:flex;gap:10px;align-items:baseline}
  .room h2 .mono{color:var(--ink-3);font-weight:400;font-size:11px}
  .roomgrid{display:grid;grid-template-columns:1fr;gap:0}
  @media(min-width:760px){.roomgrid{grid-template-columns:minmax(0,1fr) 340px}}
  .plan{padding:14px;display:grid;place-items:center;background:var(--bg)}
  .plan svg{width:100%;height:auto;max-width:560px}
  .facts{padding:12px 14px;border-left:1px solid var(--rule)}
  table{width:100%;border-collapse:collapse;margin-bottom:12px}
  td{padding:3px 0;font-size:11.5px;vertical-align:top}
  td.k{color:var(--ink-2);white-space:nowrap;padding-right:10px}
  td.v{color:var(--ink)}
  .inv{border:1px solid var(--warn);background:var(--warn-bg);border-radius:6px;
    padding:12px 14px;margin-bottom:18px}
  .inv .tag{background:var(--warn)}
  .inv ul{margin:8px 0 0;padding-left:18px}
  .inv li{margin:3px 0;font-size:11.5px}
  .inv .mono{color:var(--ink)}
  .inv.none{border-color:var(--ok);background:transparent}
  .inv.none .tag{background:var(--ok)}
  footer{position:sticky;bottom:0;background:var(--card);border-top:1px solid var(--rule);
    padding:11px 18px;display:flex;gap:10px;align-items:center}
  footer .hint{font-size:11px;color:var(--ink-3);font-family:Consolas,monospace}
  text{font-family:Consolas,ui-monospace,monospace}
"""


def badge(src, flag):
    if flag == 'assumed':
        return '<span class="b asm">ASSUMED</span>'
    if flag == 'default':
        return '<span class="b def">DEFAULT</span>'
    kind = (src or '').split(' ', 1)[0]
    if kind == 'plan-vector':
        return '<span class="b vec">VECTOR</span>'
    if kind == 'stated':
        return '<span class="b pen">STATED</span>'
    return '<span class="b pen">PEN</span>'


def html_report(ck, lock, path):
    """The review sheet — the page Gabe reads. Look approved via
    .forge/scoper/takeoff-review.mockup.html; same style tokens as
    scripts/build-room.html."""
    job = lock.get('job') if lock else '?'
    h = ['<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">',
         '<meta name="viewport" content="width=device-width,initial-scale=1">',
         '<title>Take-off review — %s</title><style>%s</style></head><body>' % (esc(job), CSS),
         '<div class="wrap">',
         '<header><b>Take-off review</b><span>%s%s</span>' % (
             esc(job), esc(' — ' + lock['title']) if lock and lock.get('title') else ''),
         '<div class="srcline">source: %s%s%s</div></header>' % (
             esc(path),
             esc(' · images ' + ', '.join(lock['sources'])) if lock and lock.get('sources') else '',
             esc(' · anchor: ' + lock['anchor']) if lock and lock.get('anchor') else '')]

    if ck.assumed:
        h.append('<div class="inv"><span class="tag">%d ASSUMED / DEFAULT VALUE%s '
                 '— CONFIRM BEFORE QUOTING</span><ul>'
                 % (len(ck.assumed), 'S' if len(ck.assumed) != 1 else ''))
        for a in ck.assumed:
            h.append('<li><span class="mono">%s</span> — <b>%s %s</b>: %s</li>'
                     % (esc(a['path']), a['kind'].upper(), esc(arch(a['value_in'])),
                        esc(a['reason'])))
        h.append('</ul><p style="margin:8px 0 0;font-size:11px;color:var(--ink-2)">'
                 'Each of these builds with an ASSUMED note placed in the model at '
                 'the feature itself. Nothing else on this job is assumed.</p></div>')
    else:
        h.append('<div class="inv none"><span class="tag">NO ASSUMED VALUES</span>'
                 '<p style="margin:8px 0 0;font-size:11px;color:var(--ink-2)">'
                 'Every value on this job is measured or stated.</p></div>')

    err_by_room = {}
    for n, msg in ck.errors:
        room = n.split(' ')[0]
        err_by_room.setdefault(room, []).append((n, msg))
    ok_by_room = {}
    for n, msg in ck.infos:
        room = n.split(' ')[0]
        ok_by_room.setdefault(room, []).append((n, msg))

    ready = blocked = 0
    for room in (lock['rooms'] if lock else []):
        name = room['name']
        errs = [e for k, e in err_by_room.items() if name.startswith(k)] and \
               [it for k, v in err_by_room.items() if name.startswith(k) for it in v] or []
        oks = [it for k, v in ok_by_room.items() if name.startswith(k) for it in v]
        if errs:
            blocked += 1
        else:
            ready += 1
        h.append('<section class="room"><h2>%s <span class="mono">%s</span></h2>'
                 '<div class="roomgrid"><div class="plan">%s</div><div class="facts">'
                 % (esc(name),
                    esc('; '.join(room.get('notes') or [])[:110]),
                    _svg_room(room)))
        h.append('<span class="lab">Stated values</span><table>')
        for i, r in enumerate(room['runs']):
            extra = ''
            if r.get('parts'):
                extra = ('<br>= ' + ' + '.join(arch(p) for p in r['parts'])
                         + (' — ' + esc(r['note']) if r.get('note') else ''))
            elif r.get('note'):
                extra = ' — ' + esc(r['note'])
            h.append('<tr><td class="k">run %d (%s)</td><td class="v">%s %s%s</td></tr>'
                     % (i, r['d'], esc(arch(r['in'])), badge(r['src'], r['flag']), extra))
        c = room.get('ceiling')
        if c:
            h.append('<tr><td class="k">ceiling</td><td class="v">%s %s%s</td></tr>'
                     % (esc(arch(c['in'])), badge(c['src'], c['flag']),
                        ' — ' + esc(c['note']) if c.get('note') else ''))
        for j, dd in enumerate(room.get('doors') or []):
            h.append('<tr><td class="k">door %d</td><td class="v">%s wide %s, at %s %s, '
                     'height %s %s</td></tr>'
                     % (j, esc(arch(dd['w_in'])), badge(dd['w_src'], dd['w_flag']),
                        esc(arch(dd['at_in'])), badge(dd['at_src'], dd['at_flag']),
                        esc(arch(dd['h_in'])), badge(dd['h_src'], dd['h_flag'])))
        for f in room.get('features') or []:
            span = f.get('length_in', f.get('width_in', 0.0))
            h.append('<tr><td class="k">%s</td><td class="v">run %d, %s long%s%s</td></tr>'
                     % (esc(f['type']), f['run'], esc(arch(span)),
                        ', %s deep' % esc(arch(f['depth_in'])) if f.get('depth_in') else '',
                        ', head %s' % esc(arch(f['head_in'])) if f.get('head_in') else ''))
        h.append('</table>')
        for n, msg in oks:
            h.append('<div class="cl good"><span class="tag">%s OK</span><p>%s</p></div>'
                     % (esc(n.replace(name, '').strip().upper() or 'CHECK'), esc(msg)))
        for n, msg in errs:
            h.append('<div class="cl bad"><span class="tag">DOES NOT VALIDATE</span>'
                     '<p><span class="mono">%s</span> — %s</p></div>' % (esc(n), esc(msg)))
        for note in room.get('notes') or []:
            h.append('<div class="cl warn"><span class="tag">INTERPRETATION — CONFIRM</span>'
                     '<p>%s</p></div>' % esc(note))
        h.append('</div></div></section>')

    h.append('<footer><span class="hint">%d room%s ready%s · %d assumed value%s '
             'will be flagged in the model</span></footer>'
             % (ready, '' if ready == 1 else 's',
                ' · %d blocked by named errors' % blocked if blocked else '',
                len(ck.assumed), '' if len(ck.assumed) == 1 else 's'))
    h.append('</div></body></html>')
    return '\n'.join(h)


# --------------------------------------------------------------- selftest --

def selftest():
    """Grammar parity vectors + the invariants that matter most, exercised on
    minimal fixtures. Exit 0 all pass."""
    vecs = json.load(open(os.path.join(HERE, 'takeoff-vectors.json'),
                          encoding='utf-8'))
    fails = 0
    for v in vecs['vectors']:
        got = parse_len(v['s'])
        want = v['in']
        ok = (got is None and want is None) or \
             (got is not None and want is not None and abs(got - want) < 1e-9)
        if not ok:
            print('FAIL grammar %-14r want %r got %r' % (v['s'], want, got))
            fails += 1
    print('grammar: %d vectors, %d failed' % (len(vecs['vectors']), fails))

    def room(**kw):
        base = {'name': 'T', 'runs': [
            {'d': 'E', 'v': '10\'', 'src': 'pen x'},
            {'d': 'S', 'v': '8\'', 'src': 'pen x'},
            {'d': 'W', 'v': '10\'', 'src': 'pen x'},
            {'d': 'N', 'v': '8\'', 'src': 'pen x'}],
            'ceiling': {'v': '8\'6"', 'src': 'pen x'}}
        base.update(kw)
        return {'job': 'selftest', 'rooms': [base]}

    cases = [
        ('clean rectangle passes', room(), True, None),
        ('parts chain that closes passes',
         room(runs=[{'d': 'E', 'v': '18\'11"', 'parts': ['10"', '17\'3"', '10"'],
                     'src': 'pen x'},
                    {'d': 'S', 'v': '14\'4"', 'src': 'pen x'},
                    {'d': 'W', 'v': '18\'11"', 'src': 'pen x'},
                    {'d': 'N', 'v': '14\'4"', 'src': 'pen x'}]), True, None),
        ('THE 31 AUG TRAP: 17\'3" transcribed as the wall-to-wall width fails '
         'the parts invariant by name',
         room(runs=[{'d': 'E', 'v': '17\'3"', 'parts': ['10"', '17\'3"', '10"'],
                     'src': 'pen x'},
                    {'d': 'S', 'v': '14\'4"', 'src': 'pen x'},
                    {'d': 'W', 'v': '17\'3"', 'src': 'pen x'},
                    {'d': 'N', 'v': '14\'4"', 'src': 'pen x'}]),
         False, 'parts'),
        ('non-closing polygon fails by name',
         room(runs=[{'d': 'E', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'S', 'v': '8\'', 'src': 'pen x'},
                    {'d': 'W', 'v': '9\'8"', 'src': 'pen x'},
                    {'d': 'N', 'v': '8\'', 'src': 'pen x'}]),
         False, 'polygon'),
        ('door with no at fails by name',
         room(doors=[{'run': 0, 'w': {'v': '38"', 'src': 'pen x'},
                      'hinge': 'near'}]), False, 'door 0 at'),
        ('door with assumed at + reason passes, flagged',
         room(doors=[{'run': 0, 'w': {'v': '38"', 'src': 'pen x'},
                      'at': {'assumed': '6"', 'reason': 'no position on plan'},
                      'hinge': 'near'}]), True, None),
        ('assumed with no reason fails',
         room(doors=[{'run': 0, 'w': {'v': '38"', 'src': 'pen x'},
                      'at': {'assumed': '6"'}, 'hinge': 'near'}]),
         False, 'no reason'),
        ('door at the corner fails by name',
         room(doors=[{'run': 0, 'w': {'v': '38"', 'src': 'pen x'},
                      'at': {'v': '0"', 'src': 'pen x'}, 'hinge': 'near'}]),
         False, 'corner'),
        ('door overrunning the far corner fails',
         room(doors=[{'run': 0, 'w': {'v': '38"', 'src': 'pen x'},
                      'at': {'v': '8\'0"', 'src': 'pen x'}, 'hinge': 'near'}]),
         False, 'corner'),
        ('missing ceiling fails by name', room(ceiling=None), False, 'ceiling'),
        ('value with no src fails', room(ceiling={'v': '8\''}), False, 'src'),
        ('unparseable value fails', room(ceiling={'v': 'about 8ish', 'src': 'pen x'}),
         False, 'parse'),
        ('default with a note passes, flagged DEFAULT',
         room(ceiling={'v': '96"', 'src': 'default',
                       'note': '8\'-0" house default, not measured'}), True, None),
        ('overlapping doors fail',
         room(doors=[{'run': 0, 'w': {'v': '38"', 'src': 'pen x'},
                      'at': {'v': '20"', 'src': 'pen x'}, 'hinge': 'near'},
                     {'run': 0, 'w': {'v': '38"', 'src': 'pen x'},
                      'at': {'v': '40"', 'src': 'pen x'}, 'hinge': 'near'}]),
         False, 'overlap'),
    ]
    for label, data, want_ok, want_word in cases:
        ck, lock = check_file(data, 'selftest')
        got_ok = not ck.errors
        good = got_ok == want_ok
        if good and not want_ok and want_word:
            blob = ' '.join(n + ' ' + m for n, m in ck.errors).lower()
            good = want_word.lower() in blob
        print('%-4s %s' % ('PASS' if good else 'FAIL', label))
        if not good:
            for n, m in ck.errors:
                print('       %s: %s' % (n, m))
            fails += 1
    # Flag bookkeeping: the assumed-at case must put exactly the door at (and
    # the defaulted door height) in the inventory, nothing else.
    ck, _ = check_file(cases[5][1], 'selftest')
    inv = sorted(a['path'] for a in ck.assumed)
    want = ['T door 0 at', 'T door 0 height']
    ok = inv == want
    print('%-4s inventory is exactly %s' % ('PASS' if ok else 'FAIL', want))
    if not ok:
        print('       got %s' % inv)
        fails += 1
    print('')
    print('%d failure(s)' % fails)
    return 1 if fails else 0


# -------------------------------------------------------------------- cli --

def main(argv):
    if not argv:
        print(__doc__)
        return 2
    if argv[0] == '--selftest':
        return selftest()
    path = argv[0]
    want_html = '--html' in argv
    rest = [a for a in argv[1:] if a != '--html']
    if not os.path.exists(path):
        print('no such file: %s' % path)
        return 2
    try:
        data = json.load(open(path, encoding='utf-8'))
    except ValueError as e:
        print('FAIL %s: not valid JSON — %s' % (path, e))
        return 1
    ck, lock = check_file(data, path)
    print_report(ck, lock, path)

    lock_path = re.sub(r'\.json$', '', path) + '.lock.json'
    if ck.errors:
        if os.path.exists(lock_path):
            os.remove(lock_path)
            print('  (stale %s deleted)' % os.path.basename(lock_path))
    else:
        with io.open(lock_path, 'w', encoding='utf-8', newline='\n') as f:
            json.dump(lock, f, indent=2, ensure_ascii=False)
            f.write('\n')
        print('  lock: %s' % lock_path)
    if want_html and lock:
        out = rest[0] if rest else re.sub(r'\.json$', '', path) + '.review.html'
        with io.open(out, 'w', encoding='utf-8', newline='\n') as f:
            f.write(html_report(ck, lock, path))
        print('  review sheet: %s' % out)
    return 1 if ck.errors else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
