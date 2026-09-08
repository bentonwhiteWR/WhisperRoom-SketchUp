# -*- coding: utf-8 -*-
"""Offline pins for the 2026-08-28 part-orientation fixes. No SketchUp, no Ruby.

    python scripts/rbtest-part-orientation.py

Three defects Benton reported off freshly built booths, three pure-logic rules,
one harness. Nothing here executes the plugin - each rule is TRANSCRIBED from
the file under test and the transcription is named next to it, so a divergence
between the two is a real risk and is stated in the report rather than hidden.

  1. STANDARD CEILING HALF TURN - wr-deck.rb, the `t[:edge]` mirror.
     Driven by the MEASURED bracket-edge fractions in the component library's
     own `_face-levels.tsv`. The fixture below is a verbatim copy of the
     `bracket_edge` column for every Standard SIDE deck part; when the P: share
     is reachable the fixture is CROSS-CHECKED against it and a disagreement
     FAILS. It is never silently trusted and never silently skipped.

  2. SIDE WALL ORDER - the 2026-08-28 40/16 swap (swap_side_wall) is GONE
     from gen-booth.py since 1.19.10: Benton's 2026-09-02 ruling puts the
     wide panel at the door end on every split-run model, which is what the
     plain S->N walk already produces. This section pins that the predicate
     stays gone and that NO side wall in the GENERATED wr-booth-data.rb
     carries a reversed slot order any more. The end-to-end pin (both build
     paths, every key) is scripts/rbtest-side-wall-order.py.

  3. THE DUCT COVER FACE SIGN - wr-overlays.rb FACE_ROOM[:duct], read out of
     the source. It is a one-constant fact and it is pinned as one.

THE POINT OF 1 AND 2 IS THE REGRESSION BOUNDARY. Benton: "84 series, 96 series,
102 series are all FINE. Do not touch them." Both rules are asserted to leave
those series bit-identical, which is the only part of this that can be proved
without a build.
"""
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

FAILS = []
CHECKS = [0]


def ck(label, got, want):
    CHECKS[0] += 1
    if got != want:
        FAILS.append('%s\n      got  %r\n      want %r' % (label, got, want))


# ---------------------------------------------------------------------------
# 1. THE STANDARD CEILING HALF TURN
# ---------------------------------------------------------------------------
#
# OBSERVED. `bracket_edge` column of P:\Sketchup\NewMasterComponentList\
# _face-levels.tsv, written 2026-08-26 by scripts/probe-levels.rb over all 370
# parts. A blank cell means the part yields no cue - every convention-A ceiling
# is blank, because it carries nothing above its rim to measure.
#
# hand is the L/R letter off the FILE NAME, which is what wr-deck's catalogue()
# parses and what the fix keys on.
MEASURED = {
    # part                 twin FL part          fl_edge   hand
    'STD6018CL SIDE R':   ('STD6018FL SIDE R',   0.2156,   'R'),
    'STD6042CL SIDE L':   ('STD6042FL SIDE L',   0.4301,   'L'),
    'STD6042CL SIDE R':   ('STD6042FL SIDE R',   0.4301,   'R'),
    'STD7224CL SIDE R':   ('STD7224FL SIDE R',   0.7823,   'R'),
    'STD7248CL SIDE L':   ('STD7248FL SIDE L',   0.2612,   'L'),
    'STD7248CL SIDE R':   ('STD7248FL SIDE R',   0.2612,   'R'),
    'STD8442CL SIDE':     ('STD8442FL SIDE',     0.2660,   ''),
    'STD9648CL SIDE':     ('STD9648FL SIDE',     0.7366,   ''),
    'STD10242CL SIDE':    ('STD10242FL SIDE',    0.2401,   ''),
}

# The ceiling parts that carry a cue of their OWN. Only one does: STD9648CL
# SIDE is convention B - authored the same way up as a floor, hardware above
# its rim - and it reads 0.7366, identical to its floor twin to four decimals.
# Every other Standard ceiling is convention A and measures nothing.
OWN_CUE = {'STD9648CL SIDE': 0.7366}

