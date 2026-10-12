"""v8 wall model + checker for the Walsh MDL 96168 E foam/Audimute layout (Phase A, offline).

Built straight from ../ap9-survey.json (observed rects, booth-local inches), not from the rounded
walls.py values. Wall-local 2D: s along the wall (S,N: booth x; E,W: booth y), z = booth z.

Rules (Benton, DEVLOG 2026-10-12 session close):
  - gap >= 0.5 between any two pieces and between a piece and any fixed item (traps, covers, beams,
    seals, window trims, door frame, panel returns, floor, ceiling tile);
  - z between 3.25 and 79.75 (floor EFP top 2.75 and tile underside 80.25, each + 0.5).
"""
import json, os, itertools

HERE = os.path.dirname(os.path.abspath(__file__))
SURVEY = json.load(open(os.path.join(HERE, '..', 'ap9-survey.json')))
G = 0.5
FLOOR = SURVEY['meta']['floor_top']                 # 2.75 observed
TILE = SURVEY['meta']['ceiling_tile_underside']     # 80.25 observed
ZMIN, ZMAX = FLOOR + G, TILE - G                    # 3.25, 79.75

# Interior face extents along each wall (observed face planes: S/W 4.25, N 93.75, E 165.75).
RUN = {'S': (4.25, 165.75), 'N': (4.25, 165.75), 'E': (4.25, 93.75), 'W': (4.25, 93.75)}
# Face plane (the coordinate across the wall) and the direction INTO the room, booth-local.
FACE = {'S': ('y', 4.25, +1), 'N': ('y', 93.75, -1), 'E': ('x', 165.75, -1), 'W': ('x', 4.25, +1)}
# Wall centre used for mirror symmetry = middle of the usable run between the corner items
# (S: between the trap stacks; E: trap to door-frame return; W: trap to N0 panel return;
#  N: W-corner clearance to the door frame).
DEPTH = 2.125   # thickest piece off the face (Audimute 1x2 box 4.125-6.25, observed); foam is 2.0

def fixed(wall):
    """Every fixed keep-out on a wall as (kind, name, s0, s1, z0, z1)."""
    out = [(f['kind'], f['name'], *f['rect']) for f in SURVEY['walls'][wall]['fixed']]
    if wall == 'N':
        # W-wall pieces stand 4.25-6.25 off the W face; a N piece must clear them by 0.5 in 3D.
        # walls.py used s >= 6.88 for this corner; keep that (conservative by 0.13).
        out.append(('corner', 'W-wall panels at the NW corner', 4.25, 6.38, 0.75, 80.25))
    return out

def usable(wall):
    """(s_lo, s_hi) the run between the corner items, each + 0.5 (derived from fixed())."""
    lo, hi = RUN[wall]
    K = fixed(wall)
    # walk in from each end past any full-height item that touches the end region
    left = [k for k in K if k[0] in ('trap', 'corner') and k[2] <= lo + 1]
    right = [k for k in K if k[0] in ('trap', 'door', 'door frame return', 'window panel return') and k[3] >= hi - 1]
    s0 = max([k[3] for k in left], default=lo) + G
    s1 = min([k[2] for k in right], default=hi) - G
    return s0, s1

CENTRE = {w: round(sum(usable(w)) / 2, 4) for w in RUN}

# Piece kinds. 'sheet' = 2x4 (foam or Audimute); vertical 24 wide x 48 tall, horizontal 48 x 24.
SIZES = {'sheet': (24, 48), '1x4': (12, 48), '1x2': (24, 12), 'sq': (24, 24)}

def dims(p):
    w, h = SIZES[p['kind']]
    return (h, w) if p.get('rot') else (w, h)

def rect(p):
    w, h = dims(p)
    return (p['s'], p['s'] + w, p['z'], p['z'] + h)

def gap2d(a, b):
    """Separation between two wall-local rects (s0,s1,z0,z1); negative means overlap."""
    return max(b[0] - a[1], a[0] - b[1], b[2] - a[3], a[2] - b[3])

def box3d(wall, r):
    """Booth-local 3D box of a piece rect on a wall (DEPTH off the face, into the room)."""
    ax, f, n = FACE[wall]
    d0, d1 = sorted((f, f + n * DEPTH))
    s0, s1, z0, z1 = r
    if ax == 'y':   # S/N: s = x
        return (s0, s1, d0, d1, z0, z1)
    return (d0, d1, s0, s1, z0, z1)   # E/W: s = y

def gap3d(a, b):
    return max(b[0] - a[1], a[0] - b[1], b[2] - a[3], a[2] - b[3], b[4] - a[5], a[4] - b[5])

def check(layout, need=None, eps=1e-6):
    """layout = {wall: [piece, ...]}, piece = dict(kind, mat, s, z, rot).
    Returns (ok, report_lines, stats). Exact geometry, no rounding."""
    lines, ok = [], True
    mins = {'piece-piece': 1e9, 'piece-fixed': 1e9, 'cross-wall 3d': 1e9}
    worst = {}
    for wall, ps in layout.items():
        s0w, s1w = RUN[wall]
        K = fixed(wall)
        rs = [rect(p) for p in ps]
        for i, (p, r) in enumerate(zip(ps, rs)):
            if r[2] < ZMIN - eps or r[3] > ZMAX + eps or r[0] < s0w + G - eps or r[1] > s1w - G + eps:
                ok = False; lines.append(f'FAIL {wall} piece {i} {p["kind"]} {r} outside the wall/floor/tile limits')
            for k in K:
                g = gap2d(r, k[2:])
                if g < mins['piece-fixed']:
                    mins['piece-fixed'] = g; worst['piece-fixed'] = f'{wall} {p["kind"]}#{i} vs {k[1]}'
                if g < G - eps:
                    ok = False; lines.append(f'FAIL {wall} piece {i} {p["kind"]} {r} is {g:.3f} from {k[1]}')
        for i, j in itertools.combinations(range(len(ps)), 2):
            g = gap2d(rs[i], rs[j])
            if g < mins['piece-piece']:
                mins['piece-piece'] = g; worst['piece-piece'] = f'{wall} #{i} {ps[i]["kind"]} vs #{j} {ps[j]["kind"]}'
            if g < G - eps:
                ok = False; lines.append(f'FAIL {wall} pieces {i},{j} gap {g:.3f}')
    # corners: pieces on adjacent walls, in 3D
    walls = list(layout)
    for wa, wb in itertools.combinations(walls, 2):
        for pa in layout[wa]:
            for pb in layout[wb]:
                g = gap3d(box3d(wa, rect(pa)), box3d(wb, rect(pb)))
                if g < mins['cross-wall 3d']:
                    mins['cross-wall 3d'] = g; worst['cross-wall 3d'] = f'{wa} {pa["kind"]} vs {wb} {pb["kind"]}'
                if g < G - eps:
                    ok = False; lines.append(f'FAIL corner {wa}/{wb} 3D gap {g:.3f}')
    # counts
    cnt = {}
    for ps in layout.values():
        for p in ps:
            key = p['kind'] if p['kind'] != 'sheet' else 'sheet ' + p['mat']
            cnt[key] = cnt.get(key, 0) + 1
    if need is not None and cnt != need:
        ok = False; lines.append(f'FAIL counts {cnt} != {need}')
    return ok, lines, {'min': mins, 'where': worst, 'counts': cnt}

NEED = {'sheet foam': 9, 'sheet audimute': 5, '1x4': 2, '1x2': 14}

if __name__ == '__main__':
    for w in 'SENW':
        print(w, 'run', RUN[w], 'usable', usable(w), 'centre', CENTRE[w], 'fixed', len(fixed(w)))
