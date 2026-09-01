# -*- coding: utf-8 -*-
"""Validate a take-off file, emit the lock file and the review sheet.

    python takeoff-check.py clients/<job>/takeoff.json
    python takeoff-check.py clients/<job>/takeoff.json --html [out.html]
    python takeoff-check.py clients/<job>/takeoff.json --html --embed-photos
    python takeoff-check.py clients/<job>/takeoff.json --apply-patch patch.json
    python takeoff-check.py --selftest

--embed-photos inlines the job's source photos (downsampled, data URIs) into
the review sheet so Gabe compares the pen marks against the transcription
instead of recalling them. OFF by default: the sheet goes to claude.ai when
published, and client imagery leaves the machine only on an explicit flag.
The output lands in *.review.html, which is gitignored either way — client
images are NEVER committed, embedded or otherwise.

--apply-patch consumes the structured patch the review sheet's copy box
emits: {"patch": 1, "job": ..., "review": {room: status}, "edits": [{room,
field, old, new}]}. Every edit's `new` is a full {v, src} / {assumed,
reason} value — an edit with no source is refused, the same defect as the
dialog's invented at:36". `old` must match the current value or the edit is
refused by name (the patch was written against a different file). A cleanly
applied patch rewrites takeoff.json and re-runs the full check.

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
for the JS side). The review sheet this file generates needs the grammar too,
but carries no third copy: dialog_grammar_js() extracts the dialog's own
parseLen/arch by text at generation time and embeds that.
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
DISPLAY_TOL = 0.05 + 1e-9   # patch staleness, inches. The sheet's `old` is
                    # arch()'s display string, rounded to a TENTH of an inch,
                    # so it can sit up to 0.05" from the stored value (1/4" =
                    # 0.25 displays as 6.2" or 6.3"). Staleness is therefore
                    # judged at display precision — anything the sheet showed
                    # matches; a real edit of even one sixteenth (0.0625")
                    # still refuses. Comparing with TOL here made every value
                    # finer than a tenth permanently unpatchable.
PART_TOL = 0.001    # parts are stated numbers; a mismatch is a transcription
                    # error, not noise, so the tolerance is float dust only
DIR = {'E': (1, 0), 'W': (-1, 0), 'N': (0, 1), 'S': (0, -1)}
SRC_KINDS = ('pen', 'plan-vector', 'stated', 'derived', 'assumed', 'default')
FEATURE_TYPES = ('heater', 'bulkhead', 'window')
# The room-level `sill` that used to live here was the height walls were
# SPLIT at for the two-band construction. Walls have built as one solid
# since 1.12.8 and nothing reads it; a room-level sill is now refused by
# name rather than silently defaulted (see check_room).
HOUSE = {'thick': 4.0, 'door_h': 80.0}
HINGE_CHOICES = ('near', 'far')

# The house winding convention. Runs are a CLOCKWISE walk of the interior
# starting at the northwest-most corner, so run 0 always heads E along the
# northernmost wall. Nothing downstream can recover this: build-takeoff.rb
# derives its mitre sense from the signed area and mitres either winding
# happily, so a counter-clockwise run list — which is exactly what a mirrored
# read of the plan produces, since swapping east for west reverses the walk —
# builds a clean, plausible, mirrored room with no message anywhere. All seven
# blind transcribers in the 31 Aug 2026 trial guessed this convention right and
# none of them could have read it anywhere (eval/RESULTS.md, defect D2).
WINDING_ORDERS = ('cw', 'ccw')
# The corner run 0 must start at, per winding: (max-y, then min-x) for cw,
# (max-y, then max-x) for ccw.
WINDING_START = {'cw': ('NW', -1), 'ccw': ('NE', 1)}

# The corner `at` is measured from, named for a reader, per run direction.
# `at` is ALWAYS the run's start corner in travel direction — build-takeoff.rb
# offsets from pts[i] along (pts[i+1] - pts[i]) — but the format never said so
# (defect D1), so the checker now says it out loud for every door.
RUN_START_END = {'E': 'west', 'W': 'east', 'N': 'south', 'S': 'north'}


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
        self.assumed = []    # the ASSUMED/DEFAULT/DERIVED inventory — numeric
                             # values only, because build-takeoff.rb renders
                             # each one's value_in as a dimension in the model
        self.nonnum = []     # the same inventory for values that are not
                             # lengths: an assumed hinge, a declared winding.
                             # Kept apart so the builder's numeric note
                             # formatting never sees a string (see report).
        self.infos = []      # passing checks worth printing (chains closed…)

    def fail(self, name, msg):
        self.errors.append((name, msg))

    def ok(self, name, msg):
        self.infos.append((name, msg))

    def flag(self, path, kind, value_in, reason):
        self.assumed.append({'path': path, 'kind': kind,
                             'value_in': value_in, 'reason': reason})

    def flag_text(self, path, kind, value, reason):
        """Flag a non-numeric recorded guess — a hinge, a winding. Same
        review discipline, separate list: the model note the builder places
        formats value_in as inches, and 'near' is not inches."""
        self.nonnum.append({'path': path, 'kind': kind,
                            'value': value, 'reason': reason})


def check_parts(ck, path, obj, v):
    """`parts` on any value object -> [floats] or None, checked to sum to v.

    Available on an {"assumed": ...} value as well as a {"v", "src"} one
    (defect D3): a transcriber who assumes a total FROM a chain — 15" +
    15'-2" + 15" on blind-f-mech — was previously forced to bury the
    arithmetic in the reason string, where nothing could verify it. An
    assumption whose arithmetic is recorded is a checkable assumption."""
    if 'parts' not in obj:
        return None
    parts = []
    bad = False
    for k, p in enumerate(obj['parts']):
        pv = parse_len(p)
        if pv is None:
            ck.fail('%s parts[%d]' % (path, k), 'part %r does not parse' % (p,))
            bad = True
        else:
            parts.append(pv)
    if bad:
        return parts
    total = sum(parts)
    if abs(total - v) > PART_TOL:
        ck.fail('%s parts' % path,
                'parts %s sum to %s but the value is %s — the chain does not '
                'close; one of these numbers is transcribed wrong'
                % (' + '.join(arch(p) for p in parts), arch(total), arch(v)))
    else:
        ck.ok('%s parts' % path, '%s = %s — chain closes exactly'
              % (' + '.join(arch(p) for p in parts), arch(v)))
    return parts


def norm_enum(ck, path, obj, choices, what):
    """A closed-vocabulary value -> {'value', 'flag', 'reason'} or None.

    Accepts the bare string ("near"), a sourced object ({"v": "far", "src":
    "pen IMG_7595"}), or a recorded guess ({"assumed": "near", "reason":
    ...}) — defect D4: an enum had no way to say "I had to assume this", so
    every transcriber wrote a bare `near`, at least one of them admittedly
    arbitrarily, and it read as measured. A missing or unknown value now
    fails by name instead of silently becoming the first choice."""
    if obj is None:
        ck.fail(path, '%s not stated — one of %s, or a recorded guess: '
                      '{"assumed": "%s", "reason": "..."}'
                % (what, '/'.join(choices), choices[0]))
        return None
    if isinstance(obj, str):
        if obj not in choices:
            ck.fail(path, '%r is not one of %s' % (obj, '/'.join(choices)))
            return None
        return {'value': obj, 'flag': None, 'reason': None}
    if not isinstance(obj, dict):
        ck.fail(path, '%r is not a %s value' % (obj, what))
        return None
    if 'assumed' in obj:
        val = obj['assumed']
        if val not in choices:
            ck.fail(path, 'assumed %r is not one of %s' % (val, '/'.join(choices)))
            return None
        reason = str(obj.get('reason', '')).strip()
        if not reason:
            ck.fail(path, 'assumed %s with no reason — a recorded assumption '
                          'is legal, a silent one is not' % what)
            return None
        ck.flag_text(path, 'assumed', val, reason)
        return {'value': val, 'flag': 'assumed', 'reason': reason}
    val = obj.get('v')
    if val not in choices:
        ck.fail(path, '%r is not one of %s' % (val, '/'.join(choices)))
        return None
    src = str(obj.get('src', '')).strip()
    kind = src.split(' ', 1)[0] if src else ''
    if kind not in SRC_KINDS:
        ck.fail(path, 'src %r missing or not one of %s — where did this %s '
                      'come from?' % (src, '/'.join(SRC_KINDS), what))
        return None
    return {'value': val, 'flag': None, 'reason': obj.get('note')}


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
                'parts': check_parts(ck, path, obj, v), 'note': obj.get('note')}
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
    elif kind == 'derived':
        # Defect D5. A value forced by the closure of the other runs, or by
        # arithmetic on stated numbers, is NOT a measurement: nothing confirms
        # it independently, because closure gives it whatever value makes the
        # walk close. It is legal, it is common, and it flags — so it reaches
        # the review sheet and the model as DERIVED rather than passing as pen.
        if not (reason and str(reason).strip()):
            ck.fail(path, 'src "derived" must name what it was derived from '
                          '(note or reason) — e.g. "derived closure" with a '
                          'note naming the runs that force it')
            return None
        flag = 'derived'
        ck.flag(path, 'derived', v, str(reason))
    parts = check_parts(ck, path, obj, v)
    return {'in': v, 'src': src, 'flag': flag,
            'reason': str(reason) if reason else None,
            'parts': parts, 'note': obj.get('note')}


def _seg_dist(p1, p2, p3, p4):
    """Minimum distance between segments p1p2 and p3p4, inches."""
    def sub(a, b):
        return (a[0] - b[0], a[1] - b[1])

    def cross(a, b):
        return a[0] * b[1] - a[1] * b[0]

    d1 = cross(sub(p4, p3), sub(p1, p3))
    d2 = cross(sub(p4, p3), sub(p2, p3))
    d3 = cross(sub(p2, p1), sub(p3, p1))
    d4 = cross(sub(p2, p1), sub(p4, p1))
    if ((d1 > 0) != (d2 > 0)) and ((d3 > 0) != (d4 > 0)):
        return 0.0   # proper crossing

    def psd(p, a, b):
        ax, ay = b[0] - a[0], b[1] - a[1]
        den = ax * ax + ay * ay
        t = 0.0 if den == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * ax + (p[1] - a[1]) * ay) / den))
        return math.hypot(p[0] - (a[0] + ax * t), p[1] - (a[1] + ay * t))

    return min(psd(p1, p3, p4), psd(p2, p3, p4), psd(p3, p1, p2), psd(p4, p1, p2))


def polygon_self_touch(pts, runs):
    """A failure message if the closed walk touches or crosses itself,
    else None. Closing to 0.00" is necessary but NOT sufficient: seven runs
    that sum to zero can still revisit a corner, and SketchUp will happily
    build the pinched two-lobe result as a single floor face with no message
    anywhere (eval/floorplans/synthetic-selfcross, confirmed by bridge
    read-back, 31 Aug 2026). That is the silent-wrong-geometry class this
    whole checker exists to refuse by name."""
    v = pts[:-1]
    n = len(v)
    # A revisited corner — the pinch. Runs i-1/i and j-1/j all meet there.
    for i in range(n):
        for j in range(i + 1, n):
            if math.hypot(v[i][0] - v[j][0], v[i][1] - v[j][1]) <= TOL:
                return ('the outline revisits the corner at (%s, %s) — the '
                        'end of run %d lands where run %d started. The runs '
                        'sum to zero but the room self-touches (a pinched '
                        'two-lobe outline), which is what a scrambled or '
                        'misordered chain looks like; fix the take-off, do '
                        'not build'
                        % (arch(v[j][0]), arch(v[j][1]), (j - 1) % n, i))
    # A run that immediately doubles back over its neighbour: a zero-width
    # sliver of wall, always a transcription error.
    for i in range(n):
        a, b = DIR[runs[i]['d']], DIR[runs[(i + 1) % n]['d']]
        if a[0] == -b[0] and a[1] == -b[1]:
            return ('run %d (%s) doubles straight back over run %d (%s) — a '
                    'zero-width sliver; two opposite runs in a row cannot '
                    'both be wall faces'
                    % ((i + 1) % n, runs[(i + 1) % n]['d'], i, runs[i]['d']))
    # Non-adjacent wall runs that cross or touch.
    for i in range(n):
        for j in range(i + 1, n):
            if j == i + 1 or (i == 0 and j == n - 1):
                continue   # neighbours share a corner by construction
            if _seg_dist(v[i], v[(i + 1) % n], v[j], v[(j + 1) % n]) <= TOL:
                return ('runs %d and %d cross or touch each other — the '
                        'outline is self-intersecting, not a room; fix the '
                        'take-off, do not build' % (i, j))
    return None


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


def signed_area(pts):
    """Shoelace over the closed walk, square inches. Negative = clockwise in
    the model frame (N = +y) — the same sense build-takeoff.rb reads to pick
    its mitre direction."""
    v = pts[:-1]
    n = len(v)
    return sum(v[i][0] * v[(i + 1) % n][1] - v[(i + 1) % n][0] * v[i][1]
               for i in range(n)) / 2.0


def check_winding(ck, name, pts, runs, decl):
    """The D2 invariant: runs walk CLOCKWISE from the northwest-most corner.

    Returns the declared order ('cw'/'ccw') for the lock. Refuses by name a
    walk that runs the other way undeclared, and one that starts at the wrong
    corner. A room genuinely transcribed the other way round — the real UIC
    job's 3190J, whose pen door chain is measured off the north corner of the
    west wall — stays legal by DECLARING it with a reason, the same discipline
    `assumed` uses: guessing is legal, guessing silently is not."""
    want = 'cw'
    if decl is not None:
        if isinstance(decl, str):
            if decl not in WINDING_ORDERS:
                ck.fail('%s winding' % name,
                        'winding %r is not one of %s'
                        % (decl, '/'.join(WINDING_ORDERS)))
                return None
            if decl == 'ccw':
                ck.fail('%s winding' % name,
                        'a counter-clockwise walk must be declared with a '
                        'reason, not just named: {"order": "ccw", "reason": '
                        '"..."}. Clockwise is the convention; departing from '
                        'it is a judgment call and gets recorded like one')
                return None
            want = decl
        elif isinstance(decl, dict):
            want = decl.get('order')
            if want not in WINDING_ORDERS:
                ck.fail('%s winding' % name, 'order %r is not one of %s'
                        % (want, '/'.join(WINDING_ORDERS)))
                return None
            reason = str(decl.get('reason', '')).strip()
            if want == 'ccw' and not reason:
                ck.fail('%s winding' % name,
                        'winding "ccw" with no reason — say why this room is '
                        'walked against the convention')
                return None
            if want == 'ccw':
                ck.flag_text('%s winding' % name, 'declared', 'ccw', reason)
        else:
            ck.fail('%s winding' % name, 'winding must be "cw" or '
                                         '{"order": ..., "reason": ...}')
            return None

    area = signed_area(pts)
    got = 'ccw' if area > 0 else 'cw'
    if got != want:
        if want == 'cw':
            ck.fail('%s winding' % name,
                    'the runs walk COUNTER-CLOCKWISE. The convention is a '
                    'clockwise walk starting at the northwest-most corner, so '
                    'run 0 heads E along the northernmost wall. Nothing '
                    'downstream can tell a deliberate counter-clockwise walk '
                    'from a MIRRORED read of the plan — swapping east for west '
                    'reverses the walk, closes just as cleanly, and the builder '
                    'mitres either winding without complaint. Rewrite the runs '
                    'clockwise from the northwest corner, or, if this room '
                    'really is transcribed the other way on purpose, declare '
                    'it: "winding": {"order": "ccw", "reason": "..."}')
        else:
            ck.fail('%s winding' % name,
                    'declared "ccw" but the runs walk CLOCKWISE — the '
                    'declaration and the geometry disagree; one of them is '
                    'wrong')
        return None

    v = pts[:-1]
    top = max(p[1] for p in v)
    corner, sense = WINDING_START[want]
    xs = [p[0] for p in v if abs(p[1] - top) <= TOL]
    want_x = max(xs) if sense > 0 else min(xs)
    if abs(pts[0][1] - top) > TOL or abs(pts[0][0] - want_x) > TOL:
        ck.fail('%s winding' % name,
                'run 0 starts at (%s, %s), which is not the %s-most corner of '
                'the outline (that corner is at (%s, %s)). A %s walk starts '
                'there by convention — `at` on every door is measured from its '
                'run\'s start corner, and the run indices are how the review '
                'sheet, the patch format and the scorer name a wall, so the '
                'start corner is part of the geometry, not a free choice'
                % (arch(pts[0][0]), arch(pts[0][1]), corner,
                   arch(want_x), arch(top), want.upper()))
        return None
    ck.ok('%s winding' % name,
          '%s from the %s corner — run 0 heads %s%s'
          % (want.upper(), corner, runs[0]['d'],
             ' (declared exception)' if want == 'ccw' else ''))
    return want


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
            touch = polygon_self_touch(pts, runs)
            if touch:
                ck.fail('%s polygon' % name, touch)
                pts = None
            else:
                ck.ok('%s polygon' % name, '%d runs, closes to %.2f", '
                      'no self-intersection' % (len(runs), math.hypot(ex, ey)))
                out['winding'] = check_winding(ck, name, pts, runs,
                                               room.get('winding'))
        out['polygon'] = [[round(x, 4), round(y, 4)] for x, y in pts[:-1]] \
            if pts else None
    else:
        out['polygon'] = None

    # D5, the enforceable half: closure forces exactly ONE unknown run per
    # axis. Two runs on the same axis both claiming to be closure-derived
    # means the arithmetic is underdetermined and the pair could be anything
    # that sums right — a closing polygon built on nothing.
    for axis, letters in (('east-west', 'EW'), ('north-south', 'NS')):
        by_closure = [i for i, r in enumerate(runs)
                      if r['d'] in letters and r['flag'] == 'derived'
                      and 'closure' in (r['src'] or '').lower()]
        if len(by_closure) > 1:
            ck.fail('%s runs' % name,
                    'runs %s are all "derived closure" on the %s axis, but '
                    'closure forces exactly one unknown per axis — with two, '
                    'any pair summing to the same total closes and none of '
                    'them is determined. Measure or state all but one'
                    % (', '.join(str(i) for i in by_closure), axis))

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
        # D1: name the corner. `at` is the distance from the corner where the
        # run STARTS, measured along the run's own travel direction — which,
        # with the winding pinned, is a specific compass corner of the room.
        anchor = 'the %s end of run %d (the run heads %s)' % (
            RUN_START_END[runs[run_i]['d']], run_i, runs[run_i]['d'])
        hinge = norm_enum(ck, '%s hinge' % path, d.get('hinge'),
                          HINGE_CHOICES, 'hinge')
        if 'at' not in d or d.get('at') is None:
            ck.fail('%s at' % path,
                    'no position on run %d. Measure from %s to the near jamb, '
                    'or mark it assumed with a reason.' % (run_i, anchor))
            continue
        at = norm_value(ck, '%s at' % path, d.get('at'))
        h = norm_value(ck, '%s height' % path, d.get('h'), required=False)
        if h is None and not ck_has_error(ck, '%s height' % path):
            # No height given at all: the house default, loudly.
            h = {'in': HOUSE['door_h'], 'src': 'default', 'flag': 'default',
                 'reason': 'standard leaf, not measured', 'parts': None,
                 'note': None}
            ck.flag('%s height' % path, 'default', h['in'], h['reason'])
        if w is None or at is None or h is None or hinge is None:
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
        ck.ok('%s at' % path, '%s from %s to the near jamb'
              % (arch(at['in']), anchor))
        doors.append({'run': run_i, 'at_in': at['in'], 'at_src': at['src'],
                      'at_flag': at['flag'], 'at_reason': at['reason'],
                      'at_from': anchor,
                      'w_in': w['in'], 'w_src': w['src'], 'w_flag': w['flag'],
                      'h_in': h['in'], 'h_src': h['src'], 'h_flag': h['flag'],
                      'h_reason': h['reason'],
                      'hinge': hinge['value'], 'hinge_flag': hinge['flag']})
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
                         # A window's sill is how high it sits off the
                         # floor and is REQUIRED — measured, or assumed
                         # with a reason. It used to be optional, and a
                         # window without one was invented twice over,
                         # differently: the review sheet drew it from the
                         # room's retired band sill (48") while
                         # build-takeoff.rb built it from the floor
                         # (`f['sill_in'] || 0.0`). One missing number,
                         # two silent placements that disagreed.
                         ('sill', t == 'window')):
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
            ff[key + '_src'] = nv['src']
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

    nv = norm_value(ck, '%s thick' % name, room.get('thick'), required=False)
    out['thick_in'] = nv['in'] if nv else HOUSE['thick']
    if 'sill' in room:
        ck.fail('%s sill' % name,
                'a room-level `sill` is no longer a thing. It was the height '
                'walls were SPLIT at for the two-band construction, and walls '
                'have built as one solid floor-to-ceiling since 1.12.8 — '
                'nothing reads this. If you meant how high a WINDOW sits off '
                'the floor, that is `sill` on the window feature itself; the '
                'two are unrelated numbers that used to share a name. '
                'Delete it.')

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
        # Non-numeric recorded guesses (assumed hinge, declared winding). Kept
        # out of assumed_inventory because build-takeoff.rb formats every entry
        # there as a length for its in-model note; these need their own note
        # pass on the builder side before they reach the model.
        'flag_inventory': ck.nonnum,
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
        print('  ASSUMED / DEFAULT / DERIVED — %d value(s), confirm before '
              'quoting:' % len(ck.assumed))
        for a in ck.assumed:
            print('    %s %s — %s (%s)' % (a['kind'].upper(), a['path'],
                                           arch(a['value_in']), a['reason']))
    else:
        print('  ASSUMED / DEFAULT / DERIVED — none. Every value is measured '
              'or stated.')
    if ck.nonnum:
        print('')
        print('  RECORDED NON-NUMERIC GUESSES — %d, confirm before quoting:'
              % len(ck.nonnum))
        for a in ck.nonnum:
            print('    %s %s — %s (%s)' % (a['kind'].upper(), a['path'],
                                           a['value'], a['reason']))
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

def _sval(room_name, field, old_arch, flag):
    """Attributes that make one SVG dimension text editable, or '' when the
    text is not a single editable value (a chain breakdown, say).

    The plan and the callout column are two views of ONE value: both carry the
    same data-room/data-field, and the page keeps every view of a field in
    step when it is edited. Assumed values are clickable like any other —
    they are the ones most worth correcting — and carry data-assumed so the
    drawing can say so before it is clicked."""
    if not field:
        return ''
    return (' class="sval%s" data-room="%s" data-field="%s" data-old="%s"'
            % (' asm' if flag in ('assumed', 'default', 'derived') else '',
               esc(room_name), esc(field), esc(old_arch)))


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
        # The parts row is a breakdown, not one editable value; only the
        # overall carries a field, so only the overall is clickable.
        rows = [(18.0, r['parts'], 6.5, None, None)] if r.get('parts') else []
        rows.append((18.0 + (16.0 if r.get('parts') else 0.0), [r['in']], 8.0,
                     'runs[%d]' % i, r.get('flag')))
        for off, vals, fs, field, flag in rows:
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
                           'fill="var(--accent)" text-anchor="middle"%s%s>%s</text>'
                           % (stx, sty, fs, rot, _sval(room['name'], field,
                                                      arch(v), flag),
                              esc(arch(v))))
                cur += v
    for dj, dd in enumerate(room.get('doors') or []):
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
                   'text-anchor="middle"%s>%s</text>'
                   % (mx, my, 'warn' if dd['at_flag'] else 'ink-2',
                      _sval(room['name'], 'doors[%d].w' % dj,
                            arch(dd['w_in']), dd.get('w_flag')), esc(lab)))
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


# The dark palette is written once and emitted twice: under the guarded
# prefers-color-scheme media query (system dark, no explicit choice) and under
# :root[data-theme="dark"] (the viewer's explicit toggle). Bare :root is the
# complete light palette, so all three viewer theme states resolve.
DARK_VARS = """--bg:#1b1e21;--card:#23272b;--ink:#e6eaed;
    --ink-2:#98a2aa;--ink-3:#6d777e;--rule:#32383d;--accent:#ff7a33;--ok:#63b98a;
    --bad:#e8705f;--warn:#e0b45a;--warn-bg:#2c2820;--solid:#2c3237;--field:#191c1f;"""

