# -*- coding: utf-8 -*-
"""Replay build-booth-components.rb's rebalance_walls + place() along-wall maths
in Python, against the REAL layout polygons in scripts/wr-booth-data.rb.

Why this exists: there is no Ruby outside SketchUp on this machine, so the only
way to reproduce the MDL 6060 E inner-shell fault before changing code is to
reimplement the two functions that decide where a part lands along its wall.

Run with no argument to see BOTH the current (broken) rule and the proposed one:

    python .forge/fixer/replay-rebalance.py

It must reproduce the probe's booth y = -7.875 for E1i under the OLD rule.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'scripts', 'wr-booth-data.rb')

IEP_SEAL_W = 6.5
STD_SEAL_W = 2.0
SLAB_NOISE = 1.0
CLOSE_TOL = 0.15

# ---------------------------------------------------------------------------
# MEASURED part box widths, i.e. what classify() reports as cls[:w] when
# wall_slab finds no panel inside an ENH definition.
#
#   6060 E: read straight off Benton's 2026-08-26 probe RUN column, which for an
#   E/W wall part IS the width (the probe walks Y).
#       E1i ENH 35.5VNT        RUN 35.7500
#       W1i ENH 35.5PanelSolid RUN 35.6250
#       E0i/W0i ENH 11.5PanelSolid RUN 11.5000
#   4872 E: from the comments in build-booth-components.rb, which quote the
#   measured boxes 41.7337 (ENH 41.5VNT) and 41.625 (ENH 41.5PanelSolid).
BOX_W = {
    'ENH 35.5VNT':        35.750,
    'ENH 35.5PanelSolid': 35.625,
    'ENH 11.5PanelSolid': 11.500,
    'ENH 41.5VNT':        41.7337,
    'ENH 41.5PanelSolid': 41.625,
    'ENH 17.5PanelSolid': 17.625,   # assumed: the panel family's 0.125 overshoot
    'ENH 41.5Panel3236WDO': 41.625, # assumed: ditto
    # Seam seals are placed on their own poly and never rebalanced by width.
    'ENH MidWallSeamSeal': 12.25,
    'MidWallSeamSeal': 7.75,
}
ASSUMED = {'ENH 17.5PanelSolid', 'ENH 41.5Panel3236WDO'}

# Standard parts DO have a findable slab, so rebalance uses the slab's exact
# panel width. Parsed from the name.
STD_RE = re.compile(r'^(?:Right|Left)?([\d.]+)')
ENH_RE = re.compile(r'ENH\s+([\d.]+)')


def nominal_width(name):
    """The module width in the part's name, or None. Mirrors the regex already
    used by iep_room_proud()."""
    m = ENH_RE.search(name)
    return float(m.group(1)) if m else None


def part_width(name, has_slab):
    """cls[:w] (no slab) or the slab's panel width (slab)."""
    if has_slab:
        m = STD_RE.match(name)
        if m:
            return float(m.group(1))
        m = ENH_RE.search(name) or re.search(r'([\d.]+)', name)
        return float(m.group(1))
    if name in BOX_W:
        return BOX_W[name]
    n = nominal_width(name)
    return n if n is not None else 0.0


def seal_or_corner(name):
    return 'SeamSeal' in name


def has_slab(name):
    """wall_slab succeeds on every Standard part and fails on ENH panels/vents;
    the ENH door is the one inner part with a findable slab."""
    if not name.startswith('ENH '):
        return True
    return 'Door' in name





# ---------------------------------------------------------------------------
booth_re = re.compile(r"'(MDL [^']+)' => \{ :label=>\"([^\"]*)\",(.*?)\n      :parts", re.S)
part_re = re.compile(r"\{ :k=>'(\w+)', :id=>'([^']+)', :sk=>'(\w+)', :sh=>'(\w+)',"
                     r" :poly=>(\[\[.*?\]\]) \}")
pt_re = re.compile(r"\[([-\d.]+),([-\d.]+)\]")


