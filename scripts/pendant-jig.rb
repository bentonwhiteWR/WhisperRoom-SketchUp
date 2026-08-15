# @title Pendant Curing Jig...
# @shelf workshop
#
# A 3D-printable jig that holds a pendant's metal housing square and centres the
# polycarbonate tube in it while the adhesive cures.
#
# The part is one lathed solid, bottom to top:
#
#     +---------------+  <- top of tube guide
#     |   |     |     |
#     |   |Ø10.10|    |     tube guide, GUIDE_LEN long
#     |   |     |     |
#     |   +--+--+     |  <- glue-squeeze relief (Ø11.70 x 1.50)
#     |  |       |    |
#     |  | Ø15.29|    |     housing socket, SOCKET_DEPTH deep
#     |  |       |    |
#   +-+--+-------+--+-+  <- flange, kept at its 3.50 minimum
#   +----+---------+---+
#        |         |        4.00 of housing left below the flange —
#        |         |          this is what you hold while you push
#
# HAND-HELD. The housing is gripped in the fingers and the jig pushed onto it.
# Flange face to the housing/tube junction is 15.00. That figure was 10.00
# through Rev B; the printed Rev B jig worked well but did not take the housing
# deep enough, so Benton called for 5.00 more socket. FLANGE_H is already at its
# minimum, so all 5.00 went into SOCKET_DEPTH and the junction moved with it.
#
# The report still warns that the grab is down to 4.00. SETTLED — Benton ruled
# it a non-issue: the cap gives somewhere to hold, and the unit comes out by
# pressing on the tube from the far side rather than by pulling on the housing.
# Left the warning in because it is the right default for anyone changing
# SOCKET_DEPTH again without that context.
#
# Nothing here is metric-to-imperial converted for you: every constant below is
# in MILLIMETRES and the script sets the model to mm/decimal.
#
# EVERY BORE ALREADY INCLUDES THE PRINT CLEARANCE. Set the nominal part size in
# HOUSING_DIA / TUBE_DIA and the clearance in CLEARANCE / TUBE_CLEAR — don't
# pre-inflate. The two clearances are separate because the housing socket fits
# well at 0.25 and the tube guide did not.
#
# Run it from the WhisperRoom panel, or by hand — the repo sits at a different
# path on each machine, so use whichever of these exists:
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/pendant-jig.rb"
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/pendant-jig.rb"
# Ctrl+Z before re-running.

