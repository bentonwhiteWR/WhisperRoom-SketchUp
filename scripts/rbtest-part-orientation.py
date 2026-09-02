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
    # The other three families were NOT reported and must not have moved.
    for fam in ('foam', 'desk', 'mjp'):
        ck('FACE_ROOM[:%s] is untouched' % fam, pairs.get(fam), '1')
    return ['THE DUCT COVER FACE SIGN - wr-overlays.rb FACE_ROOM', '',
            '    %s' % pairs]


def main():
    blocks = []
    blocks.append(test_ceilings())
    blocks.append(test_swap_predicate())
    gen, swapped = test_generated_scope()
    blocks.append(gen)
    blocks.append(test_duct_face())

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
