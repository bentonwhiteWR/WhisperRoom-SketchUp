# -*- coding: utf-8 -*-
"""Author the synthetic floor-plan eval cases — truth FIRST, plan derived.

    python eval/gen-plans.py            # (re)generate every synthetic case
    python eval/gen-plans.py --list     # name + one-liner per case
    python eval/gen-plans.py <name>     # just that case

Spec: .forge/scoper/floorplan-intake.md step 8 / §B4. Every case in CASES is
authored as EXACT numbers (inches) in this file — the truth — and everything
else is derived from those numbers: truth.json is the numbers verbatim,
takeoff.json is the transcription fixture (deliberately wrong where the case
is a trap), and input/plan.pdf + input/photo.png are a vector plan and a
rasterized "phone photo" drawn FROM the truth. The generator never parses its
own output back; if a dimension string here disagrees with its inch value,
the eval loop is what catches it — that is the loop working.

Determinism: no randomness anywhere. Re-running reproduces truth.json,
takeoff.json and photo.png byte-identical (the AC-15 requirement and then
some). plan.pdf differs only in its trailer /ID (MuPDF salts it with the
clock); its page CONTENT is identical — proven by photo.png, which is
rasterized from it, hashing the same across runs.

THE CASES ARE ADVERSARIAL ON PURPOSE. A generator that only produces cases
the pipeline already passes is worthless; these are designed to make the
checker and the builder fail, split into:
  - cases the pipeline must BUILD exactly (expects: None) — pass = clean;
  - cases the checker must REFUSE BY NAME (expects.refusal) — pass = the
    named refusal, and anything that builds is a FAIL;
  - cases that build plausible-looking WRONG geometry or fabricated
    provenance that only the scorer can catch (expects.score_fail) — pass =
    the scorer detecting the planted defect. These are the 31-Aug-shaped
    ones and the most important rows in the ledger;
  - probe cases (expects: "probe") — behavior unknown when authored; the
    first live run decides, and the README records the verdict.
"""
import io
import json
import math
import os
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'floorplans')

DIRV = {'E': (1, 0), 'W': (-1, 0), 'N': (0, 1), 'S': (0, -1)}
SRC = 'stated synthetic (authored)'   # the honest src for authored fixtures


def walk(runs):
    """Vertices from (d, inches) pairs, origin first, closing vertex dropped.
    Pure arithmetic on the authored numbers — no parsing anywhere."""
    pts = [(0.0, 0.0)]
    x = y = 0.0
    for d, n in runs:
        x += DIRV[d][0] * float(n)
        y += DIRV[d][1] * float(n)
        pts.append((round(x, 4), round(y, 4)))
    ex, ey = pts[-1]
    if abs(ex) > 1e-6 or abs(ey) > 1e-6:
        # An authored non-closing chain is legal ONLY when the case is about
        # non-closure; the case must say so or this file has a typo in it.
        return pts, (ex, ey)
    return pts[:-1], None


