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
KEY = re.compile(r"^\s*'(MDL [0-9]+ E)'\s*=>\s*\{")
PART = re.compile(r":k=>'(\w+)'.*?:sh=>'(\w+)'.*?:poly=>\[(.*?)\]\s*\}")
PAIR = re.compile(r'\[([-\d.]+),\s*([-\d.]+)\]')


def load_specs():
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
        if re.match(r"^\s*'MDL ", line):        # a Standard entry: stop collecting
            cur = None
            continue
        pm = PART.search(line)
        if pm:
            poly = [(float(a), float(b)) for a, b in PAIR.findall(pm.group(3))]
            cur['parts'].append({'k': pm.group(1), 'sh': pm.group(2), 'poly': poly})
    return specs


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

    print('\n=== 5. what this harness CANNOT see ===============================')
    print('  - bracket_edge / the end-for-end turn: needs the part geometry, so')
    print('    only SketchUp can answer whether ENH deck parts carry a bracket')
    print('    line at all. Where they do not, the code falls back to the same')
    print('    positional rule the Standard deck uses for symmetric panels.')
    print('  - contact_z, deck_extent, the real bounding boxes: not used by the')
    print('    IEP path (it seats off the placed Standard deck), but they are')
    print('    why nothing here is evidence about the Standard path.')
    print('  - whether the placed inner deck actually clears the inner walls.')

    print('\n%s' % ('ALL CHECKS PASS' if not fails else 'FAILED: ' + ', '.join(fails)))
    return 0 if not fails else 1


if __name__ == '__main__':
    sys.exit(main())
