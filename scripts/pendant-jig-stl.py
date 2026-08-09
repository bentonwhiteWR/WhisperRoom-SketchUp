#!/usr/bin/env python3
"""Write the pendant curing jig straight to binary STL.

This is a second implementation of the geometry in `pendant-jig.rb`, not a
converter. SketchUp is the only thing on Benton's machine that runs Ruby, so
going through it just to export an STL means opening the app. This skips it.

THE CONSTANTS BELOW MUST MATCH `pendant-jig.rb`. They are duplicated rather
than parsed because a regex over Ruby source is a worse failure mode than a
number that disagrees loudly. `--check` diffs them against the .rb and refuses
to write if they have drifted, so the duplication cannot rot silently.

Output is in PRINT orientation: flipped socket-opening-up and dropped onto
z=0, which is how the .rb says to print it. The bed contact is the tube-guide
mouth annulus, roughly 21.5 outside and 11.3 inside. Use a brim.

    python scripts/pendant-jig-stl.py              # writes the 5-up
    python scripts/pendant-jig-stl.py --count 1    # single, for a test print
    python scripts/pendant-jig-stl.py --use        # skip the print flip

Every dimension is MILLIMETRES.
"""

import argparse
import math
import pathlib
import re
import struct
import sys

# ------------------------------------------------------------------ measured --
HOUSING_DIA   = 15.04
HOUSING_LEN   = 19.00
TUBE_DIA      =  9.65
TUBE_LEN      = 54.00

# ---------------------------------------------------------------- print fit --
CLEARANCE     =  0.25   # housing socket — fit-tested good
TUBE_CLEAR    =  0.45   # tube guide — fit-tested, was 0.25 and too tight

# ------------------------------------------------------------------- chosen --
SOCKET_DEPTH  = 11.50   # Rev C: Rev B's 6.50 did not seat deep enough
GUIDE_LEN     = 36.00
WALL          =  3.10
FLANGE_DIA    = 28.00
FLANGE_H      =  3.50
FLANGE_RELIEF =  1.50
GLUE_RELIEF_D =  1.60
GLUE_RELIEF_H =  1.50
RELIEF_W      =  0.80
RELIEF_H      =  0.80
MOUTH_CH      =  0.60

# -------------------------------------------------------------------- layout --
COUNT         =  5
PITCH         = 32.00
TIE_BAR       = True
TIE_W         = 10.00   # DEAD. Kept only so --check still finds it in the .rb.
                        # The old tie bar was one slab this wide on the axis,
                        # which plugged every flange bore — the housing had
                        # nowhere to go. Replaced by two rails, below.
TIE_CLEAR     =  0.50   # gap between the flange bore and the inner brace face
TIE_OUTER     = 13.00   # DEAD with the flat rails. Kept for the drift check.
BRACE_T       =  2.40   # brace wall thickness — 6 passes of a 0.4 nozzle
BRACE_FRAC    =  1.00   # brace height as a fraction of the part height
SEGMENTS      = 72

# The .rb constants this file duplicates, for --check.
MIRRORED = {
    "HOUSING_DIA": HOUSING_DIA, "HOUSING_LEN": HOUSING_LEN,
    "TUBE_DIA": TUBE_DIA, "TUBE_LEN": TUBE_LEN,
    "CLEARANCE": CLEARANCE, "TUBE_CLEAR": TUBE_CLEAR,
    "SOCKET_DEPTH": SOCKET_DEPTH, "GUIDE_LEN": GUIDE_LEN, "WALL": WALL,
    "FLANGE_DIA": FLANGE_DIA, "FLANGE_H": FLANGE_H,
    "FLANGE_RELIEF": FLANGE_RELIEF,
    "GLUE_RELIEF_D": GLUE_RELIEF_D, "GLUE_RELIEF_H": GLUE_RELIEF_H,
    "RELIEF_W": RELIEF_W, "RELIEF_H": RELIEF_H, "MOUTH_CH": MOUTH_CH,
    "PITCH": PITCH, "TIE_W": TIE_W, "SEGMENTS": float(SEGMENTS),
    "TIE_CLEAR": TIE_CLEAR, "TIE_OUTER": TIE_OUTER,
    "BRACE_T": BRACE_T, "BRACE_FRAC": BRACE_FRAC,
}

# ------------------------------------------------------------------- derived --
socket_dia = HOUSING_DIA + CLEARANCE
tube_bore  = TUBE_DIA + TUBE_CLEAR
body_dia   = socket_dia + 2 * WALL
total_h    = FLANGE_H + SOCKET_DEPTH + GUIDE_LEN


def flange_bore_r():
    """Radius of the hole through the flange that the housing passes into."""
    return (HOUSING_DIA + FLANGE_RELIEF) / 2.0


