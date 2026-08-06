# csusb-rooms.rb — build CSUSB Chaparral 117 + University Hall 056 in SketchUp
#
# Paste into the Ruby Console (Window > Ruby Console), or save this file and run
#     load "C:/Users/bento/Documents/Claude/Sketchup/scripts/csusb-rooms.rb"
#
# WHAT IS ACCURATE HERE
#   The interior wall polygons are the take-off: read from the vector layer of the
#   client's PDFs and scaled off each sheet's printed scale bar. Those coordinates
#   are good to about a quarter-inch of what the drawing says.
#   WALL_T (wall thickness) is cosmetic — walls are extruded OUTWARD from the
#   interior face, so changing it never moves an interior dimension.
#   CEILING_* are GUESSES. Nobody has measured them. Change them before you trust
#   any vertical dimension or any render that shows the ceiling.
#
# Booth is MDL 96120 per quotes W-1108052606 (Enhanced) and W-1108052610 (Standard).
# Exterior 8'-2" x 10'-2"; 6'-11" high Standard, 7'-1" Enhanced.
# ADA package: 32" leaf in a 49" frame, 34.5" swing, ramp protrudes 45.625".
# Clearances follow the quote tool's own rule: 1" nominal, 10" on a vented wall
# with exterior fan silencers, 45.625" on the ADA door wall.

