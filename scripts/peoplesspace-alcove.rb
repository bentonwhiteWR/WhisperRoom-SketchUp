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
# ─── THE PALETTE IS DELIBERATELY NOT THE DRAWING PALETTE ──────────────────
#   CLAUDE.md's working-drawing palette is floor 0128_White, walls
#   0099_LightSteelBlue, doors 0043_SaddleBrown. This model does not use it.
#   Benton, 9 Sep 2026: "Change the material color too to better match this
#   photo." His call, for this client model, because it is going to render.
#   The room's colours are MEDIAN RGB SAMPLES off the real site photo
#   (SITE_RGB below names the pixel box each one came from). The booth keeps
#   its own materials. SITE_MATERIALS = false restores the drawing palette.
#
# ─── THE CONTEXT AROUND THE ALCOVE IS INVENTED ────────────────────────────
#   Benton, 9 Sep 2026: "build the outside area a bit around it to better
#   reflect the entire room." Everything beyond the alcove — the floor
#   running east, the elevator, the glazed room behind the storefront, the
#   mullions, the deck, the pipes past the alcove line — is INVENTED for a
#   render. None of it is in the architect's fragment. It is all on the
#   WR-Context-INVENTED tag so it switches off in one click, and no
#   dimension touches it. The measured alcove did not move.
#
# ─── WHERE THE EXPLANATION LIVES ──────────────────────────────────────────
#   Benton, 9 Sep 2026, on the first build's in-model text: "this is what the
#   text looks like whenever you include it. Not ideal, not sure we even need
#   all that text anyways?" He was right twice. The paragraph notes are gone.
#
#   The model now carries SHORT LABELS ONLY — a VIF mark on a stated datum, an
#   EST mark on an estimated one, the east-limit marker, the unconfirmed
#   roof-mount — all on the WR-Notes tag, which is OFF by default (the same
#   pattern as WR Lights) and sized from the room via LABEL_H rather than from
#   Model Info. The explanation — height stack, headroom, the caster warning,
#   the handedness conflict, the eleven-item estimated list — is in the report
#   HtmlDialog the build opens, and in the console puts for anyone at the Ruby
#   Console. If a label cannot be read at a glance it is the wrong tool.
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

  # ─── SITE PALETTE — sampled off the real photo, NOT the drawing palette ─
  #
  # Benton, 9 Sep 2026: "Change the material color too to better match this
  # photo." This deliberately overrides CLAUDE.md's working-drawing palette
  # (floor 0128_White, walls 0099_LightSteelBlue) for THIS client model,
  # because it is going to render rather than be read as a working drawing.
  # His call, and it applies to the room only — the booth keeps its own
  # materials. Set SITE_MATERIALS = false to get the drawing palette back.
  #
  # Every value below is the MEDIAN RGB of a named pixel box in
  # scratchpad/peoples/site-photo-materials.png, not a colour from memory.
  # The photo is not colour-calibrated: its lighting is baked into these
  # numbers, so they are a starting point for a lookdev pass, not a spec.
  SITE_MATERIALS = true
  SITE_RGB = {
    # name                        sampled box in the photo        median
    "WR Site Concrete"    => [132, 128, 116],  # x2-28  y95-190   board-formed wall
    "WR Site Corrugated"  => [175, 151,  57],  # x100-168 y155-205 olive metal wall
    "WR Site Ceiling"     => [156, 139, 108],  # x120-220 y2-40    perforated deck
    "WR Site Floor"       => [ 87,  82,  82],  # x2-70  y258-288   dark polished floor
    "WR Site Mullion"     => [ 92,  89,  82],  # x205-224 y95-215  storefront mullion
    "WR Site Glass"       => [ 92,  90,  80],  # x190-222 y120-200 through the glass
    "WR Site Pipe"        => [ 64,  58,  52],  # x30-95 y10-45     exposed pipework
    "WR Site Panel"       => [215, 214, 217]   # x105-150 y75-92   white grille / unit
  }.freeze

  # ─── CONTEXT — INVENTED. Nothing out here is measured. ─────────────────
  #
  # Benton, 9 Sep 2026: "build the outside area a bit around it to better
  # reflect the entire room." Context for a render, not a survey. It all goes
  # on WR-Context-INVENTED so it switches off in one click and so nobody
  # mistakes it for a take-off. The measured alcove does not move.
  #
  # Compass, DERIVED from the two reference images and agreeing with the
  # take-off: the viewer in both stands EAST looking WEST, so the image's
  # LEFT is SOUTH (concrete wall, elevator beyond it), its RIGHT is NORTH
  # (glass storefront with a door, and the room behind it), and the back
  # wall is WEST (the olive corrugated partition).
  BUILD_CONTEXT = true
  CTX_E   = 240.0    # how far east the open area is carried  — INVENTED
  CTX_N   = 144.0    # depth of the glazed room beyond the storefront — INVENTED
  EV_W    =  84.0    # elevator opening width  — INVENTED
  EV_OFF  =  72.0    # its near jamb, east of the alcove line — INVENTED
  EV_DEEP =  30.0    # shaft depth behind the wall — INVENTED
  MULL_SP =  48.0    # storefront mullion spacing — INVENTED, and >= the 34"
                     # the spec allows; the real spacing is not dimensioned
  GDOOR_W =  36.0    # glass door leaf in the storefront — INVENTED

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

  # A SHORT label, laid flat in the XY plane so it reads on a plan scene.
  #
  # Sketchup::Text has no font-size API — its size comes from Model Info and
  # rendered an order of magnitude too large for a room this size (Benton's
  # screenshot, 9 Sep 2026). add_3d_text takes a letter height in MODEL UNITS,
  # so the size is derived from the room instead of set by a global. Anything
  # that will not fit in a few words does not belong in the model at all: it
  # goes in the report dialog.
  LABEL_H = ROOM_W / 64.0        # ~1 3/4" against a 9'-6 3/4" room

  def self.label(parent, text, x, y, z, layer)
    g = parent.entities.add_group
    ok = g.entities.add_3d_text(text, TextAlignLeft, "Arial", true, false,
                                LABEL_H, 0.0, 0.0, true, 0.0)
    if !ok || g.entities.length.zero?
      g.erase!
      return nil
    end
    g.transformation = Geom::Transformation.translation(Geom::Vector3d.new(x, y, z))
    g.name  = "label: #{text}"
    g.layer = layer
    g
  rescue StandardError => e
    puts "  (label skipped: #{e.message})"
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
          0.0, H_CONC, "SOUTH wall — cast concrete, to structure", tags[:room], mats[:concrete])

    # WEST partition, 4" outward from x = 0, mitred at both ends.
    prism(parent,
          [[0, 0], [0, ROOM_D], [-T_PART, ROOM_D + T_GLASS], [-T_PART, -T_CONC]],
          0.0, H_ROOM, "WEST wall — olive corrugated partition", tags[:room], mats[:olive])

    # NORTH glass storefront, 2" outward from y = ROOM_D, mitred at the NW corner.
    prism(parent,
          [[0, ROOM_D], [ROOM_W, ROOM_D], [ROOM_W, ROOM_D + T_GLASS], [-T_PART, ROOM_D + T_GLASS]],
          0.0, H_ROOM, "NORTH wall — glass storefront", tags[:glass], mats[:glass])

    # EAST: NO WALL. A 1/4" floor strip marks the limit of the fragment.
    box(parent, ROOM_W - 1.0, ROOM_W, 0.0, ROOM_D, 0.0, 0.25,
        "EAST — OPEN, limit of the architect's fragment", tags[:notes], mats[:note])
    label(parent, "OPEN - LIMIT OF FRAGMENT", ROOM_W + 3.0, ROOM_D / 2.0, 0.5, tags[:notes])

    # acoustic cloud — stops short of the concrete wall by an ESTIMATED 22"
    box(parent, 0.0, ROOM_W, CLOUD_START, ROOM_D, CLOUD_Z, CLOUD_Z + CLOUD_T,
        "ACOUSTIC CLOUD CEILING 9'-5\" VIF", tags[:ceiling], mats[:cloud])
    label(parent, "CLOUD 9'-5\" VIF - SETBACK EST",
          4.0, CLOUD_START + 3.0, CLOUD_Z - 0.5, tags[:notes])

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
    label(parent, "PIPE 8'-3 1/4\" VIF - PLAN EST", 4.0, 1.0, PIPE_Z - 2.0, tags[:notes])

    # west-wall grille — pixel read, projection unknown
    box(parent, GRILLE[:x0], GRILLE[:x1], GRILLE[:y0], GRILLE[:y1],
        GRILLE[:z0], GRILLE[:z1],
        "WEST WALL GRILLE — ESTIMATED (pixel read, projection unknown)",
        tags[:obstr], mats[:grey])
    label(parent, "GRILLE EST", GRILLE[:x1] + 2.0, GRILLE[:y0], GRILLE[:z0] - 2.0, tags[:notes])

    # The raised floor is NOT modelled as a thickness — it is ours, inside the
    # booth. The whole argument lives in the report dialog, not on the drawing.
    label(parent, "z=0 = LEVEL 01 FF (ASSUMED)", 4.0, 3.0, 0.5, tags[:notes])
    f
  end

  # ═══════════════════════════════════════════════════════════════════════
  # CONTEXT — everything here is INVENTED
  #
  # Enough of the room beyond the alcove for a render to read as a real
  # place: the floor carrying on east, the concrete wall continuing with the
  # elevator recess in it, the storefront continuing with a glass door and a
  # room behind it, mullions, the deck overhead and the pipes running on.
  # None of it is in the architect's fragment and none of it is measured.
  # It all lands on WR-Context-INVENTED. The measured alcove is untouched.
  # ═══════════════════════════════════════════════════════════════════════
  def self.build_context(parent, tags, mats)
    t  = tags[:ctx]
    ex = ROOM_W + CTX_E                 # east limit of the context
    ny = ROOM_D + CTX_N                 # north limit (back of the glazed room)

    # floor east of the alcove, and the floor of the room behind the glass
    box(parent, ROOM_W, ex, -T_CONC, ny, -0.25, 0.0,
        "CONTEXT floor — open area east (INVENTED)", t, mats[:floor])
    box(parent, -T_PART, ROOM_W, ROOM_D + T_GLASS, ny, -0.25, 0.0,
        "CONTEXT floor — room behind the storefront (INVENTED)", t, mats[:floor])

    # the concrete wall carries on east, with the elevator recess in it
    ev0 = ROOM_W + EV_OFF
    ev1 = ev0 + EV_W
    box(parent, ROOM_W, ev0, -T_CONC, 0.0, 0.0, H_CONC,
        "CONTEXT south wall, west of the elevator (INVENTED)", t, mats[:concrete])
    box(parent, ev1, ex, -T_CONC, 0.0, 0.0, H_CONC,
        "CONTEXT south wall, east of the elevator (INVENTED)", t, mats[:concrete])
    box(parent, ev0, ev1, -T_CONC, 0.0, 96.0, H_CONC,
        "CONTEXT elevator header (INVENTED)", t, mats[:concrete])
    box(parent, ev0 - 6.0, ev1 + 6.0, -T_CONC - EV_DEEP, -T_CONC, 0.0, H_CONC,
        "CONTEXT elevator shaft (INVENTED)", t, mats[:concrete])
    box(parent, ev0 + 2.0, ev1 - 2.0, -T_CONC - 1.0, -T_CONC, 0.0, 90.0,
        "CONTEXT elevator doors (INVENTED)", t, mats[:mullion])

    # the storefront carries on east, with a glass door in it
    gd0 = ROOM_W + 36.0
    gd1 = gd0 + GDOOR_W
    box(parent, ROOM_W, gd0, ROOM_D, ROOM_D + T_GLASS, 0.0, H_ROOM,
        "CONTEXT storefront, west of the door (INVENTED)", t, mats[:glass])
    box(parent, gd1, ex, ROOM_D, ROOM_D + T_GLASS, 0.0, H_ROOM,
        "CONTEXT storefront, east of the door (INVENTED)", t, mats[:glass])
    box(parent, gd0, gd1, ROOM_D, ROOM_D + T_GLASS, 84.0, H_ROOM,
        "CONTEXT storefront transom over the door (INVENTED)", t, mats[:glass])
    box(parent, gd0, gd1, ROOM_D, ROOM_D + T_GLASS, 0.0, 84.0,
        "CONTEXT glass door leaf (INVENTED)", t, mats[:glass])

    # mullions along the whole storefront line — spacing INVENTED, not
    # dimensioned anywhere; kept at MULL_SP so it never reads as measured
    x = 0.0
    while x <= ex - MULL_SP
      box(parent, x, x + 2.0, ROOM_D - 0.5, ROOM_D + T_GLASS + 0.5, 0.0, H_ROOM,
          "CONTEXT mullion (INVENTED spacing)", t, mats[:mullion])
      x += MULL_SP
    end
    box(parent, 0.0, ex, ROOM_D - 0.5, ROOM_D + T_GLASS + 0.5, H_ROOM - 3.0, H_ROOM,
        "CONTEXT storefront head rail (INVENTED)", t, mats[:mullion])

    # back wall of the room behind the storefront
    box(parent, -T_PART, ex, ny, ny + T_PART, 0.0, H_ROOM,
        "CONTEXT back wall of the glazed room (INVENTED)", t, mats[:panel])

    # the perforated deck overhead, over everything the alcove slab misses
    box(parent, ROOM_W, ex, -T_CONC, ny, STRUCT_Z, STRUCT_Z + 4.0,
        "CONTEXT deck over the open area (INVENTED)", t, mats[:struct])
    box(parent, -T_PART, ROOM_W, ROOM_D + T_GLASS, ny, STRUCT_Z, STRUCT_Z + 4.0,
        "CONTEXT deck over the glazed room (INVENTED)", t, mats[:struct])

    # the pipes run on east — same centres and diameter, all still ESTIMATED
    r  = PIPE_D / 2.0
    cz = PIPE_Z + r
    PIPE_CY.each_with_index do |cy, i|
      g = parent.entities.add_group
      edges = g.entities.add_circle(pt(ROOM_W, cy, cz), Geom::Vector3d.new(1, 0, 0), r, 16)
      face  = g.entities.add_face(edges)
      if face
        d = face.normal.x > 0 ? CTX_E : -CTX_E
        face.pushpull(d)
      end
      g.name     = "CONTEXT pipe #{i + 1} carried east (INVENTED)"
      g.layer    = t
      g.material = mats[:grey]
    end

    label(parent, "CONTEXT - INVENTED, NOT MEASURED",
          ROOM_W + 12.0, -T_CONC - 12.0, 0.5, tags[:notes])
    nil
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
      label(g, "ROOF MOUNT - UNCONFIRMED",
            BX0 + 3.0, BY0 + 3.0, BOOTH_H + RM_H + 1.0, tags[:notes])
    end

    # Short labels only. The option's full argument — hinge, ramp direction and
    # the inward-ramp arithmetic — is in the report dialog.
    label(g, "OPT #{n} - HINGE #{HINGE_AT_SOUTH_JAMB ? 'S' : 'N'} (ASSUMED)",
          BX1 + 2.0, cl + (RAMP_W_HI / 2.0) + 2.0, 0.5, tags[:notes])
    label(g, "RAMP EAST - RISE UNKNOWN",
          BX1 + 2.0, cl - (RAMP_W_HI / 2.0) - LABEL_H - 2.0, 0.5, tags[:notes])
    label(g, "BOOTH PLACEHOLDER",
          BX0 + 3.0, BY1 - LABEL_H - 3.0, BOOTH_H + 0.5, tags[:notes])
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
    # One terse mark per stated height datum, set clear of the chains. The
    # stack itself, and why the raised floor does not move it, is in the dialog.
    m = ents.model
    label(m, "PIPE VIF",   sx +  4.0, -20.0, PIPE_Z,          tags[:notes])
    label(m, "CLOUD VIF",  sx + 14.0, -20.0, CLOUD_Z,         tags[:notes])
    label(m, "STRUCT VIF", sx + 24.0, -20.0, STRUCT_Z,        tags[:notes])
    label(m, "MARGIN 4 5/8\"", sx + 54.0, -20.0, BOOTH_H + RM_H, tags[:notes])
  end

  # ═══════════════════════════════════════════════════════════════════════
  # scenes, named in proposal plate order
  # ═══════════════════════════════════════════════════════════════════════
  # WR-Notes stays OFF in every scene — the same pattern as the WR Lights tag.
  # The labels are there for whoever switches the tag on; the model opens clean.
  def self.scene(model, name, eye, target, opt_tags, hide, tags)
    tags[:dims].visible  = true
    tags[:notes].visible = false
    tags[:ctx].visible   = true
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
      # the dimensioned and plan scenes drop the invented context, so a plate
      # made from either shows only what was measured
      scene(model, "#{n}-02-dimensioned",
            pt(ROOM_W + 300.0, -200.0, 120.0), ctr, pair, [tags[:ctx]], tags)
      scene(model, "#{n}-03-side",
            pt(ROOM_W + 460.0, ROOM_D / 2.0, 46.0), ctr, pair, [tags[:dims]], tags)
      scene(model, "#{n}-04-ventilation",
            pt(ROOM_W + 240.0, ROOM_D + 260.0, 230.0), ctr, pair, [tags[:dims]], tags)
      scene(model, "#{n}-05-plan", nil, nil, pair, [tags[:ctx]], tags)
    end
    tags[:opt1].visible  = true if BUILD_OPT1
    tags[:opt2].visible  = false
    tags[:notes].visible = false
    tags[:ctx].visible   = true
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
      :opt2    => tag(model, "WR-Booth-Opt2", Sketchup::Color.new(238, 140, 60)),
      :ctx     => tag(model, "WR-Context-INVENTED", Sketchup::Color.new(170, 120, 90))
    }
    # OFF by default, like the WR Lights tag. Every remaining text entity lives
    # here, so the model opens with nothing but geometry and dimensions.
    tags[:notes].visible = false

    mats = if SITE_MATERIALS
             # Sampled off the site photo. Named so they read sensibly in V-Ray.
             {
               :floor    => plain(model, "WR Site Floor",      SITE_RGB["WR Site Floor"], 1.0),
               :wall     => plain(model, "WR Site Concrete",   SITE_RGB["WR Site Concrete"], 1.0),
               :concrete => plain(model, "WR Site Concrete",   SITE_RGB["WR Site Concrete"], 1.0),
               :olive    => plain(model, "WR Site Corrugated", SITE_RGB["WR Site Corrugated"], 1.0),
               :mullion  => plain(model, "WR Site Mullion",    SITE_RGB["WR Site Mullion"], 1.0),
               :panel    => plain(model, "WR Site Panel",      SITE_RGB["WR Site Panel"], 1.0),
               :door     => material(model, MAT_DOOR),
               :glass    => plain(model, "WR Site Glass",      SITE_RGB["WR Site Glass"], 0.30),
               :cloud    => plain(model, "WR Site Ceiling",    SITE_RGB["WR Site Ceiling"], 1.0),
               :struct   => plain(model, "WR Site Ceiling deck", SITE_RGB["WR Site Ceiling"], 1.0),
               :grey     => plain(model, "WR Site Pipe",       SITE_RGB["WR Site Pipe"], 1.0)
             }
           else
             {
               :floor    => material(model, MAT_FLOOR),
               :wall     => material(model, MAT_WALL),
               :concrete => material(model, MAT_WALL),
               :olive    => material(model, MAT_WALL),
               :mullion  => plain(model, "WR Mullion", [120, 120, 126], 1.0),
               :panel    => plain(model, "WR Panel white", [235, 235, 238], 1.0),
               :door     => material(model, MAT_DOOR),
               :glass    => plain(model, "WR Glass storefront", [200, 225, 245], 0.35),
               :cloud    => plain(model, "WR Acoustic cloud",   [245, 245, 245], 0.60),
               :struct   => plain(model, "WR Concrete structure", [150, 150, 150], 0.45),
               :grey     => plain(model, "WR Obstruction grey", [130, 130, 136], 1.0)
             }
           end
    # The booth keeps its own materials in either palette — only the room
    # changes (Benton, 9 Sep 2026).
    mats.merge!(
      :booth  => plain(model, "WR Booth placeholder", [225, 225, 228], 1.0),
      :ramp   => plain(model, "WR Ramp placeholder",  [238, 98, 22], 1.0),
      :roof   => plain(model, "WR Roof unit",         [110, 110, 118], 1.0),
      :note   => plain(model, "WR Open edge",         [238, 98, 22], 1.0)
    )

    room = model.entities.add_group
    room.name = "PEOPLESSPACE ALCOVE — 9'-6 3/4\" x 10'-8 3/4\" VIF"
    build_room(room, tags, mats)

    if BUILD_CONTEXT
      ctx = model.entities.add_group
      ctx.name  = "CONTEXT — INVENTED, NOT MEASURED"
      ctx.layer = tags[:ctx]
      build_context(ctx, tags, mats)
    end

    build_option(model.entities.add_group, 1, tags, mats) if BUILD_OPT1
    build_option(model.entities.add_group, 2, tags, mats) if BUILD_OPT2

    build_dims(model.entities, tags)

    model.commit_operation
    build_scenes(model, tags)
    model.active_view.zoom_extents

    report
    show_report(model, tags)
    true
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
    puts "   12. EVERYTHING ON WR-Context-INVENTED. The open area east, the elevator,"
    puts "       the glazed room behind the storefront, the mullions, the deck and the"
    puts "       pipes past the alcove line are all INVENTED for the render. Switch"
    puts "       the tag off and what is left is the measured alcove."
    puts "   13. The room's colours are median RGB samples off the site photo, which"
    puts "       is not colour-calibrated — its lighting is baked in. A starting point"
    puts "       for a lookdev pass, not a spec. This palette deliberately replaces"
    puts "       CLAUDE.md's working-drawing palette; Benton's call, 9 Sep 2026."
    puts ""
    puts "  Chains close: south 1 + 98 + 15.75 = 114.75; west 1 + 122 + 5.75 = 128.75;"
    puts "  door opt 1  1 + 2 + 49 + 71 + 5.75 = 128.75; opt 2  1 + 71 + 49 + 2 + 5.75."
    puts ""
    puts "  The same material is in the report window this build opens. Short labels"
    puts "  live in the model on the WR-Notes tag, OFF by default — switch it on from"
    puts "  that window or from the Tags panel."
    puts ""
    puts "  THIS SCRIPT WAS NEVER RUN BEFORE YOU RAN IT. Syntax-checked only."
    puts ""
    true
  end

  # ═══════════════════════════════════════════════════════════════════════
  # THE REPORT DIALOG — the primary surface
  #
  # Everything that used to sprawl across the model as 3D paragraphs lives
  # here: the height stack, the headroom arithmetic, the caster warning, the
  # handedness conflict and the eleven-item estimated/VIF list. The console
  # puts above still carries the same material for anyone at the Ruby
  # Console. The buttons do the next step rather than just closing.
  # ═══════════════════════════════════════════════════════════════════════
  def self.show_report(model, tags)
    d = UI::HtmlDialog.new(
      :dialog_title    => 'PeoplesSpace alcove — what is measured and what is not',
      :preferences_key => 'com.whisperroom.peoplesspace',
      :scrollable      => true,
      :resizable       => true,
      :width           => 700,
      :height          => 640,
      :min_width       => 460,
      :min_height      => 360,
      :style           => UI::HtmlDialog::STYLE_DIALOG
    )
    d.set_html(report_html)

    d.add_action_callback('opt') do |_c, n|
      tags[:opt1].visible = (n.to_i == 1)
      tags[:opt2].visible = (n.to_i == 2)
      model.active_view.zoom_extents
    end
    d.add_action_callback('labels') do |_c, on|
      tags[:notes].visible = (on.to_s == 'true')
    end
    d.add_action_callback('dims') do |_c, on|
      tags[:dims].visible = (on.to_s == 'true')
    end
    d.add_action_callback('ctx') do |_c, on|
      tags[:ctx].visible = (on.to_s == 'true')
    end
    d.add_action_callback('close') { |_c| d.close }
    d.show
    d
  rescue StandardError => e
    puts "  (report dialog unavailable: #{e.class}: #{e.message} — the console"
    puts "   report above carries the same material)"
    nil
  end

  def self.report_html
    r = ramp_inward_report
    margin_drawn = PIPE_Z - BOOTH_H - RM_H
    margin_cat   = PIPE_Z - BOOTH_CAT - RM_H
    headroom     = INT_H - RAISED_FL
    <<-HTML
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>PeoplesSpace alcove</title>
<style>
  :root { --bg:#f4f5f6; --surface:#fff; --ink:#1c2327; --muted:#66727a;
          --line:#e2e6e9; --accent:#ee6216; --soft:#fdeee4; --bad:#b0402c; }
  * { box-sizing:border-box; margin:0; }
  html,body { height:100%; }
  body { font:13px/1.5 "Segoe UI",system-ui,sans-serif; background:var(--bg);
         color:var(--ink); display:flex; flex-direction:column; overflow:hidden; }
  .top { padding:12px 16px 8px; display:flex; gap:8px; align-items:center;
         flex-wrap:wrap; border-bottom:1px solid var(--line); background:var(--surface); }
  .top .t { font-weight:650; margin-right:auto; }
  .btn { font:inherit; font-size:12px; padding:5px 11px; border:1px solid var(--line);
         border-radius:6px; background:var(--surface); color:var(--ink); cursor:pointer; }
  .btn:hover { border-color:var(--accent); }
  .btn.on { background:var(--accent); border-color:var(--accent); color:#fff; }
  .wrap { flex:1 1 auto; overflow:auto; padding:14px 16px 18px; }
  h2 { font-size:12px; letter-spacing:.09em; text-transform:uppercase;
       color:var(--muted); margin:18px 0 7px; }
  h2:first-child { margin-top:0; }
  .card { background:var(--surface); border:1px solid var(--line); border-radius:9px;
          padding:11px 13px; }
  .card + .card { margin-top:8px; }
  .card.flag { border-color:#e3b3a4; background:#fdf6f4; }
  .hd { font-weight:650; }
  .hd .n { color:var(--accent); }
  table { border-collapse:collapse; width:100%; font-variant-numeric:tabular-nums; }
  td { padding:3px 8px 3px 0; vertical-align:top; }
  td.v { text-align:right; white-space:nowrap; font-weight:650; }
  ol { margin:0; padding-left:20px; }
  ol li { margin:4px 0; }
  .m { color:var(--muted); }
  .foot { padding:9px 16px; border-top:1px solid var(--line); background:var(--surface);
          color:var(--muted); font-size:11.5px; }
</style></head><body>

<div class="top">
  <span class="t">PeoplesSpace alcove &mdash; MDL 96120 E + ADA</span>
  <button class="btn" id="o1">Show option 1</button>
  <button class="btn" id="o2">Show option 2</button>
  <button class="btn on" id="cx">Context on</button>
  <button class="btn" id="lb">Labels off</button>
  <button class="btn on" id="dm">Dimensions on</button>
  <button class="btn" id="cl">Close</button>
</div>

<div class="wrap">

<h2>The number that decides this job</h2>
<div class="card">
  <div class="hd">Roof unit to bottom of pipe: <span class="n">#{fmt_in(margin_drawn)}</span>
    on the booth as drawn, <span class="n">#{fmt_in(margin_cat)}</span> on the catalogue
    7'-1" install height.</div>
  <table>
    <tr><td>booth as drawn + RM96120 roof unit</td>
        <td class="v">#{fmt_in(BOOTH_H)} + #{fmt_in(RM_H)} = #{fmt_in(BOOTH_H + RM_H)}</td></tr>
    <tr><td>bottom of pipe <span class="m">(stated, VIF)</span></td>
        <td class="v">#{fmt_in(PIPE_Z)}</td></tr>
    <tr><td>acoustic cloud <span class="m">(stated, VIF)</span></td>
        <td class="v">#{fmt_in(CLOUD_Z)}</td></tr>
    <tr><td>concrete structure <span class="m">(stated, VIF)</span></td>
        <td class="v">#{fmt_in(STRUCT_Z)}</td></tr>
  </table>
</div>
<div class="card">
  <div class="hd">The 2&nbsp;3/4" raised floor does not touch that margin.</div>
  <p class="m">The band on the architect's elevation is the WhisperRoom ADA raised floor,
  not the building's. <code>wr-overlays.rb place_efp</code> seats the EFP slab's bottom at
  <code>WR_Deck::DECK_TOP_Z</code> (0.0) &mdash; the plane the booth walls stand on. It is
  INSIDE the shell, so the roof unit does not rise. What it costs is interior headroom:
  #{fmt_in(INT_H)} &minus; #{fmt_in(RAISED_FL)} = <b>#{fmt_in(headroom)}</b>.</p>
</div>
<div class="card flag">
  <div class="hd">Casters would break it.</div>
  <p class="m"><code>wr-overlays.rb CP_BOOTH_LIFT</code> = 4.75 lifts the WHOLE booth
  group, which would put the unit top at 99.375 against a 99.25 pipe. Casters are payload
  <code>cs</code> and are not on this job &mdash; but if a quote ever carries them, this
  layout stops fitting.</p>
</div>

<h2>The ramp cannot run inward</h2>
<div class="card flag">
  <p>The ramp run is perpendicular to the door face and needs #{fmt_in(RAMP_PROT)}. With
  the booth shoved hard into a corner the alcove leaves <b>#{fmt_in(r[:free_x])}</b> east
  and <b>#{fmt_in(r[:free_y])}</b> north &mdash; short by #{fmt_in(r[:short_x])} /
  #{fmt_in(r[:short_y])}. There is no arrangement of a 98 &times; 122 booth inside
  114.75 &times; 128.75 that contains it.</p>
  <p class="m">Drawn running EAST into the open space instead: toe at
  #{fmt_in(BX1 + RAMP_PROT)}, which is #{fmt_in(BX1 + RAMP_PROT - ROOM_W)} past the alcove
  line. That is only acceptable because east is open space. Confirm it.</p>
</div>
<div class="card flag">
  <div class="hd">Handedness conflict, unresolved.</div>
  <p class="m">"South = left" points at option 1 (door at the south end); "opens against
  the glass wall" points at option 2 (door at the north end). Both are built, on
  WR-Booth-Opt1 and WR-Booth-Opt2. Pick one.</p>
</div>

<h2>Context and colour</h2>
<div class="card flag">
  <div class="hd">Everything beyond the alcove is INVENTED.</div>
  <p class="m">The floor running east, the elevator, the glazed room behind the storefront,
  the mullions, the deck overhead and the pipes past the alcove line are context for a
  render, not a take-off. They are all on <b>WR-Context-INVENTED</b> &mdash; the button
  above switches them off, and the dimensioned and plan scenes already drop them. The
  measured alcove did not move and no dimension changed.</p>
</div>
<div class="card">
  <div class="hd">Compass, and how it maps onto the photos.</div>
  <p class="m">In both reference images the viewer stands EAST looking WEST, so the
  image's LEFT is SOUTH &mdash; the board-formed concrete wall, with the elevator beyond
  it &mdash; its RIGHT is NORTH, the glass storefront with a door and the room behind it,
  and the back wall is WEST, the olive corrugated partition. That agrees with the
  take-off's compass; nothing had to be reinterpreted.</p>
</div>
<div class="card">
  <div class="hd">Room palette &mdash; sampled, not remembered.</div>
  <p class="m">Median RGB of a named pixel box in the site photo. It deliberately replaces
  CLAUDE.md's working-drawing palette for this model (Benton's call) because this one
  renders. The photo is not colour-calibrated, so its lighting is baked into these
  numbers: treat them as the start of a lookdev pass. The booth keeps its own materials.</p>
  <table>
    <tr><td>WR Site Concrete <span class="m">board-formed wall</span></td><td class="v">#848074</td></tr>
    <tr><td>WR Site Corrugated <span class="m">olive metal wall</span></td><td class="v">#AF9739</td></tr>
    <tr><td>WR Site Ceiling <span class="m">perforated deck</span></td><td class="v">#9C8B6C</td></tr>
    <tr><td>WR Site Floor <span class="m">dark polished floor</span></td><td class="v">#575252</td></tr>
    <tr><td>WR Site Mullion <span class="m">storefront framing</span></td><td class="v">#5C5952</td></tr>
    <tr><td>WR Site Glass <span class="m">through the glazing</span></td><td class="v">#5C5A50</td></tr>
    <tr><td>WR Site Pipe <span class="m">exposed pipework</span></td><td class="v">#403A34</td></tr>
    <tr><td>WR Site Panel <span class="m">white grille / unit</span></td><td class="v">#D7D6D9</td></tr>
  </table>
</div>

<h2>Everything in this model that is not a measured number</h2>
<div class="card">
<ol>
  <li><b>Roof-mount is not on a sales quote.</b> Client request only. Drawn and labelled
      UNCONFIRMED. Get the <code>sales.whisperroom.com/q/W-…</code> link before it ships.</li>
  <li><b>The booth is a placeholder box</b> at the catalogue exterior, not a built booth.
      Run <code>booth-from-link.rb</code> with a sales link for the real one.</li>
  <li><b>z = 0 is LEVEL 01 FF taken as the top of the raised floor</b> &mdash; a reading of
      the elevation, not a statement by the architect.</li>
  <li><b>Pipe plan position and diameter are ESTIMATED</b> (photo + pixel read, &plusmn;2").
      Only BOTTOM OF PIPE 8'-3 1/4" VIF is stated.</li>
  <li><b>The cloud's 22" setback</b> off the concrete wall is a pixel read.</li>
  <li><b>The west-wall grille box</b> is a pixel read; its projection is unknown.</li>
  <li><b>Hinge side is ASSUMED</b> &mdash; south jamb in both options. Nobody stated one.</li>
  <li><b>Ramp rise and slope are unknown.</b> The plate is flat and is not a ramp profile.</li>
  <li><b>The north (glass) run and the east open edge are DERIVED</b> from the south and
      west chains; the architect dimensioned each once.</li>
  <li><b>Wall thicknesses are cosmetic</b> &mdash; built outward from the measured faces
      and mitred, so they never move a dimension.</li>
  <li><b>What lies east of the alcove line</b> is open space of unknown extent.</li>
  <li><b>Everything on WR-Context-INVENTED.</b> The open area east, the elevator, the
      glazed room behind the storefront, the mullions, the deck and the pipes past the
      alcove line are context for a render, not a take-off. Switch the tag off and what
      is left is the measured alcove.</li>
  <li><b>The room's colours</b> are median RGB samples off the site photo, which is not
      colour-calibrated &mdash; its lighting is baked in. A starting point for a lookdev
      pass, not a spec.</li>
</ol>
</div>

<h2>Chains close</h2>
<div class="card">
  <table>
    <tr><td>south</td><td class="v">1 + 98 + 15.75 = 114.75</td></tr>
    <tr><td>west</td><td class="v">1 + 122 + 5.75 = 128.75</td></tr>
    <tr><td>door, option 1</td><td class="v">1 + 2 + 49 + 71 + 5.75 = 128.75</td></tr>
    <tr><td>door, option 2</td><td class="v">1 + 71 + 49 + 2 + 5.75 = 128.75</td></tr>
  </table>
</div>

</div>
<div class="foot">Labels live on the WR-Notes tag, off by default. This window changes tag
visibility only &mdash; it does not touch geometry, and nothing here is undoable because
nothing here is a model edit.</div>

<script>
(function () {
  var lb = document.getElementById('lb'), dm = document.getElementById('dm');
  var cx = document.getElementById('cx');
  var labels = false, dims = true, ctx = true;
  function call(n, a) { if (window.sketchup && sketchup[n]) sketchup[n](a); }
  document.getElementById('o1').onclick = function () { call('opt', 1); };
  document.getElementById('o2').onclick = function () { call('opt', 2); };
  lb.onclick = function () {
    labels = !labels;
    lb.textContent = labels ? 'Labels on' : 'Labels off';
    lb.className = 'btn' + (labels ? ' on' : '');
    call('labels', labels);
  };
  dm.onclick = function () {
    dims = !dims;
    dm.textContent = dims ? 'Dimensions on' : 'Dimensions off';
    dm.className = 'btn' + (dims ? ' on' : '');
    call('dims', dims);
  };
  cx.onclick = function () {
    ctx = !ctx;
    cx.textContent = ctx ? 'Context on' : 'Context off';
    cx.className = 'btn' + (ctx ? ' on' : '');
    call('ctx', ctx);
  };
  document.getElementById('cl').onclick = function () { call('close'); };
}());
</script>
</body></html>
    HTML
  end

  # Inches -> an architectural string, for the dialog only. The model's own
  # dimensions are formatted by SketchUp at full precision.
  def self.fmt_in(v)
    neg = v < 0
    v = v.abs
    ft = (v / 12.0).floor
    rem = v - (ft * 12)
    inch = rem.floor
    frac = ((rem - inch) * 16.0).round
    if frac == 16
      inch += 1
      frac = 0
    end
    if inch == 12
      ft += 1
      inch = 0
    end
    s = "#{ft}'-#{inch}"
    if frac > 0
      n = frac
      dd = 16
      while (n % 2).zero?
        n /= 2
        dd /= 2
      end
      s += " #{n}/#{dd}"
    end
    (neg ? "-" : "") + s + "\""
  end
end

WR_PeoplesSpace.build
