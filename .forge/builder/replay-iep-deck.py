#!/usr/bin/env python3
"""Replay wr-deck.rb's catalogue + tiling solver, in Python, against the REAL
component folder and the REAL generated layouts, for every Enhanced booth.

There is no Ruby outside SketchUp on this machine, so this is the only way to
see which ENH deck pieces the widened catalogue would choose and where. It is a
reimplementation, not the code itself: it mirrors NAME / ENH_NAME, catalogue,
tile, short_wall_mid, order_cuts, pick and plan line for line, and it CANNOT
see anything that needs SketchUp geometry (bracket_edge, contact_z, the actual
bounding boxes). Those are named as gaps in the output rather than faked.

Run:  python .forge/builder/replay-iep-deck.py
"""
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LIB = r'P:\Sketchup\NewMasterComponentList'
DATA = os.path.join(REPO, 'scripts', 'wr-booth-data.rb')

TOL = 0.35     # WR_Deck::TOL
INSET = 1.0    # WR_Deck::INSET

# ------------------------------------------------------------------ patterns --
# WR_Deck::NAME and WR_Deck::ENH_NAME, transcribed.
NAME = re.compile(r'\ASTD(\d{2,3})(\d{2})\s*(FL|CL)\s*(CTR|SIDE)?\s*([LR])?\Z', re.I)
ENH_NAME = re.compile(r'\AENH\s+(\d{2,3})(\d{2})\s*(FL|CL)\s*(CTR|SIDE)?\s*([LR])?\Z', re.I)
# The pattern as it stood BEFORE this change, to prove the STD pool is unmoved.
OLD_NAME = re.compile(r'\ASTD(\d{2,3})(\d{2})\s*(FL|CL)\s*(CTR|SIDE)?\s*([LR])?\Z', re.I)


def catalogue(names, family='STD'):
    """WR_Deck.catalogue: glob, then parse the basename."""
    enh = family.upper() == 'ENH'
    rx = ENH_NAME if enh else NAME
    prefix = 'ENH ' if enh else 'STD'
    out = []
    for base in names:
        if not base.startswith(prefix):        # the Dir.glob
            continue
        m = rx.match(base.strip())
        if m is None:
            continue
        out.append({'file': base,
                    'cross': float(m.group(1)), 'along': float(m.group(2)),
                    'kind': m.group(3).upper(),
                    'role': (m.group(4) or 'CTR').upper(),
                    'hand': (m.group(5) or '').upper()})
    return out


