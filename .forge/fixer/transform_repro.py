#!/usr/bin/env python3
"""
Reproduction + proof for the auto-dimension.rb container-transform bug.

There is no ruby.exe on this machine and SketchUp cannot be driven headless, so
this is a LINE-FAITHFUL Python reimplementation of the coordinate math in
scripts/auto-dimension.rb -- both the OLD version (no transform) and the NEW one
(transform threaded through collect / runs_of / the overall bounding box).

It is not a test of the Ruby. It is a test of the arithmetic the Ruby performs,
run on a synthetic room under four container transforms:

    (a) identity      -- Benton's daily case, must be a bit-for-bit no-op
    (b) translation   -- room group moved after it was drawn
    (c) rotation      -- room group rotated 30 degrees about Z
    (d) scale         -- room group scaled non-uniformly (1.5 x, 0.75 y)

Ground truth is defined independently: the room as it ACTUALLY APPEARS in the
model is T applied to the local polygon. A dimension is correct when both its
endpoints lie on that world polygon and its length equals the world wall length.

Run:  python .forge/fixer/transform_repro.py
"""

import math

TOL = 0.02
SEG_OFF = 12.0
OVR_OFF = 34.0


# --------------------------------------------------------------- transforms --
# A 4x4 column-vector matrix, same convention as Geom::Transformation, where
# `t * point` applies t to point and (A * B) * p == A * (B * p).

def ident():
    return [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]


def translate(dx, dy, dz=0.0):
    m = ident()
    m[0][3], m[1][3], m[2][3] = dx, dy, dz
    return m


def rotate_z(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    m = ident()
    m[0][0], m[0][1] = c, -s
    m[1][0], m[1][1] = s, c
    return m


def scale(sx, sy, sz=1.0):
    m = ident()
    m[0][0], m[1][1], m[2][2] = sx, sy, sz
    return m


def matmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)]
            for i in range(4)]


def xform_pt(t, p):
    x, y, z = p
    return (t[0][0] * x + t[0][1] * y + t[0][2] * z + t[0][3],
            t[1][0] * x + t[1][1] * y + t[1][2] * z + t[1][3],
            t[2][0] * x + t[2][1] * y + t[2][2] * z + t[2][3])


def xform_vec(t, v):
    """No translation component -- this is Geom::Vector3d#transform."""
    x, y, z = v
    return (t[0][0] * x + t[0][1] * y + t[0][2] * z,
            t[1][0] * x + t[1][1] * y + t[1][2] * z,
            t[2][0] * x + t[2][1] * y + t[2][2] * z)


# ------------------------------------------------------------- vector helpers --

def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def length(v):
    return math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2)


def normalize(v):
    n = length(v)
    return (v[0] / n, v[1] / n, v[2] / n)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def parallel(a, b):
    return length(cross(a, b)) < 1e-9


def samedirection(a, b):
    return parallel(a, b) and dot(a, b) > 0


def dist(a, b):
    return length(sub(a, b))


# ----------------------------------------------- auto-dimension.rb, faithfully --

def dedupe(pts):
    out = []
    for p in pts:
        if not out or dist(out[-1], p) > TOL:
            out.append(p)
    if len(out) > 1 and dist(out[0], out[-1]) < TOL:
        out.pop()
    return out


def runs_of(local_pts, tr):
    """runs_of(face, tr). tr=identity reproduces the OLD behaviour exactly."""
    pts = dedupe([xform_pt(tr, p) for p in local_pts])
    if len(pts) < 3:
        return []
    merged = []
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        v = sub(b, a)
        if length(v) < TOL:
            continue
        if merged and parallel(merged[-1]['vec'], v) and samedirection(merged[-1]['vec'], v):
            merged[-1]['b'] = b
            merged[-1]['vec'] = sub(merged[-1]['b'], merged[-1]['a'])
        else:
            merged.append({'a': a, 'b': b, 'vec': v})
    if (len(merged) > 2 and parallel(merged[-1]['vec'], merged[0]['vec'])
            and samedirection(merged[-1]['vec'], merged[0]['vec'])):
        merged[0]['a'] = merged[-1]['a']
        merged[0]['vec'] = sub(merged[0]['b'], merged[0]['a'])
        merged.pop()
    return merged


def signed_area(runs):
    return sum(r['a'][0] * r['b'][1] - r['b'][0] * r['a'][1] for r in runs) / 2.0


def outward(run, ccw):
    v = run['vec']
    n = (v[1], -v[0], 0.0) if ccw else (-v[1], v[0], 0.0)
    return normalize(n) if length(n) > 0 else (0.0, -1.0, 0.0)


def bounds_of(runs):
    """NEW: world bounding box of the traced perimeter."""
    xs, ys, zs = [], [], []
    for r in runs:
        for p in (r['a'], r['b']):
            xs.append(p[0]); ys.append(p[1]); zs.append(p[2])
    return {'minx': min(xs), 'maxx': max(xs),
            'miny': min(ys), 'maxy': max(ys),
            'minz': min(zs), 'maxz': max(zs),
            'width': max(xs) - min(xs), 'height': max(ys) - min(ys)}


def local_bounds(local_pts):
    """OLD: face.bounds -- the face's own, untransformed, local extent."""
    xs = [p[0] for p in local_pts]
    ys = [p[1] for p in local_pts]
    zs = [p[2] for p in local_pts]
    return {'minx': min(xs), 'maxx': max(xs),
            'miny': min(ys), 'maxy': max(ys),
            'minz': min(zs), 'maxz': max(zs),
            'width': max(xs) - min(xs), 'height': max(ys) - min(ys)}


