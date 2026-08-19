# @title Dowaly / Kuwait TV — three 4872 E...
# @cat Draw the room
#
# dowaly-kuwait-tv.rb — the Kuwait Television commentary room with three
# MDL 4872 E booths, drawn as a top-view layout.
#
#   Extensions > Developer > Ruby Console, then:
#     load "C:/Users/bento/Documents/Claude/Sketchup/scripts/dowaly-kuwait-tv.rb"
#
# Ctrl+Z before re-running.
#
# ===========================================================================
# THE JOB
#
# AlDowaly Center (Hosam Shehadeh) for Kuwait Television, via Sarah, 18 Aug
# 2026. Three independent sports-commentary booths in one existing room, one
# commentator each, all three potentially live on different events at the same
# time. The client asked for a recommended TOP-VIEW LAYOUT showing spacing,
# clearance from the room walls, door swing, ventilation positioning,
# maintenance access and cable entry. That is what this draws.
#
# 3 x MDL 4872 E, each with VSS, EFS, AP and an office desk.
#
# ===========================================================================
# SOURCES
#
# ROOM        the client's own figures, in centimetres, converted here and
#             nowhere else: 549 x 450 x 275 cm.
#             549 cm = 216.14 in, 450 cm = 177.17 in, 275 cm = 108.27 in.
#             He calls them "approximate" — they are not a survey.
#
# BOOTH       models.json, the canonical catalogue: MDL 4872 Enhanced is
#             4'-2" x 6'-2" x 7'-1"  ->  50 x 74 in footprint, 85 in of
#             install clearance. Standard and Enhanced share the footprint;
#             only the height differs (83 vs 85).
#
# CLEARANCES  WhisperRoomQuote/assets/layout-render.js:1064, the rule the
#             quote tool's own renderer uses: "door swing 23.5/29.5/34.5, the
#             ADA ramp 45.625 on the WA-door wall, a vent 6 (10 w/ EFS), else
#             the recommended 1" gap". These booths have EFS, so 10 in at the
#             vent wall; the 4872's door frame is under 46 in, so 23.5 in of
#             swing.
#
# ===========================================================================
# THE CEILING IS FINE, WHICH IS WORTH SAYING FIRST
#
# 275 cm = 108.27 in against the 85 in an Enhanced 4872 needs to be assembled.
# 23.3 in to spare. Height is normally the thing that kills a job; here it is
# the least of the constraints.
#
# ===========================================================================
# THE ONE NUMBER THAT IS NOT SOURCED, AND IT IS THE CLIENT'S MAIN QUESTION
#
# Hosam's priority is acoustic separation BETWEEN the three booths — three
# commentators shouting at three different matches, side by side. He asked
# specifically for a recommended spacing.
#
# WHISPERROOM PUBLISHES NO BOOTH-TO-BOOTH ACOUSTIC SEPARATION FIGURE. The 1 in
# in the clearance table is an assembly gap, not an isolation figure. GAP below
# is therefore set to 12 in because it is a sensible working aisle — it lets a
# person get between the units to reach the EFS boxes and the cable runs — and
# NOT because 12 in is known to buy any particular amount of isolation.
#
# Do not put a decoupling claim in front of this client off the back of this
# drawing. The spacing question needs an answer from engineering, and the only
# customer-facing acoustic figure is the website's ASTM E336 dB range.
#
module WR_Dowaly

  CM = 2.54

  # ─── the room, from the client's centimetres ───────────────────────────
  ROOM_L = 549.0 / CM     # 216.14 in — the long wall
  ROOM_W = 450.0 / CM     # 177.17 in
  ROOM_H = 275.0 / CM     # 108.27 in

  # ─── MDL 4872 E ────────────────────────────────────────────────────────
  BOOTH_W = 50.0          # 4'-2"
  BOOTH_D = 74.0          # 6'-2"
  BOOTH_H = 85.0          # 7'-1" install clearance

  # ─── clearances, all from layout-render.js:1064 ────────────────────────
  NOMINAL = 1.0
  EFS     = 10.0          # vent wall with exterior fan silencers
  SWING   = 23.5          # door swing, frame under 46 in

  # ─── the layout ────────────────────────────────────────────────────────
  # A working aisle, NOT an acoustic figure. See the header.
  GAP = 12.0

  WALL_T = 6.0
  DOOR_W = 32.0           # the drawn leaf. The 4872's opening is narrower than
                          # the 46 in frame that would earn 29.5 in of swing.

  MAT_FLOOR = "0128_White"
  MAT_WALL  = "0099_LightSteelBlue"
  MAT_RGB   = { "0128_White" => [255, 255, 255],
                "0099_LightSteelBlue" => [176, 196, 222] }.freeze

  # ═══════════════════════════════════════════════════════════════════════

  def self.pt(x, y, z = 0.0)
    Geom::Point3d.new(x, y, z)
  end

  def self.tag(model, name, rgb)
    l = model.layers[name] || model.layers.add(name)
    (l.color = Sketchup::Color.new(*rgb)) rescue nil
    l
  end

  def self.material(model, name)
    m = model.materials[name]
    return m if m
    m = model.materials.add(name)
    m.color = Sketchup::Color.new(*(MAT_RGB[name] || [200, 200, 200]))
    m
  end

  def self.quad(parent, corners, z, h, name, layer = nil)
    g = parent.entities.add_group
    f = g.entities.add_face(corners.map { |p| pt(p[0], p[1], z) })
    return nil if f.nil?
    f.reverse! if f.normal.z < 0
    f.pushpull(h) if h > 0.001
    g.name = name
    g.layer = layer if layer
    g
  end

  def self.flat(parent, corners, name, layer, z = 0.25)
    g = parent.entities.add_group
    f = g.entities.add_face(corners.map { |p| pt(p[0], p[1], z) })
    return nil if f.nil?
    g.name = name
    g.layer = layer
    g
  end

  def self.dim(ents, a, b, off)
    ents.add_dimension_linear(a, b, off)
  rescue StandardError => e
    puts "  (dimension skipped: #{e.message})"
  end

  def self.ft(v)
    f = (v / 12.0).floor
    r = v - (f * 12.0)
    format("%d'-%s\"", f, (r.round(2) == r.round ? r.round.to_s : format('%.2f', r)))
  end

  def self.cm(v)
    format('%.0f cm', v * CM)
  end

  def self.set_imperial(model)
    o = model.options["UnitsOptions"]
    o["LengthFormat"] = Length::Architectural
    o["LengthUnit"]   = Length::Inches
  rescue StandardError => e
    puts "  (couldn't set units: #{e.message})"
  end

  # ═══════════════════════════════════════════════════════════════════════
  def self.build
    model = Sketchup.active_model
    set_imperial(model)
    model.start_operation('Dowaly / Kuwait TV — three 4872 E', true)

    t_floor = tag(model, 'WR-KTV-Room',      [200, 200, 200])
    t_wall  = tag(model, 'WR-KTV-Walls',     [120, 128, 140])
    t_booth = tag(model, 'WR-KTV-Booths',    [ 90,  96, 104])
    t_efs   = tag(model, 'WR-KTV-Vent',      [ 64, 102, 124])
    t_swing = tag(model, 'WR-KTV-DoorSwing', [238,  98,  22])
    t_aisle = tag(model, 'WR-KTV-Access',    [150, 170, 150])
    t_note  = tag(model, 'WR-KTV-Notes',     [200,  60,  60])

    root = model.entities.add_group
    root.name  = 'Kuwait TV commentary room — 3 x MDL 4872 E'
    root.layer = t_floor

    # Room floor and walls. Origin = inside corner, +X along the 549 cm wall.
    f = quad(root, [[0, 0], [ROOM_L, 0], [ROOM_L, ROOM_W], [0, ROOM_W]],
             0.0, 0.0, 'room floor', t_floor)
    f.material = material(model, MAT_FLOOR) if f
    [[[-WALL_T, -WALL_T], [ROOM_L + WALL_T, -WALL_T], [ROOM_L + WALL_T, 0], [-WALL_T, 0]],
     [[-WALL_T, ROOM_W], [ROOM_L + WALL_T, ROOM_W], [ROOM_L + WALL_T, ROOM_W + WALL_T], [-WALL_T, ROOM_W + WALL_T]],
     [[-WALL_T, 0], [0, 0], [0, ROOM_W], [-WALL_T, ROOM_W]],
     [[ROOM_L, 0], [ROOM_L + WALL_T, 0], [ROOM_L + WALL_T, ROOM_W], [ROOM_L, ROOM_W]]
    ].each_with_index do |q, i|
      g = quad(root, q, 0.0, ROOM_H, "room wall #{i}", t_wall)
      g.material = material(model, MAT_WALL) if g
    end

    # The row. Booths stand against the far (+Y) wall with their vent wall to
    # it, doors facing the room. The run is centred on the long wall.
    run   = (3 * BOOTH_W) + (2 * GAP)
    x0    = (ROOM_L - run) / 2.0
    back  = ROOM_W - EFS              # booth back face — EFS boxes fill the 10"
    front = back - BOOTH_D            # booth door face

    3.times do |i|
      bx = x0 + (i * (BOOTH_W + GAP))
      quad(root, [[bx, front], [bx + BOOTH_W, front],
                  [bx + BOOTH_W, back], [bx, back]],
           0.0, BOOTH_H, "Booth #{i + 1} — MDL 4872 E", t_booth)

      # EFS band behind each booth — what the silencer boxes need, not decoration
      flat(root, [[bx, back], [bx + BOOTH_W, back],
                  [bx + BOOTH_W, back + EFS], [bx, back + EFS]],
           "Booth #{i + 1} vent + EFS #{ft(EFS)}", t_efs)

      # Door swing. Hinged at the booth's left jamb, opening out into the room.
      hx = bx + ((BOOTH_W - DOOR_W) / 2.0)
      flat(root, [[hx, front - SWING], [hx + DOOR_W, front - SWING],
                  [hx + DOOR_W, front], [hx, front]],
           "Booth #{i + 1} door swing #{ft(SWING)}", t_swing)
      sw = root.entities.add_group
      sw.name  = "Booth #{i + 1} swing arc"
      sw.layer = t_swing
      sw.entities.add_arc(pt(hx, front, 0.3), Geom::Vector3d.new(1, 0, 0),
                          Geom::Vector3d.new(0, 0, -1), DOOR_W, 0.degrees, 90.degrees, 16)

      # The aisle between units — reach for the EFS box and the cable runs
      next if i == 2
      flat(root, [[bx + BOOTH_W, front], [bx + BOOTH_W + GAP, front],
                  [bx + BOOTH_W + GAP, back + EFS], [bx + BOOTH_W, back + EFS]],
           "access aisle #{ft(GAP)} — WORKING GAP, NOT AN ACOUSTIC FIGURE", t_aisle)
    end

    # Circulation left in front of the doors
    flat(root, [[0, 0], [ROOM_L, 0], [ROOM_L, front - SWING], [0, front - SWING]],
         "clear circulation #{ft(front - SWING)} deep", t_aisle, 0.1)

    e = root.entities
    dim(e, pt(0, 0), pt(ROOM_L, 0), Geom::Vector3d.new(0, -30, 0))
    dim(e, pt(0, 0), pt(0, ROOM_W), Geom::Vector3d.new(-30, 0, 0))
    dim(e, pt(x0, front), pt(x0 + BOOTH_W, front), Geom::Vector3d.new(0, -14, 0))
    dim(e, pt(x0 + BOOTH_W, front), pt(x0 + BOOTH_W + GAP, front), Geom::Vector3d.new(0, -14, 0))
    dim(e, pt(0, front), pt(0, back), Geom::Vector3d.new(-14, 0, 0))
    dim(e, pt(ROOM_L, back), pt(ROOM_L, ROOM_W), Geom::Vector3d.new(14, 0, 0))
    dim(e, pt(ROOM_L, 0), pt(ROOM_L, front - SWING), Geom::Vector3d.new(14, 0, 0))
    dim(e, pt(0, 0), pt(x0, 0), Geom::Vector3d.new(0, -46, 0))

    txt = root.entities.add_text(
      "Kuwait TV — 3 x MDL 4872 E in #{cm(ROOM_L)} x #{cm(ROOM_W)}, ceiling #{cm(ROOM_H)}\n" \
      "Room figures are the CLIENT'S OWN and he calls them approximate. Nothing measured on site.\n" \
      "The #{ft(GAP)} between booths is a WORKING AISLE, not an acoustic separation figure — " \
      "WhisperRoom publishes no booth-to-booth isolation number.",
      pt(4.0, -60.0, 1.0))
    txt.layer = t_note if txt

    model.commit_operation
    model.active_view.zoom_extents

    # ---- report ---------------------------------------------------------
    puts ''
    puts '=' * 76
    puts 'DOWALY / KUWAIT TV — three MDL 4872 E commentary booths'
    puts '=' * 76
    puts "  room     #{cm(ROOM_L)} x #{cm(ROOM_W)} x #{cm(ROOM_H)} high  " \
         "= #{ft(ROOM_L)} x #{ft(ROOM_W)} x #{ft(ROOM_H)}"
    puts "  booth    MDL 4872 E, #{ft(BOOTH_W)} x #{ft(BOOTH_D)}, needs #{ft(BOOTH_H)} to assemble"
    puts ''
    puts '  CEILING — normally the constraint that kills a job, not here:'
    puts "    #{ft(ROOM_H)} available vs #{ft(BOOTH_H)} needed  ->  #{ft(ROOM_H - BOOTH_H)} clear"
    puts ''
    puts '  ALONG THE 549 cm WALL'
    puts format('    3 booths at %s + 2 aisles at %s   = %s', ft(BOOTH_W), ft(GAP), ft(run))
    puts format('    room %s  ->  %s spare, %s at each end', ft(ROOM_L), ft(ROOM_L - run), ft(x0))
    puts ''
    puts '  ACROSS THE 450 cm WALL'
    puts format('    EFS %s + booth %s + door swing %s = %s',
                ft(EFS), ft(BOOTH_D), ft(SWING), ft(EFS + BOOTH_D + SWING))
    puts format('    room %s  ->  %s of clear circulation in front of the doors',
                ft(ROOM_W), ft(front - SWING))
    puts ''
    puts '  IT FITS, and not marginally. The row could take a wider aisle: at the'
    puts format('  drawn %s the run is %s in a %s wall.', ft(GAP), ft(run), ft(ROOM_L))
    puts format('  Widening the aisle to %s still fits (run %s).', ft(21.0), ft(3 * BOOTH_W + 42.0))
    puts ''
    puts '  *** THE SPACING IS THE CLIENT\'S MAIN QUESTION AND IT IS NOT ANSWERED HERE'
    puts '    Hosam wants acoustic separation between three commentators working'
    puts '    three live events at once. WhisperRoom publishes NO booth-to-booth'
    puts '    isolation figure. The 1" in the clearance table is an assembly gap.'
    puts format('    The %s drawn here is a WORKING AISLE — enough to reach the EFS', ft(GAP))
    puts '    boxes and the cable runs — and nothing more is claimed for it.'
    puts '    Engineering has to answer the separation question before this goes out.'
    puts '    Customer-facing acoustics: the website ASTM E336 dB range only.'
    puts ''
    puts '  DRAWN FROM THE SPEC'
    puts format('    vent + EFS   %s behind each booth   (layout-render.js: 10 w/ EFS)', ft(EFS))
    puts format('    door swing   %s in front of each      (frame under 46 in)', ft(SWING))
    puts '    doors all face into the room, hinged the same hand'
    puts ''
    puts '  NOT DRAWN — the client asked for these and they need Benton or engineering'
    puts '    cable entry points   AP is on the order; no position is specified'
    puts '    desk position        office desks are INSIDE, so they take no floor'
    puts '                         clearance here. Confirm they are not exterior-mounted,'
    puts '                         which would need 14 in per the same table.'
    puts '    which wall the vents actually sit on per booth'
    puts ''
    puts '  Room figures are the CLIENT\'S OWN and he calls them approximate.'
    puts '  Nothing here has been measured on site.'
    puts '=' * 76
    puts ''
  rescue StandardError => e
    model.abort_operation if model
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(8).map { |l| "  #{l}" }.join("\n")
  end
end

WR_Dowaly.build unless $wr_no_autorun