SYMMETRIC = 0.08          # wr-deck.rb SYMMETRIC


def bracket_edge(raw):
    """wr-deck.rb bracket_edge's last two lines: a reading within SYMMETRIC of
    the middle is no reading at all."""
    if raw is None:
        return None
    return None if abs(raw - 0.5) < SYMMETRIC else raw


def edge_for(part, mirror_handed):
    """wr-deck.rb build()'s `t[:edge]`, transcribed.

    mirror_handed False is the fix: a HANDED part's twin fraction is used as
    measured. True is the behaviour before 2026-08-28, kept so the test can
    show exactly what moved."""
    own = bracket_edge(OWN_CUE.get(part))
    if own is not None:
        return own
    twin_file, raw, hand = MEASURED[part]
    e = bracket_edge(raw)
    if e is None:
        return None
    handed = hand != ''
    if mirror_handed or not handed:
        return 1.0 - e            # kind == 'CL' on every part in this table
    return e


def half(edge, at_low_end):
    """wr-deck.rb build()'s `half`. True means a 180 turn in plan."""
    if edge is None:
        return not at_low_end
    return edge > 0.5 if at_low_end else edge < 0.5


def check_tsv_fixture(report):
    """Cross-check MEASURED against the live probe output when P: is up.

    NOT a silent fallback: an unreachable share is REPORTED as an unverified
    fixture, and a disagreement is a hard failure."""
    tsv = r'P:\Sketchup\NewMasterComponentList\_face-levels.tsv'
    if not os.path.isfile(tsv):
        report.append('  fixture NOT cross-checked - %s unreachable from this '
                      'machine. The values above are a transcription and are '
                      'unverified this run.' % tsv)
        return
    seen = {}
    with io.open(tsv, encoding='utf-8', errors='replace') as f:
        head = f.readline().rstrip('\n').split('\t')
        icol = head.index('bracket_edge')
        for line in f:
            row = line.rstrip('\n').split('\t')
            if len(row) <= icol:
                continue
            v = row[icol].strip()
            seen[row[0]] = float(v) if v else None
    n = 0
    for part, (twin, raw, _hand) in sorted(MEASURED.items()):
        for name, want in ((twin, raw), (part, OWN_CUE.get(part))):
            if name not in seen:
                FAILS.append('fixture: %s is not in %s at all' % (name, tsv))
                continue
            got = seen[name]
            n += 1
            if want is None:
                if got is not None:
                    FAILS.append('fixture: %s reads %.4f in the TSV but the '
                                 'fixture says it has no cue' % (name, got))
            elif got is None or abs(got - want) > 0.0001:
                FAILS.append('fixture: %s reads %r in the TSV, fixture says %r'
                             % (name, got, want))
    report.append('  fixture cross-checked against the live probe output: '
                  '%d value(s) agree' % n)


