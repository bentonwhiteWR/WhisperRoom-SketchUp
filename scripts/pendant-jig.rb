# @title Pendant Curing Jig...
#
# A 3D-printable jig that holds a pendant's metal housing square and centres the
# polycarbonate tube in it while the adhesive cures.
#
# The part is one lathed solid, bottom to top:
#
#     +---------------+  <- top of tube guide
#     |   |     |     |
#     |   | Ø9.90|    |     tube guide, GUIDE_LEN long
#     |   |     |     |
#     |   +--+--+     |  <- glue-squeeze relief (Ø11.50 x 1.50)
#     |  |       |    |
#     |  | Ø15.29|    |     housing socket, SOCKET_DEPTH deep
#     |  |       |    |
#   +-+--+-------+--+-+  <- flange, so it stands square on the bench
#   |    | Ø16.50 |   |     relief: the 1 mm of housing that doesn't
#   +----+--------+---+       fit in the socket hangs clear of the bench
#
# Nothing here is metric-to-imperial converted for you: every constant below is
# in MILLIMETRES and the script sets the model to mm/decimal.
#
# EVERY BORE ALREADY INCLUDES THE PRINT CLEARANCE. Set the nominal part size in
# HOUSING_DIA / TUBE_DIA and the clearance once in CLEARANCE — don't pre-inflate.
#
# Run it from Extensions > Developer > Ruby Console:
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
  # Added to DIAMETER, so each bore gains half this on the radius. Benton's
  # usual allowance for a part that still has to squeeze in with a little play.
  CLEARANCE     =  0.25

  # ----------------------------------------------------------------- chosen --
  # None of these came off a part. Change them freely and re-run.
  SOCKET_DEPTH  = 18.00   # how far the housing goes in ("around 18") of its 19
  GUIDE_LEN     = 36.00   # tube guide length — two thirds of the 54 mm tube
  WALL          =  3.10   # wall around the housing socket -> body OD 21.49
  FLANGE_DIA    = 28.00   # foot, so the jig stands square instead of on the housing
  FLANGE_H      =  3.50   # tall enough for a 45 deg underside — see PRINTING below
  FLANGE_RELIEF =  1.50   # added to housing dia for the flange bore, so the
                          # protruding 1 mm of housing never touches the bench
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
  COUNT         =  1      # 1 for the test print; set 5 for the gang fixture
  PITCH         = 32.00   # centre-to-centre when COUNT > 1
  TIE_BAR       = true    # bar linking the flanges when COUNT > 1 (slicers union it)
  TIE_W         = 10.00
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
  def self.socket_dia; HOUSING_DIA + CLEARANCE; end
  def self.tube_bore;  TUBE_DIA    + CLEARANCE; end
  def self.body_dia;   socket_dia  + 2 * WALL;  end
  def self.total_h;    FLANGE_H + SOCKET_DEPTH + GUIDE_LEN; end

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

  # Overlaps the flanges by design — every slicer unions overlapping solids, so
  # the gang fixture prints as one piece without needing Solid Tools.
  def self.build_tie(parent)
    span_x0 = -FLANGE_DIA / 2.0
    span_x1 = (COUNT - 1) * PITCH + FLANGE_DIA / 2.0
    g = parent.entities.add_group
    f = g.entities.add_face([pt2(span_x0, -TIE_W / 2.0), pt2(span_x1, -TIE_W / 2.0),
                             pt2(span_x1,  TIE_W / 2.0), pt2(span_x0,  TIE_W / 2.0)])
    return nil if f.nil?
    f.reverse! if f.normal.z < 0
    f.pushpull(FLANGE_H.mm)
    g.name = 'Tie bar'
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
    tube_play  = CLEARANCE / 2.0
    tilt_deg   = Math.atan(CLEARANCE / GUIDE_LEN) * 180.0 / Math::PI
    tip_err    = Math.tan(tilt_deg * Math::PI / 180.0) * TUBE_LEN

    puts ''
    puts "PENDANT CURING JIG  —  #{COUNT} up, all dimensions mm"
    puts ''
    puts format('  body            dia %.2f  x  %.2f tall', body_dia, total_h)
    puts format('  housing socket  dia %.2f  x  %.2f deep   (housing %.2f + %.2f clearance)',
                socket_dia, SOCKET_DEPTH, HOUSING_DIA, CLEARANCE)
    puts format('  tube guide      dia %.2f  x  %.2f long   (tube %.2f + %.2f clearance)',
                tube_bore, GUIDE_LEN, TUBE_DIA, CLEARANCE)
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
    puts '  HOW STRAIGHT IT ACTUALLY HOLDS THE TUBE'
    puts format('    %.3f mm radial play in the guide over %.1f mm of guide length', tube_play, GUIDE_LEN)
    puts format('    = up to %.2f deg of tilt, or %.2f mm off-axis at the far end of the tube', tilt_deg, tip_err)
    puts '    Lengthen GUIDE_LEN or tighten CLEARANCE if that is not good enough.'
    puts ''
    puts '  NOT MEASURED — every one of these is a choice, not a part dimension:'
    puts format('    SOCKET_DEPTH  %.2f   from "around 18" of the 19 mm housing', SOCKET_DEPTH)
    puts format('    GUIDE_LEN     %.2f   two thirds of the 54 mm tube', GUIDE_LEN)
    puts format('    WALL          %.2f   picked for print strength, nothing more', WALL)
    puts format('    FLANGE        %.2f x %.2f  stands square on the bench; the height is', FLANGE_DIA, FLANGE_H)
    puts format('                              set by needing a 45 deg underside (%.2f mm land left)',
                FLANGE_H - (FLANGE_DIA - body_dia) / 2.0)
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
