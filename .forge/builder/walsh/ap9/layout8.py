"""v8 layout for Walsh MDL 96168 E: 9 foam + AP 96168 (5 x 2x4, 2 x 1x4, 14 x 1x2), no foam cut.

    python layout8.py          # builds the candidates, runs the checker, writes layout-v8*.json

Coordinates are wall-local inches (see v8model.py): s along the wall in BOOTH coordinates
(S, N: booth x; E, W: booth y), z = booth z. s0/z0 is the min corner in those coordinates, which is
NOT always the viewer's lower-left: from inside the booth S and E run right-to-left.

Why this shape (derived, see v8solve.py / v8cut.py):
  - Proven per-wall maxima (CP-SAT, OPTIMAL): E 4 sheets, W 3, N 3, S 4 = 14 = 9 foam + 5 AP 2x4,
    so every wall carries its maximum. With the 1x4s and 1x2s, the only no-cut compositions are
      A: E 4+0+2  W 3+1+2  N 3+1+1  S 4+0+9   (sheets + 1x4 + 1x2)
      B: E 4+0+2  W 3+0+4  N 3+1+1  S 4+1+7
  - Only A lets S follow a clean row scheme (no piece crosses z 27.5); W follows none in A or B.
  - S needs at least 3 of its 1x2s stood on end, W 1, N 1; E 0 (2 when E is kept symmetric).
"""
import json, os
from v8model import check, NEED, usable, CENTRE, FACE, RUN, fixed, rect, gap2d, G

HERE = os.path.dirname(os.path.abspath(__file__))
PART = {('sheet', 'foam'): 'Foam', ('sheet', 'audimute'): 'Audimute2x4',
        ('1x4', 'audimute'): 'Audimute1x4', ('1x2', 'audimute'): 'Audimute1x2'}
WALLNAME = {'S': 'back', 'E': 'left', 'W': 'right', 'N': 'front'}

def P(kind, mat, s, z, orient, note=''):
    """orient: 'vertical' or 'horizontal' as it hangs. rot flag follows v8model.SIZES."""
    base_vertical = {'sheet': True, '1x4': True, '1x2': False}[kind]
    rot = (orient == 'vertical') != base_vertical
    return dict(kind=kind, mat=mat, s=round(s, 4), z=round(z, 4), rot=rot, orient=orient, note=note)

def stack3(s, z, note):
    """three flat 1x2s, 0.5 apart, bottom one at z."""
    return [P('1x2', 'audimute', s, z + k * 12.5, 'horizontal', note) for k in range(3)]

# ---------------------------------------------------------------- S (back) ---------------------------
def wall_S(mat_option=1):
    s0, s1 = usable('S')                     # 16.875 .. 153.188 (traps + 0.5)
    t0, t1 = s0 - G, s1 + G                  # trap faces 16.375 / 153.688 (observed)
    widths = [24, 24, 24, 24, 24, 12]        # stack S0 | V1 | stack S1 | V2 | V3 | 1x2 S3 (booth x ascending)
    g = (t1 - t0 - sum(widths)) / (len(widths) + 1)     # one clearance everywhere: trap-piece and piece-piece (0.759)
    xs = [t0 + g]
    for w in widths[:-1]: xs.append(xs[-1] + w + g)
    BZ = 27.75                               # band bottom (row below ends 27.25; V tops 75.75 = beam bottom 76.25 - 0.5)
    if mat_option == 1:   # AP 2x4 in the band between foam sheets (People's Space pattern)
        m1, m2, m3, mb = 'foam', 'audimute', 'foam', 'foam'
    else:                 # all three band sheets foam; the AP 2x4 lies in the bottom row
        m1, m2, m3, mb = 'foam', 'foam', 'foam', 'audimute'
    ps = []
    ps += stack3(xs[0], BZ, 'under S0 high cover')
    ps.append(P('sheet', m1, xs[1], BZ, 'vertical', 'band'))
    ps += stack3(xs[2], BZ, 'under S1 high cover')
    ps.append(P('sheet', m2, xs[3], BZ, 'vertical', 'band'))
    ps.append(P('sheet', m3, xs[4], BZ, 'vertical', 'band'))
    # single 1x2 on end under the S3 high cover, top aligned with the stacks (64.75)
    ps.append(P('1x2', 'audimute', xs[5], 64.75 - 24, 'vertical', 'under S3 high cover'))
    # bottom row: each piece centred between the low covers it sits between
    k = {f[1]: f[2:] for f in fixed('S')}
    lo0, lo1, lo3 = k['Duct Cover lo  S0i'], k['Duct Cover lo  S1i'], k['Duct Cover lo  S3i']
    c01 = (lo0[1] + lo1[0]) / 2              # between S0 and S1 low covers
    c13 = (lo1[1] + lo3[0]) / 2              # between S1 and S3 low covers
    ps.append(P('1x2', 'audimute', c01 - 12.5, 3.25, 'vertical', 'bottom row, between S0/S1 low covers'))
    ps.append(P('1x2', 'audimute', c01 + 0.5, 3.25, 'vertical', 'bottom row, between S0/S1 low covers'))
    ps.append(P('sheet', mb, c13 - 24, 3.25, 'horizontal', 'bottom row, between S1/S3 low covers'))
    return ps

