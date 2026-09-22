# WhisperRoom concept art — the HOST ROOM and its furniture, around a
# link-built booth.
#
#   $wr_no_autorun = true
#   load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/concept-art/scene-build.rb'
#   WR_Concept.run!(:all)        # or :room, :props, :foam
#
# Re-runnable on a model that already has the booth: every top-level thing
# this file makes carries the attribute  wr_concept/role  and is erased before
# it is rebuilt. The booth group ("MDL 96120 E (components)") is never moved or
# edited, EXCEPT one material: [Color_I06], which the Foam definition alone
# uses (observed 22 Sep 2026: 1447 faces, no other user), is recoloured to the
# reported Purple foam colour.
#
# THE ROOM FOLLOWS THE HOUSE CONVENTIONS so the house tools read it:
#   * wr-drop-lights.rb finds a room by a child on tag WR-Floor whose largest
#     face is the floor polygon, and takes the ceiling height from the child
#     on tag WR-Room ("Walls").
#   * wr-scene-walls.rb / wr-autoset.rb hide walls per scene by piece NAME:
#     "Wall <n>" within two group levels of a top-level group. Windows and the
#     slat panelling are named "Wall <n> ..." so they hide with their wall.
#   * the "Ceiling" child (tag WR-Ceiling) holds the slab AND the joists, so a
#     high or plan plate that hides the ceiling hides the joists with it.
#
# Coordinates are the booth's own: booth shell x 0..122, y 0..98 (south face
# at y = 0 carries the door, ramp and the 3236 window; east face at x = 122
# carries the 3248 and 3242 windows). +y is north, +x is east.
#
# NOTHING HERE IS MEASURED. It is a designed set; every size is ASSUMED (a
# plausible converted loft) and lives in a constant so it can be changed.
#
# MATERIALS. New materials are SketchUp 2026 PBR materials (workflow,
# roughness, metalness) — V-Ray exposes them as _HostMaterial (observed), so no
# V-Ray material plugin is ever created or written here (creating/writing new
# material plugins from Ruby has hung SketchUp four times, see
# .forge/builder/HANDOFF-sunoff.md). The floor, brick, rug and exterior ground
# reuse Chaos Cosmos V-Ray materials already present in the model.

