# @title Tube Drying Stand...
#
# A 3D-printable rack that stands 60 polycarbonate tubes upright while the
# epoxy cures. Square pockets on a grid, a drain hole under each one, and
# channels underneath so what runs through has somewhere to go.
#
#   pocket walls  ####  ####  ####  ####     <- WALL_H tall, locates the tube
#   base plate    ################????###    <- BASE_T, drain hole per cell
#   drain ribs    ##      ##      ##         <- RIB_H, epoxy runs out the ends
#   --------------------------------------- bench
#
# Square pockets rather than round on purpose: a square hole prints to size
# without the first-layer squeeze a round one gets, and the tube only ever
# touches four wall midpoints, so there is less to bind on going in.
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
  POCKET_CLEAR =  0.50    # added to the tube dia to get the square pocket side.
                          # This is the number that decides how straight a tube
                          # stands — see the lean figure the script prints.
  POCKET_DEPTH = 25.00    # wall height. The other half of the lean equation,
                          # and the cheaper one to change: deeper is straighter.
  WALL_T       =  2.00    # grid wall thickness. 1.60 saves about 20% of the
                          # plastic and still prints solid on a 0.4 nozzle.

  # ---------------------------------------------------------- base and drain --
  BASE_T       =  2.50    # plate under the pockets
  DRAIN_DIA    =  5.00    # hole in each pocket floor. Must stay well under
                          # TUBE_DIA or a tube drops through — the script checks.
  RIB_H        =  4.00    # standoff under the plate, so epoxy runs out
  RIB_T        =  2.00    # ribs sit directly under the grid walls

  # ---------------------------------------------------------------- reference --
  SHOW_TUBES   = true     # translucent ghost tubes, not printed
  TUBE_SEGS    = 16

  # ------------------------------------------------------------------ derived --
  def self.pocket;  TUBE_DIA + POCKET_CLEAR;        end
  def self.pitch;   pocket + WALL_T;                end
  def self.plate_w; COLS * pitch + WALL_T;          end
  def self.plate_d; ROWS * pitch + WALL_T;          end
  def self.total_h; RIB_H + BASE_T + POCKET_DEPTH;  end
  def self.base_z;  RIB_H;                          end
  def self.floor_z; RIB_H + BASE_T;                 end

  # Overlap between the three stacked pieces. They are separate solids that the
  # slicer unions; overlapping them by a hair avoids coincident faces, which is
  # the one thing slicers are genuinely bad at.
  OVERLAP = 0.50

  # Lower-left corner of pocket [c, r]. Walls are WALL_T thick, so the first
  # pocket starts one wall in.
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

  def self.p3(x, y, z)
    Geom::Point3d.new(x.mm, y.mm, z.mm)
  end

  def self.rect(x0, y0, x1, y1, z)
    [p3(x0, y0, z), p3(x1, y0, z), p3(x1, y1, z), p3(x0, y1, z)]
  end

  # A plain box. Used for the ribs.
  def self.box(parent, x0, y0, z0, dx, dy, dz, name)
    g = parent.entities.add_group
    f = g.entities.add_face(rect(x0, y0, x0 + dx, y0 + dy, z0))
    return nil if f.nil?
    f.reverse! if f.normal.z < 0
    f.pushpull(dz.mm)
    g.name = name
    g
  end

  # Build a plate with holes in one shot: lay the outer face, cut every hole
  # into it, throw away the offcuts, extrude what's left. Whatever is removed
  # stays behind as an inner loop, so the extrusion comes out as one solid with
  # real holes rather than a stack of overlapping boxes.
  #
  # The keeper is always the largest face — the plate dwarfs any single hole.
  def self.plate_with_holes(parent, z0, thickness, name)
    g = parent.entities.add_group
    e = g.entities
    outer = e.add_face(rect(0, 0, plate_w, plate_d, z0))
    return nil if outer.nil?

    yield e, z0                       # caller cuts the holes

    faces = e.grep(Sketchup::Face)
    keep  = faces.max_by(&:area)
    (faces - [keep]).each { |f| f.erase! if f.valid? }
    keep.reverse! if keep.normal.z < 0
    keep.pushpull(thickness.mm)
    g.name = name
    g
  end

  def self.build(parent)
    # 1. Base plate, one drain hole per cell.
    base = plate_with_holes(parent, base_z, BASE_T, 'Base plate') do |e, z|
      cells.each do |c, r|
        cx, cy = pocket_centre(c, r)
        e.add_circle(p3(cx, cy, z), Z_AXIS, (DRAIN_DIA / 2.0).mm, 24)
      end
    end

    # 2. The pocket grid — the same trick, cutting squares instead of circles.
    #    What survives IS the lattice of walls.
    grid = plate_with_holes(parent, floor_z - OVERLAP, POCKET_DEPTH + OVERLAP, 'Pocket grid') do |e, z|
      cells.each do |c, r|
        x, y = pocket_origin(c, r)
        e.add_face(rect(x, y, x + pocket, y + pocket, z))
      end
    end

    # 3. Ribs, directly under the grid walls that run the long way, so the load
    #    path is straight down and the plate only ever bridges one pocket width.
    ribs = []
    (ROWS + 1).times do |r|
      y = r * pitch
      ribs << box(parent, 0, y, 0, plate_w, RIB_T, RIB_H + OVERLAP, "Drain rib #{r + 1}")
    end

    [base, grid, ribs.compact]
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
      g
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

  def self.run
    if DRAIN_DIA >= TUBE_DIA - 1.0
      UI.messagebox("DRAIN_DIA #{DRAIN_DIA} is too close to TUBE_DIA #{TUBE_DIA}.\n" \
                    "The tubes would drop through. Keep at least 1 mm of ledge.")
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
    t_dim   = tag(model, 'STAND-Dims',  [ 40,  40,  40])

    root = model.entities.add_group
    root.name = "Tube drying stand #{COLS}x#{ROWS}"

    base, grid, ribs = build(root)
    parts = ([base, grid] + ribs).compact
    parts.each { |g| g.layer = t_stand }

    solids = parts.count { |g| g.manifold? }
    naked  = parts.map { |g| naked_edges(g) }.inject(0, :+)
    one    = 1.0.mm.to_f
    vol    = parts.select(&:manifold?).map { |g| g.volume / (one * one * one) }.inject(0.0, :+)

    if SHOW_TUBES
      gt = root.entities.add_group
      gt.name = 'Ghost tubes'
      ghost_tubes(model, gt)
      gt.layer = t_ref
    end

    dimension(model, t_dim)

    model.commit_operation
    model.active_view.zoom_extents
    report(parts.size, solids, naked, vol)
  rescue StandardError => e
    model.abort_operation if model
    UI.messagebox("Stand build failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end

  def self.dimension(model, layer)
    e = model.entities
    d = []
    d << e.add_dimension_linear(p3(0, 0, 0), p3(plate_w, 0, 0),
                                Geom::Vector3d.new(0, -14.mm, 0))
    d << e.add_dimension_linear(p3(0, 0, 0), p3(0, plate_d, 0),
                                Geom::Vector3d.new(-14.mm, 0, 0))
    d << e.add_dimension_linear(p3(0, 0, 0), p3(0, 0, total_h),
                                Geom::Vector3d.new(-28.mm, 0, 0))
    x, y = pocket_origin(0, 0)
    d << e.add_dimension_linear(p3(x, y, floor_z), p3(x + pocket, y, floor_z),
                                Geom::Vector3d.new(0, -6.mm, 0))
    d << e.add_dimension_linear(p3(x, y, floor_z), p3(x + pitch, y, floor_z),
                                Geom::Vector3d.new(0, -22.mm, 0))
    d.compact.each { |dim| dim.layer = layer }
  rescue StandardError => err
    puts "  (dimensions skipped: #{err.message})"
  end

  def self.report(n_parts, solids, naked, vol)
    # How far off vertical a tube can actually sit. The pocket is square and the
    # tube round, so the worst case is the tube wedged corner to corner, which
    # is the diagonal of the clearance square, not the clearance itself.
    flat  = Math.atan(POCKET_CLEAR / POCKET_DEPTH) * 180.0 / Math::PI
    diag  = Math.atan(POCKET_CLEAR * Math.sqrt(2) / POCKET_DEPTH) * 180.0 / Math::PI
    tip_f = Math.tan(flat * Math::PI / 180.0) * TUBE_LEN
    tip_d = Math.tan(diag * Math::PI / 180.0) * TUBE_LEN
    ledge = (TUBE_DIA - DRAIN_DIA) / 2.0

    puts ''
    puts "TUBE DRYING STAND  —  #{COLS} x #{ROWS} = #{COLS * ROWS} tubes, all dimensions mm"
    puts ''
    puts format('  plate           %.2f x %.2f x %.2f tall', plate_w, plate_d, total_h)
    puts format('  pocket          %.2f square x %.2f deep   (tube %.2f + %.2f)',
                pocket, POCKET_DEPTH, TUBE_DIA, POCKET_CLEAR)
    puts format('  pitch           %.2f   walls %.2f thick', pitch, WALL_T)
    puts format('  drain hole      %.2f dia, leaving a %.2f mm ledge for the tube to sit on',
                DRAIN_DIA, ledge)
    puts format('  ribs            %d x %.2f wide x %.2f tall, channels open at both ends',
                ROWS + 1, RIB_T, RIB_H)
    puts ''
    puts '  WATERTIGHT CHECK'
    puts "    #{solids} of #{n_parts} parts are solid, #{naked} naked edges (must be 0)"
    puts format('    volume %.1f cm3  -> about %.0f g in PLA at 1.24 g/cm3', vol / 1000.0, vol / 1000.0 * 1.24)
    puts '    Three stacked solids (plate, grid, ribs), overlapping by 0.50 mm.'
    puts '    Every slicer unions overlapping bodies — export the lot as one STL.'
    puts ''
    puts '  HOW STRAIGHT A TUBE ACTUALLY STANDS'
    puts format('    %.2f deg if it leans against a flat  -> %.2f mm off at the top of the tube', flat, tip_f)
    puts format('    %.2f deg if it wedges into a corner  -> %.2f mm off at the top of the tube', diag, tip_d)
    puts '    POCKET_DEPTH is the cheap lever: the lean is clearance over depth, so'
    puts format('    going to %.0f mm deep would bring the worst case to %.2f deg.',
                POCKET_DEPTH + 10, Math.atan(POCKET_CLEAR * Math.sqrt(2) / (POCKET_DEPTH + 10)) * 180.0 / Math::PI)
    puts '    Tightening POCKET_CLEAR works too but costs you the easy drop-in.'
    puts ''
    puts '  PRINTING'
    puts '    Flat, as drawn, pockets up. Nothing needs support: the pockets are'
    puts format('    vertical, and the plate only ever bridges %.2f mm between ribs.', pocket)
    puts '    First layer is the rib bottoms only, so it wants a brim.'
    puts format('    Biggest levers on print time: POCKET_DEPTH (%.0f mm is %.0f%% of the plastic)',
                POCKET_DEPTH, 100.0 * ((plate_w * plate_d - COLS * ROWS * pocket * pocket) * POCKET_DEPTH) / (vol.zero? ? 1 : vol))
    puts '    and WALL_T. Dropping WALL_T to 1.60 still prints fully solid on a 0.4 nozzle.'
    puts ''
    puts '  NOT MEASURED — choices, not part dimensions:'
    puts format('    POCKET_CLEAR  %.2f   easy drop-in vs how straight it stands', POCKET_CLEAR)
    puts format('    POCKET_DEPTH  %.2f   Benton said "25 is probably a good amount"', POCKET_DEPTH)
    puts format('    WALL_T        %.2f   BASE_T %.2f   RIB_H %.2f   RIB_T %.2f', WALL_T, BASE_T, RIB_H, RIB_T)
    puts format('    DRAIN_DIA     %.2f   big enough to drain, small enough to hold', DRAIN_DIA)
    puts format('    COLS x ROWS   %d x %d  Benton asked for about 60', COLS, ROWS)
    puts ''
    puts '  Stand it on foil or paper. The channels drain onto whatever is underneath.'
    puts ''
  end
end

WR_TubeStand.run
