# -*- coding: utf-8 -*-
"""RUN the studio-light mounting measurements (wr-overlays.rb, 1.84.0)
outside SketchUp.

    python rbtest-sl-mount.py

Same discipline as rbtest.py / rbtest-takeoff.py: boots SketchUp's own CRuby
3.2 through rbparse.py and lifts the methods VERBATIM out of wr-overlays.rb on
every run, so the test cannot drift from the code.

WHY THIS EXISTS. Benton, 12 Oct 2026: the studio light "should not be hanging
lower than the beam. It should be mounted right on the ceiling component."
Up to 1.83.2 place_studio_lights put the fixture top at deck['CL'].min.z, the
CL tiles' BOUNDING BOX, which reaches down to the plastic hinges under the
tile edges: 1.36 in low on a 96120 E (ray-tested 80.25 against a box 78.89,
People's Space, 6 Oct 2026). 1.84.0 measures the tile's own faces instead.
These three methods are the measurement, and they touch only a handful of
SketchUp calls, so small honest stubs of those calls are enough to run them:

  ceiling_underside  the tile's underside z, off its faces, never the box
  underside_at       what an upward ray meets on ONE tile at (x, y)
  sl_keepouts        faces hanging into the fixture band inside a tile
                     rectangle - the roof-unit rods on an rv = 1 booth

THE STUBS answer exactly what the methods ask: Face#normal / #area(tr) /
#outer_loop.vertices / #vertices / #classify_point (axis-aligned rectangles
only - every face here is one), instance #definition.entities /
#transformation / #bounds.corner(i), and translation-only transforms with
#inverse and composition. That is a model of SketchUp, not SketchUp: the
geometry here is a hand-built tile with hinges and a hand-built roof unit
with rods, sized from the People's Space measurements. The live build of a
96120 E and an rv = 1 booth is still owed (see DEVLOG 1.84.0).

Mutation-checked when written: make ceiling_underside take the lowest face of
any size (the hinge) and s1 FAILS; drop the abs() so only downward normals
count and s2 FAILS; stop summing area per height and s3 FAILS; make
sl_keepouts' band test always true and k3 FAILS. (Dropping its container-
bounds skip changes no result - that skip is speed only, by design - so no
test can pin it.)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402
from rbtest import method_source  # noqa: E402

OVERLAYS = os.path.join(HERE, 'wr-overlays.rb')

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
    def initialize(x, y, z); @x = x * 1.0; @y = y * 1.0; @z = z * 1.0; end
    def length; Math.sqrt(@x * @x + @y * @y + @z * @z); end
    def normalize!
      l = length
      @x /= l; @y /= l; @z /= l
      self
    end
    def transform(_tr); Vector3d.new(@x, @y, @z); end   # translation-only
  end
  class Point3d
    attr_reader :x, :y, :z
    def initialize(x, y, z); @x = x * 1.0; @y = y * 1.0; @z = z * 1.0; end
    def transform(tr); Point3d.new(@x + tr.t[0], @y + tr.t[1], @z + tr.t[2]); end
  end
  class Transformation
    attr_reader :t
    def initialize(t = [0.0, 0.0, 0.0]); @t = t.map { |v| v * 1.0 }; end
    def *(o); Transformation.new([@t[0] + o.t[0], @t[1] + o.t[1], @t[2] + o.t[2]]); end
    def inverse; Transformation.new(@t.map { |v| -v }); end
  end
  class BoundingBox
    def initialize(lo, hi); @lo = lo; @hi = hi; end
    def corner(i)
      Point3d.new(i & 1 == 0 ? @lo[0] : @hi[0], i & 2 == 0 ? @lo[1] : @hi[1],
                  i & 4 == 0 ? @lo[2] : @hi[2])
    end
  end
end

module Sketchup
  class Vertex
    attr_reader :position
    def initialize(p); @position = p; end
  end
  class Loop
    attr_reader :vertices
    def initialize(vs); @vertices = vs; end
  end
  # An axis-aligned planar rectangle, in its container's coordinates.
  # Horizontal: plan box [x0, y0, x1, y1] at z, normal up or down.
  # Vertical: given by its 4 corners, normal sideways.
  class Face
    PointUnknown = 0
    PointInside = 1
    PointOnVertex = 2
    PointOnEdge = 4
    PointOutside = 16
    PointNotOnPlane = 32
    attr_reader :vertices
    def initialize(corners, normal)
      @vertices = corners.map { |c| Vertex.new(Geom::Point3d.new(*c)) }
      @normal = Geom::Vector3d.new(*normal)
    end
    def self.flat(x0, y0, x1, y1, z, up)
      new([[x0, y0, z], [x1, y0, z], [x1, y1, z], [x0, y1, z]], [0, 0, up ? 1 : -1])
    end
    def self.side(x0, y0, x1, y1, z0, z1)
      n = (x1 - x0).abs < 1e-9 ? [1, 0, 0] : [0, 1, 0]
      new([[x0, y0, z0], [x1, y1, z0], [x1, y1, z1], [x0, y0, z1]], n)
    end
    def normal; Geom::Vector3d.new(@normal.x, @normal.y, @normal.z); end
    def outer_loop; Loop.new(@vertices); end
    def area(_tr = nil)
      xs = @vertices.map { |v| v.position.x }
      ys = @vertices.map { |v| v.position.y }
      zs = @vertices.map { |v| v.position.z }
      dx = xs.max - xs.min; dy = ys.max - ys.min; dz = zs.max - zs.min
      [dx * dy, dx * dz, dy * dz].max
    end
    def classify_point(q)
      xs = @vertices.map { |v| v.position.x }
      ys = @vertices.map { |v| v.position.y }
      z = @vertices.first.position.z
      return PointNotOnPlane if (q.z - z).abs > 1e-6
      t = 1e-9
      return PointOutside if q.x < xs.min - t || q.x > xs.max + t || q.y < ys.min - t || q.y > ys.max + t
      on = (q.x - xs.min).abs < t || (q.x - xs.max).abs < t || (q.y - ys.min).abs < t || (q.y - ys.max).abs < t
      on ? PointOnEdge : PointInside
    end
  end
  class Entities
    include Enumerable
    def initialize(list); @list = list; end
    def each(&b); @list.each(&b); end
  end
  class ComponentDefinition
    attr_reader :entities, :name
    def initialize(name, ents); @name = name; @entities = Entities.new(ents); end
  end
  class ComponentInstance
    attr_reader :definition, :transformation
    def initialize(defn, tr); @definition = defn; @transformation = tr; end
    # Parent-space bounds of the definition's faces (recursing), like SketchUp.
    def bounds
      pts = []
      collect = lambda do |ents, tr|
        ents.each do |e|
          if e.is_a?(Face)
            e.vertices.each { |v| pts << v.position.transform(tr) }
          elsif e.is_a?(ComponentInstance)
            collect.call(e.definition.entities, tr * e.transformation)
          end
        end
      end
      collect.call(@definition.entities, @transformation)
      Geom::BoundingBox.new([pts.map(&:x).min, pts.map(&:y).min, pts.map(&:z).min],
                            [pts.map(&:x).max, pts.map(&:y).max, pts.map(&:z).max])
    end
  end
  class Group; end
end
'''

PROG = STUBS + r'''
module WR_Overlays
  IEP_BEAM_CHECK_TOL = 1.0 / 32.0

%(ceiling_underside)s

%(underside_at)s

%(sl_keepouts)s
end

$results = []
def check(name, ok, detail)
  $results << [name, ok, detail]
end
F = Sketchup::Face
I = Sketchup::ComponentInstance
D = Sketchup::ComponentDefinition
T = Geom::Transformation

# A 48 x 98 ceiling tile, 1.75 thick, authored at its own origin and placed
# with its underside at booth z 80.25 (People's Space's ray-tested face).
# Two plastic hinges hang 1.36 under it along one long edge: their bottoms
# reach 78.89, which is exactly what the old bounding-box rule mounted to.
def tile(under_up: false, split: false, hinges: true)
  ents = []
  if split   # the underside cut into three strips (hinge cut-outs)
    ents << F.flat(0, 0, 48, 30, 0.0, under_up) << F.flat(0, 30, 48, 68, 0.0, under_up) <<
            F.flat(0, 68, 48, 98, 0.0, under_up)
  else
    ents << F.flat(0, 0, 48, 98, 0.0, under_up)          # underside
  end
  ents << F.flat(0, 0, 48, 98, 1.75, true)                 # top skin
  ents << F.side(0, 0, 48, 0, 0.0, 1.75) << F.side(0, 98, 48, 98, 0.0, 1.75)
  if hinges
    [[10, 14], [80, 84]].each do |y0, y1|
      hd = D.new('hinge', [F.flat(46, y0, 47.5, y1, -1.36, false),
                           F.side(46, y0, 47.5, y0, -1.36, 0.0)])
      ents << I.new(hd, T.new)
    end
  end
  I.new(D.new('STD9648CL', ents), T.new([2.0, 0.0, 80.25]))
end

# --- ceiling_underside ---------------------------------------------------
u = WR_Overlays.ceiling_underside(tile)
check('s1 underside is the tile face (80.25), not the hinge bottom (78.89)',
      (u[:z] - 80.25).abs < 1e-9, u[:z].inspect)
check('s1b and the bounding box this replaces really does read the hinges',
      (tile.bounds.corner(0).z - 78.89).abs < 1e-9, tile.bounds.corner(0).z.inspect)
u = WR_Overlays.ceiling_underside(tile(under_up: true))
check('s2 a REVERSED underside (normal up) is still found', (u[:z] - 80.25).abs < 1e-9, u[:z].inspect)
u = WR_Overlays.ceiling_underside(tile(split: true))
check('s3 an underside split into strips still beats the one-piece top skin',
      (u[:z] - 80.25).abs < 1e-9, u[:z].inspect)
check('s4 a tile with no horizontal face is refused (nil), not guessed',
      WR_Overlays.ceiling_underside(I.new(D.new('x', [F.side(0, 0, 10, 0, 0, 2)]), T.new)).nil?, '')

# --- underside_at --------------------------------------------------------
u = WR_Overlays.ceiling_underside(tile)
z = WR_Overlays.underside_at(u[:faces], 25.0, 49.0)
check('a1 an upward ray mid-tile meets the underside at 80.25', (z - 80.25).abs < 1e-9, z.inspect)
z = WR_Overlays.underside_at(u[:faces], 48.75, 12.0)
check('a2 under a hinge it meets the hinge first (78.89)', (z - 78.89).abs < 1e-9, z.inspect)
z = WR_Overlays.underside_at(u[:faces], 60.0, 49.0)
check('a3 off the tile it meets nothing (nil)', z.nil?, z.inspect)

# --- sl_keepouts ---------------------------------------------------------
# A roof unit sitting on the roof (z 82.3 up) with a duct box above the
# ceiling and two hanger rods coming DOWN through it to z 77.15, at the
# People's Space positions (x 22.5-24.4 and 95.2-96.8, y 48.2-49.8).
rod = lambda do |x0, x1|
  D.new('Component#68', [F.side(x0, 48.2, x1, 48.2, 77.15, 85.4), F.side(x0, 49.8, x1, 49.8, 77.15, 85.4),
                         F.flat(x0, 48.2, x1, 49.8, 77.15, false)])
end
duct = D.new('VSS duct box', [F.flat(10, 20, 110, 80, 84.0, false), F.flat(10, 20, 110, 80, 96.0, true)])
rm = I.new(D.new('RM96120VSS', [I.new(D.new('Component#69', [I.new(rod.call(22.5, 24.4), T.new)]), T.new),
                                 I.new(D.new('Component#69b', [I.new(rod.call(95.2, 96.8), T.new)]), T.new),
                                 I.new(duct, T.new)]), T.new)
wall = I.new(D.new('ENH 46PanelSolid', [F.side(4.25, 4.25, 4.25, 93.75, 2.0, 81.5),
                                        F.flat(2.25, 4.25, 4.25, 93.75, 81.5, true)]), T.new)
t0 = tile
booth = Struct.new(:entities).new(Sketchup::Entities.new([t0, rm, wall]))
rect = [4.25, 4.25, 45.75, 93.75]            # tile 1's usable rectangle
k = WR_Overlays.sl_keepouts(booth, rect, 80.25, 3.0)
rods_in = k.select { |b| b[0] >= 22.4 && b[2] <= 24.5 && b[1] >= 48.1 && b[3] <= 49.9 }
check('k1 the rod inside tile 1 is a keep-out', !rods_in.empty?, k.inspect)
check('k2 the rod in the OTHER tile (x 95-97) is not in tile 1\'s list',
      k.none? { |b| b[0] > 90.0 }, k.inspect)
check('k3 nothing from the duct box above the ceiling, the wall on the rectangle edge, ' +
      'or the tile\'s own underside', k.all? { |b| (b[0] >= 22.4 && b[2] <= 24.5) || b[0] >= 45.9 }, k.inspect)
k2 = WR_Overlays.sl_keepouts(booth, [4.25, 4.25, 50.0, 93.75], 80.25, 3.0)
check('k4 a hinge under the tile, inside the rectangle, is a keep-out too',
      k2.any? { |b| b[0] >= 47.9 && b[2] <= 49.6 }, k2.inspect)
k3 = WR_Overlays.sl_keepouts(booth, rect, 80.25, 3.0, [rm])
check('k5 an instance in skip is never counted', k3.none? { |b| b[0] >= 22.4 && b[2] <= 24.5 }, k3.inspect)

out = $results.map { |(n, ok, d)| (ok ? 'PASS ' : 'FAIL ') + n + (ok ? '' : '   ' + d) }
(out.join("\n") + "\n" + $results.count { |r| !r[1] }.to_s + ' failure(s)').dup
'''


def main():
    prog = PROG % {
        'ceiling_underside': method_source(OVERLAYS, 'ceiling_underside'),
        'underside_at': method_source(OVERLAYS, 'underside_at'),
        'sl_keepouts': method_source(OVERLAYS, 'sl_keepouts'),
    }
    lib = rbparse.boot()
    got = rbparse.rb_eval(lib, prog)
    print(got)
    if got.startswith('FAIL '):        # a raise inside the harness
        return 1
    return 0 if got.rstrip().endswith('0 failure(s)') else 1


if __name__ == '__main__':
    sys.exit(main())