module WR_CSUSB

  # ─── parameters you will want to change ────────────────────────────────
  CEILING_117   = 144.0        # GUESS. Exposed structure — measure to the LOWEST duct/pipe.
  CEILING_056   = 96.0         # GUESS. Suspended lay-in grid — measure floor to tile.
  WALL_T        = 5.0          # cosmetic wall thickness
  BOOTH_H       = 83.0         # 83 = Standard 6'-11" | 85 = Enhanced 7'-1"
  DRAW_DIMS     = true
  BUILD_117     = true
  BUILD_056     = true

  # ─── booth constants (MDL 96120 + ADA package) ────────────────────────
  BOOTH_W       = 98.0         # 8'-2"
  BOOTH_L       = 122.0        # 10'-2"
  RAMP_PROT     = 45.625       # ADA ramp protrusion off the door wall
  DOOR_LEAF     = 32.0         # ADA leaf inside a 49" frame
  VENT_CLR      = 10.0         # vented wall with exterior fan silencer boxes
  NOM_CLR       = 1.0          # recommended gap everywhere else

  # ─── room 117, Chaparral Hall — interior face, inches ──────────────────
  # origin = inside south-west corner, +X east, +Y north
  ROOM_117 = [
    [   0.00, 579.21 ],  # NW
    [ 522.09, 579.21 ],  # north wall runs 43'-6" to the 117A closet
    [ 522.09, 507.27 ],  # 117A west face, 6'-0" deep
    [ 615.95, 507.27 ],  # 117A east face  (117A is 7'-10" wide)
    [ 615.95, 309.06 ],  # east wall exposed run, 16'-6"
    [ 501.92, 309.06 ],  # 109A north wall, 9'-6" wide
    [ 501.92, 198.22 ],  # 109A west face, 9'-3" deep
    [ 376.05, 198.22 ],  # return west to the 123 block, 10'-6"
    [ 376.05,   0.00 ],  # 123 block west face, 16'-6" deep
    [   0.00,   0.00 ]   # SW
  ].freeze

  # doors: [x, y, width, axis]  — axis :x runs along a N/S wall, :y along an E/W wall
  DOORS_117 = [
    [ 132.60, 579.21, 36.0, :x ],   # north wall, centreline 12'-7" from the NW corner
    [ 324.40, 579.21, 36.0, :x ],   # north wall, centreline 28'-6"
    [   0.00, 137.90, 36.0, :y ]    # west  wall, centreline 35'-3" down from the NW corner
  ].freeze

  COLUMN_117 = [ 186.00, 187.30, 15.9 ].freeze   # [x, y, side] — 15'-6" E, 32'-3" S of the NW corner

  # ─── room 056, University Hall — interior face, inches ─────────────────
  # The west side is the building's curved outer wall, traced as eight points off
  # its inner face. Faithful to about an inch; it is not the exact radius.
  ROOM_056 = [
    [ 302.60, 160.40 ],  # NE
    [ 125.80, 160.40 ],  # north wall, 14'-9"
    [  95.80, 129.60 ],  # ── door opening in the short angled wall ──
    [  78.20, 109.87 ],
    [  61.20,  89.87 ],
    [  45.60,  69.87 ],  # curved outer wall
    [  31.00,  49.87 ],
    [  17.60,  29.87 ],
    [   4.80,   9.87 ],
    [   0.00,   0.00 ],  # SW
    [ 302.60,   0.00 ]   # SE — south wall 25'-3", east wall 13'-4"
  ].freeze

  # ─── booth placement ───────────────────────────────────────────────────
  # 056: south-east corner ("toward the back", per Maxine), long axis north-south,
  # ADA door and ramp facing WEST into the open part of the room. 10" reserved on
  # the east wall for the vent/silencer side, 1" on the south.
  BOOTH_056 = { :x => 194.60, :y => 1.00, :w => BOOTH_W, :l => BOOTH_L, :door => :W }

  # 117: PLACEHOLDER ONLY. Maxine located the spot by photo ("where the student
  # desks are in Room 1C"), not by compass, so the wall is not yet known. This
  # drops the booth near the north-west corner purely so it exists in the model —
  # move it once she confirms the wall.
  BOOTH_117 = { :x => 60.00, :y => 400.00, :w => BOOTH_L, :l => BOOTH_W, :door => :S }

  # ═══════════════════════════════════════════════════════════════════════
  def self.pt(x, y, z = 0.0)
    Geom::Point3d.new(x, y, z)
  end

  def self.tag(model, name, color = nil)
    layer = model.layers[name] || model.layers.add(name)
    layer.color = color if color
    layer
  end

  # extrude a closed polygon upward; returns the group
  def self.slab(parent, poly, thickness, name, layer)
    grp  = parent.add_group
    face = grp.entities.add_face(poly.map { |p| pt(p[0], p[1], 0.0) })
    return grp if face.nil?
    face.reverse! if face.normal.z < 0
    face.pushpull(thickness) if thickness > 0
    grp.name  = name
    grp.layer = layer
    grp
  end

  # one wall per polygon edge, extruded OUTWARD from the interior face so the
  # interior dimensions stay exactly as measured. Ends are extended by WALL_T so
  # corners close.
  def self.build_walls(parent, poly, height, layer, name)
    walls = parent.add_group
    walls.name  = name
    walls.layer = layer
    n = poly.length
    n.times do |i|
      ax, ay = poly[i]
      bx, by = poly[(i + 1) % n]
      dx, dy = bx - ax, by - ay
      len = Math.sqrt(dx * dx + dy * dy)
      next if len < 0.01
      ux, uy = dx / len, dy / len
      # outward normal: interior polygon is wound counter-clockwise, so the
      # outward side is to the RIGHT of travel
      nx, ny = uy, -ux
      ex, ey = ux * WALL_T, uy * WALL_T          # corner extension
      ox, oy = nx * WALL_T, ny * WALL_T          # thickness offset
      quad = [
        [ ax - ex,           ay - ey           ],
        [ bx + ex,           by + ey           ],
        [ bx + ex + ox,      by + ey + oy      ],
        [ ax - ex + ox,      ay - ey + oy      ]
      ]
      g = walls.entities.add_group
      f = g.entities.add_face(quad.map { |p| pt(p[0], p[1], 0.0) })
      next if f.nil?
      f.reverse! if f.normal.z < 0
      f.pushpull(height)
      g.name = "wall"
    end
    walls
  end

  def self.build_doors(parent, doors, layer)
    grp = parent.add_group
    grp.name  = "door openings"
    grp.layer = layer
    doors.each do |x, y, w, axis|
      a = (axis == :x) ? [[x, y], [x + w, y]] : [[x, y], [x, y + w]]
      grp.entities.add_edges(pt(a[0][0], a[0][1], 0.1), pt(a[1][0], a[1][1], 0.1))
      # swing arc, 90 degrees, drawn into the room side
      c  = pt(a[0][0], a[0][1], 0.1)
      v1 = Geom::Vector3d.new(a[1][0] - a[0][0], a[1][1] - a[0][1], 0)
      grp.entities.add_arc(c, v1, Geom::Vector3d.new(0, 0, 1), w, 0.degrees, 90.degrees, 16)
    end
    grp
  end

  # booth as a box + ADA ramp wedge + door swing
  def self.build_booth(parent, spec, height, layer, label)
    g = parent.add_group
    g.name  = label
    g.layer = layer
    x, y, w, l = spec[:x], spec[:y], spec[:w], spec[:l]

    box = g.entities.add_group
    f = box.entities.add_face([pt(x, y), pt(x + w, y), pt(x + w, y + l), pt(x, y + l)])
    unless f.nil?
      f.reverse! if f.normal.z < 0
      f.pushpull(height)
    end
    box.name = "#{label} shell"

    # ADA ramp — a wedge running out from the door wall, RAMP_PROT deep
    r = g.entities.add_group
    r.name = "ADA ramp (#{RAMP_PROT.round(1)}\" protrusion)"
    case spec[:door]
    when :W then rq = [[x - RAMP_PROT, y], [x, y], [x, y + l], [x - RAMP_PROT, y + l]]
    when :E then rq = [[x + w, y], [x + w + RAMP_PROT, y], [x + w + RAMP_PROT, y + l], [x + w, y + l]]
    when :S then rq = [[x, y - RAMP_PROT], [x + w, y - RAMP_PROT], [x + w, y], [x, y]]
    else         rq = [[x, y + l], [x + w, y + l], [x + w, y + l + RAMP_PROT], [x, y + l + RAMP_PROT]]
    end
    rf = r.entities.add_face(rq.map { |p| pt(p[0], p[1], 0.0) })
    unless rf.nil?
      rf.reverse! if rf.normal.z < 0
      rf.pushpull(1.5)
    end
    g
  end

  def self.dim(ents, a, b, off)
    return unless DRAW_DIMS
    ents.add_dimension_linear(a, b, off)
  rescue StandardError => e
    puts "  (dimension skipped: #{e.message})"
  end

  # ═══════════════════════════════════════════════════════════════════════
  def self.build
    model = Sketchup.active_model
    model.start_operation("CSUSB rooms + MDL 96120", true)

    t_room  = tag(model, "WR-Room",   Sketchup::Color.new(120, 128, 140))
    t_floor = tag(model, "WR-Floor",  Sketchup::Color.new(200, 200, 200))
    t_booth = tag(model, "WR-Booth",  Sketchup::Color.new(238,  98,  22))
    t_door  = tag(model, "WR-Doors",  Sketchup::Color.new( 64, 102, 124))
    t_note  = tag(model, "WR-Notes",  Sketchup::Color.new( 30,  30,  30))

    ents = model.entities

    if BUILD_117
      a = ents.add_group
      a.name = "CHAPARRAL 117 - 51'-4\" x 48'-3\""
      slab(a.entities, ROOM_117, 0, "floor 117", t_floor)
      build_walls(a.entities, ROOM_117, CEILING_117, t_room, "walls 117")
      build_doors(a.entities, DOORS_117, t_door)

      cx, cy, cs = COLUMN_117
      col = a.entities.add_group
      col.name  = "column ~16\" sq"
      col.layer = t_room
      cf = col.entities.add_face([pt(cx, cy), pt(cx + cs, cy), pt(cx + cs, cy + cs), pt(cx, cy + cs)])
      unless cf.nil?
        cf.reverse! if cf.normal.z < 0
        cf.pushpull(CEILING_117)
      end

      build_booth(a.entities, BOOTH_117, BOOTH_H, t_booth, "MDL 96120 - PLACEHOLDER, confirm wall")

      dim(a.entities, pt(0, 579.21), pt(615.95, 579.21), Geom::Vector3d.new(0,  70, 0))
      dim(a.entities, pt(0, 579.21), pt(0, 0),           Geom::Vector3d.new(-70, 0, 0))
      dim(a.entities, pt(0, 579.21), pt(522.09, 579.21), Geom::Vector3d.new(0,  36, 0))
      txt = a.entities.add_text("117 — dimensions from the drawing; ceiling height is a GUESS", pt(40, 300, 1))
      txt.layer = t_note if txt
    end

    if BUILD_056
      off = 900.0    # park 056 to the east of 117 so both are visible
      b = ents.add_group
      b.name = "UNIV HALL 056 - 25'-3\" x 13'-4\""
      poly  = ROOM_056.map { |p| [p[0] + off, p[1]] }
      booth = BOOTH_056.dup
      booth[:x] += off

      slab(b.entities, poly, 0, "floor 056", t_floor)
      build_walls(b.entities, poly, CEILING_056, t_room, "walls 056")
      build_booth(b.entities, booth, BOOTH_H, t_booth, "MDL 96120 + ADA ramp")

      dim(b.entities, pt(off, 0), pt(off + 302.60, 0),               Geom::Vector3d.new(0, -60, 0))
      dim(b.entities, pt(off + 302.60, 0), pt(off + 302.60, 160.40), Geom::Vector3d.new(60, 0, 0))
      dim(b.entities, pt(off + 125.80, 160.40), pt(off + 302.60, 160.40), Geom::Vector3d.new(0, 60, 0))
      txt = b.entities.add_text("056 — curved wall traced to ~1\"; ceiling height is a GUESS", pt(off + 20, 80, 1))
      txt.layer = t_note if txt
    end

    model.commit_operation
    model.active_view.zoom_extents

    puts ""
    puts "Built. Everything is on WR-* tags so you can switch pieces off."
    puts "  Room 117 interior : 51'-4\" x 48'-3\"   (2,013 sq ft net)"
    puts "  Room 056 interior : 25'-3\" x 13'-4\"   (274 sq ft)"
    puts "  Booth MDL 96120   : 8'-2\" x 10'-2\" x #{BOOTH_H == 85.0 ? "7'-1\" Enhanced" : "6'-11\" Standard"}"
    puts "  ADA ramp adds     : #{RAMP_PROT}\" off the door wall"
    puts ""
    puts "  CEILING_117 = #{CEILING_117}\" and CEILING_056 = #{CEILING_056}\" are PLACEHOLDERS."
    puts "  The 117 booth position is a PLACEHOLDER until the wall is confirmed."
    puts ""
  rescue StandardError => e
    model.abort_operation if model
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(6)
  end
end

WR_CSUSB.build