# ---------------------------------------------------------------- E (left) ---------------------------
def wall_E(band_option=1):
    s0, s1 = usable('E')                     # 16.875 .. 92.5
    m = (s1 - s0 - 74) / 2                   # three 24s with 1.0 gaps, centred (margin 0.8125)
    cols = [s0 + m, s0 + m + 25, s0 + m + 50]
    BZ = 30.625 if band_option == 1 else 27.75   # 1: same band as W (mirror); 2: same as S and N
    ps = [P('sheet', 'audimute', cols[0], BZ, 'vertical', 'band, back column'),
          P('sheet', 'foam', cols[1], BZ, 'vertical', 'band, centre'),
          P('sheet', 'audimute', cols[2], BZ, 'vertical', 'band, front column'),
          P('1x2', 'audimute', cols[0], 3.25, 'vertical', 'bottom row'),
          P('sheet', 'foam', cols[0] + 13, 3.25, 'horizontal', 'bottom row, centre'),
          P('1x2', 'audimute', cols[2] + 12, 3.25, 'vertical', 'bottom row')]
    return ps

# ---------------------------------------------------------------- W (right) --------------------------
def wall_W():
    s0, s1 = usable('W')                     # 16.875 .. 92.0
    k = {f[1]: f[2:] for f in fixed('W')}
    lo = k['Duct Cover lo  W0i']             # z top 17.571
    cols = [17.6875, 42.6875, 67.6875]       # same column grid as E (band option 1)
    BZ = 30.625                              # lowest band that clears a flat 1x2 above the low cover
    z_flat = BZ - 12.5                       # 18.125: 0.554 above the low cover
    assert z_flat >= lo[3] + G
    ps = [P('1x2', 'audimute', 17.4375, z_flat, 'horizontal', 'back cluster, over the W0 low cover'),
          P('1x2', 'audimute', cols[0] - 0.5, BZ, 'vertical', 'back cluster, under the W0 high cover'),
          P('1x4', 'audimute', cols[0] + 12, BZ, 'vertical', 'back cluster'),
          P('sheet', 'foam', cols[1], BZ, 'vertical', 'band, centre'),
          P('sheet', 'audimute', cols[2], BZ, 'vertical', 'band, front column'),
          P('sheet', 'foam', (cols[1] + cols[2] + 24) / 2 - 24, 3.25, 'horizontal', 'bottom row, under the two band sheets')]
    return ps

# ---------------------------------------------------------------- N (front, door wall) ---------------
def wall_N():
    ps = [P('sheet', 'foam', 7.0, 3.25, 'horizontal', 'bottom row, under window N0'),
          P('1x2', 'audimute', (55.0 + 72.75) / 2 - 6, 3.25, 'vertical', 'bottom row, centre'),
          P('sheet', 'foam', 72.75, 3.25, 'horizontal', 'bottom row, under window N1'),
          P('1x4', 'audimute', 43.0, 27.75, 'vertical', 'between the windows (13.0 clear)'),
          P('sheet', 'audimute', 96.75, 27.75, 'vertical', 'beside the door, flush with the row end')]
    return ps

def build(s_opt=1, e_opt=1):
    return {'S': wall_S(s_opt), 'E': wall_E(e_opt), 'W': wall_W(), 'N': wall_N()}