def test_ceilings():
    out = ['STANDARD CEILING HALF TURN - wr-deck.rb `t[:edge]`',
           '  edge fractions are MEASURED (probe-levels.rb over the real parts);',
           '  0.0 = brackets at the part\'s low edge, 1.0 = its high edge.',
           '']
    check_tsv_fixture(out)
    out.append('')
    out.append('    %-20s %-6s %8s %8s   %-13s %-13s' %
               ('part', 'hand', 'was', 'now', 'half @ low', 'half @ high'))

    moved, held = [], []
    for part in sorted(MEASURED):
        hand = MEASURED[part][2]
        old = edge_for(part, mirror_handed=True)
        new = edge_for(part, mirror_handed=False)
        ol, nl = half(old, True), half(new, True)
        oh, nh = half(old, False), half(new, False)
        turned = (ol != nl) or (oh != nh)
        (moved if turned else held).append(part)
        out.append('    %-20s %-6s %8s %8s   %-13s %-13s%s' %
                   (part, hand or '-',
                    '-' if old is None else '%.4f' % old,
                    '-' if new is None else '%.4f' % new,
                    '%s -> %s' % (ol, nl), '%s -> %s' % (oh, nh),
                    '   MOVED' if turned else ''))

    # ---- what Benton reported, one assertion each -------------------------
    #
    # "the standard ceilings had the hinges in the center, not the outside. So
    #  those need to be rotated 180 degrees" - 7296 E/S, 7272 S/E
    # "only the 6018 CL side is flipped the wrong way" - MDL 6060
    ck('the five handed ceiling tiles Benton reported must all turn over',
       sorted(moved),
       ['STD6018CL SIDE R', 'STD7224CL SIDE R',
        'STD7248CL SIDE L', 'STD7248CL SIDE R'])

    # STD6042CL is handed but its floor twins measure 0.4301 - inside
    # SYMMETRIC, so no cue, so the positional rule, so nothing to move. Benton
    # reports the 6060's 6042 side and the whole 6084 ceiling correct today.
    for part in ('STD6042CL SIDE L', 'STD6042CL SIDE R'):
        ck('%s has no cue either way (its twins are mirror-identical)' % part,
           (edge_for(part, True), edge_for(part, False)), (None, None))

    # ---- THE REGRESSION BOUNDARY -----------------------------------------
    #
    # Benton: "84 series, 96 series, 102 series are all FINE. Do not touch
    # them." None of those parts carries a hand, so the fix cannot reach them.
    # This asserts it on the values rather than on the argument.
    for part in ('STD8442CL SIDE', 'STD9648CL SIDE', 'STD10242CL SIDE'):
        ck('%s: 84/96/102 must not move' % part,
           edge_for(part, True), edge_for(part, False))
        ck('%s: and neither must its turn, at either end' % part,
           (half(edge_for(part, True), True), half(edge_for(part, True), False)),
           (half(edge_for(part, False), True), half(edge_for(part, False), False)))
    ck('no unhanded part is in the moved list',
       [p for p in moved if MEASURED[p][2] == ''], [])

    # The rule the whole thing rests on: brackets end up OUTBOARD. After the
    # fix, every tile's final bracket fraction must be on its own outer half.
    for part in sorted(MEASURED):
        e = edge_for(part, False)
        if e is None:
            continue
        for at_low in (True, False):
            final = 1.0 - e if half(e, at_low) else e
            ck('%s at the %s end lands its brackets outboard'
               % (part, 'low' if at_low else 'high'),
               final < 0.5 if at_low else final > 0.5, True)

    out.append('')
    out.append('  MOVED: %s' % ', '.join(moved))
    out.append('  HELD : %s' % ', '.join(held))
    return out


# ---------------------------------------------------------------------------
# 2. SIDE WALL ORDER
# ---------------------------------------------------------------------------

def test_swap_predicate():
    """The 40/16 positional swap must stay out of the generator.

    1.7.10 added SWAP_TWO_PANEL_SIDE_WALL / swap_side_wall to reverse the
    slot->position pairing on the 6060 / 6084 side walls. 1.19.10 removed it
    on Benton's 2 Sep ruling; an id-keyed ASSIGN and a position-keyed
    generator can never agree across both families, so position has exactly
    one owner - the generator's plain walk - and no swap step at all.
    """
    src = io.open(os.path.join(HERE, 'gen-booth.py'), encoding='utf-8').read()
    code = '\n'.join(l for l in src.splitlines() if not l.lstrip().startswith('#'))
    out = ['SIDE WALL ORDER - gen-booth.py carries no positional swap', '']
    for token in ('SWAP_TWO_PANEL_SIDE_WALL', 'def swap_side_wall', 'pairs.reverse()'):
        ck('gen-booth.py code (comments stripped) does not contain %r' % token,
           token in code, False)
        out.append('    %-28s absent' % token)
    return out


PANEL_RE = re.compile(
    r"\{ :k=>'panel', :id=>'([^']+)', :sk=>'[^']*', :sh=>'(out|in)', "
    r":poly=>\[\[([-\d.]+),([-\d.]+)\],\[([-\d.]+),([-\d.]+)\],"
    r"\[([-\d.]+),([-\d.]+)\],\[([-\d.]+),([-\d.]+)\]\] \}")


