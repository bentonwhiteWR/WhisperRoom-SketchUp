# @title FVRL podcast booth — alcove fit plan...
# @tab client
# @cat Draw the room
# @icon mono:FV
#
# fvrl-podcast-alcove.rb — the Fort Vancouver Regional Library podcast booth
# alcove, with the MDL 96120 E footprint and its REQUIRED CLEARANCES drawn as
# real geometry so the fit question answers itself on the page.
#
#   Extensions > Developer > Ruby Console, then:
#     load "C:/Users/bento/Documents/Claude/Sketchup/scripts/fvrl-podcast-alcove.rb"
#
# Ctrl+Z before re-running. Booth shell is NOT drawn — only its footprint, so
# the real booth can be dropped straight onto it.
#
# ===========================================================================
# THE JOB
#
# PeopleSpace (Peter Harrison) asked, through Sarah: "is there anything else we
# should consider re external components? We'd want to ensure 100% it can fit
# prior to order." This plan is the answer to that, and the answer turns
# entirely on WHICH WALLS carry the door and the vents.
#
# ===========================================================================
# SOURCES — every number here is traceable, none is estimated off a drawing
#
# BOOTH        models.json, the canonical catalogue: MDL 96120 Enhanced is
#              8'-2" x 10'-2" x 7'-1"  ->  98" x 122" footprint, 85" of
#              install clearance. The Standard and the Enhanced have the SAME
#              98 x 122 footprint; only the height differs (83 vs 85).
#
# CLEARANCES   WhisperRoomQuote/assets/layout-render.js:1064, which is the rule
#              the quote tool's own renderer uses, quoted verbatim:
#                 "door swing 23.5/29.5/34.5, the ADA ramp 45.625 on the
#                  WA-door wall, a vent 6 (10 w/ EFS), else the recommended 1"
#                  gap"
#              This order has the ADA package, VSS and EFS, so the numbers that
#              apply are 45.625" at the door wall and 10" at each vent wall.
#
# THE SPACE    the architect's plan (photo3): 10'-8 3/4" VIF = 128.75".
#              Peter's own email says 10'-7 1/2" = 127.5" "at the longest
#              point". THOSE TWO DISAGREE BY 1 1/4", and the drawing is marked
#              VIF — verify in field — by the architect. 128.75 is used here
#              because it is the drawn figure; 127.5 is drawn as a second
#              limit line so both are visible.
#
# CEILING      the architect's own levels: bottom of pipe 8'-3 1/4" VIF =
#              99.25". The booth needs 85". Ceiling is NOT the constraint here,
#              which is worth saying out loud because it usually is.
#
# ===========================================================================
# WHAT IS NOT KNOWN, AND IT IS THE IMPORTANT ONE
#
# THE ALCOVE'S SECOND DIMENSION HAS NEVER BEEN GIVEN. Sarah asked for it
# directly — "What's the other dimension of your space?" — and the reply gave
# only the one figure again. The 9'-6 3/4" on the architect's plan is on the
# opening BELOW the alcove, not across it.
#
# So this plan draws the alcove OPEN on its width: the two side walls run the
# measured depth and stop, and the width is drawn at the minimum the booth
# needs. It is not a room. Anyone reading it can see the question rather than
# a number somebody made up.
#
module WR_FVRL

  # ─── parameters ────────────────────────────────────────────────────────
  BOOTH_W   = 98.0     # 8'-2"  across the alcove
  BOOTH_L   = 122.0    # 10'-2" into the alcove
  BOOTH_H   = 85.0     # 7'-1"  Enhanced install clearance

  DEPTH_ARCH  = 128.75 # 10'-8 3/4" VIF — the architect's plan
  DEPTH_EMAIL = 127.50 # 10'-7 1/2"     — Peter's email. They disagree.
  PIPE_H      = 99.25  # 8'-3 1/4" VIF, bottom of pipe

  NOMINAL = 1.0        # recommended gap at a plain wall
  EFS     = 10.0       # vent wall WITH exterior fan silencers
  RAMP    = 45.625     # ADA ramp, replaces the door swing figure

  # WHICH WALL CARRIES WHAT. This is the whole question, so it is a switch.
  # :back and :front are the ends of the 122" run; :left and :right the sides.
  # front = the open side of the alcove.
  DOOR_SIDE  = :front            # where the ADA ramp projects
  VENT_SIDES = [:left].freeze    # walls carrying vents + EFS

  WALL_T = 6.0         # the alcove walls are drawn 6" thick, cosmetic only

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

  def self.flat(parent, corners, name, layer)
    g = parent.entities.add_group
    f = g.entities.add_face(corners.map { |p| pt(p[0], p[1], 0.25) })
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
    neg = v < 0
    v = v.abs
    f = (v / 12.0).floor
    r = v - (f * 12.0)
    s = format("%d'-%s\"", f, (r == r.round ? r.round.to_s : format('%.3f', r).sub(/0+$/, '')))
    neg ? "-#{s}" : s
  end

  # Clearance demanded on one side, from the rule in layout-render.js.
  def self.clear_for(side)
    return RAMP if side == DOOR_SIDE
    return EFS  if VENT_SIDES.include?(side)
    NOMINAL
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
    model.start_operation('FVRL podcast booth alcove', true)

    t_floor = tag(model, 'WR-FVRL-Alcove',     [200, 200, 200])
    t_wall  = tag(model, 'WR-FVRL-Walls',      [120, 128, 140])
    t_booth = tag(model, 'WR-FVRL-Booth-Foot', [ 90,  96, 104])
    t_clr   = tag(model, 'WR-FVRL-Clearance',  [238,  98,  22])
    t_limit = tag(model, 'WR-FVRL-LIMIT',      [220,  40,  40])
    t_note  = tag(model, 'WR-FVRL-Notes',      [200,  60,  60])

    cb = clear_for(:back)
    cf = clear_for(:front)
    cl = clear_for(:left)
    cr = clear_for(:right)

    need_depth = BOOTH_L + cb + cf
    need_width = BOOTH_W + cl + cr

    # Origin = inside back-left corner of the alcove. +X across, +Y into depth
    # reversed: y = 0 at the BACK wall, y grows toward the open front.
    bx = cl                       # booth's left edge
    by = cb                       # booth's back edge

    root = model.entities.add_group
    root.name  = 'FVRL podcast booth — alcove fit plan'
    root.layer = t_floor

    # Alcove floor, drawn only as far as the booth + its clearances demand.
    # The width is NOT a measured room dimension — see the header.
    f = quad(root, [[0, 0], [need_width, 0], [need_width, DEPTH_ARCH], [0, DEPTH_ARCH]],
             0.0, 0.0, 'alcove floor (width NOT measured)', t_floor)
    f.material = material(model, MAT_FLOOR) if f

    # Back wall and the two returns. The front is left OPEN on purpose.
    w1 = quad(root, [[-WALL_T, -WALL_T], [need_width + WALL_T, -WALL_T],
                     [need_width + WALL_T, 0], [-WALL_T, 0]], 0.0, PIPE_H, 'back wall', t_wall)
    w2 = quad(root, [[-WALL_T, 0], [0, 0], [0, DEPTH_ARCH], [-WALL_T, DEPTH_ARCH]],
              0.0, PIPE_H, 'left wall', t_wall)
    w3 = quad(root, [[need_width, 0], [need_width + WALL_T, 0],
                     [need_width + WALL_T, DEPTH_ARCH], [need_width, DEPTH_ARCH]],
              0.0, PIPE_H, 'right wall', t_wall)
    [w1, w2, w3].each { |g| g.material = material(model, MAT_WALL) if g }

    # The booth FOOTPRINT only — the real booth drops onto this.
    quad(root, [[bx, by], [bx + BOOTH_W, by],
                [bx + BOOTH_W, by + BOOTH_L], [bx, by + BOOTH_L]],
         0.0, 0.0, "MDL 96120 E footprint #{ft(BOOTH_W)} x #{ft(BOOTH_L)}", t_booth)

    # Each clearance band as its own flat patch, named with what demands it.
    # Drawn separately rather than as one ring so a reader can see WHICH side
    # is eating the space, which is the whole point of the drawing.
    label = lambda do |side, c|
      return "ADA ramp #{ft(c)}"     if side == DOOR_SIDE
      return "vent + EFS #{ft(c)}"   if VENT_SIDES.include?(side)
      "nominal #{ft(c)}"
    end
    flat(root, [[bx, by - cb], [bx + BOOTH_W, by - cb], [bx + BOOTH_W, by], [bx, by]],
         "BACK  #{label.call(:back, cb)}", t_clr)
    flat(root, [[bx, by + BOOTH_L], [bx + BOOTH_W, by + BOOTH_L],
                [bx + BOOTH_W, by + BOOTH_L + cf], [bx, by + BOOTH_L + cf]],
         "FRONT #{label.call(:front, cf)}", t_clr)
    flat(root, [[bx - cl, by], [bx, by], [bx, by + BOOTH_L], [bx - cl, by + BOOTH_L]],
         "LEFT  #{label.call(:left, cl)}", t_clr)
    flat(root, [[bx + BOOTH_W, by], [bx + BOOTH_W + cr, by],
                [bx + BOOTH_W + cr, by + BOOTH_L], [bx + BOOTH_W, by + BOOTH_L]],
         "RIGHT #{label.call(:right, cr)}", t_clr)

    # The two competing depth limits, drawn so the 1 1/4" disagreement is
    # visible instead of buried in an email.
    lim = root.entities.add_group
    lim.name  = 'DEPTH LIMITS — architect vs email'
    lim.layer = t_limit
    lim.entities.add_edges(pt(-WALL_T, DEPTH_ARCH), pt(need_width + WALL_T, DEPTH_ARCH))
    lim.entities.add_edges(pt(-WALL_T, DEPTH_EMAIL), pt(need_width + WALL_T, DEPTH_EMAIL))

    e = root.entities
    dim(e, pt(0, 0), pt(0, DEPTH_ARCH), Geom::Vector3d.new(-WALL_T - 26, 0, 0))
    dim(e, pt(bx, by), pt(bx, by + BOOTH_L), Geom::Vector3d.new(-WALL_T - 10, 0, 0))
    dim(e, pt(bx, by + BOOTH_L), pt(bx, DEPTH_ARCH), Geom::Vector3d.new(-WALL_T - 10, 0, 0))
    dim(e, pt(bx, by), pt(bx + BOOTH_W, by), Geom::Vector3d.new(0, -26, 0))
    dim(e, pt(0, by), pt(need_width, by), Geom::Vector3d.new(0, -42, 0))

    slack = DEPTH_ARCH - need_depth
    txt = root.entities.add_text(
      "FVRL podcast booth — MDL 96120 E fit study\n" \
      "Booth #{ft(BOOTH_W)} x #{ft(BOOTH_L)} footprint. Clearances per the quote tool: " \
      "ADA ramp #{ft(RAMP)}, vent+EFS #{ft(EFS)}, plain wall #{ft(NOMINAL)}.\n" \
      "Depth needed #{ft(need_depth)} against #{ft(DEPTH_ARCH)} VIF — " \
      "#{slack >= 0 ? "#{ft(slack)} spare" : "OVER BY #{ft(-slack)}"}.\n" \
      "ALCOVE WIDTH IS NOT A MEASURED DIMENSION. It has never been supplied.",
      pt(4.0, DEPTH_ARCH + 30.0, 1.0))
    txt.layer = t_note if txt

    model.commit_operation
    model.active_view.zoom_extents

    # ---- the report -----------------------------------------------------
    puts ''
    puts '=' * 76
    puts 'FVRL PODCAST BOOTH — MDL 96120 E — ALCOVE FIT'
    puts '=' * 76
    puts "  booth footprint   #{ft(BOOTH_W)} x #{ft(BOOTH_L)}   (models.json, Enhanced)"
    puts "  install height    #{ft(BOOTH_H)}"
    puts ''
    puts '  CLEARANCE AS CONFIGURED — layout-render.js:1064 is the authority'
    puts format('    back   %-16s %s', ft(cb), label.call(:back, cb))
    puts format('    front  %-16s %s', ft(cf), label.call(:front, cf))
    puts format('    left   %-16s %s', ft(cl), label.call(:left, cl))
    puts format('    right  %-16s %s', ft(cr), label.call(:right, cr))
    puts ''
    puts "  DEPTH   needs #{ft(need_depth)}   available #{ft(DEPTH_ARCH)} VIF (architect)"
    puts "          #{slack >= 0 ? "FITS with #{ft(slack)} to spare" : "DOES NOT FIT — over by #{ft(-slack)}"}"
    puts "          Peter's email says #{ft(DEPTH_EMAIL)}, which is #{ft(DEPTH_ARCH - DEPTH_EMAIL)} less."
    puts "          Both limits are drawn. The drawing is marked VIF by the architect."
    puts "  WIDTH   needs #{ft(need_width)}   available UNKNOWN — never supplied"
    puts ''
    puts '  CEILING IS NOT THE PROBLEM, for once:'
    puts "    bottom of pipe #{ft(PIPE_H)} VIF against #{ft(BOOTH_H)} needed — " \
         "#{ft(PIPE_H - BOOTH_H)} clear."
    puts ''
    puts '  WHAT DECIDES THIS — the ramp, and it cannot go in the alcove:'
    puts format('    booth + ADA ramp on a 10\'-2" end   %s   vs %s available  -> NO',
                ft(BOOTH_L + RAMP + NOMINAL), ft(DEPTH_ARCH))
    puts format('    booth + ADA ramp on an 8\'-2" side  %s   vs width unknown -> almost certainly NO',
                ft(BOOTH_W + RAMP + NOMINAL))
    puts '    So the door wall MUST face the open side of the alcove and the'
    puts '    ramp must run out into the room. Anything else does not fit.'
    puts ''
    puts '  AND THE VENT WALLS:'
    puts format('    booth + EFS on both 10\'-2" ends    %s   vs %s available  -> NO',
                ft(BOOTH_L + EFS + EFS), ft(DEPTH_ARCH))
    puts format('    booth + EFS on one end             %s   vs %s available  -> %s',
                ft(BOOTH_L + EFS + NOMINAL), ft(DEPTH_ARCH),
                (BOOTH_L + EFS + NOMINAL) <= DEPTH_ARCH ? 'yes' : 'NO')
    puts '    The EFS boxes stick out 10". Put them on a SIDE, not on an end,'
    puts '    or the depth is gone.'
    puts ''
    puts '  QUESTIONS FOR PETER — the first one blocks the order:'
    puts '    1. THE ALCOVE WIDTH. Sarah asked once and it was not answered.'
    puts '       Without it nobody can say this fits, only that the depth works.'
    puts '    2. 10\'-8 3/4" on the architect\'s plan vs 10\'-7 1/2" in your email.'
    puts '       Which is right? Both are marked VIF. At 4 3/4" of slack that'
    puts '       difference is a quarter of the margin.'
    puts '    3. Confirm the ramp runs OUT of the alcove into the room. There is'
    puts '       no configuration where 3\'-9 5/8" of ramp fits inside it.'
    puts '    4. Which side do you want the EFS boxes on? They add 10".'
    puts ''
    puts '  Booth shell NOT drawn — footprint only, ready for the real booth.'
    puts '=' * 76
    puts ''
  rescue StandardError => e
    model.abort_operation if model
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(8).map { |l| "  #{l}" }.join("\n")
  end
end

WR_FVRL.build unless $wr_no_autorun
