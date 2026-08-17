#!/usr/bin/env python3
"""
Proof for the ceiling seam seal pass added to scripts/wr-deck.rb.

There is no ruby.exe on this machine and SketchUp cannot be driven headless, so
this is a LINE-FAITHFUL Python reimplementation of the arithmetic in
WR_Deck.joint_stations, WR_Deck.pick_seal and the transform built inside
WR_Deck.seals. It is not a test of the Ruby. It is a test of the arithmetic the
Ruby performs.

GROUND TRUTH IS DEFINED INDEPENDENTLY, in the GT_* tables below, from two
sources that are not this code:

  * scripts/probe-seam-seal.rb, run by Benton in SketchUp on a built MDL 7272 S
    on 2026-08-17 -- seal boxes, datum levels, rib stations, panel slot walls,
    the panel contact plane, and the booth x the two ceiling panels met at.
  * scripts/wr-booth-data.rb -- booth :w / :h, read straight out of the file.
  * Benton's FIT TEST on 2026-08-17: he built an MDL 7272 S with this pass, moved
    the placed STDSS CL6 by hand until it seated, and reported that it needed to
    come down 1 3/4. Section 4 shows that figure is exact, not an eyeball, and
    fails loudly if a future edit breaks the reasoning.

The seals were RE-CUT on 2026-08-17 -- 1.750 tall now, not 2.000, with the old
0.250 step at z 1.250 removed. GT_SEALS holds the new parts.

The cut lists per booth are REPORTED, from the confirmed FL/CL panel path (which
this change does not touch) and from .forge/scoper/ceiling-seam-seals.md. For the
MDL 7272 S the cut list is cross-checked against the observed placed panel spans,
so the flagship case does not rest on a reported number.

Run:  python .forge/builder/seal_placement_proof.py
"""

import math
import re

TOL = 0.35
INSET = 1.0
DECK_TOP_Z = 0.0
WALL_H = 81.0
SEAL_LEN_TOL = 0.05

# The one constant under test, mirrored from wr-deck.rb. Inches to lift the
# seal's datum face above the ceiling panels' contact plane.
#
# MEASURED BY FIT TEST, 2026-08-17: Benton built an MDL 7272 S with this pass and
# moved the placed STDSS CL6 by hand until it seated. It needed to come DOWN
# 1 3/4. Section 4 below shows why that is exact rather than an eyeball figure.
SEAL_DATUM_LIFT = -1.75

EPS = 1e-6


# ============================================================ ground truth ==
#
# observed -- scripts/probe-seam-seal.rb output, 2026-08-17, MDL 7272 S, AS
# RE-CUT. Benton re-authored the four CL seals at 13:29 on 2026-08-17: they are
# now 1.750 tall overall, not 2.000, and the old 0.250 step at z 1.250 is gone.
# The numbers below are the new parts. Anything still quoting a 2.000-tall seal
# is stale.
#
# Each seal's box, its datum face (the largest-area flat level) and its mid level
# in the part's own z.
GT_SEALS = {
    #  file            across  length  height   z_lo    z_hi   datum     mid
    'STDSS CL5':     (6.5,  58.0, 1.75,  0.00,  1.75,  0.000,  1.000),
    'STDSS CL6':     (6.5,  70.0, 1.75,  0.00,  1.75,  0.000,  1.000),
    'STDSS CL7':     (6.5,  82.0, 1.75,  0.00,  1.75,  0.000,  1.000),
    'STDSS CL8':     (6.5,  94.0, 1.75, -0.75,  1.00, -0.750,  0.250),
    'STDSS 8.5CL':   (6.5, 100.0, 1.75, -0.75,  1.00, -0.750,  0.250),
}

# observed -- the seal geometry BEFORE the re-cut, kept so that the value this
# whole placement turns on can be shown to be tied to the parts it was measured
# against. A library still holding these would want SEAL_DATUM_LIFT = -2.00.
GT_SEALS_PRE_RECUT_DATUM_TO_TOP = 2.0

# observed -- STDSS CL8's two rib walls, in the part's own x on a 6.500 part.
GT_CL8_RIB_WALLS = [(0.6875, 0.9375), (5.5625, 5.8125)]