def to_json(layout, name, title, options):
    walls = {}
    for w, ps in layout.items():
        ax, f, n = FACE[w]
        rows = []
        cnt = {}
        for p in ps:
            part = PART[(p['kind'], p['mat'])]
            cnt[part] = cnt.get(part, 0) + 1
            r = rect(p)
            near = min(((gap2d(r, k[2:]), k[1]) for k in fixed(w)), key=lambda t: t[0])
            others = [rect(q) for q in ps if q is not p]
            npg = min(gap2d(r, q) for q in others) if others else None
            rows.append({'id': f'{w}{len(rows) + 1:02d}', 'part': part,
                         'material': 'foam' if p['mat'] == 'foam' else 'Audimute',
                         'orient': p['orient'], 's0': round(r[0], 3), 's1': round(r[1], 3),
                         'z0': round(r[2], 3), 'z1': round(r[3], 3), 'w': round(r[1] - r[0], 3), 'h': round(r[3] - r[2], 3),
                         'nearest_fixed': near[1], 'gap_fixed': round(near[0], 3),
                         'gap_piece': None if npg is None else round(npg, 3), 'note': p['note']})
        walls[w] = {'name': WALLNAME[w], 's_axis': 'booth x' if ax == 'y' else 'booth y',
                    'face': {'axis': ax, 'coord': f, 'into_room': ('+' if n > 0 else '-') + ax,
                             'observed': {'S': 'y 4.25 (H-strip 4.313 at z ~40-41.5)', 'N': 'y 93.75 (window-panel H-strip 93.688 at z ~22.5-23)',
                                          'E': 'x 165.75 (H-strip 165.688 at z ~40-41)', 'W': 'x 4.25 (H-strip 4.313)'}[w]},
                    'viewed_from_inside': {'S': 's increases to the LEFT', 'E': 's increases to the LEFT (back corner on the right)',
                                           'W': 's increases to the RIGHT (back corner on the left)', 'N': 's increases to the RIGHT (door on the right)'}[w],
                    'usable_run': [round(v, 3) for v in usable(w)], 'centre': CENTRE[w],
                    'pieces': rows, 'counts': cnt}
    ok, lines, st = check(layout, NEED)
    return {'name': name, 'title': title, 'options': options, 'model': 'Z:\\Sketchup\\ClientDrawings\\Walsh Construction Tech Lab MDL 96168 E.skp',
            'booth': 'Booth - MDL 96168 E (pure translation +61.89, +11.63, +1.3125 in room coordinates)',
            'units': 'inches, booth-local; wall-local s along the wall, z up',
            'provenance': {'fixed items, faces, floor 2.75, tile 80.25': 'observed (ap9 ray survey + bounds dump, re-checked live 12 Oct evening)',
                           'piece positions': 'derived (this layout, layout8.py)', 'piece sizes': 'reported (part names 2x4/1x4/1x2; v7 bodies measured 24x48, 12x48, 24x12)'},
            'rules': ['gap >= 0.5 piece-piece and piece-fixed', 'z 3.25 .. 79.75', 'no cut', 'fabric (local -y) into the room', 'seat by multi-ray on the most proud face under the footprint'],
            'check': {'ok': ok, 'fail_lines': lines, 'min_gaps': {k: round(v, 3) for k, v in st['min'].items()}, 'where': st['where'], 'counts': st['counts']},
            'walls': walls}

if __name__ == '__main__':
    cands = [('layout-v8.json', 'v8 recommended', 'S AP 2x4 in the band; E band mirrors W', build(1, 1), {'S': 1, 'E': 1}),
             ('layout-v8-alt1.json', 'v8 alt 1', 'S foam band, AP 2x4 in the bottom row; E as v8', build(2, 1), {'S': 2, 'E': 1}),
             ('layout-v8-alt2.json', 'v8 alt 2', 'S as v8; E band aligned with S and N (27.75-75.75)', build(1, 2), {'S': 1, 'E': 2})]
    for fn, name, title, lay, opts in cands:
        js = to_json(lay, name, title, opts)
        json.dump(js, open(os.path.join(HERE, fn), 'w'), indent=1)
        c = js['check']
        print(f"{fn:<22} ok={c['ok']}  min gaps {c['min_gaps']}  counts {c['counts']}")
        for l in c['fail_lines']: print('   ', l)
        for k, v in c['where'].items(): print(f'      tightest {k}: {v}')