# ---------------------------------------------------------------- the solver --
def tile(run, widths):
    widths = sorted(widths, reverse=True)
    if not widths or widths[0] <= 0:
        return None
    big = widths[0]
    n = int(run // big)
    for k in range(n, -1, -1):
        rest = run - k * big
        if abs(rest) < TOL:
            return [big] * k
        hit = next((w for w in widths if abs(w - rest) < TOL), None)
        if hit is not None:
            return [big] * k + [hit]
    return None


def outer_parts(spec):
    return [p for p in spec['parts'] if p['sh'] != 'in']


def short_wall_mid(spec, along_is_x):
    runs = []
    for p in outer_parts(spec):
        if p['k'] != 'panel':
            continue
        xs = [q[0] for q in p['poly']]
        ys = [q[1] for q in p['poly']]
        dx, dy = max(xs) - min(xs), max(ys) - min(ys)
        along = dx if along_is_x else dy
        cross = dy if along_is_x else dx
        if not along > cross:
            continue
        mid = (min(xs) + max(xs)) / 2.0 if along_is_x else (min(ys) + max(ys)) / 2.0
        runs.append((along, mid))
    if not runs:
        return None
    shortest = min(r[0] for r in runs)
    if (max(r[0] for r in runs) - shortest) < TOL:
        return None
    mids = sorted(r[1] for r in runs if abs(r[0] - shortest) < TOL)
    return mids[len(mids) // 2]


def order_cuts(cuts, spec, along_is_x):
    if len(set(cuts)) < 2:
        return cuts
    big = max(cuts)
    odd = next((c for c in cuts if abs(c - big) >= TOL), None)
    if odd is None:
        return cuts
    target = short_wall_mid(spec, along_is_x)
    if target is None:
        return cuts
    target -= INSET
    n = len(cuts) - 1
    best = min(range(n + 1), key=lambda i: abs((i * big + odd / 2.0) - target))
    out = [big] * n
    out.insert(best, odd)
    return out


def pick(pool, width, want, at_low_end):
    same = [c for c in pool if abs(c['along'] - width) < TOL]
    if not same:
        return None, False
    byrole = [c for c in same if c['role'] == want] or same
    handed = [c for c in byrole if c['hand']]
    if not handed:
        return byrole[0], False
    wanted = 'L' if at_low_end else 'R'
    hit = next((c for c in handed if c['hand'] == wanted), None)
    if hit:
        return hit, False
    return handed[0], True


def plan(spec, cat, kind):
    w = spec['w'] - 2 * INSET
    h = spec['h'] - 2 * INSET
    if w <= 0 or h <= 0:
        return None, 'booth has no size'
    orders = ([(w, h, True), (h, w, False)] if w >= h
              else [(h, w, False), (w, h, True)])
    pool = cuts = None
    cross_len = None
    along_is_x = True
    tried = []
    for a_len, c_len, a_is_x in orders:
        p = [c for c in cat if c['kind'] == kind and abs(c['cross'] - c_len) < TOL]
        if not p:
            tried.append('nothing %.0f across' % c_len)
            continue
        widths = list(dict.fromkeys(c['along'] for c in p))
        t = tile(a_len, widths)
        if t is None:
            tried.append('%.0f across cannot tile %.2f from %s'
                         % (c_len, a_len,
                            '/'.join('%g' % x for x in sorted(widths, reverse=True))))
            continue
        pool, cuts, cross_len, along_is_x = p, t, c_len, a_is_x
        break
    if cuts is None:
        return None, ('no %s tiling for %.0f x %.0f - %s'
                      % (kind, w, h, '; '.join(tried)))
    cuts = order_cuts(cuts, spec, along_is_x)
    tiles = []
    pos = 0.0
    for i, width in enumerate(cuts):
        end_of_run = (i == 0 or i == len(cuts) - 1)
        part, sub = pick(pool, width, 'SIDE' if end_of_run else 'CTR', i == 0)
        if part is None:
            return None, 'no %s part %g in wide' % (kind, width)
        tiles.append({'part': part, 'along': width, 'at': pos, 'at_low_end': i == 0,
                      'substituted': sub, 'along_is_x': along_is_x,
                      'cross': cross_len})
        pos += width
    return tiles, '%d tile(s), %s' % (len(tiles), ' + '.join('%g' % c for c in cuts))


def tile_rect(t):
    """WR_Booth::tile_rect - the booth-plan rectangle one tile owns."""
    a = INSET + t['at']
    if t['along_is_x']:
        return a, INSET, t['along'], t['cross']
    return INSET, a, t['cross'], t['along']


# ------------------------------------------------------------- layout data --
KEY = re.compile(r"^\s*'(MDL [0-9]+ [ES])'\s*=>\s*\{")
PART = re.compile(r":k=>'(\w+)'.*?:sh=>'(\w+)'.*?:poly=>\[(.*?)\]\s*\}")
PAIR = re.compile(r'\[([-\d.]+),\s*([-\d.]+)\]')


def load_specs(family='E'):
    text = open(DATA, encoding='utf-8', errors='replace').read().splitlines()
    specs = {}
    cur = None
    for line in text:
        m = KEY.match(line)
        if m:
            w = float(re.search(r':w=>([\d.]+)', line).group(1))
            h = float(re.search(r':h=>([\d.]+)', line).group(1))
            cur = {'w': w, 'h': h, 'parts': []}
            specs[m.group(1)] = cur
            continue
        if cur is None:
            continue
        pm = PART.search(line)
        if pm:
            poly = [(float(a), float(b)) for a, b in PAIR.findall(pm.group(3))]
            cur['parts'].append({'k': pm.group(1), 'sh': pm.group(2), 'poly': poly})
    if family:
        return {k: v for k, v in specs.items() if k.endswith(' ' + family)}
    return specs



# ------------------------------------------------------- measured geometry --
#
# The parts' REAL bounding boxes, off the two probes that already exist in the
# component folder. Nothing here is a nominal figure taken from a name.
#
#   _enhanced-probe.tsv  2026-08-24, columns: file, definition, thickness,
#                        width, height, ...  -> width is the ALONG-run span and
#                        height the ACROSS-run span for a deck part.
#   _face-levels.tsv     2026-08-14, columns: file, box_x, box_y, box_z, z,
#                        area, ... -> one row per flat level, so the box repeats.
#                        This is the ONLY source on this machine for Standard
#                        deck boxes; _component-probe.tsv carries wall panels
#                        only (checked: 183 rows, not one STD deck part).
ENH_PROBE = os.path.join(LIB, '_enhanced-probe.tsv')
FACE_LEVELS = os.path.join(LIB, '_face-levels.tsv')


def enh_measured():
    """{part name: (along_span, cross_span)} for every ENH part in the probe."""
    out = {}
    with open(ENH_PROBE, encoding='utf-8', errors='replace') as fh:
        head = fh.readline().rstrip('\n').split('\t')
        iw, ih = head.index('width'), head.index('height')
        for line in fh:
            c = line.rstrip('\n').split('\t')
            if len(c) <= ih:
                continue
            try:
                out[c[0].strip()] = (float(c[iw]), float(c[ih]))
            except ValueError:
                continue
    return out


def std_measured():
    """{part name: (box_x, box_y, box_z)} off _face-levels.tsv."""
    out = {}
    with open(FACE_LEVELS, encoding='utf-8', errors='replace') as fh:
        fh.readline()
        for line in fh:
            c = line.rstrip('\n').split('\t')
            if len(c) < 4:
                continue
            try:
                out[c[0].strip()] = (float(c[1]), float(c[2]), float(c[3]))
            except ValueError:
                continue
    return out


def levels(part):
    """[(z, area)] for one part, off _face-levels.tsv, low z first."""
    rows = []
    with open(FACE_LEVELS, encoding='utf-8', errors='replace') as fh:
        fh.readline()
        for line in fh:
            c = line.rstrip('\n').split('\t')
            if len(c) < 6 or c[0].strip() != part:
                continue
            try:
                rows.append((float(c[4]), float(c[5])))
            except ValueError:
                continue
    return sorted(rows)


# ----------------------------------------------------------- the seat rule --
#
# WR_BuildBoothComponents.seat and the seat_along choice in iep_deck, transcribed. The whole
# fix is these fifteen lines, so the harness runs them rather than describing
# them.
def seat_along_for(i, n, at_low_end):
    if n < 2:
        return 'centre'
    if at_low_end:
        return 'max'
    if i == n - 1:
        return 'min'
    return 'centre'


def seat(mode, r0, rlen, span):
    """Returns the part's real [lo, hi] once seated in [r0, r0+rlen]."""
    if mode == 'min':
        lo = r0
    elif mode == 'max':
        lo = r0 + rlen - span
    else:
        lo = r0 + (rlen - span) / 2.0
    return lo, lo + span


def as_along_cross(spans, along, cross):
    """The part's two footprint spans, assigned to (along, cross) by whichever
    pairing fits the nominal name better. The parts do NOT agree on which axis
    is which - see the note in main()."""
    a, b = spans
    return (a, b) if (abs(a - along) + abs(b - cross)
                      <= abs(b - along) + abs(a - cross)) else (b, a)


def real_edges(tiles, measured, mode):
    """[(file, lo, hi)] along the run. mode 'centre' = the OLD behaviour.

    The span used is the part's REAL measured one, which is the whole point:
    the nominal slot comes from the name and the overhang is the difference.
    """
    out = []
    for i, t in enumerate(tiles):
        rx, ry, rw, rh = tile_rect(t)
        r0, rlen = (rx, rw) if t['along_is_x'] else (ry, rh)
        span = as_along_cross(measured.get(t['part']['file'],
                                           (t['along'], t['cross'])),
                              t['along'], t['cross'])[0]
        m = 'centre' if mode == 'centre' else seat_along_for(i, len(tiles),
                                                             t['at_low_end'])
        lo, hi = seat(m, r0, rlen, span)
        out.append((t['part']['file'], lo, hi))
    return out


# --------------------------------------------------------- seal catalogues --
SEAL_CL = re.compile(r'\ASTDSS\s*(?:CL\s*(\d+(?:\.\d+)?)|(\d+(?:\.\d+)?)\s*CL)\Z', re.I)
SEAL_FL = re.compile(r'\ASTDSS\s*(?:FL\s*(\d+(?:\.\d+)?)|(\d+(?:\.\d+)?)\s*FL)\Z', re.I)
SEAL_LEN_INSET = {'CL': 2.0, 'FL': 0.0}


def seal_catalogue(names, kind):
    rx = SEAL_CL if kind == 'CL' else SEAL_FL
    out = []
    for base in names:
        if not base.startswith('STDSS'):          # the Dir.glob
            continue
        m = rx.match(base.strip())
        if m is None:
            continue
        ft = float(m.group(1) or m.group(2))
        out.append({'file': base, 'feet': ft, 'cross': ft * 12.0})
    return out


def pick_seal(seals, cross):
    return next((s for s in seals if abs(s['cross'] - cross) < TOL), None)


def joint_stations(tiles):
    if not tiles or len(tiles) < 2:
        return []
    pos = 0.0
    out = []
    for t in tiles[:-1]:
        pos += t['along']
        out.append(pos)
    return out

# ------------------------------------------------------------------- checks --
def main():
    fails = []

    def check(ok, label, detail=''):
        print('%-5s %s%s' % ('PASS' if ok else 'FAIL', label,
                             ('  -- ' + detail) if detail else ''))
        if not ok:
            fails.append(label)

    if not os.path.isdir(LIB):
        print('cannot reach %s - nothing can be verified' % LIB)
        return 2
    names = sorted(os.path.splitext(f)[0] for f in os.listdir(LIB)
                   if f.lower().endswith('.skp'))
    print('%d .skp in %s\n' % (len(names), LIB))

    print('=== 1. the two catalogues =========================================')
    std = catalogue(names, 'STD')
    enh = catalogue(names, 'ENH')
    print('  STD deck codes: %d   ENH deck codes: %d' % (len(std), len(enh)))
    s = set(c['file'][3:].strip() for c in std)
    e = set(c['file'][4:].strip() for c in enh)
    check(len(std) == len(enh) and s == e, 'STD and ENH deck sets are identical',
          'only in STD: %s | only in ENH: %s' % (sorted(s - e) or 'none',
                                                 sorted(e - s) or 'none'))

    old = [n for n in names if n.startswith('STD') and OLD_NAME.match(n)]
    check(sorted(c['file'] for c in std) == sorted(old),
          'the STD pool is byte-identical to the pre-change pattern',
          '%d parts' % len(old))

    print('\n=== 2. what the widened pattern must still refuse =================')
    seals = [n for n in names if n.upper().startswith('STDSS')
             or 'SEAMSEAL' in n.upper().replace(' ', '')]
    caught = [n for n in seals if NAME.match(n) or ENH_NAME.match(n)]
    check(not caught, '%d STDSS / SeamSeal part(s) stay OUT of both pools' % len(seals),
          'leaked: %s' % (caught or 'none'))

    walls = [n for n in names if n.startswith('ENH ') and ENH_NAME.match(n) is None]
    leaked = [n for n in names if n.startswith('ENH ') and ENH_NAME.match(n)
              and ('Panel' in n or 'VNT' in n or 'NV' in n or 'Door' in n)]
    check(not leaked, '%d non-deck ENH part(s) stay OUT of the ENH pool' % len(walls),
          'leaked: %s' % (leaked or 'none'))

    lp = [n for n in names if 'LP' in n and (n.startswith('STD') or n.startswith('ENH '))]
    check(all(not (NAME.match(n) or ENH_NAME.match(n)) for n in lp),
          '%s excluded from both, in step' % ', '.join(lp))

    print('\n=== 3. per-booth ENH deck resolution ==============================')
    specs = load_specs()
    print('  %d Enhanced layouts read from wr-booth-data.rb\n' % len(specs))
    hdr = '  %-16s %-9s %-8s %s' % ('BOOTH', 'FOOTPRNT', 'DECK', 'TILES (low end first)')
    print(hdr)
    print('  ' + '-' * (len(hdr) + 30))

    resolved, refused = [], []
    for key in sorted(specs, key=lambda k: (len(k), k)):
        spec = specs[key]
        foot = '%gx%g' % (spec['w'] - 2, spec['h'] - 2)
        rows = {}
        for kind in ('FL', 'CL'):
            tiles, note = plan(spec, enh, kind)
            rows[kind] = (tiles, note)
        ok = all(t is not None for t, _ in rows.values())
        (resolved if ok else refused).append(key)
        for kind in ('FL', 'CL'):
            tiles, note = rows[kind]
            if tiles is None:
                digits = re.search(r'MDL (\d+)', key).group(1)
                print('  %-16s %-9s %-8s REFUSED: %s  [would be "ENH %s%s"]'
                      % (key, foot, kind, note, digits, kind))
                continue
            desc = ', '.join('%s @%g%s' % (t['part']['file'], t['at'],
                                           ' SUBSTITUTED-HAND' if t['substituted'] else '')
                             for t in tiles)
            print('  %-16s %-9s %-8s %s' % (key, foot, kind, desc))

    print('\n  resolved a full inner deck: %d/%d' % (len(resolved), len(specs)))
    print('  still refused:              %s'
          % (', '.join(refused) if refused else 'none'))

    print('\n=== 4. the assertions =============================================')
    # 4a. the 6060, against wr-deck.rb's own comment about the Standard deck.
    for kind in ('FL', 'CL'):
        tiles, _ = plan(specs['MDL 6060 E'], enh, kind)
        got = [(t['part']['file'], 'low' if t['at_low_end'] else 'high') for t in tiles]
        want = [('ENH 6042%s SIDE L' % kind, 'low'), ('ENH 6018%s SIDE R' % kind, 'high')]
        check(got == want, 'MDL 6060 E inner %s tiles as the Standard does' % kind,
              '%s' % got)

    # 4b. every single-tile deck centres exactly where the old code put it.
    moved = []
    for key, spec in specs.items():
        for kind in ('FL', 'CL'):
            tiles, _ = plan(spec, enh, kind)
            if tiles is None or len(tiles) != 1:
                continue
            rx, ry, rw, rh = tile_rect(tiles[0])
            cx, cy = rx + rw / 2.0, ry + rh / 2.0
            if abs(cx - spec['w'] / 2.0) > 1e-9 or abs(cy - spec['h'] / 2.0) > 1e-9:
                moved.append('%s %s -> %.4f,%.4f want %.4f,%.4f'
                             % (key, kind, cx, cy, spec['w'] / 2, spec['h'] / 2))
    check(not moved,
          'every single-tile inner deck lands on the booth centre, as before',
          '; '.join(moved) if moved else 'MDL 4872 E included')

    # 4c. the Standard tiling is untouched by the family parameter.
    diff = []
    for key, spec in specs.items():
        for kind in ('FL', 'CL'):
            a, _ = plan(spec, std, kind)
            b, _ = plan(spec, enh, kind)
            fa = [t['part']['file'][3:].strip() for t in a] if a else None
            fb = [t['part']['file'][4:].strip() for t in b] if b else None
            if fa != fb:
                diff.append('%s %s: %s vs %s' % (key, kind, fa, fb))
    check(not diff, 'STD and ENH resolve the SAME arrangement on all 25 layouts',
          '; '.join(diff) if diff else '')

    print('\n=== 6. the tray lip: where the ENH deck parts really measure =====')
    meas = enh_measured()
    stdbox = std_measured()

    # as_along_cross, above, is how a part's two spans become (along, cross).
    #
    # THE PARTS DO NOT AGREE ON WHICH AXIS IS WHICH and assuming they do is what
    # made the first run of this section report ten false failures. ENH 6042CL
    # SIDE L is 43 x 62 with X along the run; ENH 4872CL is 50 x 74 with X
    # ACROSS it. wr-deck.rb's `plan` says the same thing about STD4230FL, and
    # both flat_placement and WR_Deck.build handle it by testing both readings -
    # which is exactly what as_along_cross does.

    # 6a. The rule itself, against every ENH deck part in the probe.
    #     nominal + 1 per OUTER edge: a SIDE tile has one along the run, a CTR
    #     tile none, a single-piece deck two; across the run every tile has two.
    #
    #     SINGLE-PIECE IS DERIVED, NOT READ OFF THE NAME. 'ENH 8418 CL' has no
    #     CTR or SIDE token and is still a middle tile - it is the odd 18 in
    #     strip in the 84 series, and it measures +0 along like every other CTR.
    #     The test that separates them is whether the library has a SIDE part at
    #     that cross at all: cross 42 and 48 have none, so those are whole decks.
    has_side = set((c['cross'], c['kind']) for c in enh if c['role'] == 'SIDE')
    bad = []
    fl_under = []
    for c in enh:
        m = meas.get(c['file'])
        if m is None:
            bad.append('%s not in the probe' % c['file'])
            continue
        ga, gc = as_along_cross(m, c['along'], c['cross'])
        tiles_here = (c['cross'], c['kind']) in has_side
        if c['kind'] == 'FL':
            wa, wc = c['along'], c['cross']
        elif not tiles_here:
            wa, wc = c['along'] + 2, c['cross'] + 2      # whole deck, both ends
        elif c['role'] == 'CTR':
            wa, wc = c['along'], c['cross'] + 2          # no outer edge along
        else:
            wa, wc = c['along'] + 1, c['cross'] + 2      # SIDE: one outer end
        # An FL part is allowed to be a shade UNDER its name and one is:
        # ENH 8418 FL measures 17.9375, exactly as its Standard twin does. It is
        # a middle tile on both booths that use it, so it is centred either way
        # and the seat rule never touches it - but pretending it is 18.0000
        # would be a false claim, so it is reported rather than tolerated
        # silently.
        if c['kind'] == 'FL' and -0.07 < ga - wa < -0.0001:
            fl_under.append('%s %.4f (%+.4f)' % (c['file'], ga, ga - wa))
            continue
        if abs(ga - wa) > 0.001 or abs(gc - wc) > 0.001:
            bad.append('%s measures %.4f along x %.4f across, rule says %.4f x %.4f'
                       % (c['file'], ga, gc, wa, wc))
    check(not bad, 'all %d ENH deck parts follow "+1 per outer edge"' % len(enh),
          '; '.join(bad) if bad else
          'CL SIDE +1 along, CL CTR +0 along, single-piece CL +2, every CL +2 '
          'across; FL nominal')
    print('    FL parts under nominal (centred tiles, so unaffected): %s'
          % (', '.join(fl_under) or 'none'))

    # 6b. THE STANDARD DECK HAS NO LIP. This is what says the fix belongs in the
    #     Enhanced path and that WR_Deck.build has nothing to reuse.
    #
    #     CEILINGS ONLY, because that is the claim. Two STD FL parts are wider
    #     than their name - STD7224FL SIDE R boxes 37.9375 on a 24 in panel -
    #     and wr-deck.rb already has a capitalised comment about it: that is a
    #     BRACKET RUN, not a lip, which is why `build` seats a Standard tile by
    #     its measured deck_extent at the contact level rather than by its box.
    lipped = []
    seen = 0
    for c in std:
        b = stdbox.get(c['file'])
        if b is None or c['kind'] != 'CL':
            continue
        seen += 1
        ga, gc = as_along_cross((b[0], b[1]), c['along'], c['cross'])
        if ga - c['along'] > 0.02 or gc - c['cross'] > 0.02:
            lipped.append('%s box %.4f x %.4f vs nominal %g x %g'
                          % (c['file'], ga, gc, c['along'], c['cross']))
    check(seen >= 20 and not lipped,
          'no STD CEILING part is bigger than its nominal name (%d measured)' % seen,
          '; '.join(lipped) if lipped else
          'so the Standard deck never had a lip to solve, and WR_Deck.build '
          'has no handling of one to reuse')

    # 6c. THE 6060 E, BEFORE AND AFTER, IN REAL EDGES.
    print('\n  MDL 6060 E, real part edges along the run (deck runs 1.00 .. 61.00):')
    for kind in ('CL', 'FL'):
        tiles, _ = plan(specs['MDL 6060 E'], enh, kind)
        before = real_edges(tiles, meas, 'centre')
        after = real_edges(tiles, meas, 'seat')
        print('    %s' % kind)
        for (f, blo, bhi), (_, alo, ahi) in zip(before, after):
            print('      %-20s was %7.3f .. %7.3f   now %7.3f .. %7.3f   moved %+.3f'
                  % (f, blo, bhi, alo, ahi, alo - blo))
        print('      joint: overlap was %+.3f, now %+.3f   span was %.3f, now %.3f'
              % (before[0][2] - before[1][1], after[0][2] - after[1][1],
                 before[-1][2] - before[0][1], after[-1][2] - after[0][1]))

    tiles, _ = plan(specs['MDL 6060 E'], enh, 'CL')
    before = real_edges(tiles, meas, 'centre')
    after = real_edges(tiles, meas, 'seat')
    check(abs(before[0][2] - before[1][1] - 1.0) < 1e-9,
          'the OLD centring really did overlap the 6060 E tray by 1.000',
          '%.4f .. %.4f against %.4f .. %.4f'
          % (before[0][1], before[0][2], before[1][1], before[1][2]))
    check(abs(after[0][2] - after[1][1]) < 1e-9,
          'the 6060 E tray tiles now meet FLUSH, no overlap and no gap',
          'both faces at %.4f' % after[0][2])
    check(abs((after[-1][2] - after[0][1]) - 62.0) < 1e-9,
          'the 6060 E tray run totals 62.000 - 60 nominal plus 1 in lip each end',
          '%.4f .. %.4f' % (after[0][1], after[-1][2]))
    check(all(abs(abs(a[1] - b[1]) - 0.5) < 1e-9 for a, b in zip(after, before)),
          "each 6060 E tray tile moved OUT by exactly 0.500 - Benton's figure",
          '%+.4f and %+.4f' % (after[0][1] - before[0][1],
                               after[1][1] - before[1][1]))

    # 6d. The floor is untouched, on every layout, because ENH FL is exact.
    moved = []
    for key, spec in specs.items():
        for kind in ('FL', 'CL'):
            tiles, _ = plan(spec, enh, kind)
            if tiles is None:
                continue
            b = real_edges(tiles, meas, 'centre')
            a = real_edges(tiles, meas, 'seat')
            for (f, blo, _), (_, alo, _) in zip(b, a):
                if kind == 'FL' and abs(alo - blo) > 1e-9:
                    moved.append('%s %s %s %+.4f' % (key, kind, f, alo - blo))
    check(not moved, 'no FL tile moves on any of the 25 layouts',
          '; '.join(moved) if moved else 'ENH FL parts carry no lip, so :max and :centre agree')

    # 6e. Single-tile decks still centre. THIS IS WHAT PROTECTS THE 4872 E.
    off = []
    ones = 0
    for key, spec in specs.items():
        for kind in ('FL', 'CL'):
            tiles, _ = plan(spec, enh, kind)
            if tiles is None or len(tiles) != 1:
                continue
            ones += 1
            b = real_edges(tiles, meas, 'centre')
            a = real_edges(tiles, meas, 'seat')
            if abs(a[0][1] - b[0][1]) > 1e-9:
                off.append('%s %s moved %+.4f' % (key, kind, a[0][1] - b[0][1]))
    check(not off, '%d single-tile inner decks stay exactly centred' % ones,
          '; '.join(off) if off else 'MDL 4872 E included')

    # 6f. No joint on any layout overlaps any more, and every CEILING joint
    #     closes exactly.
    #
    #     THE FLOOR IS HELD TO "NO OVERLAP", NOT "EXACTLY ZERO", and the reason
    #     is a part rather than the code: ENH 8418 FL measures 17.9375 on an 18
    #     in slot, so centring it leaves 1/32 at each side. That gap is in the
    #     library, it is identical before and after this change (6d proves the
    #     FL tiles do not move at all), and its Standard twin STD8418 FL has the
    #     same 17.9375. Asserting 0.0000 there would be asserting that a part is
    #     a different size than it is.
    over = []
    cl_open = []
    fl_gaps = []
    for key, spec in specs.items():
        for kind in ('FL', 'CL'):
            tiles, _ = plan(spec, enh, kind)
            if tiles is None or len(tiles) < 2:
                continue
            a = real_edges(tiles, meas, 'seat')
            for (f1, _, hi), (f2, lo, _) in zip(a, a[1:]):
                d = hi - lo
                if d > 1e-9:
                    over.append('%s %s %s|%s overlap %+.4f' % (key, kind, f1, f2, d))
                elif kind == 'CL' and d < -1e-9:
                    cl_open.append('%s %s|%s gap %.4f' % (key, f1, f2, -d))
                elif kind == 'FL' and d < -1e-9:
                    fl_gaps.append('%s %s|%s gap %.4f' % (key, f1, f2, -d))
    check(not over, 'no inner deck joint overlaps on any of the 25 layouts',
          '; '.join(over) if over else 'floor and ceiling both')
    check(not cl_open, 'every multi-tile inner CEILING joint closes to 0.0000',
          '; '.join(cl_open) if cl_open else '')
    print('    floor joints left open by the part itself, unchanged by this fix:')
    print('      %s' % ('; '.join(sorted(set(fl_gaps))) or 'none'))

    print('\n=== 7. seam seals: the floor family ==============================')
    cl = seal_catalogue(names, 'CL')
    fl = seal_catalogue(names, 'FL')
    print('  CL seals: %s' % ', '.join(sorted(s['file'] for s in cl)))
    print('  FL seals: %s' % ', '.join(sorted(s['file'] for s in fl)))
    check(sorted(s['feet'] for s in cl) == sorted(s['feet'] for s in fl)
          and len(fl) == 5,
          'the floor family mirrors the ceiling family exactly',
          '%d each, feet %s' % (len(fl), sorted(s['feet'] for s in fl)))

    # No seal may reach either DECK pool - the capitalised rule in wr-deck.rb.
    leak = [s['file'] for s in cl + fl if NAME.match(s['file'])
            or ENH_NAME.match(s['file'])]
    check(not leak, 'no seam seal of either family reaches the deck/panel pool',
          'leaked: %s' % (leak or 'none'))
    # ...and the two seal patterns must not catch each other's parts.
    cross_hit = [s['file'] for s in cl if SEAL_FL.match(s['file'])] + \
                [s['file'] for s in fl if SEAL_CL.match(s['file'])]
    check(not cross_hit, 'SEAL_NAME and SEAL_FL_NAME are disjoint',
          'both matched: %s' % (cross_hit or 'none'))

    print('\n  which seal each booth picks, and how many joints:')
    allspecs = load_specs(family=None)
    print('  %-16s %-7s %-7s %-16s %-16s' % ('BOOTH', 'CROSS', 'JOINTS',
                                             'CEILING', 'FLOOR'))
    misses = []
    for key in sorted(allspecs, key=lambda k: (len(k), k)):
        spec = allspecs[key]
        row = {}
        for kind, pool in (('CL', cl), ('FL', fl)):
            tiles, _ = plan(spec, std, kind)
            if tiles is None:
                row[kind] = ('-', 'no plan', 0)
                continue
            st = joint_stations(tiles)
            if not st:
                row[kind] = ('%g' % tiles[0]['cross'], 'single tile', 0)
                continue
            s = pick_seal(pool, tiles[0]['cross'])
            row[kind] = ('%g' % tiles[0]['cross'], s['file'] if s else 'NONE',
                         len(st))
            if s is None:
                misses.append('%s %s cross %g' % (key, kind, tiles[0]['cross']))
        print('  %-16s %-7s %-7s %-16s %-16s'
              % (key, row['CL'][0], row['CL'][2], row['CL'][1], row['FL'][1]))
    check(not misses, 'every jointed deck, floor and ceiling, finds its seal',
          '; '.join(misses) if misses else '')

    # The FL/CL cut lists are the same, so the joints are the same joints.
    diff = []
    for key, spec in allspecs.items():
        a, _ = plan(spec, std, 'FL')
        b, _ = plan(spec, std, 'CL')
        if joint_stations(a) != joint_stations(b):
            diff.append(key)
    check(not diff, 'FL and CL joint stations agree on all %d layouts' % len(allspecs),
          '; '.join(diff) if diff else 'so one seal implementation serves both')

    # The length rule, against the real boxes. This is the tripwire in seals().
    print('\n  seal geometry, off _face-levels.tsv (2026-08-14):')
    unprobed = []
    lenbad = []
    for kind, pool in (('CL', cl), ('FL', fl)):
        for s in sorted(pool, key=lambda x: x['feet']):
            b = stdbox.get(s['file'])
            if b is None:
                unprobed.append(s['file'])
                continue
            length = max(b[0], b[1])
            want = s['cross'] - SEAL_LEN_INSET[kind]
            lv = levels(s['file'])
            datum = max(lv, key=lambda r: r[1])[0] if lv else None
            print('    %-14s across %6.4f  len %6.1f (rule %6.1f)  tall %6.4f  '
                  'datum %s  levels %s'
                  % (s['file'], min(b[0], b[1]), length, want, b[2],
                     ('%7.4f' % datum) if datum is not None else '    n/a',
                     ' '.join('%g' % z for z, _ in lv)))
            if abs(length - want) > 0.05:
                lenbad.append('%s %.4f vs %.4f' % (s['file'], length, want))
    check(not lenbad,
          'every probed seal matches its family length rule (CL cross-2, FL cross)',
          '; '.join(lenbad) if lenbad else '')
    print('    NOT IN THAT PROBE, so unverified here: %s'
          % (', '.join(sorted(unprobed)) or 'none'))
    print('    NOTE the CL boxes above read 2.0000 tall - that probe predates')
    print("    Benton's 2026-08-17 re-cut to 1.750, so the CL rows are STALE.")
    print('    The FL rows have no such known event but carry the same date, so')
    print('    the FL datum above is a 2026-08-14 reading, not a fit test.')

    print('\n=== 8. what this harness CANNOT see ===============================')
    print('  - bracket_edge / the end-for-end turn: needs the part geometry, so')
    print('    only SketchUp can answer whether ENH deck parts carry a bracket')
    print('    line at all. Where they do not, the code falls back to the same')
    print('    positional rule the Standard deck uses for symmetric panels.')
    print('  - contact_z, deck_extent, the real bounding boxes: not used by the')
    print('    IEP path (it seats off the placed Standard deck), but they are')
    print('    why nothing here is evidence about the Standard path.')
    print('  - whether the placed inner deck actually clears the inner walls.')
    print("  - the FLOOR SEAM SEAL'S HEIGHT. wr-deck.rb derives it (top face")
    print('    flush with the deck top) and warns by name on every build. The')
    print('    part geometry above says what it would land on; only a fit test')
    print('    says whether that is where it belongs.')
    print('  - whether the ENH tray lip really is a lip. The measurement is')
    print('    unambiguous - +1 per outer edge across all 44 parts - but that it')
    print('    is the engulfing overhang rather than something else is read off')
    print("    Benton's own sentence about the tray, not off the geometry.")

    print('\n%s' % ('ALL CHECKS PASS' if not fails else 'FAILED: ' + ', '.join(fails)))
    return 0 if not fails else 1


if __name__ == '__main__':
    sys.exit(main())