CSS = """
  :root{--bg:#f2f3f5;--card:#fff;--ink:#14181c;--ink-2:#626c75;--ink-3:#949ea6;
    --rule:#dfe3e7;--accent:#ee6216;--ok:#2c6e49;--bad:#b03027;--warn:#9a6a00;
    --warn-bg:#fdf4e0;--solid:#e3e8ec;--field:#fff;color-scheme:light dark;}
  @media (prefers-color-scheme:dark){:root:not([data-theme="light"]){@DARK@}}
  :root[data-theme="dark"]{@DARK@}
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
    border-bottom:1px solid var(--rule);display:flex;gap:10px;align-items:baseline;
    flex-wrap:wrap}
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

  /* --- source photo beside the interpretation ------------------------------ */
  .cmp{display:grid;grid-template-columns:1fr;gap:0;border-bottom:1px solid var(--rule)}
  @media(min-width:760px){.cmp{grid-template-columns:minmax(0,1fr) 340px}}
  .ph{padding:12px 14px;background:var(--bg)}
  .ph img{width:100%;height:auto;border:1px solid var(--rule);border-radius:3px;
    cursor:zoom-in;display:block}
  .phcap{margin-top:6px;font-size:10.5px;color:var(--ink-3);font-family:Consolas,monospace}
  .noph{border:1px dashed var(--rule);border-radius:3px;padding:26px 16px;text-align:center;
    color:var(--ink-3);font-size:11px;font-family:Consolas,monospace;background:var(--card)}
  .ledger{padding:12px 14px;border-left:1px solid var(--rule)}
  .ledger td.k{color:var(--ink);padding-right:10px}
  .ledger td.v{color:var(--ink-2);width:58%}
  .ledger td.v span{font-size:10.5px}
  .lightbox{position:fixed;inset:0;background:rgba(10,12,14,.88);z-index:60;
    overflow:auto;cursor:zoom-out;padding:24px}
  .lightbox img{display:block;margin:0 auto;max-width:none;width:min(1600px,160vw)}

  /* --- rotatable 3D view --------------------------------------------------- */
  .v3d{position:relative;border-top:1px solid var(--rule);background:var(--bg);
    height:340px;overflow:hidden}
  .v3d canvas{position:absolute;inset:0;width:100%;height:100%;touch-action:none;
    cursor:grab;display:block}
  .v3d canvas:active{cursor:grabbing}
  .v3d .ovl{position:absolute;inset:0;pointer-events:none;overflow:hidden}
  .v3d .ovl span{position:absolute;transform:translate(-50%,-50%);white-space:nowrap;
    font-family:Consolas,ui-monospace,monospace;font-size:10.5px;color:var(--accent);
    text-shadow:0 0 3px var(--bg),0 0 3px var(--bg),0 0 3px var(--bg)}
  .v3d .ovl span.asm{color:var(--warn);font-weight:700}
  .v3d .ovl span.dim2{color:var(--ink-2)}
  .v3d .ro{position:absolute;left:10px;bottom:8px;font-family:Consolas,monospace;
    font-size:10px;color:var(--ink-3);pointer-events:none}
  .v3d .hint3d{position:absolute;right:10px;bottom:8px;font-family:Consolas,monospace;
    font-size:10px;color:var(--ink-3);pointer-events:none}
  .v3d .rst{position:absolute;right:10px;top:8px;font-family:Consolas,monospace;
    font-size:10px;padding:3px 9px;border:1px solid var(--rule);border-radius:3px;
    background:var(--card);color:var(--ink-2);cursor:pointer}
  .v3d .rst:hover{color:var(--ink)}

  /* --- review controls, edits, the patch box ------------------------------- */
  .rv{margin-left:auto;display:flex;gap:6px}
  .rv button{font-family:Consolas,monospace;font-size:9.5px;letter-spacing:.09em;
    padding:3px 10px;border-radius:3px;border:1px solid var(--rule);background:var(--card);
    color:var(--ink-2);cursor:pointer}
  .rv button.on-a{background:var(--ok);border-color:var(--ok);color:#fff}
  .rv button.on-n{background:var(--warn);border-color:var(--warn);color:#fff}
  .val{cursor:pointer;border-bottom:1px dashed var(--ink-3)}
  /* A dimension on the plan is the same value as the one in the callout
     column, so it gets the same affordance: dashed = click me, orange bold
     = you changed it. Dotted-underlined in the drawing because SVG text has
     no border. */
  .sval{cursor:pointer;text-decoration:underline;text-decoration-style:dashed;
    text-underline-offset:2px}
  .sval:hover{fill:var(--accent);font-weight:700}
  .sval.asm{font-style:italic}
  .sval.edited{fill:var(--accent);font-weight:700;text-decoration-style:solid}
  .val:hover{border-bottom-color:var(--accent);color:var(--accent)}
  .val.edited{color:var(--accent);font-weight:700;border-bottom:1px solid var(--accent)}
  .was{color:var(--ink-3);text-decoration:line-through;margin-left:5px;font-size:10.5px}
  .edform{margin:6px 0 8px;padding:9px 10px;border:1px solid var(--accent);border-radius:4px;
    background:var(--bg);font-size:11px}
  .edform label{display:block;margin:5px 0 2px;font-size:9.5px;letter-spacing:.1em;
    text-transform:uppercase;color:var(--ink-3);font-family:Consolas,monospace}
  .edform input,.edform select{width:100%;padding:4px 7px;border:1px solid var(--rule);
    border-radius:3px;background:var(--field);color:var(--ink);
    font-family:Consolas,monospace;font-size:11.5px}
  .edform .err{color:var(--bad);margin-top:5px;font-size:10.5px;font-family:Consolas,monospace}
  .edform .row{display:flex;gap:8px;margin-top:8px}
  .edform button{font-family:Consolas,monospace;font-size:10px;padding:4px 12px;
    border-radius:3px;border:1px solid var(--rule);background:var(--card);
    color:var(--ink-2);cursor:pointer}
  .edform button.save{background:var(--accent);border-color:var(--accent);color:#fff}
  .closewarn{margin:8px 12px;padding:9px 11px;border:1px solid var(--bad);
    border-left-width:3px;border-radius:4px;background:var(--card);
    font-family:Consolas,monospace;font-size:11px;color:var(--bad);line-height:1.55}
  .closewarn b{display:block;margin-bottom:4px;letter-spacing:.06em}
  .closewarn div{margin-top:3px}
  .rnote{margin:8px 0 4px;padding:9px 11px;border:1px solid var(--warn);
    border-left-width:3px;border-radius:4px;background:var(--warn-bg)}
  .rnote label{display:block;font-family:Consolas,monospace;font-size:9.5px;
    letter-spacing:.11em;text-transform:uppercase;color:var(--warn);margin-bottom:5px}
  .rnote textarea{width:100%;min-height:64px;resize:vertical;border:1px solid var(--rule);
    border-radius:3px;background:var(--field);color:var(--ink);padding:7px 9px;
    font-family:Consolas,ui-monospace,monospace;font-size:11.5px;line-height:1.5}
  .rnote .hint{font-family:Consolas,monospace;font-size:10px;color:var(--ink-3);
    margin-top:5px}
  #patchsec{border:1px solid var(--rule);border-radius:6px;background:var(--card);
    margin-bottom:18px;padding:12px 14px}
  #patchsec textarea{width:100%;min-height:120px;resize:vertical;border:1px solid var(--rule);
    border-radius:4px;background:var(--field);color:var(--ink);padding:8px 10px;
    font-family:Consolas,ui-monospace,monospace;font-size:11px;line-height:1.5}
  #patchsec .row{display:flex;gap:10px;align-items:center;margin-top:8px}
  #patchsec button{font-family:Consolas,monospace;font-size:10.5px;padding:5px 14px;
    border-radius:3px;border:1px solid var(--accent);background:var(--accent);color:#fff;
    cursor:pointer}
  #patchsec .copied{color:var(--ok);font-size:10.5px;font-family:Consolas,monospace}
  #patchsec .how{font-size:10.5px;color:var(--ink-3);font-family:Consolas,monospace;
    margin-top:6px}
""".replace('@DARK@', DARK_VARS)


