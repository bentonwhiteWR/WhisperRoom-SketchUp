#!/usr/bin/env python3
"""
Studio Light spray guide — STL generator.

The part is a pure height field: every solid column runs from z = 0 up to one
height, so the whole thing can be described as h(x, y) over a rectangular
partition of the plan. Building it that way instead of unioning overlapping
boxes is what makes the mesh exactly watertight — there are no coincident
faces to reconcile and no overlap fudge to choose.

Every dimension here matches docs/spray-guide.html Rev D. If the two disagree,
this file is right and the sheet is stale.

    python scripts/spray-guide-stl.py [-o out.stl]

Writes a binary STL in millimetres, then self-audits:
  * every directed edge used exactly once  ->  closed, orientable, manifold
  * mesh volume by the divergence theorem  vs  the analytic column sum
Both must pass or it refuses to write the file.
"""

import argparse
import struct
import sys

# --------------------------------------------------------------- constants --
# All millimetres. Source tags match the sheet's provenance table.

L        = 150.0   # specified  overall length
D        =  65.0   # derived    plate depth, 30.1 + 27.0 + 7.9
T        =   5.0   # measured   plate thickness

STEP_L   =  82.4   # derived    step footprint, photo-scaled +/- 1.5
STEP_W   =  22.2   # derived    step footprint, photo-scaled +/- 1.5
STEP_H   =   6.0   # specified  proud of the plate face
RIM      =   2.4   # derived    plate front edge to the step

WIN_L    =  98.0   # specified  spray opening
WIN_H    =  27.0   # measured   spray opening depth
WIN_Y0   =  30.1   # derived    front edge to the opening

FOOT_Y1  =  85.1   # measured   overall depth, front edge to foot outer face
FOOT_Z   =  19.5   # specified  foot height, total (was 12.0, too low)

# Derived positions.
LEG      = (L - WIN_L) / 2.0          # 26.00 side leg, and the foot width
sx0, sx1 = (L - STEP_L) / 2.0, (L + STEP_L) / 2.0
sy0, sy1 = RIM, RIM + STEP_W
wx0, wx1 = LEG, L - LEG
wy0, wy1 = WIN_Y0, WIN_Y0 + WIN_H

TOP = T + STEP_H                      # 11.00 step crown


# ------------------------------------------------------------ height field --
def height_field():
    """Return (xs, ys, h) where h[j][i] is the column height of cell
    (xs[i]..xs[i+1]) x (ys[j]..ys[j+1]).  Height 0 means void."""
    xs = sorted({0.0, LEG, sx0, sx1, L - LEG, L})
    ys = sorted({0.0, sy0, sy1, wy0, wy1, D, FOOT_Y1})

    h = []
    for j in range(len(ys) - 1):
        y0, y1 = ys[j], ys[j + 1]
        row = []
        for i in range(len(xs) - 1):
            x0, x1 = xs[i], xs[i + 1]
            in_win  = wx0 <= x0 and x1 <= wx1 and wy0 <= y0 and y1 <= wy1
            in_foot = y0 >= D and (x1 <= LEG or x0 >= L - LEG)
            in_step = sx0 <= x0 and x1 <= sx1 and sy0 <= y0 and y1 <= sy1
            on_plate = y1 <= D

            if in_win:
                row.append(0.0)
            elif y0 >= D:
                row.append(FOOT_Z if in_foot else 0.0)
            elif in_step and on_plate:
                row.append(TOP)
            else:
                row.append(T)
        h.append(row)
    return xs, ys, h


# -------------------------------------------------------------------- mesh --
class Mesh:
    def __init__(self):
        self.tris = []

    def tri(self, a, b, c):
        self.tris.append((a, b, c))

    def quad(self, a, b, c, d):
        """Vertices counter-clockwise seen from outside."""
        self.tri(a, b, c)
        self.tri(a, c, d)


