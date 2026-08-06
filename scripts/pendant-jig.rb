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
  FLANGE_H      =  2.00
  FLANGE_RELIEF =  1.50   # added to housing dia for the flange bore, so the
                          # protruding 1 mm of housing never touches the bench
  GLUE_RELIEF_D =  1.60   # added to tube dia at the shoulder: a gutter for
  GLUE_RELIEF_H =  1.50   # squeeze-out, so glue can't bond the tube to the jig

  # ------------------------------------------------------------------ layout --
  COUNT         =  1      # 1 for the test print; set 5 for the gang fixture
  PITCH         = 32.00   # centre-to-centre when COUNT > 1
  TIE_BAR       = true    # bar linking the flanges when COUNT > 1 (slicers union it)
  TIE_W         = 10.00
  SEGMENTS      = 72      # facets around — 72 gives ~0.9 mm chords on the OD

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
  # the closed loop: up the outside, in across the top, down the bores, out
  # across the bottom. Every step is a real feature of the part.
  def self.profile
    rf = FLANGE_DIA / 2.0
    rb = body_dia   / 2.0
    rr = (HOUSING_DIA + FLANGE_RELIEF) / 2.0
    rh = socket_dia / 2.0
    rg = (tube_bore + GLUE_RELIEF_D)   / 2.0
    rt = tube_bore  / 2.0

    z1 = FLANGE_H                      # flange top
    z2 = z1 + SOCKET_DEPTH             # shoulder the housing face butts against
    z3 = z2 + GLUE_RELIEF_H            # top of the squeeze-out gutter
    z4 = total_h                       # top of the tube guide

    [[rr, 0], [rf, 0], [rf, z1], [rb, z1], [rb, z4],   # outside, bottom to top
     [rt, z4], [rt, z3], [rg, z3], [rg, z2],           # tube guide + gutter
     [rh, z2], [rh, z1], [rr, z1]]                     # housing socket + relief
  end

  # One jig as a single lathed solid. No Solid Tools, so this works in Make as
  # well as Pro — a revolve gives us the bores without any boolean subtraction.
  def self.build_jig(parent, x_offset)
    g = parent.entities.add_group
    ents = g.entities

    face = ents.add_face(profile.map { |r, z| pt(r, z) })
    raise 'profile face failed — check that no two radii collide' if face.nil?

    # Path circle centred on the revolve axis. Radius is deliberately larger
    # than the profile's widest point so the two never touch and SketchUp can't
    # weld them together; it has no effect on the result.
    path = ents.add_circle(ORIGIN, Z_AXIS, (FLANGE_DIA).mm, SEGMENTS)
    face.followme(path)
    path.each { |e| e.erase! if e.valid? }

    # A reversed lathe reads as a solid with negative volume, and slicers hate it.
    if g.manifold? && g.volume < 0
      g.entities.grep(Sketchup::Face).each(&:reverse!)
    end

    g.transform!(Geom::Transformation.translation([x_offset.mm, 0, 0]))
    g.name = 'Pendant jig'
    g
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
    COUNT.times do |i|
      g = build_jig(root, i * PITCH)
      g.layer = t_jig
      solids += 1 if g.manifold?
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

    model.commit_operation
    model.active_view.zoom_extents
    report(solids)
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

  def self.report(solids)
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
    puts "  solids built    #{solids} of #{COUNT} manifold"
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
    puts format('    FLANGE        %.2f x %.2f  so it stands square on the bench', FLANGE_DIA, FLANGE_H)
    puts format('    FLANGE_RELIEF %.2f   clears the 1.00 mm of housing left proud of the socket', FLANGE_RELIEF)
    puts format('    GLUE gutter   %.2f x %.2f  added to stop glue bonding the tube to the jig', GLUE_RELIEF_D, GLUE_RELIEF_H)
    puts format('    INSERTION     %.2f   ghost tube only — never asked, affects nothing printed', INSERTION)
    puts ''
    puts '  PRINT IT FLANGE DOWN. Both bores are then vertical and self-supporting,'
    puts '  and the shoulder the housing registers against is a clean layer face.'
    puts ''
  end
end

WR_PendantJig.run
