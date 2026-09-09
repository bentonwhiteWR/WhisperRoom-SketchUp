# @title PeoplesSpace alcove (client, in progress)
# @tab client
# Build the PeoplesSpace booth alcove — MDL 96120 E + ADA, roof-mounted vent
#
#   Extensions > Developer > Ruby Console, then:
#     load "C:/Users/bento/Documents/Claude/Sketchup/scripts/peoplesspace-alcove.rb"
#
#   Ctrl+Z before re-running. The whole build is one undo operation.
#
# Imperial throughout. Model units are set to Architectural on build.
#
# ══════════════════════════════════════════════════════════════════════════
# THIS SCRIPT HAS NEVER BEEN RUN. There is no ruby.exe on the authoring
# machine and no live SketchUp bridge. It was syntax-checked with
# scripts/rbparse.py (real CRuby 3.2) and its geometry was cross-checked by
# .forge/builder/peoplesspace-check.py, but nothing has been executed in
# SketchUp. The build is wrapped so it aborts and prints one FAILED: line
# rather than leaving half a model.
# ══════════════════════════════════════════════════════════════════════════
#
# ─── WHAT IS MEASURED ─────────────────────────────────────────────────────
#   ROOM_W 114.75 (9'-6 3/4") and ROOM_D 128.75 (10'-8 3/4") — STATED on the
#     architect's partial plan, both carrying VIF. Transcribed, not scaled.
#   PIPE_Z 99.25, CLOUD_Z 113.0, STRUCT_Z 122.0 — STATED on the architect's
#     elevation, all VIF, measured from LEVEL 01 FF 0'-0".
#   Booth 98 x 122 x 84.3125 — models.json / wr-booth-data.rb / dimension-
#     booth.rb, observed.
#   Roof unit RM96120 88 x 113.5 x 10.3125 and its seating — wr-roof-vent.rb,
#     measured off the .skp.
#   Ramp projection 45.625 and swing clearance 34.5 — layout-render.js.
#
# ─── WHAT IS NOT MEASURED (the script prints this list again at the end) ──
#   ROOF_MOUNT_CONFIRMED = false. Benton, 9 Sep 2026: "Idk I thought we had
#     it." Roof-mounted ventilation is a CLIENT REQUEST, not a line on a
#     sales quote. CLAUDE.md: I draw what is on the quote. It is drawn here
#     and labelled UNCONFIRMED in the model and in the console.
#   The east side of the alcove — OPEN SPACE (Benton, 9 Sep 2026). No wall is
#     built there. Its extent is unknown; the fragment stops at the line.
#   The raised floor datum: z = 0 is taken as the TOP of the raised floor as
#     drawn on the elevation. A reading of a fragment, not a statement.
#   RAISED_FLOOR 2.75 is the WhisperRoom ADA raised floor — OURS, not the
#     building's (Benton, 9 Sep 2026). It sits INSIDE the shell, so it does
#     not lift the roof. See the HEIGHT STACK note below.
#   The pipe band: three pipes hugging the concrete wall, plan position and
#     diameter ESTIMATED off a pixel read of the elevation and the p.3 photo.
#     Drawn and labelled ESTIMATED on the drawing itself.
#   CLOUD_START 22.0 — pixel read of where the cloud stops short of the
#     concrete wall. Not dimensioned.
#   The west-wall grille box — pixel read, projection unknown.
#   Hinge sides — nobody has stated one. See HINGE below.
#   Ramp rise and slope — not in models.json, options.json or layout-
#     render.js. The plate is drawn flat at RAMP_T and is NOT a ramp profile.
#   Wall thicknesses — cosmetic. Walls are built OUTWARD from the measured
#     interior face and mitred, so thickness never moves a dimension.
#
# ─── THE HEIGHT STACK, AND WHY THE RAISED FLOOR IS NOT A BLOCKER ─────────
#   The WhisperRoom raised floor (EFP, part of the ADA package) is placed
#   INSIDE the shell: wr-overlays.rb place_efp seats the slab's bottom at
#   WR_Deck::DECK_TOP_Z (= 0.0), which is the plane the booth walls stand on
#   (wr-deck.rb). It therefore eats 2.75" of INTERIOR headroom and moves
#   nothing on the outside. The roof unit does NOT go up 2.75", and the
#   roof-unit-to-pipe margin is unchanged:
#
#     booth as drawn 84.3125 + unit 10.3125 = 94.6250 -> 4 5/8" under the pipe
#     catalogue 85.0 + unit 10.3125         = 95.3125 -> 3 15/16" under it
#     interior clear 79.5 - 2.75            = 76.7500  = 6'-4 3/4" headroom
#
#   Casters would change that (wr-overlays.rb CP_BOOTH_LIFT = 4.75 lifts the
#   WHOLE booth), and casters are payload 'cs' — not requested here. If the
#   quote ever carries casters, the unit tops out at 99.375 and hits the pipe.
#
# ─── THE RAMP DOES NOT RUN INWARD ────────────────────────────────────────
#   Benton, 9 Sep 2026: the ramp "goes inwards, on the left side to open up
#   against the glass wall". It cannot. The ramp run is perpendicular to the
#   door face and needs 45.625". Best case, with the booth shoved hard into a
#   corner, the alcove leaves 114.75 - 98 = 16.75" east and 128.75 - 122 =
#   6.75" north. Short by 28 7/8" east or 38 7/8" north. There is no
#   arrangement of a 98 x 122 booth inside a 114.75 x 128.75 alcove that
#   contains the ramp. RAMP_DIR is therefore :east and the script re-derives
#   and prints that arithmetic every run. East is OPEN SPACE (Benton's answer
#   1), so the ramp landing there is acceptable — the 29 7/8" overrun past
#   the alcove line stopped being a problem when east stopped being a wall.
#
# ─── HINGE ────────────────────────────────────────────────────────────────
#   ASSUMED, both options: hinge on the SOUTH jamb, leaf opens 90 degrees to
#   the south, so the clear approach along the ramp is from the NORTH — the
#   glass-wall side. That is the reading of "open up against the glass wall"
#   that a wheelchair approach makes sense under. Nobody has stated a hinge
#   side; flip HINGE_AT_SOUTH_JAMB if this is wrong.