# The sheet's script: review controls + the structured patch box, and the
# per-room rotatable 3D view. The 3D interaction (pointer-drag orbit, arrow
# keys, reset, colours read live from the sheet's own CSS tokens) matches the
# workspace's approved viewer in docs/tube-drying-stand.html; wheel zoom is
# added per the 3D-artifact house rule (rotate, flip, zoom). Hand-written
# WebGL, zero external dependencies — the sheet must also work from file://
# with no network. The page's parseLen/arch are NOT a copy: the /*@GRAMMAR@*/
# marker is filled at generation time with the literal function text extracted
# from scripts/build-room.html (dialog_grammar_js), the same extraction
# scripts/takeoff-vectors.html uses to run the parity vectors.
JS = r"""
(function () {
  'use strict';
  var LOCK = JSON.parse(document.getElementById('lockdata').textContent);
  var pd = document.getElementById('photodata');
  var PHOTOS = pd ? JSON.parse(pd.textContent) : {};

  // ---------------------------------------------------------------- grammar --
  // parseLen and arch are NOT written here: they are the dialog's own shipped
  // functions, extracted verbatim from scripts/build-room.html at sheet
  // generation time (dialog_grammar_js below) — the grammar cannot drift
  // because there is no third copy to drift.
  /*@GRAMMAR@*/

  // ------------------------------------------------------- photos, lightbox --
  document.querySelectorAll('img.photo').forEach(function (img) {
    var name = img.getAttribute('data-img');
    if (PHOTOS[name]) img.src = PHOTOS[name];
    img.addEventListener('click', function () {
      var lb = document.createElement('div');
      lb.className = 'lightbox';
      var big = document.createElement('img');
      big.src = img.src; big.alt = img.alt;
      lb.appendChild(big);
      lb.addEventListener('click', function () { lb.remove(); });
      document.body.appendChild(lb);
    });
  });

  // -------------------------------------------- review state + patch emitter --
  // Every edit is a measurement claim: the form will not save without a
  // source, and "assumed" will not save without a reason. The patch box emits
  // structured JSON that takeoff-check.py --apply-patch consumes directly —
  // never prose, because re-interpreting prose is the transcription step this
  // whole sheet exists to remove.
  // Every edit still carries a source into the patch — the source is simply
  // known in advance here: the reviewer corrected it on this sheet. Written
  // once so the CLI's refusal rule stays satisfied without asking.
  var EDIT_SRC = 'stated corrected on the review sheet';
  var state = { edits: [], review: {}, notes: {} };
  var roomsByName = {};
  (LOCK.rooms || []).forEach(function (r) { roomsByName[r.name] = r; });
  var $patch = document.getElementById('patchbox');
  var $counts = document.getElementById('fcounts');

  function recordEdit(room, field, oldArch, newObj) {
    state.edits = state.edits.filter(function (e) {
      return !(e.room === room && e.field === field);
    });
    if (newObj) state.edits.push({ room: room, field: field, old: oldArch, 'new': newObj });
    renderPatch();
  }
  function renderPatch() {
    var notes = {}, nn = 0, rk;
    for (rk in state.notes) {
      if (state.notes[rk] && state.notes[rk].trim()) {
        notes[rk] = state.notes[rk].trim(); nn++;
      }
    }
    var any = state.edits.length || Object.keys(state.review).length || nn;
    if (!any) {
      $patch.value = '(no edits, notes or room decisions yet — click a dashed '
        + 'value to change it, or APPROVE / NEEDS CHANGES on a room)';
    } else {
      var out = { patch: 1, job: LOCK.job, review: state.review,
                  edits: state.edits };
      // Notes are prose and go nowhere near --apply-patch, which ignores the
      // key. They exist so a change that is NOT a number — move the door to
      // the other wall, this partition is gone — reaches the model builder
      // in the reviewer's own words instead of being lost in a screenshot.
      if (nn) out.notes = notes;
      $patch.value = JSON.stringify(out, null, 2);
    }
    renderClosure();
    if ($counts) {
      var a = 0, n = 0, k;
      for (k in state.review) {
        if (state.review[k] === 'approved') a++; else n++;
      }
      $counts.textContent = ' · ' + state.edits.length + ' edit(s), '
        + nn + ' note(s), ' + a + ' approved, ' + n + ' needs-changes';
    }
  }

  // Every room gets a note box, revealed by NEEDS CHANGES. A verdict with no
  // way to say WHAT is wrong sends the reviewer back to prose in chat, which
  // is the transcription hop this sheet exists to remove.
  // ------------------------------------------------------------- closure --
  // A room's opposite walls are BOTH measured, so they are allowed to differ —
  // real rooms are not square. What is not allowed is changing one and leaving
  // the drawing claiming a room that cannot close. Editing 18'-11" on the
  // north wall does NOT rewrite the south wall: copying a number Benton did
  // not measure is the invention this sheet exists to stop. It says so
  // instead, live, in the room it happened in.
  function curInches(rname, field, fallback) {
    var e = state.edits.filter(function (x) {
      return x.room === rname && x.field === field;
    })[0];
    if (!e) return fallback;
    var raw = e['new'].v !== undefined ? e['new'].v : e['new'].assumed;
    var n = parseLen(raw);
    return isNaN(n) ? fallback : n;
  }
  function closureIssues(rname) {
    var r = roomsByName[rname], msgs = [];
    if (!r || !r.runs) return msgs;
    var ax = { N: 0, S: 0, E: 0, W: 0 };
    r.runs.forEach(function (run, i) {
      var v = curInches(rname, 'runs[' + i + ']', run['in']);
      if (ax[run.d] !== undefined) ax[run.d] += v;
      // A chain is its own claim: the parts must still sum to the overall.
      if (run.parts && run.parts.length) {
        var sum = 0;
        run.parts.forEach(function (p) { sum += p; });
        if (Math.abs(sum - v) > 0.05) {
          msgs.push('run ' + i + ' (' + run.d + ') now reads ' + arch(v)
            + ' but its segments still sum to ' + arch(sum)
            + ' — the chain no longer closes, so one of them is wrong.');
        }
      }
    });
    [['N', 'S', 'north', 'south'], ['E', 'W', 'east', 'west']].forEach(function (q) {
      var d = ax[q[0]] - ax[q[1]];
      if (Math.abs(d) > 0.05) {
        msgs.push(q[2] + ' walls total ' + arch(ax[q[0]]) + ' but ' + q[3]
          + ' total ' + arch(ax[q[1]]) + ' — off by ' + arch(Math.abs(d))
          + '. Both are measured, so this may be real; if it is not, the '
          + 'opposite wall needs the same correction.');
      }
    });
    return msgs;
  }
  var closeBoxes = {};
  function renderClosure() {
    Object.keys(closeBoxes).forEach(function (rname) {
      var msgs = closureIssues(rname), box = closeBoxes[rname];
      box.hidden = !msgs.length;
      if (!msgs.length) return;
      box.innerHTML = '<b>This room no longer closes</b>';
      msgs.forEach(function (m) {
        var d = document.createElement('div');
        d.textContent = m;
        box.appendChild(d);
      });
    });
  }

  var noteBoxes = {};
  document.querySelectorAll('section.room[data-room]').forEach(function (sec) {
    var room = sec.getAttribute('data-room');
    var d = document.createElement('div');
    d.className = 'rnote';
    d.hidden = true;
    var lab = document.createElement('label');
    lab.textContent = 'What needs to change in ' + room + '?';
    var ta = document.createElement('textarea');
    ta.placeholder = 'e.g. the door on the north wall opens the other way; '
      + 'the west partition is gone; the alcove is deeper than drawn. '
      + 'A number you can measure is better entered by clicking the dashed '
      + 'value above — that becomes a checked edit instead of prose.';
    ta.setAttribute('aria-label', 'Requested changes for ' + room);
    var hint = document.createElement('div');
    hint.className = 'hint';
    hint.textContent = 'Goes into the patch box at the bottom, under "notes".';
    d.appendChild(lab); d.appendChild(ta); d.appendChild(hint);
    sec.appendChild(d);
    noteBoxes[room] = { box: d, ta: ta };
    var cw = document.createElement('div');
    cw.className = 'closewarn';
    cw.hidden = true;
    sec.insertBefore(cw, sec.children[1] || null);
    closeBoxes[room] = cw;
    ta.addEventListener('input', function () {
      state.notes[room] = ta.value;
      renderPatch();
    });
  });

  function syncNote(room) {
    var nb = noteBoxes[room];
    if (!nb) return;
    var want = state.review[room] === 'needs-changes'
      || !!(state.notes[room] && state.notes[room].trim());
    nb.box.hidden = !want;
    return nb;
  }

  document.querySelectorAll('.rv button').forEach(function (b) {
    b.addEventListener('click', function () {
      var room = b.getAttribute('data-room'), st = b.getAttribute('data-st');
      var box = b.parentElement;
      if (state.review[room] === st) delete state.review[room];
      else state.review[room] = st;
      box.querySelectorAll('button').forEach(function (x) {
        var on = state.review[room] === x.getAttribute('data-st');
        x.className = on ? (x.getAttribute('data-st') === 'approved' ? 'on-a' : 'on-n') : '';
      });
      var nb = syncNote(room);
      if (nb && state.review[room] === 'needs-changes') nb.ta.focus();
      renderPatch();
    });
  });

  // ------------------------------------------------------------ inline edit --
  // A value shows up twice: as a dimension ON THE PLAN and as a row in the
  // callout column. They are ONE value, so an edit to either must move both —
  // a drawing that disagrees with the table beside it is exactly the kind of
  // thing that reaches a client. Every view of a field registers here and
  // paintField repaints all of them together.
  var views = {};
  function keyOf(room, field) { return JSON.stringify([room, field]); }
  function register(el) {
    var k = keyOf(el.getAttribute('data-room'), el.getAttribute('data-field'));
    (views[k] = views[k] || []).push(el);
  }
  function setCls(el, name, on) {
    // SVG elements have classList in every browser this page targets, but
    // className is a read-only SVGAnimatedString there — never assign it.
    if (on) { el.classList.add(name); } else { el.classList.remove(name); }
  }
  function paintField(room, field, txt, edited) {
    (views[keyOf(room, field)] || []).forEach(function (el) {
      // The door label on the plan is "38\" ASSUMED at" — swap only the
      // number, never the trailing note.
      var oldArch = el.getAttribute('data-old');
      var cur = el.textContent;
      el.textContent = cur.indexOf(oldArch) === 0
        ? txt + cur.slice(oldArch.length) : txt;
      setCls(el, 'edited', edited);
    });
  }

  var openForm = null;
  function closeForm() { if (openForm) { openForm.remove(); openForm = null; } }
  document.querySelectorAll('.val, .sval').forEach(function (span) {
    register(span);
    var isSvg = span.classList.contains('sval');
    span.setAttribute('title', span.classList.contains('asm')
      ? 'assumed — click to replace it with a measured value'
      : 'click to change this value');
    span.addEventListener('click', function () {
      closeForm();
      var room = span.getAttribute('data-room');
      var field = span.getAttribute('data-field');
      var oldArch = span.getAttribute('data-old');
      var existing = state.edits.filter(function (e) {
        return e.room === room && e.field === field;
      })[0];
      var f = document.createElement('div');
      f.className = 'edform';
      // One box. The source is not asked for because on this sheet it is
      // always the same answer — Benton corrected the number while reviewing
      // it — so asking a question with one possible answer just taxes every
      // edit. EDIT_SRC still satisfies --apply-patch's rule that no
      // measurement claim lands without a source.
      f.innerHTML =
        '<label>new value (was ' + oldArch.replace(/</g, '&lt;') + ')</label>'
        + '<input class="fv" placeholder="e.g. 12&#39;6&quot;, 38&quot;, 150">'
        + '<div class="err" hidden></div>'
        + '<div class="row"><button class="save">SAVE</button>'
        + '<button class="cancel">CANCEL</button>'
        + (existing ? '<button class="drop">REMOVE EDIT</button>' : '') + '</div>';
      if (isSvg) {
        // An SVG <text> cannot contain a <div>; drop the form just below the
        // drawing so it opens next to the dimension that was clicked.
        var plan = span.closest('.plan') || span.closest('section.room');
        plan.parentNode.insertBefore(f, plan.nextSibling);
      } else {
        span.parentElement.appendChild(f);
      }
      openForm = f;
      var $v = f.querySelector('.fv'), $e = f.querySelector('.err');
      if (existing) {
        $v.value = existing['new'].v !== undefined
          ? existing['new'].v : existing['new'].assumed;
      }
      f.querySelector('.save').addEventListener('click', function () {
        var raw = $v.value.trim();
        var inches = parseLen(raw);
        if (isNaN(inches)) {
          $e.textContent = 'value does not parse — grammar: 150, 150", 12\'6", '
            + '12\'-6", 12\' 6 1/2", 12.5\'; a bare number is inches';
          $e.hidden = false; return;
        }
        recordEdit(room, field, oldArch, { v: raw, src: EDIT_SRC });
        paintField(room, field, arch(inches), true);
        (views[keyOf(room, field)] || []).forEach(function (el) {
          if (el.classList.contains('sval')) return;   // no strikethrough in SVG
          var was = el.parentElement.querySelector('.was[data-for="' + field + '"]');
          if (!was) {
            was = document.createElement('span');
            was.className = 'was'; was.setAttribute('data-for', field);
            el.after(was);
          }
          was.textContent = oldArch;
        });
        closeForm();
      });
      f.querySelector('.cancel').addEventListener('click', closeForm);
      var drop = f.querySelector('.drop');
      if (drop) drop.addEventListener('click', function () {
        recordEdit(room, field, oldArch, null);
        paintField(room, field, oldArch, false);
        (views[keyOf(room, field)] || []).forEach(function (el) {
          if (el.classList.contains('sval')) return;
          var was = el.parentElement.querySelector('.was[data-for="' + field + '"]');
          if (was) was.remove();
        });
        closeForm();
      });
      $v.focus();
    });
  });

  document.getElementById('copybtn').addEventListener('click', function () {
    var done = function () {
      var c = document.querySelector('#patchsec .copied');
      c.textContent = 'copied — paste it back to takeoff-check.py --apply-patch';
      setTimeout(function () { c.textContent = ''; }, 4000);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText($patch.value).then(done, function () {
        $patch.select(); document.execCommand('copy'); done();
      });
    } else { $patch.select(); document.execCommand('copy'); done(); }
  });
  renderPatch();

  // ------------------------------------------------------------- 3D viewers --
  // Geometry is generated from the LOCK — the checked numbers, never the raw
  // take-off — so the view shows what would actually be built. ASSUMED values
  // draw in the warn colour, the same flag they carry on the plan.
  function rgb(hex) {
    hex = hex.trim().replace('#', '');
    if (hex.length === 3) hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
    return [parseInt(hex.slice(0, 2), 16) / 255, parseInt(hex.slice(2, 4), 16) / 255,
            parseInt(hex.slice(4, 6), 16) / 255];
  }
  function tokens() {
    var cs = getComputedStyle(document.documentElement);
    function t(k, fb) {
      var v = cs.getPropertyValue('--' + k).trim();
      return rgb(v && v.charAt(0) === '#' ? v : fb);
    }
    var solid = t('solid', '#e3e8ec'), warn = t('warn', '#9a6a00');
    return {
      wall: solid,
      feat: solid.map(function (v) { return v * 0.82; }),
      asm: [solid[0] * 0.35 + warn[0] * 0.65, solid[1] * 0.35 + warn[1] * 0.65,
            solid[2] * 0.35 + warn[2] * 0.65],
      floor: t('bg', '#f2f3f5').map(function (v) { return v * 0.96; }),
      ink: t('ink', '#14181c'),
      accent: t('accent', '#ee6216')
    };
  }
  function mul(a, b) {
    var o = new Float32Array(16), i, j, k;
    for (i = 0; i < 4; i++) for (j = 0; j < 4; j++) {
      var s = 0;
      for (k = 0; k < 4; k++) s += a[k * 4 + j] * b[i * 4 + k];
      o[i * 4 + j] = s;
    }
    return o;
  }
  function perspective(fovy, asp, n, f) {
    var t = 1 / Math.tan(fovy / 2);
    return new Float32Array([t / asp, 0, 0, 0, 0, t, 0, 0, 0, 0, (f + n) / (n - f), -1,
                             0, 0, 2 * f * n / (n - f), 0]);
  }
  function lookAt(eye, at, up) {
    function s(a, b) { return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]; }
    function x(a, b) {
      return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
    }
    function d(a, b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
    function nz(a) { var m = Math.sqrt(d(a, a)) || 1; return [a[0] / m, a[1] / m, a[2] / m]; }
    var z = nz(s(eye, at)), xx = nz(x(up, z)), y = x(z, xx);
    return new Float32Array([
      xx[0], y[0], z[0], 0, xx[1], y[1], z[1], 0, xx[2], y[2], z[2], 0,
      -d(xx, eye), -d(y, eye), -d(z, eye), 1]);
  }

  // Simple ear clipping — the polygons are small rectilinear rooms.
  function triArea2(a, b, c) {
    return (b[0] - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (b[1] - a[1]);
  }
  function inTri(p, a, b, c) {
    var d1 = triArea2(p, a, b), d2 = triArea2(p, b, c), d3 = triArea2(p, c, a);
    var neg = (d1 < 0) || (d2 < 0) || (d3 < 0);
    var pos = (d1 > 0) || (d2 > 0) || (d3 > 0);
    return !(neg && pos);
  }
  function triangulate(poly) {
    var n = poly.length, idx = [], i, area = 0;
    for (i = 0; i < n; i++) {
      var j = (i + 1) % n;
      area += poly[i][0] * poly[j][1] - poly[j][0] * poly[i][1];
      idx.push(i);
    }
    var ccw = area > 0, tris = [], guard = 0;
    while (idx.length > 3 && guard++ < 500) {
      var cut = false;
      for (i = 0; i < idx.length; i++) {
        var a = idx[(i + idx.length - 1) % idx.length], b = idx[i],
            c = idx[(i + 1) % idx.length];
        var cr = triArea2(poly[a], poly[b], poly[c]);
        if (ccw ? cr <= 1e-7 : cr >= -1e-7) continue;
        var ok = true, m;
        for (m = 0; m < idx.length; m++) {
          var p = idx[m];
          if (p === a || p === b || p === c) continue;
          if (inTri(poly[p], poly[a], poly[b], poly[c])) { ok = false; break; }
        }
        if (ok) { tris.push([a, b, c]); idx.splice(i, 1); cut = true; break; }
      }
      if (!cut) break;
    }
    if (idx.length === 3) tris.push([idx[0], idx[1], idx[2]]);
    return tris;
  }

  function viewer(section, room) {
    var cv = section.querySelector('canvas');
    var ovl = section.querySelector('.ovl');
    var ro = section.querySelector('.ro');
    var gl = null;
    try {
      gl = cv.getContext('webgl', { antialias: true, alpha: true, depth: true })
        || cv.getContext('experimental-webgl', { antialias: true, alpha: true, depth: true });
    } catch (e) { gl = null; }
    if (!gl) {
      section.querySelector('.v3d').innerHTML =
        '<p style="padding:20px;font-size:11px;color:var(--ink-2)" class="mono">'
        + 'This view needs WebGL, which this browser has turned off. '
        + 'Every dimension it would show is on the plan above.</p>';
      return null;
    }
    var poly = room.polygon;
    var t = room.thick_in || 4, ceil = room.ceiling ? room.ceiling['in'] : 96;

    // Outward normal per run: interior is on the polygon side, so outward is
    // the right side of each directed edge for CCW polygons, left for CW.
    var n = poly.length, area = 0, i;
    for (i = 0; i < n; i++) {
      var j = (i + 1) % n;
      area += poly[i][0] * poly[j][1] - poly[j][0] * poly[i][1];
    }
    var ccw = area > 0;
    function runGeom(i) {
      var a = poly[i], b = poly[(i + 1) % n];
      var ux = b[0] - a[0], uy = b[1] - a[1];
      var L = Math.hypot(ux, uy) || 1;
      ux /= L; uy /= L;
      var nx = ccw ? uy : -uy, ny = ccw ? -ux : ux;
      return { a: a, u: [ux, uy], n: [nx, ny], L: L };
    }

    var M = { pos: [], nrm: [], mat: [], lin: [], acc: [] };
    var bmin = [1e9, 1e9, 1e9], bmax = [-1e9, -1e9, -1e9];
    function pt(o, u, du, nn, dn, z) {
      var p = [o[0] + u[0] * du + nn[0] * dn, o[1] + u[1] * du + nn[1] * dn, z];
      for (var k = 0; k < 3; k++) {
        if (p[k] < bmin[k]) bmin[k] = p[k];
        if (p[k] > bmax[k]) bmax[k] = p[k];
      }
      return p;
    }
    function quad(a, b, c, d, nrm, m) {
      [a, b, c, a, c, d].forEach(function (p) {
        M.pos.push(p[0], p[1], p[2]);
        M.nrm.push(nrm[0], nrm[1], nrm[2]);
        M.mat.push(m);
      });
    }
    function edge(a, b) { M.lin.push(a[0], a[1], a[2], b[0], b[1], b[2]); }
    // Box: corner o on the interior face at run offset, u along the run for
    // len, nn outward (or inward) for dep, z0..z1 up.
    function box(o, u, len, nn, dep, z0, z1, m) {
      var p000 = pt(o, u, 0, nn, 0, z0), p100 = pt(o, u, len, nn, 0, z0),
          p110 = pt(o, u, len, nn, dep, z0), p010 = pt(o, u, 0, nn, dep, z0),
          p001 = pt(o, u, 0, nn, 0, z1), p101 = pt(o, u, len, nn, 0, z1),
          p111 = pt(o, u, len, nn, dep, z1), p011 = pt(o, u, 0, nn, dep, z1);
      var un = [-nn[0], -nn[1], 0];
      quad(p000, p100, p101, p001, un, m);                       // interior face
      quad(p010, p110, p111, p011, nn.concat(0), m);             // outer face
      quad(p000, p010, p011, p001, [-u[0], -u[1], 0], m);        // start cap
      quad(p100, p110, p111, p101, [u[0], u[1], 0], m);          // end cap
      quad(p001, p101, p111, p011, [0, 0, 1], m);                // top
      quad(p000, p100, p110, p010, [0, 0, -1], m);               // bottom
      edge(p000, p100); edge(p100, p110); edge(p110, p010); edge(p010, p000);
      edge(p001, p101); edge(p101, p111); edge(p111, p011); edge(p011, p001);
      edge(p000, p001); edge(p100, p101); edge(p110, p111); edge(p010, p011);
    }

    var MAT_WALL = 0, MAT_FEAT = 1, MAT_ASM = 2, MAT_FLOOR = 3;
    var labels = [];   // {p:[x,y,z], text, cls}

    // Floor
    var tris = triangulate(poly);
    tris.forEach(function (tr) {
      var a = poly[tr[0]], b = poly[tr[1]], c = poly[tr[2]];
      [[a[0], a[1], -0.7], [b[0], b[1], -0.7], [c[0], c[1], -0.7]].forEach(function (p) {
        M.pos.push(p[0], p[1], p[2]);
        M.nrm.push(0, 0, 1);
        M.mat.push(MAT_FLOOR);
      });
    });

    // Walls, split around door openings.
    (room.runs || []).forEach(function (r, i) {
      var g = runGeom(i);
      var m = r.flag ? MAT_ASM : MAT_WALL;
      var spans = (room.doors || []).filter(function (d) { return d.run === i; })
        .map(function (d) { return d; })
        .sort(function (a, b) { return a.at_in - b.at_in; });
      var cur = 0;
      spans.forEach(function (d) {
        if (d.at_in > cur + 0.05) {
          box([g.a[0] + g.u[0] * cur, g.a[1] + g.u[1] * cur],
              g.u, d.at_in - cur, g.n, t, 0, ceil, m);
        }
        var h = Math.min(d.h_in, ceil);
        if (h < ceil - 0.1) {
          box([g.a[0] + g.u[0] * d.at_in, g.a[1] + g.u[1] * d.at_in],
              g.u, d.w_in, g.n, t, h, ceil, m);
        }
        cur = d.at_in + d.w_in;
        var lc = [g.a[0] + g.u[0] * (d.at_in + d.w_in / 2),
                  g.a[1] + g.u[1] * (d.at_in + d.w_in / 2)];
        var asm = d.at_flag || d.w_flag;
        labels.push({
          p: [lc[0], lc[1], h * 0.55],
          text: 'door ' + arch(d.w_in) + ' at ' + arch(d.at_in)
            + (d.at_flag ? ' ASSUMED' : ''),
          cls: asm ? 'asm' : ''
        });
      });
      if (g.L > cur + 0.05) {
        box([g.a[0] + g.u[0] * cur, g.a[1] + g.u[1] * cur],
            g.u, g.L - cur, g.n, t, 0, ceil, m);
      }
      labels.push({
        p: [g.a[0] + g.u[0] * g.L / 2 + g.n[0] * (t + 13),
            g.a[1] + g.u[1] * g.L / 2 + g.n[1] * (t + 13), 2],
        text: arch(r['in']) + (r.flag ? ' ' + r.flag.toUpperCase() : ''),
        cls: r.flag ? 'asm' : ''
      });
    });

    // Features — the same massing the builder makes: heater 24" tall,
    // bulkhead head..ceiling across the room, window 1" deep sill..ceiling.
    (room.features || []).forEach(function (f) {
      var g = runGeom(f.run);
      var inw = [-g.n[0], -g.n[1]];
      var flagged = ['from', 'length', 'width', 'depth', 'head', 'sill']
        .some(function (k) { return f[k + '_flag']; });
      var m = flagged ? MAT_ASM : MAT_FEAT;
      var o = [g.a[0] + g.u[0] * (f.from_in || 0), g.a[1] + g.u[1] * (f.from_in || 0)];
      if (f.type === 'heater') {
        box(o, g.u, f.length_in, inw, f.depth_in || 10, 0, 24, m);
        labels.push({
          p: [o[0] + g.u[0] * f.length_in / 2 + inw[0] * (f.depth_in + 8),
              o[1] + g.u[1] * f.length_in / 2 + inw[1] * (f.depth_in + 8), 27],
          text: 'heater ' + arch(f.length_in), cls: 'dim2'
        });
      } else if (f.type === 'bulkhead') {
        var ext = 0;
        poly.forEach(function (p) {
          var d = (p[0] - g.a[0]) * inw[0] + (p[1] - g.a[1]) * inw[1];
          if (d > ext) ext = d;
        });
        box(o, g.u, f.length_in, inw, ext, Math.min(f.head_in, ceil), ceil, m);
        labels.push({
          p: [o[0] + g.u[0] * f.length_in / 2 + inw[0] * ext / 2,
              o[1] + g.u[1] * f.length_in / 2 + inw[1] * ext / 2,
              (Math.min(f.head_in, ceil) + ceil) / 2],
          text: 'bulkhead, head ' + arch(f.head_in), cls: 'dim2'
        });
      } else if (f.type === 'window') {
        // sill_in is required on a window, so this is never null. The
        // fallback matches build-takeoff.rb (`|| 0.0`) rather than the
        // retired room band sill, so the sheet can never draw a window
        // somewhere the model would not build it.
        var sill = f.sill_in != null ? f.sill_in : 0;
        box(o, g.u, f.width_in, inw, 1, Math.min(sill, ceil), ceil, m);
        labels.push({
          p: [o[0] + g.u[0] * f.width_in / 2, o[1] + g.u[1] * f.width_in / 2,
              (Math.min(sill, ceil) + ceil) / 2],
          text: 'window ' + arch(f.width_in), cls: 'dim2'
        });
      }
    });

    // Ceiling-height dimension: a vertical accent line off the first corner.
    var g0 = runGeom(0), gl_ = runGeom(n - 1);
    var ox = g0.n[0] + gl_.n[0], oy = g0.n[1] + gl_.n[1];
    var om = Math.hypot(ox, oy) || 1;
    ox = ox / om; oy = oy / om;
    var cx = poly[0][0] + ox * (t + 16), cy = poly[0][1] + oy * (t + 16);
    M.acc.push(cx, cy, 0, cx, cy, ceil);
    M.acc.push(cx - 4, cy - 4, 0, cx + 4, cy + 4, 0);
    M.acc.push(cx - 4, cy - 4, ceil, cx + 4, cy + 4, ceil);
    labels.push({
      p: [cx, cy, ceil / 2],
      text: 'ceil ' + arch(ceil) + (room.ceiling && room.ceiling.flag ? ' ASSUMED' : ''),
      cls: room.ceiling && room.ceiling.flag ? 'asm' : ''
    });

    // GL plumbing (docs/tube-drying-stand.html's shaders, one more colour).
    var VS = 'attribute vec3 aPos; attribute vec3 aNrm; attribute float aMat;'
      + 'uniform mat4 uMVP; varying vec3 vN; varying float vM;'
      + 'void main(){ vN = aNrm; vM = aMat; gl_Position = uMVP * vec4(aPos, 1.0); }';
    var FS = 'precision mediump float; varying vec3 vN; varying float vM;'
      + 'uniform vec3 uC0; uniform vec3 uC1; uniform vec3 uC2; uniform vec3 uC3;'
      + 'uniform vec3 uLight;'
      + 'void main(){ vec3 nn = normalize(vN); if (!gl_FrontFacing) nn = -nn;'
      + ' float d = 0.6 + 0.4 * max(dot(nn, normalize(uLight)), 0.0);'
      + ' vec3 c = uC0; if (vM > 2.5) c = uC3; else if (vM > 1.5) c = uC2;'
      + ' else if (vM > 0.5) c = uC1;'
      + ' gl_FragColor = vec4(c * d, 1.0); }';
    var LVS = 'attribute vec3 aPos; uniform mat4 uMVP;'
      + 'void main(){ gl_Position = uMVP * vec4(aPos, 1.0); }';
    var LFS = 'precision mediump float; uniform vec4 uCol;'
      + 'void main(){ gl_FragColor = uCol; }';
    function compile(src, type) {
      var s = gl.createShader(type);
      gl.shaderSource(s, src); gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS))
        throw new Error(gl.getShaderInfoLog(s));
      return s;
    }
    function program(vs, fs) {
      var p = gl.createProgram();
      gl.attachShader(p, compile(vs, gl.VERTEX_SHADER));
      gl.attachShader(p, compile(fs, gl.FRAGMENT_SHADER));
      gl.linkProgram(p);
      if (!gl.getProgramParameter(p, gl.LINK_STATUS))
        throw new Error(gl.getProgramInfoLog(p));
      return p;
    }
    var progT = program(VS, FS), progL = program(LVS, LFS);
    function buf(data) {
      var b = gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, b);
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(data), gl.STATIC_DRAW);
      return b;
    }
    var bufP = buf(M.pos), bufN = buf(M.nrm), bufM = buf(M.mat),
        bufL = buf(M.lin), bufA = buf(M.acc);
    var nTri = M.pos.length / 3, nLin = M.lin.length / 3, nAcc = M.acc.length / 3;

    var HOME = { az: 36, el: 28, zoom: 1 };
    var st = { az: HOME.az, el: HOME.el, zoom: HOME.zoom };
    var mid = [(bmin[0] + bmax[0]) / 2, (bmin[1] + bmax[1]) / 2, (bmin[2] + bmax[2]) / 2];
    var rad = 0.5 * Math.hypot(bmax[0] - bmin[0], bmax[1] - bmin[1], bmax[2] - bmin[2]);
    var COL = tokens();

    // Labels live in an HTML overlay, projected each draw, so they stay
    // horizontal and legible at every rotation.
    var spans = labels.map(function (lb) {
      var s = document.createElement('span');
      s.textContent = lb.text;
      if (lb.cls) s.className = lb.cls;
      ovl.appendChild(s);
      return s;
    });

    function attr(prog, name, b, size) {
      var l = gl.getAttribLocation(prog, name);
      if (l < 0) return;
      gl.bindBuffer(gl.ARRAY_BUFFER, b);
      gl.enableVertexAttribArray(l);
      gl.vertexAttribPointer(l, size, gl.FLOAT, false, 0, 0);
    }
    function draw() {
      var dpr = Math.min(window.devicePixelRatio || 1, 2);
      var w = cv.clientWidth, h = cv.clientHeight;
      if (!w || !h) return;
      cv.width = Math.round(w * dpr); cv.height = Math.round(h * dpr);
      gl.viewport(0, 0, cv.width, cv.height);
      gl.clearColor(0, 0, 0, 0);
      gl.enable(gl.DEPTH_TEST);
      gl.disable(gl.CULL_FACE);
      gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

      var fov = 32 * Math.PI / 180, asp = w / h;
      var dist = rad / Math.sin(Math.min(fov, 2 * Math.atan(Math.tan(fov / 2) * asp)) / 2)
        * 1.12 / st.zoom;
      var az = st.az * Math.PI / 180, el = st.el * Math.PI / 180;
      var eye = [mid[0] + dist * Math.cos(el) * Math.sin(az),
                 mid[1] - dist * Math.cos(el) * Math.cos(az),
                 mid[2] + dist * Math.sin(el)];
      var mvp = mul(perspective(fov, asp, dist * 0.05, dist * 4),
                    lookAt(eye, mid, [0, 0, 1]));

      gl.useProgram(progT);
      gl.uniformMatrix4fv(gl.getUniformLocation(progT, 'uMVP'), false, mvp);
      gl.uniform3fv(gl.getUniformLocation(progT, 'uC0'), COL.wall);
      gl.uniform3fv(gl.getUniformLocation(progT, 'uC1'), COL.feat);
      gl.uniform3fv(gl.getUniformLocation(progT, 'uC2'), COL.asm);
      gl.uniform3fv(gl.getUniformLocation(progT, 'uC3'), COL.floor);
      gl.uniform3fv(gl.getUniformLocation(progT, 'uLight'), [-0.4, -0.6, 0.69]);
      attr(progT, 'aPos', bufP, 3);
      attr(progT, 'aNrm', bufN, 3);
      attr(progT, 'aMat', bufM, 1);
      gl.enable(gl.POLYGON_OFFSET_FILL);
      gl.polygonOffset(1.0, 1.0);
      gl.drawArrays(gl.TRIANGLES, 0, nTri);
      gl.disable(gl.POLYGON_OFFSET_FILL);

      gl.useProgram(progL);
      gl.uniformMatrix4fv(gl.getUniformLocation(progL, 'uMVP'), false, mvp);
      gl.enable(gl.BLEND);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
      gl.uniform4f(gl.getUniformLocation(progL, 'uCol'),
                   COL.ink[0], COL.ink[1], COL.ink[2], 0.5);
      attr(progL, 'aPos', bufL, 3);
      gl.drawArrays(gl.LINES, 0, nLin);
      gl.uniform4f(gl.getUniformLocation(progL, 'uCol'),
                   COL.accent[0], COL.accent[1], COL.accent[2], 0.9);
      attr(progL, 'aPos', bufA, 3);
      gl.drawArrays(gl.LINES, 0, nAcc);
      gl.disable(gl.BLEND);

      labels.forEach(function (lb, i) {
        var p = lb.p;
        var cxp = mvp[0] * p[0] + mvp[4] * p[1] + mvp[8] * p[2] + mvp[12];
        var cyp = mvp[1] * p[0] + mvp[5] * p[1] + mvp[9] * p[2] + mvp[13];
        var cwp = mvp[3] * p[0] + mvp[7] * p[1] + mvp[11] * p[2] + mvp[15];
        var s = spans[i];
        if (cwp <= 0.001) { s.hidden = true; return; }
        var px = (cxp / cwp * 0.5 + 0.5) * w, py = (0.5 - cyp / cwp * 0.5) * h;
        if (px < -60 || px > w + 60 || py < -20 || py > h + 20) {
          s.hidden = true; return;
        }
        s.hidden = false;
        s.style.left = px + 'px';
        s.style.top = py + 'px';
      });
      ro.textContent = 'AZ ' + Math.round((st.az % 360 + 360) % 360) + '°  EL '
        + Math.round(st.el) + '°  ×' + st.zoom.toFixed(2);
    }

    var drag = null;
    cv.addEventListener('pointerdown', function (e) {
      drag = { x: e.clientX, y: e.clientY, az: st.az, el: st.el };
      cv.setPointerCapture(e.pointerId);
    });
    cv.addEventListener('pointermove', function (e) {
      if (!drag) return;
      st.az = drag.az - (e.clientX - drag.x) * 0.45;
      st.el = Math.max(-15, Math.min(88, drag.el + (e.clientY - drag.y) * 0.35));
      draw();
    });
    function endDrag() { drag = null; }
    cv.addEventListener('pointerup', endDrag);
    cv.addEventListener('pointercancel', endDrag);
    cv.addEventListener('wheel', function (e) {
      e.preventDefault();
      st.zoom = Math.max(0.5, Math.min(3, st.zoom * Math.exp(-e.deltaY * 0.0012)));
      draw();
    }, { passive: false });
    cv.tabIndex = 0;
    cv.addEventListener('keydown', function (e) {
      var step = e.shiftKey ? 15 : 5, used = true;
      if (e.key === 'ArrowLeft') st.az += step;
      else if (e.key === 'ArrowRight') st.az -= step;
      else if (e.key === 'ArrowUp') st.el = Math.min(88, st.el + step);
      else if (e.key === 'ArrowDown') st.el = Math.max(-15, st.el - step);
      else if (e.key === 'r' || e.key === 'R') {
        st.az = HOME.az; st.el = HOME.el; st.zoom = HOME.zoom;
      } else used = false;
      if (used) { e.preventDefault(); draw(); }
    });
    section.querySelector('.rst').addEventListener('click', function () {
      st.az = HOME.az; st.el = HOME.el; st.zoom = HOME.zoom; draw();
    });

    draw();
    return { draw: draw, retoken: function () { COL = tokens(); draw(); } };
  }

  var viewers = [];
  var byName = {};
  (LOCK.rooms || []).forEach(function (r) { byName[r.name] = r; });
  document.querySelectorAll('section.room[data-room]').forEach(function (sec) {
    var room = byName[sec.getAttribute('data-room')];
    if (!room || !room.polygon || !sec.querySelector('.v3d canvas')) return;
    try {
      var v = viewer(sec, room);
      if (v) viewers.push(v);
    } catch (e) {
      var el = sec.querySelector('.v3d');
      if (el) el.innerHTML = '<p style="padding:20px;font-size:11px;'
        + 'color:var(--bad)" class="mono">3D view failed: ' + String(e).replace(/</g, '&lt;')
        + '. The plan above is unaffected.</p>';
    }
  });
  window.addEventListener('resize', function () {
    viewers.forEach(function (v) { v.draw(); });
  });
  if (window.matchMedia) {
    var mq = window.matchMedia('(prefers-color-scheme: dark)');
    var onTheme = function () { viewers.forEach(function (v) { v.retoken(); }); };
    if (mq.addEventListener) mq.addEventListener('change', onTheme);
    else if (mq.addListener) mq.addListener(onTheme);
    new MutationObserver(onTheme)
      .observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
  }

  // --------------------------------------------------------------- autotest --
  // #autotest drives the same code paths the UI uses and reports into the
  // DOM, so a headless --dump-dom run verifies the page end to end.
  if (location.hash === '#autotest') {
    var fails = [];
    function chk(ok, m) { if (!ok) fails.push(m); }
    chk(Math.abs(parseLen("12'6\"") - 150) < 1e-9, 'parseLen 12\'6"');
    chk(Math.abs(parseLen("12' 6 1/2\"") - 150.5) < 1e-9, 'parseLen frac');
    chk(Math.abs(parseLen('150') - 150) < 1e-9, 'bare number is inches');
    chk(isNaN(parseLen('about 8ish')), 'junk rejected');
    var v0 = document.querySelector('.val');
    chk(!!v0, 'an editable value exists');
    if (v0) {
      recordEdit(v0.getAttribute('data-room'), v0.getAttribute('data-field'),
                 v0.getAttribute('data-old'),
                 { v: v0.getAttribute('data-old'), src: 'stated autotest re-check' });
    }
    var sec0 = document.querySelector('section.room[data-room]');
    if (sec0) {
      state.review[sec0.getAttribute('data-room')] = 'approved';
      renderPatch();
    }
    try {
      var p = JSON.parse($patch.value);
      chk(p.patch === 1 && p.edits.length === 1 && p.edits[0]['new'].src
        === 'stated autotest re-check', 'patch box holds the structured edit');
    } catch (e) { fails.push('patch box is not JSON: ' + e); }
    chk(viewers.length > 0, '3D viewer initialised (' + viewers.length + ')');
    var d = document.createElement('div');
    d.id = 'autotest-result';
    d.textContent = fails.length ? 'AUTOTEST FAIL: ' + fails.join('; ')
      : 'AUTOTEST OK (' + viewers.length + ' viewers)';
    document.body.appendChild(d);
    var pp = document.createElement('pre');
    pp.id = 'autotest-patch';
    pp.textContent = $patch.value;
    document.body.appendChild(pp);
    // Leave one edit form open so a screenshot shows the rendered form.
    var v1 = document.querySelectorAll('.val')[1];
    if (v1) v1.click();
  }
})();
"""