def side_walls():
    """Every E/W panel of every model in the GENERATED wr-booth-data.rb, as
    (model, wall, shell) -> [(slot_id, y_lo, y_hi), ...] low end first."""
    path = os.path.join(HERE, 'wr-booth-data.rb')
    src = io.open(path, encoding='utf-8').read()
    out = {}
    model = None
    for line in src.splitlines():
        m = re.match(r"\s*'(MDL [^']+)' =>", line)
        if m:
            model = m.group(1)
            continue
        g = PANEL_RE.search(line)
        if not g or model is None:
            continue
        pid, shell = g.group(1), g.group(2)
        wall = pid[0]
        if wall not in ('E', 'W'):
            continue
        ys = [float(g.group(i)) for i in (4, 6, 8, 10)]
        out.setdefault((model, wall, shell), []).append((pid, min(ys), max(ys)))
    for k in out:
        out[k].sort(key=lambda r: r[1])
    return out


def test_generated_scope():
    walls = side_walls()
    out = ['THE GENERATED DATA - no side wall carries a reversed slot order', '']
    ck('wr-booth-data.rb has side walls to check at all', len(walls) > 0, True)

    swapped = set()
    for (model, wall, shell), panels in sorted(walls.items()):
        if len(panels) != 2:
            continue
        lens = [round(hi - lo, 3) for _pid, lo, hi in panels]
        idx = [int(re.sub(r'\D', '', p[0])) for p in panels]
        # slot ids descending along the run == this wall was walked the other
        # way, which is the swap and the ONLY thing that produces it.
        if idx == sorted(idx, reverse=True):
            swapped.add((model, wall, shell))
            out.append('    %-12s %s %-3s  slot order reversed, lengths %s'
                       % (model, wall, shell, lens))

    ck('NO model carries a reversed side-wall slot order (2026-09-02 ruling: '
       'slot 0, the wide slot, at the door end on every split-run model)',
       sorted({m for m, _w, _s in swapped}), [])
    ck('and that holds on every wall and both shells - nothing left over',
       len(swapped), 0)
    if not swapped:
        out.append('    (none - every two-panel side wall walks slot 0 first from the door end)')

    return out, swapped


# ---------------------------------------------------------------------------
# 3. THE DUCT COVER FACE SIGN
# ---------------------------------------------------------------------------

def test_duct_face():
    src = io.open(os.path.join(HERE, 'wr-overlays.rb'), encoding='utf-8').read()
    m = re.search(r'FACE_ROOM = \{([^}]*)\}', src)
    ck('wr-overlays.rb still declares FACE_ROOM', m is not None, True)
    pairs = dict(re.findall(r':(\w+)\s*=>\s*(-?\d+)', m.group(1))) if m else {}
    # Benton 2026-08-28: "ALL duct covers need to be flipped 180 degrees."
    ck('FACE_ROOM[:duct] is -1 (the cover yaws 180 in place)',
       pairs.get('duct'), '-1')
    # Foam and desk were NOT reported and must not have moved. The MJP moved
    # to -1 on 2026-09-08 and is pinned by test_mjp_chain below.
    for fam in ('foam', 'desk'):
        ck('FACE_ROOM[:%s] is untouched' % fam, pairs.get(fam), '1')
    return ['THE DUCT COVER FACE SIGN - wr-overlays.rb FACE_ROOM', '',
            '    %s' % pairs]