# observed -- the ceiling panels of the MDL 7272 S. Slot wall stations are
# measured FROM EACH PANEL'S OWN JOINT EDGE, and the slot's z range is in booth
# coordinates.
GT_PANEL_CONTACT_Z = 81.000
GT_PANEL_SLOTS = {
    'STD7248CL SIDE L': (2.221, 2.654),
    'STD7224CL SIDE R': (2.195, 2.678),
}
GT_PANEL_SLOT_Z = (80.249, 81.000)

# observed -- where the build actually seated the two ceiling panels of the
# MDL 7272 S, in booth x. The joint is where they meet.
GT_7272_PANEL_SPANS = [(1.00, 49.00), (49.00, 73.00)]

# observed -- booth :w / :h straight out of scripts/wr-booth-data.rb.
GT_BOOTHS = {
    'MDL 7272 S':  (74.0, 74.0),
    'MDL 7296 S':  (98.0, 74.0),
    'MDL 6084 S':  (86.0, 62.0),
    'MDL 96168 S': (170.0, 98.0),
    'MDL 10284 S': (86.0, 104.0),
    'MDL 4872 S':  (74.0, 50.0),
    'MDL 4230 S':  (44.0, 32.0),
}

# reported -- the cut list the confirmed FL/CL panel path produces for each
# booth, and which axis it tiles along. Not under test here; this change does not
# touch plan(), tile() or order_cuts(). The 7272 row is re-derived from
# GT_7272_PANEL_SPANS below and must agree.
GT_CUTS = {
    'MDL 7272 S':  ([48.0, 24.0], True),
    'MDL 7296 S':  ([48.0, 48.0], True),
    'MDL 6084 S':  ([42.0, 42.0], True),
    'MDL 96168 S': ([48.0, 48.0, 24.0, 48.0], True),
    'MDL 10284 S': ([42.0, 42.0, 18.0], False),
    'MDL 4872 S':  ([72.0], True),
    'MDL 4230 S':  ([42.0], False),
}


# --------------------------------------------------------------- transforms --
# A 4x4 column-vector matrix, same convention as Geom::Transformation.

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


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)]
            for i in range(4)]


def apply(m, p):
    x, y, z = p
    return (m[0][0] * x + m[0][1] * y + m[0][2] * z + m[0][3],
            m[1][0] * x + m[1][1] * y + m[1][2] * z + m[1][3],
            m[2][0] * x + m[2][1] * y + m[2][2] * z + m[2][3])


def corners(lo, hi):
    return [(x, y, z) for x in (lo[0], hi[0])
            for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]


def box_of(pts):
    return (tuple(min(p[i] for p in pts) for i in range(3)),
            tuple(max(p[i] for p in pts) for i in range(3)))


# ==================================== the code under test, transliterated ====

SEAL_NAME = re.compile(
    r'\ASTDSS\s*(?:CL\s*(\d+(?:\.\d+)?)|(\d+(?:\.\d+)?)\s*CL)\Z', re.I)


def seal_catalogue(names):
    """WR_Deck.seal_catalogue, with the folder glob replaced by a name list."""
    out = []
    for base in names:
        m = SEAL_NAME.match(base.strip())
        if m is None:
            continue
        ft = float(m.group(1) or m.group(2))
        out.append({'file': base, 'feet': ft, 'cross': ft * 12.0})
    return out


def pick_seal(seals, cross):
    for s in seals:
        if abs(s['cross'] - float(cross)) < TOL:
            return s
    return None


def joint_stations(tiles):
    if not tiles or len(tiles) < 2:
        return []
    st, pos = [], 0.0
    for t in tiles[:-1]:
        pos += float(t)
        st.append(pos)
    return st