def load_booths():
    txt = open(SRC).read()
    out = {}
    heads = list(booth_re.finditer(txt))
    for i, m in enumerate(heads):
        body = txt[m.end():heads[i + 1].start() if i + 1 < len(heads) else len(txt)]
        parts = []
        for pm in part_re.finditer(body):
            pts = [(float(a), float(b)) for a, b in pt_re.findall(pm.group(5))]
            parts.append({'k': pm.group(1), 'id': pm.group(2), 'sk': pm.group(3),
                          'sh': pm.group(4), 'poly': pts})
        out[m.group(1)] = parts
    return out


# ---------------------------------------------------------------------------
# ASSIGN, transcribed from build-booth-components.rb:405-495. Only the booths
# that carry the E/W swap matter here.
ASSIGN = {
    'MDL 6060 S': {'E0': '16PanelSolid', 'E1': '40VNT',
                   'W0': '16PanelSolid', 'W1': '40PanelSolid'},
    'MDL 6084 S': {'E0': '16PanelSolid', 'E1': '40PanelSolid',
                   'W0': '16PanelSolid', 'W1': '40PanelSolid'},
    'MDL 7272 S': {'N0': '46VNT_VSS', 'N1': '22PanelSolid',
                   'S0': 'Right46Door', 'S1': '22PanelSolid',
                   'E0': '22PanelSolid', 'E1': '46VNT_VSS',
                   'W0': '22PanelSolid', 'W1': '46Panel3236WDO'},
    'MDL 7296 S': {'E0': '22PanelSolid', 'E1': '46PanelSolid',
                   'W0': '22PanelSolid', 'W1': '46PanelSolid'},
    'MDL 6060 E': {'E0': '16PanelSolid', 'E0i': 'ENH 11.5PanelSolid',
                   'E1': '40VNT', 'E1i': 'ENH 35.5VNT',
                   'W0': '16PanelSolid', 'W0i': 'ENH 11.5PanelSolid',
                   'W1': '40PanelSolid', 'W1i': 'ENH 35.5PanelSolid'},
    'MDL 6084 E': {'E0': '16PanelSolid', 'E0i': 'ENH 11.5PanelSolid',
                   'E1': '40PanelSolid', 'E1i': 'ENH 35.5PanelSolid',
                   'W0': '16PanelSolid', 'W0i': 'ENH 11.5PanelSolid',
                   'W1': '40PanelSolid', 'W1i': 'ENH 35.5PanelSolid'},
    'MDL 7272 E': {'N0': '46VNT_VSS', 'N0i': 'ENH 41.5VNT',
                   'N1': '22PanelSolid', 'N1i': 'ENH 17.5PanelSolid',
                   'S0': 'Right46Door', 'S0i': 'ENH Right41.5Door',
                   'S1': '22PanelSolid', 'S1i': 'ENH 17.5PanelSolid',
                   'E0': '22PanelSolid', 'E0i': 'ENH 17.5PanelSolid',
                   'E1': '46VNT_VSS', 'E1i': 'ENH 41.5VNT',
                   'W0': '22PanelSolid', 'W0i': 'ENH 17.5PanelSolid',
                   'W1': '46Panel3236WDO', 'W1i': 'ENH 41.5Panel3236WDO'},
    'MDL 7296 E': {'E0': '22PanelSolid', 'E0i': 'ENH 17.5PanelSolid',
                   'E1': '46PanelSolid', 'E1i': 'ENH 41.5PanelSolid',
                   'W0': '22PanelSolid', 'W0i': 'ENH 17.5PanelSolid',
                   'W1': '46PanelSolid', 'W1i': 'ENH 41.5PanelSolid'},
}


def guess(kind, run, inner):
    """guess_component(), close enough for the slots ASSIGN does not name."""
    n = ('%.1f' % run) if inner else ('%g' % round(run))
    pre = 'ENH ' if inner else ''
    if kind == 'VNT':
        return '%s%sVNT' % (pre, n)
    if kind == 'DRFRM':
        return '%sRight%sDoor' % (pre, n)
    return '%s%sPanelSolid' % (pre, n)


