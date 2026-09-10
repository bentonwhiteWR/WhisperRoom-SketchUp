# -*- coding: utf-8 -*-
"""RUN the wall-part test outside SketchUp: the box branch, the panel branch,
and the refusals.

    python rbtest-wall-part.py                 # against build-booth-components.rb
    python rbtest-wall-part.py --src FILE      # against a copy (mutation checks)

Same discipline as rbtest.py: boots SketchUp's own CRuby 3.2 through rbparse.py
and lifts `height_axis` and `panel_axis` VERBATIM out of
build-booth-components.rb, plus the two constants, so this cannot drift from
the code it tests.

WHY IT EXISTS
-------------
Benton, 2026-09-10, with a screenshot: 46Vnt_VSS_EFS_CP.skp exists on the
share and the builder refused it on N0 and E0 — "no axis measures 81 in, not a
wall part". The panel inside it IS 81 (edge faces at 1.3125 and 82.3125,
_face-levels.tsv); the assembly boxes 87.0625 because the EFS foot hangs
1.3125 below the panel and the caster plate 4.75 below that, and 6.0625 is a
sixteenth over the old +/-6 box tolerance. Thirteen siblings fail the same way
(the whole 40 in EFS/CP family, both SideVent_VSS_EFS_CP, every _HX twin).
The rule now measures the panel when the box fails. This file pins that, and
pins that nothing which passed before is classified any differently.

WHAT IT ASSERTS
  1. THE REPORTED PART: 46Vnt_VSS_EFS_CP's measured box and face set is
     accepted on the :panel route, on the Z axis, with the faces returned.
  2. NO-OP FOR PASSING PARTS: 46VntCP (box 86.6128) and plain 46VNT are
     accepted on the :box route WITHOUT the face block ever being called —
     the block raises if it runs, so a leak into the panel path fails loudly.
  3. HX: the same part's _HX twin (panel 91, box 97.0625) is accepted on the
     panel route at want 91; the NON-HX part offered to an HX slot is refused.
  4. WRONG PARTS STAY WRONG: a floor deck (48 x 72 x 3.108) is refused; a
     part with an 81 in face on TWO axes is refused as ambiguous; an Enhanced
     79.5 panel offered to a Standard slot is refused (1.5 > PANEL_FACE_TOL).
  5. THE CONSTANTS: BOX_H_TOL is 6.0 and PANEL_FACE_TOL is 1.0, and
     PANEL_FACE_TOL < 1.5 (the Std/Enh height gap) — the tightness that keeps
     4's last case refused.

MUTATION-CHECKED when written (2026-09-10), each against a scratch copy:
  - delete the `boxes = yield` panel branch      -> 6 checks fail
  - PANEL_FACE_TOL = 2.0                         -> 3 fail (ENH-in-Standard among them)
  - `axes.length == 1` -> `axes.length >= 1`     -> 1 fails (the ambiguity check)
  - BOX_H_TOL = 7.0                              -> 4 fail (check 1 lands on :box)
Baseline: 0 failures. The two fixtures that first exercised the OLD branch by
accident (an 87 in assembly at 91 is inside +/-6; [81,10,81] passes on X) were
rewritten so the box fails first - see the comments beside them.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402
from rbtest import method_source  # noqa: E402

PROG = r'''
class Float
  def to_f; self; end
end
class Integer
  def to_f; self * 1.0; end
end

module WR_BuildBoothComponents
  BOX_H_TOL      = %(box_tol)s
  PANEL_FACE_TOL = %(face_tol)s

%(height_axis)s

%(panel_axis)s
end

$results = []
def check(name, got, want)
  $results << [name, got == want, "got #{got.inspect}, wanted #{want.inspect}"]
end
M = WR_BuildBoothComponents
NEVER = lambda { raise 'the face block ran for a part whose box passes' }

# 1 - 46Vnt_VSS_EFS_CP, as measured (_component-probe.tsv / _face-levels.tsv):
#     box 12.125 x 58.625 x 87.0625 (z -4.75 .. 82.3125); panel faces z 1.3125
#     .. 82.3125 = 81.000; caster plate z -4.75 .. -3.4375; silencer stack tall
#     but short of the panel; a few small horizontal faces.
E_CP  = [12.125, 58.625, 87.0625]
FACES_CP = [
  [[0.0, 1.0],   [6.3125, 52.3125], [1.3125, 82.3125]],   # the panel, front face
  [[0.0, 1.0],   [6.3125, 52.3125], [1.3125, 82.3125]],   # the panel, back face
  [[0.0, 12.125],[0.0, 58.625],     [-4.75, -3.4375]],    # caster plate
  [[1.0, 12.125],[46.0, 58.625],    [5.5625, 77.3281]],   # silencer stack, 71.8 tall
  [[0.0, 1.0],   [6.3125, 52.3125], [82.3125, 82.3125]],  # panel top edge
  [[0.0, 1.0],   [6.3125, 52.3125], [1.3125, 1.3125]]     # panel bottom edge
]
r = M.height_axis(E_CP, 81.0) { FACES_CP }
check('46Vnt_VSS_EFS_CP accepted', r.nil?, false)
check('46Vnt_VSS_EFS_CP accepted on the PANEL route', r && r[1], :panel)
check('46Vnt_VSS_EFS_CP height axis is Z', r && r[0], 2)
check('46Vnt_VSS_EFS_CP hands the faces back for wall_slab', r && r[2].equal?(FACES_CP), true)

# 2 - parts that pass today pass exactly as before, and never touch the faces
r = M.height_axis([8.5468, 46.0, 86.6128], 81.0, &NEVER)      # 46VntCP
check('46VntCP accepted on the BOX route', r, [2, :box, nil])
r = M.height_axis([8.5468, 46.0, 81.8628], 81.0, &NEVER)      # 46VNT
check('46VNT accepted on the BOX route', r, [2, :box, nil])
r = M.height_axis([46.0, 8.6003, 92.17], 91.0, &NEVER)        # LeftSideVent_VSS_HX
check('an HX part on the box route at 91', r, [2, :box, nil])

# 3 - HX
FACES_CP_HX = FACES_CP.map { |b| [b[0], b[1], [b[2][0] + 5.0, b[2][1] + 15.0]] }
FACES_CP_HX[0] = [[0.0, 1.0], [6.3125, 52.3125], [6.0625, 97.0625]]   # 91 panel
FACES_CP_HX[1] = FACES_CP_HX[0]
r = M.height_axis([12.125, 58.625, 97.0625], 91.0) { FACES_CP_HX }
check('46Vnt_VSS_EFS_CP_HX accepted on the panel route at 91', r && r[1], :panel)
# The plain 46VNT (box 81.8628) in an HX slot: 9.1 off, so the box fails and
# the panel route must say no because its only tall face is 81, not 91.
# (The CP assembly itself, 87.0625, is inside the box rule's +/-6 of 91 and
# always was - a looseness of the OLD branch this fix neither adds nor removes;
# no pack composes a non-HX name for an HX slot, so no name reaches it.)
r = M.height_axis([8.5468, 46.0, 81.8628], 91.0) { [[[0.0, 1.0], [0.0, 46.0], [0.0, 81.0]]] }
check('a non-HX panel offered to an HX slot is refused on the panel route', r, nil)

# 4 - wrong parts stay wrong
r = M.height_axis([48.0, 72.0, 3.108], 81.0) { [[[0.0, 48.0], [0.0, 72.0], [1.0, 1.0]]] }
check('a floor deck is refused', r, nil)
# The box must FAIL first (90 on both long axes, 9 off) so the panel route is
# the one deciding; it then sees an 81 in face on X and another on Z.
two = [[[0.0, 81.0], [0.0, 1.0], [0.0, 10.0]], [[0.0, 1.0], [0.0, 10.0], [0.0, 81.0]]]
r = M.height_axis([90.0, 10.0, 90.0], 81.0) { two }
check('an 81 in face on TWO axes is refused as ambiguous', r, nil)
enh = [[[0.0, 1.0], [0.0, 41.5], [0.0, 79.5]]]
r = M.height_axis([1.0, 41.5, 100.0], 81.0) { enh }
check('an Enhanced 79.5 panel offered to a Standard slot is refused', r, nil)
r = M.height_axis([1.0, 41.5, 100.0], 79.5) { enh }
check('...and accepted at its own 79.5', r && r[1], :panel)

# 5 - the constants
check('BOX_H_TOL is the old 6.0', M::BOX_H_TOL, 6.0)
check('PANEL_FACE_TOL is 1.0', M::PANEL_FACE_TOL, 1.0)
check('PANEL_FACE_TOL is under the 1.5 Std/Enh gap', M::PANEL_FACE_TOL < 1.5, true)

out = $results.map { |(n, ok, d)| (ok ? 'PASS ' : 'FAIL ') + n + (ok ? '' : '   ' + d) }
(out.join("\n") + "\n" + $results.count { |r| !r[1] }.to_s + ' failure(s)').dup
'''


def const(text, name):
    import re
    m = re.search(r'^  %s\s*=\s*([\d.]+)' % name, text, re.M)
    if not m:
        raise SystemExit('build-booth-components.rb: %s not found' % name)
    return m.group(1)


def main():
    src = os.path.join(HERE, 'build-booth-components.rb')
    if '--src' in sys.argv:
        src = sys.argv[sys.argv.index('--src') + 1]
    text = open(src, encoding='utf-8').read()
    prog = PROG % {'box_tol': const(text, 'BOX_H_TOL'),
                   'face_tol': const(text, 'PANEL_FACE_TOL'),
                   'height_axis': method_source(src, 'height_axis'),
                   'panel_axis': method_source(src, 'panel_axis')}
    lib = rbparse.boot()
    got = rbparse.rb_eval(lib, prog)
    print('wall-part test: box route, panel route, refusals  (%s)' % os.path.basename(src))
    print(got)
    return 0 if got.rstrip().endswith('0 failure(s)') else 1


if __name__ == '__main__':
    sys.exit(main())