def bore_min_radius(z):
    """Radius the flange bore is open to at height z, in USE coordinates.

    Straight at the full bore radius up to the 45 deg lead-in, then closing
    down to the socket wall at the top of the flange.
    """
    rr = flange_bore_r()
    rh = socket_dia / 2.0
    lead = rr - rh
    knee = FLANGE_H - lead
    if z <= knee:
        return rr
    return rr - (z - knee)


def point_in_profile(r, z, prof):
    """Even-odd test of (radius, height) against the closed section polygon."""
    inside = False
    n = len(prof)
    for i in range(n):
        r1, z1 = prof[i]
        r2, z2 = prof[(i + 1) % n]
        if (z1 > z) != (z2 > z):
            xr = r1 + (z - z1) * (r2 - r1) / (z2 - z1)
            if r < xr:
                inside = not inside
    return inside


def void_radius(z, prof, margin=0.15):
    """How far out the central channel is open at height z. 0 if solid on axis."""
    r = 0.0
    while r < FLANGE_DIA:
        if point_in_profile(r, z, prof):
            return max(0.0, r - margin)
        r += 0.05
    return 0.0


def bore_obstructions(count, braces, prof):
    """Sample the whole internal channel and report anything solid inside it.

    THIS IS THE CHECK THAT WAS MISSING, and the first version of it was still
    wrong. The first Rev C STL shipped with a tie bar slab lying straight
    across all five flange bores. The per-unit watertight test passed, because
    the slab was appended after it had already run. A vertex-based test then
    also passed, because the slab's corners sit outside the bores even though
    its middle spans them — testing vertices cannot catch a plate crossing a
    hole.

    So this samples points that must be air and asks whether any solid claims
    them. The channel is found from the section itself rather than assumed, so
    it covers the flange bore, the housing socket, the glue gutter, and the
    tube guide — not just the one hole that happened to break. Solids are
    tested analytically: each unit's revolve by point-in-polygon, the braces
    as boxes. USE coordinates, before the print flip.
    """
    hits = []
    axes = [i * PITCH for i in range(count)]
    steps = 40
    for i, ax in enumerate(axes):
        for zs in range(1, steps):
            z = total_h * zs / steps
            r_max = void_radius(z, prof)
            if r_max <= 0:
                continue
            for rs in range(4):
                r = r_max * rs / 3.0
                for asteps in range(12):
                    a = 2.0 * math.pi * asteps / 12.0
                    x = ax + r * math.cos(a)
                    y = r * math.sin(a)
                    what = None
                    for j, other in enumerate(axes):
                        if j != i and point_in_profile(math.hypot(x - other, y), z, prof):
                            what = f"body of unit {j + 1}"
                            break
                    if what is None:
                        for (x0, x1, y0, y1, z0, z1) in braces:
                            if x0 <= x <= x1 and y0 <= y <= y1 and z0 <= z <= z1:
                                what = "brace"
                                break
                    if what:
                        hits.append((i + 1, round(x, 2), round(y, 2), round(z, 2), what))
    return hits


def profile():
    """Half-section as [radius, height], counter-clockwise, closed by wrapping.

    Identical to WR_PendantJig.profile. Read z with the flange at the bottom;
    the print flip happens after the mesh is built.
    """
    rf = FLANGE_DIA / 2.0
    rb = body_dia / 2.0
    rv = socket_dia / 2.0 + RELIEF_W
    rr = (HOUSING_DIA + FLANGE_RELIEF) / 2.0
    rh = socket_dia / 2.0
    rg = (tube_bore + GLUE_RELIEF_D) / 2.0
    rt = tube_bore / 2.0

    z1 = FLANGE_H
    z2 = z1 + SOCKET_DEPTH
    z3 = z2 + GLUE_RELIEF_H
    z4 = total_h

    land = FLANGE_H - (rf - rb)
    lead = rr - rh

    return [
        (rr, 0.0), (rf, 0.0), (rf, land), (rb, FLANGE_H), (rb, z4),
        (rt + MOUTH_CH, z4), (rt, z4 - MOUTH_CH), (rt, z3),
        (rg, z3), (rg, z2), (rv, z2), (rv, z2 - RELIEF_H),
        (rh, z2 - RELIEF_H), (rh, FLANGE_H), (rr, FLANGE_H - lead),
    ]