def dialog_grammar_js():
    """The dialog's own parseLen and arch, extracted verbatim by text from
    scripts/build-room.html — the same extraction takeoff-vectors.html does
    to run the parity vectors against the shipped dialog. The review sheet
    embeds THIS text at generation time (the /*@GRAMMAR@*/ marker in JS), so
    the dimension grammar keeps living in exactly two places: parseLen there
    and parse_len here. Fails BY NAME if the dialog moves or the functions
    change shape — a silently-empty grammar would be the old defect back."""
    p = os.path.join(HERE, 'build-room.html')
    if not os.path.exists(p):
        raise SystemExit('FAIL grammar: scripts/build-room.html not found at '
                         '%s — the review sheet embeds the dialog\'s own '
                         'parseLen/arch and cannot be generated without it' % p)
    src = io.open(p, encoding='utf-8').read()
    out = []
    for name, arg in (('parseLen', 's'), ('arch', 'n')):
        m = re.search(r'function %s\(%s\)\{[\s\S]*?\n  \}' % (name, arg), src)
        if not m:
            raise SystemExit('FAIL grammar: could not extract function %s '
                             'from scripts/build-room.html — the dialog '
                             'changed shape; update dialog_grammar_js '
                             '(and takeoff-vectors.html, which extracts the '
                             'same way)' % name)
        out.append(m.group(0))
    return '\n  '.join(out)