# ---------------------------------------------------------------------------
# 5. THE MJP'S PLACED ORIENTATION - the WHOLE chain, transcribed and run.
#
# Benton, 2026-09-08, off the 1.19.2 code: the MJP hung "upside down" with
# the cable tails rising into the desk and no jack field facing the room, and
# it "needs to rotate 180 degrees, as well as flip upside down". Root cause in
# .forge/fixer/mjp-orientation-diagnosis.md: 1.19.2's MJP_SPIN180 turned a
# part that is authored right way up, and FACE_ROOM[:mjp] = +1 pointed the
# closed back at the room.
#
# THIS SECTION EXISTS BECAUSE NEITHER HARNESS REACHED wall_transform. The two
# constants were "verified" by tests that never composed them, which is how a
# wrong-axis fix shipped. So the chain is transcribed here in full -
# build-booth-components.rb:1572 rotation(), wr-overlays.rb wall_transform()
# (the nrm sign, the spin, the z_top seating) and axes_for() - and driven by
# the MJP.skp bounds MEASURED off the P: library (_component-probe.tsv:
# 8.7500 x 3.0306 x 18.3839, origin_z 8.8839 => z -8.8839..9.5000; the jack
# box is the horizontal-face band z 2.125..9.5 in _face-levels.tsv, the tails
# everything below it). The three constants are READ OUT OF THE SOURCE, not
# restated, so a re-flip of any one of them goes red here.
#
# The transcription itself is the risk, so it is checked two ways: the OLD
# (1.19.2) settings must reproduce Benton's screenshot to the inch, and the
# NEW settings must land the part where the portal draws it.
# ---------------------------------------------------------------------------
OVERLAYS_RB = os.path.join(HERE, 'wr-overlays.rb')

MJP_E = [8.75, 3.0306, 18.3839]           # def-space extents, observed
MJP_LO = [0.0, 0.0, -8.8839]              # bounds.min  (origin_z = -min.z)
MJP_HI = [8.75, 3.0306, 9.5]              # bounds.max
MJP_BOX_DEF_Z = (2.125, 9.5)              # the jack box, def z
MJP_W, MJP_T = 8.39, 3.01                 # wr-overlays.rb
MJP_TOP_Z = 27.25 + 3.64 / 2.0            # wr-overlays.rb MJP_TOP_Z = 29.07

EVEN = [[0, 1, 2], [1, 2, 0], [2, 0, 1]]  # build-booth-components.rb:1527


def _cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]


def _det(c0, c1, c2):
    return (c0[0]*(c1[1]*c2[2]-c1[2]*c2[1]) - c1[0]*(c0[1]*c2[2]-c0[2]*c2[1])
            + c2[0]*(c0[1]*c1[2]-c0[2]*c1[1]))


def _apply(cols, p):
    return [cols[0][i]*p[0] + cols[1][i]*p[1] + cols[2][i]*p[2] for i in range(3)]


def mjp_axes_for(e, want_w, want_h, want_t):
    """wr-overlays.rb axes_for, verbatim scoring and iteration order."""
    import itertools
    best = None
    for wi, hi, ti in itertools.permutations([0, 1, 2]):
        err = abs(e[wi]-want_w) + abs(e[ti]-want_t)
        if want_h is not None:
            err += abs(e[hi]-want_h)
        if best is None or err < best['err']:
            best = {'wi': wi, 'hi': hi, 'ti': ti, 'err': err}
    return best


def mjp_rotation(hi, ti, wi, nrm):
    """build-booth-components.rb:1572 rotation(): columns = image of def X,Y,Z."""
    s = 1 if [hi, ti, wi] in EVEN else -1
    ax = [None, None, None]
    ax[hi] = [0, 0, 1]
    ax[ti] = nrm
    ax[wi] = _cross([0, 0, 1], nrm) if s > 0 else _cross(nrm, [0, 0, 1])
    return ax


def mjp_place(ax, wall, face_sign, room_flip, spin180):
    """wr-overlays.rb wall_transform, the rotation and the z seating only.

    Returns (cols, nrm, room_dir, box_z, tail_tip_z). room_dir is the unit
    vector from the wall into the booth, independent of room_flip."""
    walls = {'S': ('y', 1.0), 'N': ('y', -1.0), 'W': ('x', 1.0), 'E': ('x', -1.0)}
    naxis, room0 = walls[wall]
    room = room0 * (-1.0 if room_flip else 1.0)
    o = room * face_sign
    nrm = [o, 0, 0] if naxis == 'x' else [0, o, 0]
    room_dir = [room0, 0, 0] if naxis == 'x' else [0, room0, 0]
    cols = mjp_rotation(ax['hi'], ax['ti'], ax['wi'], nrm)
    if spin180:                       # rotation(ORIGIN, nrm, 180) * rot
        def r(v):
            d = sum(n*c for n, c in zip(nrm, v))
            return [2*d*n - c for n, c in zip(nrm, v)]
        cols = [r(c) for c in cols]
    zs = []
    for px in (MJP_LO, MJP_HI):
        for py in (MJP_LO, MJP_HI):
            for pz in (MJP_LO, MJP_HI):
                zs.append(_apply(cols, [px[0], py[1], pz[2]])[2])
    d_z = MJP_TOP_Z - max(zs)
    box = sorted(_apply(cols, [0, 0, z])[2] + d_z for z in MJP_BOX_DEF_Z)
    tip = _apply(cols, [0, 0, MJP_LO[2]])[2] + d_z
    return cols, nrm, room_dir, (round(box[0], 2), round(box[1], 2)), round(tip, 2)


