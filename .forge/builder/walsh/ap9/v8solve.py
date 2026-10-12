"""v8: exact per-wall placement search with OR-Tools CP-SAT (Phase A, offline, no model edits).

Positions are solved in hundredths of an inch; keep-outs are rounded OUTWARD (lower edges down, upper
edges up), so a solution is never closer to a fixed item than the 0.5 rule. Pieces are non-guillotine
and free to sit anywhere, unlike guill.py's depth-limited grid.

    python v8solve.py cap                 # max sheets per wall, then the (1x4, 1x2) frontier at that count
    python v8solve.py sym WALL n_sheet n_1x4 n_1x2 [opts]   # most mirror-symmetric layout for one wall

Returned pieces: dict(kind, s, z, rot) in wall-local inches (see v8model.py).
"""
import sys, math, json, itertools
from ortools.sat.python import cp_model
from v8model import fixed, usable, CENTRE, SIZES, G, ZMIN, ZMAX, rect, check

SC = 100
def dn(x): return math.floor(x * SC + 1e-6)
def up(x): return math.ceil(x * SC - 1e-6)
GU = round(G * SC)

def _piece(m, wall, kind, rot_ok, present=None, name=''):
    """One piece: lower-left (s, z), orientation r (1 = turned 90 deg)."""
    w0, h0 = SIZES[kind]
    s0, s1 = usable(wall)
    s = m.NewIntVar(up(s0), dn(s1), 's' + name)
    z = m.NewIntVar(up(ZMIN), dn(ZMAX), 'z' + name)
    if rot_ok == 'only':
        r = m.NewConstant(1)
    elif rot_ok and w0 != h0:
        r = m.NewBoolVar('r' + name)
    else:
        r = m.NewConstant(0)
    W = w0 * SC + (h0 - w0) * SC * r
    H = h0 * SC + (w0 - h0) * SC * r
    enf = [present] if present is not None else []
    m.Add(s + W <= dn(s1)).OnlyEnforceIf(enf)
    m.Add(z + H <= dn(ZMAX)).OnlyEnforceIf(enf)
    for k in fixed(wall):
        a, b, c, d = k[2:]
        bs = [m.NewBoolVar('') for _ in range(4)]
        m.Add(s + W + GU <= dn(a)).OnlyEnforceIf(bs[0])
        m.Add(s >= up(b) + GU).OnlyEnforceIf(bs[1])
        m.Add(z + H + GU <= dn(c)).OnlyEnforceIf(bs[2])
        m.Add(z >= up(d) + GU).OnlyEnforceIf(bs[3])
        if present is None: m.AddBoolOr(bs)
        else: m.AddBoolOr(bs + [present.Not()])
    # gap-inflated intervals for NoOverlap2D (each side grows by G, so touching = G apart)
    xs = m.NewIntVar(-10**7, 10**7, ''); xe = m.NewIntVar(-10**7, 10**7, '')
    ys = m.NewIntVar(-10**7, 10**7, ''); ye = m.NewIntVar(-10**7, 10**7, '')
    m.Add(xs == s); m.Add(xe == s + W + GU); m.Add(ys == z); m.Add(ye == z + H + GU)
    xsz = m.NewIntVar(0, 10**6, ''); ysz = m.NewIntVar(0, 10**6, '')
    m.Add(xsz == W + GU); m.Add(ysz == H + GU)
    if present is None:
        xi = m.NewIntervalVar(xs, xsz, xe, ''); yi = m.NewIntervalVar(ys, ysz, ye, '')
    else:
        xi = m.NewOptionalIntervalVar(xs, xsz, xe, present, ''); yi = m.NewOptionalIntervalVar(ys, ysz, ye, present, '')
    return dict(kind=kind, s=s, z=z, r=r, W=W, H=H, xi=xi, yi=yi, present=present)

def _solve(m, tl, workers=8):
    sv = cp_model.CpSolver()
    sv.parameters.max_time_in_seconds = tl
    sv.parameters.num_workers = workers
    st = sv.Solve(m)
    return sv, st

def _out(sv, P):
    res = []
    for p in P:
        if p['present'] is not None and not sv.Value(p['present']): continue
        res.append(dict(kind=p['kind'], s=sv.Value(p['s']) / SC, z=sv.Value(p['z']) / SC, rot=bool(sv.Value(p['r']))))
    return res

ROT = {'sheet': True, '1x4': True, '1x2': True, 'sq': False}

