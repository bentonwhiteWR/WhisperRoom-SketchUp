# -*- coding: utf-8 -*-
"""RUN the take-off pipeline's pure Ruby methods outside SketchUp.

    python rbtest-takeoff.py

Same discipline as rbtest.py / rbtest-proposal.py: boots SketchUp 2024's own
CRuby 3.2 via rbparse.py, lifts the methods VERBATIM out of the scripts (so
the test can never drift from the code), and runs them on synthetic input.

Covered here, offline:
  - WR_BuildRoom.door_errors   (build-room.rb) — the corner-door refusal
    that replaces the silent leaf-in-solid-wall defect
  - WR_BuildTakeoff.lock_errors (build-takeoff.rb) — the builder's own
    re-validation, what makes "force it past the checker" fail by name

  - WR_BuildTakeoff.door_jambs (build-takeoff.rb, 1.84.0) — the doors the
    builder now hands the dimension engine, from the lock's own numbers
  - WR_AutoDimension.door_corner / closure / coverage (auto-dimension.rb,
    1.84.0) and WR_RoomDimsNow.verdict / line_for (dimension-room-now.rb):
    doors off their NEAR corner, and the chain-closure verdict on the CCU
    Sands Hall 113 outline (a free-standing pilaster that used to read
    "CHAINS DO NOT CLOSE", y +18") plus chains that genuinely do not close

NOT covered (impure, verified live through the bridge on 31 Aug 2026 —
see DEVLOG): build_from, build_feature, place_notes, takeoff_readback.

Mutation-checked when written: weaken door_errors' corner test to `at < 0`
and de1/de2 FAIL; drop lock_errors' ceiling clause and le3 FAILs.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402
from rbtest import method_source  # noqa: E402

SHIMS = r'''
class Float
  def to_f; self; end
end
class Integer
  def to_f; self * 1.0; end
  def to_i; self; end      # absent in the minimal VM, like Object#class
end

# Just enough Geom for door_errors: points that subtract into a vector with
# a length. The real Geom::Point3d does exactly this much here.
class Pt
  attr_reader :x, :y
  def initialize(x, y); @x = x; @y = y; end
  def -(o); Vec.new(@x - o.x, @y - o.y); end
end
class Vec
  def initialize(x, y); @x = x; @y = y; end
  def length; Math.sqrt(@x * @x + @y * @y); end
end
'''

PROG = SHIMS + r'''
module WR_BuildRoom
  DIR = { 'E' => [1, 0], 'W' => [-1, 0], 'N' => [0, 1], 'S' => [0, -1] }.freeze
  TOL = 0.02

%(door_errors)s
end

module WR_BuildTakeoff
  TOL = 0.02

%(lock_errors)s

%(door_jambs)s
end

module WR_AutoDimension
  TOL = 0.02

%(door_corner)s

%(closure)s

%(coverage)s
end

module WR_RoomDimsNow
%(verdict)s

%(inches)s

%(line_for)s
end

# Plain stand-ins for Geom::Point3d / Vector3d / BoundingBox: closure reads
# only .x / .y off the run points and vectors, and width / height / min off
# the box - exactly what the real classes answer.
class P2
  attr_reader :x, :y
  def initialize(x, y); @x = x * 1.0; @y = y * 1.0; end
end
class Box2
  attr_reader :min, :width, :height
  def initialize(pts)
    xs = pts.map(&:x); ys = pts.map(&:y)
    @min = P2.new(xs.min, ys.min)
    @width = xs.max - xs.min
    @height = ys.max - ys.min
  end
end
DIRV = { 'E' => [1, 0], 'W' => [-1, 0], 'N' => [0, 1], 'S' => [0, -1] }
# A run list [[d, inches], ...] -> engine runs (:a, :b, :vec) and its box,
# walked from (0, 0) exactly as build-room.rb's polygon walks a take-off.
def engine_runs(list)
  x = 0.0; y = 0.0
  runs = list.map do |d, v|
    a = P2.new(x, y)
    x += DIRV[d][0] * v; y += DIRV[d][1] * v
    b = P2.new(x, y)
    { :a => a, :b => b, :vec => P2.new(b.x - a.x, b.y - a.y) }
  end
  [runs, Box2.new(runs.map { |r| r[:a] } + runs.map { |r| r[:b] })]
end
# The same outline walked the OTHER way round (the floor face's loop may run
# either way; the verdict must not depend on it).
def reversed(list)
  flip = { 'E' => 'W', 'W' => 'E', 'N' => 'S', 'S' => 'N' }
  list.reverse.map { |d, v| [flip[d], v] }
end

# CCU Sands Hall 113 as taken off (clients/ccu-sands-hall-113/takeoff.json,
# 6 Oct 2026): north wall E, east wall S, then the south wall west with the
# free-standing pilaster (N 18, W 12, S 18) and the corner pilaster (N 18,
# W 7 1/8), then the west wall N. The outline closes to 0.00 both ways.
CCU = [['E', 458.125], ['S', 421.125], ['W', 178.0], ['N', 18.0], ['W', 12.0],
       ['S', 18.0], ['W', 261.0], ['N', 18.0], ['W', 7.125], ['N', 403.125]]

RECT = [Pt.new(0, 0), Pt.new(144, 0), Pt.new(144, -120), Pt.new(0, -120)]

def lock(rooms)
  { 'rooms' => rooms }
end

def room(over = {})
  { 'name' => 'T',
    'runs' => [{ 'd' => 'E', 'in' => 144.0 }, { 'd' => 'S', 'in' => 120.0 },
               { 'd' => 'W', 'in' => 144.0 }, { 'd' => 'N', 'in' => 120.0 }],
    'ceiling' => { 'in' => 102.0 },
    'doors' => [] }.merge(over)
end

results = []
def check(results, name, ok, detail)
  results << [name, ok, detail]
end

# --- door_errors ---------------------------------------------------------
e = WR_BuildRoom.door_errors(RECT, [{ 'run' => 0, 'at' => 0, 'w' => 36 }])
check(results, 'de1 corner door refused by name',
      e.length == 1 && e[0].include?('touches the corner'), e.inspect)
e = WR_BuildRoom.door_errors(RECT, [{ 'run' => 0, 'at' => 120, 'w' => 36 }])
check(results, 'de2 overrun door refused', e.length == 1 &&
      e[0].include?('touches the corner'), e.inspect)
e = WR_BuildRoom.door_errors(RECT, [{ 'run' => 0, 'at' => 36, 'w' => 36 }])
check(results, 'de3 mid-wall door passes', e.empty?, e.inspect)
e = WR_BuildRoom.door_errors(RECT, [{ 'run' => 9, 'at' => 36, 'w' => 36 }])
check(results, 'de4 bad run index named', e.length == 1 &&
      e[0].include?('run 9 does not exist'), e.inspect)
e = WR_BuildRoom.door_errors(RECT, [{ 'run' => 0, 'at' => 36, 'w' => 0 }])
check(results, 'de5 zero width named', e.length == 1 &&
      e[0].include?('width must be positive'), e.inspect)

# --- lock_errors ---------------------------------------------------------
e = WR_BuildTakeoff.lock_errors(lock([room]))
check(results, 'le1 clean lock passes', e.empty?, e.inspect)
e = WR_BuildTakeoff.lock_errors(lock([room('runs' => [
  { 'd' => 'E', 'in' => 144.0 }, { 'd' => 'S', 'in' => 120.0 },
  { 'd' => 'W', 'in' => 140.0 }, { 'd' => 'N', 'in' => 120.0 }])]))
check(results, 'le2 non-closing runs named', e.length == 1 &&
      e[0].include?('do not close'), e.inspect)
e = WR_BuildTakeoff.lock_errors(lock([room('ceiling' => nil)]))
check(results, 'le3 missing ceiling named', e.length == 1 &&
      e[0].include?('no ceiling height'), e.inspect)
e = WR_BuildTakeoff.lock_errors(lock([room('doors' => [
  { 'run' => 0, 'at_in' => 0.0, 'w_in' => 36.0, 'h_in' => 80.0 }])]))
check(results, 'le4 corner door named', e.length == 1 &&
      e[0].include?('touches the corner'), e.inspect)
e = WR_BuildTakeoff.lock_errors(lock([room('doors' => [
  { 'run' => 0, 'at_in' => 20.0, 'w_in' => 30.0, 'h_in' => 80.0 },
  { 'run' => 0, 'at_in' => 60.0, 'w_in' => 30.0, 'h_in' => 84.0 }])]))
check(results, 'le5 mixed door heights on one run named', e.length == 1 &&
      e[0].include?('different heights'), e.inspect)

# --- 1.12.x: F2/F3 from eval/floorplans/synthetic-headroom ----------------
e = WR_BuildTakeoff.lock_errors(lock([room('doors' => [
  { 'run' => 0, 'at_in' => 36.0, 'w_in' => 36.0, 'h_in' => 110.0 }])]))
check(results, 'le6 door taller than ceiling named', e.length == 1 &&
      e[0].include?('taller than its ceiling'), e.inspect)
e = WR_BuildTakeoff.lock_errors(lock([room('features' => [
  { 'type' => 'bulkhead', 'run' => 0, 'from_in' => 24.0,
    'length_in' => 60.0, 'head_in' => 108.0 }])]))
check(results, 'le7 bulkhead head above ceiling named', e.length == 1 &&
      e[0].include?('head at or above the ceiling'), e.inspect)
e = WR_BuildTakeoff.lock_errors(lock([room('features' => [
  { 'type' => 'window', 'run' => 0, 'from_in' => 24.0,
    'width_in' => 36.0, 'sill_in' => 102.0 }])]))
check(results, 'le8 window sill at ceiling named', e.length == 1 &&
      e[0].include?('sill at or above the ceiling'), e.inspect)
e = WR_BuildTakeoff.lock_errors(lock([room('features' => [
  { 'type' => 'bulkhead', 'run' => 0, 'from_in' => 24.0,
    'length_in' => 60.0, 'head_in' => 99.0 }])]))
check(results, 'le9 real bulkhead still passes', e.empty?, e.inspect)

# --- 1.84.0: doors are dimensioned, off their near corner ----------------
pts = [[0.0, 0.0], [458.125, 0.0], [458.125, -421.125], [280.125, -421.125]]
j = WR_BuildTakeoff.door_jambs(pts, [{ 'run' => 0, 'at_in' => 6.125, 'w_in' => 36.0 }])
check(results, 'dj1 CCU door: jambs at 6 1/8 and 42 1/8 along the north wall',
      j == [[0, [6.125, 0.0], [42.125, 0.0]]], j.inspect)
j = WR_BuildTakeoff.door_jambs(pts, [{ 'run' => 1, 'at_in' => 30.0, 'w_in' => 36.0 }])
check(results, 'dj2 a door on a south-running wall runs south',
      j == [[1, [458.125, -30.0], [458.125, -66.0]]], j.inspect)
j = WR_BuildTakeoff.door_jambs(pts, [{ 'run' => 9, 'at_in' => 6.0, 'w_in' => 36.0 },
                                     { 'run' => 0, 'at_in' => 50.0, 'w_in' => 30.0 }])
check(results, 'dj3 a bad run is skipped (lock_errors refuses it), the real door comes back',
      j.length == 1 && j[0][0] == 0, j.inspect)
dc = WR_AutoDimension.door_corner(458.125, 6.125, 42.125)
check(results, 'dc1 CCU door, loop from the NW corner: 6 1/8 off NW, then 36',
      dc[:from] == :a && dc[:near] == 6.125 && (dc[:far] - dc[:near] - 36.0).abs < 1e-9,
      dc.inspect)
dc = WR_AutoDimension.door_corner(458.125, 416.0, 452.0)
check(results, 'dc2 the same door with the loop the other way (the old 34-8 read): ' +
      'still 6 1/8 off the NW corner',
      dc[:from] == :b && (458.125 - dc[:near] - 6.125).abs < 1e-9 &&
      (dc[:near] - dc[:far] - 36.0).abs < 1e-9, dc.inspect)
dc = WR_AutoDimension.door_corner(100.0, 32.0, 68.0)
check(results, 'dc3 a dead-centre door ties to the run start', dc[:from] == :a, dc.inspect)

# --- 1.84.0: chain closure with a free-standing pilaster ------------------
r, b = engine_runs(CCU)
c = WR_AutoDimension.closure(r, b)
v = WR_RoomDimsNow.verdict(c)
check(results, 'cl1 CCU outline CLOSES (the free pilaster used to read y +18)',
      v == :closes && c[:gap_x].abs < 1e-6 && c[:gap_y].abs < 1e-6 && c[:dx].abs < 1e-6 &&
      c[:dy].abs < 1e-6, c.inspect)
check(results, 'cl2 and the pilaster faces are reported as 18 in doubled back, not hidden',
      (c[:jog_y] - 18.0).abs < 1e-6 && c[:jog_x].abs < 1e-6, c.inspect)
check(results, 'cl3 the room line says chains close',
      WR_RoomDimsNow.line_for('Sands Hall 113', 10, 22, 1, v, 4.0, nil)
        .include?('chains close'), v.inspect)
r, b = engine_runs(reversed(CCU))
c = WR_AutoDimension.closure(r, b)
check(results, 'cl4 the same outline wound the other way also closes',
      WR_RoomDimsNow.verdict(c) == :closes, c.inspect)
r, b = engine_runs([['E', 120.0], ['S', 30.0], ['W', 40.0], ['S', 50.0], ['W', 80.0], ['N', 80.0]])
c = WR_AutoDimension.closure(r, b)
check(results, 'cl5 a plain L still closes, with nothing doubled back',
      WR_RoomDimsNow.verdict(c) == :closes && c[:jog_x].abs < 1e-9 && c[:jog_y].abs < 1e-9,
      c.inspect)
r, b = engine_runs([['E', 144.0], ['S', 50.0], ['W', 30.0], ['N', 20.0], ['W', 30.0],
                    ['S', 20.0], ['W', 84.0], ['N', 50.0]])
c = WR_AutoDimension.closure(r, b)
check(results, 'cl6 a notch in another room closes too (20 in doubled back on y)',
      WR_RoomDimsNow.verdict(c) == :closes && (c[:jog_y] - 20.0).abs < 1e-9, c.inspect)

# --- and a chain that genuinely does NOT close still says so --------------
r, b = engine_runs([['E', 144.0], ['S', 120.0], ['W', 140.0], ['N', 120.0]])
c = WR_AutoDimension.closure(r, b)
v = WR_RoomDimsNow.verdict(c)
check(results, 'nc1 a west wall misread 4 in short: DOES NOT CLOSE',
      v == :open && (c[:dx] - 4.0).abs < 1e-9, c.inspect)
check(results, 'nc2 and the room line says CHAINS DO NOT CLOSE',
      WR_RoomDimsNow.line_for('T', 4, 10, 0, v, 4.0, nil).include?('CHAINS DO NOT CLOSE'),
      v.inspect)
bad = CCU.dup
bad[6] = ['W', 243.0]                 # 21'-9" misread as 20'-3": 18 in short
r, b = engine_runs(bad)
c = WR_AutoDimension.closure(r, b)
check(results, 'nc3 CCU with one run misread by exactly the pilaster depth still ' +
      'DOES NOT CLOSE (the doubled-back allowance cannot absorb it)',
      WR_RoomDimsNow.verdict(c) == :open, c.inspect)
r, b = engine_runs([['E', 100.0], ['S', 40.0], ['W', 100.0], ['N', 30.0]])
c = WR_AutoDimension.closure(r, b)
check(results, 'nc4 a side 10 in short on the vertical: DOES NOT CLOSE',
      WR_RoomDimsNow.verdict(c) == :open && (c[:dy] + 10.0).abs < 1e-9, c.inspect)
# Runs that return to the start but leave a stretch of the overall
# uncovered: unreachable from a real face, so built by hand here - it is the
# one case the coverage gap (not :dx) has to catch on its own.
c = WR_AutoDimension.closure(
  [{ :a => P2.new(0, 0), :b => P2.new(40, 0), :vec => P2.new(40, 0) },
   { :a => P2.new(40, 0), :b => P2.new(0, 0), :vec => P2.new(-40, 0) }],
  Box2.new([P2.new(0, 0), P2.new(100, 10)]))
check(results, 'nc5 runs that cover only 40 of a 100 in overall: DOES NOT CLOSE',
      WR_RoomDimsNow.verdict(c) == :open && (c[:gap_x] + 60.0).abs < 1e-9, c.inspect)

out = results.map { |(n, ok, d)| (ok ? 'PASS ' : 'FAIL ') + n + (ok ? '' : '   ' + d) }
(out.join("\n") + "\n" + results.count { |r| !r[1] }.to_s + ' failure(s)').dup
'''


def main():
    prog = PROG % {
        'door_errors': method_source(os.path.join(HERE, 'build-room.rb'),
                                     'door_errors'),
        'lock_errors': method_source(os.path.join(HERE, 'build-takeoff.rb'),
                                     'lock_errors'),
        'door_jambs': method_source(os.path.join(HERE, 'build-takeoff.rb'),
                                    'door_jambs'),
        'door_corner': method_source(os.path.join(HERE, 'auto-dimension.rb'),
                                     'door_corner'),
        'closure': method_source(os.path.join(HERE, 'auto-dimension.rb'),
                                 'closure'),
        'coverage': method_source(os.path.join(HERE, 'auto-dimension.rb'),
                                  'coverage'),
        'verdict': method_source(os.path.join(HERE, 'dimension-room-now.rb'),
                                 'verdict'),
        'inches': method_source(os.path.join(HERE, 'dimension-room-now.rb'),
                                'inches'),
        'line_for': method_source(os.path.join(HERE, 'dimension-room-now.rb'),
                                  'line_for'),
    }
    lib = rbparse.boot()
    got = rbparse.rb_eval(lib, prog)
    print(got)
    if got.startswith('FAIL '):        # a raise inside the harness
        return 1
    return 0 if got.rstrip().endswith('0 failure(s)') else 1


if __name__ == '__main__':
    sys.exit(main())
