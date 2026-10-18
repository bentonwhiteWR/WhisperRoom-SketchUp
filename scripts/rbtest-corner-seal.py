# -*- coding: utf-8 -*-
"""RUN corner_yaw outside SketchUp: every Standard corner seal lands elbow-OUT.

    python rbtest-corner-seal.py

WHY THIS EXISTS
---------------
On 18 Oct 2026 every outer corner seal on a booth-from-link build came out
turned 180 deg, elbow in toward the panels, the moment Benton put 3/8 in
chamfers on CornerSeamSeal / CornerSeamSeal_HX. The geometry was fine. The
orientation test was not: it averaged the part's EDGE END POINTS, which on a
corner seal sit 0.0035 in from the box centre on each axis - mostly screw-mark
24-gons and outline corners - and the chamfers tipped that average 0.045 in
the other way. 1.84.4 reads the L's PLAN AREA instead (plan_mass), which leans
about 0.87 in toward the elbow on each axis whatever is drawn on its walls.

WHAT IT DOES
------------
Lifts `corner_yaw` and `plan_mass` verbatim out of build-booth-components.rb
(rbtest.method_source, so an edit to either is what gets tested) and runs them
in SketchUp 2024's CRuby against Geom / Sketchup stubs. The parts are the REAL
plan outlines of the corner seal as it has existed, read off the files with
SketchUp 2026's SketchUpAPI.dll on 18 Oct 2026:

    plain     the plain L every booth was built with until 18 Oct (SW frame)
    chamfered the 3/8 in chamfers, still in the SW frame (master model, 11:59)
    share     the files on the share since 12:07: chamfered AND re-axed 180 deg,
              elbow at (4, 4), with the stray floor triangles the chamfer cut
              left on the bottom face
    share HX  the same for CornerSeamSeal_HX, which has three of them

Each part also carries one wall face with four 24-gon screw-mark holes - the
geometry that fooled the old average. A wall projects to a line in plan, so it
must add nothing.

Every part is tried on all four corners of two booths, starting from each of
the four quarter turns place() might hand over. The seal is right when its
elbow lands on the booth's outer corner and its box stays on the corner
polygon. All 2 x 4 x 4 x 4 = 128 cases must pass.

WHAT IT DOES NOT DO
-------------------
It does not run place() or the SketchUp API. That a corner's box arrives
centred on its polygon is taken from the 12:02 build of 18 Oct (observed: all
four boxes sat exactly on their polygons). A live build is still the check that
the booth looks right.

CHECKED AGAINST ITSELF
----------------------
The run includes its own mutation check: corner_yaw is run a second time with
its "furthest" turned back into "nearest" (the 1.84.3 comparison), and that run
must FAIL. If it ever passes, this test has stopped proving anything.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402
import rbtest   # noqa: E402

SRC = os.path.join(HERE, 'build-booth-components.rb')

STUBS = r'''
class Float
  def to_f; self; end
end
class Integer
  def to_f; self * 1.0; end
end
module Geom
  class Vector3d
    attr_reader :x, :y, :z
    def initialize(x, y, z); @x = x.to_f; @y = y.to_f; @z = z.to_f; end
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
    def self.translation(v); new(nil, [v.x, v.y, v.z]); end
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
    def *(other)
      m = (0..2).map { |i| (0..2).map { |j| (0..2).inject(0.0) { |a, k| a + @m[i][k] * other.m[k][j] } } }
      o = mul_v(other.o)
      Transformation.new(m, (0..2).map { |i| o[i] + @o[i] })
    end
    def apply_p(p); r = mul_v([p.x, p.y, p.z]); Point3d.new(r[0] + @o[0], r[1] + @o[1], r[2] + @o[2]); end
  end
end
module Sketchup
  class Vertex
    attr_reader :position
    def initialize(p); @position = p; end
  end
  class Loop
    attr_reader :vertices
    def initialize(outer, pts); @outer = outer; @vertices = pts.map { |p| Vertex.new(p) }; end
    def outer?; @outer; end
  end
  class Face
    attr_reader :loops
    def initialize(loops); @loops = loops; end
  end
  class Edge; end
  class ComponentInstance; end
  class Group; end
end
'''

# Sent once. The methods under test go in separately (METHODS) so the mutant
# can replace them in the same VM without redefining any constant.
FIXTURE = r'''
module WR_BuildBoothComponents
  VZ = Geom::Vector3d.new(0, 0, 1)
  @log = []
  def self.log; @log; end
  def self.puts(*a); @log << a.join(' '); nil; end
end

module CornerSealTest
  Defn = Struct.new(:name, :entities)
  S = 4.875

  def self.pt(x, y, z); Geom::Point3d.new(x, y, z); end

  # A face from outlines [[x, y], ...] at height z, outer loop first.
  def self.face(z, outer, *holes)
    loops = [Sketchup::Loop.new(true, outer.map { |q| pt(q[0], q[1], z) })]
    holes.each { |h| loops << Sketchup::Loop.new(false, h.map { |q| pt(q[0], q[1], z) }) }
    Sketchup::Face.new(loops)
  end

  # One wall face of a leg, in the vertical plane `along` = :x (y fixed) or
  # :y (x fixed), with four 24-gon screw-mark holes of 0.248 radius - drawn
  # the way the real part has them.
  def self.wall(fixed, a0, a1, top, at, along)
    p3 = lambda { |a, z| along == :x ? pt(a, fixed, z) : pt(fixed, a, z) }
    outer = [p3.call(a0, 0.0), p3.call(a1, 0.0), p3.call(a1, top), p3.call(a0, top)]
    loops = [Sketchup::Loop.new(true, outer)]
    [2.0, 27.75, 53.25, top - 2.0].each do |zc|
      ring = (0...24).map do |i|
        t = i * 2.0 * Math::PI / 24.0
        p3.call(at + 0.248 * Math.cos(t), zc + 0.248 * Math.sin(t))
      end
      loops << Sketchup::Loop.new(false, ring)
    end
    Sketchup::Face.new(loops)
  end

  # Real outlines (SketchUpAPI.dll, 18 Oct 2026). Elbow is the corner of the
  # box the L's legs meet at, in the part's own frame.
  PLAIN = [[0, 0], [4.875, 0], [4.875, 1], [2, 1], [2, 2], [1, 2], [1, 4.875], [0, 4.875]]
  CHAM_SW = [[0.375, 0], [4.5, 0], [4.875, 0.375], [4.875, 1], [2, 1], [2, 2], [1, 2],
             [1, 4.875], [0.375, 4.875], [0, 4.5], [0, 0.375]]
  CHAM_NE = [[3, -0.875], [3.625, -0.875], [4, -0.5], [4, 3.625], [3.625, 4], [-0.5, 4],
             [-0.875, 3.625], [-0.875, 3], [2, 3], [2, 2], [3, 2]]

  def self.parts
    tri_sw = [[0, 0], [0, 0.375], [0.375, 0]]
    tri_ne = [[4, 4], [4, 3.625], [3.625, 4]]
    tri_se = [[4, -0.875], [3.625, -0.875], [4, -0.5]]
    tri_nw = [[-0.875, 4], [-0.5, 4], [-0.875, 3.625]]
    [['plain', [0.0, 0.0], [0.0, S, 0.0, S],
      [face(81.0, PLAIN), face(0.0, PLAIN.reverse), wall(1.0, 2.0, 4.875, 81.0, 4.0, :x)]],
     ['chamfered', [0.0, 0.0], [0.0, S, 0.0, S],
      [face(81.0, CHAM_SW), face(0.0, CHAM_SW.reverse), face(0.0, tri_sw),
       wall(1.0, 2.0, 4.875, 81.0, 4.0, :x)]],
     ['share', [4.0, 4.0], [-0.875, 4.0, -0.875, 4.0],
      [face(81.0, CHAM_NE), face(0.0, CHAM_NE.reverse), face(0.0, tri_ne),
       wall(3.0, -0.875, 2.0, 81.0, 0.0, :x)]],
     ['share HX', [4.0, 4.0], [-0.875, 4.0, -0.875, 4.0],
      [face(91.0, CHAM_NE), face(0.0, CHAM_NE.reverse), face(0.0, tri_ne), face(0.0, tri_se),
       face(0.0, tri_nw), wall(3.0, -0.875, 2.0, 91.0, 0.0, :x)]]]
  end

  # Every corner of a w x h booth, from each of four starting turns. Returns
  # [failures, cases].
  def self.run_booth(name, ents, elbow, bx, w, h)
    defn = Defn.new(name, ents)
    vz = Geom::Vector3d.new(0, 0, 1)
    o0 = pt(0, 0, 0)
    cx = (bx[0] + bx[1]) / 2.0
    cy = (bx[2] + bx[3]) / 2.0
    bad = []
    n = 0
    [['SW', 0.0, 0.0, 0.0, 0.0], ['SE', w - S, 0.0, w, 0.0],
     ['NE', w - S, h - S, w, h], ['NW', 0.0, h - S, 0.0, h]].each do |cn, x0, y0, ox, oy|
      pivot = pt(x0 + S / 2.0, y0 + S / 2.0, 0)
      4.times do |k|
        n += 1
        r = Geom::Transformation.rotation(o0, vz, k * Math::PI / 2.0)
        c = pt(cx, cy, 0).transform(r)
        tr = Geom::Transformation.translation(Geom::Vector3d.new(pivot.x - c.x, pivot.y - c.y, 0)) * r
        yaw = WR_BuildBoothComponents.corner_yaw(defn, tr, pivot, [w / 2.0, h / 2.0])
        fin = Geom::Transformation.rotation(pivot, vz, yaw) * tr
        e = pt(elbow[0], elbow[1], 0).transform(fin)
        miss = Math.hypot(e.x - ox, e.y - oy)
        xs = []
        ys = []
        [[bx[0], bx[2]], [bx[1], bx[2]], [bx[0], bx[3]], [bx[1], bx[3]]].each do |q|
          p = pt(q[0], q[1], 0).transform(fin)
          xs << p.x
          ys << p.y
        end
        off = [(xs.min - x0).abs, (xs.max - x0 - S).abs, (ys.min - y0).abs, (ys.max - y0 - S).abs].max
        if miss > 1e-6 || off > 1e-6
          bad << format('%s %s turn %d: elbow %.2f in from the outer corner, box %.3f off its polygon',
                        name, cn, k * 90, miss, off)
        end
      end
    end
    [bad, n]
  end

  def self.check
    bad = []
    n = 0
    parts.each do |name, elbow, bx, ents|
      [[146.0, 98.0], [54.0, 78.0]].each do |w, h|
        b, c = run_booth(name, ents, elbow, bx, w, h)
        bad.concat(b)
        n += c
      end
    end
    warned = WR_BuildBoothComponents.log.length
    if bad.empty? && warned.zero?
      format('PASS %d', n)
    else
      format('FAIL %d of %d', bad.length, n) + (warned.zero? ? '' : format(' (%d warnings)', warned)) +
        "\n    " + bad.first(6).join("\n    ")
    end
  end
end

'''

METHODS = r'''
module WR_BuildBoothComponents
  @log = []

__PLAN_MASS__

__CORNER_YAW__
end

(begin
  CornerSealTest.check
rescue Exception => e
  'FAIL ' + e.message
end).dup
'''


def methods(corner_yaw_src):
    return (METHODS.replace('__PLAN_MASS__', rbtest.method_source(SRC, 'plan_mass'))
                   .replace('__CORNER_YAW__', corner_yaw_src))


def main():
    real = rbtest.method_source(SRC, 'corner_yaw')
    lib = rbparse.boot()
    print('corner_yaw: 4 corner seal parts x 4 corners x 4 starting turns x 2 booths')
    got = rbparse.rb_eval(lib, STUBS + FIXTURE + methods(real))
    print('  real       %s' % got)

    # The mutation: back to "nearest the booth's middle". It must fail, or
    # this test cannot tell a right answer from a wrong one.
    if 'd > bestd' not in real:
        print('  FAIL - corner_yaw no longer compares `d > bestd`; update the mutation check')
        return 1
    # Same VM: reopening the module replaces both methods and clears the log.
    mutant = rbparse.rb_eval(lib, methods(real.replace('d > bestd', 'd < bestd')))
    print('  mutant     %s' % mutant.split('\n')[0])

    if got.startswith('PASS') and mutant.startswith('FAIL'):
        print('  PASS - every corner seal lands elbow-out, on its polygon; the mutant is caught')
        return 0
    print('  FAIL')
    return 1


if __name__ == '__main__':
    sys.exit(main())