def badge(src, flag):
    if flag == 'assumed':
        return '<span class="b asm">ASSUMED</span>'
    if flag == 'default':
        return '<span class="b def">DEFAULT</span>'
    if flag == 'derived':
        return '<span class="b def">DERIVED</span>'
    kind = (src or '').split(' ', 1)[0]
    if kind == 'plan-vector':
        return '<span class="b vec">VECTOR</span>'
    if kind == 'stated':
        return '<span class="b pen">STATED</span>'
    return '<span class="b pen">PEN</span>'


# ------------------------------------------------- photos + the transcription --

PHOTO_EDGE = 1600   # long edge, px — pen callouts stay legible, page stays small
PHOTO_QUALITY = 78

IMG_RE = re.compile(r'(IMG_[A-Za-z0-9]+)')


def load_photos(lock, takeoff_path, embed):
    """{IMG_name: {'path', 'uri'|None, 'err'|None}} for every image source.

    uri is a downsampled JPEG data URI when embed is true and the file is
    readable; otherwise None with err naming why (missing file, no PIL...).
    The photos are gitignored client assets — they reach the sheet only
    through this explicit flag, and the sheet file itself is gitignored."""
    base = os.path.dirname(os.path.abspath(takeoff_path))
    out = {}
    for s in (lock.get('sources') or []):
        m = re.search(r'(IMG_[A-Za-z0-9]+)\.(jpe?g|png|webp)$', str(s), re.I)
        if not m:
            continue
        name = m.group(1)
        rec = {'path': str(s), 'uri': None, 'err': None}
        if embed:
            p = os.path.join(base, str(s).replace('/', os.sep))
            if not os.path.exists(p):
                rec['err'] = 'file not found: %s' % p
            else:
                try:
                    import base64
                    from PIL import Image
                    im = Image.open(p)
                    # Deliberately NOT applying the EXIF orientation: a phone
                    # shooting a plan flat on a table gets an arbitrary
                    # orientation tag (gravity is ambiguous straight down),
                    # and on this job all three tags are wrong while the raw
                    # pixels read upright. Re-encoding strips the tag so the
                    # browser shows the same orientation. A sideways photo is
                    # loud and cosmetic; the reviewer will say so.
                    im.thumbnail((PHOTO_EDGE, PHOTO_EDGE))
                    buf = io.BytesIO()
                    im.convert('RGB').save(buf, 'JPEG', quality=PHOTO_QUALITY)
                    rec['uri'] = ('data:image/jpeg;base64,'
                                  + base64.b64encode(buf.getvalue()).decode('ascii'))
                except Exception as e:
                    rec['err'] = '%s: %s' % (type(e).__name__, e)
        out[name] = rec
    return out