def capacity(wall, fix=None, maxes=None, weights=None, tl=60, rot=ROT):
    """Optional pool; maximise sum(weight * present) with counts in `fix` forced. Returns (status, counts, pieces)."""
    maxes = maxes or {'sheet': 6, '1x4': 6, '1x2': 24}
    weights = weights or {'sheet': 2, '1x4': 1, '1x2': 0.5}
    m = cp_model.CpModel(); P = []
    for kind, n in maxes.items():
        for i in range(n):
            pr = m.NewBoolVar(f'p{kind}{i}')
            P.append(_piece(m, wall, kind, rot[kind], pr, f'{kind}{i}'))
        ks = [p for p in P if p['kind'] == kind]
        for a, b in zip(ks, ks[1:]):
            m.AddImplication(b['present'], a['present'])     # use pieces in order
    m.AddNoOverlap2D([p['xi'] for p in P], [p['yi'] for p in P])
    for kind, n in (fix or {}).items():
        m.Add(sum(p['present'] for p in P if p['kind'] == kind) == n)
    m.Maximize(sum(int(weights[p['kind']] * 2) * p['present'] for p in P))
    sv, st = _solve(m, tl)
    if st not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        return sv.StatusName(st), None, None
    pcs = _out(sv, P)
    cnt = {k: sum(1 for p in pcs if p['kind'] == k) for k in maxes}
    return sv.StatusName(st), cnt, pcs

def feasible(wall, counts, tl=60, rot=ROT, extra=None):
    m = cp_model.CpModel(); P = []
    for kind, n in counts.items():
        ks = [_piece(m, wall, kind, rot[kind], None, f'{kind}{i}') for i in range(n)]
        for a, b in zip(ks, ks[1:]):
            m.Add(a['s'] * 100000 + a['z'] <= b['s'] * 100000 + b['z'])   # interchangeable: order them
        P += ks
    m.AddNoOverlap2D([p['xi'] for p in P], [p['yi'] for p in P])
    if extra: extra(m, P)
    sv, st = _solve(m, tl)
    if st in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        return sv.StatusName(st), _out(sv, P)
    return sv.StatusName(st), None

def symmetric(wall, counts, tl=120, rot=ROT, extra=None, centre=None, weight=None, zweight=1, workers=8):
    """Fixed piece counts; minimise the mirror-symmetry defect about the wall centre.
    Every piece is matched with a partner of the same kind (or with itself, which then wants to sit on
    the axis). Defect of a pair = |mirror offset along s| + zweight*|z difference|, weighted by piece area.
    Matched pairs must share an orientation. Returns (status, objective, pieces with 'pair' ids)."""
    C2 = round(2 * (CENTRE[wall] if centre is None else centre) * SC)
    weight = weight or {'sheet': 4, '1x4': 2, '1x2': 1, 'sq': 2}
    m = cp_model.CpModel(); P = []; groups = {}
    for kind, n in counts.items():
        ks = [_piece(m, wall, kind, rot[kind], None, f'{kind}{i}') for i in range(n)]
        for a, b in zip(ks, ks[1:]):
            m.Add(a['s'] <= b['s'])
        groups[kind] = ks; P += ks
    m.AddNoOverlap2D([p['xi'] for p in P], [p['yi'] for p in P])
    obj = []; pairs = []
    for kind, ks in groups.items():
        n = len(ks)
        M = {}
        for i in range(n):
            for j in range(i, n):
                M[i, j] = m.NewBoolVar(f'm{kind}{i}{j}')
        for i in range(n):
            m.AddExactlyOne([M[min(i, j), max(i, j)] for j in range(n)])
        for (i, j), b in M.items():
            a_, c_ = ks[i], ks[j]
            d = m.NewIntVar(0, 10**6, '')
            if i == j:
                e = 2 * a_['s'] + a_['W'] - C2
                m.Add(d >= e).OnlyEnforceIf(b); m.Add(d >= -e).OnlyEnforceIf(b)
            else:
                m.Add(a_['r'] == c_['r']).OnlyEnforceIf(b)
                e = a_['s'] + a_['W'] + c_['s'] - C2
                dz = m.NewIntVar(0, 10**6, '')
                m.Add(dz >= a_['z'] - c_['z']).OnlyEnforceIf(b); m.Add(dz >= c_['z'] - a_['z']).OnlyEnforceIf(b)
                m.Add(d >= e + zweight * dz).OnlyEnforceIf(b); m.Add(d >= -e + zweight * dz).OnlyEnforceIf(b)
            obj.append(weight[kind] * d)
            pairs.append((kind, i, j, b))
    if extra:
        obj += list(extra(m, P) or [])
    m.Minimize(sum(obj))
    sv, st = _solve(m, tl, workers)
    if st not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        return sv.StatusName(st), None, None
    pcs = _out(sv, P)
    pid = {}
    idx = {id(p): k for k, p in enumerate(P)}
    for kind, i, j, b in pairs:
        if sv.Value(b):
            a_, c_ = idx[id(groups[kind][i])], idx[id(groups[kind][j])]
            pid[a_] = pid[c_] = f'{kind}{i}-{j}' if i != j else f'{kind}{i}=axis'
    for k, p in enumerate(pcs): p['pair'] = pid.get(k)
    return sv.StatusName(st), sv.ObjectiveValue() / SC, pcs

