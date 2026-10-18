"""Replay corner seal orientation, OLD (git HEAD) vs NEW (working tree) corner_yaw,
on the REAL part geometry (every edge and every face loop, dumped by loopdump.py).

Both methods are lifted verbatim from the .rb by rbtest.method_source and run in
SketchUp 2024's CRuby 3.2 VM against Geom/Sketchup stubs. The booth is the
146 x 98 MDL 96144 S that Benton built at 12:02 (corner polygons 4.875 square).

The starting transform handed to corner_yaw stands in for place()'s output: each
of the four quarter turns of the part, translated so its box centre is on the
corner polygon's centre (which is what place() does for a corner - observed in
the 12:02 build, every box sat exactly on its polygon). The test reports the
answer for all four, so a dependence on the part's own frame would show.
"""
import json, math, os, subprocess, sys

REPO = r"C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp"
sys.path.insert(0, os.path.join(REPO, "scripts"))
import rbparse, rbtest  # noqa

HERE = os.path.dirname(os.path.abspath(__file__))
# loops/*.json are NOT committed (part geometry): regenerate them with loopdump.py, e.g.
#   python -I loopdump.py <master 23 Sep>.skp loops/plain.json CornerSeamSeal
#   python -I loopdump.py <master 11:59>.skb loops/chamSW.json CornerSeamSeal
#   python -I loopdump.py P:/Sketchup/NewMasterComponentList/CornerSeamSeal.skp loops/share.json
# (and the _HX twins). The file list and sources are in ../corner-seam-seal-flip-notes.md.
import tempfile
head_src = os.path.join(tempfile.gettempdir(), "head_build-booth-components.rb")
with open(head_src, "wb") as f:
    f.write(subprocess.run(["git", "-C", REPO, "show", "HEAD:scripts/build-booth-components.rb"],
                           capture_output=True, check=True).stdout)
work_src = os.path.join(REPO, "scripts", "build-booth-components.rb")

# variant -> (json, elbow point in the definition's own frame, read off the top-face outline)
VARIANTS = [
    ("plain L, 23 Sep master (=Walsh/ISL)", "plain.json", (0.0, 0.0)),
    ("plain L HX, 23 Sep master", "plain_HX.json", (0.0, 0.0)),
    ("chamfered, SW frame, master 11:59", "chamSW.json", (0.0, 0.0)),
    ("chamfered HX, SW frame, master 11:59", "chamSW_HX.json", (0.0, 0.0)),
    ("chamfered, re-axed, SHARE 12:07", "share.json", (4.0, 4.0)),
    ("chamfered HX, re-axed, SHARE 12:07", "share_HX.json", (4.0, 4.0)),
]
W, H = 146.0, 98.0

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
  class Edge
    attr_reader :start, :end
    def initialize(a, b); @start = Vertex.new(a); @end = Vertex.new(b); end
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
  class ComponentInstance; end
  class Group; end
end
class Defn
  attr_reader :entities, :name
  def initialize(name, ents); @name = name; @entities = ents; end
end
def pt(a); Geom::Point3d.new(a[0], a[1], a[2]); end
def mkdef(name, edges, faces)
  ents = edges.map { |e| Sketchup::Edge.new(pt(e[0]), pt(e[1])) }
  faces.each { |f| ents << Sketchup::Face.new(f.map { |lp| Sketchup::Loop.new(lp[0], lp[1].map { |q| pt(q) }) }) }
  Defn.new(name, ents)