def _dot(a, b):
    return sum(x*y for x, y in zip(a, b))


def test_mjp_chain():
    src = io.open(OVERLAYS_RB, encoding='utf-8').read()
    out = ['THE MJP PLACED ORIENTATION - the chain, transcribed and run', '']

    # -- the three constants, read out of the source ------------------------
    m = re.search(r'^\s*MJP_SPIN180\s*=\s*(true|false)', src, re.M)
    spin = (m.group(1) == 'true') if m else None
    ck('wr-overlays.rb declares MJP_SPIN180', spin is not None, True)
    m = re.search(r'FACE_ROOM = \{([^}]*)\}', src)
    pairs = dict(re.findall(r':(\w+)\s*=>\s*(-?\d+)', m.group(1))) if m else {}
    face = int(pairs.get('mjp', '0'))
    ck('FACE_ROOM[:mjp] is declared', face in (1, -1), True)
    m = re.search(r'axes_for\(gx\[:e\],\s*MJP_W,\s*([^,]+),\s*MJP_T\)', src)
    ck('the MJP axes_for call exists', m is not None, True)
    want_h = m.group(1).strip() if m else '?'
    ck('the MJP axes_for call passes nil for height (a guess ties, see 1.14.6)',
       want_h, 'nil')
    out.append('    source: MJP_SPIN180 = %s, FACE_ROOM[:mjp] = %+d, axes_for height = %s'
               % (str(spin).lower(), face, want_h))

    # -- axes_for: nil must pick width X / thickness Y / height Z, by a margin
    ax = mjp_axes_for(MJP_E, MJP_W, None, MJP_T)
    ck('axes_for(nil) picks wi 0 / hi 2 / ti 1 (18.38 is the vertical)',
       (ax['wi'], ax['hi'], ax['ti']), (0, 2, 1))
    guess = mjp_axes_for(MJP_E, MJP_W, 8.0, MJP_T)
    tie = abs((abs(MJP_E[0]-MJP_W) + abs(MJP_E[2]-8.0))
              - (abs(MJP_E[2]-MJP_W) + abs(MJP_E[0]-8.0))) < 1e-9
    ck('the old guessed 8.0 was an exact tie between up and along-the-wall',
       tie, True)
    out.append('    axes_for(nil): wi %d hi %d ti %d, err %.4f; the 8.0 guess tied at %.4f'
               % (ax['wi'], ax['hi'], ax['ti'], ax['err'], guess['err']))

    # -- the NEW settings, every wall, both faces ----------------------------
    out.append('    with the source settings:')
    for wall in 'SNWE':
        for label, flip in (('int', False), ('ext', True)):
            cols, nrm, room_dir, box, tip = mjp_place(ax, wall, face, flip, spin)
            d = _det(*cols)
            field = [-c for c in cols[1]]              # def -Y = the jack field
            ck('%s %s: det +1, no reflection' % (wall, label), round(d, 6), 1.0)
            ck('%s %s: def +Z lands UP (box above tails)' % (wall, label),
               cols[2], [0, 0, 1])
            want = _dot(field, room_dir) if not flip else -_dot(field, room_dir)
            ck('%s %s: jack field (def -Y) faces %s' % (wall, label,
                                                       'the room' if not flip else 'out of the booth'),
               round(want, 6), 1.0)
            ck('%s %s: box at 21.70..29.07 off the floor' % (wall, label), box, (21.7, 29.07))
            ck('%s %s: tail tips at 10.69' % (wall, label), tip, 10.69)
            out.append('      %s %s  def+Z -> %s  field -> %s  det %+.0f  box %.2f..%.2f  tails to %.2f'
                       % (wall, label, cols[2], field, d, box[0], box[1], tip))

    # -- the OLD settings must reproduce the 2026-09-08 screenshot ----------
    cols, _n, room_dir, box, tip = mjp_place(ax, 'S', 1, False, True)
    ck('1.19.2 settings (spin on, face +1) put the box at 10.69..18.06 - the screenshot',
       box, (10.69, 18.06))
    ck('1.19.2 settings sent def +Z DOWN', cols[2], [0, 0, -1])
    ck('1.19.2 settings pointed the jack field INTO the wall',
       round(_dot([-c for c in cols[1]], room_dir), 6), -1.0)
    out.append('    1.19.2 settings re-run: def+Z -> %s, box %.2f..%.2f, tails to %.2f (the defect)'
               % (cols[2], box[0], box[1], tip))

    # -- MJP_TOP_Z is a wall datum, not a desk offset --------------------------
    # The 27.25 came from "32.5 desk surface minus 5.25" ONCE, at portal QA,
    # and is a literal here on purpose: when the desk moved 3/32 on 2026-09-08
    # the MJP stayed put. Pin the independence so a later "tidy-up" cannot
    # rewrite it as DESK_SURFACE_Z - 5.25 and drag the box down silently.
    m = re.search(r'^\s*MJP_TOP_Z\s*=\s*(.+)$', src, re.M)
    ck('MJP_TOP_Z is declared', m is not None, True)
    expr = m.group(1).strip() if m else ''
    ck('MJP_TOP_Z is anchored on the literal 27.25, not on DESK_SURFACE_Z',
       ('27.25' in expr, 'DESK' in expr), (True, False))
    return out


