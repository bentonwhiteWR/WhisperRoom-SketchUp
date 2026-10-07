# @title Holmdel / Private Office (option 2): MDL 4872 S Audiology Basic Plus, no ramp (Claude, for Gabe White)
# @tab client
# @cat Draw the room
# @icon rooms-csusb
#
# Holmdel, room option 2, "Private Office". The room comes from the take-off
# LOCK (clients/holmdel/takeoff.lock.json, built by build-takeoff.rb); this
# script finishes it for proposal renders (LVT floor, painted drywall, base,
# real east windows cut through the wall, door trim, 2x2 ceiling, the ASSUMED
# desk and chair), places the quoted booth, dimensions everything, lights it
# for V-Ray and builds the proposal scenes.
#
# Written by Claude, for Gabe White, 7 Oct 2026.
#
#   load "C:/Users/whisp/Desktop/2026 Claude Files/SketchUp/WhisperRoom-SketchUp/scripts/holmdel-private-office-option-2-gabe.rb"
#
# Stages (each its own bridge job; nothing runs on load except `run`, which
# only finishes the room and never touches the booth):
#   WR_Holmdel.run          finishes, windows, desk + chair, notes, room dims (re-runnable)
#   WR_Holmdel.booth!       places the booth ONCE (built by .forge/builder/holmdel/jobs/build-booth.rb
#                           at the tool's origin), then swing, fit dims, labels (re-runnable)
#   WR_Holmdel.fit_report   clearances read back from the placed parts
#   WR_Holmdel.lights!      V-Ray 2x4 troffer lights + dome
#   WR_Holmdel.scenes!      deletes EVERY scene and builds the proposal set
#
# --- COORDINATES (inches) -------------------------------------------------------
# build-takeoff.rb's frame: origin = NW interior corner, +X east, +Y north, so the
# room is x 0..141.75, y -143..0. North wall y 0, east (window) wall x 141.75,
# south wall y -143, west (door) wall x 0.
#
# --- STATED on the plan (Holmdel whisper booth option 2.png) ----------------------
#   11'-9 3/4" E-W (top and bottom), 11'-11" N-S (both sides). West wall: 8'-3 3/4"
#   north corner to door, 2'-9" door. East wall: 8'-5 1/4" (Gabe: a window).
# --- DERIVED ------------------------------------------------------------------------
#   10 1/4" door to SW corner (143 - 99.75 - 33). 2" below the main window (closure).
# --- ASSUMED (every one labelled ASSUMED in the model) ------------------------------
#   Upper east window 22 3/4" wide from the NE corner, pier 17" (both scaled from the
#   PNG at 3.10 px/in). Window sills 30", heads 84". Desk 25 1/2" x 68 3/4", 5" off the
#   east wall, 40" off the north wall, 29 1/2" top (scaled; client confirming what it is).
#   Ceiling 8'-0" house default. Room door 6'-8" default. Finishes and lighting are
#   invented for the renders, not client data.