module WR_PendantJig
  # ---------------------------------------------------------------- measured --
  # The two numbers Benton measured off the real parts.
  HOUSING_DIA   = 15.04   # metal housing outside diameter
  HOUSING_LEN   = 19.00   # metal housing overall length
  TUBE_DIA      =  9.65   # polycarbonate tube outside diameter
  TUBE_LEN      = 54.00   # polycarbonate tube overall length

  # -------------------------------------------------------------- print fit --
  # Added to DIAMETER, so each bore gains half this on the radius.
  #
  # Two separate figures, and that is the whole point. Rev A used 0.25 for both.
  # On the printed part the housing socket came out a good fit and the tube guide
  # came out too tight, so only the tube figure moved. FIT-TESTED, which makes
  # these the best-sourced numbers in the file — better than anything measured,
  # because they include this printer's real behaviour.
  CLEARANCE     =  0.25   # housing socket — confirmed good on the printed jig
  TUBE_CLEAR    =  0.45   # tube guide — was 0.25 and too tight, opened by 0.20

  # ----------------------------------------------------------------- chosen --
  # None of these came off a part. Change them freely and re-run.
  SOCKET_DEPTH  = 11.50   # how far the housing goes in, of its 19.
                          #
                          # FIT-TESTED. Rev B printed at 6.50 and the jig worked
                          # well, but the housing did not seat deep enough, so
                          # Benton asked for 5.00 more. 6.50 + 5.00 = 11.50.
                          #
                          # This supersedes the old "flange face to junction is
                          # 10.00" spec, which is what set 6.50 in the first
                          # place. That junction is now 15.00 and the 10.00
                          # figure is dead — do not restore it.
                          # Was 18.00 (Rev A), 13.00, 6.50 (Rev B), now 11.50.
  GUIDE_LEN     = 36.00   # tube guide length — two thirds of the 54 mm tube
  WALL          =  3.10   # wall around the housing socket -> body OD 21.49
  FLANGE_DIA    = 28.00   # foot, so the jig stands square instead of on the housing
  FLANGE_H      =  3.50   # As SMALL as the 45 deg underside allows, which is
                          # FLANGE_DIA/2 - body_dia/2 = 3.255, rounded up.
                          #
                          # This briefly went to 7.00 on the theory that the jig
                          # stands on a bench with the housing tucked up inside
                          # it. It does not. THE HOUSING IS HELD IN THE HAND and
                          # the jig is pushed onto it, so every mm of flange is a
                          # mm of housing you cannot get your fingers to. Keep it
                          # at the minimum and spend the 10.00 on socket instead.
  FLANGE_RELIEF =  1.50   # added to housing dia for the flange bore, so the
                          # protruding part of the housing passes through clear
  GLUE_RELIEF_D =  1.60   # added to tube dia at the shoulder: a gutter for
  GLUE_RELIEF_H =  1.50   # squeeze-out, so glue can't bond the tube to the jig

  # ---------------------------------------------------------------- PRINTING --
  # PRINT IT SOCKET-OPENING-UP, i.e. flipped from how it is drawn here. That
  # puts the shoulder the housing registers against on TOP of solid material,
  # so it prints as a clean flat layer instead of drooping as an unsupported
  # ceiling over the socket. It is the one surface whose flatness decides
  # whether the housing sits square, so it gets the good side of the print.
  #
  # Everything below exists to make that orientation work without supports.
  RELIEF_W      =  0.80   # corner-relief groove at the shoulder: cuts the inside
  RELIEF_H      =  0.80   # corner OUTWARD past the housing OD, so the fillet a
                          # nozzle always leaves in an internal corner cannot
                          # hold the housing off its seat. This is the fix for
                          # "rounded edges might make it lean."
  MOUTH_CH      =  0.60   # chamfer at the tube-guide mouth. That face is on the
                          # bed when printed inverted, and elephant's foot would
                          # otherwise squeeze the bore and pinch the tube.

  # ------------------------------------------------------------------ layout --
  COUNT         =  5      # 5-up gang fixture. Set 1 for a single test print.
                          # At PITCH 32.00 the 28.00 flanges sit 4.00 apart and
                          # the tie bar bridges them, so it prints as one piece
                          # 156.00 long across the flanges.
  PITCH         = 32.00   # centre-to-centre when COUNT > 1
  TIE_BAR       = true    # rails linking the flanges when COUNT > 1 (slicers union them)
  TIE_W         = 10.00   # DEAD. The tie used to be ONE slab this wide, centred
                          # on the axis. It lay straight across every flange
                          # bore and the housing could not get in. Caught in the
                          # printed STL, not here. Kept only so the numbers still
                          # line up with pendant-jig-stl.py's drift check.
  TIE_CLEAR     =  0.50   # gap from the flange bore to the inner brace face
  TIE_OUTER     = 13.00   # DEAD with the flat rails. Kept so the numbers still
                          # line up with pendant-jig-stl.py's drift check.
  BRACE_T       =  3.20   # spine thickness — 8 passes of a 0.4 nozzle
  BRACE_FRAC    =  1.00   # spine height as a fraction of the part height
  SEGMENTS      = 72      # facets around — 72 gives ~0.9 mm chords on the OD

  # true  -> model is flipped to PRINT orientation, ready to export straight to STL
  # false -> model is drawn in USE orientation, standing on its flange as on a bench
  FLIP_FOR_PRINT = false

  # false shows the true faceted geometry. SketchUp softens near-coplanar edges
  # for display, which makes a faceted cylinder LOOK rounded — it is not, and
  # the STL is unaffected either way. Set false when you want to see the facets.
  SMOOTH_SHADING = true

  # Ghost copies of the real parts, so the fit is visible. Not printed.
  SHOW_PARTS    = true
  INSERTION     = 10.00   # ASSUMED: how deep the tube seats into the housing.
                          # Cosmetic only — it does not change the jig.

  # ------------------------------------------------------------------ derived --
  def self.socket_dia; HOUSING_DIA + CLEARANCE;  end
  def self.tube_bore;  TUBE_DIA    + TUBE_CLEAR; end
  def self.body_dia;   socket_dia  + 2 * WALL;   end
  def self.total_h;    FLANGE_H + SOCKET_DEPTH + GUIDE_LEN; end

  # This is a HAND-HELD fixture. The housing is held in the fingers and the jig
  # pushed down onto it, so what matters is how much housing is left sticking
  # out below the flange to hold. Not bench clearance — there is no bench.
  def self.proud;   HOUSING_LEN - SOCKET_DEPTH; end   # below the socket mouth
  def self.grab;    proud - FLANGE_H;           end   # below the flange underside
  def self.junction; FLANGE_H + SOCKET_DEPTH;   end   # flange face -> shoulder

  # The price of a short socket: how far the housing can rock inside it.
  def self.housing_tilt(depth = SOCKET_DEPTH)
    Math.atan(CLEARANCE / depth) * 180.0 / Math::PI
  end

  def self.pt(x, z)
    Geom::Point3d.new(x.mm, 0, z.mm)
  end

  # The half-section, revolved about Z. Listed as [radius, height] pairs walking
  # the closed loop counter-clockwise: up the outside, in across the top, down
  # the bores, out across the bottom. Every vertex is a real feature.
  #
  # Read the z values as DRAWN (flange at the bottom). Printing flips it, so
  # every downward-facing surface here is an upward-facing one on the bed and
  # vice versa — which is the whole reason the chamfers sit where they do.
  def self.profile
    rf = FLANGE_DIA / 2.0
    rb = body_dia   / 2.0
    rv = socket_dia / 2.0 + RELIEF_W               # corner-relief groove
    rr = (HOUSING_DIA + FLANGE_RELIEF) / 2.0
    rh = socket_dia / 2.0
    rg = (tube_bore + GLUE_RELIEF_D)   / 2.0
    rt = tube_bore  / 2.0

    z1   = FLANGE_H                    # flange top / socket mouth
    z2   = z1 + SOCKET_DEPTH           # shoulder the housing face butts against
    z3   = z2 + GLUE_RELIEF_H          # top of the squeeze-out gutter
    z4   = total_h                     # top of the tube guide

    land = FLANGE_H - (rf - rb)        # straight bit under the flange chamfer
    lead = rr - rh                     # 45 deg lead-in into the housing socket

    [[rr,           0],                # -- bottom face, inner edge
     [rf,           0],                #    bottom face, outer edge
     [rf,        land],                #    flange rim
     [rb,    FLANGE_H],                #    45 deg flange underside (when printed)
     [rb,          z4],                #    body outer wall
     [rt + MOUTH_CH, z4],              # -- top face
     [rt, z4 - MOUTH_CH],              #    guide-mouth chamfer (bed side)
     [rt,          z3],                #    tube guide bore
     [rg,          z3],                #    glue gutter
     [rg,          z2],                #
     [rv,          z2],                # -- the seat, out to the relief groove
     [rv, z2 - RELIEF_H],              #    corner relief: nothing intrudes
     [rh, z2 - RELIEF_H],              #    inside rh near the seat
     [rh,    FLANGE_H],                #    housing socket wall
     [rr, FLANGE_H - lead]]            #    45 deg lead-in, then back to [rr, 0]
  end                                  #    which closes the loop by wrapping

  # One jig as a single closed solid.
  #
  # This is built as an explicit polygon mesh rather than with follow_me. A
  # follow_me revolve has to close back on itself, and SketchUp does not
  # reliably weld that last seam — you get hairline cracks at the rims and the
  # group stops being a solid. Building the mesh ourselves means the last
  # column of quads is wrapped back to column 0 by index, so there is no seam
  # to fail. It also needs no Solid Tools, so it works in Make as well as Pro.
  #
  # Geom::PolygonMesh#add_point merges coincident points, which is what welds
  # every shared rim edge into one edge with exactly two faces on it.
  def self.build_jig(parent, x_offset)
    g    = parent.entities.add_group
    prof = profile
    n    = prof.size

    mesh = Geom::PolygonMesh.new(n * SEGMENTS, n * SEGMENTS)

    # idx[i][j] — profile point i, swept to rotation step j.
    idx = Array.new(n) { Array.new(SEGMENTS) }
    SEGMENTS.times do |j|
      a  = 2.0 * Math::PI * j / SEGMENTS
      ca = Math.cos(a)
      sa = Math.sin(a)
      prof.each_with_index do |(r, z), i|
        idx[i][j] = mesh.add_point(Geom::Point3d.new((r * ca).mm, (r * sa).mm, z.mm))
      end
    end

    # The profile is a closed loop and every radius is > 0, so sweeping it all
    # the way round gives a watertight surface with no caps needed. Both loops
    # wrap with %, which is where the seam would otherwise be.
    # Wound so the normals face outward. The profile runs counter-clockwise in
    # the radius/height plane, which makes this order the outward one — checked
    # by summing the signed mesh volume, not guessed.
    n.times do |i|
      i2 = (i + 1) % n
      SEGMENTS.times do |j|
        j2 = (j + 1) % SEGMENTS
        mesh.add_polygon(idx[i][j2], idx[i2][j2], idx[i2][j], idx[i][j])
      end
    end

    # 12 = AUTO_SOFTEN | SMOOTH_SOFT_EDGES: the cylindrical bands read smooth,
    # the steps between features stay hard. Purely a display choice — the
    # geometry and therefore the STL are identical either way.
    g.entities.add_faces_from_mesh(mesh, SMOOTH_SHADING ? 12 : 0)

    # A mesh wound the wrong way is a solid with negative volume, and slicers
    # read that as inside-out.
    if g.manifold? && g.volume < 0
      g.entities.grep(Sketchup::Face).each(&:reverse!)
    end

    g.transform!(Geom::Transformation.translation([x_offset.mm, 0, 0]))
    g.name = 'Pendant jig'
    g
  end

  # An edge with anything other than two faces on it is a crack. This is the
  # check that would have caught the follow_me seam, so it now runs every time.
  def self.naked_edges(group)
    group.entities.grep(Sketchup::Edge).count { |e| e.faces.size != 2 }
  end

  # Pappus's theorem: a closed section revolved about an axis sweeps a volume of
  # 2*pi*Rc*A, Rc being the section centroid's radius. It gives an independent
  # number to sanity-check the mesh volume against — if the two disagree by more
  # than the faceting error, something in the mesh is wrong.
  def self.expected_volume
    p  = profile
    n  = p.size
    a2 = 0.0
    cr = 0.0
    n.times do |i|
      r1, z1 = p[i]
      r2, z2 = p[(i + 1) % n]
      x = r1 * z2 - r2 * z1
      a2 += x
      cr += (r1 + r2) * x
    end
    return 0.0 if a2.abs < 1e-9
    2.0 * Math::PI * (cr / (3.0 * a2)).abs * (a2 / 2.0).abs
  end

  # ONE CENTRE SPINE, standing on edge, full height — in the GAPS only.
  #
  # Fourth shape here, and the right one. The three before it:
  #
  #   1. One slab down the centreline at flange height, running the full
  #      length. The flange bore is Ø16.54 and the slab lay straight across
  #      it, so the housing could not enter ANY unit. Caught in the printed
  #      STL, not here.
  #   2. Two flat rails outboard of the bores, still at flange height. Bores
  #      clear, but 4.23 x 3.50 lying flat is about 15 mm4 of second moment —
  #      a strap, not a brace. It felt flimsy, correctly.
  #   3. Two vertical webs outboard, full height. Genuinely stiff, but they
  #      wall in both flanks, and out at y 8.77 the body only reaches them
  #      over a 12.4 strip, so the weld to each unit is shallow.
  #
  # On the centreline the bodies come CLOSEST together, so a spine there meets
  # each at its widest point: 1.97 into the body wall and 5.23 into the
  # flange. It leaves both flanks open to see and grab, and costs about a
  # third of what two side webs did. Standing on edge over the full 51.00 it
  # is ~35400 mm4 against the rails' 30 — bending stiffness goes as the CUBE
  # of depth, which is why rotating the section matters so much more than
  # thickening it.
  #
  # Full height also fixes the print: a flange-height tie is the LAST thing
  # laid down socket-up, so five 51 mm towers would stand unlinked for the
  # whole build. This joins them from the first layer.
  #
  # THE CATCH, and it is trap 1 again: the spine cannot run continuously,
  # because at each unit the centreline IS the bore. Every segment stops
  # clear of the bore at both ends, so the spine is a row of posts bridging
  # gap by gap. Overlapping by design — slicers union it.
  def self.spine_stop; (HOUSING_DIA + FLANGE_RELIEF) / 2.0 + TIE_CLEAR; end

  def self.build_tie(parent)
    g = parent.entities.add_group
    y0 = -BRACE_T / 2.0
    y1 =  BRACE_T / 2.0
    (COUNT - 1).times do |i|
      gx0 = i * PITCH + spine_stop
      gx1 = (i + 1) * PITCH - spine_stop
      next if gx1 <= gx0
      f = g.entities.add_face([pt2(gx0, y0), pt2(gx1, y0),
                               pt2(gx1, y1), pt2(gx0, y1)])
      next if f.nil?
      f.reverse! if f.normal.z < 0
      f.pushpull((total_h * BRACE_FRAC).mm)
    end
    return nil if g.entities.grep(Sketchup::Face).empty?
    g.name = 'Spine'
    g
  end

  def self.pt2(x, y, z = 0.0)
    Geom::Point3d.new(x.mm, y.mm, z.mm)
  end

  # A plain cylinder, used only for the ghost housing and tube.
  def self.cylinder(parent, dia, len, z_base, x_offset, name)
    g = parent.entities.add_group
    c = g.entities.add_circle(Geom::Point3d.new(x_offset.mm, 0, z_base.mm),
                              Z_AXIS, (dia / 2.0).mm, SEGMENTS)
    f = g.entities.add_face(c)
    return nil if f.nil?
    f.reverse! if f.normal.z < 0
    f.pushpull(len.mm)
    g.name = name
    g
  end

  def self.tag(model, name, rgb)
    l = model.layers[name] || model.layers.add(name)
    (l.color = Sketchup::Color.new(*rgb)) rescue nil
    l
  end

  def self.ghost(model, name, rgb)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*rgb)
    m.alpha = 0.45
    m
  end

  def self.run
    model = Sketchup.active_model

    # This part is metric. Deliberately NOT the repo's Architectural default.
    begin
      o = model.options['UnitsOptions']
      o['LengthUnit']      = Length::Millimeter
      o['LengthFormat']    = Length::Decimal
      o['LengthPrecision'] = 2
    rescue StandardError
    end

    model.start_operation('Build pendant curing jig', true)

    t_jig  = tag(model, 'JIG-Body',  [110, 120, 130])
    t_ref  = tag(model, 'JIG-Parts', [238,  98,  22])
    t_dim  = tag(model, 'JIG-Dims',  [ 40,  40,  40])

    root = model.entities.add_group
    root.name = COUNT > 1 ? "Pendant jig x#{COUNT}" : 'Pendant jig'

    solids = 0
    naked  = 0
    vol_mm = 0.0
    COUNT.times do |i|
      g = build_jig(root, i * PITCH)
      g.layer = t_jig
      naked += naked_edges(g)
      if g.manifold?
        solids += 1
        # SketchUp volume comes back in cubic inches.
        one = 1.0.mm.to_f
        vol_mm += g.volume / (one * one * one)
      end
    end

    if COUNT > 1 && TIE_BAR
      tb = build_tie(root)
      tb.layer = t_jig if tb
    end

    if SHOW_PARTS
      mat_h = ghost(model, 'Jig ghost housing', [150, 150, 158])
      mat_t = ghost(model, 'Jig ghost tube',    [120, 190, 220])
      z_shoulder = FLANGE_H + SOCKET_DEPTH
      COUNT.times do |i|
        x = i * PITCH
        h = cylinder(root, HOUSING_DIA, HOUSING_LEN, z_shoulder - HOUSING_LEN, x, 'Housing (ref)')
        t = cylinder(root, TUBE_DIA,    TUBE_LEN,    z_shoulder - INSERTION,   x, 'Tube (ref)')
        [h, t].compact.each { |gg| gg.layer = t_ref }
        h.material = mat_h if h
        t.material = mat_t if t
      end
    end

    dimension(model, t_dim)

    # Flip about X so the socket opens upward — the orientation it prints in.
    # Done last so the dimensions come along with it.
    if FLIP_FOR_PRINT
      flip = Geom::Transformation.rotation(ORIGIN, X_AXIS, Math::PI)
      root.transform!(flip)
    end

    model.commit_operation
    model.active_view.zoom_extents
    report(solids, naked, vol_mm)
  rescue StandardError => e
    model.abort_operation if model
    UI.messagebox("Jig build failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end

  # Key dimensions live in the model, not just in the console, so the numbers
  # travel with the file.
  def self.dimension(model, layer)
    e  = model.entities
    rb = body_dia / 2.0
    z1 = FLANGE_H
    z2 = z1 + SOCKET_DEPTH
    off = Geom::Vector3d.new((rb + 12).mm, 0, 0)

    dims = []
    dims << e.add_dimension_linear(pt(0, 0), pt(0, total_h), off)                    # overall height
    dims << e.add_dimension_linear(pt(0, z1), pt(0, z2), Geom::Vector3d.new((rb + 24).mm, 0, 0))
    dims << e.add_dimension_linear(pt(0, z2), pt(0, total_h), Geom::Vector3d.new((rb + 36).mm, 0, 0))
    dims << e.add_dimension_linear(pt(-body_dia / 2.0, total_h), pt(body_dia / 2.0, total_h),
                                   Geom::Vector3d.new(0, 0, 14.mm))                  # body OD
    dims << e.add_dimension_linear(pt(-socket_dia / 2.0, z1), pt(socket_dia / 2.0, z1),
                                   Geom::Vector3d.new(0, 0, -10.mm))                 # socket bore
    dims << e.add_dimension_linear(pt(-tube_bore / 2.0, total_h), pt(tube_bore / 2.0, total_h),
                                   Geom::Vector3d.new(0, 0, 26.mm))                  # tube bore
    dims.compact.each { |d| d.layer = layer }
  rescue StandardError => err
    puts "  (dimensions skipped: #{err.message})"
  end

  def self.report(solids, naked, vol_mm)
    # The whole point of the jig is how straight it holds the tube, so state it.
    tube_play  = TUBE_CLEAR / 2.0
    tilt_deg   = Math.atan(TUBE_CLEAR / GUIDE_LEN) * 180.0 / Math::PI
    tip_err    = Math.tan(tilt_deg * Math::PI / 180.0) * TUBE_LEN

    puts ''
    puts "PENDANT CURING JIG  —  #{COUNT} up, all dimensions mm"
    puts ''
    puts format('  body            dia %.2f  x  %.2f tall', body_dia, total_h)
    puts format('  housing socket  dia %.2f  x  %.2f deep   (housing %.2f + %.2f clearance)',
                socket_dia, SOCKET_DEPTH, HOUSING_DIA, CLEARANCE)
    puts format('  tube guide      dia %.2f  x  %.2f long   (tube %.2f + %.2f clearance)',
                tube_bore, GUIDE_LEN, TUBE_DIA, TUBE_CLEAR)
    puts format('  glue gutter     dia %.2f  x  %.2f deep at the shoulder',
                tube_bore + GLUE_RELIEF_D, GLUE_RELIEF_H)
    puts format('  flange          dia %.2f  x  %.2f, bore dia %.2f',
                FLANGE_DIA, FLANGE_H, HOUSING_DIA + FLANGE_RELIEF)
    puts ''
    puts '  WATERTIGHT CHECK  (this is the bit that was broken before)'
    puts "    #{solids} of #{COUNT} groups report as solid"
    puts "    #{naked} naked edges  — must be 0. Anything else is a crack in a rim."
    puts format('    volume %.1f mm3   vs %.1f exact  (%+.2f%% — faceting, under 0.5%% is fine)',
                vol_mm, expected_volume,
                expected_volume.zero? ? 0.0 : 100.0 * (vol_mm - expected_volume) / expected_volume)
    if naked.zero? && solids == COUNT
      puts '    -> closed. Entity Info will say Solid Group, and it will slice.'
    else
      puts '    -> NOT closed. Send me this line and I will fix it.'
    end
    puts ''
    puts '  GRIP AND GRAB  —  this is a hand-held fixture, not a bench stand'
    puts format('    flange face to shoulder   %.2f   (Rev C spec: 15.00, was 10.00)', junction)
    puts format('    socket holds              %.2f of the %.2f housing', SOCKET_DEPTH, HOUSING_LEN)
    puts format('    proud of the socket mouth %.2f,  of which %.2f is below the flange',
                proud, grab)
    if grab < 5.0
      puts format('    *** ONLY %.2f mm OF HOUSING TO HOLD. Drop FLANGE_H or SOCKET_DEPTH.', grab)
    else
      puts format('    -> %.2f mm of housing left to get your fingers on. OK.', grab)
    end
    puts ''
    puts '    WHAT THE SHORT SOCKET COSTS. Engagement is what holds the housing'
    puts '    square, and this is the fixture\'s whole job, so it is worth stating:'
    [18.0, 13.0, SOCKET_DEPTH].each do |d|
      mark = (d - SOCKET_DEPTH).abs < 0.001 ? '  <- as drawn' : ''
      puts format('      %5.2f engagement -> housing can rock %.2f deg%s', d, housing_tilt(d), mark)
    end
    puts format('    The tube guide is far better than that at %.2f deg, so the housing,',
                Math.atan(TUBE_CLEAR / GUIDE_LEN) * 180.0 / Math::PI)
    puts '    not the tube, is now what limits how square the joint comes out.'
    puts ''
    puts '  HOW STRAIGHT IT ACTUALLY HOLDS THE TUBE'
    puts format('    %.3f mm radial play in the guide over %.1f mm of guide length', tube_play, GUIDE_LEN)
    puts format('    = up to %.2f deg of tilt, or %.2f mm off-axis at the far end of the tube', tilt_deg, tip_err)
    puts '    Lengthen GUIDE_LEN or tighten CLEARANCE if that is not good enough.'
    puts ''
    puts '  FIT-TESTED on the printed jig — better sourced than any measurement:'
    puts format('    CLEARANCE     %.2f   housing socket, came out a good fit', CLEARANCE)
    puts format('    TUBE_CLEAR    %.2f   tube guide, was %.2f and too tight', TUBE_CLEAR, CLEARANCE)
    puts format('    SOCKET_DEPTH  %.2f   Rev B printed at 6.50 and did not seat', SOCKET_DEPTH)
    puts '                          deep enough; deepened by 5.00 on Benton\'s call'
    puts ''
    puts '  NOT MEASURED — every one of these is a choice, not a part dimension:'
    puts format('    GUIDE_LEN     %.2f   two thirds of the 54 mm tube', GUIDE_LEN)
    puts format('    WALL          %.2f   picked for print strength, nothing more', WALL)
    puts format('    FLANGE        %.2f x %.2f  height is set by BENCH CLEARANCE, not by the', FLANGE_DIA, FLANGE_H)
    puts format('                              45 deg rule: it must exceed the %.2f of housing left', proud)
    puts format('                              proud. Underside is still 45 deg, with %.2f of', FLANGE_H - (FLANGE_DIA - body_dia) / 2.0)
    puts '                              straight land below the chamfer taking up the rest.'
    puts format('    RELIEF        %.2f x %.2f  corner groove at the seat', RELIEF_W, RELIEF_H)
    puts format('    MOUTH_CH      %.2f        chamfer at the bed-side guide mouth', MOUTH_CH)
    puts format('    FLANGE_RELIEF %.2f   clears the 1.00 mm of housing left proud of the socket', FLANGE_RELIEF)
    puts format('    GLUE gutter   %.2f x %.2f  added to stop glue bonding the tube to the jig', GLUE_RELIEF_D, GLUE_RELIEF_H)
    puts format('    INSERTION     %.2f   ghost tube only — never asked, affects nothing printed', INSERTION)
    puts ''
    puts '  PRINT IT SOCKET-OPENING-UP — flipped from how it is drawn here.'
    puts '    The shoulder the housing seats on then prints ON TOP of solid material'
    puts '    instead of drooping as an unsupported ceiling over the socket. That one'
    puts '    surface decides whether the housing sits square, so it gets the good side.'
    puts format('    Every sloped face is 45 deg in that orientation, so NO SUPPORTS.')
    puts "    Set FLIP_FOR_PRINT = true to have the script draw it that way instead."
    puts '    Bed contact is a ring about 21 mm across on a 57 mm tall part — use a brim.'
    puts ''
    puts '  WHY IT WILL NOT LEAN'
    puts format('    corner relief %.2f x %.2f pushes the internal corner out to r %.2f,',
                RELIEF_W, RELIEF_H, socket_dia / 2.0 + RELIEF_W)
    puts format('    which is %.2f mm clear of the housing OD at r %.2f. The fillet a nozzle',
                socket_dia / 2.0 + RELIEF_W - HOUSING_DIA / 2.0, HOUSING_DIA / 2.0)
    puts '    always leaves in an internal corner therefore sits OUTSIDE the housing'
    puts '    and cannot hold its face off the seat.'
    puts ''
    puts '  Nothing in this model is filleted. SketchUp softens near-coplanar edges for'
    puts '  display, which makes a faceted cylinder look rounded; the steps are square'
    puts '  and the STL is identical. SMOOTH_SHADING = false to see the real facets.'
    puts ''
  end
end

WR_PendantJig.run