# ---------------------------------------------------------------------------
# 6. THE DESK SURFACE HEIGHT - wr-overlays.rb DESK_SURFACE_Z.
#
# Benton, 2026-09-08, off a booth-builder-link import: "the desk needs to
# lower by 3/32\"". The portal's 32.5 is the anchor and the 3/32 is his
# fit-check, so the source carries the subtraction, not 32.40625. Read the
# expression out of the file and evaluate it; a bare re-typed number or a
# second "correction" on top of this one goes red here.
# ---------------------------------------------------------------------------
DESK_SURFACE_WANT = 32.5 - 3.0 / 32.0        # 32.40625


def test_desk_height():
    src = io.open(OVERLAYS_RB, encoding='utf-8').read()
    m = re.search(r'^\s*DESK_SURFACE_Z\s*=\s*([0-9.\s/\-+*()]+?)\s*$', src, re.M)
    ck('wr-overlays.rb declares DESK_SURFACE_Z as a plain arithmetic expression',
       m is not None, True)
    expr = m.group(1).strip() if m else '0'
    val = eval(expr, {'__builtins__': {}}, {})     # digits and operators only
    ck('DESK_SURFACE_Z evaluates to 32.5 - 3/32 = 32.40625 (Benton, 8 Sep 2026)',
       round(val, 6), round(DESK_SURFACE_WANT, 6))
    ck('DESK_SURFACE_Z is written as the 32.5 anchor minus the 3/32, not a bare number',
       ('32.5' in expr and '/' in expr), True)
    # Nothing else keys off the desk height: the seating and its console line.
    # Counted on CODE lines only - the comments explaining it do not count.
    code = [l for l in src.splitlines() if not l.lstrip().startswith('#')]
    n = sum(len(re.findall(r'DESK_SURFACE_Z', l)) for l in code)
    ck('DESK_SURFACE_Z is read at exactly its declaration plus two uses (seating, print)',
       n, 3)
    return ['THE DESK SURFACE HEIGHT - wr-overlays.rb DESK_SURFACE_Z', '',
            '    %s = %.5f  (%d references in the file)' % (expr, val, n)]


