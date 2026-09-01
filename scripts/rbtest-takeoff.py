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
end

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

out = results.map { |(n, ok, d)| (ok ? 'PASS ' : 'FAIL ') + n + (ok ? '' : '   ' + d) }
(out.join("\n") + "\n" + results.count { |r| !r[1] }.to_s + ' failure(s)').dup
'''


def main():
    prog = PROG % {
        'door_errors': method_source(os.path.join(HERE, 'build-room.rb'),
                                     'door_errors'),
        'lock_errors': method_source(os.path.join(HERE, 'build-takeoff.rb'),
                                     'lock_errors'),
    }
    lib = rbparse.boot()
    got = rbparse.rb_eval(lib, prog)
    print(got)
    if got.startswith('FAIL '):        # a raise inside the harness
        return 1
    return 0 if got.rstrip().endswith('0 failure(s)') else 1


if __name__ == '__main__':
    sys.exit(main())
