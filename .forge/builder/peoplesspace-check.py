#!/usr/bin/env python3
"""PeoplesSpace alcove — independent arithmetic cross-check.

Checks the numbers scripts/peoplesspace-alcove.rb is built from, WITHOUT
reading the Ruby: wall-run closure, the ramp fit, and the height stack with
the 2.75 in WhisperRoom raised floor carried through.

Run:  python .forge/builder/peoplesspace-check.py
"""

FR = 1.0 / 16.0


def arch(v):
    """Inches -> architectural string, to the nearest 1/16."""
    neg = v < 0
    v = abs(v)
    ft = int(v // 12)
    rem = v - ft * 12
    inch = int(rem)
    frac = round((rem - inch) / FR)
    if frac == 16:
        inch += 1
        frac = 0
    if inch == 12:
        ft += 1
        inch = 0
    s = f"{ft}'-{inch}"
    if frac:
        n, d = frac, 16
        while n % 2 == 0:
            n //= 2
            d //= 2
        s += f" {n}/{d}"
    s += '"'
    return ("-" if neg else "") + s


fails = []


def check(label, got, want, tol=1e-9):
    ok = abs(got - want) <= tol
    print(f"  [{'ok' if ok else 'FAIL'}] {label}: {got:.4f} vs {want:.4f}  ({arch(got)})")
    if not ok:
        fails.append(label)


# ---------------------------------------------------------------- the room --
# STATED (architect fragment, all VIF) -- clients/peoplesspace/takeoff.json
W = 114.75          # 9'-6 3/4"  alcove clear width  (x, west->east)
D = 128.75          # 10'-8 3/4" alcove clear depth  (y, south concrete -> north glass)

print("ROOM (stated, VIF)")
check("alcove width  9'-6 3/4\"", W, 114.75)
check("alcove depth 10'-8 3/4\"", D, 128.75)

# --------------------------------------------------------------- the booth --
# OBSERVED: wr-booth-data.rb 'MDL 96120 E' w=122 h=98; models.json 8'-2" x 10'-2"
BW, BL = 98.0, 122.0        # x, y as placed (long axis north-south)
GAP = 1.0                   # nominal wall clearance, layout-render.js clrIn
BX0, BY0 = GAP, GAP
BX1, BY1 = BX0 + BW, BY0 + BL

print("\nPLAN CHAINS (must close on the overalls)")
check("south chain 1 | 98 | 15.75", BX0 + BW + (W - BX1), W)
check("west  chain 1 | 122 | 5.75", BY0 + BL + (D - BY1), D)
print(f"   east strip free = {W - BX1:.3f}  north strip free = {D - BY1:.3f}")

# door chains, each measured from y=0 on the booth's east (door) face
OPT = {1: (3.0, 52.0), 2: (72.0, 121.0)}       # frame near/far jamb, y
FRAME = 49.0                                    # ADA / wide-access frame width
for n, (j0, j1) in OPT.items():
    check(f"opt {n} frame width", j1 - j0, FRAME)
    segs = [BY0, j0 - BY0, j1 - j0, BY1 - j1, D - BY1]
    check(f"opt {n} east chain {' | '.join(f'{s:g}' for s in segs)}", sum(segs), D)
    print(f"        door centreline y = {(j0 + j1) / 2:.3f}  ({arch((j0 + j1) / 2)})")

# ----------------------------------------------------------------- the ramp --
RAMP = 45.625       # 3'-9 5/8" ADA ramp projection, layout-render.js RAMP_PROT (observed)
SWING = 34.5        # swing clearance for a 49" frame, layout-render.js (observed)

print("\nRAMP — does it close INSIDE the alcove? (Benton, answer 5: 'goes inwards')")
# The ramp run is perpendicular to the door face. Best case in either axis is
# the booth shoved hard into a corner, so the free strip is room minus booth.
free_x = W - BW      # 16.75
free_y = D - BL      # 6.75
print(f"  best-case free strip east  (room {W} - booth {BW}) = {free_x:.3f}")
print(f"  best-case free strip north (room {D} - booth {BL}) = {free_y:.3f}")
print(f"  ramp needs {RAMP}")
inward_ok = (free_x >= RAMP) or (free_y >= RAMP)
print(f"  INWARD RAMP FITS: {inward_ok}   short by "
      f"{RAMP - free_x:.3f} east / {RAMP - free_y:.3f} north")
if inward_ok:
    fails.append("inward ramp unexpectedly fits — re-derive")

print("\nRAMP EAST (the only arrangement that closes; east is OPEN SPACE, answer 1)")
toe = BX1 + RAMP
check("ramp toe x", toe, 144.625)
check("swing clearance line x", BX1 + SWING, 133.5)
print(f"   overrun past the alcove line = {toe - W:.3f}  ({arch(toe - W)})")

# ------------------------------------------------------------ height stack --
# STATED (architect elevation, VIF), z = 0 at LEVEL 01 FF
PIPE = 99.25        # 8'-3 1/4"  bottom of pipe
CLOUD = 113.0       # 9'-5"      acoustic cloud ceiling
STRUCT = 122.0      # 10'-2"     concrete structure
# OBSERVED
BOOTH_DRAWN = 84.3125   # 7'-0 5/16" 96120 E as drawn (dimension-booth.rb HEIGHTS)
BOOTH_CAT = 85.0        # 7'-1" catalogue install clearance (models.json)
RM_H = 10.3125          # RM96120 roof unit height (wr-roof-vent.rb, measured)
EFP = 2.75              # WhisperRoom raised floor (ADA package) -- Benton, 9 Sep 2026
PHI = 79.5              # Enhanced interior clear height (wr-booth-data.rb)

print("\nHEIGHT STACK (z = 0 at LEVEL 01 FF, all room figures VIF)")
print("  The EFP raised floor sits INSIDE the shell: wr-overlays.rb place_efp puts the")
print("  slab bottom at WR_Deck::DECK_TOP_Z (= 0.0), the plane the walls stand on. So")
print("  it does NOT lift the roof. Observed, not assumed.")
top_drawn = BOOTH_DRAWN + RM_H
top_cat = BOOTH_CAT + RM_H
check("roof unit top, drawn booth", top_drawn, 94.625)
check("roof unit top, catalogue", top_cat, 95.3125)
print(f"   MARGIN to bottom of pipe, drawn     = {PIPE - top_drawn:.4f}  ({arch(PIPE - top_drawn)})")
print(f"   MARGIN to bottom of pipe, catalogue = {PIPE - top_cat:.4f}  ({arch(PIPE - top_cat)})")
print(f"   (if the raised floor were UNDER the shell it would be "
      f"{PIPE - top_drawn - EFP:.4f} / {PIPE - top_cat - EFP:.4f} -- it is not)")
check("clear to cloud above the unit", CLOUD - top_drawn, 18.375)
check("clear to structure above the unit", STRUCT - top_drawn, 27.375)
print(f"   interior headroom over the raised floor = {PHI - EFP:.4f}  ({arch(PHI - EFP)})")

# ------------------------------------------------------------- roof unit xy --
RM_W, RM_D = 88.0, 113.5    # RM96120 as measured (wr-roof-vent.rb: 113.500 x 88.0)
print("\nROOF UNIT SEATING (centred on the nominal footprint, wr-roof-vent.rb seat)")
nom_x = BW - 2 * 1.0
nom_y = BL - 2 * 1.0
ux0 = BX0 + 1.0 + (nom_x - RM_W) / 2.0
uy0 = BY0 + 1.0 + (nom_y - RM_D) / 2.0
check("unit x0", ux0, 6.0)
check("unit x1", ux0 + RM_W, 94.0)
check("unit y0", uy0, 5.25)
check("unit y1", uy0 + RM_D, 118.75)
print(f"   unit starts {uy0:.2f} north of the concrete face; assumed pipe band is 21 deep,")
print(f"   so the unit is under it for its first {21.0 - uy0:.2f} in")

print("\n" + ("ALL CHECKS PASS" if not fails else f"FAILURES: {fails}"))
raise SystemExit(1 if fails else 0)
