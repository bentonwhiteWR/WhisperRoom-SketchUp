# csusb-rooms.rb — build CSUSB Chaparral 117 + University Hall 056 in SketchUp
#
#   Extensions > Developer > Ruby Console, then:
#     load "C:/Users/bento/Documents/Claude/Sketchup/scripts/csusb-rooms.rb"
#
# Everything is imperial. Model units are set to Architectural on build.
#
# WHAT IS MEASURED
#   Interior wall polygons — read from the vector layer of the client's PDFs and
#   scaled off each sheet's printed scale bar. Good to about a quarter-inch.
#   117's three doors — position, 3'-0" width, hinge side and out-swing all read
#   off the drawn leaves.
#   056's door — only the 43" opening. Leaf width and hinge side are ASSUMED.
#
# WHAT IS NOT MEASURED
#   CEILING_* — house default 8'-0". Nobody has measured either room.
#   DOOR_H    — standard 6'-8". No elevations on the sheets.
#   WALL_T    — cosmetic. Walls mitre OUTWARD from the interior face, so this
#               never moves an interior dimension.

module WR_CSUSB

  # ─── parameters ────────────────────────────────────────────────────────
  CEILING_117 = 96.0     # 8'-0" house default. Measure to the LOWEST duct/pipe — 117 is open structure.
  CEILING_056 = 96.0     # 8'-0" house default. Measure floor to tile — 056 has a lay-in grid.
  DOOR_H      = 80.0     # standard 6'-8" leaf
  WALL_T      = 5.0      # drawings show 4.9" N/S, 5.3" E, 7.7" W in 117; 5.2" in 056

  BUILD_117   = true
  BUILD_056   = true
  DRAW_DOORS  = true
  DRAW_DIMS   = true
  DIM_DOORS   = true     # dimension every door off its wall corner — how a booth gets placed
  BUILD_BOOTH = false
  BOOTH_H     = 83.0     # 83 = Standard 6'-11" | 85 = Enhanced 7'-1"

  # ─── materials ─────────────────────────────────────────────────────────
  # Names match SketchUp's built-in "Colors-Named" collection, so these are the
  # real library materials, not look-alikes. If the .skm can't be found the
  # script creates a material with the same name and RGB, which looks identical.
  MAT_FLOOR = "0128_White"             # white floor so dimensions read against it
  MAT_WALL  = "0099_LightSteelBlue"
  MAT_DOOR  = "0043_SaddleBrown"
  MAT_RGB   = {
    "0128_White"           => [255, 255, 255],
    "0099_LightSteelBlue"  => [176, 196, 222],
    "0043_SaddleBrown"     => [139,  69,  19]
  }.freeze

  BOOTH_W   = 98.0       # MDL 96120, 8'-2"
  BOOTH_L   = 122.0      # 10'-2"
  RAMP_PROT = 45.625     # ADA ramp protrusion off the door wall

  # ─── room 117, Chaparral Hall — interior face, inches ──────────────────
  # origin = inside south-west corner, +X east, +Y north
  ROOM_117 = [
    [   0.00, 579.21 ],  # 0  NW
    [ 522.09, 579.21 ],  # 1  north wall 43'-6" to the 117A closet
    [ 522.09, 507.27 ],  # 2  117A west face, 6'-0" deep
    [ 615.95, 507.27 ],  # 3  117A east face, 7'-10" wide
    [ 615.95, 309.06 ],  # 4  east wall exposed run, 16'-6"
    [ 501.92, 309.06 ],  # 5  109A north wall, 9'-6"
    [ 501.92, 198.22 ],  # 6  109A west face, 9'-3" deep
    [ 376.05, 198.22 ],  # 7  return west to the 123 block, 10'-6"
    [ 376.05,   0.00 ],  # 8  123 block west face, 16'-6" deep
    [   0.00,   0.00 ]   # 9  SW
  ].freeze

  # :edge = polygon edge index (edge i runs point i -> i+1)
  # :at   = distance along that edge from its first point to the near jamb
  # :hinge/:swing measured from the drawn leaves — all three are 3'-0" and open out
  DOORS_117 = [
    { :edge => 0, :at => 132.3, :w => 36.0, :hinge => :end,   :swing => :out },
    { :edge => 0, :at => 324.0, :w => 36.0, :hinge => :end,   :swing => :out },
    { :edge => 9, :at => 138.0, :w => 36.0, :hinge => :start, :swing => :out }
  ].freeze

  COLUMN_117 = [ 178.05, 184.46, 15.9 ].freeze   # SW corner; centre 15'-6" E / 32'-3" S of NW

  # ─── room 056, University Hall — interior face, inches ─────────────────
  ROOM_056 = [
    [ 302.60, 160.40 ],  # 0  NE
    [ 125.80, 160.40 ],  # 1  north wall 14'-9"
    [  95.80, 129.60 ],  # 2  angled wall — the only door is this whole edge
    [  78.20, 109.87 ],  # 3
    [  61.20,  89.87 ],  # 4
    [  45.60,  69.87 ],  # 5  curved outer wall, traced to about an inch
    [  31.00,  49.87 ],  # 6
    [  17.60,  29.87 ],  # 7
    [   4.80,   9.87 ],  # 8
    [   0.00,   0.00 ],  # 9  SW
    [ 302.60,   0.00 ]   # 10 SE
  ].freeze

  DOORS_056 = [
    { :edge => 1, :at => 0.0, :w => 36.0, :hinge => :start, :swing => :out }
  ].freeze

  BOOTH_056 = { :x => 194.60, :y => 1.00, :w => BOOTH_W, :l => BOOTH_L, :door => :W }
  BOOTH_117 = { :x =>  60.00, :y => 400.00, :w => BOOTH_L, :l => BOOTH_W, :door => :S }

  # ═══════════════════════════════════════════════════════════════════════
  def self.pt(x, y, z = 0.0)
    Geom::Point3d.new(x, y, z)
  end

  def self.tag(model, name, color = nil)
    layer = model.layers[name] || model.layers.add(name)
    layer.color = color if color
    layer
  end

  # Signed area — the two rooms wind in opposite directions, so which side is
  # "outside" cannot be hard-coded.
  def self.ccw?(poly)
    s = 0.0
    n = poly.length
    n.times do |i|
      ax, ay = poly[i]
      bx, by = poly[(i + 1) % n]
      s += (ax * by) - (bx * ay)
    end
    s > 0.0
  end

  def self.edge_dirs(poly)
    ccw = ccw?(poly)
    n = poly.length
    dirs = []
    n.times do |i|
      ax, ay = poly[i]
      bx, by = poly[(i + 1) % n]
      dx = bx - ax
      dy = by - ay
      len = Math.sqrt((dx * dx) + (dy * dy))
      len = 1.0 if len < 1.0e-9
      ux = dx / len
      uy = dy / len
      dirs << { :u => [ux, uy], :n => (ccw ? [uy, -ux] : [-uy, ux]), :len => len }
    end
    dirs
  end

  # Mitred outer polygon: each vertex is where the two offset wall faces meet.
  # This is what squares the corners off instead of letting walls cross.
  def self.mitre(poly, dirs, t)
    n = poly.length
    out = []
    n.times do |i|
      pv = dirs[(i - 1) % n][:n]
      nv = dirs[i][:n]
      c  = (pv[0] * nv[0]) + (pv[1] * nv[1])
      if (1.0 + c).abs < 0.1
        out << [poly[i][0] + (nv[0] * t), poly[i][1] + (nv[1] * t)]
      else
        k = t / (1.0 + c)
        out << [poly[i][0] + (k * (pv[0] + nv[0])), poly[i][1] + (k * (pv[1] + nv[1]))]
      end
    end
    out
  end

  # Fetch a Colors-Named material, loading the real .skm when it can be found and
  # falling back to an identically-named colour if it can't.
  def self.material(model, name)
    m = model.materials[name]
    return m if m
    begin
      base = Sketchup.find_support_file("Materials")
      if base
        path = File.join(base, "Colors-Named", "#{name}.skm")
        return model.materials.load(path) if File.exist?(path)
      end
    rescue StandardError
      # fall through to the colour below
    end
    m = model.materials.add(name)
    m.color = Sketchup::Color.new(*(MAT_RGB[name] || [200, 200, 200]))
    m
  end

  def self.slab(parent, poly, name, layer)
    grp = parent.add_group
    f = grp.entities.add_face(poly.map { |p| pt(p[0], p[1], 0.0) })
    f.reverse! if f && f.normal.z < 0     # front face up, so it takes paint cleanly
    grp.name  = name
    grp.layer = layer
    grp
  end

  def self.quad(parent, corners, z, h, name)
    return if h <= 0.01
    g = parent.entities.add_group
    f = g.entities.add_face(corners.map { |p| pt(p[0], p[1], z) })
    return if f.nil?
    f.reverse! if f.normal.z < 0
    f.pushpull(h)
    g.name = name
    g
  end

  # Walls mitred outward from the interior polygon, split around door openings,
  # header over each opening. Corners meet cleanly — no crossing, no overshoot.
  def self.build_walls(parent, poly, height, layer, name, doors)
    dirs  = edge_dirs(poly)
    outer = mitre(poly, dirs, WALL_T)
    walls = parent.add_group
    walls.name  = name
    walls.layer = layer
    n = poly.length

    n.times do |i|
      ax, ay = poly[i]
      ux, uy = dirs[i][:u]
      nx, ny = dirs[i][:n]
      len    = dirs[i][:len]
      next if len < 0.01

      inner = lambda { |d| [ax + (ux * d), ay + (uy * d)] }
      # outer point at distance d: the mitred corner at the ends, a plain offset between
      outp = lambda do |d|
        return outer[i]           if d <= 0.001
        return outer[(i + 1) % n] if d >= len - 0.001
        ip = inner.call(d)
        [ip[0] + (nx * WALL_T), ip[1] + (ny * WALL_T)]
      end

      ops = doors.select { |dr| dr[:edge] == i }
                 .map    { |dr| [dr[:at], [dr[:at] + dr[:w], len].min] }
                 .sort_by { |o| o[0] }

      marks = [0.0]
      ops.each { |o| marks << o[0] << o[1] }
      marks << len

      k = 0
      while k < marks.length - 1
        s = marks[k]
        e = marks[k + 1]
        if (e - s) > 0.05
          quad(walls, [inner.call(s), inner.call(e), outp.call(e), outp.call(s)], 0.0, height, "wall")
        end
        k += 2
      end

      ops.each do |o|
        quad(walls,
             [inner.call(o[0]), inner.call(o[1]), outp.call(o[1]), outp.call(o[0])],
             DOOR_H, height - DOOR_H, "header")
      end
    end
    walls
  end

  # Leaf drawn open 90 degrees on the measured hinge side, plus the floor swing arc.
  def self.build_doors(parent, poly, doors, layer, name)
    dirs = edge_dirs(poly)
    grp  = parent.add_group
    grp.name  = name
    grp.layer = layer

    doors.each do |d|
      i = d[:edge]
      ax, ay = poly[i]
      ux, uy = dirs[i][:u]
      nx, ny = dirs[i][:n]
      w = d[:w]

      if d[:hinge] == :start
        hx = ax + (ux * d[:at])
        hy = ay + (uy * d[:at])
        cx = ux
        cy = uy
      else
        hx = ax + (ux * (d[:at] + w))
        hy = ay + (uy * (d[:at] + w))
        cx = -ux
        cy = -uy
      end
      sx = (d[:swing] == :out) ? nx : -nx
      sy = (d[:swing] == :out) ? ny : -ny

      t = 1.75
      leaf = [
        [hx,                          hy                         ],
        [hx + (sx * w),               hy + (sy * w)              ],
        [hx + (sx * w) + (cx * t),    hy + (sy * w) + (cy * t)   ],
        [hx + (cx * t),               hy + (cy * t)              ]
      ]
      quad(grp, leaf, 0.0, DOOR_H, "door leaf #{w.round}\" #{d[:swing]}")

      cross = (cx * sy) - (cy * sx)
      grp.entities.add_arc(pt(hx, hy, 0.25),
                           Geom::Vector3d.new(cx, cy, 0),
                           Geom::Vector3d.new(0, 0, cross > 0 ? 1 : -1),
                           w, 0.degrees, 90.degrees, 16)
    end
    grp
  end

  # Door dimensions: corner -> near jamb, and the opening width. This is what you
  # need to place a booth against a wall, so it is on by default.
  def self.dim_doors(ents, poly, doors)
    return unless DIM_DOORS
    dirs = edge_dirs(poly)
    doors.each do |d|
      i = d[:edge]
      ax, ay = poly[i]
      ux, uy = dirs[i][:u]
      nx, ny = dirs[i][:n]
      off1 = Geom::Vector3d.new(nx * (WALL_T + 20.0), ny * (WALL_T + 20.0), 0)
      off2 = Geom::Vector3d.new(nx * (WALL_T + 40.0), ny * (WALL_T + 40.0), 0)
      corner = pt(ax, ay)
      near   = pt(ax + (ux * d[:at]),            ay + (uy * d[:at]))
      far    = pt(ax + (ux * (d[:at] + d[:w])),  ay + (uy * (d[:at] + d[:w])))
      dim(ents, corner, near, off1)
      dim(ents, near,   far,  off2)
    end
  end

  def self.build_booth(parent, spec, height, layer, label)
    g = parent.add_group
    g.name  = label
    g.layer = layer
    x = spec[:x]
    y = spec[:y]
    w = spec[:w]
    l = spec[:l]
    quad(g, [[x, y], [x + w, y], [x + w, y + l], [x, y + l]], 0.0, height, "#{label} shell")
    rq = case spec[:door]
         when :W then [[x - RAMP_PROT, y], [x, y], [x, y + l], [x - RAMP_PROT, y + l]]
         when :E then [[x + w, y], [x + w + RAMP_PROT, y], [x + w + RAMP_PROT, y + l], [x + w, y + l]]
         when :S then [[x, y - RAMP_PROT], [x + w, y - RAMP_PROT], [x + w, y], [x, y]]
         else         [[x, y + l], [x + w, y + l], [x + w, y + l + RAMP_PROT], [x, y + l + RAMP_PROT]]
         end
    quad(g, rq, 0.0, 1.5, "ADA ramp #{RAMP_PROT}\"")
    g
  end

  def self.dim(ents, a, b, off)
    return unless DRAW_DIMS
    ents.add_dimension_linear(a, b, off)
  rescue StandardError => e
    puts "  (dimension skipped: #{e.message})"
  end

  def self.set_imperial(model)
    o = model.options["UnitsOptions"]
    o["LengthFormat"] = Length::Architectural
    o["LengthUnit"]   = Length::Inches
  rescue StandardError => e
    puts "  (couldn't set units automatically: #{e.message} — set Model Info > Units to Architectural)"
  end

  # ═══════════════════════════════════════════════════════════════════════
  def self.build
    model = Sketchup.active_model
    set_imperial(model)
    model.start_operation("CSUSB rooms", true)

    t_room  = tag(model, "WR-Room",  Sketchup::Color.new(120, 128, 140))
    t_floor = tag(model, "WR-Floor", Sketchup::Color.new(200, 200, 200))
    t_booth = tag(model, "WR-Booth", Sketchup::Color.new(238,  98,  22))
    t_door  = tag(model, "WR-Doors", Sketchup::Color.new( 64, 102, 124))
    t_note  = tag(model, "WR-Notes", Sketchup::Color.new( 30,  30,  30))

    m_floor = material(model, MAT_FLOOR)
    m_wall  = material(model, MAT_WALL)
    m_door  = material(model, MAT_DOOR)
    ents = model.entities

    if BUILD_117
      a = ents.add_group
      a.name = "CHAPARRAL 117 - 51'-4\" x 48'-3\""
      f = slab(a.entities, ROOM_117, "floor 117", t_floor)
      f.material = m_floor if f
      w = build_walls(a.entities, ROOM_117, CEILING_117, t_room, "walls 117", DOORS_117)
      w.material = m_wall if w
      if DRAW_DOORS
        d = build_doors(a.entities, ROOM_117, DOORS_117, t_door, "doors 117")
        d.material = m_door if d
      end

      cx, cy, cs = COLUMN_117
      col = a.entities.add_group
      col.name  = "column ~16\" sq"
      col.layer = t_room
      quad(col, [[cx, cy], [cx + cs, cy], [cx + cs, cy + cs], [cx, cy + cs]], 0.0, CEILING_117, "column")
      col.material = m_wall

      build_booth(a.entities, BOOTH_117, BOOTH_H, t_booth, "MDL 96120 - PLACEHOLDER") if BUILD_BOOTH

      # ── dimensions, all four sides ──
      up    = Geom::Vector3d.new(0,  90, 0)
      up2   = Geom::Vector3d.new(0,  62, 0)
      left  = Geom::Vector3d.new(-90, 0, 0)
      down  = Geom::Vector3d.new(0, -70, 0)
      right = Geom::Vector3d.new(70,  0, 0)

      # top — overall, then the north-wall chain
      dim(a.entities, pt(0, 579.21),      pt(615.95, 579.21), up)
      dim(a.entities, pt(0, 579.21),      pt(522.09, 579.21), up2)   # 43'-6"
      dim(a.entities, pt(522.09, 579.21), pt(615.95, 579.21), up2)   # 7'-10" (117A)

      # left — overall depth
      dim(a.entities, pt(0, 579.21), pt(0, 0), left)

      # bottom — south chain, projected: 31'-4" / 10'-6" / 9'-6"
      dim(a.entities, pt(0, 0),      pt(376.05, 0), down)
      dim(a.entities, pt(376.05, 0), pt(501.92, 0), down)
      dim(a.entities, pt(501.92, 0), pt(615.95, 0), down)

      # right — east chain: 6'-0" / 16'-6" / 9'-3" / 16'-6"
      dim(a.entities, pt(615.95, 579.21), pt(615.95, 507.27), right)
      dim(a.entities, pt(615.95, 507.27), pt(615.95, 309.06), right)
      dim(a.entities, pt(615.95, 309.06), pt(615.95, 198.22), right)
      dim(a.entities, pt(615.95, 198.22), pt(615.95, 0),      right)

      dim_doors(a.entities, ROOM_117, DOORS_117)

      txt = a.entities.add_text("117 — plan dims measured. Ceiling drawn at 8'-0\" (house default, NOT measured).", pt(40, 300, 1))
      txt.layer = t_note if txt
    end

    if BUILD_056
      off  = 900.0
      b = ents.add_group
      b.name = "UNIV HALL 056 - 25'-3\" x 13'-4\""
      poly = ROOM_056.map { |p| [p[0] + off, p[1]] }

      f2 = slab(b.entities, poly, "floor 056", t_floor)
      f2.material = m_floor if f2
      w2 = build_walls(b.entities, poly, CEILING_056, t_room, "walls 056", DOORS_056)
      w2.material = m_wall if w2
      if DRAW_DOORS
        d2 = build_doors(b.entities, poly, DOORS_056, t_door, "doors 056")
        d2.material = m_door if d2
      end

      if BUILD_BOOTH
        booth = BOOTH_056.dup
        booth[:x] = booth[:x] + off
        build_booth(b.entities, booth, BOOTH_H, t_booth, "MDL 96120 + ADA ramp")
      end

      dim(b.entities, pt(off, 0), pt(off + 302.60, 0),                    Geom::Vector3d.new(0, -80, 0))
      dim(b.entities, pt(off + 302.60, 0), pt(off + 302.60, 160.40),      Geom::Vector3d.new(80, 0, 0))
      dim(b.entities, pt(off + 125.80, 160.40), pt(off + 302.60, 160.40), Geom::Vector3d.new(0, 62, 0))
      # the curved wall has no single in-line dimension — give clear width at depth
      dim(b.entities, pt(off + 70.15, 100.40), pt(off + 302.60, 100.40), Geom::Vector3d.new(0, 14, 0))
      dim(b.entities, pt(off + 24.66,  40.40), pt(off + 302.60,  40.40), Geom::Vector3d.new(0, 14, 0))
      dim_doors(b.entities, poly, DOORS_056)

      txt = b.entities.add_text("056 — curved wall traced to ~1\". Ceiling drawn at 8'-0\" (house default, NOT measured).", pt(off + 20, 80, 1))
      txt.layer = t_note if txt
    end

    model.commit_operation
    model.active_view.zoom_extents

    puts ""
    puts "Built. Architectural units. Everything on WR-* tags."
    puts "  117 : 51'-4\" x 48'-3\" (2,013 sq ft net) — 3 doors, all 3'-0\", all swing out"
    puts "        north wall, near jambs 11'-0\" and 27'-0\" east of the NW corner"
    puts "        west  wall, near jamb  11'-6\" north of the SW corner (35'-3\" CL down from NW)"
    puts "  056 : 25'-3\" x 13'-4\" (274 sq ft) — one door, the full 43\" angled NW opening"
    puts "  Walls #{WALL_T}\" thick, mitred at the corners, extruded OUTWARD."
    puts "  Openings cut to #{DOOR_H}\" with a header over; leaves drawn open 90 degrees."
    puts BUILD_BOOTH ? "  Booth MDL 96120 included (placeholder position)." : "  Rooms only (BUILD_BOOTH = false)."
    puts ""
    puts "  NOT MEASURED: ceilings (drawn 8'-0\" house default), DOOR_H #{DOOR_H}\","
    puts "                and the 056 leaf width + hinge side (its 43\" opening IS measured)."
    puts ""
  rescue StandardError => e
    model.abort_operation if model
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(6)
  end
end

WR_CSUSB.build