def _img_of(src):
    m = IMG_RE.search(str(src or ''))
    return m.group(1) if m else None


def room_ledger(room):
    """[(stated, target, note, img, flag)] — every value in the room that
    reads from a photo, so a reader can tick each pen mark against the number
    it became. Assumed values are listed too, marked as NOT on any photo."""
    rows = []

    def add(nv_in, src, flag, reason, target, note, parts=None):
        img = _img_of(src)
        if flag in ('assumed', 'default', 'derived'):
            rows.append(('(%s %s)' % (flag, arch(nv_in)), target,
                         reason or note, None, flag))
            return
        stated = arch(nv_in)
        if parts:
            stated += ' = ' + ' + '.join(arch(p) for p in parts)
        rows.append((stated, target, note, img, flag))

    for i, r in enumerate(room.get('runs') or []):
        add(r['in'], r['src'], r['flag'], r.get('reason'),
            'run %d (%s)' % (i, r['d']), r.get('note'), r.get('parts'))
    c = room.get('ceiling')
    if c:
        add(c['in'], c['src'], c['flag'], c.get('reason'), 'ceiling', c.get('note'))
    for j, d in enumerate(room.get('doors') or []):
        add(d['w_in'], d['w_src'], d['w_flag'], None, 'door %d width' % j, None)
        add(d['at_in'], d['at_src'], d['at_flag'], d.get('at_reason'),
            'door %d position (from %s)'
            % (j, d.get('at_from') or 'the run\'s start corner'), None)
    for j, f in enumerate(room.get('features') or []):
        for key in ('from', 'length', 'width', 'depth', 'head', 'sill'):
            if (key + '_in') in f:
                add(f[key + '_in'], f.get(key + '_src'), f.get(key + '_flag'),
                    None, '%s %s' % (f['type'], key), None)
    return rows


def room_images(room):
    """The photo(s) this room reads from — IMG tokens in its measured srcs,
    most-used first."""
    counts = {}
    for stated, target, note, img, flag in room_ledger(room):
        if img:
            counts[img] = counts.get(img, 0) + 1
    return sorted(counts, key=lambda k: -counts[k])


def val_span(room_name, field, inches):
    """An editable value: the page turns these into edit forms whose output
    lands in the structured patch box."""
    a = arch(inches)
    return ('<span class="val" data-room="%s" data-field="%s" data-old="%s">%s'
            '</span>' % (esc(room_name), esc(field), esc(a), esc(a)))


# ---------------------------------------------------------------- the patch --

FIELD_RE = re.compile(r'^(runs|doors|features)\[(\d+)\](?:\.([A-Za-z]+))?$')
DOOR_SUB = ('at', 'w', 'h')
FEAT_SUB = ('from', 'length', 'width', 'depth', 'head', 'sill')


def _stated_inches(obj):
    """Inches currently stated by a raw take-off value object, or None."""
    if isinstance(obj, dict):
        if 'assumed' in obj:
            return parse_len(obj['assumed'])
        if 'v' in obj:
            return parse_len(obj['v'])
    elif isinstance(obj, (int, float, str)):
        return parse_len(obj)
    return None


def apply_patch(data, patch):
    """Apply a review-sheet patch to raw take-off data, in place.

    Returns (errors, n_applied, review). Every failure is by name and any
    failure means NOTHING was mutated for that edit; the caller only writes
    the file when errors is empty. The two rules that bind everything else
    bind here too: an edit with no source is refused (a measurement claim
    with no source is the dialog's old invented at:36"), and an `old` that
    does not match the current file is refused (the patch was written against
    a different take-off)."""
    errs = []
    if not isinstance(patch, dict) or patch.get('patch') != 1:
        errs.append(('patch', 'not a review-sheet patch — expected '
                              '{"patch": 1, "job": ..., "edits": [...]}'))
        return errs, 0, {}
    pj, dj = str(patch.get('job') or ''), str(data.get('job') or '')
    if pj and dj and pj != dj:
        errs.append(('patch job', 'patch is for %r but the file is %r — '
                                  'wrong take-off' % (pj, dj)))
        return errs, 0, {}
    rooms = {}
    for r in (data.get('rooms') or []):
        rooms[str(r.get('name', '')).strip()] = r
    review = {}
    for k, v in (patch.get('review') or {}).items():
        if v not in ('approved', 'needs-changes'):
            errs.append(('review %s' % k, 'status %r is not approved/needs-changes' % (v,)))
        elif k not in rooms:
            errs.append(('review %s' % k, 'no such room'))
        else:
            review[k] = v

    n = 0
    for k, e in enumerate(patch.get('edits') or []):
        if not isinstance(e, dict):
            errs.append(('edit %d' % k, 'not an object'))
            continue
        name = 'edit %d (%s %s)' % (k, e.get('room'), e.get('field'))
        room = rooms.get(str(e.get('room') or ''))
        if room is None:
            errs.append((name, 'room %r is not in the take-off' % (e.get('room'),)))
            continue
        new = e.get('new')
        has_src = isinstance(new, dict) and (
            ('v' in new and str(new.get('src', '')).strip())
            or ('assumed' in new and str(new.get('reason', '')).strip()))
        if not has_src:
            errs.append((name, 'new value carries no source — every edit is a '
                               'measurement claim; give {"v", "src"} or '
                               '{"assumed", "reason"}'))
            continue
        if _stated_inches(new) is None:
            errs.append((name, 'new value does not parse'))
            continue
        field = str(e.get('field') or '')
        m = FIELD_RE.match(field)
        container = key = None
        if field in ('ceiling', 'thick'):
            container, key = room, field
        elif m:
            kind, idx, sub = m.group(1), int(m.group(2)), m.group(3)
            lst = room.get(kind) or []
            if idx >= len(lst):
                errs.append((name, '%s[%d] does not exist (%d present)'
                             % (kind, idx, len(lst))))
                continue
            if kind == 'runs' and sub is None:
                container, key = lst, idx
            elif kind == 'doors' and sub in DOOR_SUB:
                container, key = lst[idx], sub
            elif kind == 'features' and sub in FEAT_SUB:
                container, key = lst[idx], sub
        if container is None:
            errs.append((name, 'field %r is not editable — one of: runs[i], '
                               'ceiling, thick, doors[j].at/.w/.h, '
                               'features[j].from/.length/.width/.depth/.head/.sill'
                         % (field,)))
            continue
        current = container[key] if (isinstance(key, int) or key in container) \
            else None
        cur_in = _stated_inches(current)
        if current is None:
            # An absent optional value is currently the house default — the
            # sheet shows it flagged DEFAULT, and measuring it is exactly the
            # edit this exists for.
            if key == 'h':
                cur_in = HOUSE['door_h']
            elif key == 'thick':
                cur_in = HOUSE['thick']
        old_in = parse_len(e.get('old'))
        if old_in is None:
            errs.append((name, 'old %r does not parse' % (e.get('old'),)))
            continue
        # `old` comes back from the sheet at arch()'s tenth-of-an-inch
        # display precision, never exact — see DISPLAY_TOL.
        if cur_in is None or abs(cur_in - old_in) > DISPLAY_TOL:
            errs.append((name, 'old is %s but the file currently says %s — '
                               'the patch was written against a different '
                               'take-off; regenerate the sheet and re-review'
                         % (arch(old_in),
                            arch(cur_in) if cur_in is not None else 'nothing')))
            continue
        if isinstance(key, int):
            # A run: keep its direction, replace the value wholesale. If the
            # old run carried a parts chain the edit drops it unless the new
            # value brings its own — the reviewer changed the number, and a
            # stale chain would contradict it.
            replacement = dict(new)
            replacement['d'] = container[key].get('d')
            container[key] = replacement
        else:
            container[key] = dict(new)
        n += 1
    return errs, n, review


