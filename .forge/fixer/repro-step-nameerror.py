# -*- coding: utf-8 -*-
"""Reproduce Benton's two 'load booth from link' defects OUTSIDE SketchUp.

    python .forge/fixer/repro-step-nameerror.py

Benton, 11 Sep 2026: "The Step is not loading at all. Also, booths with a CP
need to start up higher when loaded. They need to load up 4 3/4" higher."

This lifts WR_Overlays.place_step VERBATIM out of scripts/wr-overlays.rb
(plus the pure helpers it calls) and runs it in the CRuby 3.2 DLL that
SketchUp ships (scripts/rbparse.py boots it), with the SketchUp-only pieces
stubbed: Geom::{Point3d,Vector3d,Transformation} as a small real linear
algebra, load_def returning a fake definition, geom_extents answering the
44 x 12 x 5 box the DEVLOG records for the step part, and add() recording
the box the instance would land in.

Then it emulates the CALLER'S control flow exactly as build_booth has it:

    casters_in = false
    begin
      oc, owarn, casters_in = WR_Overlays.place_all(...)   # plates go in, then the step
    rescue Exception => e
      warn << "OVERLAYS FAILED ..."
    end
    lift = WR_Overlays.booth_lift(casters_in, stack_bottom)

and prints what the ground lift comes out as. Run BEFORE the fix it shows the
defect; AFTER the fix it must print PASS. It is deliberately a standalone
script, not a harness pin — the permanent pin lives in scripts/rbtest-overlays.py.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.normpath(os.path.join(HERE, '..', '..', 'scripts'))
sys.path.insert(0, SCRIPTS)
import rbparse  # noqa: E402
import importlib  # noqa: E402
rbo = importlib.import_module('rbtest-overlays')  # noqa: E402  (lift_* helpers)

SRC = os.path.join(SCRIPTS, 'wr-overlays.rb')

METHODS = ['kind_of', 'wall_of', 'booth_lift', 'step_ground_z', 'step_blockers',
           'step_seat', 'place_step']
SCALARS = ['CP_BOOTH_LIFT', 'CP_TRAY_DEPTH', 'CP_PLATE_HEIGHT', 'STEP_DEPTH',
           'STEP_ALONG_OFFSET']

STUBS = r'''
class Float
  def to_f; self; end
end
class Integer
  def to_f; self * 1.0; end
  def degrees; self * Math::PI / 180.0; end
end
class Float
  def degrees; self * Math::PI / 180.0; end
end

module Geom
  class Vector3d
    attr_reader :x, :y, :z
    def initialize(x, y, z); @x = x.to_f; @y = y.to_f; @z = z.to_f; end
    def *(o)   # cross product, as the SketchUp API defines Vector3d#*
      Vector3d.new(@y * o.z - @z * o.y, @z * o.x - @x * o.z, @x * o.y - @y * o.x)
    end
    def transform(t); t.apply_v(self); end
  end
  class Point3d
    attr_reader :x, :y, :z
    def initialize(x, y, z); @x = x.to_f; @y = y.to_f; @z = z.to_f; end
    def transform(t); t.apply_p(self); end
  end
  class Transformation
    attr_reader :m, :o
    def initialize(m = nil, o = nil)
      @m = m || [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
      @o = o || [0.0, 0.0, 0.0]
    end
    # "turns the standard axes into the given axes": columns are the axes.
    def self.axes(_origin, xa, ya, za)
      new([[xa.x, ya.x, za.x], [xa.y, ya.y, za.y], [xa.z, ya.z, za.z]],
          [_origin.x, _origin.y, _origin.z])
    end
    def self.translation(v); new(nil, [v.x, v.y, v.z]); end
    # Rodrigues, about an axis through pt.
    def self.rotation(pt, axis, ang)
      k = [axis.x, axis.y, axis.z]
      c = Math.cos(ang); s = Math.sin(ang); t = 1.0 - c
      m = [[c + k[0]*k[0]*t,        k[0]*k[1]*t - k[2]*s,  k[0]*k[2]*t + k[1]*s],
           [k[1]*k[0]*t + k[2]*s,   c + k[1]*k[1]*t,       k[1]*k[2]*t - k[0]*s],
           [k[2]*k[0]*t - k[1]*s,   k[2]*k[1]*t + k[0]*s,  c + k[2]*k[2]*t]]
      p = [pt.x, pt.y, pt.z]
      rp = (0..2).map { |i| (0..2).inject(0.0) { |a, j| a + m[i][j] * p[j] } }
      new(m, (0..2).map { |i| p[i] - rp[i] })
    end
    def mul_v(v); (0..2).map { |i| (0..2).inject(0.0) { |a, j| a + @m[i][j] * v[j] } }; end
    def *(other)   # self * other: other first, then self
      m = (0..2).map { |i| (0..2).map { |j| (0..2).inject(0.0) { |a, k| a + @m[i][k] * other.m[k][j] } } }
      o = mul_v(other.o)
      Transformation.new(m, (0..2).map { |i| o[i] + @o[i] })
    end
    def apply_v(v); r = mul_v([v.x, v.y, v.z]); Vector3d.new(r[0], r[1], r[2]); end
    def apply_p(p); r = mul_v([p.x, p.y, p.z]); Point3d.new(r[0] + @o[0], r[1] + @o[1], r[2] + @o[2]); end
  end
end

module WR_BuildBoothComponents
  def self.load_def(_model, _dir, name, cache)
    cache[name] = { :name => name }
  end
end
'''

FIXTURE = r'''
module WR_Overlays
  STEP_NAME = 'Step'.freeze
  STEP_FRONT_AWAY = true
__CONSTS__

__METHODS__

  # ---- stubs for the SketchUp-only calls place_step makes ----
  @log = []
  @added = []
  def self.log; @log; end
  def self.added; @added; end
  def self.puts(*a); @log << a.join(' '); nil; end
  def self.geom_extents(_defn)
    { :lo => [0.0, 0.0, 0.0], :hi => [44.0, 12.0, 5.0], :e => [44.0, 12.0, 5.0] }
  end
  def self.add(_booth, defn, tr, name, _layer)
    pts = []
    [0.0, 44.0].each { |px| [0.0, 12.0].each { |py| [0.0, 5.0].each { |pz|
      pts << Geom::Point3d.new(px, py, pz).transform(tr) } } }
    box = [[pts.map { |q| q.x }.min, pts.map { |q| q.x }.max],
           [pts.map { |q| q.y }.min, pts.map { |q| q.y }.max],
           [pts.map { |q| q.z }.min, pts.map { |q| q.z }.max]]
    @added << [name, box]
    format('%.2f..%.2f %.2f..%.2f %.2f..%.2f', box[0][0], box[0][1], box[1][0], box[1][1], box[2][0], box[2][1])
  end
end

# The door slot on the S wall, exterior face on y 0, frame centre x 49.
DOOR_S = { :id => 'S0', :name => 'Right46Door',
           :poly => [[26.0, 0.0], [72.0, 0.0], [72.0, 4.875], [26.0, 4.875]], :inner => false }
DOOR_E = { :id => 'E0', :name => 'Left46Door',
           :poly => [[96.0, 26.0], [100.875, 26.0], [100.875, 72.0], [96.0, 72.0]], :inner => false }
CFG = { 'dir' => 'P:/x', 'dry' => false }

out = []

# 1 — place_step itself, a Standard booth on casters, plain door, S wall.
warns = []
err = nil
n = nil
begin
  n = WR_Overlays.place_step(nil, nil, CFG, {}, [DOOR_S], true, -1.0, nil, warns)
rescue Exception => e
  err = e.message
end
out << (err ? 'step S raised: ' + err.gsub(/\s+/, ' ')[0, 90] : format('step S placed %d box %s warns %d', n, WR_Overlays.added.last ? WR_Overlays.added.last[1].map { |a| format('%.2f..%.2f', a[0], a[1]) }.join(' ') : '-', warns.length))

# 2 — the CALLER's control flow, as build_booth has it: plates go in (n=1),
# then the step; an exception anywhere in place_all loses casters_in.
casters_in = false
overlay_err = nil
begin
  plates = 1                      # place_casters returned 1: the plate set is IN the model
  ci = plates > 0
  placed = plates
  placed += WR_Overlays.place_step(nil, nil, CFG, {}, [DOOR_S], ci, -1.0, nil, [])
  _placed, _warns, casters_in = [placed, [], ci]
rescue Exception => e
  overlay_err = e.message
end
lift = WR_Overlays.booth_lift(casters_in, -1.0)
out << format('caller: overlays %s casters_in %s lift %.4f (plates in the model hang at %.4f)',
              overlay_err ? 'FAILED' : 'ok', casters_in ? 'true' : 'false', lift, -1.0 - WR_Overlays::CP_BOOTH_LIFT + lift)

# 3 — E wall, Enhanced on casters (stack -1.3125), to exercise the other basis.
WR_Overlays.added.clear
warns = []
err = nil
begin
  n = WR_Overlays.place_step(nil, nil, CFG, {}, [DOOR_E], true, -1.3125, nil, warns)
rescue Exception => e
  err = e.message
end
out << (err ? 'step E raised: ' + err.gsub(/\s+/, ' ')[0, 90] : format('step E placed %d box %s', n, WR_Overlays.added.last[1].map { |a| format('%.2f..%.2f', a[0], a[1]) }.join(' ')))
out << 'STEP line: ' + (WR_Overlays.log.find { |l| l =~ /\A\s*STEP\s/ } || '(none printed)').gsub(/\s+/, ' ')[0, 200]

out.join(' | ')
'''

# What the fixed code must produce. Step S: frame centre 49, 44 along ->
# x 27..71; 12 out from the S face on y 0 -> y -12..0; underside on the
# ground, -5.75 booth-local on a Standard booth on casters, 5 tall.
# Step E: frame centre y 49 -> y 27..71; out from x 100.875 -> 100.875..112.875;
# ground -6.0625 on an Enhanced booth on casters.
EXPECT = ('step S placed 1 box 27.00..71.00 -12.00..0.00 -5.75..-0.75 warns 0'
          ' | caller: overlays ok casters_in true lift 5.7500 (plates in the model hang at 0.0000)'
          ' | step E placed 1 box 100.88..112.88 27.00..71.00 -6.06..-1.06')


def lift_scalar(lines, name):
    """rbtest-overlays' lift_scalar, but tolerant of a trailing comment."""
    pat = re.compile(r'^  %s\s*=\s*[-\d.]+\s*(#.*)?$' % re.escape(name))
    for ln in lines:
        if pat.match(ln):
            return ln
    raise SystemExit('wr-overlays.rb: no scalar constant %s' % name)


def main():
    lines = open(SRC, encoding='utf-8').read().split('\n')
    consts = '\n'.join(lift_scalar(lines, c) for c in SCALARS)
    prog = (STUBS + FIXTURE
            .replace('__CONSTS__', consts)
            .replace('__METHODS__', '\n\n'.join(rbo.lift_method(lines, m) for m in METHODS)))
    lib = rbparse.boot()
    got = rbparse.rb_eval(lib, prog)
    print('repro: place_step lifted verbatim, run in the CRuby 3.2 DLL')
    for part in got.split(' | '):
        print('  ' + part)
    ok = got.startswith(EXPECT)
    print('  RESULT: ' + ('PASS - the step places and the caster datum survives' if ok
                          else 'FAIL - this is the defect'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
