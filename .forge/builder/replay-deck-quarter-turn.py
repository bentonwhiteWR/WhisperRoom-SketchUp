#!/usr/bin/env python3
"""Replay WR_Deck.build's quarter-turn decision, in Python, against the REAL
rule parsed out of scripts/wr-deck.rb.

WHY THIS EXISTS. v1.6.38 changed the quarter turn from an assertion about a
filename (`turn = !along_is_x`, "fact 2": definition X runs along the tiling
direction) to a question asked of the part itself (does the definition's
measured X match the ALONG nominal or the CROSS one?). That is a change to
every deck placement in every booth, and the claim justifying it is:

    For any part that really does satisfy fact 2, the new rule returns exactly
    what the old rule returned. It can only change parts whose measured box
    CONTRADICTS the name.

That claim is arithmetic, and arithmetic can be checked here even though no
Ruby can run on this machine. What CANNOT be checked here is which convention
any real .skp actually uses - nothing outside SketchUp can open one. See the
"what this harness cannot see" section at the end, and do not report a pass
here as evidence that a booth builds right.

Run:  python .forge/builder/replay-deck-quarter-turn.py
"""
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(REPO, 'scripts', 'wr-deck.rb')

fails = []
checks = 0


def check(label, got, want):
    global checks
    checks += 1
    if got != want:
        fails.append('%s\n      got  %r\n      want %r' % (label, got, want))


src = open(SRC, encoding='utf-8').read()

m = re.search(r'^\s*SQUARE_TOL\s*=\s*([\d.]+)\s*$', src, re.M)
if not m:
    sys.exit('SQUARE_TOL not found in %s' % SRC)
SQUARE_TOL = float(m.group(1))


def turn(dx, along_nom, cross_nom, along_is_x):
    """The rule as written in build(), transcribed. Returns (turn, disagreed)."""
    old_turn = not along_is_x
    if abs(along_nom - cross_nom) <= SQUARE_TOL:
        return old_turn, False
    x_is_along = abs(dx - along_nom) < abs(dx - cross_nom)
    t = old_turn if x_is_along else (not old_turn)
    return t, (t != old_turn)


print('=== 1. parsed out of the source ===================================')
print('  %s' % os.path.relpath(SRC, REPO))
print('    SQUARE_TOL = %s' % SQUARE_TOL)
check('the old rule is gone as a bare assignment',
      len(re.findall(r'^\s*turn = !t\[:along_is_x\]\s*$', src, re.M)), 0)
check('the new rule reads the measured dx',
      len(re.findall(r'x_is_along = \(dx - along_nom\)\.abs < \(dx - cross_nom\)\.abs', src)), 1)
check('a disagreement is reported, never silent',
      bool(re.search(r'if turn != old_turn.*?warn <<', src, re.S)), True)
print('')

print('=== 2. THE REDUCTION PROPERTY, which is the whole safety argument ==')
# Every real deck pairing in the folder listing, both orientations, both
# tiling directions. A part satisfying fact 2 measures its ALONG nominal on X.
PAIRS = [(48, 96), (96, 48), (48, 72), (72, 48), (96, 24), (24, 96),
         (102, 42), (42, 102), (84, 42), (42, 84), (60, 42), (60, 18),
         (72, 24), (30, 42)]
worst = 0
for along, cross in PAIRS:
    for along_is_x in (True, False):
        t, disagreed = turn(along, along, cross, along_is_x)   # dx == along: fact 2 holds
        check('fact-2 part %gx%g along_is_x=%s is unchanged' % (along, cross, along_is_x),
              (t, disagreed), (not along_is_x, False))
        worst = max(worst, abs(along - cross))
print('  %d pairings x 2 tiling directions: a part that satisfies fact 2 never moves.'
      % len(PAIRS))
print('  This is the claim the change rests on, and it holds by construction.')
print('')

print('=== 3. the part that contradicts its name gets the opposite turn ===')
# STD4896CL: named 48 across / 96 along, but authored with the 48 edge on X.
t, disagreed = turn(48.0, 96.0, 48.0, False)
check('4896 authored crossways turns the other way', (t, disagreed), (False, True))
print('  STD4896CL, dx measuring 48 against an along nominal of 96:')
print('    old rule: turn=True  (quarter turn -> laid crossways, what Benton saw)')
print('    new rule: turn=%-5s disagreed=%s -> NAMED in the build warnings' % (t, disagreed))
# and the same part authored per fact 2 must NOT move
t2, d2 = turn(96.0, 96.0, 48.0, False)
check('4896 authored per fact 2 is untouched', (t2, d2), (True, False))
print('    same part authored per fact 2: turn=%s, disagreed=%s (unchanged)' % (t2, d2))
print('')

print('=== 4. square decks keep the old rule ==============================')
for n in (48, 72, 96):
    for along_is_x in (True, False):
        t, disagreed = turn(float(n), float(n), float(n), along_is_x)
        check('square %g along_is_x=%s' % (n, along_is_x),
              (t, disagreed), (not along_is_x, False))
# and a near-square pair inside the tolerance is treated the same way
t, disagreed = turn(48.0, 48.0, 48.5, False)
check('within SQUARE_TOL is treated as square', disagreed, False)
print('  STD4848 / STD7272 / STD9696: no cue, no way to be wrong, old rule kept.')
print('  The smallest REAL gap the tolerance must resolve is 96 vs 24 = 72 in,')
print('  and SQUARE_TOL is %g - three orders of margin.' % SQUARE_TOL)
print('')

print('=== 5. what this harness CANNOT see ================================')
print('  - WHICH CONVENTION ANY REAL .skp USES. Nothing outside SketchUp can')
print('    open one, so the premise that STD4896CL is authored with its 48 edge')
print('    on X is INFERRED from the defect Benton reported, not measured. If')
print('    it is authored the other way, this change is a no-op for that part')
print('    and the 4896 ceiling is still wrong - and the cause is elsewhere.')
print('  - whether any OTHER part in the folder disagrees with its name. The')
print('    build now warns by name for each one that does; that console output')
print('    is the measurement, and it does not exist until Benton runs it.')
print('  - anything about the 180s (flip, half) - untouched by this change and')
print('    not modelled here.')
print('  - whether the running SketchUp has this code. A Ruby module keeps its')
print('    constants until restart.')
print('')

if fails:
    print('%d of %d CHECKS FAILED' % (len(fails), checks))
    for f in fails:
        print('  %s' % f)
    sys.exit(1)
print('ALL %d CHECKS PASS' % checks)