def revolve(prof, x_offset=0.0, segments=SEGMENTS):
    """Sweep the closed profile about Z. Returns a triangle list.

    Both loops wrap with %, so the last column of quads joins back to column 0
    by index and there is no seam to leak. Every radius is > 0, so the surface
    closes on itself and needs no caps.
    """
    ring = []
    for j in range(segments):
        a = 2.0 * math.pi * j / segments
        ca, sa = math.cos(a), math.sin(a)
        ring.append([(r * ca + x_offset, r * sa, z) for r, z in prof])

    tris = []
    n = len(prof)
    for i in range(n):
        i2 = (i + 1) % n
        for j in range(segments):
            j2 = (j + 1) % segments
            a, b = ring[j2][i], ring[j2][i2]
            c, d = ring[j][i2], ring[j][i]
            # Same winding as the Ruby, which was checked by signed volume.
            tris.append((a, b, c))
            tris.append((a, c, d))
    return tris


def box(x0, x1, y0, y1, z0, z1):
    """Axis-aligned box as 12 outward-wound triangles."""
    v = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
         (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    quads = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    tris = []
    for a, b, c, d in quads:
        tris.append((v[a], v[b], v[c]))
        tris.append((v[a], v[c], v[d]))
    return tris


def signed_volume(tris):
    """Sum of tetrahedron volumes to the origin. Positive means outward normals."""
    total = 0.0
    for a, b, c in tris:
        total += (a[0] * (b[1] * c[2] - b[2] * c[1])
                  - a[1] * (b[0] * c[2] - b[2] * c[0])
                  + a[2] * (b[0] * c[1] - b[1] * c[0]))
    return total / 6.0


def pappus_volume(prof):
    """2*pi*Rc*A for the revolved section — an independent number to check against."""
    n = len(prof)
    a2 = 0.0
    cr = 0.0
    for i in range(n):
        r1, z1 = prof[i]
        r2, z2 = prof[(i + 1) % n]
        x = r1 * z2 - r2 * z1
        a2 += x
        cr += (r1 + r2) * x
    if abs(a2) < 1e-9:
        return 0.0
    return 2.0 * math.pi * abs(cr / (3.0 * a2)) * abs(a2 / 2.0)


def naked_edges(tris):
    """Count edges not shared by exactly two triangles. Must be 0."""
    seen = {}
    for tri in tris:
        for i in range(3):
            p, q = tri[i], tri[(i + 1) % 3]
            key = (p, q) if p <= q else (q, p)
            seen[key] = seen.get(key, 0) + 1
    return sum(1 for c in seen.values() if c != 2)


def transform(tris, flip, dz):
    """Rotate 180 deg about X when flipping, then translate in z.

    The rotation is proper, so winding and therefore the normals survive it.
    """
    out = []
    for tri in tris:
        pts = []
        for x, y, z in tri:
            if flip:
                y, z = -y, -z
            pts.append((x, y, z + dz))
        out.append(tuple(pts))
    return out


def write_stl(path, tris, name="pendant-jig"):
    with open(path, "wb") as fh:
        fh.write(name.encode("ascii", "replace").ljust(80, b"\0")[:80])
        fh.write(struct.pack("<I", len(tris)))
        for a, b, c in tris:
            ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
            vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
            nx = uy * vz - uz * vy
            ny = uz * vx - ux * vz
            nz = ux * vy - uy * vx
            m = math.sqrt(nx * nx + ny * ny + nz * nz)
            if m > 0:
                nx, ny, nz = nx / m, ny / m, nz / m
            fh.write(struct.pack("<12fH", nx, ny, nz,
                                 a[0], a[1], a[2], b[0], b[1], b[2],
                                 c[0], c[1], c[2], 0))


def check_against_ruby(rb_path):
    """Refuse to write if this file's constants have drifted from the .rb."""
    try:
        src = pathlib.Path(rb_path).read_text(encoding="utf-8")
    except OSError as err:
        return [f"could not read {rb_path}: {err}"]
    bad = []
    for key, mine in MIRRORED.items():
        m = re.search(rf"^\s*{key}\s*=\s*(-?[\d.]+)", src, re.M)
        if not m:
            bad.append(f"{key}: not found in the .rb")
        elif abs(float(m.group(1)) - mine) > 1e-9:
            bad.append(f"{key}: .rb has {m.group(1)}, this file has {mine}")
    return bad


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--count", type=int, default=COUNT, help="units in the row")
    ap.add_argument("--out", default=None, help="output .stl path")
    ap.add_argument("--use", action="store_true",
                    help="draw in USE orientation instead of flipping for print")
    ap.add_argument("--no-tie", action="store_true", help="omit the tie bar")
    args = ap.parse_args()

    here = pathlib.Path(__file__).resolve().parent
    drift = check_against_ruby(here / "pendant-jig.rb")
    if drift:
        print("CONSTANTS HAVE DRIFTED FROM pendant-jig.rb — refusing to write:")
        for line in drift:
            print(f"    {line}")
        return 1

    count = max(1, args.count)
    prof = profile()
    flip = not args.use

    tris = []
    for i in range(count):
        tris.extend(revolve(prof, x_offset=i * PITCH))

    per_unit = len(tris) // count
    one = tris[:per_unit]
    naked = naked_edges(one)
    vol_mesh = signed_volume(one)
    vol_exact = pappus_volume(prof)

    tie = []
    rails = []
    if count > 1 and TIE_BAR and not args.no_tie:
        # TWO VERTICAL WEBS, standing on edge, full height of the part.
        #
        # Three earlier shapes were wrong or weak. One slab across the axis
        # blocked every flange bore. Two flat rails at flange height cleared
        # the bores but were 4.23 x 3.50 lying down, about 15 mm4 of second
        # moment each — a strap, not a brace. Standing the same material on
        # edge over the full 51.00 gives roughly 26500 mm4, and stiffness in
        # bending goes as the cube of depth, so this is not a small change.
        #
        # It also fixes the print. Flat rails sit at flange height, which is
        # the LAST thing printed in socket-up orientation, so the five towers
        # are unlinked for the whole build. Full-height webs tie them together
        # from the first layer.
        #
        # Inner face clears the flange bore, the widest internal feature. The
        # webs straddle the body wall, so they fuse to every unit up its
        # entire length.
        x0 = -FLANGE_DIA / 2.0
        x1 = (count - 1) * PITCH + FLANGE_DIA / 2.0
        y_in = flange_bore_r() + TIE_CLEAR
        z_top = total_h * BRACE_FRAC
        for sign in (-1.0, 1.0):
            a, b = sorted((sign * y_in, sign * (y_in + BRACE_T)))
            rails.append((x0, x1, a, b, 0.0, z_top))
            tie.extend(box(x0, x1, a, b, 0.0, z_top))
        tris.extend(tie)

    # Run this on the ASSEMBLED row, after the tie bar, before writing anything.
    blocked = bore_obstructions(count, rails, prof)
    if blocked:
        print()
        print("BORE OBSTRUCTED — refusing to write.")
        print(f"  {len(blocked)} sample points inside a flange bore are solid;")
        print("  the housing cannot enter. First few (unit, x, y, z, what):")
        for pt in blocked[:6]:
            print(f"    {pt}")
        return 1

    zs = [p[2] for tri in tris for p in tri]
    dz = max(zs) if flip else 0.0
    tris = transform(tris, flip, dz)

    name = f"pendant-jig-revC-{count}up"
    out = pathlib.Path(args.out) if args.out else here.parent / "exports" / f"{name}.stl"
    out.parent.mkdir(parents=True, exist_ok=True)
    write_stl(out, tris, name)

    xs = [p[0] for tri in tris for p in tri]
    ys = [p[1] for tri in tris for p in tri]
    zs = [p[2] for tri in tris for p in tri]

    err = 0.0 if vol_exact == 0 else 100.0 * (vol_mesh - vol_exact) / vol_exact
    print()
    print(f"PENDANT CURING JIG Rev C  —  {count} up  —  binary STL")
    print()
    print(f"  wrote        {out}")
    print(f"  triangles    {len(tris)}  ({per_unit} per unit"
          + (f" + {len(tie)} tie bar)" if tie else ")"))
    print(f"  orientation  {'PRINT (socket up, on z=0)' if flip else 'USE (standing on flange)'}")
    print()
    print("  WATERTIGHT CHECK  (one revolved unit)")
    print(f"    {naked} naked edges  — must be 0")
    print(f"    volume {vol_mesh:.1f} mm3  vs {vol_exact:.1f} exact  "
          f"({err:+.2f}% — faceting, under 0.5% is fine)")
    print("    -> closed." if naked == 0 and vol_mesh > 0
          else "    -> NOT closed. Do not slice this.")
    print()
    print("  BORE CHECK  (whole row, after the tie bar)")
    print(f"    0 obstructions — every flange bore is open to r "
          f"{flange_bore_r():.2f} for the housing")
    print()
    print("  BOUNDING BOX")
    print(f"    X {max(xs) - min(xs):7.2f}   Y {max(ys) - min(ys):7.2f}"
          f"   Z {max(zs) - min(zs):7.2f}")
    print(f"    sits on z = {min(zs):.2f}")
    print()
    if tie:
        print("  The tie bar is a SEPARATE overlapping shell, not a boolean union.")
        print("  Every slicer unions overlapping solids, so it prints as one piece,")
        print("  but the STL is deliberately not manifold as a whole. If Dremel's")
        print("  slicer complains, run --no-tie and the units come out separate.")
        print()
    print("  Print socket-opening-up, which is how this is written. Bed contact is")
    print(f"  the guide-mouth annulus, about {body_dia:.1f} outside. Use a brim.")
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
