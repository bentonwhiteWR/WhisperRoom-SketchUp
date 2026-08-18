# @title CSUSB Chaparral 106...
# @cat Draw the room
#
# csusb-106.rb — build CSUSB Chaparral Hall room 106 in SketchUp
#
#   Extensions > Developer > Ruby Console, then:
#     load "C:/Users/bento/Documents/Claude/Sketchup/scripts/csusb-106.rb"
#
# Ctrl+Z before re-running. Everything is imperial; units are set to
# Architectural on build.
#
# ---------------------------------------------------------------------------
# WHERE THE NUMBERS CAME FROM
#
# Source: "FloorPlan Layout Example.pdf", sheet A-1, CSUSB Capital Planning,
# 003 Chaparral Hall, dated 8/17/2021. That sheet is a VECTOR pdf, not a scan,
# so the wall lines were read straight out of the drawing's own path data
# rather than measured off pixels.
#
# SCALE IS EXACT, NOT ESTIMATED. The sheet prints at 1" = 30'-0". A pdf point
# is 1/72 in of paper, so one point is 30*12/72 = 5.000 inches of building.
# No scale bar was traced and no ratio was fitted.
#
# The scale was then CHECKED against the drawing rather than trusted: interior
# partitions come out 0.96 pt = 4.8 in thick, and csusb-rooms.rb records the
# same walls on the same sheet as "4.9 in N/S" from an independent read. Two
# reads agreeing to a tenth of an inch is what makes the polygon below good to
# about a quarter-inch, which is the same grade as room 117.
#
# The room outline was confirmed a second way: the drawing was rasterised at
# 1200 dpi and flood-filled from inside 106. The filled region matches the
# polygon below, and its area (552 sq ft measured inside the ink) brackets the
# polygon's 575 sq ft as expected, since the fill stops at the inside of every
# drawn line weight.
#
# WHAT IS MEASURED
#   ROOM_106  interior wall faces, to about a quarter-inch.
#   DOORS     both openings' widths and positions, read off the wall gaps.
#             Hinge side and swing direction read off the drawn leaf and arc.
#   OPENINGS  the two cased openings, read off where the walls stop.
#
# WHAT IS NOT MEASURED — these are assumptions and are printed on build
#   CEILING   8'-0" house default. Nobody has measured 106. This is the number
#             that disqualifies a booth fastest, so it is worth a tape.
#   DOOR_H    standard 6'-8". There are no elevations on the sheet.
#   WALL_T    cosmetic. Walls are mitred OUTWARD from the interior face, so
#             this never moves an interior dimension. The sheet actually draws
#             the partitions at 4.8" and the north exterior wall at 11.7";
#             4" is the house default and is left alone deliberately.
#
# NOT MODELLED, AND WHY
#   The 108 doorway is a recess about 41" wide and 38" deep in the south-west
#   wall. It is built here as a plain cased opening in that wall, because the
#   room-108 door that sits inside it belongs to 108, not to 106, and its own
#   leaf and hinge could not be read cleanly off the sheet. For booth fit that
#   is the right simplification: what 106 has on that wall is a 41" opening.
#
module WR_CSUSB_106

  # ─── parameters ────────────────────────────────────────────────────────
  CEILING  = 96.0    # 8'-0" HOUSE DEFAULT — not measured, see the header
  DOOR_H   = 80.0    # 6'-8" standard leaf — not measured
  WALL_T   = 4.0     # cosmetic; built outward so it never moves a dimension

  DRAW_DOORS = true
  DRAW_DIMS  = true
  DIM_DOORS  = true  # corner -> near jamb, then the opening width

  MAT_FLOOR = "0128_White"
  MAT_WALL  = "0099_LightSteelBlue"
  MAT_DOOR  = "0043_SaddleBrown"
  MAT_RGB   = {
    "0128_White"          => [255, 255, 255],
    "0099_LightSteelBlue" => [176, 196, 222],
    "0043_SaddleBrown"    => [139,  69,  19]
  }.freeze

  # ─── room 106 — interior face, inches ──────────────────────────────────
  #
  # Origin = the inside corner where the west wall meets the north face of the
  # 108/T108 block. +X east, +Y north. North on the sheet is up.
  #
  # 106 is a Z: a tall west bay, a notch out of the north-east where 106A sits,
  # and a leg running south-east to the corridor.
  ROOM_106 = [
    [   0.00, 135.00 ],  # 0  west wall, at the 108 block's north face
    [   0.00, 368.40 ],  # 1  NW — west wall runs 19'-5.4"
    [ 180.60, 368.40 ],  # 2  north wall 15'-0.6" east to 106A
    [ 180.60, 270.30 ],  # 3  106A west face, 8'-2.1" deep
    [ 333.30, 270.30 ],  # 4  106A south face, 12'-8.7" east to the east wall
    [ 333.30,   0.00 ],  # 5  east wall 22'-6.3" south to the corridor
    [ 185.40,   0.00 ],  # 6  corridor wall 12'-3.9" west
    [ 185.40, 135.00 ]   # 7  108 block east face, 11'-3" north
  ].freeze

  # :edge = polygon edge index (edge i runs point i -> i+1)
  # :at   = distance along that edge, from its FIRST point, to the near jamb
  # :leaf = false for a cased opening — the wall is cut, no door is drawn
  DOORS_106 = [
    # 106A's door, in the wall 106 shares with 106A. Leaf and arc are drawn on
    # the sheet swinging south into 106, hinged on its east jamb.
    { :edge => 3, :at =>  28.20, :w => 35.10, :hinge => :end,   :swing => :in,  :leaf => true },
    # The corridor door onto C100. Arc is drawn south of the wall — it swings
    # OUT of the room into the corridor — hinged on its east jamb.
    { :edge => 5, :at =>  58.50, :w => 34.80, :hinge => :start, :swing => :out, :leaf => true },
    # Cased opening to room 104. The east wall simply stops 59.4" short of the
    # corridor wall and no leaf is drawn anywhere near it.
    { :edge => 4, :at => 210.90, :w => 59.40, :hinge => :start, :swing => :out, :leaf => false },
    # Cased opening into the 108 doorway recess. See the header.
    { :edge => 7, :at =>   4.80, :w => 40.80, :hinge => :start, :swing => :out, :leaf => false }
  ].freeze

  # ═══════════════════════════════════════════════════════════════════════

  def self.pt(x, y, z = 0.0)
    Geom::Point3d.new(x, y, z)
  end

  def self.tag(model, name, color = nil)
    layer = model.layers[name] || model.layers.add(name)
    layer.color = color if color
    layer
  end

  # Signed area. The winding is not hard-coded because a polygon typed off a
  # plan can come out either way round, and getting it wrong turns every wall
  # inside out without any other symptom.
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

  # Mitred outer polygon: every vertex is where the two offset wall faces meet.
  # Extending each wall by its own thickness instead would cross them into an X
  # at the corners.
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
      nil
    end
    m = model.materials.add(name)
    m.color = Sketchup::Color.new(*(MAT_RGB[name] || [200, 200, 200]))
    m
  end

  def self.slab(parent, poly, name, layer)
    grp = parent.add_group
    f = grp.entities.add_face(poly.map { |p| pt(p[0], p[1], 0.0) })
    f.reverse! if f && f.normal.z < 0
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
        quad(walls, [inner.call(s), inner.call(e), outp.call(e), outp.call(s)],
             0.0, height, "wall") if (e - s) > 0.05
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

  # Leaf drawn open 90 degrees on the measured hinge side, plus its floor arc.
  # A cased opening (:leaf => false) is skipped entirely — the wall is already
  # cut by build_walls, and drawing a leaf on an opening that has none is how a
  # drawing starts telling a client something the building does not do.
  def self.build_doors(parent, poly, doors, layer, name)
    dirs = edge_dirs(poly)
    grp  = parent.add_group
    grp.name  = name
    grp.layer = layer

    doors.each do |d|
      next unless d[:leaf]
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
        [hx,                       hy                      ],
        [hx + (sx * w),            hy + (sy * w)           ],
        [hx + (sx * w) + (cx * t), hy + (sy * w) + (cy * t)],
        [hx + (cx * t),            hy + (cy * t)           ]
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

  def self.dim(ents, a, b, off)
    return unless DRAW_DIMS
    ents.add_dimension_linear(a, b, off)
  rescue StandardError => e
    puts "  (dimension skipped: #{e.message})"
  end

  # Every wall run gets its own dimension string, and every opening is
  # dimensioned corner -> near jamb then jamb -> jamb. That second pair is what
  # a booth actually gets placed against, so it is not optional.
  def self.dim_walls(ents, poly)
    dirs = edge_dirs(poly)
    poly.length.times do |i|
      a = poly[i]
      b = poly[(i + 1) % poly.length]
      nx, ny = dirs[i][:n]
      off = Geom::Vector3d.new(nx * (WALL_T + 14.0), ny * (WALL_T + 14.0), 0)
      dim(ents, pt(a[0], a[1]), pt(b[0], b[1]), off)
    end
  end

  def self.dim_doors(ents, poly, doors)
    return unless DIM_DOORS
    dirs = edge_dirs(poly)
    doors.each do |d|
      i = d[:edge]
      ax, ay = poly[i]
      ux, uy = dirs[i][:u]
      nx, ny = dirs[i][:n]
      off1 = Geom::Vector3d.new(nx * (WALL_T + 34.0), ny * (WALL_T + 34.0), 0)
      off2 = Geom::Vector3d.new(nx * (WALL_T + 54.0), ny * (WALL_T + 54.0), 0)
      corner = pt(ax, ay)
      near   = pt(ax + (ux * d[:at]),           ay + (uy * d[:at]))
      far    = pt(ax + (ux * (d[:at] + d[:w])), ay + (uy * (d[:at] + d[:w])))
      dim(ents, corner, near, off1)
      dim(ents, near,   far,  off2)
    end
  end

  def self.area(poly)
    s = 0.0
    n = poly.length
    n.times do |i|
      ax, ay = poly[i]
      bx, by = poly[(i + 1) % n]
      s += (ax * by) - (bx * ay)
    end
    s.abs / 2.0
  end

  def self.ft(inches)
    f = (inches / 12.0).floor
    r = inches - (f * 12.0)
    format("%d'-%.1f\"", f, r)
  end

  def self.set_imperial(model)
    o = model.options["UnitsOptions"]
    o["LengthFormat"] = Length::Architectural
    o["LengthUnit"]   = Length::Inches
  rescue StandardError => e
    puts "  (couldn't set units: #{e.message} — set Model Info > Units to Architectural)"
  end

  # ═══════════════════════════════════════════════════════════════════════
  def self.build
    model = Sketchup.active_model
    set_imperial(model)
    model.start_operation("CSUSB Chaparral 106", true)

    t_floor = tag(model, "WR-106-Floor",  Sketchup::Color.new(200, 200, 200))
    t_wall  = tag(model, "WR-106-Walls",  Sketchup::Color.new(120, 128, 140))
    t_door  = tag(model, "WR-106-Doors",  Sketchup::Color.new(238,  98,  22))
    t_dim   = tag(model, "WR-106-Dims",   Sketchup::Color.new(40,   40,  40))
    t_note  = tag(model, "WR-106-Notes",  Sketchup::Color.new(200,  60,  60))

    m_floor = material(model, MAT_FLOOR)
    m_wall  = material(model, MAT_WALL)
    m_door  = material(model, MAT_DOOR)

    room = model.entities.add_group
    room.name  = "CSUSB Chaparral 106"
    room.layer = t_floor

    # slab/build_walls/build_doors call parent.add_group, so they take an
    # ENTITIES, not a Group. quad() takes a Group and reaches for .entities
    # itself. Passing the group here raises NoMethodError on Group#add_group.
    f = slab(room.entities, ROOM_106, "106 floor", t_floor)
    f.material = m_floor

    w = build_walls(room.entities, ROOM_106, CEILING, t_wall, "106 walls", DOORS_106)
    w.material = m_wall

    if DRAW_DOORS
      d = build_doors(room.entities, ROOM_106, DOORS_106, t_door, "106 doors")
      d.material = m_door
    end

    dims = room.entities
    dim_walls(dims, ROOM_106)
    dim_doors(dims, ROOM_106, DOORS_106)
    room.entities.grep(Sketchup::Dimension).each { |x| x.layer = t_dim }

    note = room.entities.add_text(
      "106 — walls from the A-1 vector pdf at 1\" = 30' (1 pt = 5.000 in), good to ~1/4\".\n" \
      "Ceiling drawn at 8'-0\" HOUSE DEFAULT — NOT MEASURED. Get a tape on it before quoting a booth.",
      pt(20.0, 200.0, 1.0))
    note.layer = t_note if note

    model.commit_operation
    model.active_view.zoom_extents

    a = area(ROOM_106)
    puts ""
    puts "=" * 72
    puts "CSUSB Chaparral Hall — room 106"
    puts "=" * 72
    puts "  net floor area   #{(a / 144.0).round(1)} sq ft   (#{a.round} sq in)"
    puts "  bounding box     #{ft(333.30)} east-west  x  #{ft(368.40)} north-south"
    puts ""
    puts "  wall runs, interior face, clockwise from the west wall:"
    puts "    west            #{ft(233.40)}"
    puts "    north           #{ft(180.60)}"
    puts "    106A west face  #{ft(98.10)}"
    puts "    106A south face #{ft(152.70)}"
    puts "    east            #{ft(270.30)}"
    puts "    corridor (S)    #{ft(147.90)}"
    puts "    108 east face   #{ft(135.00)}"
    puts "    108 north face  #{ft(185.40)}"
    puts "  chain closes on itself by construction — the polygon is a closed loop."
    puts ""
    puts "  openings:"
    puts "    106A door       #{ft(35.10)} wide, #{ft(28.20)} from the 106A west corner,"
    puts "                    hinged east, swings INTO 106"
    puts "    corridor door   #{ft(34.80)} wide, #{ft(58.50)} west of the south-east corner,"
    puts "                    hinged east, swings OUT into C100"
    puts "    to room 104     #{ft(59.40)} cased opening at the south end of the east wall"
    puts "    to room 108     #{ft(40.80)} cased opening in the 108 north face"
    puts ""
    puts "  MEASURED    wall faces, opening widths and positions, hinge + swing"
    puts "  ASSUMED     ceiling #{ft(CEILING)} (house default, NOT measured)"
    puts "              door height #{ft(DOOR_H)} (no elevations on the sheet)"
    puts "              wall thickness #{WALL_T}\" (cosmetic — built outward from the"
    puts "              interior face, so it never moves a dimension. Sheet draws 4.8\".)"
    puts "  NOT BUILT   the 108 doorway recess is flattened to a plain #{ft(40.80)} opening"
    puts ""
    puts "  Nothing here has been checked against a tape. Treat every figure as"
    puts "  estimated from the drawing until someone measures the room."
    puts "=" * 72
    puts ""
  rescue StandardError => e
    model.abort_operation if model
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(8).map { |l| "  #{l}" }.join("\n")
  end
end

WR_CSUSB_106.build unless $wr_no_autorun