end
'''


def lit(x):
    return repr(float(x))


def defn_literal(d):
    edges = "[" + ",".join("[[%s,%s,%s],[%s,%s,%s]]" % tuple(lit(c) for c in (*a, *b)) for a, b in d["edges"]) + "]"
    faces = "[" + ",".join(
        "[" + ",".join("[%s,[%s]]" % ("true" if lp["outer"] else "false",
                                      ",".join("[%s,%s,%s]" % tuple(lit(c) for c in v) for v in lp["v"]))
                       for lp in f["loops"]) + "]"
        for f in d["faces"]) + "]"
    return edges, faces


prog = [STUBS]
prog.append("module OldM\n  VZ = Geom::Vector3d.new(0, 0, 1)\n" +
            rbtest.method_source(head_src, "collect_points") + "\n" +
            rbtest.method_source(head_src, "corner_yaw") + "\nend\n")
prog.append("module NewM\n  VZ = Geom::Vector3d.new(0, 0, 1)\n  @log = []\n  def self.log; @log; end\n"
            "  def self.puts(*a); @log << a.join(' '); nil; end\n" +
            rbtest.method_source(work_src, "plan_mass") + "\n" +
            rbtest.method_source(work_src, "corner_yaw") + "\nend\n")

prog.append(r'''
VZ0 = Geom::Vector3d.new(0, 0, 1)
O0 = Geom::Point3d.new(0, 0, 0)
def replay(mod, defn, bx, elbow, w, h)
  cx = (bx[0] + bx[1]) / 2.0
  cy = (bx[2] + bx[3]) / 2.0
  s = 4.875
  corners = [['SW', 0.0, 0.0, 0.0, 0.0], ['SE', w - s, 0.0, w, 0.0],
             ['NE', w - s, h - s, w, h], ['NW', 0.0, h - s, 0.0, h]]
  out = []
  corners.each do |nm, x0, y0, ox, oy|
    pivot = Geom::Point3d.new(x0 + s / 2.0, y0 + s / 2.0, 0)
    target = [w / 2.0, h / 2.0]
    res = (0..3).map do |k|
      r = Geom::Transformation.rotation(O0, VZ0, k * Math::PI / 2.0)
      c = Geom::Point3d.new(cx, cy, 0).transform(r)
      tr = Geom::Transformation.translation(Geom::Vector3d.new(pivot.x - c.x, pivot.y - c.y, 0)) * r
      yaw = mod.corner_yaw(defn, tr, pivot, target)
      fin = Geom::Transformation.rotation(pivot, VZ0, yaw) * tr
      e = Geom::Point3d.new(elbow[0], elbow[1], 0).transform(fin)
      dout = Math.hypot(e.x - ox, e.y - oy)          # elbow to the booth's OUTER corner
      bxs = []; bys = []
      [[bx[0], bx[2]], [bx[1], bx[2]], [bx[0], bx[3]], [bx[1], bx[3]]].each do |q|
        pp = Geom::Point3d.new(q[0], q[1], 0).transform(fin); bxs << pp.x; bys << pp.y
      end
      foot = [(bxs.min - x0).abs, (bxs.max - x0 - s).abs, (bys.min - y0).abs, (bys.max - y0 - s).abs].max
      ang = (Math.atan2(fin.m[1][0], fin.m[0][0]) * 180.0 / Math::PI).round
      ang = ang + 360 if ang <= -180
      [dout < 1.0 ? 'OUT' : 'IN', ang, format('%.2f', dout), format('%.4f', foot),
       format('(%.3f,%.3f)', fin.o[0], fin.o[1])]
    end
    verdicts = res.map { |q| q[0] }.uniq
    out << format('%s %s elbow->outer corner %s in, frame yaw %d deg, T %s, off-footprint %s  [same for all 4 start turns: %s]',
                  nm, res[0][0], res[0][2], res[0][1], res[0][4], res.map { |q| q[3] }.max, verdicts.length == 1 ? 'yes' : 'NO ' + verdicts.join('/'))
  end
  out
end
RESULTS = []
''')

summary = []
for label, fn, elbow in VARIANTS:
    d = json.load(open(os.path.join(HERE, "loops", fn)))
    e, f = defn_literal(d)
    xs = [p[0] for ed in d["edges"] for p in ed]; ys = [p[1] for ed in d["edges"] for p in ed]
    bx = (min(xs), max(xs), min(ys), max(ys))
    prog.append("D = mkdef(%r, %s, %s)\n" % (fn, e, f))
    prog.append("RESULTS << ['%s', 'OLD'] + replay(OldM, D, %s, %s, %s, %s)\n" % (
        label, "[%s]" % ",".join(lit(v) for v in bx), "[%s,%s]" % (lit(elbow[0]), lit(elbow[1])), lit(W), lit(H)))
    prog.append("RESULTS << ['%s', 'NEW'] + replay(NewM, D, %s, %s, %s, %s)\n" % (
        label, "[%s]" % ",".join(lit(v) for v in bx), "[%s,%s]" % (lit(elbow[0]), lit(elbow[1])), lit(W), lit(H)))
    prog.append("Object.send(:remove_const, :D)\n")
    # both centroids, in the definition frame, for the record (python, independent of the Ruby)
    pts = [p for ed in d["edges"] for p in ed]
    ecx = sum(p[0] for p in pts) / len(pts); ecy = sum(p[1] for p in pts) / len(pts)
    ax = ay = at = 0.0
    for fc in d["faces"]:
        for lp in fc["loops"]:
            v = lp["v"]; a2 = sx = sy = 0.0
            for i in range(len(v)):
                p, q = v[i], v[(i + 1) % len(v)]
                cr = p[0] * q[1] - q[0] * p[1]; a2 += cr; sx += (p[0] + q[0]) * cr; sy += (p[1] + q[1]) * cr
            if abs(a2) < 1e-9: continue
            wgt = (0.5 if lp["outer"] else -0.5) * abs(a2)
            ax += wgt * sx / (3 * a2); ay += wgt * sy / (3 * a2); at += wgt
    bcx = (bx[0] + bx[1]) / 2; bcy = (bx[2] + bx[3]) / 2
    def toward(cx, cy):
        # signed distance of the centroid from the box centre, measured TOWARD the elbow
        ex, ey = elbow[0] - bcx, elbow[1] - bcy; n = math.hypot(ex, ey)
        return ((cx - bcx) * ex + (cy - bcy) * ey) / n
    summary.append("%-40s box x %.3f..%.3f y %.3f..%.3f  edge-endpoint centroid %+.4f in toward elbow   "
                   "plan-area centroid %+.4f in toward elbow  (area %.3f = top+bottom)"
                   % (label, bx[0], bx[1], bx[2], bx[3], toward(ecx, ecy), toward(ax / at, ay / at), at))

prog.append("RESULTS.map { |r| r.join(\"\\n    \") }.join(\"\\n\") + \"\\n\" + NewM.log.join(\"\\n\")\n")
lib = rbparse.boot()
got = rbparse.rb_eval(lib, "\n".join(prog))
print("\n".join(summary))
print()
print(got)