def levels(R, vpen=0, also=None):
    """extra= hook: every piece's bottom OR top sits on one of R shared row lines (tidiness).
    vpen = objective penalty per 1x2 stood on end (12 wide x 24 tall). `also` = further hook."""
    def f(m, P):
        L = [m.NewIntVar(up(ZMIN), dn(ZMAX), f'L{k}') for k in range(R)]
        for a, b in zip(L, L[1:]): m.Add(a + 1 <= b)
        for p in P:
            bs = []
            for k in range(R):
                b1 = m.NewBoolVar(''); m.Add(p['z'] == L[k]).OnlyEnforceIf(b1)
                b2 = m.NewBoolVar(''); m.Add(p['z'] + p['H'] == L[k]).OnlyEnforceIf(b2)
                bs += [b1, b2]
            m.AddBoolOr(bs)
        terms = [vpen * p['r'] for p in P if p['kind'] == '1x2'] if vpen else []
        if also: terms += list(also(m, P) or [])
        return terms
    return f

def show(wall, pcs):
    for p in sorted(pcs, key=lambda p: (p['z'], p['s'])):
        r = rect(p)
        print(f"   {p['kind']:<5} {r[1]-r[0]:>2.0f}x{r[3]-r[2]:<2.0f} s {r[0]:7.2f}-{r[1]:7.2f}  z {r[2]:6.2f}-{r[3]:6.2f}  {p.get('pair') or ''}")

if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'cap':
        for wall in sys.argv[2:] or 'ESWN':
            st, cnt, pcs = capacity(wall, weights={'sheet': 1, '1x4': 0, '1x2': 0}, tl=60)
            B = cnt['sheet']
            print(wall, 'max sheets', B, st, flush=True)
            for f4 in range(0, 3):
                st2, cnt2, _ = capacity(wall, fix={'sheet': B, '1x4': f4}, weights={'sheet': 0, '1x4': 0, '1x2': 1}, tl=90)
                print('   sheets', B, '1x4', f4, '-> max 1x2', cnt2 and cnt2['1x2'], st2, flush=True)
            st3, cnt3, _ = capacity(wall, fix={'sheet': B - 1, '1x4': 0}, weights={'sheet': 0, '1x4': 0, '1x2': 1}, tl=90)
            print('   sheets', B - 1, '1x4 0 -> max 1x2', cnt3 and cnt3['1x2'], st3, flush=True)
    elif cmd == 'sym':
        wall = sys.argv[2]; n = list(map(int, sys.argv[3:6]))
        st, obj, pcs = symmetric(wall, {'sheet': n[0], '1x4': n[1], '1x2': n[2]}, tl=float(sys.argv[6]) if len(sys.argv) > 6 else 120)
        print(wall, st, 'defect', obj)
        if pcs: show(wall, pcs)
    elif cmd == 'tidy':
        # tidy WALL n_sheet n_1x4 n_1x2 R tl [vpen]
        wall = sys.argv[2]; n = list(map(int, sys.argv[3:6])); R = int(sys.argv[6]); tl = float(sys.argv[7])
        vpen = int(sys.argv[8]) if len(sys.argv) > 8 else 0
        st, obj, pcs = symmetric(wall, {'sheet': n[0], '1x4': n[1], '1x2': n[2]}, tl=tl, extra=levels(R, vpen * SC))
        print(wall, n, 'rows', R, st, 'objective', obj, flush=True)
        if pcs: show(wall, pcs)
