# -*- coding: utf-8 -*-
"""RUN dimension-room-now.rb's pure section outside SketchUp.

    python rbtest-roomdims.py

Same VM and discipline as rbtest-boothdims.py: SketchUp's own CRuby 3.2 booted
through rbparse.py, the PURE SECTION lifted verbatim on every run.

WHAT IT ASSERTS
  1. offsets_for: the chain sits 36 in beyond the wall thickness from the
     interior face; doors and overall keep auto-dimension.rb's own band
     spacing, which is read out of that file's constants here, not retyped.
  2. run_thickness on a 144 x 120 rectangle built the way build-room.rb
     builds walls (outward, mitred): every run reads 4; a 6 in wall reads 6;
     reversed face normals still read; the inner face is never the answer.
  3. a wall split around a door (two pieces + header) still reads.
  4. a jog: the parallel wall one step further out does not win.
  5. nothing near the run reads nil; a face 30 in out is ignored.
  6. room_thickness: agree, disagree (thickest wins, flagged), none (4, flagged).
  7. verdict and line_for.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402

RB = os.path.join(HERE, 'dimension-room-now.rb')
ENGINE = os.path.join(HERE, 'auto-dimension.rb')

PROG = r'''
module WR_RoomDimsNow
@@PURE@@
end

$results = []
def check(name, got, want)
  $results << [name, got == want, "got #{got.inspect}, wanted #{want.inspect}"]
end
R = WR_RoomDimsNow

# 1 - offsets
o = R.offsets_for(4.0)
check('chain = 4 + 36 from the interior face', o[:seg], 40.0)
check('doors 13 beyond the chain', o[:door], 53.0)
check('overall 28 beyond the chain', o[:ovr], 68.0)
check('door step matches the engine', R::DOOR_STEP, @@DOOR@@ - @@SEG@@)
check('overall step matches the engine', R::OVR_STEP, @@OVR@@ - @@SEG@@)
check('6 in wall moves every row 2 in', R.offsets_for(6.0)[:seg], 42.0)

# a wall solid's four vertical faces, as [normal, points]
def box(x0, y0, x1, y1)
  [[[0.0, -1.0], [[x0, y0], [x1, y0]]],
   [[0.0, 1.0],  [[x0, y1], [x1, y1]]],
   [[-1.0, 0.0], [[x0, y0], [x0, y1]]],
   [[1.0, 0.0],  [[x1, y0], [x1, y1]]]]
end

# 144 x 120 room, CCW, walls t thick built outward (mitre = corner squares)
def rect_walls(t)
  box(-t, -t, 144.0 + t, 0.0) + box(-t, 120.0, 144.0 + t, 120.0 + t) +
    box(-t, 0.0, 0.0, 120.0) + box(144.0, 0.0, 144.0 + t, 120.0)
end

# 2
w = rect_walls(4.0)
check('south run reads 4', R.run_thickness([0.0, 0.0], [144.0, 0.0], [0.0, -1.0], w), 4.0)
check('east run reads 4',  R.run_thickness([144.0, 0.0], [144.0, 120.0], [1.0, 0.0], w), 4.0)
check('north run reads 4', R.run_thickness([144.0, 120.0], [0.0, 120.0], [0.0, 1.0], w), 4.0)
check('west run reads 4',  R.run_thickness([0.0, 120.0], [0.0, 0.0], [-1.0, 0.0], w), 4.0)
check('6 in walls read 6', R.run_thickness([0.0, 0.0], [144.0, 0.0], [0.0, -1.0], rect_walls(6.0)), 6.0)
rev = w.map { |n, pts| [[-n[0], -n[1]], pts] }
check('reversed normals still read', R.run_thickness([0.0, 0.0], [144.0, 0.0], [0.0, -1.0], rev), 4.0)
check('5.5 reads to the sixteenth', R.run_thickness([0.0, 0.0], [144.0, 0.0], [0.0, -1.0], rect_walls(5.5)), 5.5)

# 3 - door 36 wide at 50 on the south wall: two wall pieces + header
split = box(-4.0, -4.0, 50.0, 0.0) + box(86.0, -4.0, 148.0, 0.0) + box(50.0, -4.0, 86.0, 0.0)
check('split wall still reads', R.run_thickness([0.0, 0.0], [144.0, 0.0], [0.0, -1.0], split), 4.0)
no_header = box(-4.0, -4.0, 50.0, 0.0) + box(86.0, -4.0, 148.0, 0.0)
check('split wall without header still covers half', R.run_thickness([0.0, 0.0], [144.0, 0.0], [0.0, -1.0], no_header), 4.0)

# 4 - jog: run A (0..60, y=0); next parallel run B steps out 6 (y=-6, 60..144)
jog = box(-4.0, -4.0, 64.0, 0.0) + box(56.0, -10.0, 148.0, -6.0)
check('a parallel wall one jog out does not win', R.run_thickness([0.0, 0.0], [60.0, 0.0], [0.0, -1.0], jog), 4.0)
only_far = box(56.0, -10.0, 148.0, -6.0)
check('a jog wall that only clips the end is not this wall', R.run_thickness([0.0, 0.0], [60.0, 0.0], [0.0, -1.0], only_far), nil)

# 5
check('no faces reads nil', R.run_thickness([0.0, 0.0], [144.0, 0.0], [0.0, -1.0], []), nil)
check('a face 30 in out is ignored', R.run_thickness([0.0, 0.0], [144.0, 0.0], [0.0, -1.0], box(0.0, -34.0, 144.0, -30.0)), nil)
check('perpendicular faces never read', R.run_thickness([0.0, 0.0], [144.0, 0.0], [0.0, -1.0], [[[1.0, 0.0], [[10.0, -4.0], [10.0, 0.0]]]]), nil)

# 6
check('agreeing reads', R.room_thickness([4.0, 4.0, nil, 4.0]), [4.0, nil])
check('disagreeing reads take the thickest', R.room_thickness([4.0, 6.0]), [6.0, :disagree])
check('no reads fall back to 4', R.room_thickness([nil, nil]), [4.0, :fallback])

# 7
c = { :skew => 0, :dx => 0.0, :dy => 0.01, :gap_x => 0.0, :gap_y => 0.0 }
check('closes', R.verdict(c), :closes)
check('open', R.verdict(c.merge(:gap_x => 0.5)), :open)
check('skew', R.verdict(c.merge(:skew => 1)), :skew)
check('line', R.line_for('Room', 4, 6, 1, :closes, 4.0, nil),
      'Room: 4 runs, 6 dims, 1 door, chains close (walls 4")')
check('fallback line', R.line_for('A', 6, 12, 2, :open, 4.0, :fallback),
      'A: 6 runs, 12 dims, 2 doors, CHAINS DO NOT CLOSE (walls unread, 4" assumed)')

out = $results.map { |(n, ok, d)| (ok ? 'PASS ' : 'FAIL ') + n + (ok ? '' : '   ' + d) }
(out.join("\n") + "\n" + $results.count { |r| !r[1] }.to_s + ' failure(s)').dup
'''


def pure_section(src):
    lines = src.splitlines()
    start = end = None
    for i, ln in enumerate(lines):
        if start is None and 'PURE SECTION' in ln and ln.lstrip().startswith('#'):
            start = i
        if start is not None and i > start and ln.lstrip().startswith('# ---- END PURE'):
            end = i
            break
    if start is None or end is None:
        raise SystemExit('dimension-room-now.rb: PURE SECTION / END PURE markers not found')
    return '\n'.join(lines[start:end])


def engine_const(src, name):
    m = re.search(r'^\s*%s\s*=\s*([0-9.]+)' % name, src, re.M)
    if not m:
        raise SystemExit('auto-dimension.rb: constant %s not found' % name)
    return m.group(1)


def main():
    src = open(RB, encoding='utf-8').read()
    eng = open(ENGINE, encoding='utf-8').read()
    prog = (PROG.replace('@@PURE@@', pure_section(src))
                .replace('@@SEG@@', engine_const(eng, 'SEG_OFF'))
                .replace('@@DOOR@@', engine_const(eng, 'DOOR_OFF'))
                .replace('@@OVR@@', engine_const(eng, 'OVR_OFF')))
    got = rbparse.rb_eval(rbparse.boot(), prog)
    print(got)
    if got.startswith('FAIL ') or 'error' in got[:40].lower():
        return 1
    return 0 if got.rstrip().endswith('0 failure(s)') else 1


if __name__ == '__main__':
    sys.exit(main())
