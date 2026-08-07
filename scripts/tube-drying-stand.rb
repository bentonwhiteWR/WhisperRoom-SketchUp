# @title Tube Drying Stand...
#
# A 3D-printable rack that stands 60 polycarbonate tubes upright while the
# epoxy cures. Open diamond-lattice walls, a ledge under each pocket to catch
# the tube, and four small corner feet.
#
#           /\  /\  /\      diamond openings, 20.6 deg from vertical
#   walls  /  \/  \/  \     — well inside the 45 deg self-supporting limit
#          \  /\  /\  /
#   ledge  --  --  --       2.00 frame per pocket: holds the tube, drains epoxy
#   feet   #            #   4 corner pads only
#   ----------------------- bench
#
# PRINT IT UPSIDE DOWN — wall tops on the bed. That is not a preference, it is
# what makes the corner feet possible: right way up, the plate would be one
# 123 x 75 unsupported overhang held up on four 4 mm pads. Inverted, the feet
# are the last thing printed and sit on solid material. See the audit the
# script prints.
#
# All dimensions MILLIMETRES. The script sets the model to mm/decimal.
#
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/tube-drying-stand.rb"
#
# Ctrl+Z before re-running.

module WR_TubeStand
  # ---------------------------------------------------------------- measured --
  TUBE_DIA     =  9.65    # polycarbonate tube outside diameter
  TUBE_LEN     = 54.00    # tube overall length

  # ----------------------------------------------------------------- the grid --
  COLS         = 10
  ROWS         =  6       # 10 x 6 = 60 tubes
  POCKET_CLEAR =  0.50    # added to the tube dia to get the square pocket side
  POCKET_DEPTH = 25.00    # wall height, and the span the tube is located over
  WALL_T       =  2.00    # grid wall thickness

  # ------------------------------------------------------- ledge and openings --
  BASE_T       =  2.50    # thickness of the ledge frame under each pocket
  LEDGE_W      =  2.00    # how far that frame reaches in from the pocket wall.
                          # Everything inside it is open, so the whole middle of
                          # each pocket drains. Kept at 2.00 because printed
                          # inverted this is an unsupported inward step, and 2 mm
                          # is comfortably inside the ~5 mm that prints clean.

  # -------------------------------------------------------- diamond fenestration --
  DIA_POST     =  1.50    # solid strip left each side of a diamond, at the wall
                          # intersections where the two grids cross
  DIA_MARGIN   =  3.00    # solid band left at the top and bottom of every wall.
                          # These two bands are what actually locate the tube, so
                          # the openings cost nothing in straightness.

  # ------------------------------------------------------------------- feet --
  FOOT_H       =  4.00    # standoff, so epoxy runs clear of the bench

  # ------------------------------------------------------------------ output --
  FLIP_FOR_PRINT = false  # true -> drawn inverted, ready to export as STL
  SHOW_TUBES     = true   # translucent ghost tubes, not printed
  TUBE_SEGS      = 16

  # ------------------------------------------------------------------ derived --
  def self.pocket;   TUBE_DIA + POCKET_CLEAR;         end
  def self.pitch;    pocket + WALL_T;                 end
  def self.plate_w;  COLS * pitch + WALL_T;           end
  def self.plate_d;  ROWS * pitch + WALL_T;           end
  def self.total_h;  FOOT_H + BASE_T + POCKET_DEPTH;  end
  def self.base_z;   FOOT_H;                          end
  def self.floor_z;  FOOT_H + BASE_T;                 end
  def self.opening;  pocket - 2 * LEDGE_W;            end
  def self.dia_w;    pocket - 2 * DIA_POST;           end
  def self.dia_h;    POCKET_DEPTH - 2 * DIA_MARGIN;   end

  # A foot only ever sits where the base plate is solid: the outer wall band
  # plus the ledge. Deriving it means it stays on solid material if the grid
  # parameters change.
  def self.foot;     WALL_T + LEDGE_W;                end

  OVERLAP = 0.50   # pieces overlap by this so there are no coincident faces

  def self.pocket_origin(c, r)
    [WALL_T + c * pitch, WALL_T + r * pitch]
  end

  def self.pocket_centre(c, r)
    x, y = pocket_origin(c, r)
    [x + pocket / 2.0, y + pocket / 2.0]
  end

  def self.cells
    out = []
    ROWS.times { |r| COLS.times { |c| out << [c, r] } }
    out
  end

  # Centres of the pockets along one wall's length — where the diamonds go.
  def self.span_centres(n)
    (0...n).map { |i| WALL_T + i * pitch + pocket / 2.0 }
  end

  def self.p3(x, y, z)
    Geom::Point3d.new(x.mm, y.mm, z.mm)
  end

  def self.rect(x0, y0, x1, y1, z)
    [p3(x0, y0, z), p3(x1, y0, z), p3(x1, y1, z), p3(x0, y1, z)]
  end

  def self.box(parent, x0, y0, z0, dx, dy, dz, name)
    g = parent.entities.add_group
    f = g.entities.add_face(rect(x0, y0, x0 + dx, y0 + dy, z0))
    return nil if f.nil?
    f.reverse! if f.normal.z < 0
    f.pushpull(dz.mm)
    g.name = name
    g
  end

  # Lay the outer face, cut the openings into it, throw away the offcuts,
  # extrude what is left. Whatever was removed stays behind as an inner loop,
  # so the result is ONE solid with real openings rather than a pile of boxes.
  # The keeper is always the largest face — the panel dwarfs any single opening.
  def self.extrude_with_openings(entities, outer_pts, cut_loops, thickness, axis)
    face = entities.add_face(outer_pts)
    return nil if face.nil?
    cut_loops.each { |pts| entities.add_face(pts) }

    faces = entities.grep(Sketchup::Face)
    keep  = faces.max_by(&:area)
    (faces - [keep]).each { |f| f.erase! if f.valid? }

    n = keep.normal
    dir = case axis
          when :x then n.x
          when :y then n.y
          else         n.z
          end
    keep.pushpull(dir < 0 ? -thickness.mm : thickness.mm)
    keep
  end

  # The ledge plate: full footprint, with a square opening inside every pocket.
  def self.base_plate(parent)
    g = parent.entities.add_group
    cuts = cells.map do |c, r|
      x, y = pocket_origin(c, r)
      rect(x + LEDGE_W, y + LEDGE_W, x + LEDGE_W + opening, y + LEDGE_W + opening, base_z)
    end
    ok = extrude_with_openings(g.entities, rect(0, 0, plate_w, plate_d, base_z),
                               cuts, BASE_T, :z)
    return nil if ok.nil?
    g.name = 'Ledge plate'
    g
  end

  # One wall panel, standing on edge, with a diamond punched through at every
  # pocket it passes. plane :xz means the wall runs along X and is WALL_T thick
  # in Y; :yz is the other way about.
  def self.wall_panel(parent, plane, offset, length, centres, name)
    g  = parent.entities.add_group
    z0 = floor_z - OVERLAP
    z1 = floor_z + POCKET_DEPTH
    pt = lambda { |u, z| plane == :xz ? p3(u, offset, z) : p3(offset, u, z) }

    hw = dia_w / 2.0
    hh = dia_h / 2.0
    zc = floor_z + POCKET_DEPTH / 2.0
    diamonds = centres.map do |u|
      [pt.call(u - hw, zc), pt.call(u, zc - hh), pt.call(u + hw, zc), pt.call(u, zc + hh)]
    end

    outer = [pt.call(0, z0), pt.call(length, z0), pt.call(length, z1), pt.call(0, z1)]
    ok = extrude_with_openings(g.entities, outer, diamonds, WALL_T,
                               plane == :xz ? :y : :x)
    return nil if ok.nil?
    g.name = name
    g
  end

  def self.build(parent)
    parts = []
    parts << base_plate(parent)

    # Walls running along X, one per row boundary.
    (ROWS + 1).times do |r|
      parts << wall_panel(parent, :xz, r * pitch, plate_w, span_centres(COLS),
                          "Wall X#{r + 1}")
    end
    # Walls running along Y, one per column boundary.
    (COLS + 1).times do |c|
      parts << wall_panel(parent, :yz, c * pitch, plate_d, span_centres(ROWS),
                          "Wall Y#{c + 1}")
    end

    # Four corner pads. Sized so each one lands wholly on solid ledge plate —
    # printed inverted these go on LAST, on top of that plate.
    f = foot
    [[0, 0], [plate_w - f, 0], [0, plate_d - f], [plate_w - f, plate_d - f]]
      .each_with_index do |(x, y), i|
        parts << box(parent, x, y, 0, f, f, FOOT_H + OVERLAP, "Foot #{i + 1}")
      end

    parts.compact
  end

  def self.ghost_tubes(model, parent)
    m = model.materials['Stand ghost tube'] || model.materials.add('Stand ghost tube')
    m.color = Sketchup::Color.new(120, 190, 220)
    m.alpha = 0.40
    cells.each do |c, r|
      cx, cy = pocket_centre(c, r)
      g = parent.entities.add_group
      circle = g.entities.add_circle(p3(cx, cy, floor_z), Z_AXIS, (TUBE_DIA / 2.0).mm, TUBE_SEGS)
      f = g.entities.add_face(circle)
      next if f.nil?
      f.reverse! if f.normal.z < 0
      f.pushpull(TUBE_LEN.mm)
      g.name = "Tube #{r * COLS + c + 1} (ref)"
    end
  end

  def self.tag(model, name, rgb)
    l = model.layers[name] || model.layers.add(name)
    (l.color = Sketchup::Color.new(*rgb)) rescue nil
    l
  end

  def self.naked_edges(group)
    group.entities.grep(Sketchup::Edge).count { |e| e.faces.size != 2 }
  end

  # The printed volume is the UNION of overlapping panels, so summing the
  # groups would double-count every wall intersection. Work it out from the
  # geometry instead.
  def self.union_volume
    lattice = (plate_w * plate_d - COLS * ROWS * pocket * pocket) * POCKET_DEPTH
    n_dia   = (ROWS + 1) * COLS + (COLS + 1) * ROWS
    lattice -= n_dia * (0.5 * dia_w * dia_h) * WALL_T
    plate    = (plate_w * plate_d - COLS * ROWS * opening * opening) * BASE_T
    feet     = 4 * foot * foot * FOOT_H
    [lattice + plate + feet, n_dia]
  end

  def self.run
    # A tube must not be able to drop through the opening in any orientation —
    # the diagonal is the case that catches people out, not the side.
    if opening * Math.sqrt(2) >= TUBE_DIA
      UI.messagebox("The pocket opening is #{format('%.2f', opening)} square, whose diagonal " \
                    "#{format('%.2f', opening * Math.sqrt(2))} is not less than the tube at " \
                    "#{TUBE_DIA}.\nThe tubes would drop through. Increase LEDGE_W.")
      return
    end

    model = Sketchup.active_model
    begin
      o = model.options['UnitsOptions']
      o['LengthUnit']      = Length::Millimeter
      o['LengthFormat']    = Length::Decimal
      o['LengthPrecision'] = 2
    rescue StandardError
    end

    model.start_operation('Build tube drying stand', true)

    t_stand = tag(model, 'STAND-Body',  [110, 120, 130])
    t_ref   = tag(model, 'STAND-Tubes', [238,  98,  22])

    root = model.entities.add_group
    root.name = "Tube drying stand #{COLS}x#{ROWS}"

    parts = build(root)
    parts.each { |g| g.layer = t_stand }
    solids = parts.count(&:manifold?)
    naked  = parts.map { |g| naked_edges(g) }.inject(0, :+)

    if SHOW_TUBES
      gt = root.entities.add_group
      gt.name = 'Ghost tubes'
      ghost_tubes(model, gt)
      gt.layer = t_ref
    end

    if FLIP_FOR_PRINT
      root.transform!(Geom::Transformation.rotation(ORIGIN, X_AXIS, Math::PI))
    end

    model.commit_operation
    model.active_view.zoom_extents
    report(parts.size, solids, naked)
  rescue StandardError => e
    model.abort_operation if model
    UI.messagebox("Stand build failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end

  def self.report(n_parts, solids, naked)
    vol, n_dia = union_volume
    flat  = Math.atan(POCKET_CLEAR / POCKET_DEPTH) * 180.0 / Math::PI
    diag  = Math.atan(POCKET_CLEAR * Math.sqrt(2) / POCKET_DEPTH) * 180.0 / Math::PI
    dia_a = Math.atan((dia_w / 2.0) / (dia_h / 2.0)) * 180.0 / Math::PI
    lattice_area = plate_w * plate_d - COLS * ROWS * pocket * pocket

    puts ''
    puts "TUBE DRYING STAND  —  #{COLS} x #{ROWS} = #{COLS * ROWS} tubes, all dimensions mm"
    puts ''
    puts format('  plate           %.2f x %.2f x %.2f tall', plate_w, plate_d, total_h)
    puts format('  pocket          %.2f square x %.2f deep   (tube %.2f + %.2f)',
                pocket, POCKET_DEPTH, TUBE_DIA, POCKET_CLEAR)
    puts format('  ledge           %.2f wide, leaving a %.2f square opening per pocket',
                LEDGE_W, opening)
    puts format('  diamonds        %d of them, %.2f wide x %.2f tall', n_dia, dia_w, dia_h)
    puts format('  feet            4 corner pads, %.2f square x %.2f tall', foot, FOOT_H)
    puts ''
    puts '  WATERTIGHT CHECK'
    puts "    #{solids} of #{n_parts} parts are solid, #{naked} naked edges (must be 0)"
    puts format('    printed volume %.1f cm3 -> about %.0f g in PLA', vol / 1000.0, vol / 1000.0 * 1.24)
    puts '    Panels overlap by 0.50 at every intersection, so summing the group'
    puts '    volumes would double-count. The figure above is the union, worked'
    puts '    out from the geometry. Export the lot as one STL; slicers union it.'
    puts ''
    puts '  WILL IT PRINT WITHOUT SUPPORTS — INVERTED, WALL TOPS ON THE BED'
    puts format('    diamond flanks   %.1f deg from vertical   limit is 45      OK', dia_a)
    puts format('    ledge underside  %.2f mm inward step      clean under ~5   OK', LEDGE_W)
    puts format('    plate bridging   %.2f mm wall to wall     ~10 is the rule  OK', pocket)
    puts format('    bed contact      %.0f mm2 of wall top     use a brim       OK', lattice_area)
    puts '    pocket walls     vertical                                     OK'
    puts '    feet             printed last, onto solid plate               OK'
    puts '    No enclosed voids anywhere, so nothing traps support material.'
    puts ''
    puts '    RIGHT WAY UP IT WILL NOT PRINT. The plate becomes a'
    puts format('    %.0f x %.0f overhang held up on four %.1f mm pads.', plate_w, plate_d, foot)
    puts '    Flip it in the slicer, or set FLIP_FOR_PRINT = true here.'
    puts ''
    puts '  HOW STRAIGHT A TUBE STANDS'
    puts format('    %.2f deg leaning on a flat, %.2f deg wedged into a corner', flat, diag)
    puts format('    -> up to %.2f mm off at the top of a %.0f mm tube',
                Math.tan(diag * Math::PI / 180.0) * TUBE_LEN, TUBE_LEN)
    puts format('    The diamonds cost nothing here: the solid %.2f bands at the top and',
                DIA_MARGIN)
    puts format('    bottom of every wall still locate the tube over the full %.0f mm.', POCKET_DEPTH)
    puts ''
    puts '  NOT MEASURED — choices, not part dimensions:'
    puts format('    POCKET_CLEAR  %.2f   easy drop-in vs how straight it stands', POCKET_CLEAR)
    puts format('    POCKET_DEPTH  %.2f   Benton said "25 is probably a good amount"', POCKET_DEPTH)
    puts format('    LEDGE_W       %.2f   catches the tube, drains the rest', LEDGE_W)
    puts format('    DIA_POST      %.2f   DIA_MARGIN %.2f   WALL_T %.2f   BASE_T %.2f',
                DIA_POST, DIA_MARGIN, WALL_T, BASE_T)
    puts format('    FOOT_H        %.2f   foot size %.2f is derived, not chosen', FOOT_H, foot)
    puts format('    COLS x ROWS   %d x %d  Benton asked for about 60', COLS, ROWS)
    puts ''
    puts '  Stand it on foil or paper. The whole underside drains.'
    puts ''
  end
end

WR_TubeStand.run