def build():
    xs, ys, h = height_field()
    nx, ny = len(xs) - 1, len(ys) - 1
    m = Mesh()

    def H(i, j):
        if 0 <= i < nx and 0 <= j < ny:
            return h[j][i]
        return 0.0

    # Every distinct column height in the part. Walls are split at each of
    # these so that two walls meeting on the same vertical line are cut
    # identically -- without this the plate's 5.00 side wall butts into the
    # foot's 12.00 side wall mid-edge and leaves a T-junction, which is a
    # crack to a slicer even though the part looks closed.
    levels = sorted({0.0} | {v for row in h for v in row})

    def bands(lo, hi):
        """[lo, hi] cut at every level it contains."""
        cuts = [z for z in levels if lo < z < hi]
        edges = [lo] + cuts + [hi]
        return list(zip(edges[:-1], edges[1:]))

    # top and bottom faces
    for j in range(ny):
        for i in range(nx):
            z = h[j][i]
            if z <= 0.0:
                continue
            x0, x1, y0, y1 = xs[i], xs[i + 1], ys[j], ys[j + 1]
            m.quad((x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z))       # +Z
            m.quad((x0, y0, 0.0), (x0, y1, 0.0), (x1, y1, 0.0), (x1, y0, 0.0))  # -Z

    # walls on every X-normal cell boundary, including the outside
    for j in range(ny):
        for i in range(nx + 1):
            a, b = H(i - 1, j), H(i, j)     # left column, right column
            if a == b:
                continue
            x, y0, y1 = xs[i], ys[j], ys[j + 1]
            for lo, hi in bands(min(a, b), max(a, b)):
                if a > b:                   # material on the left, face +X
                    m.quad((x, y0, lo), (x, y1, lo), (x, y1, hi), (x, y0, hi))
                else:                       # material on the right, face -X
                    m.quad((x, y0, lo), (x, y0, hi), (x, y1, hi), (x, y1, lo))

    # walls on every Y-normal cell boundary
    for j in range(ny + 1):
        for i in range(nx):
            a, b = H(i, j - 1), H(i, j)     # near column, far column
            if a == b:
                continue
            y, x0, x1 = ys[j], xs[i], xs[i + 1]
            for lo, hi in bands(min(a, b), max(a, b)):
                if a > b:                   # material on the near side, face +Y
                    m.quad((x0, y, lo), (x0, y, hi), (x1, y, hi), (x1, y, lo))
                else:                       # material on the far side, face -Y
                    m.quad((x0, y, lo), (x1, y, lo), (x1, y, hi), (x0, y, hi))

    return m, (xs, ys, h)


# ------------------------------------------------------------------ audits --
def audit_manifold(tris):
    """Closed and consistently oriented iff every directed edge is used once
    and its reverse is used once."""
    used = {}
    for a, b, c in tris:
        for e in ((a, b), (b, c), (c, a)):
            used[e] = used.get(e, 0) + 1

    dup = [e for e, n in used.items() if n != 1]
    unpaired = [e for e in used if (e[1], e[0]) not in used]
    return dup, unpaired


def volume_from_mesh(tris):
    """Divergence theorem: V = 1/6 sum a . (b x c)."""
    v = 0.0
    for a, b, c in tris:
        cx = b[1] * c[2] - b[2] * c[1]
        cy = b[2] * c[0] - b[0] * c[2]
        cz = b[0] * c[1] - b[1] * c[0]
        v += a[0] * cx + a[1] * cy + a[2] * cz
    return v / 6.0


def volume_analytic(grid):
    xs, ys, h = grid
    v = 0.0
    for j in range(len(ys) - 1):
        for i in range(len(xs) - 1):
            v += (xs[i + 1] - xs[i]) * (ys[j + 1] - ys[j]) * h[j][i]
    return v


# ------------------------------------------------------------------- write --
def write_binary_stl(path, tris, header):
    with open(path, "wb") as f:
        f.write(header.encode("ascii", "replace")[:80].ljust(80, b" "))
        f.write(struct.pack("<I", len(tris)))
        for a, b, c in tris:
            ux, uy, uz = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
            vx, vy, vz = (c[0] - a[0], c[1] - a[1], c[2] - a[2])
            nx_, ny_, nz_ = (uy * vz - uz * vy,
                             uz * vx - ux * vz,
                             ux * vy - uy * vx)
            mag = (nx_ * nx_ + ny_ * ny_ + nz_ * nz_) ** 0.5 or 1.0
            f.write(struct.pack("<3f", nx_ / mag, ny_ / mag, nz_ / mag))
            for p in (a, b, c):
                f.write(struct.pack("<3f", *p))
            f.write(struct.pack("<H", 0))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--out", default="exports/spray-guide-revD.stl")
    args = ap.parse_args()

    m, grid = build()
    tris = m.tris

    dup, unpaired = audit_manifold(tris)
    v_mesh = volume_from_mesh(tris)
    v_calc = volume_analytic(grid)

    xs = [p[0] for t in tris for p in t]
    ys = [p[1] for t in tris for p in t]
    zs = [p[2] for t in tris for p in t]

    print("Studio Light spray guide — Rev D")
    print("  triangles          %d" % len(tris))
    print("  bounding box       %.2f x %.2f x %.2f mm"
          % (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
    print("  duplicate edges    %d" % len(dup))
    print("  unpaired edges     %d" % len(unpaired))
    print("  volume, mesh       %.1f mm3" % v_mesh)
    print("  volume, analytic   %.1f mm3" % v_calc)
    print("  mass at 1.24 g/cm3 %.1f g solid" % (v_calc / 1000.0 * 1.24))

    ok = not dup and not unpaired and abs(v_mesh - v_calc) < 1e-6 * max(1.0, v_calc)
    if not ok:
        print("\nAUDIT FAILED — nothing written.", file=sys.stderr)
        if dup:
            print("  edges used more than once: %r" % dup[:5], file=sys.stderr)
        if unpaired:
            print("  edges with no reverse:     %r" % unpaired[:5], file=sys.stderr)
        return 1

    write_binary_stl(args.out, tris, "WhisperRoom Studio Light spray guide Rev D - mm")
    print("\n  AUDIT PASSED — closed, orientable, watertight.")
    print("  wrote %s" % args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