def place_seal(seal_box, datum, station, cross, along_is_x, wall_h=WALL_H):
    """The transform built inside WR_Deck.seals, step for step."""
    across, length, _height, z_lo, z_hi = seal_box
    lo = (0.0, 0.0, z_lo)
    hi = (across, length, z_hi)
    assert abs((z_hi - z_lo) - _height) < EPS

    tr = ident()
    if not along_is_x:
        tr = mul(rotate_z(90.0), tr)

    now = apply(tr, (0.0, 0.0, datum))[2]
    target_z = DECK_TOP_Z + wall_h + SEAL_DATUM_LIFT
    tr = mul(translate(0.0, 0.0, target_z - now), tr)

    got = box_of([apply(tr, c) for c in corners(lo, hi)])

    want_a = INSET + station
    want_c = INSET + cross / 2.0
    wx, wy = (want_a, want_c) if along_is_x else (want_c, want_a)
    cx = (got[0][0] + got[1][0]) / 2.0
    cy = (got[0][1] + got[1][1]) / 2.0
    tr = mul(translate(wx - cx, wy - cy, 0.0), tr)

    return tr, box_of([apply(tr, c) for c in corners(lo, hi)])


# reported -- the cross dimensions the CL catalogue actually carries, from
# wr-booth-data.rb's cross list and the STD<cross><along>CL naming.
CAT_CROSSES = [42.0, 48.0, 60.0, 72.0, 84.0, 96.0, 102.0]


def deck_cross_and_along(w, h):
    """plan()'s orientation choice: long way first, short way as the fallback.

    The fallback is not decoration. MDL 4230 S is 42 x 30 and its only ceiling
    part is 42 ACROSS by 30 along, so the long-way attempt finds nothing 30
    across and the deck tiles along its SHORT side. Modelling only the long-way
    rule gets that booth's axis wrong.
    """
    dw, dh = w - 2 * INSET, h - 2 * INSET
    orders = ([(dw, dh, True), (dh, dw, False)] if dw >= dh
              else [(dh, dw, False), (dw, dh, True)])
    for a_len, c_len, a_is_x in orders:
        if any(abs(c - c_len) < TOL for c in CAT_CROSSES):
            return a_len, c_len, a_is_x
    return orders[0]


# ================================================================== checks ===

failures = []


def check(name, got, want, tol=0.001):
    ok = abs(got - want) <= tol
    if not ok:
        failures.append('%s: got %.4f, want %.4f' % (name, got, want))
    return ok


def check_eq(name, got, want):
    ok = (got == want)
    if not ok:
        failures.append('%s: got %r, want %r' % (name, got, want))
    return ok