def arch(n):
    neg = n < 0
    n = abs(n)
    f = int(n // 12)
    i = round((n - f * 12) * 10) / 10
    if i >= 12:
        f, i = f + 1, i - 12
    s = ('%g' % i) if i % 1 else str(int(i))
    return ('-' if neg else '') + "%d'-%s\"" % (f, s)


def V(s):
    return {'v': s, 'src': SRC}


# =========================================================== the case set ==
#
# Truth numbers are stated FIRST in each block, as plain inches.

CASES = []


def case(name, summary, truth_rooms, takeoff_rooms, expects=None, readme='',
         plan_notes=(), truth_ref=None, extra_case=None):
    CASES.append({
        'name': name, 'summary': summary, 'truth_rooms': truth_rooms,
        'takeoff_rooms': takeoff_rooms, 'expects': expects, 'readme': readme,
        'plan_notes': list(plan_notes), 'truth_ref': truth_ref,
        'extra_case': extra_case or {},
    })


def troom(room, runs, ceiling_in, doors=(), features=(), tol=0.1, note=None):
    pts, gap = walk(runs)
    t = {'room': room,
         'source': 'authored by eval/gen-plans.py — exact by construction',
         'tolerance_in': tol,
         'polygon': [[p[0], p[1]] for p in (pts if gap is None else pts[:-1])],
         'ceiling_in': ceiling_in,
         'doors': list(doors), 'features': list(features)}
    if note:
        t['note'] = note
    return t


# --- 1. synthetic-nonclosing ------------------------------------------------
# Truth: the room is 144 x 120. The PLAN's west callout says 11'8" (140) —
# a 4" transcription trap printed right on the drawing. A verbatim take-off
# cannot close, and the only correct output is the named refusal.
case(
    'synthetic-nonclosing',
    'chain 4" open — pass is the checker refusing by name, nothing builds',
    [troom('nonclose', [('E', 144), ('S', 120), ('W', 144), ('N', 120)], 102.0)],
    [{'name': 'nonclose',
      'runs': [{'d': 'E', **V('12\'')}, {'d': 'S', **V('10\'')},
               {'d': 'W', **V('11\'8"')}, {'d': 'N', **V('10\'')}],
      'ceiling': V('8\'6"')}],
    expects={'refusal': ['runs do not close']},
    readme="""The plan itself carries the defect: the west wall is called out
11'-8" where the east wall is 12'-0", so a verbatim transcription is a chain
4" open. Pass = `takeoff-check.py` refuses with the polygon-closure message
BY NAME and no lock file exists; if anything ever builds from this case, the
refusal has been silently un-fixed and the case turns red.""",
    plan_notes=['west callout deliberately reads 11\'-8" — the trap'],
)

# --- 2. synthetic-missing ---------------------------------------------------
case(
    'synthetic-missing',
    'door with no position + room with no ceiling — both must fail by name',
    [troom('nodoorpos', [('E', 120), ('S', 96), ('W', 120), ('N', 96)], 102.0,
           doors=[{'run': 0, 'w_in': 36.0, 'jambs_in': None,
                   'expect_flag': 'assumed'}]),
     troom('noceil', [('E', 108), ('S', 108), ('W', 108), ('N', 108)], None)],
    [{'name': 'nodoorpos',
      'runs': [{'d': 'E', **V('10\'')}, {'d': 'S', **V('8\'')},
               {'d': 'W', **V('10\'')}, {'d': 'N', **V('8\'')}],
      'ceiling': V('8\'6"'),
      'doors': [{'run': 0, 'w': V('36"'), 'hinge': 'near'}]},   # no `at`
     {'name': 'noceil',
      'runs': [{'d': 'E', **V('9\'')}, {'d': 'S', **V('9\'')},
               {'d': 'W', **V('9\'')}, {'d': 'N', **V('9\'')}]}],  # no ceiling
    expects={'refusal': ['no position on run 0', 'noceil ceiling']},
    readme="""Two omissions a real plan commits constantly: a door drawn with
a width but no position, and a room with no ceiling height anywhere. The old
dialog invented `at:36"` and a 96" ceiling here — the 31 Aug defect. Pass =
both fail BY NAME (door 0: measure corner->near jamb or record an assumption;
noceil: ceiling missing) and nothing builds.""",
    plan_notes=['door drawn with width only — no position callout',
                'room "noceil" has no ceiling callout anywhere'],
)

# --- 3. synthetic-cornerdoor ------------------------------------------------
case(
    'synthetic-cornerdoor',
    'door at the corner, door overrunning the far corner, two doors overlapping',
    [troom('corner', [('E', 168), ('S', 120), ('W', 168), ('N', 120)], 96.0)],
    [{'name': 'corner',
      'runs': [{'d': 'E', **V('14\'')}, {'d': 'S', **V('10\'')},
               {'d': 'W', **V('14\'')}, {'d': 'N', **V('10\'')}],
      'ceiling': V('8\''),
      'doors': [
          {'run': 0, 'at': V('0"'), 'w': V('36"'), 'hinge': 'near'},
          {'run': 1, 'at': V('8\'0"'), 'w': V('36"'), 'hinge': 'near'},
          {'run': 2, 'at': V('20"'), 'w': V('38"'), 'hinge': 'near'},
          {'run': 2, 'at': V('40"'), 'w': V('38"'), 'hinge': 'far'}]}],
    expects={'refusal': ['touches the corner', 'overlap']},
    readme="""Three door pathologies on one room: `at 0"` (in the corner),
`at 8'0" + 36"` on a 10' run (overruns the far corner), and two doors on the
same run whose openings overlap. The corner cases used to build a leaf into
solid wall SILENTLY — the defect class this mission exists for. Pass = all
refused by name, nothing builds.""",
)

# --- 4. synthetic-nasty -----------------------------------------------------
# Truth first: L-shaped room, parts chain, two heaters, a bulkhead, and an
# adjacent rectangular room with a DIFFERENT ceiling and a window.
case(
    'synthetic-nasty',
    'L-room + parts chain + heaters + bulkhead + adjacent room, different ceilings',
    [troom('ell',
           [('E', 220), ('S', 96), ('W', 100), ('S', 60), ('W', 120), ('N', 156)],
           105.0,
           doors=[{'run': 4, 'w_in': 36.0, 'jambs_in': [30.0, 66.0],
                   'expect_flag': None}],
           features=[{'type': 'heater', 'count': 2},
                     {'type': 'bulkhead', 'count': 1}]),
     troom('adjacent', [('E', 120), ('S', 156), ('W', 120), ('N', 156)], 98.0,
           doors=[{'run': 0, 'w_in': 38.0, 'jambs_in': [40.0, 78.0],
                   'expect_flag': None}],
           features=[{'type': 'window', 'count': 1}])],
    [{'name': 'ell',
      'runs': [
          {'d': 'E', 'v': '18\'4"', 'parts': ['10"', '16\'8"', '10"'],
           'src': SRC, 'note': '16\'8" is clear width between the heaters'},
          {'d': 'S', **V('8\'')}, {'d': 'W', **V('8\'4"')},
          {'d': 'S', **V('5\'')}, {'d': 'W', **V('10\'')},
          {'d': 'N', **V('13\'')}],
      'ceiling': V('8\'9"'),
      'doors': [{'run': 4, 'at': V('30"'), 'w': V('36"'), 'h': V('80"'),
                 'hinge': 'near'}],
      'features': [
          {'type': 'heater', 'run': 0, 'from': V('0"'),
           'length': V('10"'), 'depth': V('10"')},
          {'type': 'heater', 'run': 0, 'from': V('17\'6"'),
           'length': V('10"'), 'depth': V('10"')},
          {'type': 'bulkhead', 'run': 1, 'from': V('12"'),
           'length': V('72"'), 'head': V('8\'3"')}]},
     {'name': 'adjacent',
      'runs': [{'d': 'E', **V('10\'')}, {'d': 'S', **V('13\'')},
               {'d': 'W', **V('10\'')}, {'d': 'N', **V('13\'')}],
      'ceiling': V('8\'2"'),
      'doors': [{'run': 0, 'at': V('40"'), 'w': V('38"'), 'h': V('80"'),
                 'hinge': 'near'}],
      'features': [{'type': 'window', 'run': 3, 'from': V('24"'),
                    'width': V('60"'), 'sill': V('30"')}]}],
    readme="""The kitchen-sink tier-1 case: a six-run L-shaped room whose long
wall carries a closing parts chain (10" + 16'8" + 10" = 18'4"), two heater
massings, a bulkhead at 8'-3", plus an adjacent rectangular room at a
DIFFERENT ceiling height (8'-2" vs 8'-9") with a window. Pass = everything
builds within 0.1", both ceilings exact, all four features present, ASSUMED
inventory empty.""",
)

# --- 5. synthetic-jog -------------------------------------------------------
case(
    'synthetic-jog',
    'wall that returns (8-run jog) with a parts chain on the far wall',
    [troom('jog', [('E', 96), ('S', 24), ('E', 48), ('S', 96),
                   ('W', 144), ('N', 120)], 96.0,
           doors=[{'run': 3, 'w_in': 36.0, 'jambs_in': [12.0, 48.0],
                   'expect_flag': None}])],
    [{'name': 'jog',
      'runs': [{'d': 'E', **V('8\'')}, {'d': 'S', **V('2\'')},
               {'d': 'E', **V('4\'')}, {'d': 'S', **V('8\'')},
               {'d': 'W', 'v': '12\'', 'parts': ['8\'', '4\''], 'src': SRC,
                'note': 'south wall overall; segments oppose the jogged north wall'},
               {'d': 'N', **V('10\'')}],
      'ceiling': V('8\''),
      'doors': [{'run': 3, 'at': V('12"'), 'w': V('36"'), 'h': V('80"'),
                 'hinge': 'near'}]}],
    readme="""A north wall that jogs 2' down mid-run (six runs, two of them
the return), the opposite wall carrying the closing 8' + 4' = 12' chain, and
a door 12" from the jogged corner. Pass = built within 0.1" including both
jog vertices and the door jambs.""",
)

# --- 6. synthetic-units -----------------------------------------------------
# Unit-format torture. Truth: 106 x 110 room, ceiling 102, door at 30.5 w 36.
# The west run is written 8.833' = 105.996" — 0.004" of decimal dust that
# must close (TOL is 0.02") and score inside the 0.1" tier-1 floor.
case(
    'synthetic-units',
    "mixed 8'10\" / 8'-10\" / 106\" / 8.833' / unicode / ft-in — all one room",
    [troom('units', [('E', 106), ('S', 110), ('W', 106), ('N', 110)], 102.0,
           doors=[{'run': 0, 'w_in': 36.0, 'jambs_in': [30.5, 66.5],
                   'expect_flag': None}])],
    [{'name': 'units',
      'runs': [{'d': 'E', **V('8\'10"')},
               {'d': 'S', **V('110')},          # bare number IS inches
               {'d': 'W', **V('8.833\'')},      # 105.996" — decimal dust
               {'d': 'N', **V('9′2″')}],   # unicode prime/double-prime
      'ceiling': V('8.5\''),
      'doors': [{'run': 0, 'at': V('2\' 6 1/2"'), 'w': V('3ft'),
                 'h': V('6ft 8in'), 'hinge': 'near'}]}],
    readme="""Every format the grammar admits, one room: `8'10"`, a bare
`110` (inches), decimal feet `8.833'` (105.996" — closes within the 0.02"
dust tolerance and must score inside 0.1"), unicode `9′2″`, spaced
fraction `2' 6 1/2"`, and word units `3ft` / `6ft 8in`. Pass = parses,
closes, builds within 0.1". Any grammar drift between the Python checker and
the JS dialog shows up here first.""",
)

# --- 7. synthetic-clearwidth ------------------------------------------------
# The 31 Aug trap, generalized, transcribed CORRECTLY: 15'0" is the clear
# width between two 12"-deep cabinets; the wall run is 17'0".
case(
    'synthetic-clearwidth',
    "15'0\" is clear width between cabinets; wall is 17'0\" — correct transcription",
    [troom('clear', [('E', 204), ('S', 120), ('W', 204), ('N', 120)], 96.0,
           doors=[{'run': 1, 'w_in': 36.0, 'jambs_in': [42.0, 78.0],
                   'expect_flag': None}],
           features=[{'type': 'heater', 'count': 2}])],
    [{'name': 'clear',
      'runs': [{'d': 'E', 'v': '17\'0"', 'parts': ['12"', '15\'0"', '12"'],
                'src': SRC,
                'note': '15\'0" is CLEAR WIDTH between the two cabinets, not the wall'},
               {'d': 'S', **V('10\'')}, {'d': 'W', **V('17\'')},
               {'d': 'N', **V('10\'')}],
      'ceiling': V('8\''),
      'doors': [{'run': 1, 'at': V('42"'), 'w': V('36"'), 'h': V('80"'),
                 'hinge': 'near'}],
      'features': [
          {'type': 'heater', 'run': 0, 'from': V('0"'),
           'length': V('12"'), 'depth': V('24"'),
           'note': 'cabinet massed as heater type — footprint honesty'},
          {'type': 'heater', 'run': 0, 'from': V('16\''),
           'length': V('12"'), 'depth': V('24"')}]}],
    readme="""The 31 Aug failure shape with fresh numbers, transcribed the
RIGHT way: the plan states 15'-0" clear between two 12" cabinets, and the
take-off records the whole chain (12" + 15'0" + 12" = 17'0"). Pass = builds
at 204" wide exactly, both cabinet massings present. Sibling case
`synthetic-clearwidth-trap` is the same plan transcribed the WRONG way.""",
    plan_notes=["plan states 15'-0\" CLEAR between cabinets — the trap dimension"],
)

# --- 8. synthetic-clearwidth-trap -------------------------------------------
# Same truth; the take-off reads 15'0" as the wall-to-wall width and records
# NO parts. The checker has nothing to catch — this validates clean and
# builds plausible geometry 24" wrong. Only the scorer catches it. This is
# the exact silent-failure class of 31 Aug.
case(
    'synthetic-clearwidth-trap',
    "same plan mis-transcribed: 15'0\" as the wall width, no chain — checker-silent",
    None,                                    # truth lives in the sibling case
    [{'name': 'clear',
      'runs': [{'d': 'E', **V('15\'0"')}, {'d': 'S', **V('10\'')},
               {'d': 'W', **V('15\'')}, {'d': 'N', **V('10\'')}],
      'ceiling': V('8\''),
      'doors': [{'run': 1, 'at': V('42"'), 'w': V('36"'), 'h': V('80"'),
                 'hinge': 'near'}]}],
    expects={'score_fail': ['max vertex error', 'feature missing']},
    truth_ref='../synthetic-clearwidth/truth.json',
    readme="""**Do not "fix" this take-off — its wrongness is its job.** The
same plan as `synthetic-clearwidth`, transcribed the way 31 Aug actually
went: 15'-0" (the clear width between the cabinets) written down as the
wall-to-wall width, chain not recorded, cabinets dropped. The checker
validates it CLEAN — with no recorded chain there is nothing to check — and
the builder produces a plausible-looking room 24" too small with no
complaint. Pass = the SCORER catches it (max vertex error 24" and the two
missing cabinet massings) against the sibling's truth. This documents the
residual risk by measurement: the parts invariant protects only a
transcriber who records the chain; the eval loop is the net under that.""",
)

# --- 9. synthetic-unflagged -------------------------------------------------
# Truth: the plan does NOT state the door position (expect_flag: assumed).
# The take-off writes the right number with a fabricated pen source. The
# geometry scores 0.00" — and the case must STILL fail, on provenance.
case(
    'synthetic-unflagged',
    'right number, fabricated source — must fail on provenance, not geometry',
    [troom('unflag', [('E', 144), ('S', 120), ('W', 144), ('N', 120)], 96.0,
           doors=[{'run': 0, 'w_in': 36.0, 'jambs_in': [36.0, 72.0],
                   'expect_flag': 'assumed'}])],
    [{'name': 'unflag',
      'runs': [{'d': 'E', **V('12\'')}, {'d': 'S', **V('10\'')},
               {'d': 'W', **V('12\'')}, {'d': 'N', **V('10\'')}],
      'ceiling': V('8\''),
      'doors': [{'run': 0,
                 'at': {'v': '36"', 'src': 'pen plan.pdf'},   # FABRICATED —
                 # the plan states no door position; see input/plan.pdf
                 'w': V('36"'), 'h': V('80"'), 'hinge': 'near'}]}],
    expects={'score_fail': ['unflagged']},
    readme="""**Do not "fix" this take-off — its wrongness is its job.** The
plan draws the door but states NO position (look at input/plan.pdf). The
take-off records `at: 36"` with `src: "pen plan.pdf"` — the right number
with a fabricated source, which is the un-catchable version of the dialog's
old invented `at:36"`. It validates, builds, and scores 0.00" on geometry.
Pass = the scorer STILL fails it, because truth marks the position
`expect_flag: assumed` and the model carries no ASSUMED note. An unflagged
assumption is a failing score even when the number is right — that is the
never-invent rule, measured.""",
    plan_notes=['door drawn with width callout only — position stated NOWHERE'],
)

# --- 10. synthetic-selfcross ------------------------------------------------
# PROBE. A run list that closes arithmetically but revisits a vertex — the
# shape a scrambled transcription produces. Authored prediction: the checker
# accepts it (it only checks closure) and the builder does something
# un-named. The first live run decides; the README records the verdict.
case(
    'synthetic-selfcross',
    'closes arithmetically but self-touches — probe: refusal or silent garbage?',
    [troom('selfcross',
           [('N', 60), ('E', 120), ('S', 120), ('W', 240), ('N', 120), ('E', 120),
            ('S', 60)], 96.0)],
    [{'name': 'selfcross',
      'runs': [{'d': 'N', **V('5\'')}, {'d': 'E', **V('10\'')},
               {'d': 'S', **V('10\'')}, {'d': 'W', **V('20\'')},
               {'d': 'N', **V('10\'')}, {'d': 'E', **V('10\'')},
               {'d': 'S', **V('5\'')}],
      'ceiling': V('8\'')}],
    expects={'refusal': ['revisits the corner', 'self-touches']},
    readme="""WAS A PROBE CASE, now an expected refusal. Seven runs that sum to zero — the closure check
passes — but the walk revisits (0,60): the polygon self-touches, which is
what a scrambled run order looks like after a bad transcription. Neither the
checker nor the builder was written with this in mind.

**VERDICT (live, 31 Aug 2026): DEFECT — silent acceptance.** The checker
validated it, `build-takeoff.rb` built it, and SketchUp accepted the pinched
loop as a single 7-vertex floor face (200 sqft, two lobes joined at a
point) with no message anywhere — a physically meaningless "room" of the
exact 31 Aug silent class. The fix belongs in `scripts/takeoff-check.py`
(a self-intersection/repeated-vertex check on the walked polygon), which is
owned by another Builder; recorded in eval/RESULTS.md, not fixed here. When
that check lands, flip this case to `expects: {"refusal": [...]}`.

**FIXED (1.12.3, 31 Aug 2026):** `takeoff-check.py` now runs
`polygon_self_touch` after closure — revisited corners, doubling-back runs
and crossing non-adjacent runs each fail by name and delete any stale lock.
This case is flipped to the expected refusal; a future PASS-turned-FAIL
here means the refusal got un-fixed.""",
)

# --- 11. synthetic-headroom -------------------------------------------------
# PROBE. Bulkhead head ABOVE the ceiling; door TALLER than the ceiling.
case(
    'synthetic-headroom',
    'bulkhead head above ceiling + door taller than ceiling — probe',
    [troom('headroom', [('E', 144), ('S', 120), ('W', 144), ('N', 120)], 96.0,
           doors=[{'run': 1, 'w_in': 36.0, 'jambs_in': [30.0, 66.0],
                   'expect_flag': None}],
           features=[{'type': 'bulkhead', 'count': 1}])],
    [{'name': 'headroom',
      'runs': [{'d': 'E', **V('12\'')}, {'d': 'S', **V('10\'')},
               {'d': 'W', **V('12\'')}, {'d': 'N', **V('10\'')}],
      'ceiling': V('8\''),
      'doors': [{'run': 1, 'at': V('30"'), 'w': V('36"'),
                 'h': V('8\'6"'), 'hinge': 'near'}],     # 102" > 96" ceiling
      'features': [{'type': 'bulkhead', 'run': 0, 'from': V('24"'),
                    'length': V('60"'), 'head': V('9\'0"')}]}],  # 108" > 96"
    expects='probe',
    readme="""PROBE CASE. Two physically impossible statements a transcription
error produces: a bulkhead whose underside (9'-0") is ABOVE the 8'-0"
ceiling, and a door leaf (8'-6") TALLER than the ceiling. Neither the
checker nor the lock validation names these.

**VERDICT (live, 31 Aug 2026): TWO DEFECTS, both silent.**
(1) The impossible bulkhead is silently DROPPED — `build-takeoff.rb`'s
`build_feature` hits `return if ... z1 - z0 <= TOL` (line ~317) and the
massing simply never exists; no refusal, no note. The scorer's
feature-missing check is what catches it. (2) The 8'-6" leaf builds 6"
THROUGH the 8'-0" ceiling plane, wall cut full-height, no message. Both
fixes belong in files owned by another Builder (`takeoff-check.py` should
refuse both by name); recorded in eval/RESULTS.md, not fixed here. When the
checks land, flip this case to `expects: {"refusal": [...]}`.""",
)

# --- 12. synthetic-sliver ---------------------------------------------------
# PROBE. A door 0.03" from the corner — one hundredth past the 0.02"
# refusal line. The checker passes it by construction; does the wall cut
# survive, and is the sliver geometry sane?
case(
    'synthetic-sliver',
    'door 0.03" off the corner — just past the refusal line; probe the geometry',
    [troom('sliver', [('E', 144), ('S', 120), ('W', 144), ('N', 120)], 96.0,
           doors=[{'run': 0, 'w_in': 36.0, 'jambs_in': [0.03, 36.03],
                   'expect_flag': None}])],
    [{'name': 'sliver',
      'runs': [{'d': 'E', **V('12\'')}, {'d': 'S', **V('10\'')},
               {'d': 'W', **V('12\'')}, {'d': 'N', **V('10\'')}],
      'ceiling': V('8\''),
      'doors': [{'run': 0, 'at': V('0.03'), 'w': V('36"'), 'h': V('80"'),
                 'hinge': 'near'}]}],
    readme="""Originally a probe: the corner-door refusal fires below 0.02";
this door sits at 0.03" — legal by one hundredth of an inch, leaving a
0.03" wall sliver at the corner mitre.

**VERDICT (live, 31 Aug 2026): SURVIVED.** The cut and mitre built sane
geometry (11 wall solids, every one a closed 6-face box), read-back jambs
landed at 0.03/36.03 exactly, leaf and opening counts match. Promoted from
probe to a locked tier-1 build case so a future geometry change cannot
silently break the boundary.""",
)


# ============================================================== emitters ==

def emit_json(path, obj):
    with io.open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(obj, f, indent=2, ensure_ascii=False)
        f.write('\n')


def takeoff_doc(c):
    return {
        'job': c['name'],
        'title': 'Eval fixture: ' + c['summary'],
        'sources': ['input/plan.pdf', 'input/photo.png'],
        'anchor': 'authored — truth set in eval/gen-plans.py before the plan '
                  'was drawn; the plan is derived from the truth',
        'rooms': c['takeoff_rooms'],
    }


# ---------------------------------------------------------------- drawing --

PEN = (0.10, 0.13, 0.55)      # ballpoint blue for stated dimensions
INK = (0.15, 0.15, 0.15)      # printed linework
FEAT = (0.45, 0.45, 0.45)


def draw_case(c, folder):
    """input/plan.pdf + input/photo.png, drawn from the TRUTH numbers.
    Labels come from the takeoff strings where the plan states them, because
    the plan is what the transcriber reads — but geometry is truth's."""
    import pymupdf

    rooms = c['truth_rooms'] or []
    if not rooms:
        return None
    doc = pymupdf.open()
    page = doc.new_page(width=792, height=612)     # US letter landscape
    # Lay rooms left to right with a gap, fit to page.
    polys = [r['polygon'] for r in rooms]
    placed, xoff = [], 0.0
    for p in polys:
        xs = [q[0] for q in p]
        ys = [q[1] for q in p]
        placed.append([(q[0] - min(xs) + xoff, q[1] - min(ys)) for q in p])
        xoff += (max(xs) - min(xs)) + 60.0
    allx = [q[0] for p in placed for q in p]
    ally = [q[1] for p in placed for q in p]
    w, h = max(allx) - min(allx), max(ally) - min(ally)
    sc = min((792 - 160) / max(w, 1), (612 - 200) / max(h, 1))

    def X(x):
        return 80 + (x - min(allx)) * sc

    def Y(y):
        return 612 - 120 - (y - min(ally)) * sc     # model +y (north) is up

    shape = page.new_shape()
    tw = pymupdf.get_text_length

    for ri, (r, poly) in enumerate(zip(rooms, placed)):
        pts = [pymupdf.Point(X(x), Y(y)) for x, y in poly]
        shape.draw_polyline(pts + [pts[0]])
        shape.finish(color=INK, width=2.2, closePath=False)
        cx = sum(p.x for p in pts) / len(pts)
        cy = sum(p.y for p in pts) / len(pts)
        page.insert_text((cx - tw(r['room'], 'hebo', 11) / 2, cy), r['room'],
                         fontname='hebo', fontsize=11, color=INK)
        if r.get('ceiling_in'):
            t = 'CLG %s' % arch(r['ceiling_in'])
            page.insert_text((cx - tw(t, 'heit', 9) / 2, cy + 14), t,
                             fontname='heit', fontsize=9, color=PEN)
        # Dimension callouts per run, from the takeoff's own strings (what
        # the plan states); geometry from truth.
        toff = (c['takeoff_rooms'] or [])
        truns = toff[ri]['runs'] if ri < len(toff) else []
        closed = poly + [poly[0]]
        for i in range(len(poly)):
            (ax, ay), (bx, by) = closed[i], closed[i + 1]
            ux, uy = bx - ax, by - ay
            ln = math.hypot(ux, uy) or 1.0
            ux, uy = ux / ln, uy / ln
            nx, ny = uy, -ux                      # outward for CW-ish walks
            mx, my = (ax + bx) / 2, (ay + by) / 2
            # push outward: away from centroid
            gx = sum(p[0] for p in poly) / len(poly)
            gy = sum(p[1] for p in poly) / len(poly)
            if (mx - gx) * nx + (my - gy) * ny < 0:
                nx, ny = -nx, -ny
            label = None
            if i < len(truns):
                tr = truns[i]
                if tr.get('parts'):
                    label = ' | '.join(str(p) for p in tr['parts'])
                    label += '   (= %s)' % tr.get('v', '')
                else:
                    label = str(tr.get('v', ''))
            if not label:
                label = arch(math.hypot(bx - ax, by - ay))
            px = X(mx) + nx * 16
            py = Y(my) - ny * 16
            rot = 0 if abs(ux) >= abs(uy) else 90
            wlab = tw(label, 'heit', 9)
            if rot == 0:
                page.insert_text((px - wlab / 2, py + 3), label,
                                 fontname='heit', fontsize=9, color=PEN)
            else:
                page.insert_text((px, py + wlab / 2), label, fontname='heit',
                                 fontsize=9, color=PEN, rotate=90)
        # Doors: tick + width label; position label ONLY if the takeoff
        # states one (the unflagged case's plan must stay silent).
        for j, d in enumerate((toff[ri].get('doors') or []) if ri < len(toff) else []):
            run_i = d.get('run', 0)
            if run_i >= len(poly):
                continue
            (ax, ay), (bx, by) = closed[run_i], closed[run_i + 1]
            ux, uy = bx - ax, by - ay
            ln = math.hypot(ux, uy) or 1.0
            ux, uy = ux / ln, uy / ln
            td = (rooms[ri].get('doors') or [])
            at = (td[j]['jambs_in'][0] if j < len(td) and td[j].get('jambs_in')
                  else 24.0)
            wd = td[j]['w_in'] if j < len(td) else 36.0
            j0 = (ax + ux * at, ay + uy * at)
            j1 = (ax + ux * (at + wd), ay + uy * (at + wd))
            shape.draw_line(pymupdf.Point(X(j0[0]), Y(j0[1])),
                            pymupdf.Point(X(j1[0]), Y(j1[1])))
            shape.finish(color=(1, 1, 1), width=3.0)
            shape.draw_line(pymupdf.Point(X(j0[0]), Y(j0[1])),
                            pymupdf.Point(X(j1[0]) + (Y(j1[1]) - Y(j0[1])) * 0.6,
                                          Y(j1[1]) + (X(j1[0]) - X(j0[0])) * 0.6))
            shape.finish(color=INK, width=0.8)
            lab = 'door %s' % (d.get('w', {}).get('v', ''))
            if isinstance(d.get('at'), dict) and 'v' in d['at']:
                lab += ' @ %s' % d['at']['v']
            if isinstance(d.get('h'), dict) and 'v' in d['h']:
                lab += ' h %s' % d['h']['v']
            nx2, ny2 = -uy, ux
            gx = sum(p[0] for p in poly) / len(poly)
            gy = sum(p[1] for p in poly) / len(poly)
            mjx, mjy = (j0[0] + j1[0]) / 2, (j0[1] + j1[1]) / 2
            if (mjx - gx) * nx2 + (mjy - gy) * ny2 > 0:
                nx2, ny2 = -nx2, -ny2              # label INSIDE the room
            page.insert_text((X(mjx) + nx2 * 26 - 24, Y(mjy) - ny2 * 26),
                             lab, fontname='heit', fontsize=8, color=PEN)
        # Features as dashed boxes with labels.
        for f in (toff[ri].get('features') or []) if ri < len(toff) else []:
            run_i = f.get('run', 0)
            if run_i >= len(poly):
                continue
            (ax, ay), (bx, by) = closed[run_i], closed[run_i + 1]
            ux, uy = bx - ax, by - ay
            ln = math.hypot(ux, uy) or 1.0
            ux, uy = ux / ln, uy / ln
            nx, ny = -uy, ux
            gx = sum(p[0] for p in poly) / len(poly)
            gy = sum(p[1] for p in poly) / len(poly)
            if ((ax + bx) / 2 - gx) * nx + ((ay + by) / 2 - gy) * ny > 0:
                nx, ny = -nx, -ny                  # inward
            fr = _n(f.get('from'))
            span = _n(f.get('length') or f.get('width')) or 24.0
            dep = _n(f.get('depth')) or 8.0
            p0 = (ax + ux * fr, ay + uy * fr)
            quad = [p0, (p0[0] + ux * span, p0[1] + uy * span),
                    (p0[0] + ux * span + nx * dep, p0[1] + uy * span + ny * dep),
                    (p0[0] + nx * dep, p0[1] + ny * dep)]
            qp = [pymupdf.Point(X(x), Y(y)) for x, y in quad]
            shape.draw_polyline(qp + [qp[0]])
            shape.finish(color=FEAT, width=0.8, dashes='[3 2] 0')
            flab = f['type']
            for k in ('from', 'length', 'width', 'depth', 'head', 'sill'):
                if isinstance(f.get(k), dict) and 'v' in f[k]:
                    flab += ' %s %s' % (k, f[k]['v'])
            page.insert_text((qp[0].x + 2, qp[0].y - 3), flab,
                             fontname='heit', fontsize=7, color=FEAT)
    shape.commit()

    page.insert_text((80, 40), 'SYNTHETIC EVAL PLAN — %s' % c['name'],
                     fontname='hebo', fontsize=13, color=INK)
    page.insert_text((80, 56), 'not a client drawing; truth authored in '
                     'eval/gen-plans.py, plan derived from it',
                     fontname='helv', fontsize=8, color=FEAT)
    yy = 70
    for note in c['plan_notes']:
        page.insert_text((80, yy), '* ' + note, fontname='heit', fontsize=8,
                         color=PEN)
        yy += 11

    doc.set_metadata({'title': c['name'], 'author': 'eval/gen-plans.py',
                      'producer': 'gen-plans', 'creator': 'gen-plans',
                      'creationDate': '', 'modDate': ''})
    pdf_path = os.path.join(folder, 'input', 'plan.pdf')
    doc.save(pdf_path, deflate=True)

    # The "phone photo": rasterize, mild perspective + warm cast. Fixed
    # numbers — deterministic.
    try:
        from PIL import Image, ImageEnhance
        pix = page.get_pixmap(dpi=130)
        img = Image.frombytes('RGB', (pix.width, pix.height), pix.samples)
        wpx, hpx = img.size
        d = int(wpx * 0.015)
        img = img.transform(
            (wpx, hpx), Image.QUAD,
            (d, d, -d, hpx - d, wpx + d, hpx + d, wpx - d, -d),
            resample=Image.BILINEAR, fillcolor=(228, 224, 216))
        img = ImageEnhance.Brightness(img).enhance(0.97)
        img = ImageEnhance.Color(img).enhance(0.9)
        img = img.rotate(-1.3, resample=Image.BILINEAR,
                         fillcolor=(228, 224, 216))
        img.save(os.path.join(folder, 'input', 'photo.png'), optimize=True)
    finally:
        doc.close()
    return pdf_path


def _n(v):
    """Inches from an authored value dict WITHOUT parsing its string: the
    generator may only read numbers it authored. Falls back to a minimal
    literal read of the authored forms used in this file."""
    if not isinstance(v, dict):
        return None
    s = str(v.get('v', ''))
    # authored forms only: N', N'M", N", bare N — for drawing offsets only
    m = None
    import re as _re
    m = _re.match(r"^(\d+)'(?:\s*(\d+)\")?$|^(\d+(?:\.\d+)?)\"?$", s)
    if not m:
        return None
    if m.group(3) is not None:
        return float(m.group(3))
    return float(m.group(1)) * 12 + float(m.group(2) or 0)


# ------------------------------------------------------------------ main --

def emit(c):
    folder = os.path.join(OUT, c['name'])
    os.makedirs(os.path.join(folder, 'input'), exist_ok=True)
    if c['truth_rooms'] is not None:
        emit_json(os.path.join(folder, 'truth.json'),
                  {'generated_by': 'eval/gen-plans.py — truth authored first, '
                                   'plan derived from it',
                   'rooms': c['truth_rooms']})
    cj = {}
    if c['truth_ref']:
        cj['truth'] = c['truth_ref']
    if c['expects'] == 'probe':
        cj['probe'] = True
    elif c['expects']:
        cj['expects'] = c['expects']
    if cj:
        emit_json(os.path.join(folder, 'case.json'), cj)
    elif os.path.exists(os.path.join(folder, 'case.json')):
        os.remove(os.path.join(folder, 'case.json'))   # stale expectation
    emit_json(os.path.join(folder, 'takeoff.json'), takeoff_doc(c))
    with io.open(os.path.join(folder, 'README.md'), 'w', encoding='utf-8',
                 newline='\n') as f:
        f.write('# %s\n\n%s\n\n%s\n\nGenerated by `eval/gen-plans.py` — '
                'regenerate with `python eval/gen-plans.py %s`. Truth is '
                'authored in that file FIRST; the plan in `input/` is drawn '
                'from the truth, never the reverse.\n'
                % (c['name'], c['summary'], c['readme'].strip(), c['name']))
    plan = None
    src = c
    if c['truth_rooms'] is None and c['truth_ref']:
        # trap sibling: draw the SAME plan as the truth case
        base = next(x for x in CASES
                    if c['truth_ref'].split('/')[-2] == x['name'])
        src = dict(base)
        src['name'] = c['name']
        src['plan_notes'] = base['plan_notes']
        src['takeoff_rooms'] = base['takeoff_rooms']
    try:
        plan = draw_case(src, folder)
    except Exception as e:
        print('  (plan drawing failed for %s: %s)' % (c['name'], e))
    print('  %s%s' % (c['name'], '  (+plan.pdf, photo.png)' if plan else ''))


def main(argv):
    if '--list' in argv:
        for c in CASES:
            tag = (c['expects'] if isinstance(c['expects'], str)
                   else 'refusal' if 'refusal' in (c['expects'] or {})
                   else 'score_fail' if c['expects'] else 'build')
            print('  %-26s %-10s %s' % (c['name'], tag, c['summary']))
        return 0
    only = [a for a in argv if not a.startswith('-')]
    for c in CASES:
        if only and c['name'] not in only:
            continue
        emit(c)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