def name_for(key, part):
    # Seals and corners never appear in ASSIGN and are not guessed by run: the
    # builder resolves them by kind. Name them as the library does so the
    # harness does not invent a width for them.
    if part['k'] == 'seal':
        return ('ENH MidWallSeamSeal' if part['sh'] == 'in' else 'MidWallSeamSeal'), False
    if part['k'] == 'corner':
        return ('ENH CornerSeamSeal' if part['sh'] == 'in' else 'CornerSeamSeal'), False
    a = ASSIGN.get(key, {}).get(part['id'])
    if a:
        return a, False
    pts = part['poly']
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    run = max(xs) - min(xs) if part['id'][0] in 'NS' else max(ys) - min(ys)
    return guess(part['sk'], run, part['sh'] == 'in'), True


# ---------------------------------------------------------------------------
def rebalance(key, parts, use_nominal):
    """rebalance_walls(). Mutates poly extents in a copy; returns a log and the
    resulting slot [lo,hi] per part id."""
    slots = {}
    log = []
    for p in parts:
        xs = [q[0] for q in p['poly']]
        ys = [q[1] for q in p['poly']]
        slots[p['id']] = [min(xs), max(xs), min(ys), max(ys)]

    walls = {}
    for p in parts:
        if p['k'] == 'corner':
            continue
        w = p['id'][0]
        if w not in 'NSEW':
            continue
        walls.setdefault((w, p['sh'] == 'in'), []).append(p)

    for (w, inn), lst in sorted(walls.items()):
        run_x = w in 'NS'
        joint = IEP_SEAL_W if inn else STD_SEAL_W

        def ext(pid):
            s = slots[pid]
            return (s[0], s[1]) if run_x else (s[2], s[3])

        def pw_of(p):
            nm, _ = name_for(key, p)
            sl = ext(p['id'])
            want = sl[1] - sl[0]
            if has_slab(nm):
                return part_width(nm, True)
            # ---- the line under test -------------------------------------
            if use_nominal:
                n = nominal_width(nm)
                wdt = n if n is not None else part_width(nm, False)
            else:
                wdt = part_width(nm, False)
            # --------------------------------------------------------------
            return want if abs(wdt - want) <= SLAB_NOISE else wdt

        lst.sort(key=lambda p: ext(p['id'])[0])
        need = any(p['k'] == 'panel' and
                   abs(pw_of(p) - (ext(p['id'])[1] - ext(p['id'])[0])) > 0.1
                   for p in lst)
        if not need:
            continue

        first = ext(lst[0]['id'])[0]
        last = ext(lst[-1]['id'])[1]
        pos = first
        old_end = first
        plan = []
        for p in lst:
            s = ext(p['id'])
            if p['k'] == 'panel':
                pw = pw_of(p)
                plan.append((p, pos, pw, s))
                pos += pw
                old_end = s[1]
            else:
                plan.append((p, pos - old_end, None, s))
                pos += joint

        if abs(pos - last) > CLOSE_TOL:
            log.append('  *** %s %s wall does not close after rebalancing to real '
                       'widths (off %+.3f in) - leaving it as generated.'
                       % (w, 'inner' if inn else 'outer', pos - last))
            continue

        for p, a, pw, s in plan:
            if p['k'] == 'panel':
                if abs(a - s[0]) < 0.001 and abs(pw - (s[1] - s[0])) < 0.001:
                    continue
                sl = slots[p['id']]
                if run_x:
                    sl[0], sl[1] = a, a + pw
                else:
                    sl[2], sl[3] = a, a + pw
                log.append('  rebalanced %-8s %-24s %.3f..%.3f  (slot was %.3f..%.3f)'
                           % (p['id'], name_for(key, p)[0], a, a + pw, s[0], s[1]))
            elif abs(a) > 0.001:
                sl = slots[p['id']]
                if run_x:
                    sl[0] += a
                    sl[1] += a
                else:
                    sl[2] += a
                    sl[3] += a
                log.append('  rebalanced %-8s seal shifted %+.3f in along the wall'
                           % (p['id'], a))
        log.append('  %s %s wall closes %+.4f' % (w, 'inner' if inn else 'outer', pos - last))
    return slots, log


