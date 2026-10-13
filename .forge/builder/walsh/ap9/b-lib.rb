# Phase B helpers for the Walsh v8 acoustic layout. Loaded by b-wall.rb and b-verify.rb.
# Booth-local inches throughout (the booth group is a pure translation). Nothing here edits the model.
require 'json'

module B8
  DIR = 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/walsh/ap9'
  MODEL_RE = /Walsh Construction Tech Lab MDL 96168 E\.skp\z/
  BOOTH = 'Booth - MDL 96168 E'
  G = 0.5
  # s axis, d (normal) axis, n = sign of the into-room direction along d, nominal face (observed survey)
  FR = { 'S' => { s: 0, d: 1, n: 1.0, face: 4.25 }, 'N' => { s: 0, d: 1, n: -1.0, face: 93.75 },
         'E' => { s: 1, d: 0, n: -1.0, face: 165.75 }, 'W' => { s: 1, d: 0, n: 1.0, face: 4.25 } }
  UP = Geom::Vector3d.new(0, 0, 1)

  def self.model!
    m = Sketchup.active_model
    raise "wrong model: #{m.path.inspect}" unless m.path.to_s =~ MODEL_RE
    m
  end

  def self.booth(m)
    b = m.entities.grep(Sketchup::Group).find { |g| g.name == BOOTH }
    raise 'no booth group' unless b
    b
  end

  def self.pieces(b)
    b.entities.grep(Sketchup::ComponentInstance).select { |e| e.definition.name =~ /\A(Foam|Audimute)/ }
  end

  def self.nvec(w)
    f = FR[w]; a = [0.0, 0.0, 0.0]; a[f[:d]] = f[:n]; Geom::Vector3d.new(*a)
  end

  # face-vertex extents of entities under transform tr -> [lo[3], hi[3]]
  def self.ext(ents, tr, acc = [])
    ents.each do |e|
      case e
      when Sketchup::Face then e.vertices.each { |v| acc << v.position.transform(tr) }
      when Sketchup::Group, Sketchup::ComponentInstance then ext(e.definition.entities, tr * e.transformation, acc)
      end
    end
    acc
  end

  def self.box(pts)
    [[pts.map { |p| p.x.to_f }.min, pts.map { |p| p.y.to_f }.min, pts.map { |p| p.z.to_f }.min], [pts.map { |p| p.x.to_f }.max, pts.map { |p| p.y.to_f }.max, pts.map { |p| p.z.to_f }.max]]
  end

  # Body box in definition coordinates. Audimute: its largest child (the panel body, not the hang clips).
  @body = {}
  def self.body_local(defn)
    @body[defn.name] ||= begin
      if defn.name =~ /\AAudimute/
        kids = defn.entities.grep(Sketchup::ComponentInstance)
        bx = kids.map { |c| box(ext(c.definition.entities, c.transformation)) }
        bx.max_by { |lo, hi| (hi[0] - lo[0]) * (hi[1] - lo[1]) * (hi[2] - lo[2]) }
      else
        box(ext(defn.entities, Geom::Transformation.new))
      end
    end
  end

  # local back-plane point and local into-room vector (observed v7 convention)
  def self.back_and_front(defn)
    lo, hi = body_local(defn)
    if defn.name =~ /\AAudimute/
      [Geom::Point3d.new(0, hi[1], 0), Geom::Vector3d.new(0, -1, 0)]   # body back y=1.5, fabric local -y
    else
      [Geom::Point3d.new(0, 0, lo[2]), Geom::Vector3d.new(0, 0, 1)]    # foam back z=0, profile local +z
    end
  end

  # rotation axes for a part hung on wall w (observed from the v7 instances)
  def self.axes(part, orient, w)
    n = nvec(w)
    if part == 'Foam'
      za = n
      if orient == 'vertical' then xa = UP; ya = za.cross(xa) else ya = UP; xa = ya.cross(za) end
    else
      ya = n.reverse
      x_up = (part == 'Audimute2x4' && orient == 'horizontal') || (part == 'Audimute1x2' && orient == 'vertical')
      if x_up then xa = UP; za = xa.cross(ya) else za = UP; xa = ya.cross(za) end
    end
    raise "axes not right-handed for #{part} #{orient} #{w}" unless (xa.cross(ya) - za).length.to_f < 1e-6
    [xa, ya, za]
  end

  def self.coord(p, i) = [p.x, p.y, p.z][i].to_f

  # measure an instance: body rect in wall-local (s0,s1,z0,z1), back-plane d, front vector
  def self.measure(inst, w)
    f = FR[w]
    lo, hi = body_local(inst.definition)
    pts = [lo[0], hi[0]].product([lo[1], hi[1]], [lo[2], hi[2]]).map { |a, c, d| Geom::Point3d.new(a, c, d).transform(inst.transformation) }
    bp, fv = back_and_front(inst.definition)
    s = pts.map { |p| coord(p, f[:s]) }; z = pts.map(&:z).map(&:to_f); d = pts.map { |p| coord(p, f[:d]) }
    { s0: s.min, s1: s.max, z0: z.min, z1: z.max, dmin: d.min, dmax: d.max,
      back: coord(bp.transform(inst.transformation), f[:d]), front: fv.transform(inst.transformation).normalize }
  end

  # which wall an instance's body sits on (nil = off the walls, e.g. staged outside)
  def self.wall_of(inst)
    lo, hi = body_local(inst.definition)
    pts = [lo[0], hi[0]].product([lo[1], hi[1]], [lo[2], hi[2]]).map { |a, c, d| Geom::Point3d.new(a, c, d).transform(inst.transformation) }
    x0, x1 = pts.map { |p| p.x.to_f }.minmax; y0, y1 = pts.map { |p| p.y.to_f }.minmax
    return nil if x1 < 0 || y1 < 0 || x0 > 170 || y0 > 98
    return 'S' if y1 - y0 < 3 && y0 < 8
    return 'N' if y1 - y0 < 3 && y1 > 90
    return 'E' if x1 - x0 < 3 && x1 > 160
    return 'W' if x1 - x0 < 3 && x0 < 8
    '?'
  end

  # Multi-ray seat: grid over the footprint, cast toward the wall from 3.5 in inside the room, stepping
  # through any foam/Audimute hit, so nothing has to be hidden. Returns the most proud face coordinate.
  def self.seat(m, b, w, s0, s1, z0, z1, skip)
    f = FR[w]; bt = b.transformation; bi = bt.inverse
    dir = nvec(w).reverse.transform(bt)
    ns = [((s1 - s0 - 0.5) / 3.0).ceil, 1].max; nz = [((z1 - z0 - 0.5) / 0.5).ceil, 1].max
    vals = []; whats = Hash.new(0); misses = 0
    (0..ns).each do |i|
      s = s0 + 0.25 + (s1 - s0 - 0.5) * i / ns
      (0..nz).each do |k|
        z = z0 + 0.25 + (z1 - z0 - 0.5) * k / nz
        a = [0.0, 0.0, z]; a[f[:s]] = s; a[f[:d]] = f[:face] + f[:n] * 3.5
        pt = Geom::Point3d.new(*a).transform(bt)
        hit = nil
        60.times do
          h = m.raytest([pt, dir], true)
          break unless h
          if h[1].any? { |e| skip.include?(e) }
            pt = h[0].offset(dir, 0.001)
          else
            hit = h; break
          end
        end
        unless hit then misses += 1; next end
        vals << coord(hit[0].transform(bi), f[:d])
        leaf = hit[1].reverse.find { |e| e.respond_to?(:definition) }
        whats[leaf ? leaf.definition.name : hit[1].last.class.name] += 1
      end
    end
    raise "no ray hit the #{w} wall over s #{s0}-#{s1} z #{z0}-#{z1}" if vals.empty?
    proud = vals.max_by { |v| v * f[:n] }
    { seat: proud, rays: vals.length, misses: misses, lo: vals.min, hi: vals.max,
      proud_off: (proud - f[:face]) * f[:n], hit_parts: whats }
  end

  def self.gap2(a, b) = [b[0] - a[1], a[0] - b[1], b[2] - a[3], a[2] - b[3]].max
end