module WR_PeoplesSpace

  # ─── room, STATED on the architect's plan (both VIF) ────────────────────
  ROOM_W = 114.75        # 9'-6 3/4"  west partition face -> east open line
  ROOM_D = 128.75        # 10'-8 3/4" south concrete face -> north glass line

  # ─── heights, STATED on the architect's elevation (all VIF) ────────────
  PIPE_Z    =  99.25     # 8'-3 1/4"  bottom of pipe — governs the roof unit
  CLOUD_Z   = 113.0      # 9'-5"      acoustic cloud ceiling, underside
  STRUCT_Z  = 122.0      # 10'-2"     concrete structure, underside

  # ─── booth, OBSERVED ───────────────────────────────────────────────────
  BOOTH_W   =  98.0      # 8'-2"  exterior, x  (models.json / wr-booth-data.rb)
  BOOTH_L   = 122.0      # 10'-2" exterior, y
  BOOTH_H   =  84.3125   # 7'-0 5/16" as drawn (dimension-booth.rb HEIGHTS)
  BOOTH_CAT =  85.0      # 7'-1" catalogue install clearance (models.json)
  INT_W     =  89.5      # eiw — Enhanced clear interior, x
  INT_L     = 113.5      # eih — Enhanced clear interior, y
  INT_H     =  79.5      # phi — Enhanced clear interior height
  RAISED_FL =   2.75     # WhisperRoom ADA raised floor, INSIDE the shell

  # ─── clearances, OBSERVED (WhisperRoomQuote assets/layout-render.js) ───
  GAP       =   1.0      # nominal clearance to a wall
  RAMP_PROT =  45.625    # 3'-9 5/8" ADA ramp projection off the door wall
  RAMP_W_HI =  46.0      # ramp width at the door
  RAMP_W_LO =  36.0      # ramp width at the foot
  RAMP_T    =   2.0      # FLAT PLATE. Rise and slope are unknown — not a ramp.
  SWING_CLR =  34.5      # swing clearance for a 49" frame
  FRAME_W   =  49.0      # wide-access / ADA door frame
  LEAF_W    =  32.0      # ADA leaf inside the 49" frame (options.json)

  # ─── roof unit RM96120, MEASURED off the .skp (wr-roof-vent.rb) ────────
  RM_X      =  88.0      # across the booth's 98 axis
  RM_Y      = 113.5      # along the booth's 122 axis
  RM_H      =  10.3125
  NOM_INSET =   1.0      # nominal footprint is 1" inboard of the exterior

  # ─── NOT MEASURED — estimates and assumptions, every one flagged ───────
  ROOF_MOUNT_CONFIRMED = false   # no sales quote carries rv=1. Benton, 9 Sep.
  HINGE_AT_SOUTH_JAMB  = true    # ASSUMED, see the header
  RAMP_DIR   = :east     # DERIVED — the inward ramp does not close, see header
  CLOUD_START = 22.0     # cloud stops this far north of the concrete — pixel read
  CLOUD_T     =  2.5     # cloud slab thickness — not dimensioned
  PIPE_D      =  5.5     # pipe diameter — ESTIMATED from the p.3 photo
  PIPE_CY     = [3.5, 10.5, 17.5].freeze   # ESTIMATED plan positions, y
  GRILLE      = { :x0 => 0.0, :x1 => 12.0, :y0 => 41.0, :y1 => 89.0,
                  :z0 => 103.7, :z1 => 115.7 }.freeze   # pixel read, +/-1.5"

  # ─── wall thicknesses — cosmetic, built outward, mitred ────────────────
  T_CONC  = 8.0          # south cast concrete wall
  T_PART  = 4.0          # west partition (CLAUDE.md default)
  T_GLASS = 2.0          # north storefront

  H_CONC  = STRUCT_Z     # the concrete wall reaches the structure on the elevation
  H_ROOM  = CLOUD_Z      # partition and storefront drawn to the cloud

  # ─── switches ──────────────────────────────────────────────────────────
  BUILD_OPT1    = true   # door at the SOUTH end (left as drawn — Benton, answer 4)
  BUILD_OPT2    = true   # door at the NORTH end (nearest the glass wall)
  BUILD_STRUCT  = true
  BUILD_ROOF_RM = true
  DRAW_DIMS     = true
  DRAW_SCENES   = true

  # ─── materials ─────────────────────────────────────────────────────────
  MAT_FLOOR = "0128_White"
  MAT_WALL  = "0099_LightSteelBlue"
  MAT_DOOR  = "0043_SaddleBrown"
  MAT_RGB   = {
    "0128_White"          => [255, 255, 255],
    "0099_LightSteelBlue" => [176, 196, 222],
    "0043_SaddleBrown"    => [139,  69,  19]
  }.freeze

  # ─── door options: near/far jamb on the booth's east face, y ───────────
  # Chains close on 128.75 — proved by .forge/builder/peoplesspace-check.py
  #   opt 1:  1 |  2 | 49 | 71 | 5.75
  #   opt 2:  1 | 71 | 49 |  2 | 5.75
  OPTIONS = {
    1 => { :j0 =>  3.0, :j1 =>  52.0, :label => "door SOUTH end (as drawn)" },
    2 => { :j0 => 72.0, :j1 => 121.0, :label => "door NORTH end (at the glass)" }
  }.freeze

  # booth exterior box, both options
  BX0 = GAP
  BY0 = GAP
  BX1 = BX0 + BOOTH_W        #  99.0 — the door face
  BY1 = BY0 + BOOTH_L        # 123.0

  # ═══════════════════════════════════════════════════════════════════════
  # helpers
  # ═══════════════════════════════════════════════════════════════════════
  def self.pt(x, y, z = 0.0)
    Geom::Point3d.new(x, y, z)
  end

  def self.tag(model, name, color = nil)
    layer = model.layers[name] || model.layers.add(name)
    (layer.color = color) if color
    layer
  end

  # Colors-Named .skm when it can be found, an identically-named colour if not.
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

  def self.plain(model, name, rgb, alpha = 1.0)
    m = model.materials[name]
    return m if m
    m = model.materials.add(name)
    m.color = Sketchup::Color.new(*rgb)
    m.alpha = alpha
    m
  end

  # A prism on a plan polygon: base at z, extruded up by h.
  def self.prism(parent, poly, z, h, name, layer = nil, mat = nil)
    return nil if h <= 0.001
    g = parent.entities.add_group
    f = g.entities.add_face(poly.map { |p| pt(p[0], p[1], z) })
    if f.nil?
      g.erase!
      return nil
    end
    f.reverse! if f.normal.z < 0
    f.pushpull(h)
    g.name    = name
    g.layer   = layer if layer
    g.material = mat  if mat
    g
  end

  def self.box(parent, x0, x1, y0, y1, z0, z1, name, layer = nil, mat = nil)
    prism(parent, [[x0, y0], [x1, y0], [x1, y1], [x0, y1]], z0, z1 - z0, name, layer, mat)
  end

  def self.note(parent, text, p, layer)
    t = parent.entities.add_text(text, p)
    (t.layer = layer) if t
    t
  rescue StandardError => e
    puts "  (note skipped: #{e.message})"
    nil
  end

  def self.dim(ents, a, b, off)
    return nil unless DRAW_DIMS
    d = ents.add_dimension_linear(a, b, off)
    (d.layer = @dim_layer) if d && @dim_layer
    d
  rescue StandardError => e
    puts "  (dimension skipped: #{e.message})"
    nil
  end

  def self.set_imperial(model)
    o = model.options["UnitsOptions"]
    o["LengthFormat"] = Length::Architectural
    o["LengthUnit"]   = Length::Inches
  rescue StandardError => e
    puts "  (couldn't set units: #{e.message} — set Model Info > Units to Architectural)"
  end

  # ═══════════════════════════════════════════════════════════════════════
  # the ramp arithmetic, re-derived every run so the model never outruns it
  # ═══════════════════════════════════════════════════════════════════════
  def self.ramp_inward_report
    free_x = ROOM_W - BOOTH_W          # 16.75, booth hard against a wall
    free_y = ROOM_D - BOOTH_L          #  6.75
    fits   = (free_x >= RAMP_PROT) || (free_y >= RAMP_PROT)
    { :free_x => free_x, :free_y => free_y, :fits => fits,
      :short_x => RAMP_PROT - free_x, :short_y => RAMP_PROT - free_y }
  end

  # ═══════════════════════════════════════════════════════════════════════
  # the room
  # ═══════════════════════════════════════════════════════════════════════
  def self.build_room(parent, tags, mats)
    # floor on the measured interior polygon
    f = prism(parent, [[0, 0], [ROOM_W, 0], [ROOM_W, ROOM_D], [0, ROOM_D]],
              -0.25, 0.25, "floor — 9'-6 3/4\" x 10'-8 3/4\" VIF", tags[:floor], mats[:floor])

    # SOUTH cast concrete wall, 8" outward from y = 0, mitred into the west
    # partition at the SW corner (the mitre line runs (0,0) -> (-T_PART,-T_CONC)).
    prism(parent,
          [[0, 0], [ROOM_W, 0], [ROOM_W, -T_CONC], [-T_PART, -T_CONC]],
          0.0, H_CONC, "SOUTH wall — cast concrete, to structure", tags[:room], mats[:wall])

    # WEST partition, 4" outward from x = 0, mitred at both ends.
    prism(parent,
          [[0, 0], [0, ROOM_D], [-T_PART, ROOM_D + T_GLASS], [-T_PART, -T_CONC]],
          0.0, H_ROOM, "WEST wall — partition (slat wall)", tags[:room], mats[:wall])

    # NORTH glass storefront, 2" outward from y = ROOM_D, mitred at the NW corner.
    prism(parent,
          [[0, ROOM_D], [ROOM_W, ROOM_D], [ROOM_W, ROOM_D + T_GLASS], [-T_PART, ROOM_D + T_GLASS]],
          0.0, H_ROOM, "NORTH wall — glass storefront", tags[:glass], mats[:glass])

    # EAST: NO WALL. A 1/4" floor strip marks the limit of the fragment.
    box(parent, ROOM_W - 1.0, ROOM_W, 0.0, ROOM_D, 0.0, 0.25,
        "EAST — OPEN, limit of the architect's fragment", tags[:notes], mats[:note])
    note(parent, "EAST SIDE IS OPEN SPACE (Benton, 9 Sep 2026).\n" \
                 "No wall here. The fragment stops at this line;\n" \
                 "what lies east of it is not dimensioned.",
         pt(ROOM_W + 6.0, ROOM_D / 2.0, 1.0), tags[:notes])

    # acoustic cloud — stops short of the concrete wall by an ESTIMATED 22"
    box(parent, 0.0, ROOM_W, CLOUD_START, ROOM_D, CLOUD_Z, CLOUD_Z + CLOUD_T,
        "ACOUSTIC CLOUD CEILING 9'-5\" VIF", tags[:ceiling], mats[:cloud])
    note(parent, "ACOUSTIC CLOUD 9'-5\" VIF (stated).\n" \
                 "Its 22\" setback off the concrete wall is a\n" \
                 "PIXEL READ of the elevation — ESTIMATED, +/-2\".",
         pt(4.0, CLOUD_START + 4.0, CLOUD_Z - 2.0), tags[:notes])

    if BUILD_STRUCT
      box(parent, -T_PART, ROOM_W, -T_CONC, ROOM_D + T_GLASS, STRUCT_Z, STRUCT_Z + 4.0,
          "CONCRETE STRUCTURE 10'-2\" VIF", tags[:ceiling], mats[:struct])
    end

    # pipes — three, running east-west along the concrete wall. Bottom of pipe
    # 8'-3 1/4" VIF is STATED; everything else about them is ESTIMATED.
    pipes = parent.entities.add_group
    pipes.name  = "PIPES — bottom 8'-3 1/4\" VIF (plan position ESTIMATED)"
    pipes.layer = tags[:obstr]
    r  = PIPE_D / 2.0
    cz = PIPE_Z + r
    PIPE_CY.each_with_index do |cy, i|
      g = pipes.entities.add_group
      edges = g.entities.add_circle(pt(-T_PART, cy, cz), Geom::Vector3d.new(1, 0, 0), r, 24)
      face  = g.entities.add_face(edges)
      if face
        d = face.normal.x > 0 ? (ROOM_W + T_PART) : -(ROOM_W + T_PART)
        face.pushpull(d)
      end
      g.name     = "pipe #{i + 1} — dia #{PIPE_D}\" ESTIMATED, y #{cy}\" ESTIMATED"
      g.material = mats[:grey]
    end
    note(parent, "PIPES — BOTTOM OF PIPE 8'-3 1/4\" VIF is STATED on the\n" \
                 "elevation and is the height that governs a roof-mounted\n" \
                 "booth. THEIR PLAN POSITION IS AN ESTIMATE: three pipes,\n" \
                 "dia ~5 1/2\", centres at 3 1/2\" / 10 1/2\" / 17 1/2\" off\n" \
                 "the concrete face, read off a photo and a pixel read of\n" \
                 "the elevation (+/-2\"). NOT dimensioned by the architect.",
         pt(ROOM_W + 6.0, 2.0, PIPE_Z + 12.0), tags[:notes])

    # west-wall grille — pixel read, projection unknown
    box(parent, GRILLE[:x0], GRILLE[:x1], GRILLE[:y0], GRILLE[:y1],
        GRILLE[:z0], GRILLE[:z1],
        "WEST WALL GRILLE — ESTIMATED (pixel read, projection unknown)",
        tags[:obstr], mats[:grey])

    # the raised floor is NOT modelled as a thickness — it is ours, inside the booth
    note(parent, "RAISED FLOOR: the band on the architect's elevation is the\n" \
                 "WHISPERROOM raised floor (ADA package) — 2 3/4\" above the\n" \
                 "normal WhisperRoom floor, INSIDE the shell (wr-overlays.rb\n" \
                 "seats the EFP slab on the booth's own deck top). It does NOT\n" \
                 "lift the booth or the roof unit; it costs 2 3/4\" of INTERIOR\n" \
                 "headroom: 79 1/2\" - 2 3/4\" = 76 3/4\" (6'-4 3/4\").\n" \
                 "z = 0 here is LEVEL 01 FF as drawn — ASSUMED to be the top of\n" \
                 "that floor. Not stated by the architect.",
         pt(4.0, 4.0, 1.0), tags[:notes])
    f
  end

  # ═══════════════════════════════════════════════════════════════════════
  # one booth option: shell, door, ramp, roof unit
  # ═══════════════════════════════════════════════════════════════════════
  def self.build_option(parent, n, tags, mats)
    o  = OPTIONS[n]
    j0 = o[:j0]
    j1 = o[:j1]
    cl = (j0 + j1) / 2.0

    g = parent.entities.add_group
    g.name  = "OPTION #{n} — MDL 96120 E + ADA, #{o[:label]}"
    g.layer = tags["opt#{n}".to_sym]

    # shell — PLACEHOLDER. No sales link, so this is the catalogue exterior,
    # not the built booth. booth-from-link.rb builds the real one.
    box(g, BX0, BX1, BY0, BY1, 0.0, BOOTH_H,
        "MDL 96120 E shell PLACEHOLDER 8'-2\" x 10'-2\" x 7'-0 5/16\"",
        tags["opt#{n}".to_sym], mats[:booth])

    # door frame on the east face + leaf open 90 degrees + swing arc
    box(g, BX1 - 1.0, BX1 + 1.0, j0, j1, 0.0, 80.0,
        "door frame #{FRAME_W}\" (ADA / wide access)", tags[:doors], mats[:door])

    hx = BX1
    hy = HINGE_AT_SOUTH_JAMB ? j0 : j1
    sy = HINGE_AT_SOUTH_JAMB ? 1.0 : -1.0     # closed leaf runs this way along y
    box(g, hx, hx + LEAF_W, hy - (sy > 0 ? 0.0 : 1.75), hy + (sy > 0 ? 1.75 : 0.0),
        0.0, 80.0, "door leaf #{LEAF_W}\" open 90deg — hinge #{HINGE_AT_SOUTH_JAMB ? 'SOUTH' : 'NORTH'} jamb (ASSUMED)",
        tags[:doors], mats[:door])
    begin
      g.entities.add_arc(pt(hx, hy, 0.25),
                         Geom::Vector3d.new(1, 0, 0),
                         Geom::Vector3d.new(0, 0, sy > 0 ? 1 : -1),
                         LEAF_W, 0.degrees, 90.degrees, 16)
    rescue StandardError => e
      puts "  (swing arc skipped: #{e.message})"
    end

    # ADA ramp — EAST, into the open space. See the header: inward does not close.
    ramp = [[BX1,             cl - RAMP_W_HI / 2.0],
            [BX1 + RAMP_PROT, cl - RAMP_W_LO / 2.0],
            [BX1 + RAMP_PROT, cl + RAMP_W_LO / 2.0],
            [BX1,             cl + RAMP_W_HI / 2.0]]
    prism(g, ramp, 0.0, RAMP_T,
          "ADA ramp 3'-9 5/8\" projection — FLAT PLATE, rise/slope UNKNOWN",
          tags["opt#{n}".to_sym], mats[:ramp])

    # roof unit — centred on the nominal footprint (wr-roof-vent.rb seat rule)
    if BUILD_ROOF_RM
      ux0 = BX0 + NOM_INSET + ((BOOTH_W - 2 * NOM_INSET) - RM_X) / 2.0
      uy0 = BY0 + NOM_INSET + ((BOOTH_L - 2 * NOM_INSET) - RM_Y) / 2.0
      box(g, ux0, ux0 + RM_X, uy0, uy0 + RM_Y, BOOTH_H, BOOTH_H + RM_H,
          "RM96120 roof unit — ROOF-MOUNT NOT CONFIRMED ON A QUOTE",
          tags[:roof], mats[:roof])
      note(g, "ROOF-MOUNTED VENTILATION — UNCONFIRMED.\n" \
              "Benton, 9 Sep 2026: \"Idk I thought we had it.\" This is a\n" \
              "client request, not a line on a sales quote. Drawn so the\n" \
              "height can be checked; get the quote link before it ships.\n" \
              "Unit top 7'-10 5/8\"; bottom of pipe 8'-3 1/4\" VIF;\n" \
              "MARGIN 4 5/8\" on the booth as drawn, 3 15/16\" on the\n" \
              "catalogue 7'-1\" install height.",
           pt(BX0 + 4.0, BY0 + 4.0, BOOTH_H + RM_H + 3.0), tags[:notes])
    end

    note(g, "OPTION #{n} — #{o[:label]}\n" \
            "Door centreline #{format('%.2f', cl)}\" off the concrete face.\n" \
            "Hinge SOUTH jamb, leaf opens south — ASSUMED, nobody stated it.\n" \
            "Ramp runs EAST into the open space; toe #{format('%.3f', BX1 + RAMP_PROT)}\",\n" \
            "which is 2'-5 7/8\" past the alcove line. The ramp CANNOT run\n" \
            "inward: it needs 45 5/8\" and the alcove leaves 16 3/4\".\n" \
            "Clear interior 89 1/2\" x 113 1/2\" (client asked for this).",
         pt(BX1 + 4.0, cl, 30.0), tags[:notes])
    g
  end

  # ═══════════════════════════════════════════════════════════════════════
  # dimensions — every in-line run on all four sides, chains that close
  # ═══════════════════════════════════════════════════════════════════════
  def self.build_dims(ents, tags)
    return unless DRAW_DIMS
    @dim_layer = tags[:dims]
    down  = Geom::Vector3d.new(0, -22, 0)
    down2 = Geom::Vector3d.new(0, -46, 0)
    left  = Geom::Vector3d.new(-22, 0, 0)
    left2 = Geom::Vector3d.new(-46, 0, 0)
    up    = Geom::Vector3d.new(0, 22, 0)
    right = Geom::Vector3d.new(60, 0, 0)

    # SOUTH — chain 1 | 98 | 15.75, overall 114.75 outside it
    dim(ents, pt(0, 0),    pt(BX0, 0),    down)
    dim(ents, pt(BX0, 0),  pt(BX1, 0),    down)
    dim(ents, pt(BX1, 0),  pt(ROOM_W, 0), down)
    dim(ents, pt(0, 0),    pt(ROOM_W, 0), down2)

    # WEST — chain 1 | 122 | 5.75, overall 128.75 outside it
    dim(ents, pt(0, 0),   pt(0, BY0),    left)
    dim(ents, pt(0, BY0), pt(0, BY1),    left)
    dim(ents, pt(0, BY1), pt(0, ROOM_D), left)
    dim(ents, pt(0, 0),   pt(0, ROOM_D), left2)

    # NORTH — overall only. DERIVED: the storefront is drawn parallel to the
    # dimensioned south wall; the architect dimensioned the width once.
    dim(ents, pt(0, ROOM_D), pt(ROOM_W, ROOM_D), up)

    # EAST (open) — the same 1 | 122 | 5.75 read on the open edge
    dim(ents, pt(ROOM_W, 0),   pt(ROOM_W, BY0),    right)
    dim(ents, pt(ROOM_W, BY0), pt(ROOM_W, BY1),    right)
    dim(ents, pt(ROOM_W, BY1), pt(ROOM_W, ROOM_D), right)

    # per-option door chains on the booth's door face, plus the ramp and swing
    OPTIONS.each do |n, o|
      next if n == 1 && !BUILD_OPT1
      next if n == 2 && !BUILD_OPT2
      off = Geom::Vector3d.new(70 + (n - 1) * 60, 0, 0)
      dim(ents, pt(BX1, 0),      pt(BX1, BY0),    off)
      dim(ents, pt(BX1, BY0),    pt(BX1, o[:j0]), off)
      dim(ents, pt(BX1, o[:j0]), pt(BX1, o[:j1]), off)   # the 49" frame
      dim(ents, pt(BX1, o[:j1]), pt(BX1, BY1),    off)
      dim(ents, pt(BX1, BY1),    pt(BX1, ROOM_D), off)
      # door centreline as a SEPARATE ordinate from the SW corner, never in the chain
      cl = (o[:j0] + o[:j1]) / 2.0
      dim(ents, pt(BX1 + 8.0, 0), pt(BX1 + 8.0, cl),
          Geom::Vector3d.new(0, 0, 40 + (n - 1) * 12))
      # ramp projection and swing clearance off the door face
      dim(ents, pt(BX1, cl), pt(BX1 + RAMP_PROT, cl),
          Geom::Vector3d.new(0, 26 + (n - 1) * 20, 0))
      dim(ents, pt(BX1, cl), pt(BX1 + SWING_CLR, cl),
          Geom::Vector3d.new(0, 40 + (n - 1) * 20, 0))
      # the overrun past the alcove line
      dim(ents, pt(ROOM_W, cl), pt(BX1 + RAMP_PROT, cl),
          Geom::Vector3d.new(0, 54 + (n - 1) * 20, 0))
    end

    # clear interior, on the plan — the client asked for it
    dim(ents, pt(BX0 + 4.25, BY0 + 4.25), pt(BX0 + 4.25 + INT_W, BY0 + 4.25),
        Geom::Vector3d.new(0, 10, 0))
    dim(ents, pt(BX0 + 4.25, BY0 + 4.25), pt(BX0 + 4.25, BY0 + 4.25 + INT_L),
        Geom::Vector3d.new(10, 0, 0))

    # ─── the height stack, dimensioned on a section line east of the room ──
    sx = ROOM_W + 40.0
    fwd = Geom::Vector3d.new(0, -14, 0)
    [[BOOTH_H,          "booth as drawn"],
     [BOOTH_H + RM_H,   "roof unit top"],
     [PIPE_Z,           "bottom of pipe VIF"],
     [CLOUD_Z,          "acoustic cloud VIF"],
     [STRUCT_Z,         "concrete structure VIF"]].each_with_index do |(z, _lbl), i|
      dim(ents, pt(sx + i * 10.0, 0, 0), pt(sx + i * 10.0, 0, z), fwd)
    end
    # the margin itself, called out on its own
    dim(ents, pt(sx + 52.0, 0, BOOTH_H + RM_H), pt(sx + 52.0, 0, PIPE_Z), fwd)
    note(ents.model,
         "HEIGHT STACK, z = 0 at LEVEL 01 FF (ASSUMED = top of the raised floor).\n" \
         "  booth as drawn      7'-0 5/16\"   (catalogue install height 7'-1\")\n" \
         "  + RM96120 roof unit 0'-10 5/16\"  -> top 7'-10 5/8\"\n" \
         "  BOTTOM OF PIPE      8'-3 1/4\" VIF -> MARGIN 4 5/8\" (3 15/16\" on 7'-1\")\n" \
         "  ACOUSTIC CLOUD      9'-5\"    VIF\n" \
         "  CONCRETE STRUCTURE 10'-2\"    VIF\n" \
         "  WhisperRoom raised floor 2 3/4\" is INSIDE the shell — it does not\n" \
         "  move the roof. Interior headroom 79 1/2\" - 2 3/4\" = 6'-4 3/4\".",
         pt(sx, -30.0, 40.0), tags[:notes])
  end

  # ═══════════════════════════════════════════════════════════════════════
  # scenes, named in proposal plate order
  # ═══════════════════════════════════════════════════════════════════════
  def self.scene(model, name, eye, target, opt_tags, hide, tags)
    [tags[:dims], tags[:notes]].each { |t| t.visible = true }
    opt_tags.each { |t, vis| t.visible = vis }
    hide.each { |t| t.visible = false }
    cam = model.active_view.camera
    if eye.nil?
      cam.perspective = false
      cam.set(pt(ROOM_W / 2.0, ROOM_D / 2.0, 400.0),
              pt(ROOM_W / 2.0, ROOM_D / 2.0, 0.0),
              Geom::Vector3d.new(0, 1, 0))
    else
      cam.perspective = true
      cam.set(eye, target, Geom::Vector3d.new(0, 0, 1))
    end
    page = model.pages.add(name)
    page
  rescue StandardError => e
    puts "  (scene #{name} skipped: #{e.message})"
    nil
  end

  def self.build_scenes(model, tags)
    return unless DRAW_SCENES
    ctr = pt(ROOM_W / 2.0, ROOM_D / 2.0, 42.0)
    [[1, tags[:opt1], tags[:opt2], BUILD_OPT1],
     [2, tags[:opt2], tags[:opt1], BUILD_OPT2]].each do |n, on, off, want|
      next unless want
      pair = { on => true, off => false }
      scene(model, "#{n}-01-exterior",
            pt(ROOM_W + 300.0, -160.0, 150.0), ctr, pair, [tags[:dims], tags[:notes]], tags)
      scene(model, "#{n}-02-dimensioned",
            pt(ROOM_W + 300.0, -200.0, 120.0), ctr, pair, [], tags)
      scene(model, "#{n}-03-side",
            pt(ROOM_W + 460.0, ROOM_D / 2.0, 46.0), ctr, pair, [tags[:dims]], tags)
      scene(model, "#{n}-04-ventilation",
            pt(ROOM_W + 240.0, ROOM_D + 260.0, 230.0), ctr, pair, [tags[:dims]], tags)
      scene(model, "#{n}-05-plan", nil, nil, pair, [], tags)
    end
    tags[:opt1].visible = true if BUILD_OPT1
    tags[:opt2].visible = false
  end

  # ═══════════════════════════════════════════════════════════════════════
  def self.build
    model = Sketchup.active_model
    set_imperial(model)
    model.start_operation("PeoplesSpace alcove", true)

    tags = {
      :room    => tag(model, "WR-Room",       Sketchup::Color.new(120, 128, 140)),
      :floor   => tag(model, "WR-Floor",      Sketchup::Color.new(200, 200, 200)),
      :glass   => tag(model, "WR-Glass",      Sketchup::Color.new(150, 190, 220)),
      :ceiling => tag(model, "WR-Ceiling",    Sketchup::Color.new(210, 210, 214)),
      :obstr   => tag(model, "WR-Obstruction", Sketchup::Color.new(110, 110, 116)),
      :doors   => tag(model, "WR-Doors",      Sketchup::Color.new(64, 102, 124)),
      :roof    => tag(model, "WR-RoofVent",   Sketchup::Color.new(90, 90, 96)),
      :notes   => tag(model, "WR-Notes",      Sketchup::Color.new(30, 30, 30)),
      :dims    => tag(model, "WR-Dims",       Sketchup::Color.new(238, 98, 22)),
      :opt1    => tag(model, "WR-Booth-Opt1", Sketchup::Color.new(238, 98, 22)),
      :opt2    => tag(model, "WR-Booth-Opt2", Sketchup::Color.new(238, 140, 60))
    }

    mats = {
      :floor  => material(model, MAT_FLOOR),
      :wall   => material(model, MAT_WALL),
      :door   => material(model, MAT_DOOR),
      :glass  => plain(model, "WR Glass storefront", [200, 225, 245], 0.35),
      :cloud  => plain(model, "WR Acoustic cloud",   [245, 245, 245], 0.60),
      :struct => plain(model, "WR Concrete structure", [150, 150, 150], 0.45),
      :grey   => plain(model, "WR Obstruction grey", [130, 130, 136], 1.0),
      :booth  => plain(model, "WR Booth placeholder", [225, 225, 228], 1.0),
      :ramp   => plain(model, "WR Ramp placeholder",  [238, 98, 22], 1.0),
      :roof   => plain(model, "WR Roof unit",         [110, 110, 118], 1.0),
      :note   => plain(model, "WR Open edge",         [238, 98, 22], 1.0)
    }

    room = model.entities.add_group
    room.name = "PEOPLESSPACE ALCOVE — 9'-6 3/4\" x 10'-8 3/4\" VIF"
    build_room(room, tags, mats)

    build_option(model.entities.add_group, 1, tags, mats) if BUILD_OPT1
    build_option(model.entities.add_group, 2, tags, mats) if BUILD_OPT2

    build_dims(model.entities, tags)

    model.commit_operation
    build_scenes(model, tags)
    model.active_view.zoom_extents

    report
  rescue StandardError => e
    begin
      model.abort_operation if model
    rescue StandardError
      nil
    end
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(8)
    nil
  end

  # ═══════════════════════════════════════════════════════════════════════
  # the console report — everything in the model that is not a measured number
  # ═══════════════════════════════════════════════════════════════════════
  def self.report
    r = ramp_inward_report
    puts ""
    puts "PEOPLESSPACE ALCOVE — built. Architectural units, everything on WR-* tags."
    puts "  Alcove 9'-6 3/4\" x 10'-8 3/4\" VIF, interior faces. East side OPEN — no wall."
    puts "  Walls built OUTWARD from the measured faces and mitred: concrete #{T_CONC}\","
    puts "  partition #{T_PART}\", storefront #{T_GLASS}\". Thickness is cosmetic."
    puts ""
    puts "  ROOF UNIT TO PIPE (the number that decides this job):"
    puts format("    booth as drawn %.4f + RM96120 %.4f = %.4f -> MARGIN %.4f in (4 5/8\")",
                BOOTH_H, RM_H, BOOTH_H + RM_H, PIPE_Z - BOOTH_H - RM_H)
    puts format("    catalogue      %.4f + RM96120 %.4f = %.4f -> MARGIN %.4f in (3 15/16\")",
                BOOTH_CAT, RM_H, BOOTH_CAT + RM_H, PIPE_Z - BOOTH_CAT - RM_H)
    puts "    The 2 3/4\" WhisperRoom raised floor is INSIDE the shell (wr-overlays.rb"
    puts "    seats the EFP on the booth deck top), so it does NOT reduce this margin."
    puts format("    It costs interior headroom instead: %.2f - %.2f = %.2f in (6'-4 3/4\").",
                INT_H, RAISED_FL, INT_H - RAISED_FL)
    puts "    CASTERS WOULD BREAK IT: wr-overlays CP_BOOTH_LIFT 4.75 lifts the whole"
    puts "    booth, putting the unit at 99.375 against a 99.25 pipe. Not requested."
    puts ""
    puts "  RAMP — Benton asked for it to run INWARD. IT DOES NOT CLOSE:"
    puts format("    needs %.3f; alcove leaves %.3f east and %.3f north with the booth",
                RAMP_PROT, r[:free_x], r[:free_y])
    puts format("    hard into a corner. Short by %.3f east / %.3f north.",
                r[:short_x], r[:short_y])
    puts "    Drawn running EAST into the open space instead — toe at"
    puts format("    %.3f in, %.3f in past the alcove line. East is open, so this is",
                BX1 + RAMP_PROT, BX1 + RAMP_PROT - ROOM_W)
    puts "    the only arrangement that installs. CONFIRM IT."
    puts ""
    puts "  NOT MEASURED — every one of these is in the model and labelled there:"
    puts "    1. ROOF-MOUNT IS NOT ON A SALES QUOTE. Client request only"
    puts "       (Benton, 9 Sep 2026). Drawn, labelled UNCONFIRMED. Get the link."
    puts "    2. The booth is a PLACEHOLDER BOX at the catalogue exterior, not a"
    puts "       built booth. Run booth-from-link.rb with a sales link for the real one."
    puts "    3. z = 0 is LEVEL 01 FF taken as the TOP of the raised floor — a"
    puts "       reading of the elevation, not a statement by the architect."
    puts "    4. Pipe plan position and diameter — ESTIMATED (photo + pixel read,"
    puts "       +/-2\"). Only BOTTOM OF PIPE 8'-3 1/4\" VIF is stated."
    puts "    5. The cloud's 22\" setback off the concrete wall — pixel read."
    puts "    6. The west-wall grille box — pixel read, projection unknown."
    puts "    7. Hinge side — ASSUMED SOUTH jamb in both options. Nobody stated one."
    puts "    8. Ramp rise and slope — UNKNOWN. The plate is flat, not a ramp."
    puts "    9. The north (glass) run and the east open edge are DERIVED from the"
    puts "       south and west chains; the architect dimensioned each once."
    puts "   10. Wall thicknesses — cosmetic, built outward, never move a dimension."
    puts "   11. What lies east of the alcove line — open space, extent unknown."
    puts ""
    puts "  Chains close: south 1 + 98 + 15.75 = 114.75; west 1 + 122 + 5.75 = 128.75;"
    puts "  door opt 1  1 + 2 + 49 + 71 + 5.75 = 128.75; opt 2  1 + 71 + 49 + 2 + 5.75."
    puts ""
    puts "  THIS SCRIPT WAS NEVER RUN BEFORE YOU RAN IT. Syntax-checked only."
    puts ""
    true
  end
end

WR_PeoplesSpace.build
