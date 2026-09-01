# -*- coding: utf-8 -*-
"""RUN WR_BuildRoom.door outside SketchUp and check the swing arc.

    python rbtest-doorswing.py

Same discipline as rbtest.py / rbtest-takeoff.py: boots SketchUp's own CRuby
3.2 through rbparse.py, lifts `signed_area`, `outward` and `door` VERBATIM out
of build-room.rb (so this test can never drift from the code), and runs them
against a stubbed Geom / Sketchup::Entities that records what was drawn.

WHY IT EXISTS
-------------
Reported 31 Aug 2026 by Benton, looking at real rooms: "all of the door swings
are the wrong way. The door is mostly shown inside the room, but the swing
outline is on the outside." The leaf is built toward `-outward`, so it knows
which side the room is on; the arc was rotated by a sign that depended only on
the hinge side, which always lands on the LEFT-hand normal of the run. That is
the interior only when the polygon winds counter-clockwise. Rooms now wind
clockwise by convention, so every door was wrong.

WHAT IT ASSERTS, for both windings x both hinge sides:
  1. the arc's far endpoint coincides with the LEAF's tip (so the two cannot
     disagree by construction, not merely by two calculations agreeing today)
  2. the arc's first point is the closed jamb
  3. the arc's midpoint is on the INTERIOR side of the wall plane
  4. the leaf tip itself is on the interior side (guards the leaf, not just
     the arc)

The counter-clockwise cases are not hypothetical: room 3190J in
clients/uic-daley-library/takeoff.json declares `"winding": {"order": "ccw"}`.

MUTATION-CHECKED when written. Restore the old fixed sign

    ang = (Math::PI / 2.0) * k / steps * ((hinge == 'far') ? -1.0 : 1.0)

and the two CW cases FAIL on checks 1 and 3 while the two CCW cases still
pass - which is exactly the reported symptom, and why it was invisible until
the winding convention landed.
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
  def to_i; self; end
end

# --- just enough Geom -------------------------------------------------------
module Geom
  class Vector3d
    attr_reader :x, :y, :z
    def initialize(x, y, z = 0)
      @x = x.to_f
      @y = y.to_f
      @z = z.to_f
    end
    def length
      Math.sqrt(@x * @x + @y * @y + @z * @z)
    end
    def normalize
      l = length
      Vector3d.new(@x / l, @y / l, @z / l)
    end
  end

  class Point3d
    attr_reader :x, :y, :z
    def initialize(x, y, z = 0)
      @x = x.to_f
      @y = y.to_f
      @z = z.to_f
    end
    def -(o)
      Vector3d.new(@x - o.x, @y - o.y, @z - o.z)
    end
    # SketchUp's own signature: offset(vector) moves by the vector's full
    # length; offset(vector, distance) moves that far along it.
    def offset(v, d = nil)
      l = v.length
      s = d.nil? ? 1.0 : (d.to_f / l)
      Point3d.new(@x + v.x * s, @y + v.y * s, @z + v.z * s)
    end
    def transform(tr)
      tr.apply(self)
    end
  end

  class Transformation
    def self.rotation(origin, _axis, ang)
      Transformation.new(origin, ang)
    end
    def initialize(origin, ang)
      @o = origin
      @a = ang
    end
    # Rotation about +Z only, which is all Z_AXIS ever asks for here.
    def apply(p)
      c = Math.cos(@a)
      s = Math.sin(@a)
      dx = p.x - @o.x
      dy = p.y - @o.y
      Point3d.new(@o.x + dx * c - dy * s, @o.y + dx * s + dy * c, p.z)
    end
  end
end

Z_AXIS = Geom::Vector3d.new(0, 0, 1)

# --- just enough Sketchup::Entities ----------------------------------------
GROUPS = []

class FaceStub
  def normal; Geom::Vector3d.new(0, 0, 1); end
  def reverse!; nil; end
  def pushpull(_d); nil; end
end

class EntsStub
  def initialize(owner); @owner = owner; end
  def add_group
    ng = GroupStub.new
    GROUPS.push(ng)
    ng
  end
  def add_face(pts)
    @owner.faces.push(pts)
    FaceStub.new
  end
  def add_line(p, q)
    @owner.lines.push([p, q])
    nil
  end
end

class GroupStub
  attr_accessor :name, :layer, :material
  attr_reader :faces, :lines, :entities
  def initialize
    @faces = []
    @lines = []
    @name = ''
    @entities = EntsStub.new(self)
  end
  def valid?; true; end
  def erase!; nil; end
end
'''

PROG = SHIMS + r'''
module WR_BuildRoom
  TOL = 0.02

@@SIGNED_AREA@@

@@OUTWARD@@

@@DOOR@@
end

def pt(x, y)
  Geom::Point3d.new(x, y, 0)
end

# Same rectangle both ways round. CW is the convention takeoff-check.py now
# enforces (start at the north-west corner and walk clockwise); CCW is the
# same room walked the other way, which is what room 3190J of
# clients/uic-daley-library/takeoff.json legitimately is.
CW  = [pt(0, 120), pt(144, 120), pt(144, 0), pt(0, 0)]
CCW = [pt(0, 0), pt(144, 0), pt(144, 120), pt(0, 120)]

def named(prefix)
  GROUPS.find { |g| g.name.to_s.start_with?(prefix) }
end

def near?(p, q)
  ((p.x - q.x).abs < 0.001) && ((p.y - q.y).abs < 0.001)
end

def check(results, name, ok, detail)
  results.push([name, ok, detail.to_s])
end

results = []
AT = 40.0
W  = 36.0

[['CW', CW], ['CCW', CCW]].each do |wname, pts|
  ccw = WR_BuildRoom.signed_area(pts) > 0
  check(results, wname + ' winding detected as ' + (ccw ? 'ccw' : 'cw'),
        ccw == (wname == 'CCW'), 'signed_area ' + WR_BuildRoom.signed_area(pts).to_s)

  ['near', 'far'].each do |hinge|
    run_i = 0
    GROUPS.clear
    parent = GroupStub.new
    WR_BuildRoom.door(parent, pts, run_i, ccw, 4.0, AT, W, 80.0, hinge,
                      'tag_door', 'tag_leaf', 'mat')

    leaf = named('Door leaf')
    arcg = named('Swing')
    tag = wname + '/' + hinge + ': '

    if leaf.nil? || arcg.nil? || leaf.faces.empty? || arcg.lines.empty?
      check(results, tag + 'leaf and arc were drawn', false,
            'leaf ' + leaf.inspect + ' arc ' + arcg.inspect)
      next
    end

    # Leaf face is [pivot, tip, tip+u*1.5s, pivot+u*1.5s] - tip is index 1.
    face = leaf.faces[0]
    pivot = face[0]
    tip = face[1]

    arc_pts = arcg.lines.map { |l| l[0] } + [arcg.lines[-1][1]]
    a0 = arc_pts[0]
    a_end = arc_pts[-1]
    a_mid = arc_pts[arc_pts.length / 2]

    a = pts[run_i]
    b = pts[(run_i + 1) % pts.size]
    u = (b - a).normalize
    nv = WR_BuildRoom.outward(pts, run_i, ccw)
    j0 = a.offset(u, AT)
    j1 = a.offset(u, AT + W)
    closed = (hinge == 'far') ? j0 : j1

    # 1. the arc ENDS at the leaf's tip
    check(results, tag + 'arc endpoint is the leaf tip', near?(a_end, tip),
          'arc end (' + a_end.x.round(2).to_s + ',' + a_end.y.round(2).to_s +
          ') vs leaf tip (' + tip.x.round(2).to_s + ',' + tip.y.round(2).to_s + ')')

    # 2. the arc STARTS at the closed jamb
    check(results, tag + 'arc starts at the closed jamb', near?(a0, closed),
          'arc start (' + a0.x.round(2).to_s + ',' + a0.y.round(2).to_s + ')')

    # 3. the arc's midpoint is INSIDE (negative along the outward normal)
    dm = (a_mid - pivot).x * nv.x + (a_mid - pivot).y * nv.y
    check(results, tag + 'arc midpoint is on the interior side', dm < -1.0,
          'dot with outward normal = ' + dm.round(2).to_s)

    # 4. and so is the leaf tip
    dt = (tip - pivot).x * nv.x + (tip - pivot).y * nv.y
    check(results, tag + 'leaf tip is on the interior side', dt < -1.0,
          'dot with outward normal = ' + dt.round(2).to_s)
  end
end

out = results.map { |(n, ok, d)| (ok ? 'PASS ' : 'FAIL ') + n + (ok ? '' : '   ' + d) }
(out.join("\n") + "\n" + results.count { |r| !r[1] }.to_s + ' failure(s)').dup
'''


def main():
    src = os.path.join(HERE, 'build-room.rb')
    prog = PROG
    for token, name in (('@@SIGNED_AREA@@', 'signed_area'),
                        ('@@OUTWARD@@', 'outward'),
                        ('@@DOOR@@', 'door')):
        prog = prog.replace(token, method_source(src, name))
    lib = rbparse.boot()
    got = rbparse.rb_eval(lib, prog)
    print(got)
    if got.startswith('FAIL '):
        return 1
    return 0 if got.rstrip().endswith('0 failure(s)') else 1


if __name__ == '__main__':
    sys.exit(main())