# ---------------------------------------------------------------------------
# 4. THE 72-SERIES DECK MIRROR IS GONE - wr-deck.rb, MIRROR_DECK_KINDS.
#
# Benton, 2026-09-02, off 1.19.10: 7272 floor + ceiling and 7296 floor had the
# hinges in the CENTER; 7296 ceiling (the one deck not mirrored) was right.
# The mirror was scaling(-1, 1, 1) = a reflection of X, and both decks tile
# along X, so it reflected every SIDE tile across the tiling axis and sent its
# bracket line from the outer wall to the seam. Root cause and axis argument:
# .forge/fixer/ROOTCAUSE-deck-mirror-72-2026-09-02.md.
#
# Three things are pinned, each read out of the SOURCE rather than assumed:
#   a. the table is empty;
#   b. the mirror line still reflects X, so the documented alternative in the
#      comment ("a Y question wants scaling(1, -1, 1)") stays truthful;
#   c. the reason no mirror of ANY axis is needed now: on the 7272 and 7296
#      the generated layout puts the 46 in side panel (E0/W0) on the LOW half
#      of Y, where every 72-series floor part is authored with its 24.125 in
#      big-wall gap (33% along). Both sides of that comparison agree.
# ---------------------------------------------------------------------------
DECK_RB = os.path.join(HERE, 'wr-deck.rb')
DATA_RB = os.path.join(HERE, 'wr-booth-data.rb')


def test_deck_mirror():
    out = ['4. 72-SERIES DECK MIRROR (MIRROR_DECK_KINDS)', '']
    src = open(DECK_RB, encoding='utf-8').read()
    m = re.search(r'MIRROR_DECK_KINDS\s*=\s*\{(.*?)\}\.freeze', src, re.S)
    body = '' if m is None else re.sub(r'#.*', '', m.group(1)).strip()
    ck('MIRROR_DECK_KINDS is defined in wr-deck.rb', m is not None, True)
    ck('MIRROR_DECK_KINDS is EMPTY (no 72-series deck is mirrored)', body, '')
    ck('the deck mirror line still reflects X (comment alternative is honest)',
       'Geom::Transformation.scaling(ORIGIN, -1, 1, 1) * tr if mirror' in src, True)

    data = open(DATA_RB, encoding='utf-8').read()
    for model in ('MDL 7272 S', 'MDL 7272 E', 'MDL 7296 S', 'MDL 7296 E'):
        i = data.find("'%s' =>" % model)
        j = data.find("\n    '", i + 1)
        chunk = data[i:j]
        for wall in ('E0', 'W0'):
            mm = re.search(r":id=>'%s'.*?:poly=>\[\[[\d.]+,([\d.]+)\],\[[\d.]+,([\d.]+)\],"
                           r"\[[\d.]+,([\d.]+)\]" % wall, chunk)
            ys = sorted(float(v) for v in mm.groups()) if mm else []
            ck('%s %s: 46 in side panel on the LOW half of Y (y 2..48)' % (model, wall),
               (ys[0], ys[-1]) if ys else None, (2.0, 48.0))
    out.append('  table body: %r' % body)
    return out


def main():
    blocks = []
    blocks.append(test_ceilings())
    blocks.append(test_swap_predicate())
    gen, swapped = test_generated_scope()
    blocks.append(gen)
    blocks.append(test_duct_face())
    blocks.append(test_deck_mirror())
    blocks.append(test_mjp_chain())
    blocks.append(test_desk_height())

    for b in blocks:
        print('\n'.join(b))
        print('')

    print('=' * 78)
    if FAILS:
        print('FAILED  %d of %d check(s):\n' % (len(FAILS), CHECKS[0]))
        for f in FAILS:
            print('  - %s' % f)
        return 1
    print('ALL %d CHECKS PASS' % CHECKS[0])
    print('')
    print('UNRUN IN SKETCHUP. Nothing here builds a booth; these are the pure')
    print('rules only. What Benton must look at on the next build is listed in')
    print('.forge/fixer/HANDOFF-part-orientation.md.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