def html_report(ck, lock, path, photos=None):
    """The review sheet — the page Gabe reads. Look approved via
    .forge/scoper/takeoff-review.mockup.html; same style tokens as
    scripts/build-room.html. `photos` comes from load_photos(); when a photo
    is embedded the sheet shows the pen source beside the interpretation so
    review is a comparison, not a memory test."""
    photos = photos or {}
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
        h.append('<section class="room" data-room="%s"><h2>%s '
                 '<span class="mono">%s</span>'
                 '<span class="rv"><button data-room="%s" data-st="approved">'
                 'APPROVE</button><button data-room="%s" data-st="needs-changes">'
                 'NEEDS CHANGES</button></span></h2>'
                 % (esc(name), esc(name),
                    esc('; '.join(room.get('notes') or [])[:110]),
                    esc(name), esc(name)))

        # The source photo beside the interpretation. The take-off carries no
        # pixel coordinates for the pen marks, so no callout overlay is drawn
        # on the image — instead every value that reads from this photo is
        # listed against the number it became, and the reviewer ticks pen
        # mark against number instead of recalling it.
        imgs = room_images(room)
        primary = imgs[0] if imgs else None
        rec = photos.get(primary) if primary else None
        h.append('<div class="cmp"><div class="ph">')
        if rec and rec.get('uri'):
            h.append('<img class="photo" data-img="%s" alt="Source photo %s — '
                     'the marked-up plan this room was read from">'
                     % (esc(primary), esc(primary)))
            h.append('<div class="phcap">%s — click to enlarge. Every value '
                     'right of here was read off this photo unless marked '
                     'assumed.</div>' % esc(rec['path']))
        elif primary:
            why = (rec.get('err') if rec else
                   'run takeoff-check.py --html --embed-photos to inline it')
            h.append('<div class="noph">photo not embedded — %s<br>%s<br>'
                     'client images stay out of git either way; the sheet '
                     'file is gitignored</div>'
                     % (esc(rec['path'] if rec else primary), esc(why)))
        else:
            h.append('<div class="noph">no photo source recorded for this '
                     'room</div>')
        h.append('</div><div class="ledger">'
                 '<span class="lab">Pen callout &rarr; take-off value</span><table>')
        for stated, target, note, img, flag in room_ledger(room):
            h.append('<tr><td class="k">%s</td><td class="v">%s%s%s</td></tr>'
                     % (esc(stated), esc(target),
                        ' <span style="color:var(--warn)">not on any photo</span>'
                        if flag in ('assumed', 'default') else
                        (' · %s' % esc(img) if img and len(imgs) > 1 else ''),
                        '<br><span style="color:var(--ink-3)">%s</span>'
                        % esc(note) if note else ''))
        h.append('</table></div></div>')

        h.append('<div class="roomgrid"><div class="plan">%s</div><div class="facts">'
                 % _svg_room(room))
        h.append('<span class="lab">Stated values — click one to change it</span><table>')
        for i, r in enumerate(room['runs']):
            extra = ''
            if r.get('parts'):
                extra = ('<br>= ' + ' + '.join(arch(p) for p in r['parts'])
                         + (' — ' + esc(r['note']) if r.get('note') else ''))
            elif r.get('note'):
                extra = ' — ' + esc(r['note'])
            h.append('<tr><td class="k">run %d (%s)</td><td class="v">%s %s%s</td></tr>'
                     % (i, r['d'], val_span(name, 'runs[%d]' % i, r['in']),
                        badge(r['src'], r['flag']), extra))
        c = room.get('ceiling')
        if c:
            h.append('<tr><td class="k">ceiling</td><td class="v">%s %s%s</td></tr>'
                     % (val_span(name, 'ceiling', c['in']),
                        badge(c['src'], c['flag']),
                        ' — ' + esc(c['note']) if c.get('note') else ''))
        for j, dd in enumerate(room.get('doors') or []):
            h.append('<tr><td class="k">door %d</td><td class="v">%s wide %s, '
                     'at %s %s, height %s %s</td></tr>'
                     % (j, val_span(name, 'doors[%d].w' % j, dd['w_in']),
                        badge(dd['w_src'], dd['w_flag']),
                        val_span(name, 'doors[%d].at' % j, dd['at_in']),
                        badge(dd['at_src'], dd['at_flag']),
                        val_span(name, 'doors[%d].h' % j, dd['h_in']),
                        badge(dd['h_src'], dd['h_flag'])))
        for j, f in enumerate(room.get('features') or []):
            bits = []
            for key in ('from', 'length', 'width', 'depth', 'head', 'sill'):
                if (key + '_in') in f:
                    bits.append('%s %s' % (
                        key, val_span(name, 'features[%d].%s' % (j, key),
                                      f[key + '_in'])))
            h.append('<tr><td class="k">%s</td><td class="v">run %d, %s</td></tr>'
                     % (esc(f['type']), f['run'], ', '.join(bits)))
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
        h.append('</div></div>')
        # The rotatable 3D view — built from the LOCK numbers, i.e. what
        # would actually be built. ASSUMED walls/values draw in the warn
        # colour there too.
        if room.get('polygon'):
            h.append('<div class="v3d"><canvas aria-label="Rotatable 3D view '
                     'of %s"></canvas><div class="ovl"></div>'
                     '<button class="rst">RESET VIEW</button>'
                     '<div class="ro"></div>'
                     '<div class="hint3d">drag to rotate · scroll to zoom · '
                     'arrows step · R resets</div></div>' % esc(name))
        h.append('</section>')

    h.append('<div id="patchsec"><span class="lab">Review patch — structured, '
             'not prose</span>'
             '<textarea id="patchbox" readonly spellcheck="false"></textarea>'
             '<div class="row"><button id="copybtn">COPY PATCH</button>'
             '<span class="copied"></span></div>'
             '<div class="how">paste it back and run:  python '
             'scripts/takeoff-check.py %s --apply-patch patch.json'
             '<br>every edit carries its measured-vs-assumed source — the page '
             'will not record one without it'
             '<br>numbers apply automatically; anything you typed under '
             '"notes" is for a person to read and act on</div></div>' % esc(path))

    h.append('<footer><span class="hint">%d room%s ready%s · %d assumed value%s '
             'will be flagged in the model<span id="fcounts"></span></span></footer>'
             % (ready, '' if ready == 1 else 's',
                ' · %d blocked by named errors' % blocked if blocked else '',
                len(ck.assumed), '' if len(ck.assumed) == 1 else 's'))
    h.append('</div>')

    # Data + script. </ is escaped so a note containing "</script>" cannot
    # break out of the JSON blocks.
    h.append('<script type="application/json" id="lockdata">%s</script>'
             % json.dumps(lock, ensure_ascii=False).replace('</', '<\\/'))
    uris = {k: v['uri'] for k, v in photos.items() if v.get('uri')}
    if uris:
        h.append('<script type="application/json" id="photodata">%s</script>'
                 % json.dumps(uris).replace('</', '<\\/'))
    h.append('<script>%s</script>'
             % JS.replace('/*@GRAMMAR@*/', dialog_grammar_js()))
    h.append('</body></html>')
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
        ('THE SELFCROSS PROBE: runs sum to zero but revisit a corner — '
         'fails by name, does not build',
         room(runs=[{'d': 'N', 'v': '5\'', 'src': 'pen x'},
                    {'d': 'E', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'S', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'W', 'v': '20\'', 'src': 'pen x'},
                    {'d': 'N', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'E', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'S', 'v': '5\'', 'src': 'pen x'}]),
         False, 'revisits'),
        ('non-adjacent runs that cross fail by name',
         room(runs=[{'d': 'E', 'v': '20\'', 'src': 'pen x'},
                    {'d': 'N', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'W', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'S', 'v': '20\'', 'src': 'pen x'},
                    {'d': 'W', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'N', 'v': '10\'', 'src': 'pen x'}]),
         False, 'cross'),
        ('a run doubling straight back fails by name',
         room(runs=[{'d': 'E', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'W', 'v': '4\'', 'src': 'pen x'},
                    {'d': 'N', 'v': '5\'', 'src': 'pen x'},
                    {'d': 'W', 'v': '6\'', 'src': 'pen x'},
                    {'d': 'S', 'v': '5\'', 'src': 'pen x'}]),
         False, 'doubles'),
        ('an honest L-shaped room still passes',
         room(runs=[{'d': 'E', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'S', 'v': '5\'', 'src': 'pen x'},
                    {'d': 'E', 'v': '2\'', 'src': 'pen x'},
                    {'d': 'S', 'v': '5\'', 'src': 'pen x'},
                    {'d': 'W', 'v': '12\'', 'src': 'pen x'},
                    {'d': 'N', 'v': '10\'', 'src': 'pen x'}]),
         True, None),

        # ---- D2, the winding convention. The blind trial's dangerous gap:
        # seven transcribers all guessed clockwise-from-northwest and nothing
        # written down told them to. A walk the other way closes, mitres and
        # builds clean, and is indistinguishable from a mirrored read.
        ('THE MIRROR: the same L-room walked counter-clockwise closes and '
         'self-intersects nowhere, but is refused by name as undeclared '
         'winding',
         room(runs=[{'d': 'S', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'E', 'v': '12\'', 'src': 'pen x'},
                    {'d': 'N', 'v': '5\'', 'src': 'pen x'},
                    {'d': 'W', 'v': '2\'', 'src': 'pen x'},
                    {'d': 'N', 'v': '5\'', 'src': 'pen x'},
                    {'d': 'W', 'v': '10\'', 'src': 'pen x'}]),
         False, 'COUNTER-CLOCKWISE'),
        ('a counter-clockwise rectangle is refused by name',
         room(runs=[{'d': 'S', 'v': '8\'', 'src': 'pen x'},
                    {'d': 'E', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'N', 'v': '8\'', 'src': 'pen x'},
                    {'d': 'W', 'v': '10\'', 'src': 'pen x'}]),
         False, 'COUNTER-CLOCKWISE'),
        ('a counter-clockwise walk DECLARED with a reason passes (the real '
         'UIC 3190J, whose pen door chain is measured off the north corner)',
         room(winding={'order': 'ccw', 'reason': 'pen chain runs the other way'},
              runs=[{'d': 'W', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'S', 'v': '8\'', 'src': 'pen x'},
                    {'d': 'E', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'N', 'v': '8\'', 'src': 'pen x'}]),
         True, None),
        ('a bare "ccw" with no reason is refused — declaring is a judgment '
         'call and gets recorded like one',
         room(winding='ccw',
              runs=[{'d': 'W', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'S', 'v': '8\'', 'src': 'pen x'},
                    {'d': 'E', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'N', 'v': '8\'', 'src': 'pen x'}]),
         False, 'must be declared with a reason'),
        ('a declaration that contradicts the geometry is refused by name',
         room(winding={'order': 'ccw', 'reason': 'wrong'}), False,
         'the declaration and the geometry disagree'),
        ('a clockwise walk that starts at the wrong corner is refused by name',
         room(runs=[{'d': 'S', 'v': '8\'', 'src': 'pen x'},
                    {'d': 'W', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'N', 'v': '8\'', 'src': 'pen x'},
                    {'d': 'E', 'v': '10\'', 'src': 'pen x'}]),
         False, 'not the NW-most corner'),

        # ---- D3: parts on an assumed value.
        ('an ASSUMED total may now carry the chain that justifies it, and the '
         'chain is checked',
         room(runs=[{'d': 'E', 'assumed': '17\'8"',
                     'reason': 'no wall-to-wall total on the plan; 15" + '
                               '15\'2" + 15" between the heaters',
                     'parts': ['15"', '15\'2"', '15"']},
                    {'d': 'S', 'v': '8\'', 'src': 'pen x'},
                    {'d': 'W', 'v': '17\'8"', 'src': 'pen x'},
                    {'d': 'N', 'v': '8\'', 'src': 'pen x'}]), True, None),
        ('an ASSUMED total whose chain does not sum fails by name',
         room(runs=[{'d': 'E', 'assumed': '17\'8"',
                     'reason': 'chain arithmetic',
                     'parts': ['15"', '15\'2"', '12"']},
                    {'d': 'S', 'v': '8\'', 'src': 'pen x'},
                    {'d': 'W', 'v': '17\'8"', 'src': 'pen x'},
                    {'d': 'N', 'v': '8\'', 'src': 'pen x'}]),
         False, 'the chain does not close'),

        # ---- D5: closure-derived provenance.
        ('a closure-derived run is legal, flagged DERIVED, and needs a note',
         room(runs=[{'d': 'E', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'S', 'v': '8\'', 'src': 'pen x'},
                    {'d': 'W', 'v': '10\'', 'src': 'derived closure',
                     'note': 'unlabelled on the plan; forced by run 0'},
                    {'d': 'N', 'v': '8\'', 'src': 'pen x'}]), True, None),
        ('a derived value with nothing naming the derivation fails by name',
         room(runs=[{'d': 'E', 'v': '10\'', 'src': 'pen x'},
                    {'d': 'S', 'v': '8\'', 'src': 'pen x'},
                    {'d': 'W', 'v': '10\'', 'src': 'derived closure'},
                    {'d': 'N', 'v': '8\'', 'src': 'pen x'}]),
         False, 'must name what it was derived from'),
        ('TWO closure-derived runs on one axis are underdetermined and fail '
         'by name',
         room(runs=[{'d': 'E', 'v': '10\'', 'src': 'derived closure',
                     'note': 'forced'},
                    {'d': 'S', 'v': '8\'', 'src': 'pen x'},
                    {'d': 'W', 'v': '10\'', 'src': 'derived closure',
                     'note': 'forced'},
                    {'d': 'N', 'v': '8\'', 'src': 'pen x'}]),
         False, 'closure forces exactly one unknown per axis'),

        # ---- D4: the enum assumed-escape.
        ('a door with no hinge fails by name instead of silently becoming '
         '"near"',
         room(doors=[{'run': 0, 'w': {'v': '38"', 'src': 'pen x'},
                      'at': {'v': '36"', 'src': 'pen x'}}]),
         False, 'hinge not stated'),
        ('a door whose hinge had to be guessed is legal when recorded',
         room(doors=[{'run': 0, 'w': {'v': '38"', 'src': 'pen x'},
                      'at': {'v': '36"', 'src': 'pen x'},
                      'hinge': {'assumed': 'near',
                                'reason': 'no leaf drawn on the plan'}}]),
         True, None),
        ('an assumed hinge with no reason fails by name',
         room(doors=[{'run': 0, 'w': {'v': '38"', 'src': 'pen x'},
                      'at': {'v': '36"', 'src': 'pen x'},
                      'hinge': {'assumed': 'near'}}]),
         False, 'assumed hinge with no reason'),
        ('a hinge read off a drawn leaf may carry its source',
         room(doors=[{'run': 0, 'w': {'v': '38"', 'src': 'pen x'},
                      'at': {'v': '36"', 'src': 'pen x'},
                      'hinge': {'v': 'far', 'src': 'pen x'}}]), True, None),
        ('an unknown hinge value fails by name',
         room(doors=[{'run': 0, 'w': {'v': '38"', 'src': 'pen x'},
                      'at': {'v': '36"', 'src': 'pen x'},
                      'hinge': 'left'}]),
         False, "'left' is not one of near/far"),

        # ---- the retired band sill, and the window sill that shared its name.
        ('THE NAME COLLISION: a window with no sill fails by name instead of '
         'being invented twice — the sheet drew it at the room band sill 48", '
         'build-takeoff.rb built it at the floor 0"',
         room(features=[{'type': 'window', 'run': 0,
                         'from': {'v': '2\'', 'src': 'pen x'},
                         'width': {'v': '4\'', 'src': 'pen x'}}]),
         False, 'window) sill'),
        ('a window sill that had to be guessed is legal when recorded',
         room(features=[{'type': 'window', 'run': 0,
                         'from': {'v': '2\'', 'src': 'pen x'},
                         'width': {'v': '4\'', 'src': 'pen x'},
                         'sill': {'assumed': '30"',
                                  'reason': 'no sill height on the plan'}}]),
         True, None),
        ('a room-level sill — the retired wall-band split height — is refused '
         'by name, not silently ignored',
         room(sill={'v': '48"', 'src': 'pen x'}), False, 'no longer a thing'),

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
    asm_case = [c for c in cases
                if c[0].startswith('door with assumed at')][0]
    ck, _ = check_file(asm_case[1], 'selftest')
    inv = sorted(a['path'] for a in ck.assumed)
    want = ['T door 0 at', 'T door 0 height']
    ok = inv == want
    print('%-4s inventory is exactly %s' % ('PASS' if ok else 'FAIL', want))
    if not ok:
        print('       got %s' % inv)
        fails += 1

    # ---- the patch path: what the review sheet's copy box emits ------------
    def pcase(label, patch_body, want_ok, want_word=None, check=None,
              quarter=False):
        w = '38 1/4"' if quarter else '38"'
        data = room(doors=[{'run': 0, 'w': {'v': w, 'src': 'pen x'},
                            'at': {'assumed': '6"', 'reason': 'no position'},
                            'hinge': 'near'}])
        patch = {'patch': 1, 'job': 'selftest'}
        patch.update(patch_body)
        errs, n, review = apply_patch(data, patch)
        good = (not errs) == want_ok
        if good and not want_ok and want_word:
            blob = ' '.join(nm + ' ' + m for nm, m in errs).lower()
            good = want_word.lower() in blob
        if good and want_ok and check:
            good = check(data, n, review)
        print('%-4s patch: %s' % ('PASS' if good else 'FAIL', label))
        if not good:
            for nm, m in errs:
                print('       %s: %s' % (nm, m))
            return 1
        return 0

    fails += pcase(
        'a sourced edit applies and the file re-validates',
        {'edits': [{'room': 'T', 'field': 'doors[0].at',
                    'old': '0\'-6"', 'new': {'v': '9"', 'src': 'pen tape'}}],
         'review': {'T': 'approved'}},
        True, None,
        lambda d, n, rv: (n == 1 and rv == {'T': 'approved'}
                          and d['rooms'][0]['doors'][0]['at'] == {'v': '9"', 'src': 'pen tape'}
                          and not check_file(d, 'p')[0].errors))
    fails += pcase(
        'an edit with no source is refused (the invented-at:36 defect)',
        {'edits': [{'room': 'T', 'field': 'doors[0].at',
                    'old': '0\'-6"', 'new': {'v': '9"'}}]},
        False, 'no source')
    fails += pcase(
        'assumed edit with a reason applies',
        {'edits': [{'room': 'T', 'field': 'ceiling', 'old': '8\'6"',
                    'new': {'assumed': '8\'6"', 'reason': 'still unmeasured'}}]},
        True, None,
        lambda d, n, rv: d['rooms'][0]['ceiling'].get('reason') == 'still unmeasured')
    fails += pcase(
        'tenth-rounded old (what the sheet displays) matches a 1/4" value',
        # The sheet shows every value through arch(), rounded to 0.1", and
        # emits THAT string as `old` — so a stored 38 1/4" comes back as
        # 38.2" or 38.3". Staleness is judged at DISPLAY_TOL; comparing at
        # TOL once made every value finer than a tenth unpatchable.
        {'edits': [{'room': 'T', 'field': 'doors[0].w',
                    'old': '3\'-2.3"', 'new': {'v': '38 1/4"', 'src': 'pen tape'}}]},
        True, None,
        lambda d, n, rv: n == 1,
        quarter=True)
    fails += pcase(
        'old that does not match the file is refused (stale patch)',
        {'edits': [{'room': 'T', 'field': 'ceiling', 'old': '9\'0"',
                    'new': {'v': '8\'6"', 'src': 'pen tape'}}]},
        False, 'different')
    # The review sheet must at least render — an unescaped % in the CSS/JS
    # constants once crashed every invocation of this file at import time
    # (eval RESULTS.md F4); rendering here makes that class of break loud.
    ck_h, lock_h = check_file(room(), 'selftest')
    try:
        page = html_report(ck_h, lock_h, 'selftest')
        ok_h = page.startswith('<!DOCTYPE html') and 'lockdata' in page
    except Exception as e:
        page, ok_h = '', False
        print('       html_report raised %s: %s' % (type(e).__name__, e))
    print('%-4s review sheet renders (%d chars)'
          % ('PASS' if ok_h else 'FAIL', len(page)))
    if not ok_h:
        fails += 1

    # The sheet is one big inline <script>, so a single stray character in it
    # is a syntax error that kills the WHOLE block — photos, 3D viewers, the
    # patch box, all of it, silently. That shipped once: a literal newline
    # inside a JS string literal. "It renders" never proved the script parses,
    # so parse it for real when node is on the machine.
    if ok_h:
        import subprocess, tempfile, shutil
        node = shutil.which('node')
        if not node:
            print('SKIP review-sheet JS parse (no node on this machine)')
        else:
            blocks = re.findall(r'<script>(.*?)</script>', page, re.S)
            jsok, why = bool(blocks), 'no inline <script> found'
            for i, b in enumerate(blocks):
                fh = tempfile.NamedTemporaryFile('w', suffix='.js', delete=False,
                                                 encoding='utf-8', newline=chr(10))
                fh.write(b)
                fh.close()
                r = subprocess.run([node, '--check', fh.name],
                                   capture_output=True, text=True)
                os.unlink(fh.name)
                if r.returncode != 0:
                    jsok = False
                    err = [ln for ln in (r.stderr or '').splitlines()
                           if 'Error' in ln] or ['(no message)']
                    why = 'block %d: %s' % (i, err[0].strip())
                    break
            print('%-4s review sheet JS parses (%d block(s))%s'
                  % ('PASS' if jsok else 'FAIL', len(blocks),
                     '' if jsok else ' — ' + str(why)))
            if not jsok:
                fails += 1

    # apply_patch only applies; check_file judges what the edit did. Prove
    # the pair: a run edit keeps its direction, and the polygon it reopens
    # fails the full check by name.
    data2 = room()
    errs2, n2, _ = apply_patch(
        data2, {'patch': 1, 'job': 'selftest',
                'edits': [{'room': 'T', 'field': 'runs[0]', 'old': '10\'',
                           'new': {'v': '10\'2"', 'src': 'stated tape'}}]})
    ck2, _ = check_file(data2, 'p')
    ok2 = (not errs2 and n2 == 1 and data2['rooms'][0]['runs'][0]['d'] == 'E'
           and any('polygon' in nm for nm, _ in ck2.errors))
    print('%-4s patch: run edit keeps d, and the reopened polygon fails the '
          'full check by name' % ('PASS' if ok2 else 'FAIL'))
    if not ok2:
        fails += 1
    fails += pcase(
        'unknown field is refused by name',
        {'edits': [{'room': 'T', 'field': 'doors[0].hinge', 'old': '6"',
                    'new': {'v': '9"', 'src': 'pen tape'}}]},
        False, 'not editable')
    fails += pcase(
        'wrong job is refused',
        {'job': 'other-job',
         'edits': [{'room': 'T', 'field': 'ceiling', 'old': '8\'6"',
                    'new': {'v': '8\'6"', 'src': 'pen tape'}}]},
        False, 'wrong take-off')
    fails += pcase(
        'measuring a DEFAULT door height applies (absent h = house 80")',
        {'edits': [{'room': 'T', 'field': 'doors[0].h', 'old': '6\'-8"',
                    'new': {'v': '82"', 'src': 'pen tape'}}]},
        True, None,
        lambda d, n, rv: d['rooms'][0]['doors'][0]['h'] == {'v': '82"', 'src': 'pen tape'})
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
    embed = '--embed-photos' in argv
    rest = [a for a in argv[1:] if a not in ('--html', '--embed-photos')]
    patch_path = None
    if '--apply-patch' in rest:
        i = rest.index('--apply-patch')
        if i + 1 >= len(rest):
            print('--apply-patch needs the patch file')
            return 2
        patch_path = rest[i + 1]
        del rest[i:i + 2]
    if not os.path.exists(path):
        print('no such file: %s' % path)
        return 2
    try:
        data = json.load(open(path, encoding='utf-8'))
    except ValueError as e:
        print('FAIL %s: not valid JSON — %s' % (path, e))
        return 1

    if patch_path:
        if not os.path.exists(patch_path):
            print('no such patch file: %s' % patch_path)
            return 2
        try:
            patch = json.load(open(patch_path, encoding='utf-8'))
        except ValueError as e:
            print('FAIL %s: not valid JSON — %s' % (patch_path, e))
            return 1
        perrs, n, review = apply_patch(data, patch)
        print('')
        print('APPLY PATCH  %s -> %s' % (patch_path, path))
        for nm, msg in perrs:
            print('  FAIL  %-28s %s' % (nm, msg))
        if perrs:
            print('  %d edit(s) refused by name — NOTHING was written; the '
                  'take-off is unchanged.' % len(perrs))
            return 1
        for rname, st in sorted(review.items()):
            print('  %-9s %s' % (st.upper(), rname))
        pnotes = patch.get('notes') or {}
        if isinstance(pnotes, dict) and pnotes:
            print('  reviewer notes — prose, NOT applied; act on these by hand:')
            for rname in sorted(pnotes):
                for ln in str(pnotes[rname]).splitlines() or ['']:
                    print('    %-9s %s' % (rname, ln.rstrip()))
        print('  %d edit(s) applied; rewriting %s and re-running the full '
              'check.' % (n, path))
        with io.open(path, 'w', encoding='utf-8', newline='\n') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write('\n')

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
        photos = load_photos(lock, path, embed)
        if embed:
            for name, rec in sorted(photos.items()):
                if rec['err']:
                    print('  PHOTO FAIL %s — %s (placeholder rendered)'
                          % (name, rec['err']))
                elif rec['uri']:
                    print('  photo embedded: %s (%d KB downsampled to %dpx '
                          'long edge)' % (rec['path'],
                                          len(rec['uri']) * 3 // 4 // 1024,
                                          PHOTO_EDGE))
        out = rest[0] if rest else re.sub(r'\.json$', '', path) + '.review.html'
        with io.open(out, 'w', encoding='utf-8', newline='\n') as f:
            f.write(html_report(ck, lock, path, photos))
        print('  review sheet: %s%s' % (out,
              ' (client photos EMBEDDED — this file must never be committed; '
              '*.review.html is gitignored)' if embed else ''))
    return 1 if ck.errors else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
