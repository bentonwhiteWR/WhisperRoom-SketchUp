# @title Build Room...
# @cat Room tools
#
# Type a take-off, get a built and dimensioned room.
#
# Runs are entered the way you read them off a plan — a direction and a length
# each — and the dialog previews the polygon and tells you whether it CLOSES
# before anything is built. A take-off that does not close is the normal case,
# not the exception, and the gap is where the misread wall is.
#
# Walls are built OUTWARD from the interior polygon, so wall thickness stays
# cosmetic and changing it never moves a dimension already reported to a client.
# Outer corners are mitred by intersecting adjacent offset edges — extending
# each wall by its thickness at both ends makes them cross into an X.
#
# Doors are real openings: the wall is split around them, a header goes over,
# and the leaf is drawn open 90 degrees with its swing arc.
#
# Finishes by calling auto-dimension.rb, so the room arrives dimensioned.
#
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/build-room.rb"

require 'json'

module WR_BuildRoom
  DIR = { 'E' => [1, 0], 'W' => [-1, 0], 'N' => [0, 1], 'S' => [0, -1] }.freeze
  TOL = 0.02

  MAT_FLOOR = '0128_White'.freeze
  MAT_WALL  = '0099_LightSteelBlue'.freeze
  MAT_DOOR  = '0043_SaddleBrown'.freeze
  RGB = { MAT_FLOOR => [255, 255, 255],
          MAT_WALL  => [176, 196, 222],
          MAT_DOOR  => [139, 69, 19] }.freeze

  # ---------------------------------------------------------------- materials --

  def self.material(model, name)
    m = model.materials[name]
    return m if m
    pd = (ENV['ProgramData'] || 'C:/ProgramData').tr('\\', '/')
    %w[2026 2025 2024 2023].each do |v|
      path = File.join(pd, 'SketchUp', "SketchUp #{v}", 'SketchUp', 'Materials',
                       'Colors-Named', "#{name}.skm")
      next unless File.exist?(path)
      begin
        loaded = model.materials.load(path)
        return loaded if loaded
      rescue StandardError
      end
    end
    m = model.materials.add(name)
    m.color = Sketchup::Color.new(*(RGB[name] || [200, 200, 200]))
    m
  end

  def self.tag(model, name, rgb)
    l = model.layers[name] || model.layers.add(name)
    (l.color = Sketchup::Color.new(*rgb)) rescue nil
    l
  end

  # ------------------------------------------------------------------ geometry --

  def self.pt(x, y, z = 0.0)
    Geom::Point3d.new(x, y, z)
  end

  # Interior polygon from the run list. Returns nil if it does not close.
  def self.polygon(runs)
    pts = [pt(0, 0)]
    x = 0.0
    y = 0.0
    runs.each do |r|
      v = DIR[r['d']]
      return nil unless v
      x += v[0] * r['v'].to_f
      y += v[1] * r['v'].to_f
      pts << pt(x, y)
    end
    return nil if x.abs > TOL || y.abs > TOL
    pts.pop                                    # last point IS the first
    pts
  end

  def self.signed_area(pts)
    a = 0.0
    n = pts.size
    n.times { |i| j = (i + 1) % n; a += pts[i].x * pts[j].y - pts[j].x * pts[i].y }
    a / 2.0
  end

  # Outward normal of edge i, from the winding rather than assumed.
  def self.outward(pts, i, ccw)
    j = (i + 1) % pts.size
    v = pts[j] - pts[i]
    n = ccw ? Geom::Vector3d.new(v.y, -v.x, 0) : Geom::Vector3d.new(-v.y, v.x, 0)
    n.length > 0 ? n.normalize : Geom::Vector3d.new(0, -1, 0)
  end

  # The mitred outer polygon: each outer vertex is where the two adjacent
  # offset edges actually cross. This is the bit that stops walls overshooting
  # into an X at every corner.
  def self.mitre(pts, ccw, t)
    n = pts.size
    out = []
    n.times do |i|
      prev = (i - 1 + n) % n
      np = outward(pts, prev, ccw)
      nc = outward(pts, i, ccw)
      a0 = pts[prev].offset(np, t)
      a1 = pts[i].offset(np, t)
      b0 = pts[i].offset(nc, t)
      b1 = pts[(i + 1) % n].offset(nc, t)
      hit = Geom.intersect_line_line([a0, a1 - a0], [b0, b1 - b0])
      out << (hit || pts[i].offset(nc, t))     # parallel edges: fall back square
    end
    out
  end

  # ----------------------------------------------------------------- building --

  def self.quad(ents, p, z0, z1)
    f = ents.add_face(p.map { |q| pt(q.x, q.y, z0) })
    return nil if f.nil?
    f.reverse! if f.normal.z < 0
    f.pushpull(z1 - z0)
    f
  end

  # One run's wall, split around any doors on it. Sub-segments that ARE an
  # opening get built from the door head up, which is the header.
  def self.wall_run(parent, pts, outer, i, ccw, thick, ceil, doors, door_h)
    n = pts.size
    a = pts[i]
    b = pts[(i + 1) % n]
    u = (b - a)
    len = u.length.to_f
    return 0 if len < TOL
    u = u.normalize
    nv = outward(pts, i, ccw)

    cuts = doors.select { |d| d['run'].to_i == i }
                .map { |d| [d['at'].to_f, d['at'].to_f + d['w'].to_f] }
                .select { |s, e| s > TOL && e < len - TOL }
                .sort_by { |s, _| s }

    spans = []
    cursor = 0.0
    cuts.each do |s, e|
      spans << [cursor, s, :wall] if s - cursor > TOL
      spans << [s, e, :opening]
      cursor = e
    end
    spans << [cursor, len, :wall] if len - cursor > TOL

    built = 0
    spans.each do |s, e, kind|
      # Use the mitre point at a real corner; a square face at a door jamb.
      o0 = (s <= TOL)       ? outer[i]           : a.offset(u, s).offset(nv, thick)
      o1 = (e >= len - TOL) ? outer[(i + 1) % n] : a.offset(u, e).offset(nv, thick)
      poly = [a.offset(u, s), a.offset(u, e), o1, o0]
      g = parent.entities.add_group
      ok = if kind == :opening
             quad(g.entities, poly, door_h, ceil)
           else
             quad(g.entities, poly, 0.0, ceil)
           end
      if ok
        g.name = (kind == :opening ? "Header #{i + 1}" : "Wall #{i + 1}")
        built += 1
      else
        g.erase! if g.valid?
      end
    end
    built
  end

  # The opening marker is what auto-dimension.rb reads to find the jambs, so it
  # sits exactly in the wall plane and spans exactly the opening. The leaf and
  # its swing go on their own tag — a leaf swung 90 degrees has bounds that
  # reach into the room and would give the wrong jamb.
  def self.door(parent, pts, i, ccw, thick, at, w, door_h, hinge, t_door, t_leaf, mat)
    n = pts.size
    a = pts[i]
    b = pts[(i + 1) % n]
    u = (b - a).normalize
    nv = outward(pts, i, ccw)

    j0 = a.offset(u, at)
    j1 = a.offset(u, at + w)

    g = parent.entities.add_group
    f = g.entities.add_face([j0, j1, j1.offset(nv, thick), j0.offset(nv, thick)])
    if f
      f.reverse! if f.normal.z < 0
      g.name = "Opening #{i + 1}"
      g.layer = t_door
    else
      g.erase! if g.valid?
    end

    # Leaf, open 90 degrees on the hinge side, swinging into the room.
    inward = Geom::Vector3d.new(-nv.x, -nv.y, 0)
    pivot  = (hinge == 'far') ? j1 : j0
    swing  = (hinge == 'far') ? -1.0 : 1.0
    tip    = pivot.offset(inward, w)
    lg = parent.entities.add_group
    lf = lg.entities.add_face([pivot, tip,
                               tip.offset(u, 1.5 * swing),
                               pivot.offset(u, 1.5 * swing)])
    if lf
      lf.reverse! if lf.normal.z < 0
      lf.pushpull(door_h)
      lg.name = "Door leaf #{i + 1}"
      lg.layer = t_leaf
      lg.material = mat
    else
      lg.erase! if lg.valid?
    end

    # Swing arc, from the closed jamb round to the open leaf.
    ag = parent.entities.add_group
    begin
      closed = (hinge == 'far') ? j0 : j1
      vec = closed - pivot
      steps = 12
      arc = (0..steps).map do |k|
        ang = (Math::PI / 2.0) * k / steps * ((hinge == 'far') ? -1.0 : 1.0)
        tr = Geom::Transformation.rotation(pivot, Z_AXIS, ang)
        pivot.offset(vec).transform(tr)
      end
      arc.each_cons(2) { |p, q| ag.entities.add_line(p, q) }
      ag.name = "Swing #{i + 1}"
      ag.layer = t_leaf
    rescue StandardError
      ag.erase! if ag.valid?
    end
  end

  # ---------------------------------------------------------------------- run --

  def self.build(cfg)
    model = Sketchup.active_model
    runs  = cfg['runs'] || []
    doors = cfg['doors'] || []
    thick = cfg['thick'].to_f
    thick = 4.0 if thick <= 0
    ceil  = cfg['ceil'].to_f
    ceil  = 96.0 if ceil <= 0
    door_h = cfg['door_h'].to_f
    door_h = 80.0 if door_h <= 0
    house = (ceil - 96.0).abs < TOL

    pts = polygon(runs)
    if pts.nil?
      UI.messagebox("Those runs do not close. Fix the take-off first —\n" \
                    "a chain that does not close means a wall face was misread.")
      return
    end

    begin
      model.options['UnitsOptions']['LengthFormat'] = Length::Architectural
    rescue StandardError
    end

    model.start_operation('Build room', true)
    ccw = signed_area(pts) > 0
    outer = mitre(pts, ccw, thick)

    t_floor = tag(model, 'WR-Floor', [230, 230, 230])
    t_wall  = tag(model, 'WR-Room',  [120, 128, 140])
    t_door  = tag(model, 'WR-Doors', [238, 98, 22])
    t_leaf  = tag(model, 'WR-Doors-Leaf', [200, 130, 60])
    t_note  = tag(model, 'WR-Notes', [90, 90, 96])

    room = model.entities.add_group
    room.name = cfg['name'].to_s.strip.empty? ? 'Room' : cfg['name'].to_s.strip

    # Floor, from the interior polygon — the measured polygon is the truth.
    fg = room.entities.add_group
    floor = fg.entities.add_face(pts)
    if floor
      floor.reverse! if floor.normal.z < 0
      fg.name = 'Floor'
      fg.layer = t_floor
      fg.material = material(model, MAT_FLOOR)
    end

    wg = room.entities.add_group
    wg.name = 'Walls'
    wg.layer = t_wall
    walls = 0
    pts.size.times { |i| walls += wall_run(wg, pts, outer, i, ccw, thick, ceil, doors, door_h) }
    wg.material = material(model, MAT_WALL)

    dg = room.entities.add_group
    dg.name = 'Doors'
    mat_door = material(model, MAT_DOOR)
    doors.each do |d|
      i = d['run'].to_i
      next unless i >= 0 && i < pts.size
      door(dg, pts, i, ccw, thick, d['at'].to_f, d['w'].to_f, door_h,
           d['hinge'].to_s, t_door, t_leaf, mat_door)
    end

    # The ceiling height is the thing that disqualifies a booth fastest, so if
    # it is the house default it gets said on the drawing, not just in chat.
    if house
      begin
        bb = floor ? floor.bounds : room.bounds
        note = model.entities.add_text(
          "Ceiling 8'-0\" — HOUSE DEFAULT, not measured. Confirm before quoting.",
          Geom::Point3d.new(bb.min.x, bb.max.y + 20.0, 0))
        note.layer = t_note
      rescue StandardError
      end
    end

    model.commit_operation

    # Finish by dimensioning it. This is the whole reason auto-dimension.rb
    # was built first.
    dims = nil
    if floor
      begin
        $wr_suppress_autorun = true
        load File.join(File.dirname(__FILE__), 'auto-dimension.rb')
        model.start_operation('Dimension room', true)
        dims = WR_AutoDimension.dimension_face(floor)
        model.commit_operation
      rescue StandardError => e
        model.abort_operation
        puts "  (dimensioning skipped: #{e.class}: #{e.message})"
      ensure
        $wr_suppress_autorun = false
      end
    end

    model.active_view.zoom_extents
    report(pts, walls, doors.size, ceil, thick, house, dims)
  rescue StandardError => e
    model.abort_operation if model
    UI.messagebox("Build room failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(6)
  end

  def self.report(pts, walls, ndoors, ceil, thick, house, dims)
    puts ''
    puts 'BUILD ROOM'
    puts ''
    puts "  #{pts.size} wall runs, #{walls} wall solids, #{ndoors} door(s)"
    puts format('  walls %.2f" thick, built OUTWARD from the interior polygon and mitred', thick)
    puts format('  ceiling %s%s', WR_AutoDimension.arch(ceil),
                house ? '  <- HOUSE DEFAULT, not measured' : '  (stated)')
    puts ''
    if dims
      WR_AutoDimension.report(dims)
    else
      puts '  Not dimensioned — run Auto Dimension on the floor face.'
      puts ''
    end
  end

  # ------------------------------------------------------------------- dialog --

  def self.open
    html = File.join(File.dirname(__FILE__), 'build-room.html')
    unless File.exist?(html)
      UI.messagebox("build-room.html is missing from\n#{File.dirname(__FILE__)}")
      return
    end
    d = UI::HtmlDialog.new(
      :dialog_title    => 'Build Room',
      :preferences_key => 'com.whisperroom.buildroom',
      :scrollable      => true, :resizable => true,
      :width => 860, :height => 640, :min_width => 520, :min_height => 420,
      :style => UI::HtmlDialog::STYLE_DIALOG
    )
    d.set_file(html)
    d.add_action_callback('build') do |_c, payload|
      begin
        build(JSON.parse(payload))
      rescue StandardError => e
        UI.messagebox("Bad payload:\n#{e.message}")
      end
      d.close
    end
    d.add_action_callback('cancel') { |_c| d.close }
    d.show
  end
end

WR_BuildRoom.open