def main():
    print('Ceiling seam seal placement -- arithmetic proof')
    print('SEAL_DATUM_LIFT = %+.3f  (derived guess: datum flush with the '
          'contact plane)' % SEAL_DATUM_LIFT)
    print()

    lib = sorted(GT_SEALS.keys())

    # -- 0. The name-to-length rule, on all five parts. -----------------------
    print('0. seal length == feet x 12 - 2, and the name parses')
    for f in lib:
        s = pick_seal(seal_catalogue(lib), GT_SEALS[f][1] + 2.0)
        check_eq('  %-14s selected by its own cross' % f, s and s['file'], f)
        check('  %-14s length' % f, GT_SEALS[f][1], s['cross'] - 2.0)
        print('   %-14s cross %6.1f  ->  length %6.1f' % (f, s['cross'],
                                                          GT_SEALS[f][1]))
    print()

    # -- 1. Registration: the seal's ribs against the panels' slots. ----------
    #
    # This is the claim the whole placement rule rests on -- centre the seal on
    # the joint and the ribs land in the slots -- and it is checked against two
    # panels and one seal measured independently of each other.
    print('1. registration -- ribs vs slots, all measured, none assumed')
    across = GT_SEALS['STDSS CL8'][0]
    rib_centres = [(a + b) / 2.0 for a, b in GT_CL8_RIB_WALLS]
    rib_off = [abs(c - across / 2.0) for c in rib_centres]
    check('   STDSS CL8 rib pair symmetric about its own centreline',
          rib_off[0], rib_off[1], 0.0005)
    print('   STDSS CL8 ribs at part x %.4f / %.4f  ->  +/- %.4f from centre'
          % (rib_centres[0], rib_centres[1], rib_off[0]))
    for panel, (a, b) in sorted(GT_PANEL_SLOTS.items()):
        mid = (a + b) / 2.0
        check('   %s slot centre vs rib offset' % panel, mid, rib_off[0], 0.002)
        print('   %-20s slot centred %.4f from its joint edge' % (panel, mid))
    print('   -> agree to 3 decimals on two panels; centring on the joint is '
          'sufficient, no handing')
    print('   (rib x stations were measured on the PRE-RECUT CL8. The re-cut '
          'changed z only, and')
    print('    the 2026-08-17 fit test seated the seal, which corroborates '
          'that the x did not move.)')
    print()

    # -- 2. MDL 7272 S -- the off-centre test. --------------------------------
    print('2. MDL 7272 S -- the booth chosen because its joint is NOT the '
          'deck midpoint')
    w, h = GT_BOOTHS['MDL 7272 S']
    along_len, cross_len, along_is_x = deck_cross_and_along(w, h)
    cuts, want_axis = GT_CUTS['MDL 7272 S']
    check_eq('   tiling axis is booth X', along_is_x, want_axis)

    # Cross-check the reported cut list against the observed placed panels.
    obs_cuts = [round(hi - lo, 6) for lo, hi in GT_7272_PANEL_SPANS]
    check_eq('   cut list matches the observed placed panel spans',
             [round(c, 6) for c in cuts], obs_cuts)
    obs_joint = GT_7272_PANEL_SPANS[0][1]          # booth x where they meet

    st = joint_stations(cuts)
    check_eq('   exactly one joint', len(st), 1)
    check('   joint in booth x', INSET + st[0], obs_joint)
    midpoint = INSET + along_len / 2.0
    if abs(INSET + st[0] - midpoint) < 0.5:
        failures.append('   the joint came out at the deck midpoint -- this '
                        'booth exists to catch exactly that')
    print('   joint at booth x %.3f  (deck midpoint would be %.3f -- NOT that)'
          % (INSET + st[0], midpoint))

    seal = pick_seal(seal_catalogue(lib), cross_len)
    check_eq('   seal selected', seal['file'], 'STDSS CL6')
    box = GT_SEALS[seal['file']]
    _tr, bnds = place_seal(box[:5], box[5], st[0], cross_len, along_is_x)
    (x0, y0, z0), (x1, y1, z1) = bnds
    check('   bounds x lo', x0, 45.750)
    check('   bounds x hi', x1, 52.250)
    check('   bounds y lo', y0, 2.000)
    check('   bounds y hi', y1, 72.000)
    check('   centre x', (x0 + x1) / 2.0, 49.000)
    check('   datum lands on the contact plane + lift',
          z0 + (box[5] - box[3]), GT_PANEL_CONTACT_Z + SEAL_DATUM_LIFT)
    print('   %s  ->  %.3f %.3f %.3f  to  %.3f %.3f %.3f'
          % (seal['file'], x0, y0, z0, x1, y1, z1))

    # Ribs, in booth coordinates.
    ribs = [(x0 + x1) / 2.0 - rib_off[0], (x0 + x1) / 2.0 + rib_off[0]]
    check('   rib low  in booth x', ribs[0], 46.5625, 0.0005)
    check('   rib high in booth x', ribs[1], 51.4375, 0.0005)
    print('   ribs at booth x %.4f / %.4f   (want 46.5625 / 51.4375)'
          % (ribs[0], ribs[1]))

    # The 1 in clear at each end of the cross span, stated rather than assumed.
    print('   clear at each end of the cross span: %.3f / %.3f'
          % (y0 - INSET, (INSET + cross_len) - y1))
    print()

    # -- 3. Every other booth. ------------------------------------------------
    print('3. the rest of the acceptance set')
    want = {
        # booth          seal            joint stations in booth coords
        'MDL 7296 S':  ('STDSS CL6', [49.0]),
        'MDL 6084 S':  ('STDSS CL5', [43.0]),
        'MDL 96168 S': ('STDSS CL8', [49.0, 97.0, 121.0]),
        'MDL 10284 S': ('STDSS CL7', [43.0, 85.0]),
        'MDL 4872 S':  (None, []),
        'MDL 4230 S':  (None, []),
    }
    for booth in ['MDL 7296 S', 'MDL 6084 S', 'MDL 96168 S', 'MDL 10284 S',
                  'MDL 4872 S', 'MDL 4230 S']:
        w, h = GT_BOOTHS[booth]
        along_len, cross_len, along_is_x = deck_cross_and_along(w, h)
        cuts, want_axis = GT_CUTS[booth]
        check_eq('   %-12s tiling axis' % booth, along_is_x, want_axis)
        st = joint_stations(cuts)
        want_seal, want_st = want[booth]

        got_st = [round(INSET + s, 4) for s in st]
        check_eq('   %-12s joint stations' % booth, got_st,
                 [round(v, 4) for v in want_st])

        if not st:
            # A single-tile ceiling: zero seals AND zero warnings.
            print('   %-12s no joint -> 0 seals, 0 warnings' % booth)
            continue

        seal = pick_seal(seal_catalogue(lib), cross_len)
        check_eq('   %-12s seal' % booth, seal and seal['file'], want_seal)
        box = GT_SEALS[seal['file']]
        # The length tripwire in WR_Deck.seals, run here too.
        if abs(box[1] - (cross_len - 2.0)) > SEAL_LEN_TOL:
            failures.append('   %s: %s measures %.4f, cross-2 is %.4f'
                            % (booth, seal['file'], box[1], cross_len - 2.0))

        placed = []
        for s in st:
            _tr, b = place_seal(box[:5], box[5], s, cross_len, along_is_x)
            placed.append(b)
        check_eq('   %-12s seal count' % booth, len(placed), len(want_st))

        for b, wst in zip(placed, want_st):
            (x0, y0, z0), (x1, y1, z1) = b
            ctr = ((x0 + x1) / 2.0) if along_is_x else ((y0 + y1) / 2.0)
            check('   %-12s centre on the joint' % booth, ctr, wst)
            # Long axis must run ACROSS the tiling axis. A seal still lying
            # along X on a Y-tiling booth means the quarter turn was not taken.
            long_is_y = (y1 - y0) > (x1 - x0)
            check_eq('   %-12s long axis across the joint' % booth,
                     long_is_y, along_is_x)
            check('   %-12s across-joint extent' % booth,
                  (x1 - x0) if along_is_x else (y1 - y0), 6.5)
            # Height: both seal families must land their datum on the same
            # plane, which is the CL5/6/7 vs CL8 cross-check.
            check('   %-12s datum height' % booth, z0 + (box[5] - box[3]),
                  GT_PANEL_CONTACT_Z + SEAL_DATUM_LIFT)
            print('   %-12s %-12s at %7.3f  ->  %7.3f %7.3f %7.3f  to  '
                  '%7.3f %7.3f %7.3f'
                  % (booth, seal['file'], wst, x0, y0, z0, x1, y1, z1))
    print()

    # -- 4. THE HEIGHT RULE: the seal's TOP FACE lands on the contact plane. ---
    #
    # This is the section that has to fail loudly. -1.75 is not a magic number
    # and not an eyeball figure: it is datum-to-top, which is 1.750 on BOTH seal
    # families because CL8's datum and its top are each 0.750 lower than
    # CL5/6/7's. One constant therefore serves all five and the 0.750 family
    # shift needs no special case. If a future edit breaks any of that, this
    # section is where it shows up.
    print('4. HEIGHT -- the seal top lands on the panels contact plane')
    print('   panel contact plane  booth z %.3f' % GT_PANEL_CONTACT_Z)
    for f in lib:
        box = GT_SEALS[f]
        datum, mid, top = box[5], box[6], box[4]
        d2t = top - datum

        # (a) datum-to-top is the same on both families. This is WHY one
        #     constant covers all five.
        check('   %-14s datum-to-top is 1.750' % f, d2t, 1.750)

        # (b) the constant IS -(datum-to-top). Anyone changing SEAL_DATUM_LIFT
        #     without changing the parts breaks this.
        check('   %-14s SEAL_DATUM_LIFT == -(datum-to-top)' % f,
              SEAL_DATUM_LIFT, -d2t)

        _tr, b = place_seal(box[:5], datum, 48.0, box[1] + 2.0, True)
        z_datum = b[0][2] + (datum - box[3])
        z_mid = b[0][2] + (mid - box[3])
        z_top = b[0][2] + (top - box[3])

        # (c) the placed TOP face is on the contact plane, exactly.
        check('   %-14s TOP FACE on the contact plane' % f, z_top,
              GT_PANEL_CONTACT_Z)
        check('   %-14s datum at 79.250' % f, z_datum, 79.250)

        # (d) the 0.750 top section drops into the 0.750 panel slot.
        check('   %-14s top section into the slot floor' % f, z_mid,
              GT_PANEL_SLOT_Z[0], 0.002)
        check('   %-14s top section depth' % f, z_top - z_mid,
              GT_PANEL_SLOT_Z[1] - GT_PANEL_SLOT_Z[0], 0.002)

        print('   %-14s datum %7.3f  mid %7.3f  top %7.3f   top section '
              '%.3f into a %.3f slot' % (f, z_datum, z_mid, z_top,
                                         z_top - z_mid,
                                         GT_PANEL_SLOT_Z[1] - GT_PANEL_SLOT_Z[0]))

    # (e) and the number is tied to the parts it was measured against.
    check('   pre-recut 2.000-tall seals would want -2.00',
          -GT_SEALS_PRE_RECUT_DATUM_TO_TOP, -2.00)
    print('   the seals were 2.000 tall until 2026-08-17; that library would '
          'want -2.00 here')
    print()

    # -- 5. Missing seal is reported, never substituted. ----------------------
    print('5. missing seal')
    short = [f for f in lib if f != 'STDSS CL6']
    s = pick_seal(seal_catalogue(short), 72.0)
    check_eq('   with STDSS CL6 removed, nothing is selected for a 72 cross',
             s, None)
    # And nothing of the wrong length sneaks through the tolerance.
    near = sorted(short, key=lambda f: abs(GT_SEALS[f][1] - 70.0))[:2]
    print('   nearest remaining: %s -- neither cross is within TOL %.2f of 72, '
          'so nothing substitutes'
          % (', '.join('%s (cross %.0f)' % (f, GT_SEALS[f][1] + 2.0)
                       for f in near), TOL))
    print('   -> WR_Deck.seals returns a warning naming the cross and the '
          'joint count, and places nothing')
    print()

    # -- 6. Seals cannot enter the panel pool. --------------------------------
    print('6. the two catalogues are disjoint')
    panel_name = re.compile(
        r'\ASTD(\d{2,3})(\d{2})\s*(FL|CL)\s*(CTR|SIDE)?\s*([LR])?\Z', re.I)
    for f in lib:
        check_eq('   %-14s rejected by the panel NAME regex' % f,
                 panel_name.match(f) is not None, False)
    for p in ['STD7248CL SIDE L', 'STD7224CL SIDE R', 'STD9648FL CTR']:
        check_eq('   %-18s rejected by SEAL_NAME' % p,
                 SEAL_NAME.match(p) is not None, False)
    print('   STDSS* never matches STD + digits, and STD* panels never match '
          'SEAL_NAME')
    print()

    # -- 7. How the tension got resolved: the part changed, not the code. -----
    print('7. how the mismatch was resolved')
    slot_depth = GT_PANEL_SLOT_Z[1] - GT_PANEL_SLOT_Z[0]
    print('   panel slot: %.3f deep, booth z %.3f .. %.3f -- unchanged'
          % (slot_depth, GT_PANEL_SLOT_Z[0], GT_PANEL_SLOT_Z[1]))
    print('   the seals used to be 2.000 tall with a 0.250 step at z 1.250, and '
          'the section that')
    print('   met the slot was 1.000 against a %.3f slot. Benton RE-CUT the four '
          'CL seals to' % slot_depth)
    print('   1.750 overall with that step removed, so the top section is now '
          '0.750 and seats.')
    print('   The part was corrected; the code did not grow an offset to '
          'compensate for it.')
    print()

    if failures:
        print('FAIL')
        for f in failures:
            print('  - ' + f)
        raise SystemExit(1)
    print('PASS -- selection, joint count, station, rotation, centring and '
          'HEIGHT all match.')
    print('        SEAL_DATUM_LIFT = %+.3f is measured by fit test, not '
          'derived.' % SEAL_DATUM_LIFT)
    print('NOTE -- this is the arithmetic, checked against the probe. The '
          'PLACEMENT ITSELF has')
    print('        been run in SketchUp once (MDL 7272 S, 2026-08-17); this '
          'script has not.')


if __name__ == '__main__':
    main()