module WR_Concept
  DICT = 'wr_concept'.freeze

  # ---- the room (interior faces), inches --------------------------------
  Z0 = -1.3            # floor top: the booth's lowest deck part sits at -1.3
  H  = 168.0           # 14'-0" clear to the ceiling slab (assumed loft)
  XW = -90.0           # west wall inner face  (7'-6" off the booth's W face, so
                       #   AUTO-SET's ventilation eye stands inside the room)
  XE = 300.0           # east wall inner face  (room 32'-6" E-W)
  YS = -260.0          # south wall inner face (the ramp faces 19'-8" of floor,
                       #   and AUTO-SET's angled eye stands inside this wall)
  YN = 134.0           # north wall inner face
  # THE BOOTH BACKS INTO THE NORTH-WEST CORNER, 18 in off both walls (Benton,
  # 22 Sep 2026: 18 in off the room's perimeter walls). The corner is the
  # coordinator's call, not Benton's: the cable walls (N, W) face the room
  # walls and the door, ramp and three windows face the open room.
  BOOTH_GAP = 18.0
  T  = 10.0            # wall thickness, cosmetic, built outward
  JOIST_PITCH = 65.0   # see build_ceiling!
  JOIST_START = 32.5   # first joist this far east of the west wall

  # Window openings, [a0, a1, sill, head] along the wall's own axis.
  SOUTH_WIN = [[-70.0, 14.0, 20.0, 140.0], [60.0, 144.0, 20.0, 140.0],
               [190.0, 274.0, 20.0, 140.0]].freeze
  WEST_WIN  = [[-236.0, -166.0, 20.0, 140.0], [-142.0, -72.0, 20.0, 140.0]].freeze

  BRAND_ORANGE = [238, 98, 22].freeze          # #ee6216, the one accent
  # #6a4aa8 — ASSUMED. The reported product colour (#5858bc, WhisperRoomQuote
  # assets/layout-render.js "measured") renders plainly BLUE in V-Ray (observed
  # 22 Sep 2026), so the hue is pushed to purple at similar lightness. The
  # repo's other reference, iso-render.js, says #4f336a. Benton to confirm.
  FOAM_PURPLE  = [106, 74, 168].freeze

  SKM = 'C:/ProgramData/SketchUp/SketchUp 2026/SketchUp/Materials'.freeze

  def self.model; Sketchup.active_model; end

  # ------------------------------------------------------------ materials --
  # A SketchUp PBR material. rough 0..1, metal 0..1 (nil = off).
  def self.pbr(name, rgb, rough, metal = nil)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*rgb)
    m.roughness_enabled = true
    m.roughness_factor = rough.to_f
    if metal
      m.metalness_enabled = true
      m.metallic_factor = metal.to_f
    else
      m.metalness_enabled = false
    end
    m
  end

  # Load a SketchUp 2026 library .skm once; returns the Material.
  def self.skm(rel, as)
    return model.materials[as] if model.materials[as]
    path = File.join(SKM, rel)
    raise "no such material file: #{path}" unless File.exist?(path)
    m = model.materials.load(path)
    m.name = as if m.name != as
    m
  end

  def self.cosmos(name)
    m = model.materials[name]
    raise "Cosmos material #{name.inspect} is not in this model" if m.nil?
    m
  end

  RECORD_COLOURS = [[168, 52, 38], [36, 58, 92], [214, 196, 160], [30, 30, 32],
                    [196, 142, 44], [78, 104, 74], [120, 38, 62], [230, 226, 214],
                    [52, 118, 138], [150, 86, 50]].freeze

  def self.materials!
    @m = {}
    @m[:floor]    = cosmos('Oak Honey Semigloss 300cm')
    @m[:brick]    = cosmos('Brick Wall Red 07 250cm')
    @m[:rug]      = cosmos('Wool_D01_20cm#1')
    @m[:ground]   = cosmos('Concrete Simple G01 400cm')
    @m[:beam]     = cosmos('Oak Honey Semigloss 300cm')
    @m[:plaster]  = pbr('CA Plaster Warm White', [226, 220, 208], 0.9)
    @m[:ceiling]  = pbr('CA Ceiling Charcoal', [46, 46, 48], 0.95)
    @m[:steel]    = pbr('CA Blackened Steel', [30, 30, 32], 0.42, 0.6)
    @m[:slat]     = skm('Wood/Wood_Veneer_15_1K.skm', 'CA Oak Slat')
    @m[:felt]     = pbr('CA Felt Black', [20, 20, 21], 1.0)
    @m[:orange]   = pbr('CA Brand Orange Linen', BRAND_ORANGE, 0.85)
    @m[:skirting] = pbr('CA Skirting', [34, 34, 36], 0.6)
    @m[:walnut]   = pbr('CA Walnut', [92, 60, 40], 0.38)
    @m[:screen]   = pbr('CA Screen Glass', [6, 6, 8], 0.06)
    @m[:plastic]  = pbr('CA Black Plastic', [22, 22, 24], 0.45)
    @m[:cone]     = pbr('CA Speaker Cone', [40, 40, 42], 0.7)
    @m[:ring]     = pbr('CA Speaker Ring', [200, 200, 196], 0.3, 0.8)
    @m[:spruce]   = pbr('CA Guitar Spruce', [214, 170, 110], 0.18)
    @m[:rosewood] = pbr('CA Guitar Rosewood', [74, 38, 22], 0.22)
    @m[:hole]     = pbr('CA Guitar Hole', [10, 8, 6], 1.0)
    @m[:ceramic]  = pbr('CA Ceramic Stone', [196, 190, 178], 0.5)
    @m[:records]  = RECORD_COLOURS.each_with_index.map do |c, i|
      pbr("CA Sleeve #{i + 1}", c, 0.55)
    end
    @m
  end

  # ------------------------------------------------------------- geometry --
  def self.tag(e, role)
    e.set_attribute(DICT, 'role', role)
    e
  end

  def self.layer(name)
    model.layers[name] || model.layers.add(name)
  end

  # An axis-aligned box as its own group inside `ents`, painted `m`.
  def self.box(ents, x0, y0, z0, x1, y1, z1, m = nil, name = nil)
    x0, x1 = [x0, x1].minmax
    y0, y1 = [y0, y1].minmax
    z0, z1 = [z0, z1].minmax
    return nil if (x1 - x0) < 0.01 || (y1 - y0) < 0.01 || (z1 - z0) < 0.01
    g = ents.add_group
    f = g.entities.add_face([x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0])
    f.reverse! if f.normal.z < 0
    f.pushpull(z1 - z0)
    g.material = m if m
    g.name = name if name
    g
  end

  # A box with every edge chamfered by b, the chamfers softened so they shade
  # as a small round-over. 26 faces: 6 main, 12 edge strips, 8 corner caps.
  def self.bevel_box(ents, x0, y0, z0, x1, y1, z1, b, m = nil, name = nil)
    x0, x1 = [x0, x1].minmax
    y0, y1 = [y0, y1].minmax
    z0, z1 = [z0, z1].minmax
    b = [b, (x1 - x0) / 2.01, (y1 - y0) / 2.01, (z1 - z0) / 2.01].min
    g = ents.add_group
    e = g.entities
    lo = [x0, y0, z0]
    hi = [x1, y1, z1]
    # coordinate along axis a at "side" s (-1 lo, +1 hi), inset by k*b
    at = lambda { |a, s, k| s > 0 ? hi[a] - k * b : lo[a] + k * b }
    pt = lambda { |c| Geom::Point3d.new(c[0], c[1], c[2]) }
    faces = []
    # main faces
    3.times do |a|
      [-1, 1].each do |s|
        o = [0, 1, 2] - [a]
        q = []
        [[-1, -1], [1, -1], [1, 1], [-1, 1]].each do |u, v|
          c = [0, 0, 0]
          c[a] = at.call(a, s, 0)
          c[o[0]] = at.call(o[0], u, 1)
          c[o[1]] = at.call(o[1], v, 1)
          q << pt.call(c)
        end
        faces << e.add_face(q)
      end
    end
    # edge strips
    [[0, 1], [0, 2], [1, 2]].each do |a, c2|
      w = ([0, 1, 2] - [a, c2]).first
      [-1, 1].each do |sa|
        [-1, 1].each do |sc|
          q = []
          [[-1, 0, 1], [1, 0, 1], [1, 1, 0], [-1, 1, 0]].each do |sw, ka, kc|
            c = [0, 0, 0]
            c[w] = at.call(w, sw, 1)
            c[a] = at.call(a, sa, ka)
            c[c2] = at.call(c2, sc, kc)
            q << pt.call(c)
          end
          faces << e.add_face(q)
        end
      end
    end
    # corner caps
    [-1, 1].each do |sx|
      [-1, 1].each do |sy|
        [-1, 1].each do |sz|
          s = [sx, sy, sz]
          q = (0..2).map do |a|
            pt.call((0..2).map { |k| at.call(k, s[k], k == a ? 0 : 1) })
          end
          faces << e.add_face(q)
        end
      end
    end
    ctr = Geom::Point3d.new((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
    e.grep(Sketchup::Face).each do |f|
      v = f.bounds.center - ctr
      f.reverse! if v.length > 0 && f.normal.dot(v) < 0
    end
    e.grep(Sketchup::Edge).each do |ed|
      fs = ed.faces
      next unless fs.size == 2
      ang = fs[0].normal.angle_between(fs[1].normal)
      if ang < 50.0.degrees
        ed.soft = true
        ed.smooth = true
      end
    end
    g.material = m if m
    g.name = name if name
    g
  end

  # A cylinder along `axis` from base centre c, radius r, length len.
  def self.cyl(ents, c, axis, r, len, m = nil, seg = 24)
    axis = Geom::Vector3d.new(*axis).normalize
    g = ents.add_group
    circ = g.entities.add_circle(Geom::Point3d.new(*c), axis, r, seg)
    f = g.entities.add_face(circ)
    f.reverse! if f.normal.dot(axis) < 0
    f.pushpull(len)
    g.entities.grep(Sketchup::Edge).each do |ed|
      next unless ed.faces.size == 2
      if ed.faces[0].normal.angle_between(ed.faces[1].normal) < 30.0.degrees
        ed.soft = true
        ed.smooth = true
      end
    end
    g.material = m if m
    g
  end

  # A wall slab along x (y0..y1 thick) with rectangular openings cut by
  # composing pieces — no boolean ops. wins: [[x0, x1, sill, head], ...]
  def self.wall_x(ents, xa, xb, y0, y1, z0, z1, wins, m, name)
    g = ents.add_group
    g.name = name
    e = g.entities
    x = xa
    wins.sort_by(&:first).each do |a0, a1, sill, head|
      box(e, x, y0, z0, a0, y1, z1)
      box(e, a0, y0, z0, a1, y1, z0 + sill)
      box(e, a0, y0, z0 + head, a1, y1, z1)
      x = a1
    end
    box(e, x, y0, z0, xb, y1, z1)
    g.material = m
    g
  end

  def self.wall_y(ents, ya, yb, x0, x1, z0, z1, wins, m, name)
    g = ents.add_group
    g.name = name
    e = g.entities
    y = ya
    wins.sort_by(&:first).each do |a0, a1, sill, head|
      box(e, x0, y, z0, x1, a0, z1)
      box(e, x0, a0, z0, x1, a1, z0 + sill)
      box(e, x0, a0, z0 + head, x1, a1, z1)
      y = a1
    end
    box(e, x0, y, z0, x1, yb, z1)
    g.material = m
    g
  end

  # A black steel window in an opening. `axis` :x (opening runs along x) or
  # :y. `d0..d1` is the frame's depth band across the wall. cols x rows panes.
  def self.steel_window(ents, axis, a0, a1, z0, z1, d0, d1, cols, rows, m, name)
    g = ents.add_group
    g.name = name
    e = g.entities
    fw = 2.25
    mw = 1.25
    mk = lambda do |p0, p1, q0, q1, dd0, dd1|
      if axis == :x
        bevel_box(e, p0, dd0, q0, p1, dd1, q1, 0.12)
      else
        bevel_box(e, dd0, p0, q0, dd1, p1, q1, 0.12)
      end
    end
    mk.call(a0, a1, z0, z0 + fw, d0, d1)
    mk.call(a0, a1, z1 - fw, z1, d0, d1)
    mk.call(a0, a0 + fw, z0, z1, d0, d1)
    mk.call(a1 - fw, a1, z0, z1, d0, d1)
    dm0 = d0 + 0.4
    dm1 = d1 - 0.4
    (1...cols).each do |i|
      c = a0 + (a1 - a0) * i / cols.to_f
      mk.call(c - mw / 2, c + mw / 2, z0 + fw, z1 - fw, dm0, dm1)
    end
    (1...rows).each do |j|
      c = z0 + (z1 - z0) * j / rows.to_f
      mk.call(a0 + fw, a1 - fw, c - mw / 2, c + mw / 2, dm0, dm1)
    end
    g.material = m
    g
  end

  # ----------------------------------------------------------------- room --
  def self.erase_role(prefix)
    doomed = model.entities.select do |e|
      r = e.get_attribute(DICT, 'role') rescue nil
      r && r.to_s.start_with?(prefix)
    end
    model.entities.erase_entities(doomed) unless doomed.empty?
    doomed.length
  end

  # The link builder's default 40'-8" shell, on first run only.
  def self.erase_default_room
    r = model.entities.find do |e|
      e.is_a?(Sketchup::Group) && e.name == 'Room' && e.get_attribute(DICT, 'role').nil?
    end
    return false if r.nil?
    r.erase!
    true
  end

  def self.build_room!
    m = @m
    top = Z0 + H
    root = model.entities.add_group
    root.name = 'Loft'
    tag(root, 'room')
    e = root.entities

    # FLOOR: one face, the interior polygon — what wr-drop-lights reads.
    fl = e.add_group
    fl.name = 'Floor'
    fl.layer = layer('WR-Floor')
    ff = fl.entities.add_face([XW, YS, Z0], [XE, YS, Z0], [XE, YN, Z0], [XW, YN, Z0])
    ff.reverse! if ff.normal.z < 0
    fl.material = m[:floor]
    # the slab under it, and under the walls (never named "floor")
    sl = box(e, XW - T, YS - T, Z0 - 8, XE + T, YN + T, Z0 - 0.02, m[:skirting], 'Slab')
    sl.layer = layer('CA-Room')

    # WALLS: pieces named "Wall <n>" (1 north, 2 east, 3 south, 4 west)
    wg = e.add_group
    wg.name = 'Walls'
    wg.layer = layer('WR-Room')
    w = wg.entities
    box(w, XW - T, YN, Z0, XE + T, YN + T, top, m[:brick], 'Wall 1')
    box(w, XE, YS, Z0, XE + T, YN, top, m[:plaster], 'Wall 2')
    wall_x(w, XW - T, XE + T, YS - T, YS, Z0, top, SOUTH_WIN, m[:plaster], 'Wall 3')
    wall_y(w, YS, YN, XW - T, XW, Z0, top, WEST_WIN, m[:plaster], 'Wall 4')
    SOUTH_WIN.each_with_index do |(a0, a1, sill, head), i|
      steel_window(w, :x, a0, a1, Z0 + sill, Z0 + head, YS - 4.5, YS - 2.0, 4, 6,
                   m[:steel], "Wall 3 window #{i + 1}")
    end
    WEST_WIN.each_with_index do |(a0, a1, sill, head), i|
      steel_window(w, :y, a0, a1, Z0 + sill, Z0 + head, XW - 4.5, XW - 2.0, 3, 6,
                   m[:steel], "Wall 4 window #{i + 1}")
    end
    # the west skirting stops short of the booth: nothing in its 18 in gap
    bb = booth ? booth.bounds : nil
    ws_end = bb ? bb.min.y.to_f - 1.0 : YN
    box(w, XW, YS, Z0, XW + 0.6, ws_end, Z0 + 5.0, m[:skirting], 'Wall 4 skirting')
    box(w, XW, YS, Z0, XE, YS + 0.6, Z0 + 5.0, m[:skirting], 'Wall 3 skirting')
    build_slats!(w)
    build_ceiling!(w)

    # exterior ground, seen only through the windows
    gr = model.entities.add_group
    gr.name = 'Exterior ground'
    tag(gr, 'room-ext')
    gr.layer = layer('CA-Room')
    gf = gr.entities.add_face([-4000, -4000, Z0 - 0.5], [4000, -4000, Z0 - 0.5],
                              [4000, 4000, Z0 - 0.5], [-4000, 4000, Z0 - 0.5])
    gf.reverse! if gf.normal.z < 0
    gr.material = m[:ground]
    root
  end

  # CEILING: one face at the ceiling plane plus the joists below it, as one
  # group INSIDE "Walls". Two house tools decide where it goes:
  #   * wr-drop-lights.rb treats any room child that is not Floor/Walls/Doors
  #     (by tag or name) as an OBSTRUCTION; a ceiling child is flat, broad and
  #     over the whole floor, so it became a keep-out everywhere and the key,
  #     pendant and sconces all skipped (observed 22 Sep 2026). Inside Walls it
  #     is structure and never scanned.
  #   * the tool takes the ceiling height from the Walls child's TOP, so the
  #     ceiling is a face AT that top (no slab above it) -- nothing moves.
  #   wr-scene-walls.rb still finds it as a ceiling by shape + name, so a high
  #   or plan plate hides the joists with it.
  def self.build_ceiling!(w)
    m = @m
    top = Z0 + H
    cg = w.add_group
    cg.name = 'Ceiling'
    cg.layer = layer('WR-Ceiling')
    c = cg.entities
    cf = c.add_face([XW - T, YS - T, top], [XE + T, YS - T, top],
                    [XE + T, YN + T, top], [XW - T, YN + T, top])
    cf.reverse! if cf.normal.z > 0
    cf.material = m[:ceiling]
    cf.back_material = m[:ceiling]
    # joists at XW + 32.5 + 65k. The lights tool's drum grid lands at
    # x = -25, 105, 235 in this 32'-6" room (observed 22 Sep 2026), so this
    # pitch puts every drum mid-bay. Change the room and the pitch must be
    # re-checked against the grid the tool prints.
    x = XW + JOIST_START
    while x < XE - 10
      bevel_box(c, x - 2.0, YS, top - 11.25, x + 2.0, YN, top, 0.3, m[:beam])
      x += JOIST_PITCH
    end
    cg
  end

  # Move an older build's ceiling (a direct child of the room) into Walls.
  def self.migrate_ceiling!
    root = model.entities.find { |e| e.get_attribute(DICT, 'role') == 'room' }
    raise 'no room group' if root.nil?
    walls = root.entities.find { |e| e.is_a?(Sketchup::Group) && e.name == 'Walls' }
    raise 'no Walls child' if walls.nil?
    old = root.entities.select { |e| e.is_a?(Sketchup::Group) && e.name == 'Ceiling' } +
          walls.entities.select { |e| e.is_a?(Sketchup::Group) && e.name == 'Ceiling' }
    model.start_operation('WR concept: ceiling into Walls', true)
    begin
      materials!
      old.each(&:erase!)
      build_ceiling!(walls.entities)
      model.commit_operation
    rescue Exception
      model.abort_operation
      raise
    end
    "ceiling rebuilt inside Walls (#{old.length} old removed)"
  end

  # Oak slat acoustic panelling on the east wall: vertical slats on felt.
  def self.build_slats!(ents)
    m = @m
    g = ents.add_group
    g.name = 'Wall 2 slats'
    e = g.entities
    y0 = -222.0
    y1 = 110.0
    z0 = Z0 + 6.0
    z1 = Z0 + 114.0
    box(e, XE - 0.5, y0, z0, XE, y1, z1, m[:felt])
    sd = model.definitions['CA Slat'] || model.definitions.add('CA Slat')
    sd.entities.clear!
    bevel_box(sd.entities, 0, 0, 0, 0.75, 1.75, z1 - z0, 0.08)
    y = y0 + 0.75
    n = 0
    while y + 1.75 <= y1
      i = e.add_instance(sd, Geom::Transformation.translation([XE - 0.5 - 0.75, y, z0]))
      i.material = m[:slat]
      y += 2.5
      n += 1
    end
    n
  end

  def self.booth
    model.entities.find { |e| e.respond_to?(:name) && e.name =~ /\AMDL \d+/ }
  end

  # Translate (never rotate) the booth so its west face stands BOOTH_GAP off
  # the west wall's interior face and its north face BOOTH_GAP off the north
  # wall's. Idempotent: the move is computed from the booth's live bounds.
  def self.place_booth!
    b = booth
    raise 'no booth group (a top-level container named MDL ...)' if b.nil?
    bb = b.bounds
    dx = (XW + BOOTH_GAP) - bb.min.x.to_f
    dy = (YN - BOOTH_GAP) - bb.max.y.to_f
    return 'booth already in its corner' if dx.abs < 0.001 && dy.abs < 0.001
    b.transform!(Geom::Transformation.translation([dx, dy, 0.0]))
    format('booth translated by (%.3f, %.3f) in', dx, dy)
  end

  def self.recolour_foam!
    fm = model.materials['[Color_I06]']
    return 'no [Color_I06] in this model' if fm.nil?
    fm.color = Sketchup::Color.new(*FOAM_PURPLE)
    "foam [Color_I06] -> #{FOAM_PURPLE.inspect}"
  end

  # ---------------------------------------------------------------- props --
  COSMOS = { chair: 'Chair Lounge 009', sofa: 'Sofa Sectional 001',
             table: 'Table Coffee 001', plant_tall: 'Indoor Plant 004',
             plant_small: 'Indoor Plant 007', task: 'Zody Executive 4D Arms Metal Base',
             lamp: 'Lamp Floor 16-45' }.freeze

  def self.place(key, x, y, deg, role)
    d = model.definitions[COSMOS[key]]
    raise "Cosmos definition #{COSMOS[key]} is not in this model" if d.nil?
    t = Geom::Transformation.translation([x, y, Z0]) *
        Geom::Transformation.rotation(ORIGIN, Z_AXIS, deg.degrees)
    i = model.entities.add_instance(d, t)
    tag(i, role)
    i.layer = layer('CA-Props')
    i
  end

  def self.prop_group(name, role)
    g = model.entities.add_group
    g.name = name
    tag(g, role)
    g.layer = layer('CA-Props')
    g
  end

  def self.build_lounge!
    m = @m
    out = []
    # rug: charcoal wool, bevelled edge
    rg = prop_group('Rug', 'prop-rug')
    bevel_box(rg.entities, -84.0, -250.0, Z0, 30.0, -124.0, Z0 + 0.45, 0.2, m[:rug])
    # Cosmos furniture. ASSUMED: Cosmos assets face -Y in their own frame
    # (the preview shots all show their fronts); rotations follow from that.
    out << place(:sofa, -58.0, -190.0, 90, 'prop-sofa')        # back to the west wall
    out << place(:table, 0.0, -188.0, 90, 'prop-table')
    out << place(:chair, 42.0, -228.0, -118, 'prop-chair')     # faces WNW, toward the sofa
    out << place(:lamp, -76.0, -250.0, 35, 'prop-lamp')
    # south of the booth's west gap, clear of the door approach (the key light)
    out << place(:plant_tall, -62.0, -62.0, 0, 'prop-plant-tall')
    # the one brand-orange accent: a linen lumbar cushion in the lounge chair
    pg = prop_group('Orange cushion', 'prop-cushion')
    cu = bevel_box(pg.entities, -8.0, -2.4, 0.0, 8.0, 2.4, 11.0, 1.6, m[:orange])
    pg.transform!(Geom::Transformation.translation([42.0, -228.0, Z0 + 15.2]) *
                  Geom::Transformation.rotation(ORIGIN, Z_AXIS, -118.degrees) *
                  Geom::Transformation.translation([0.0, 9.5, 0.0]) *
                  Geom::Transformation.rotation(ORIGIN, X_AXIS, -14.degrees))
    out << cu
    out.compact.length
  end

  DESK_C   = [185.0, -40.0].freeze   # desk centre, plan
  DESK_ROT = -23.0                   # deg: engineer looks NW, into the booth

  def self.build_desk!
    m = @m
    g = prop_group('Producer desk', 'prop-desk')
    e = g.entities
    # built about its own centre, engineer on +x, then turned to face the
    # booth's east windows from the south-east (DESK_C / DESK_ROT)
    xa = -15.0
    xb = 15.0
    ya = -39.0
    yb = 39.0
    zt = Z0 + 29.0
    bevel_box(e, xa, ya, zt, xb, yb, zt + 1.5, 0.3, m[:walnut], 'Top')
    # blackened steel end frames
    [ya + 2.0, yb - 3.5].each do |y|
      bevel_box(e, xa + 2.0, y, Z0, xa + 3.5, y + 1.5, zt, 0.1, m[:steel])
      bevel_box(e, xb - 3.5, y, Z0, xb - 2.0, y + 1.5, zt, 0.1, m[:steel])
      bevel_box(e, xa + 2.0, y, zt - 2.5, xb - 2.0, y + 1.5, zt, 0.1, m[:steel])
      bevel_box(e, xa + 2.0, y, Z0, xb - 2.0, y + 1.5, Z0 + 1.5, 0.1, m[:steel])
    end
    bevel_box(e, xa + 4.0, ya + 3.5, zt - 3.0, xa + 5.0, yb - 3.5, zt, 0.1, m[:steel])
    # two 27" displays, facing +x (the engineer), toed in
    [[-15.0, 10.0], [15.0, -10.0]].each do |yc, toe|
      mg = e.add_group
      me = mg.entities
      bevel_box(me, -0.35, -12.1, 6.0, 0.35, 12.1, 20.2, 0.15, m[:plastic])
      box(me, 0.35, -11.75, 6.35, 0.4, 11.75, 19.85, m[:screen])
      bevel_box(me, -1.6, -1.2, 1.0, -0.6, 1.2, 14.0, 0.2, m[:steel])
      bevel_box(me, -5.0, -4.5, 0.0, 3.0, 4.5, 0.6, 0.2, m[:steel])
      mg.transform!(Geom::Transformation.translation([xa + 7.5, yc, zt + 1.5]) *
                    Geom::Transformation.rotation(ORIGIN, Z_AXIS, toe.degrees))
    end
    # studio monitors on the desk ends, toed in toward the chair
    [[ya + 6.0, 22.0], [yb - 6.0, -22.0]].each do |yc, toe|
      sg = e.add_group
      se = sg.entities
      bevel_box(se, -5.5, -4.2, 0.0, 5.5, 4.2, 13.0, 0.6, m[:plastic])
      cyl(se, [5.5, 0.0, 4.2], [1, 0, 0], 3.3, 0.12, m[:ring], 32)
      cyl(se, [5.62, 0.0, 4.2], [1, 0, 0], 2.8, 0.1, m[:cone], 32)
      cyl(se, [5.5, 0.0, 10.4], [1, 0, 0], 1.1, 0.12, m[:ring], 24)
      sg.transform!(Geom::Transformation.translation([xa + 9.0, yc, zt + 1.5]) *
                    Geom::Transformation.rotation(ORIGIN, Z_AXIS, toe.degrees))
    end
    # keyboard, interface, mouse
    bevel_box(e, xa + 17.0, -9.0, zt + 1.5, xa + 22.5, 9.0, zt + 2.3, 0.2, m[:plastic])
    bevel_box(e, xa + 11.0, -31.0, zt + 1.5, xa + 17.0, -22.0, zt + 3.3, 0.3, m[:steel])
    bevel_box(e, xa + 19.0, 13.0, zt + 1.5, xa + 22.0, 15.0, zt + 2.6, 0.5, m[:plastic])
    g.transform!(Geom::Transformation.translation([DESK_C[0], DESK_C[1], 0.0]) *
                 Geom::Transformation.rotation(ORIGIN, Z_AXIS, DESK_ROT.degrees))
    r = DESK_ROT.degrees
    cx = DESK_C[0] + 31.0 * Math.cos(r)
    cy = DESK_C[1] + 31.0 * Math.sin(r)
    task = place(:task, cx, cy, -90 + DESK_ROT, 'prop-task-chair')
    [g, task]
  end

  # Records shelving against the brick, east of the booth.
  def self.build_shelves!
    m = @m
    g = prop_group('Record shelving', 'prop-shelves')
    e = g.entities
    xa = 88.0
    xb = 214.0
    ya = YN - 15.0
    yb = YN - 0.5
    levels = [Z0 + 3.0, Z0 + 17.0, Z0 + 31.0, Z0 + 45.0, Z0 + 59.0, Z0 + 73.0]
    levels.each { |z| bevel_box(e, xa, ya, z, xb, yb, z + 1.25, 0.2, m[:walnut]) }
    [xa, (xa + xb) / 2.0 - 0.6, xb - 1.2].each do |x|
      [ya, yb - 1.2].each do |y|
        bevel_box(e, x, y, Z0, x + 1.2, y + 1.2, levels.last + 1.25, 0.1, m[:steel])
      end
    end
    # record sleeves on the two lowest shelves, one definition per colour
    defs = m[:records].each_with_index.map do |mt, i|
      d = model.definitions["CA Sleeve #{i + 1}"] || model.definitions.add("CA Sleeve #{i + 1}")
      d.entities.clear!
      bevel_box(d.entities, 0, 0, 0, 0.22, 12.4, 12.4, 0.03, mt)
      d
    end
    rng = Random.new(7)
    n = 0
    [levels[0] + 1.25, levels[1] + 1.25].each do |z|
      x = xa + 1.6
      while x < xb - 2.0
        if (x - xa) > 60 && (x - xa) < 64.5
          x += 4.0
          next
        end
        d = defs[rng.rand(defs.size)]
        lean = (rng.rand - 0.5) * 2.0
        t = Geom::Transformation.translation([x, ya + 1.2, z]) *
            Geom::Transformation.rotation(ORIGIN, Y_AXIS, lean.degrees)
        e.add_instance(d, t)
        x += 0.24 + rng.rand * 0.08
        n += 1
      end
    end
    # books on the third shelf
    x = xa + 2.0
    z = levels[2] + 1.25
    while x < xb - 40.0
      th = 0.8 + rng.rand * 1.4
      ht = 8.0 + rng.rand * 3.5
      dp = 6.0 + rng.rand * 2.5
      bevel_box(e, x, yb - 1.5 - dp, z, x + th, yb - 1.5, z + ht, 0.08,
                m[:records][rng.rand(m[:records].size)])
      x += th + 0.05
    end
    # a few objects above: stoneware vases and a stacked pair of boxes
    cyl(e, [xb - 22.0, yb - 7.0, levels[2] + 1.25], [0, 0, 1], 3.0, 9.0, m[:ceramic], 32)
    cyl(e, [xa + 30.0, yb - 7.0, levels[3] + 1.25], [0, 0, 1], 2.4, 7.0, m[:ceramic], 32)
    bevel_box(e, xa + 70.0, yb - 11.0, levels[3] + 1.25, xa + 84.0, yb - 2.0, levels[3] + 5.25, 0.3, m[:plastic])
    bevel_box(e, xa + 71.0, yb - 10.0, levels[3] + 5.25, xa + 83.0, yb - 3.0, levels[3] + 8.25, 0.3, m[:walnut])
    n
  end

  # Acoustic guitar on an A-frame stand, beside the lounge.
  def self.build_guitar!(x, y, face_deg)
    m = @m
    g = prop_group('Guitar on stand', 'prop-guitar')
    e = g.entities
    gg = e.add_group
    ge = gg.entities
    # body outline: smooth union of two bouts, star-shaped about p
    ca = [0.0, 0.0, 7.8]
    cb = [0.0, 10.4, 5.9]
    p = [0.0, 6.2]
    exit_d = lambda do |c, th|
      dx = p[0] - c[0]
      dy = p[1] - c[1]
      ux = Math.cos(th)
      uy = Math.sin(th)
      bq = dx * ux + dy * uy
      cq = dx * dx + dy * dy - c[2] * c[2]
      -bq + Math.sqrt([bq * bq - cq, 0.0].max)
    end
    pts = (0...72).map do |i|
      th = 2 * Math::PI * i / 72.0
      d = (exit_d.call(ca, th)**8 + exit_d.call(cb, th)**8)**(1.0 / 8)
      Geom::Point3d.new(p[0] + d * Math.cos(th), p[1] + d * Math.sin(th), 0.0)
    end
    f = ge.add_face(pts)
    f.reverse! if f.normal.z < 0
    f.pushpull(4.0)
    ge.grep(Sketchup::Edge).each do |ed|
      next unless ed.faces.size == 2
      if ed.faces[0].normal.angle_between(ed.faces[1].normal) < 20.0.degrees
        ed.soft = true
        ed.smooth = true
      end
    end
    ge.grep(Sketchup::Face).each do |fc|
      fc.material = fc.normal.z > 0.9 ? m[:spruce] : m[:rosewood]
    end
    cyl(ge, [0.0, 7.2, 4.0], [0, 0, 1], 2.0, 0.02, m[:hole], 40)
    bevel_box(ge, -1.9, 1.2, 4.0, 1.9, 2.4, 4.35, 0.1, m[:rosewood])        # bridge
    bevel_box(ge, -0.95, 15.6, 2.4, 0.95, 34.0, 4.3, 0.25, m[:rosewood])     # neck
    bevel_box(ge, -1.6, 34.0, 2.6, 1.6, 41.0, 3.3, 0.25, m[:rosewood])       # headstock
    # stand the guitar up: local Y -> world Z, top faces local -Y, lean back 14 deg
    gg.transform!(Geom::Transformation.translation([0.0, 0.0, 10.8]) *
                  Geom::Transformation.rotation(ORIGIN, X_AXIS, -14.degrees) *
                  Geom::Transformation.rotation(ORIGIN, X_AXIS, 90.degrees) *
                  Geom::Transformation.translation([0.0, 0.0, -2.0]))
    # A-frame stand: two front legs up to a yoke behind the neck, one back leg
    strut = lambda do |a, b|
      v = Geom::Point3d.new(*b) - Geom::Point3d.new(*a)
      cyl(e, a, [v.x, v.y, v.z], 0.32, v.length, m[:steel], 12)
    end
    [-5.0, 5.0].each { |sx| strut.call([sx, -4.0, 0.0], [sx * 0.16, 6.0, 27.0]) }
    strut.call([0.0, 13.0, 0.0], [0.0, 6.4, 26.6])
    bevel_box(e, -1.4, 5.4, 26.4, 1.4, 7.0, 27.6, 0.25, m[:steel])
    bevel_box(e, -6.0, -5.2, 2.6, 6.0, -1.2, 3.6, 0.3, m[:steel])
    g.transform!(Geom::Transformation.translation([x, y, Z0]) *
                 Geom::Transformation.rotation(ORIGIN, Z_AXIS, face_deg.degrees))
    g
  end

  def self.build_props!
    out = []
    out << "lounge: #{build_lounge!} parts"
    build_desk!
    out << 'producer desk + task chair'
    out << "record shelving: #{build_shelves!} sleeves"
    build_guitar!(-40.0, -110.0, 40.0)
    out << 'guitar on stand'
    out << "plant (small): #{place(:plant_small, 272.0, 108.0, 0, 'prop-plant-small').definition.name}"
    out.join('; ')
  end

  # Leave the viewport INSIDE the room on the booth, textured, so whoever is
  # watching the SketchUp window sees the set fill in (Benton, 22 Sep 2026).
  HERO_EYE    = [236.0, -230.0, 58.0].freeze
  HERO_TARGET = [-12.0, 40.0, 58.0].freeze

  def self.view_hero!(eye = HERO_EYE, target = HERO_TARGET, fov = 42.0)
    v = model.active_view
    c = Sketchup::Camera.new(Geom::Point3d.new(*eye), Geom::Point3d.new(*target), Z_AXIS)
    c.perspective = true
    c.fov = fov
    v.camera = c
    ro = model.rendering_options
    ro['RenderMode'] = 2 rescue nil
    ro['Texture'] = true rescue nil
    ro['DrawSilhouettes'] = false rescue nil
    ro['DisplayFog'] = false rescue nil
    v.invalidate
    true
  end

  def self.run!(stage = :all)
    out = []
    model.start_operation('WR concept: host room', true)
    begin
      materials!
      if [:all, :room].include?(stage)
        out << "default Room erased: #{erase_default_room}"
        out << "old room parts erased: #{erase_role('room') + erase_role('slats')}"
        out << place_booth!
        build_room!
      end
      out << recolour_foam! if [:all, :room, :foam].include?(stage)
      if [:all, :props].include?(stage)
        out << "old props erased: #{erase_role('prop')}"
        out << build_props!
      end
      model.commit_operation
    rescue Exception
      model.abort_operation
      raise
    end
    view_hero!
    out
  end
end

unless $wr_no_autorun
  WR_Concept.run!($wr_concept_stage || :all).each { |l| puts l }
end