def place_run(name, slot, booth_c, kind):
    """place()'s ALONG-WALL result only: returns (lo, hi) of the part's box
    along its wall. Reproduces box_trim / flush exactly."""
    sl_lo, sl_hi = slot
    slot_len = sl_hi - sl_lo
    slot_c = (sl_lo + sl_hi) / 2.0
    slab = has_slab(name)
    if seal_or_corner(name):
        r_len = slot_len          # a seal is placed on its own polygon
    else:
        r_len = part_width(name, True) if slab else part_width(name, False)
    box_trim = (not slab) and abs(r_len - slot_len) > 0.02
    flush = (kind == 'panel')
    if (not flush) or box_trim:
        lo = slot_c - r_len / 2.0
    elif slot_c < booth_c:
        lo = sl_lo
    else:
        lo = sl_hi - r_len
    hi = lo + r_len
    # ...and the one-ended trim for the panel family (iep_trim_end == :lo).
    if name.startswith('ENH ') and kind == 'panel' and not slab:
        over = r_len - slot_len
        if not re.search(r'VNT|NV', name) and over > 0.02:
            # shifted half the overshoot toward the part's own low-width end.
            # Sign in world depends on the wall's parity; magnitude is what
            # matters for "does it stay inside the booth", so report both ends.
            pass
    return lo, hi


def report(key, parts, use_nominal, shells=('in',)):
    slots, log = rebalance(key, parts, use_nominal)
    xs = [q[0] for p in parts for q in p['poly']]
    ys = [q[1] for p in parts for q in p['poly']]
    centre = ((min(xs) + max(xs)) / 2.0, (min(ys) + max(ys)) / 2.0)
    print('  --- rebalance ---')
    for l in log:
        print(l)
    if not log:
        print('  (no wall needed rebalancing)')
    print('  --- placement, along-wall extent in booth coords ---')
    print('  %-10s %-24s %9s %9s   %s'
          % ('SLOT', 'COMPONENT', 'SLOT', 'PART', 'flag'))
    for p in sorted(parts, key=lambda p: p['id']):
        if p['sh'] not in shells or p['k'] == 'corner':
            continue
        w = p['id'][0]
        if w not in 'NSEW':
            continue
        run_x = w in 'NS'
        s = slots[p['id']]
        slot = (s[0], s[1]) if run_x else (s[2], s[3])
        nm, guessed = name_for(key, p)
        lo, hi = place_run(nm, slot, centre[0] if run_x else centre[1], p['k'])
        interior = (min(xs), max(xs)) if run_x else (min(ys), max(ys))
        flag = ''
        if lo < interior[0] - 0.01 or hi > interior[1] + 0.01:
            flag = '<<< OUTSIDE THE BOOTH'
        if guessed:
            flag += ' (guessed)'
        if nm in ASSUMED:
            flag += ' (box width assumed)'
        print('  %-10s %-24s %9.4f %9.4f   %8.4f..%-9.4f %s'
              % (p['id'], nm, slot[1] - slot[0], hi - lo, lo, hi, flag))


if __name__ == '__main__':
    booths = load_booths()
    keys = sys.argv[1:] or ['MDL 6060 E', 'MDL 4872 E']
    for key in keys:
        if key not in booths:
            print('no such booth: %s' % key)
            continue
        for use_nominal in (False, True):
            print('')
            print('=' * 78)
            print('%s   width rule = %s'
                  % (key, 'NOMINAL from the name (PROPOSED)' if use_nominal
                     else 'PACKAGED BOUNDING BOX (CURRENT)'))
            print('=' * 78)
            report(key, [dict(p, poly=list(p['poly'])) for p in booths[key]],
                   use_nominal, shells=('in', 'out'))