module WR_Holmdel
  CLIENT = 'Holmdel'.freeze
  DICT = 'wr_holmdel'.freeze
  ROOM = 'Private Office'.freeze
  W = 141.75
  D = 143.0
  CEIL = 96.0
  THICK = 4.0
  DOOR_H = 80.0
  # room door, west wall: opening y -132.75..-99.75, hinge at the south jamb, swings in
  RDOOR_Y = [-132.75, -99.75].freeze
  RDOOR_PIVOT = [0.0, -132.75].freeze
  RDOOR_R = 33.0
  # east windows: [north edge y, south edge y] (y = -distance from the north wall)
  WINDOWS = [[0.0, -22.75], [-39.75, -141.0]].freeze
  SILL = 30.0
  HEAD = 84.0
  # ASSUMED desk (scaled off the plan): x 111.25..136.75, y -108.75..-40, top 29.5
  DESK_PLAN = { :x0 => 111.25, :x1 => 136.75, :y0 => -108.75, :y1 => -40.0, :top => 29.5 }.freeze
  # Desk position history (7 Oct 2026): Gabe first said to move the desk to the south wall if it did
  # not fit (it was built there once: 21 1/2" between the booth's outside desk and this desk); he then
  # OVERRODE that: keep the desk on the EAST wall at its plan position. The gaps are reported, not fixed.
  DESK = DESK_PLAN

  # Booth: MDL 4872 S, built at the tool's origin (local: S face y 0 = vent wall,
  # N face y 50 = door wall, W end x 0 = window wall, E end x 74 = solid).
  # Turned 180 deg so the WINDOW wall faces EAST (the room windows): vent wall faces the
  # NORTH room wall, door wall faces south (open floor), solid end faces the west wall.
  BOOTH_MODEL = 'MDL 4872 S'.freeze
  BOOTH_ROT = 180.0
  GAP_WEST = 2.0      # Gabe, 7 Oct: 2-3" off the walls
  GAP_NORTH = 11.0    # vent side: measured hood 10.0" beyond the exterior + 1" clear (NOT 2-3", see report)
  BOOTH_EXT = [74.0, 50.0].freeze
  CAT_H = 83.0        # 6'-11" Standard catalog install height (models.json)

  T_DIMS = 'HL-Dims-Room'.freeze
  T_DIMS_B = 'HL-Dims-Booth'.freeze
  T_ELEV = 'HL-Dims-Elevation'.freeze
  T_INT = 'HL-Dims-Interior'.freeze
  T_NOTES = 'HL-Notes'.freeze
  T_LABEL = 'HL-Labels-Assumed'.freeze
  T_SWING = 'HL-Swings'.freeze
  T_FLOORL = 'HL-Floor-Light'.freeze
  T_CTX = 'HL-Context'.freeze
  T_FURN = 'HL-Furniture'.freeze
  T_SECTION = 'HL-Section'.freeze
  T_CEIL = 'WR-Ceiling'.freeze
  T_LIGHT = 'WR Lights'.freeze

  TEX_DIR = 'C:/Users/whisp/Desktop/2026 Claude Files/SketchUp/ClientDrawings/holmdel-textures'.freeze
  M_LVT     = ['HL LVT Oak Plank', 'hl-lvt-oak.png', 56.0, [168, 138, 106]].freeze
  M_LVT_L   = ['HL LVT Oak Plank Light (dims views)', 'hl-lvt-oak-light.png', 56.0, [214, 196, 172]].freeze
  # The booth's own floor is 'WhisperRoom Floor Carpet' (EFP + deck tops, observed). Its texture, exported and
  # lifted to a light grey with the fibre pattern kept, is the dimension-view stand-in: carpet, never wood.
  M_WRC_L   = ['HL WhisperRoom Carpet Light (dims views)', 'hl-wr-carpet-light.png', 12.0, [185, 185, 185]].freeze
  M_CEILT   = ['HL Acoustic Ceiling 2x2', 'hl-ceiling-2x2.png', 24.0, [236, 236, 236]].freeze
  M_DOORW   = ['HL Door Maple Veneer', 'hl-door-maple.png', 36.0, [196, 160, 118]].freeze
  M_PAINT   = ['HL Paint Warm White', nil, nil, [238, 235, 228]].freeze
  M_TRIM    = ['HL Trim Semi-Gloss White', nil, nil, [246, 245, 242]].freeze
  M_FRAME   = ['HL Window Frame Dark Bronze', nil, nil, [58, 52, 46]].freeze
  M_GLASS   = ['HL Window Glass Clear', nil, nil, [200, 222, 230]].freeze
  M_METAL   = ['HL Brushed Steel', nil, nil, [178, 180, 182]].freeze
  M_BLACK   = ['HL Black Powder Coat', nil, nil, [34, 34, 36]].freeze
  M_DESKTOP = ['HL Desk Top Walnut', nil, nil, [112, 80, 56]].freeze
  M_MESH    = ['HL Chair Mesh Charcoal', nil, nil, [52, 54, 58]].freeze
  M_LENS    = ['HL Troffer Lens', nil, nil, [255, 255, 255]].freeze
  M_GROUND  = ['HL Exterior Ground', nil, nil, [150, 160, 132]].freeze
  M_ORANGE  = ['HL WhisperRoom Orange', nil, nil, [238, 98, 22]].freeze
  M_DARKTXT = ['HL Note Text', nil, nil, [44, 44, 46]].freeze
  M_SCREEN  = ['HL Monitor Screen', nil, nil, [24, 26, 30]].freeze

  # 2x4 lensed troffers (ASSUMED layout): [x0, y0, x1, y1]
  FIXTURES = [[35.0, -95.0, 59.0, -47.0], [95.0, -95.0, 119.0, -47.0]].freeze
  LUMENS = 4000.0
  LIGHT_GAIN = 320.0
  LIGHT_TUNE = 3.0
  TROFFER_K = 4000
  DOME_INTENSITY = 250.0   # 30 (UT) left the windows a dull grey at EV 16.7; 250 reads as daylight (test 7 Oct)

  NOTES = [
    'VIRSONO HOLMDEL, ROOM OPTION 2: PRIVATE OFFICE. Plain dimensions are stated on the client plan. ASSUMED / DERIVED / DEFAULT = not measured.',
    'East wall: 8\'-5 1/4" window is stated; the upper window (1\'-10 3/4"), the pier (1\'-5") and both sills (2\'-6") and heads (7\'-0") are ASSUMED.',
    "Desk by the east wall: ASSUMED (client confirming what it is), 2'-1 1/2\" x 5'-8 3/4\" scaled, 5\" off the east wall, 3'-4\" off the north wall. Kept at its plan position (Gabe).",
    'Ceiling 8\'-0" is the house DEFAULT (not on the plan). Room door 6\'-8" DEFAULT. Finishes and lighting are illustrative.',
    'Booth: MDL 4872 S, Audiology Basic Plus as quoted, WITHOUT the ramp. 2" off the west wall; 11" off the north wall (vent side: hood 10" deep, 1" clear).',
    'All dimensions to be confirmed on site before ordering.'
  ].freeze

  # ==================================================================== helpers

  def self.pt(x, y, z = 0.0)
    Geom::Point3d.new(x, y, z)
  end

  def self.fi(v)
    s = v < 0 ? '-' : ''
    v = v.abs
    f = (v / 12).floor
    i = v - 12 * f
    format("%s%d'-%.2f\"", s, f, i)
  end

  def self.mine?(e, kind = nil)
    return false unless e.valid? && e.get_attribute(DICT, 'own')
    kind.nil? || e.get_attribute(DICT, 'kind') == kind
  end

  def self.own(e, kind)
    if e && e.valid?
      e.set_attribute(DICT, 'own', true)
      e.set_attribute(DICT, 'kind', kind)
    end
    e
  end

  def self.tag(model, name, rgb = [128, 128, 128])
    l = model.layers[name] || model.layers.add(name)
    (l.color = Sketchup::Color.new(*rgb)) rescue nil
    l
  end

  def self.mat(model, spec, alpha = nil)
    name, tex, size, rgb = spec
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*rgb)
    if tex
      path = File.join(TEX_DIR, tex)
      raise "texture missing: #{path}" unless File.exist?(path)
      m.texture = path
      m.texture.size = size
    end
    m.alpha = alpha if alpha
    m
  end

  def self.room_group(model)
    model.entities.grep(Sketchup::Group).find { |g| g.name == ROOM }
  end

  def self.sub(group, name)
    group.entities.grep(Sketchup::Group).find { |g| g.name == name }
  end

  def self.box(parent, x0, y0, z0, x1, y1, z1, name, m = nil, layer = nil)
    x0, x1 = [x0, x1].minmax
    y0, y1 = [y0, y1].minmax
    z0, z1 = [z0, z1].minmax
    g = parent.entities.add_group
    f = g.entities.add_face(pt(x0, y0, z0), pt(x1, y0, z0), pt(x1, y1, z0), pt(x0, y1, z0))
    raise "#{name}: degenerate box" unless f
    f.reverse! if f.normal.z < 0
    f.pushpull(z1 - z0)
    g.name = name
    g.material = m if m
    g.layer = layer if layer
    g
  end

  def self.cyl(parent, x, y, z0, z1, r, name, m = nil, seg = 24)
    g = parent.entities.add_group
    c = g.entities.add_circle(pt(x, y, z0), Z_AXIS, r, seg)
    f = g.entities.add_face(c)
    f.reverse! if f.normal.z < 0
    f.pushpull(z1 - z0)
    g.name = name
    g.material = m if m
    g
  end

  def self.slab(parent, poly, z0, z1, name, m = nil, layer = nil)
    g = parent.entities.add_group
    f = g.entities.add_face(poly.map { |p| pt(p[0], p[1], z0) })
    raise "#{name}: degenerate slab" unless f
    f.reverse! if f.normal.z < 0
    f.pushpull(z1 - z0)
    g.name = name
    g.material = m if m
    g.layer = layer if layer
    g
  end

  def self.floor_text(parent, s, x, y, z, h, m = nil, layer = nil, rot = 0.0)
    g = parent.entities.add_group
    g.entities.add_3d_text(s, TextAlignLeft, 'Arial', true, false, h, 0.0, 0.0, true, 0.0)
    tr = Geom::Transformation.translation([x, y, z]) *
         Geom::Transformation.rotation(ORIGIN, Z_AXIS, rot * Math::PI / 180.0)
    g.transform!(tr)
    g.material = m if m
    g.layer = layer if layer
    g
  end

  def self.dimx(ents, a, b, off, layer, label = nil, kind = 'dims')
    d = ents.add_dimension_linear(a, b, off)
    d.layer = layer
    d.text = "<> #{label}" if label
    (d.has_aligned_text = true) rescue nil
    own(d, kind)
  end

  def self.outside_end(d)
    (d.text_position = Sketchup::DimensionLinear::TEXT_OUTSIDE_END) rescue nil
    d
  end

  def self.outside_start(d)
    (d.text_position = Sketchup::DimensionLinear::TEXT_OUTSIDE_START) rescue nil
    d
  end

  def self.clear_mine!(model, kinds)
    gone = model.entities.select { |e| e.valid? && mine?(e) && kinds.include?(e.get_attribute(DICT, 'kind')) }
    model.entities.erase_entities(gone) unless gone.empty?
    gone.size
  end

  # ================================================================== FINISHES

  # Cut the two east window openings through Wall 2 (once; recorded on the wall).
  def self.cut_windows!(room)
    walls = sub(room, 'Walls')
    wall = walls.entities.grep(Sketchup::Group).find { |g| g.name == 'Wall 2' }
    raise 'east wall (Wall 2) not found in the take-off room' unless wall
    return 0 if wall.get_attribute(DICT, 'windows_cut')
    inv = (room.transformation * walls.transformation * wall.transformation).inverse
    n = 0
    WINDOWS.each do |yn, ys|
      q = [pt(W, ys, SILL), pt(W, yn, SILL), pt(W, yn, HEAD), pt(W, ys, HEAD)].map { |p| p.transform(inv) }
      f = wall.entities.add_face(q)
      raise "window face not made at y #{yn}..#{ys}" unless f
      # push away from the room, through the full thickness
      dir = f.normal.transform(wall.transformation)
      f.pushpull(dir.x > 0 ? THICK : -THICK)
      n += 1
    end
    wall.set_attribute(DICT, 'windows_cut', n)
    n
  end

  def self.window_units!(model, fin)
    frame = mat(model, M_FRAME)
    glass = mat(model, M_GLASS, 0.18)
    trim = mat(model, M_TRIM)
    WINDOWS.each_with_index do |(yn, ys), k|
      wg = fin.entities.add_group
      label = k.zero? ? "Upper east window 1'-10 3/4\" wide (width, sill 2'-6\", head 7'-0\" ASSUMED)" :
                        "East window 8'-5 1/4\" wide (sill 2'-6\", head 7'-0\" ASSUMED)"
      wg.name = label
      xf0 = W + 1.0           # frame set 1" into the 4" wall from the room face
      xf1 = W + 3.0
      fw = 1.75
      box(wg, xf0, ys, SILL, xf1, yn, SILL + fw, 'Frame sill', frame)
      box(wg, xf0, ys, HEAD - fw, xf1, yn, HEAD, 'Frame head', frame)
      box(wg, xf0, ys, SILL, xf1, ys + fw, HEAD, 'Frame jamb', frame)
      box(wg, xf0, yn - fw, SILL, xf1, yn, HEAD, 'Frame jamb', frame)
      span = yn - ys
      lites = span > 60 ? 3 : 1
      (1...lites).each do |i|
        ym = ys + span * i / lites
        box(wg, xf0, ym - 1.0, SILL, xf1, ym + 1.0, HEAD, 'Mullion', frame)
      end
      box(wg, W + 1.9, ys + fw, SILL + fw, W + 2.1, yn - fw, HEAD - fw, 'Glass', glass)
      # interior stool (window ledge), painted, 1" proud of the wall face
      box(wg, W - 1.0, ys, SILL - 0.75, W + 1.0, yn, SILL, 'Stool', trim)
      # drywall returns stay the wall's own paint
    end
  end

  def self.finishes!(model, room)
    lvt = mat(model, M_LVT)
    paint = mat(model, M_PAINT)
    trim = mat(model, M_TRIM)
    fg = sub(room, 'Floor')
    raise 'take-off Floor group missing' unless fg
    fg.material = lvt
    sub(room, 'Walls').material = paint
    c = sub(room, 'Ceiling')
    c.material = mat(model, M_CEILT) if c
    # the take-off's 1" window massing: hidden for good (real windows below)
    room.entities.grep(Sketchup::Group).select { |g| g.name =~ /\AWindow \d/ }.each { |g| g.hidden = true }
    # the room door leaf: maple veneer; its swing line goes to the plan-only tag
    dg = sub(room, 'Doors')
    if dg
      dg.entities.grep(Sketchup::Group).each do |g|
        g.material = mat(model, M_DOORW) if g.name =~ /leaf/
        g.layer = tag(model, T_SWING, [238, 98, 22]) if g.name =~ /Swing/
      end
    end

    fin = own(model.entities.add_group, 'finish')
    fin.name = 'Holmdel finishes (illustrative)'

    # light LVT copy for dimension views only
    fl = fin.entities.add_group
    ff = fl.entities.add_face([pt(0, 0, 0.03), pt(W, 0, 0.03), pt(W, -D, 0.03), pt(0, -D, 0.03)])
    ff.reverse! if ff.normal.z < 0
    fl.name = 'Floor, light LVT (dimension views only)'
    fl.layer = tag(model, T_FLOORL, [210, 210, 210])
    fl.material = mat(model, M_LVT_L)

    # painted base 4 1/4" x 1/2", every wall except the door opening (+ casing)
    base = fin.entities.add_group
    base.name = 'Base 4 1/4" painted'
    base.material = trim
    bh = 4.25
    bt = 0.5
    box(base, 0, -bt, 0, W, 0, bh, 'Base north')
    box(base, W - bt, -D, 0, W, 0, bh, 'Base east')
    box(base, 0, -D, 0, W, -D + bt, bh, 'Base south')
    box(base, 0, -D, 0, bt, RDOOR_Y[0] - 2.5, bh, 'Base west south of door')
    box(base, 0, RDOOR_Y[1] + 2.5, 0, bt, 0, bh, 'Base west north of door')

    # door casing 2 1/2" both faces, frame liner through the wall, lever on the leaf
    fr = fin.entities.add_group
    fr.name = "Room door trim (door 2'-9\" x 6'-8\" DEFAULT height)"
    fr.material = trim
    y0, y1 = RDOOR_Y
    [[-0.0, 0.75], [-THICK - 0.75, -THICK]].each do |xa, xb|
      box(fr, xa, y0 - 2.5, 0, xb, y0, DOOR_H + 2.5, 'Casing')
      box(fr, xa, y1, 0, xb, y1 + 2.5, DOOR_H + 2.5, 'Casing')
      box(fr, xa, y0 - 2.5, DOOR_H, xb, y1 + 2.5, DOOR_H + 2.5, 'Casing head')
    end
    box(fr, -THICK, y0, 0, 0, y0 + 0.75, DOOR_H, 'Jamb liner')
    box(fr, -THICK, y1 - 0.75, 0, 0, y1, DOOR_H, 'Jamb liner')
    box(fr, -THICK, y0, DOOR_H - 0.75, 0, y1, DOOR_H, 'Head liner')
    # leaf lies open along the south jamb line (x 0..33, y -132.75..-131.25): lever near its free end
    lv = fr.entities.add_group
    lv.name = 'Lever'
    box(lv, 29.0, -131.25, 36.0, 30.0, -129.6, 37.0, 'Lever rose', mat(model, M_METAL))
    box(lv, 26.0, -130.1, 36.0, 30.0, -129.4, 37.0, 'Lever arm', mat(model, M_METAL))

    cut_windows!(room)
    window_units!(model, fin)

    # outlets (illustrative), one per wall
    dv = fin.entities.add_group
    dv.name = 'Outlets (illustrative)'
    dv.material = trim
    box(dv, 90.0, -0.3, 14.0, 92.75, 0, 18.5, 'Outlet N')
    box(dv, 0, -60.0, 14.0, 0.3, -57.25, 18.5, 'Outlet W')
    box(dv, 80.0, -D, 14.0, 82.75, -D + 0.3, 18.5, 'Outlet S')
    box(dv, 2.0, -95.0, 44.0, 2.6, -92.25, 48.5, 'Switch W')
    dv.entities.grep(Sketchup::Group).last.move!(Geom::Transformation.translation([-2.0, 0, 0])) rescue nil

    # ceiling fixtures (2x4 lensed troffers), on the ceiling tag
    ct = tag(model, T_CEIL, [200, 200, 200])
    FIXTURES.each_with_index do |(x0, y0f, x1, y1f), k|
      g = fin.entities.add_group
      g.layer = ct
      g.name = "2x4 lensed troffer ##{k + 1} (illustrative)"
      box(g, x0, y0f, CEIL - 0.5, x1, y1f, CEIL, 'Trim', trim)
      box(g, x0 + 1.5, y0f + 1.5, CEIL - 0.6, x1 - 1.5, y1f - 1.5, CEIL - 0.5, 'Lens', mat(model, M_LENS))
    end

    # context: corridor stub outside the room door, ground outside the windows
    co = fin.entities.add_group
    co.name = 'Context: corridor + exterior ground (illustrative)'
    co.layer = tag(model, T_CTX, [180, 180, 180])
    cx0 = -THICK - 60.0
    cx1 = -THICK
    box(co, cx0, -170.0, -1.0, cx1, -70.0, -0.02, 'Corridor floor', lvt)
    box(co, cx0 - 4.0, -170.0, 0, cx0, -70.0, CEIL, 'Corridor far wall', paint)
    box(co, cx0 - 4.0, -74.0, 0, cx1, -70.0, CEIL, 'Corridor end wall', paint)
    box(co, cx0 - 4.0, -174.0, 0, cx1, -170.0, CEIL, 'Corridor end wall', paint)
    box(co, cx0, -170.0, CEIL, cx1, -70.0, CEIL + 1.0, 'Corridor ceiling', mat(model, M_CEILT))
    box(co, W + THICK, -600.0, -24.0, W + 900.0, 400.0, -12.0, 'Exterior ground (12" below floor)', mat(model, M_GROUND))
    fin
  end

  # ========================================================== DESK (ASSUMED)

  def self.chair!(model, parent, cx, cy, face_deg)
    g = parent.entities.add_group
    g.name = 'Task chair (illustrative)'
    blk = mat(model, M_BLACK)
    mesh = mat(model, M_MESH)
    # 5-star base, gas column, seat, back (back on the -x side before rotation)
    5.times do |i|
      a = i * 2 * Math::PI / 5
      arm = g.entities.add_group
      box(arm, 0, -0.75, 2.5, 12.5, 0.75, 4.0, 'Base arm', blk)
      arm.transform!(Geom::Transformation.rotation(ORIGIN, Z_AXIS, a))
      cst = cyl(g, 12.0 * Math.cos(a), 12.0 * Math.sin(a), 0.0, 2.5, 1.2, 'Caster', blk, 12)
      cst
    end
    cyl(g, 0, 0, 4.0, 17.0, 1.1, 'Gas column', mat(model, M_METAL), 16)
    box(g, -9.5, -9.5, 17.0, 9.5, 9.5, 20.0, 'Seat', mesh)
    box(g, -10.5, -1.0, 20.0, -9.0, 1.0, 25.0, 'Back post', blk)
    box(g, -11.5, -9.0, 24.0, -10.0, 9.0, 40.0, 'Back', mesh)
    box(g, -1.0, -11.0, 20.0, 1.0, -9.5, 26.5, 'Arm post', blk)
    box(g, -1.0, 9.5, 20.0, 1.0, 11.0, 26.5, 'Arm post', blk)
    box(g, -5.0, -11.0, 26.5, 5.0, -9.0, 27.5, 'Arm pad', blk)
    box(g, -5.0, 9.0, 26.5, 5.0, 11.0, 27.5, 'Arm pad', blk)
    g.transform!(Geom::Transformation.translation([cx, cy, 0]) * Geom::Transformation.rotation(ORIGIN, Z_AXIS, face_deg * Math::PI / 180.0))
    g
  end

  def self.desk!(model)
    g = own(model.entities.add_group, 'desk')
    g.name = "DESK (ASSUMED: 2'-1 1/2\" x 5'-8 3/4\" scaled, at its plan position; client confirming what it is)"
    g.layer = tag(model, T_FURN, [140, 110, 80])
    d = DESK
    top = mat(model, M_DESKTOP)
    blk = mat(model, M_BLACK)
    box(g, d[:x0], d[:y0], d[:top] - 1.25, d[:x1], d[:y1], d[:top], 'Desk top', top)
    # sled legs at the north and south ends, modesty panel on the window side
    [[d[:y0] + 2.0, d[:y0] + 3.5], [d[:y1] - 3.5, d[:y1] - 2.0]].each do |ya, yb|
      box(g, d[:x0] + 1.5, ya, 0, d[:x0] + 3.0, yb, d[:top] - 1.25, 'Leg', blk)
      box(g, d[:x1] - 3.0, ya, 0, d[:x1] - 1.5, yb, d[:top] - 1.25, 'Leg', blk)
      box(g, d[:x0] + 1.5, ya, 0, d[:x1] - 1.5, yb, 1.0, 'Foot rail', blk)
      box(g, d[:x0] + 1.5, ya, d[:top] - 2.75, d[:x1] - 1.5, yb, d[:top] - 1.25, 'Top rail', blk)
    end
    box(g, d[:x1] - 3.0, d[:y0] + 3.5, 12.0, d[:x1] - 2.25, d[:y1] - 3.5, d[:top] - 1.25, 'Modesty panel', blk)
    # monitor + keyboard: the user sits on the WEST side facing the windows
    my = d[:y1] - 18.0   # work position at the north end; the middle carries the length dim, the south end the labels
    box(g, d[:x1] - 8.0, my - 4.0, d[:top], d[:x1] - 4.0, my + 4.0, d[:top] + 0.5, 'Monitor foot', blk)
    box(g, d[:x1] - 6.5, my - 1.0, d[:top] + 0.5, d[:x1] - 5.5, my + 1.0, d[:top] + 6.0, 'Monitor neck', blk)
    box(g, d[:x1] - 7.0, my - 12.0, d[:top] + 5.0, d[:x1] - 6.0, my + 12.0, d[:top] + 19.0, 'Monitor', blk)
    box(g, d[:x1] - 7.05, my - 11.5, d[:top] + 5.5, d[:x1] - 7.0, my + 11.5, d[:top] + 18.5, 'Screen', mat(model, M_SCREEN))
    box(g, d[:x0] + 11.0, my - 8.5, d[:top], d[:x0] + 16.5, my + 8.5, d[:top] + 0.6, 'Keyboard', blk)
    # Gabe round 2: tucked in. Seat front 7 1/2" under the desktop, arm pads (top 27 1/2") 3" under its
    # 28 1/4" underside. Chair back at x 97.75.
    chair!(model, g, d[:x0] - 2.0, my, 0.0)
    g
  end

  # =================================================================== NOTES

  def self.notes!(model)
    t = tag(model, T_NOTES, [90, 90, 96])
    g = own(model.entities.add_group, 'notes')
    g.name = 'Notes (plan)'
    g.layer = t
    m = mat(model, M_DARKTXT)
    NOTES.each_with_index { |s, i| floor_text(g, s, -40.0, -226.0 - 6.0 * i, 0.05, 2.6, m) }
    # ASSUMED labels on the items themselves (plan views)
    lt = tag(model, T_LABEL, [238, 98, 22])
    org = mat(model, M_ORANGE)
    lab = own(model.entities.add_group, 'notes')
    lab.name = 'ASSUMED labels (plan)'
    lab.layer = lt
    floor_text(lab, 'DESK (ASSUMED)', DESK[:x0] + 17.0, DESK[:y0] + 4.0, DESK[:top] + 0.2, 2.4, org, nil, 90.0)
    floor_text(lab, 'CLIENT CONFIRMING', DESK[:x0] + 20.5, DESK[:y0] + 4.0, DESK[:top] + 0.2, 1.7, org, nil, 90.0)
    floor_text(lab, 'CEILING 8\'-0" DEFAULT', 52.0, -134.0, 0.2, 2.6, org)
    g
  end

  # =============================================================== ROOM DIMS

  def self.room_dims!(model)
    t = tag(model, T_DIMS, [40, 40, 40])
    g = own(model.entities.add_group, 'dims')
    g.name = 'Room dimensions (plan)'
    g.layer = t
    e = g.entities
    z = 0.2
    s1 = 24.0
    s2 = 60.0
    # NORTH (y 0): overall
    dimx(e, pt(0, 0, z), pt(W, 0, z), Geom::Vector3d.new(0, s2, 0), t)
    # SOUTH (y -143): overall
    dimx(e, pt(0, -D, z), pt(W, -D, z), Geom::Vector3d.new(0, -s2, 0), t)
    # WEST (x 0): north corner -> door -> south corner, then overall
    v = Geom::Vector3d.new(-s1, 0, 0)
    dimx(e, pt(0, 0, z), pt(0, RDOOR_Y[1], z), v, t)
    dimx(e, pt(0, RDOOR_Y[1], z), pt(0, RDOOR_Y[0], z), v, t, 'door')
    outside_end(dimx(e, pt(0, RDOOR_Y[0], z), pt(0, -D, z), v, t, 'DERIVED'))
    dimx(e, pt(0, 0, z), pt(0, -D, z), Geom::Vector3d.new(-s2, 0, 0), t)
    # EAST (x W): upper window, pier, window, remainder, then overall
    v = Geom::Vector3d.new(s1, 0, 0)
    outside_start(dimx(e, pt(W, 0, z), pt(W, WINDOWS[0][1], z), v, t, 'ASSUMED'))
    dimx(e, pt(W, WINDOWS[0][1], z), pt(W, WINDOWS[1][0], z), v, t, 'pier ASM.')
    dimx(e, pt(W, WINDOWS[1][0], z), pt(W, WINDOWS[1][1], z), v, t, 'window')
    outside_end(dimx(e, pt(W, WINDOWS[1][1], z), pt(W, -D, z), v, t, 'DERIVED'))
    dimx(e, pt(W, 0, z), pt(W, -D, z), Geom::Vector3d.new(s2, 0, 0), t)
    # desk (ASSUMED, scaled): size and offsets to the east and north walls
    d = DESK
    zt = d[:top] + 0.3
    # length dim ON the desk top, west half, clear of the east-wall chain (Gabe round 2: it ran over the window dims)
    dimx(e, pt(d[:x0] + 6.0, d[:y0], zt + 20.0), pt(d[:x0] + 6.0, d[:y1], zt + 20.0), Geom::Vector3d.new(0.01, 0, 0), t)
    outside_start(dimx(e, pt(d[:x0], d[:y0], zt), pt(d[:x1], d[:y0], zt), Geom::Vector3d.new(0, -12.0, 0), t, 'ASM.'))
    outside_end(dimx(e, pt(d[:x1], d[:y0] + 3.0, CEIL + 4.5), pt(W, d[:y0] + 3.0, CEIL + 4.5), Geom::Vector3d.new(0, 0.01, 0), t))
    dimx(e, pt(d[:x0] + 12.0, d[:y1], CEIL + 4.5), pt(d[:x0] + 12.0, 0, CEIL + 4.5), Geom::Vector3d.new(0.01, 0, 0), t, 'ASSUMED')
    g
  end

  def self.room_elev_dims!(model)
    t = tag(model, T_ELEV, [40, 40, 40])
    g = own(model.entities.add_group, 'dims')
    g.name = 'Room elevation dimensions'
    g.layer = t
    e = g.entities
    # just north of the cut (y -112, south of the desk), in the white margin outside the cut walls
    yy = -111.5
    dimx(e, pt(-THICK, yy, 0), pt(-THICK, yy, CEIL), Geom::Vector3d.new(-12, 0, 0), t, 'ceiling DEFAULT')
    dimx(e, pt(W + THICK, yy, 0), pt(W + THICK, yy, SILL), Geom::Vector3d.new(12, 0, 0), t, 'sill ASSUMED')
    dimx(e, pt(W + THICK, yy, SILL), pt(W + THICK, yy, HEAD), Geom::Vector3d.new(12, 0, 0), t, 'window ASSUMED')
    g
  end

  # ===================================================================== BOOTH

  def self.booth(model)
    model.entities.grep(Sketchup::Group).find { |g| g.get_attribute(DICT, 'booth') && g.name =~ /4872/ }
  end

  def self.lw(g, x, y, z = 0.0)
    pt(x, y, z).transform(g.transformation)
  end

  def self.wbox(pts)
    xs = pts.map { |q| q.x.to_f }
    ys = pts.map { |q| q.y.to_f }
    zs = pts.map { |q| q.z.to_f }
    { :x0 => xs.min, :y0 => ys.min, :x1 => xs.max, :y1 => ys.max, :z0 => zs.min, :z1 => zs.max }
  end

  def self.lrect(g, x0, y0, x1, y1)
    wbox([lw(g, x0, y0), lw(g, x1, y0), lw(g, x1, y1), lw(g, x0, y1)])
  end

  def self.inst_box(g, c)
    t = g.transformation * c.transformation
    b = c.definition.bounds
    wbox((0..7).map { |i| b.corner(i).transform(t) })
  end

  def self.part(g, re)
    g.entities.find { |c| c.respond_to?(:definition) && c.definition.name =~ re }
  end

  def self.walk_pts(ents, tr, acc, depth = 0)
    return if depth > 8
    ents.each do |e|
      if e.is_a?(Sketchup::Edge)
        e.vertices.each { |v| acc << v.position.transform(tr) }
      elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        walk_pts(e.definition.entities, tr * e.transformation, acc, depth + 1)
      end
    end
  end

  # The wide-access door AS BUILT (world): hinge pin from the frame and leaf
  # hinges, the exterior lockset, the leaf's far tip -> swing radius.
  def self.real_door(g)
    door = part(g, /\ARightWADoor|\ALeftWADoor/)
    raise 'booth: no WA door part' unless door
    fh = []
    dh = []
    lock = []
    leaf = []
    stack = [[door.definition.entities, g.transformation * door.transformation]]
    until stack.empty?
      ents, tr = stack.pop
      ents.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        t = tr * e.transformation
        n = e.definition.name
        acc = []
        walk_pts(e.definition.entities, t, acc) if n =~ /\AHinge|\ALockset \(ext\)|\AWA door\z/
        fh.concat(acc) if n =~ /\AHinge \(door frame\)/
        dh.concat(acc) if n =~ /\AHinge \(door\)/
        lock.concat(acc) if n =~ /\ALockset \(ext\)/
        leaf.concat(acc) if n =~ /\AWA door\z/
        stack << [e.definition.entities, t] unless n =~ /\AHinge|\ALockset/
      end
    end
    raise "booth door: hinge/lock/leaf not found (#{fh.size}/#{dh.size}/#{lock.size}/#{leaf.size})" if fh.empty? || dh.empty? || lock.empty? || leaf.empty?
    a = wbox(fh)
    b = wbox(dh)
    piv = pt((a[:x0] + a[:x1] + b[:x0] + b[:x1]) / 4.0, (a[:y0] + a[:y1] + b[:y0] + b[:y1]) / 4.0)
    lb = wbox(lock)
    stk = pt((lb[:x0] + lb[:x1]) / 2.0, (lb[:y0] + lb[:y1]) / 2.0)
    tip = leaf.map { |q| pt(q.x, q.y) }.max_by { |q| q.distance(piv) }
    { :pivot => piv, :lock => stk, :r => tip.distance(piv).to_f, :frame => door.definition.name, :leaf => wbox(leaf) }
  end

  # LeftWADoor.skp and RightWADoor.skp in NewMasterComponentList are geometrically IDENTICAL
  # (observed 7 Oct 2026: frame hinge at y 44.0, exterior lockset at y 12.2 in both), the same
  # finding as Left/Right40Door on University of Tennessee. As built, the leaf hinges on the LEFT
  # seen from outside. The quote says hinge R, so the door part is mirrored ONCE about its own slot
  # centre (booth-local x 26.5, slot 2..51) to draw the hinge on the RIGHT seen from outside (the
  # east end of the booth's south face). Real component, mirrored; same method as UT.
  DOOR_SLOT_CX = 26.5
  def self.mirror_door!(g)
    return 0 if g.get_attribute(DICT, 'door_mirrored')
    n = 0
    g.entities.each do |e|
      next unless e.respond_to?(:definition) && e.definition.name =~ /WADoor\z/
      e.transformation = Geom::Transformation.scaling(pt(DOOR_SLOT_CX, 0, 0), -1.0, 1.0, 1.0) * e.transformation
      n += 1
    end
    g.set_attribute(DICT, 'door_mirrored', n)
    n
  end

  def self.place_booth!(model)
    g = booth(model)
    raise 'no Holmdel booth: run .forge/builder/holmdel/jobs/build-booth.rb first' unless g
    return g if g.get_attribute(DICT, 'placed')
    o = g.transformation.origin
    raise "booth not at the tool's origin (#{o.to_a.inspect}); refusing to guess" if o.x.abs > 0.01 || o.y.abs > 0.01
    tx = GAP_WEST + BOOTH_EXT[0]
    ty = -GAP_NORTH
    g.transformation = Geom::Transformation.translation([tx, ty, 0]) *
                       Geom::Transformation.rotation(ORIGIN, Z_AXIS, BOOTH_ROT * Math::PI / 180.0) * g.transformation
    g.set_attribute(DICT, 'placed', true)
    g
  end

  # Everything measured off the placed booth, world coords.
  def self.geom(model, g = booth(model))
    vent = part(g, /\A\d+VNT/)
    win = part(g, /WDO\z|\A\d+Panel\d+WDO/)
    desk = part(g, /\ADeskSmall/)
    roofs = g.entities.select { |c| c.respond_to?(:definition) && c.definition.name =~ /CL\z|Light/ }
    {
      :seal => lrect(g, 0.0, 0.0, 74.0, 50.0), :int => lrect(g, 2.0, 2.0, 72.0, 48.0),
      :efp => (e = part(g, /\AEFP/)) && inst_box(g, e),
      :vent => vent && inst_box(g, vent), :window => win && inst_box(g, win), :desk => desk && inst_box(g, desk),
      :door => real_door(g), :top => g.bounds.max.z.to_f, :roofs => roofs, :bounds => wbox((0..7).map { |i| g.bounds.corner(i) })
    }
  end

  def self.box_gap(a, b)
    dx = [a[:x0] - b[:x1], b[:x0] - a[:x1], 0].max
    dy = [a[:y0] - b[:y1], b[:y0] - a[:y1], 0].max
    Math.hypot(dx, dy)
  end

  def self.circle_box(cx, cy, r, b)
    dx = [b[:x0] - cx, 0, cx - b[:x1]].max
    dy = [b[:y0] - cy, 0, cy - b[:y1]].max
    Math.hypot(dx, dy) - r
  end

  # Points of a door's swept quarter (leaf positions from closed to 90 deg open), for honest
  # clearances: a full circle overstates reach on the side the leaf never sweeps.
  def self.sweep_pts(piv, closed_to, open_dir, r, n = 24, k = 6)
    c = Geom::Vector3d.new(closed_to.x - piv.x, closed_to.y - piv.y, 0)
    c.length = 1.0
    o = open_dir.clone
    o.length = 1.0
    sgn = (c.x * o.y - c.y * o.x) < 0 ? -1.0 : 1.0
    pts = []
    (0..n).each do |i|
      ang = sgn * (Math::PI / 2.0) * i / n
      ca = Math.cos(ang)
      sa = Math.sin(ang)
      dx = c.x * ca - c.y * sa
      dy = c.x * sa + c.y * ca
      (1..k).each { |j| pts << [piv.x + dx * r * j / k, piv.y + dy * r * j / k] }
    end
    pts
  end

  def self.pts_box(pts, b)
    pts.map { |x, y| Math.hypot([b[:x0] - x, 0, x - b[:x1]].max, [b[:y0] - y, 0, y - b[:y1]].max) }.min
  end

  def self.fit_rows(model)
    g = booth(model)
    raise 'booth not placed' unless g && g.get_attribute(DICT, 'placed')
    r = geom(model, g)
    s = r[:seal]
    d = r[:door]
    v = r[:vent]
    rows = []
    n = BOOTH_MODEL
    rows << ["#{n}: exterior #{fi(s[:x1] - s[:x0])} x #{fi(s[:y1] - s[:y0])}, top #{fi(r[:top])} drawn", nil]
    rows << ["#{n}: exterior to WEST wall", s[:x0]]
    rows << ["#{n}: exterior to NORTH wall (vent side)", -s[:y1]]
    rows << ["#{n}: vent hood/silencer (46VNT_VSS_EFS) to NORTH wall", -v[:y1]]
    rows << ["#{n}: vent hood depth beyond the exterior (measured)", v[:y1] - s[:y1]]
    rows << ["#{n}: vent part spans x #{v[:x0].round(2)}..#{v[:x1].round(2)} along the north wall", nil]
    rows << ["#{n}: exterior to EAST wall (windows)", W - s[:x1]]
    rows << ["#{n}: exterior to SOUTH wall", s[:y0] + D]
    wc = r[:window]
    face = wc && ((wc[:x0] + wc[:x1]) / 2.0 > (s[:x0] + s[:x1]) / 2.0 ? 'EAST' : 'not east')
    rows << ["#{n}: booth window wall faces #{face} (window part x #{wc[:x0].round(2)}..#{wc[:x1].round(2)}, y #{wc[:y0].round(1)}..#{wc[:y1].round(1)})", nil]
    rows << ["#{n}: booth window to the room's east windows (clear floor)", W - s[:x1]]
    # the desk, kept at its plan position (Gabe): every gap to the booth
    dk = DESK
    db = { :x0 => dk[:x0], :x1 => dk[:x1], :y0 => dk[:y0], :y1 => dk[:y1] }
    rows << ["DESK (east wall, plan position): booth exterior to desk, x gap", dk[:x0] - s[:x1]]
    if r[:desk]
      bd = r[:desk]
      rows << ["DESK: booth's outside desk (DeskSmall on the window wall, to x #{bd[:x1].round(2)}) to desk = tester seat / walk gap", dk[:x0] - bd[:x1]]
    end
    if wc
      ov = [[wc[:y1], dk[:y1]].min - [wc[:y0], dk[:y0]].max, 0].max
      rows << ["DESK: stands in front of the booth window wall for this much of its #{fi(wc[:y1] - wc[:y0])} run (#{fi(dk[:x0] - wc[:x1])} away)", ov]
    end
    bsw = sweep_pts(d[:pivot], d[:lock], Geom::Vector3d.new(0, -1, 0), d[:r])
    rsw = sweep_pts(pt(*RDOOR_PIVOT), pt(0.0, RDOOR_Y[1]), Geom::Vector3d.new(1, 0, 0), RDOOR_R)
    rows << ["DESK: to the booth door's swept quarter (leaf swings south, toward the room door)", pts_box(bsw, db)]
    rows << ["DESK: north end to north wall / east side to east wall", nil]
    rows << ["  north", dk[:y1].abs]
    rows << ["  east", W - dk[:x1]]
    rows << ["DESK: south end to south wall (walk past the desk)", dk[:y0] + D]
    rows << ["#{n}: door #{d[:frame]}: hinge (#{d[:pivot].x.round(2)}, #{d[:pivot].y.round(2)}), lockset (#{d[:lock].x.round(1)}, #{d[:lock].y.round(1)}), leaf radius", d[:r]]
    rows << ["#{n}: booth door swing tip (south) to south wall", (d[:pivot].y - d[:r]) + D]
    rows << ["#{n}: booth door swept quarter to room door swept quarter",
             bsw.map { |ax, ay| rsw.map { |bx, by| Math.hypot(ax - bx, ay - by) }.min }.min]
    all = [s, v, r[:desk]].compact
    near = all.map { |b| circle_box(RDOOR_PIVOT[0], RDOOR_PIVOT[1], RDOOR_R, b) }.min
    rows << ["#{n}: room door swing (33\") to nearest booth part", near]
    rows << ["#{n}: walkway, booth south face to room door swing (x 0..33)", (s[:y0] - (RDOOR_Y[1]))]
    rows << ["#{n}: open floor south of the booth (to the south wall)", s[:y0] + D]
    rows << ["#{n}: top (drawn) to 8'-0\" DEFAULT ceiling", CEIL - r[:top]]
    rows << ["#{n}: catalog install height 6'-11\" to 8'-0\" ceiling", CEIL - CAT_H]
    it = r[:int]
    rows << ["#{n}: interior #{fi(it[:x1] - it[:x0])} x #{fi(it[:y1] - it[:y0])} (panel faces)", nil]
    rows
  end

  def self.fit_report(model = Sketchup.active_model)
    rows = fit_rows(model)
    puts 'FIT CHECK, Holmdel option 2 (negative = overlap)'
    rows.each { |r| puts format('  %-96s %s', r[0], r[1].nil? ? '' : fi(r[1])) }
    rows.map { |r| [r[0], r[1] && r[1].round(2)] }
  end

  # Place (once) and rebuild the booth's own annotations: swing, dims, labels.
  def self.booth!(model = Sketchup.active_model)
    model.start_operation('Holmdel booth', true)
    g = place_booth!(model)
    mirror_door!(g)
    g.name = "#{BOOTH_MODEL} (components): Audiology Basic Plus as quoted, NO ramp"
    clear_mine!(model, %w[booth-ann])
    r = geom(model, g)
    s = r[:seal]
    d = r[:door]
    ag = own(model.entities.add_group, 'booth-ann')
    ag.name = 'Booth annotations (swing, fit dims, interior dims)'
    # swing arc, 90 deg, on the open (south) side
    sw = ag.entities.add_group
    sw.name = "Booth door swing, leaf #{fi(d[:r])}"
    sw.layer = tag(model, T_SWING, [238, 98, 22])
    piv = pt(d[:pivot].x, d[:pivot].y, 0.3)
    closed = Geom::Vector3d.new(d[:lock].x - piv.x, d[:lock].y - piv.y, 0)
    closed.length = d[:r]
    out = Geom::Vector3d.new(0, -d[:r], 0)
    sweep = (closed.x * out.y - closed.y * out.x) < 0 ? -1.0 : 1.0
    arc = (0..18).map { |i| piv.offset(closed).transform(Geom::Transformation.rotation(piv, Z_AXIS, (Math::PI / 2.0) * i / 18 * sweep)) }
    arc.each_cons(2) { |a, b| sw.entities.add_line(a, b) }
    sw.entities.add_line(piv, piv.offset(out))
    booth_dims!(model, ag, r)
    puts "foam: #{foam_gray!(model)}"
    lt = tag(model, T_LABEL, [238, 98, 22])
    org = mat(model, M_ORANGE)
    floor_text(ag, BOOTH_MODEL, s[:x0] + 22.0, s[:y0] + 30.0, r[:top] + 0.3, 4.5, org, lt)
    floor_text(ag, 'AUDIOLOGY BASIC PLUS, NO RAMP', s[:x0] + 12.0, s[:y0] + 23.0, r[:top] + 0.3, 2.2, org, lt)
    model.commit_operation
    fit_report(model)
  rescue StandardError => e
    model.abort_operation
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(6)
    raise
  end

  def self.booth_dims!(model, parent, r)
    tp = tag(model, T_DIMS_B, [238, 98, 22])
    te = tag(model, T_ELEV, [40, 40, 40])
    ti = tag(model, T_INT, [40, 40, 40])
    e = parent.entities
    s = r[:seal]
    v = r[:vent]
    d = r[:door]
    zt = r[:top] + 0.3
    z = 0.3
    x0, y0, x1, y1 = s[:x0], s[:y0], s[:x1], s[:y1]
    # size
    # on the light floor beside the booth, not on its dark roof
    dimx(e, pt(x0, y0, z), pt(x1, y0, z), Geom::Vector3d.new(0, -8.0, 0), tp, 'booth')
    zw = CEIL + 4.5   # above the walls, so the wall tops never hide the text
    dimx(e, pt(x0, y0, zw), pt(x0, y1, zw), Geom::Vector3d.new(-12.0, 0, 0), tp)
    # gaps to the walls
    outside_start(dimx(e, pt(0, y0 + 4.0, zt), pt(x0, y0 + 4.0, zt), Geom::Vector3d.new(0, 0.01, 0), tp))
    outside_end(dimx(e, pt(x1 - 4.0, y1, zt), pt(x1 - 4.0, 0, zt), Geom::Vector3d.new(0.01, 0, 0), tp))
    # booth to the desk, and the booth's outside desk to the desk (the tester's seat zone)
    dimx(e, pt(x1, -109.0, DESK[:top] + 0.5), pt(DESK[:x0], -109.0, DESK[:top] + 0.5), Geom::Vector3d.new(0, 0.01, 0), tp, 'to desk')
    if r[:desk]
      bd = r[:desk]
      dimx(e, pt(bd[:x1], -30.0, r[:top] + 1.0), pt(DESK[:x0], -30.0, r[:top] + 1.0), Geom::Vector3d.new(0, 0.01, 0), tp, 'clear')
    end
    # door swing south, and walkway to the room door's swing
    zh = r[:top] + 1.0
    dimx(e, pt(d[:pivot].x - 4.0, y0, zh), pt(d[:pivot].x - 4.0, d[:pivot].y - d[:r], zh), Geom::Vector3d.new(0.01, 0, 0), tp)   # 'swing' suffix dropped: it ran into the to-desk text; the arc says it
    dimx(e, pt(10.0, y0, zh), pt(10.0, RDOOR_Y[1], zh), Geom::Vector3d.new(0.01, 0, 0), tp, 'walkway')
    # elevation (north-looking section at y -75): booth height and clearance at the booth's east corner
    ex = x1
    ye = -111.5  # just north of the section cut, in front of everything it shows
    dimx(e, pt(ex, ye, 0), pt(ex, ye, r[:top]), Geom::Vector3d.new(8, 0, 0), te, 'booth')
    dc = dimx(e, pt(ex, ye, r[:top]), pt(ex, ye, CEIL), Geom::Vector3d.new(8, 0, 0), te, 'to ceiling')
    (dc.has_aligned_text = false) rescue nil
    # interior plan: light floor over the EFP, interior and EFP sizes
    it = r[:int]
    ef = r[:efp]
    fz = ef ? ef[:z1] : 2.11
    slab(parent, [[it[:x0], it[:y0]], [it[:x1], it[:y0]], [it[:x1], it[:y1]], [it[:x0], it[:y1]]],
         fz + 0.02, fz + 0.05, 'Booth floor, light WhisperRoom carpet (interior dims view only)', mat(model, M_WRC_L), ti)
    zi = fz + 0.2
    dimx(e, pt(it[:x0], it[:y1] - 6.0, zi), pt(it[:x1], it[:y1] - 6.0, zi), Geom::Vector3d.new(0, 0.01, 0), ti, 'interior')
    dimx(e, pt(it[:x1] - 8.0, it[:y0], zi), pt(it[:x1] - 8.0, it[:y1], zi), Geom::Vector3d.new(0.01, 0, 0), ti, 'interior')
    if ef
      dimx(e, pt(ef[:x0], ef[:y0] + 10.0, zi), pt(ef[:x1], ef[:y0] + 10.0, zi), Geom::Vector3d.new(0, 0.01, 0), ti, 'elevated floor')
      dimx(e, pt(ef[:x0] + 24.0, ef[:y0], zi), pt(ef[:x0] + 24.0, ef[:y1], zi), Geom::Vector3d.new(0.01, 0, 0), ti, 'elevated floor')
    end
  end

  # Foam colour as quoted (Gray). Foam.skp has no colour variants (wr-overlays.rb reports the
  # link's colour only); its material [Color_I06] is recoloured to a neutral gray ONLY when Foam
  # is that material's sole user (same method as University of Tennessee foam_gray!).
  def self.foam_gray!(model)
    fm = model.materials['[Color_I06]']
    return 'no [Color_I06]' unless fm
    users = Hash.new(0)
    model.definitions.each do |d|
      d.entities.each do |e|
        users[d.name] += 1 if (e.respond_to?(:material) && e.material == fm) || (e.is_a?(Sketchup::Face) && e.back_material == fm)
      end
    end
    return "NOT recoloured: [Color_I06] also used by #{users.keys.inspect}" unless users.keys == ['Foam']
    fm.color = Sketchup::Color.new(96, 96, 98)
    'foam gray'
  end

  # ================================================================== LIGHTS

  def self.quiet_load(file)
    was_s = $wr_suppress_autorun
    was_n = $wr_no_autorun
    $wr_suppress_autorun = true
    $wr_no_autorun = true
    load File.join(File.dirname(__FILE__), file)
  ensure
    $wr_suppress_autorun = was_s
    $wr_no_autorun = was_n
  end

  def self.lights!(model = Sketchup.active_model)
    raise 'V-Ray is not loaded' unless defined?(VRay::Command) && VRay::Command.respond_to?(:create_rectangle_light)
    quiet_load('wr-drop-lights.rb') unless defined?(WR_DropLights)
    remove_lights!(model)
    ctx = VRay::Context.active
    raise 'no active V-Ray context' unless ctx
    scene = ctx.scene
    t = tag(model, T_LIGHT, [255, 220, 120])
    rgb = WR_DropLights.kelvin_rgb(TROFFER_K)
    color = VRay::Color.new(rgb[0], rgb[1], rgb[2])
    made = []
    model.start_operation('Holmdel troffer lights', true)
    FIXTURES.each_with_index do |(x0, y0, x1, y1), k|
      hx = (x1 - x0 - 3.0) / 2.0     # V-Ray rectangle light sizes are HALF-lengths
      hy = (y1 - y0 - 3.0) / 2.0
      d, plug = WR_DropLights.create_light(ctx, hx, hy)
      wants = [[:invisible, true], [:affectReflections, false], [:units, 1.0],
               [:intensity, LUMENS * LIGHT_GAIN * LIGHT_TUNE], [:color, color]]
      errs = WR_DropLights.write_params(scene, plug, wants)
      inst = model.entities.add_instance(d, Geom::Transformation.translation(pt((x0 + x1) / 2.0, (y0 + y1) / 2.0, CEIL - 0.8)))
      inst.layer = t
      inst.name = "Troffer light ##{k + 1} (#{LUMENS.round} lm x #{LIGHT_GAIN.round} x #{LIGHT_TUNE})"
      own(inst, 'light')
      made << [inst.name, (plug[:intensity] rescue nil), errs.keys]
    end
    begin
      o = VRay::Command.create_dome_light(:context => ctx, :path => nil)
      WR_DropLights.write_params(scene, o.plugin, [[:intensity, DOME_INTENSITY], [:invisible, false]])
      di = model.entities.add_instance(o.entity, Geom::Transformation.translation(pt(70, -70, 0)))
      di.layer = t
      di.name = "Dome light (white, x#{DOME_INTENSITY})"
      own(di, 'light')
      made << [di.name]
    rescue StandardError => e
      made << ['dome FAILED', e.message]
    end
    model.commit_operation
    made
  end

  def self.remove_lights!(model = Sketchup.active_model)
    gone = model.entities.select { |e| mine?(e, 'light') }
    model.entities.erase_entities(gone) unless gone.empty?
    gone.size
  end

  # ================================================================== SCENES

  def self.all_tags
    [T_DIMS, T_DIMS_B, T_ELEV, T_INT, T_NOTES, T_LABEL, T_SWING, T_FLOORL, T_CTX, T_CEIL, T_LIGHT,
     'WR-Dims', 'WR-Dims-Doors', 'WR-Obstruction', 'WR-Notes']
  end

  def self.cam(eye, target, fov)
    c = Sketchup::Camera.new(pt(*eye), pt(*target), Z_AXIS, true, fov)
    (c.aspect_ratio = 0.0) rescue nil
    c
  end

  # Straight-down PARALLEL projection (no perspective), framed for 16:9: camera.height is the
  # visible model height in inches.
  def self.par_cam(cx, cy, w, h)
    c = Sketchup::Camera.new(pt(cx, cy, 2000.0), pt(cx, cy, 0), Y_AXIS, false)
    c.height = [h, w / (16.0 / 9.0)].max
    (c.aspect_ratio = 0.0) rescue nil
    c
  end

  def self.top_cam(cx, cy, w, h, fov = 12.0)
    a = 16.0 / 9.0
    half = [h / 2.0, w / (2.0 * a)].max
    dist = half / Math.tan(fov * Math::PI / 360.0)
    c = Sketchup::Camera.new(pt(cx, cy, dist), pt(cx, cy, 0), Y_AXIS, true, fov)
    (c.aspect_ratio = 0.0) rescue nil
    c
  end

  def self.section_plane(model)
    sp = model.entities.grep(Sketchup::SectionPlane).find { |s| s.get_attribute(DICT, 'own') }
    unless sp
      # keeps everything NORTH of y -75 (the booth), removes the south wall and the desk's south end
      sp = model.entities.add_section_plane([pt(0, -112.0, 0), Geom::Vector3d.new(0, 1, 0)])
      own(sp, 'section')
      (sp.name = 'Elevation cut looking north') rescue nil
    end
    sp.layer = tag(model, T_SECTION, [200, 200, 200])
    sp
  end

  # [name, kind, tags on, camera, use the section cut]
  def self.scene_defs(model)
    r = geom(model)
    s = r[:seal]
    cx = (s[:x0] + s[:x1]) / 2.0
    cy = (s[:y0] + s[:y1]) / 2.0
    [
      ['01 hero from the room door', :render, [], cam([7, -127, 62], [62, -32, 40], 68.0), false],
      ['02 hero window side', :render, [], cam([134, -134, 60], [58, -36, 42], 60.0), false],
      ['03 overhead cutaway', :render, [], cam([215, -250, 400], [68, -70, 0], 34.0), false],
      ['04 dimensioned plan', :plan, [T_DIMS, T_DIMS_B, T_SWING, T_FLOORL, T_NOTES, T_LABEL], top_cam(70, -96, 340, 345), false],
      ['05 dimensioned elevation', :elev, [T_ELEV, T_CEIL], cam([71, -330, 50], [71, 0, 50], 30.0), true],
      ['04b dimensioned plan parallel', :plan, [T_DIMS, T_DIMS_B, T_SWING, T_FLOORL, T_NOTES, T_LABEL], par_cam(68, -104, 360, 372), false],
      ['06 booth interior plan', :plan, [T_INT], top_cam(cx, cy, 96, 70), false]
    ]
  end

  def self.scenes!(model = Sketchup.active_model)
    view = model.active_view
    sp = section_plane(model)
    model.options['PageOptions']['ShowTransition'] = false rescue nil
    model.rendering_options['DisplaySectionPlanes'] = false
    model.start_operation('Holmdel scenes', true)
    model.pages.to_a.each { |pg| model.pages.erase(pg) }
    roofs = geom(model)[:roofs]
    made = []
    scene_defs(model).each do |name, kind, on, c, cut|
      roofs.each { |e| e.hidden = (name =~ /\A06 /) ? true : false }
      all_tags.each { |t| model.layers[t].visible = false if model.layers[t] }
      model.layers[T_CTX].visible = (kind == :render && name !~ /overhead/) if model.layers[T_CTX]
      model.layers[T_CEIL].visible = (kind == :render && name !~ /overhead/) if model.layers[T_CEIL]
      model.layers[T_LIGHT].visible = true if kind == :render && model.layers[T_LIGHT]
      model.layers[T_LABEL].visible = true if kind == :plan && name =~ /\A04/
      on.each { |t| model.layers[t].visible = true if model.layers[t] }
      model.entities.active_section_plane = cut ? sp : nil
      view.camera = c
      pg = model.pages.add(name)
      pg.use_section_planes = true if pg.respond_to?(:use_section_planes=)
      pg.update
      made << pg.name
    end
    model.entities.active_section_plane = nil
    roofs.each { |e| e.hidden = false }
    model.pages.selected_page = model.pages[0]
    model.commit_operation
    made
  end

  # ===================================================================== RUN

  def self.run(model = Sketchup.active_model)
    raise "wrong file: #{model.path}" unless model.path =~ /Holmdel/i
    room = room_group(model)
    raise "take-off room '#{ROOM}' not found: build it from clients/holmdel/takeoff.lock.json first" unless room
    model.options['UnitsOptions']['LengthFormat'] = Length::Architectural rescue nil
    model.start_operation('Holmdel finishes', true)
    gone = clear_mine!(model, %w[finish desk notes dims])
    finishes!(model, room)
    desk!(model)
    notes!(model)
    room_dims!(model)
    room_elev_dims!(model)
    model.commit_operation
    puts "Holmdel: cleared #{gone}, room finished"
    true
  rescue StandardError => e
    model.abort_operation
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(8)
    raise
  end
end

WR_Holmdel.run unless $wr_suppress_autorun
