# @title David Smith — studio room...
# @cat Draw the room
#
# smith-studio.rb — build David Smith's studio room in SketchUp
#
#   Extensions > Developer > Ruby Console, then:
#     load "C:/Users/bento/Documents/Claude/Sketchup/scripts/smith-studio.rb"
#
# Ctrl+Z before re-running.
#
# ---------------------------------------------------------------------------
# SOURCE
#
# "Studio Diagram (1).pdf" — a HAND SKETCH scanned by the client, sent to Sarah
# Smith 3 Aug 2026 ("an outline of the room that I possibly would like to
# assemble a voice unit in"). Not a scaled drawing: the pencil lines are not to
# scale, so EVERY number here comes from a written dimension on the sketch and
# nothing was scaled off the paper. Where the sketch gives no number, this
# script leaves the feature out rather than inventing one.
#
# ---------------------------------------------------------------------------
# THE CEILING IS THE HEADLINE, AND IT IS TIGHT
#
# The sketch writes "Ceiling Height 7' 3/4"" = 84.75 in. Against the catalogue
# install clearances:
#
#     Standard  6'-11" = 83 in   ->  FITS, with 1.75 in to spare
#     Enhanced  7'-1"  = 85 in   ->  DOES NOT FIT, short by 0.25 in
#
# A quarter of an inch is inside anyone's tape-measure error on a hand sketch,
# so Enhanced is not "ruled out" here, it is "unresolved until measured". Get
# the real floor-to-ceiling before anything Enhanced is quoted. Note also that
# the catalogue figure is the clearance needed to lift the tray ceiling onto the
# booth during assembly, not the booth's own height — so it is a hard number,
# not a comfort margin.
#
# ---------------------------------------------------------------------------
# THE NORTH WALL DOES NOT CLOSE — 11 IN UNACCOUNTED
#
# The sketch dimensions the north ("Exterior") wall as a chain:
#
#     corner box ~5"  +  16"  +  32" entry door  +  25"   =  78"
#
# but it gives the south wall as 7'-4" = 88". The chain is 10-11 in short, and
# there is no dimension on the sheet that closes it. That gap is not split
# silently here, because splitting it would put a made-up door position on a
# drawing a client is going to look at.
#
# Instead the door is drawn TWICE:
#   - solid, on the WEST-referenced position (the 16" runs off the corner box,
#     which is a physical feature, so this is the better-founded of the two)
#   - as a ghost outline on the EAST-referenced position (88" - 25" - 32")
#
# The two sit 10 in apart. Ask David which end he measured from, and the ghost
# disappears.
#
# ---------------------------------------------------------------------------
# WHAT IS WRITTEN ON THE SKETCH (used)      WHAT IS NOT (left out or flagged)
#
#   overall 7'-4" x 11'-2"                    every window WIDTH — the sketch
#   ceiling 7'-0 3/4"                         labels five windows but dimensions
#   32" entry door, 16" and 25" offsets       none of them, so no window is drawn
#   east wall chain: 2'-9", 1'-2" exhaust     the vents' HEIGHT on the wall —
#     vent, 4'-1", 3'-5", 1'-2", 1'-2"          only the along-wall run is given
#     return vent, 1'-2 3/4"                  wall thickness (cosmetic here)
#   two corner boxes at the west corners,     which of the box's two figures is
#     each labelled 4" and 5"                   the 4 and which the 5
#
# The corner boxes are modelled 5" x 5", the larger of the two figures both
# ways. That is the CONSERVATIVE case for fitting a booth against the west
# wall — it can only ever say a booth is tighter than it really is.
#
# NOTHING HERE HAS BEEN CHECKED WITH A TAPE. Treat every figure as the client's
# estimate until someone measures the room.
#
module WR_SmithStudio

  # ─── parameters ────────────────────────────────────────────────────────
  CEILING  = 84.75   # 7'-0 3/4" — WRITTEN ON THE SKETCH, not a house default
  DOOR_H   = 80.0    # 6'-8" standard — ASSUMED, no heights on the sketch
  WALL_T   = 4.0     # cosmetic; built outward so it never moves a dimension

  STD_CLEAR = 83.0   # 6'-11" Standard install clearance
  ENH_CLEAR = 85.0   # 7'-1"  Enhanced install clearance

  DRAW_GHOST_DOOR = true   # the east-referenced alternative entry door position

  MAT_FLOOR = "0128_White"
  MAT_WALL  = "0099_LightSteelBlue"
  MAT_DOOR  = "0043_SaddleBrown"
  MAT_RGB   = {
    "0128_White"          => [255, 255, 255],
    "0099_LightSteelBlue" => [176, 196, 222],
    "0043_SaddleBrown"    => [139,  69,  19]
  }.freeze

  # ─── the room — interior face, inches ──────────────────────────────────
  #
  # Origin = inside south-west corner. +X east, +Y north. North is the
  # "Exterior" wall at the top of the sketch, which carries the 32" entry door.
  #
  # A 88 x 134 rectangle with a 5" square bite out of each west corner.
  BOX = 5.0
  W   = 88.0     # 7'-4"  south wall
  L   = 134.0    # 11'-2" west wall

  ROOM = [
    [ BOX,   0.0 ],  # 0  south wall, east from the SW corner box
    [ W,     0.0 ],  # 1  SE corner
    [ W,     L   ],  # 2  east wall 11'-2" north
    [ BOX,   L   ],  # 3  north wall west to the NW corner box
    [ BOX,   L - BOX ],  # 4  NW box east face
    [ 0.0,   L - BOX ],  # 5  NW box south face
    [ 0.0,   BOX ],  # 6  west wall south
    [ BOX,   BOX ]   # 7  SW box north face
  ].freeze

  # :edge = polygon edge index (edge i runs point i -> i+1)
  # :at   = distance along that edge, from its FIRST point, to the near jamb
  #
  # edge 0 south (83")   1 east (134")   2 north (83")   3,4 NW box
  # edge 5 west (124")   6,7 SW box
  DOORS = [
    # 32" entry door, north wall. Chain runs 16" from the corner box's east
    # face, so the west jamb is at x = 5 + 16 = 21 and the east jamb at 53.
    # Edge 2 runs east-to-west, so :at is measured from x = 88.
    # Hinged east, swings INTO the room — the arc is drawn inside on the sheet.
    { :edge => 2, :at => 35.0, :w => 32.0, :hinge => :start, :swing => :in,
      :leaf => true, :name => "32in entry door (Exterior)" },

    # Interior entry door, east wall. North jamb 4'-1" (49") down from the NE
    # corner, south jamb 3'-5" (41") up from the SE corner. That makes the
    # opening 44" — unusually wide for an interior door, and it comes from two
    # separate dimensions rather than one stated width, so CONFIRM IT.
    { :edge => 1, :at => 41.0, :w => 44.0, :hinge => :end, :swing => :in,
      :leaf => true, :name => "interior entry door (44in - CONFIRM)" }
  ].freeze

  # Wall registers. Only the along-wall run is dimensioned on the sketch — no
  # height, no projection — so these are drawn as thin plates on the wall face
  # purely to show WHERE along the wall they are. Do not read a height off them.
  VENTS = [
    { :edge => 1, :at =>  87.0, :w => 14.0, :name => "exhaust vent 1'-2\"" },
    { :edge => 1, :at =>  14.0, :w => 14.0, :name => "return vent 1'-2\"" }
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

  # Mitred outer polygon — each vertex is where the two offset faces meet, so
  # the corners square off instead of the walls crossing into an X.
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
      quad(grp, [[hx, hy],
                 [hx + (sx * w), hy + (sy * w)],
                 [hx + (sx * w) + (cx * t), hy + (sy * w) + (cy * t)],
                 [hx + (cx * t), hy + (cy * t)]], 0.0, DOOR_H, d[:name].to_s)

      cross = (cx * sy) - (cy * sx)
      grp.entities.add_arc(pt(hx, hy, 0.25),
                           Geom::Vector3d.new(cx, cy, 0),
                           Geom::Vector3d.new(0, 0, cross > 0 ? 1 : -1),
                           w, 0.degrees, 90.degrees, 16)
    end
    grp
  end

  # The east-referenced alternative entry door, drawn as a floor outline only.
  # It is deliberately NOT a solid leaf: it is a question, and a question should
  # not look like a door on a drawing a client reads.
  def self.ghost_door(parent, poly, layer)
    g = parent.add_group
    g.name  = "ALTERNATIVE entry door position (east-referenced)"
    g.layer = layer
    x0 = W - 25.0 - 32.0     # 88 - 25 - 32 = 31
    x1 = W - 25.0            # 63
    y  = L
    g.entities.add_edges(pt(x0, y - 2.0), pt(x1, y - 2.0))
    g.entities.add_edges(pt(x0, y - 2.0), pt(x0, y))
    g.entities.add_edges(pt(x1, y - 2.0), pt(x1, y))
    g.entities.add_arc(pt(x1, y, 0.25), Geom::Vector3d.new(-1, 0, 0),
                       Geom::Vector3d.new(0, 0, -1), 32.0, 0.degrees, 90.degrees, 16)
    g
  end

  # Along-wall position only — see the header. Drawn as a 2" plate so nobody
  # reads a register height off this model.
  def self.build_vents(parent, poly, vents, layer)
    dirs = edge_dirs(poly)
    g = parent.add_group
    g.name  = "vents (ALONG-WALL POSITION ONLY, no height given)"
    g.layer = layer
    vents.each do |v|
      i = v[:edge]
      ax, ay = poly[i]
      ux, uy = dirs[i][:u]
      nx, ny = dirs[i][:n]
      a = [ax + (ux * v[:at]),            ay + (uy * v[:at])]
      b = [ax + (ux * (v[:at] + v[:w])),  ay + (uy * (v[:at] + v[:w]))]
      inn = 1.5
      quad(g, [a, b,
               [b[0] - (nx * inn), b[1] - (ny * inn)],
               [a[0] - (nx * inn), a[1] - (ny * inn)]], 36.0, 2.0, v[:name])
    end
    g
  end

  def self.dim(ents, a, b, off)
    ents.add_dimension_linear(a, b, off)
  rescue StandardError => e
    puts "  (dimension skipped: #{e.message})"
  end

  def self.dim_walls(ents, poly)
    dirs = edge_dirs(poly)
    poly.length.times do |i|
      a = poly[i]
      b = poly[(i + 1) % poly.length]
      next if dirs[i][:len] < 8.0        # the 5" box faces would just be clutter
      nx, ny = dirs[i][:n]
      off = Geom::Vector3d.new(nx * (WALL_T + 14.0), ny * (WALL_T + 14.0), 0)
      dim(ents, pt(a[0], a[1]), pt(b[0], b[1]), off)
    end
  end

  def self.dim_doors(ents, poly, doors)
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
    format("%d'-%s\"", f, (r == r.round ? r.round.to_s : format("%.2f", r)))
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
    model.start_operation("David Smith studio", true)

    t_floor = tag(model, "WR-Studio-Floor", Sketchup::Color.new(200, 200, 200))
    t_wall  = tag(model, "WR-Studio-Walls", Sketchup::Color.new(120, 128, 140))
    t_door  = tag(model, "WR-Studio-Doors", Sketchup::Color.new(238,  98,  22))
    t_vent  = tag(model, "WR-Studio-Vents", Sketchup::Color.new(64, 102, 124))
    t_query = tag(model, "WR-Studio-UNRESOLVED", Sketchup::Color.new(220, 40, 40))
    t_note  = tag(model, "WR-Studio-Notes", Sketchup::Color.new(200, 60, 60))

    room = model.entities.add_group
    room.name  = "David Smith studio (from hand sketch)"
    room.layer = t_floor

    f = slab(room.entities, ROOM, "studio floor", t_floor)
    f.material = material(model, MAT_FLOOR)

    w = build_walls(room.entities, ROOM, CEILING, t_wall, "studio walls", DOORS)
    w.material = material(model, MAT_WALL)

    d = build_doors(room.entities, ROOM, DOORS, t_door, "studio doors")
    d.material = material(model, MAT_DOOR)

    build_vents(room.entities, ROOM, VENTS, t_vent)
    ghost_door(room.entities, ROOM, t_query) if DRAW_GHOST_DOOR

    dim_walls(room.entities, ROOM)
    dim_doors(room.entities, ROOM, DOORS)

    note = room.entities.add_text(
      "David Smith studio — from a HAND SKETCH, nothing measured with a tape.\n" \
      "Ceiling 7'-0 3/4\" (84.75\"): Standard 6'-11\" FITS by 1 3/4\"; " \
      "Enhanced 7'-1\" is 1/4\" SHORT — measure before quoting Enhanced.\n" \
      "North wall chain is 11\" short of the stated 7'-4\". The red outline is the " \
      "alternative entry-door position. Ask David which end he measured from.",
      pt(10.0, 60.0, 1.0))
    note.layer = t_note if note

    model.commit_operation
    model.active_view.zoom_extents

    a = area(ROOM)
    puts ""
    puts "=" * 74
    puts "DAVID SMITH — STUDIO ROOM   (hand sketch, 3 Aug 2026)"
    puts "=" * 74
    puts "  overall        #{ft(W)} x #{ft(L)}   net #{(a / 144.0).round(1)} sq ft"
    puts "  ceiling        #{ft(CEILING)}  — WRITTEN ON THE SKETCH"
    puts ""
    puts "  CEILING CHECK — this is the constraint that decides the booth:"
    puts "    Standard  needs #{ft(STD_CLEAR)}  ->  " \
         "#{CEILING >= STD_CLEAR ? "FITS, #{(CEILING - STD_CLEAR).round(2)}\" to spare" : 'DOES NOT FIT'}"
    puts "    Enhanced  needs #{ft(ENH_CLEAR)}  ->  " \
         "#{CEILING >= ENH_CLEAR ? "FITS, #{(CEILING - ENH_CLEAR).round(2)}\" to spare" : "SHORT BY #{(ENH_CLEAR - CEILING).round(2)}\""}"
    puts "    A quarter inch is inside tape error on a sketch. Enhanced is"
    puts "    UNRESOLVED, not ruled out. Get a real floor-to-ceiling."
    puts ""
    puts "  *** NORTH WALL DOES NOT CLOSE ***"
    puts "    corner box 5\" + 16\" + 32\" door + 25\"  =  78\""
    puts "    stated south wall                      =  88\""
    puts "    unaccounted                            =  10\""
    puts "    The door is drawn on the WEST-referenced position and the"
    puts "    east-referenced alternative is outlined in red, 10\" away."
    puts "    ASK DAVID which end he measured the door from."
    puts ""
    puts "  openings, both swinging into the room:"
    puts "    32\" entry door   north wall, west jamb #{ft(21.0)} from the west wall"
    puts "    interior door    east wall, #{ft(41.0)} up from the SE corner,"
    puts "                     #{ft(44.0)} wide — DERIVED from two dimensions,"
    puts "                     not stated. 44\" is wide for an interior door. CONFIRM."
    puts ""
    puts "  vents, east wall — along-wall position only, no height on the sketch:"
    puts "    return vent   #{ft(14.0)} to #{ft(28.0)} up from the SE corner"
    puts "    exhaust vent  #{ft(87.0)} to #{ft(101.0)} up from the SE corner"
    puts ""
    puts "  NOT DRAWN"
    puts "    Five windows are labelled on the sketch (three west, two south)"
    puts "    but NOT ONE is dimensioned for width, so none is drawn. Only the"
    puts "    1'-5\" offsets at each end of the west wall are given."
    puts ""
    puts "  QUESTIONS FOR DAVID — these change the answer, so ask before quoting:"
    puts "    1. Floor to ceiling, measured. 1/4\" decides Standard vs Enhanced."
    puts "    2. The 32\" entry door: 16\" from the west wall, or 25\" from the"
    puts "       east? Both are on the sketch and they disagree by 10\"."
    puts "    3. The interior door on the east wall — what is its actual width?"
    puts "    4. The two boxes at the west corners: what are they, and which"
    puts "       way round are the 4\" and 5\"? Drawn 5x5 as the tight case."
    puts "    5. Window widths, if the booth is going against a window wall."
    puts ""
    puts "  NO BOOTH IS DRAWN. Sales quotes the model; send the quote link and"
    puts "  it can be placed against these walls."
    puts "=" * 74
    puts ""
  rescue StandardError => e
    model.abort_operation if model
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(8).map { |l| "  #{l}" }.join("\n")
  end
end

WR_SmithStudio.build unless $wr_no_autorun