def dimension_face(local_pts, tr, bb):
    """
    Returns the list of (start_pt, end_pt, offset_vec) triples that would be
    handed to model.entities.add_dimension_linear -- i.e. the actual drawn
    geometry, which is what we then check against ground truth.

    OLD  == dimension_face(pts, identity, local_bounds(pts))
    NEW  == dimension_face(pts, T,        bounds_of(runs_of(pts, T)))
    """
    runs = runs_of(local_pts, tr)
    assert len(runs) >= 3, 'could not read a closed outer loop'
    ccw = signed_area(runs) > 0
    out = []
    for r in runs:
        n = outward(r, ccw)
        out.append((r['a'], r['b'], (n[0] * SEG_OFF, n[1] * SEG_OFF, 0.0)))
    z = bb['minz']
    out.append(((bb['minx'], bb['miny'], z), (bb['maxx'], bb['miny'], z),
                (0.0, -OVR_OFF, 0.0)))
    out.append(((bb['minx'], bb['miny'], z), (bb['minx'], bb['maxy'], z),
                (-OVR_OFF, 0.0, 0.0)))
    return runs, out


# ------------------------------------------------------------- ground truth --

def on_world_polygon(p, world_pts):
    """Is p on some edge of the room as it actually appears in the model?"""
    n = len(world_pts)
    for i in range(n):
        a, b = world_pts[i], world_pts[(i + 1) % n]
        ab = sub(b, a)
        L = length(ab)
        if L < TOL:
            continue
        u = normalize(ab)
        t = dot(sub(p, a), u)
        if -TOL <= t <= L + TOL:
            perp = length(sub(sub(p, a), (u[0] * t, u[1] * t, u[2] * t)))
            if perp < 1e-6:
                return True
    return False


# ------------------------------------------------------------------- the room --
# An L-shaped room in the group's OWN coordinates, drawn near the origin the way
# build-room.rb draws it. L-shaped on purpose: a plain rectangle would hide a
# winding or run-merging error.

ROOM = [(0.0, 0.0, 0.0),
        (144.0, 0.0, 0.0),
        (144.0, 96.0, 0.0),
        (72.0, 96.0, 0.0),
        (72.0, 168.0, 0.0),
        (0.0, 168.0, 0.0)]

CASES = [
    ('a identity   ', ident()),
    ('b translation', translate(600.0, -250.0, 0.0)),
    ('c rotation 30', matmul(translate(600.0, -250.0, 0.0), rotate_z(30.0))),
    ('d scale 1.5x/0.75y', matmul(translate(600.0, -250.0, 0.0), scale(1.5, 0.75))),
    ('e nested (move o rotate o move)',
     matmul(translate(300.0, 400.0, 0.0),
            matmul(rotate_z(45.0), translate(50.0, 20.0, 0.0)))),
]


def main():
    failures = []
    for name, T in CASES:
        world = [xform_pt(T, p) for p in ROOM]

        old_runs, old_dims = dimension_face(ROOM, ident(), local_bounds(ROOM))
        new_runs, new_dims = dimension_face(ROOM, T, bounds_of(runs_of(ROOM, T)))

        # -- OLD: do its drawn points land on the room as it really is?
        old_ok = all(on_world_polygon(a, world) and on_world_polygon(b, world)
                     for a, b, _ in old_dims[:len(old_runs)])
        # -- NEW: same question.
        new_ok = all(on_world_polygon(a, world) and on_world_polygon(b, world)
                     for a, b, _ in new_dims[:len(new_runs)])

        # -- Do the NEW segment lengths equal the real wall lengths?
        want = []
        n = len(world)
        i = 0
        while i < n:
            a, b = world[i], world[(i + 1) % n]
            want.append(length(sub(b, a)))
            i += 1
        got = sorted(round(length(r['vec']), 6) for r in new_runs)
        want_s = sorted(round(w, 6) for w in want)
        len_ok = got == want_s

        # -- Identity must be a bit-for-bit no-op.
        noop = (old_dims == new_dims)

        print('%-32s  old-on-room=%-5s  new-on-room=%-5s  new-lengths=%-5s  identical=%s'
              % (name, old_ok, new_ok, len_ok, noop))

        if not new_ok:
            failures.append(name + ': NEW dimensions are not on the real room')
        if not len_ok:
            failures.append(name + ': NEW segment lengths != real wall lengths')
        if name.startswith('a ') and not noop:
            failures.append('identity is NOT a no-op -- daily case changed')
        if not name.startswith('a ') and old_ok:
            failures.append(name + ': OLD was expected to be wrong but was not')

        # -- What the old overall actually read vs the truth.
        ob, nb = local_bounds(ROOM), bounds_of(runs_of(ROOM, T))
        print('      overall  old %.2f x %.2f   new %.2f x %.2f   (real extent %.2f x %.2f)'
              % (ob['width'], ob['height'], nb['width'], nb['height'],
                 max(p[0] for p in world) - min(p[0] for p in world),
                 max(p[1] for p in world) - min(p[1] for p in world)))
        # -- How far the old chain landed from where it belonged.
        off = max(min(dist(a, w) for w in world) for a, _b, _o in old_dims[:len(old_runs)])
        print('      worst old chain endpoint is %.2f" from any real room corner' % off)

    print()
    if failures:
        print('FAIL')
        for f in failures:
            print('  - ' + f)
        raise SystemExit(1)
    print('PASS -- identity unchanged; every transformed case now lands on the real room.')


if __name__ == '__main__':
    main()
