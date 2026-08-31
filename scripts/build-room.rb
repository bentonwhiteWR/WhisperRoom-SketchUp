# @title Draw floor plan...
# @cat Draw the room
#
# Type a room, get it built and dimensioned.
#
# It opens on the case that is nearly always the case — a plain rectangle — so
# it asks for a length and a width and nothing else, with a Build button that
# works immediately. "More detail..." expands into the take-off: runs entered
# the way you read them off a plan, a direction and a length each, with the
# doors, the wall thickness and the room name. The dialog previews the polygon
# and tells you whether it CLOSES before anything is built. A take-off that
# does not close is the normal case, not the exception, and the gap is where
# the misread wall is.
#
# Simple mode is not a second geometry routine. Length and width become the
# four runs the take-off would have produced and go down the same build path,
# because a parallel path is how two modes silently stop agreeing. Expanding
# therefore costs nothing — the runs are already the ones being previewed.
# Collapsing back is offered only while the take-off is still a rectangle with
# no doors on it; otherwise the button says why it is off rather than dropping
# geometry quietly.
#
# Ceiling height stays on screen in both modes, pre-filled at the 8'-0" house
# default, because it is the constraint that disqualifies a booth fastest and
# the one clients forget.
#
# Dimensions are typed the way they are read — 150, 150", 12'6", 12'-6",
# 12' 6 1/2", 12.5' all parse, and a BARE NUMBER IS INCHES, which is what the
# take-off has always meant.
#
# Walls are built OUTWARD from the interior polygon, so wall thickness stays
# cosmetic and changing it never moves a dimension already reported to a client.
# That property is why the 4" default is safe to leave and safe to override in
# detail mode: the interior polygon is the measured truth and it does not move.
# Outer corners are mitred by intersecting adjacent offset edges — extending
# each wall by its thickness at both ends makes them cross into an X.
#
# Doors are real openings: the wall is split around them, a header goes over,
# and the leaf is drawn open 90 degrees with its swing arc.
#
# Finishes by calling auto-dimension.rb, so the room arrives dimensioned.
#
# TWO-BAND WALLS. Every wall run (and every door header) builds as two
# stacked solids split at a sill height, not one — a lower band from the
# floor to the sill, and an upper band from the sill to the ceiling. The
# upper band goes on its own tag, WR-Room-Upper, alongside WR-Floor,
# WR-Room, WR-Doors, WR-Doors-Leaf and WR-Notes. Hiding WR-Room-Upper on a
# scene "lowers" the walls for a ventilation render without editing any
# geometry — nothing was ever moved, so there is nothing to put back. See
# proposal-scenes.rb for the same per-scene tag-visibility pattern applied
# to the dimension tags.
#
# The split is one generic operation (see `band`, below `quad`) applied
# identically to a plain wall span and to a door header — there is no
# special case for openings. That generic rule has a real consequence for
# how a doorway looks when the upper band is hidden, and it is a look
# decision, not something this script gets to make silently:
#
#   sill height <  door head height  -> the header (door_h..ceil) falls
#     entirely at or above the sill, so it builds as ONE solid, entirely
#     on WR-Room-Upper. Hide that tag and the whole header disappears —
#     the doorway reads as a clean, open pass-through.
#
#   sill height >= door head height  -> the header straddles the sill, so
#     it SPLITS: a lower shard (door_h..sill) stays on WR-Room next to the
#     wall below it and never hides, while only the piece from sill..ceil
#     moves to WR-Room-Upper. Hiding the upper band still leaves that
#     lower shard hanging over the opening.
#
# DEFAULT_SILL (below) is picked to land in the first case, because a
# clean pass-through is the more useful default for a "see into the room"
# render. Which case Benton actually wants is still open — see the
# handoff note.
#
# The split cannot move a dimension or disturb a mitred corner: `band`
# only clips the Z range a span already had (0..ceil for a wall, or
# door_h..ceil for a header) at the sill height. The XY footprint —
# where the mitred outer polygon comes from — is computed once per wall
# run before any Z work happens and is shared unchanged by both bands.
#
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/build-room.rb"

require 'json'

module WR_BuildRoom
  DIR = { 'E' => [1, 0], 'W' => [-1, 0], 'N' => [0, 1], 'S' => [0, -1] }.freeze
  TOL = 0.02
  PREF = 'com.whisperroom.buildroom'.freeze

  # Where a wall splits into its lower (always-visible) and upper
  # (WR-Room-Upper, hideable) band. This is a GUESS, not a settled
  # convention — Benton has not yet said whether it is fixed across jobs
  # or varies per room. Change it here in one place; it is also exposed
  # per-build as cfg['sill'] from the dialog.
  DEFAULT_SILL = 48.0.freeze

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

  # Builds one wall/header span as up to two independent solids, clipped
  # from the span's own (z0, z1) at `sill`. Same footprint `poly` both
  # times, so the two stack with no gap and no overlap at the seam.
  #
  # The lower piece is left untagged (Layer0) so it inherits whatever tag
  # the caller's parent group carries (WR-Room today) exactly as a single
  # full-height span always has. The upper piece is explicitly tagged
  # `upper_tag` (WR-Room-Upper) so it hides independently of that parent.
  #
  # One span can produce zero, one or two solids: a span that never
  # reaches the sill builds lower only, one that starts at or above it
  # builds upper only, and one that straddles it builds both. That last
  # case is exactly how a door header ends up split — see the file header.
  def self.band(parent, poly, z0, z1, sill, name, upper_tag)
    built = 0
    lo0 = z0
    lo1 = [z1, sill].min
    if lo1 - lo0 > TOL
      g = parent.entities.add_group
      if quad(g.entities, poly, lo0, lo1)
        g.name = name
        built += 1
      else
        g.erase! if g.valid?
      end
    end
    hi0 = [z0, sill].max
    hi1 = z1
    if hi1 - hi0 > TOL
      g = parent.entities.add_group
      if quad(g.entities, poly, hi0, hi1)
        g.name = "#{name} (upper)"
        g.layer = upper_tag
        built += 1
      else
        g.erase! if g.valid?
      end
    end
    built
  end

  # One run's wall, split around any doors on it. Sub-segments that ARE an
  # opening get built from the door head up, which is the header. Every
  # sub-segment then splits again at `sill` into its lower and upper band
  # via `band`, above.
  def self.wall_run(parent, pts, outer, i, ccw, thick, ceil, doors, door_h, sill, upper_tag)
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
      z0, z1 = kind == :opening ? [door_h, ceil] : [0.0, ceil]
      name = kind == :opening ? "Header #{i + 1}" : "Wall #{i + 1}"
      built += band(parent, poly, z0, z1, sill, name, upper_tag)
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

  # Doors whose cut cannot be made, by name. `wall_run` drops any cut that
  # touches a corner (the mitre owns the corner), and until 1.11.0 `build`
  # still drew the leaf for it — a door leaf embedded in solid wall, silently.
  # Now the whole build refuses first, matching the closure-failure pattern.
  # Pure data in, messages out, so rbtest-takeoff.py can run it outside
  # SketchUp.
  def self.door_errors(pts, doors)
    errs = []
    n = pts.size
    doors.each_with_index do |d, j|
      i = d['run'].to_i
      unless i >= 0 && i < n
        errs << "door #{j + 1}: run #{i} does not exist (#{n} runs)"
        next
      end
      len = (pts[(i + 1) % n] - pts[i]).length.to_f
      at = d['at'].to_f
      w = d['w'].to_f
      if w <= TOL
        errs << "door #{j + 1} on run #{i}: width must be positive"
      elsif at < TOL || at + w > len - TOL
        errs << format('door %d on run %d touches the corner (at %.1f" + ' \
                       'width %.1f" vs run %.1f") — build-room cannot cut a ' \
                       'corner opening; move it or shrink it', j + 1, i, at, w, len)
      end
    end
    errs
  end

  # ---------------------------------------------------------------------- run --

  def self.build(cfg)
    model = Sketchup.active_model
    runs  = cfg['runs'] || []
    doors = cfg['doors'] || []
    thick = cfg['thick'].to_f
    thick = 4.0 if thick <= 0          # cosmetic — walls grow outward, dimensions don't move
    ceil  = cfg['ceil'].to_f
    ceil  = 96.0 if ceil <= 0
    door_h = cfg['door_h'].to_f
    door_h = 80.0 if door_h <= 0
    sill = cfg['sill'].to_f
    sill = DEFAULT_SILL if sill <= 0
    house = (ceil - 96.0).abs < TOL

    pts = polygon(runs)
    if pts.nil?
      UI.messagebox("Those runs do not close. Fix the take-off first —\n" \
                    "a chain that does not close means a wall face was misread.")
      return
    end

    bad = door_errors(pts, doors)
    unless bad.empty?
      UI.messagebox("Doors that cannot be cut — nothing was built:\n\n" +
                    bad.join("\n"))
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
    t_wall_up = tag(model, 'WR-Room-Upper', [176, 182, 190])
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
    pts.size.times { |i| walls += wall_run(wg, pts, outer, i, ccw, thick, ceil, doors, door_h, sill, t_wall_up) }
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
    report(pts, walls, doors.size, ceil, thick, house, dims, sill, door_h)
  rescue StandardError => e
    model.abort_operation if model
    UI.messagebox("Build room failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(6)
  end

  def self.report(pts, walls, ndoors, ceil, thick, house, dims, sill, door_h)
    puts ''
    puts 'BUILD ROOM'
    puts ''
    puts "  #{pts.size} wall runs, #{walls} wall solids, #{ndoors} door(s)"
    puts format('  walls %.2f" thick, built OUTWARD from the interior polygon and mitred', thick)
    puts format('  ceiling %s%s', WR_AutoDimension.arch(ceil),
                house ? '  <- HOUSE DEFAULT, not measured' : '  (stated)')
    puts format('  two-band split at %s — lower band stays on WR-Room, upper band on ' \
                'WR-Room-Upper (hide that tag to lower the walls for a render)',
                WR_AutoDimension.arch(sill))
    puts(sill < door_h - TOL \
      ? '  sill is below the door head, so door headers build ENTIRELY on WR-Room-Upper — ' \
        'hiding it leaves a clean pass-through.'
      : '  sill is at/above the door head, so door headers SPLIT — a shard stays on ' \
        'WR-Room over each opening even with WR-Room-Upper hidden.')
    puts ''
    if dims
      WR_AutoDimension.report(dims)
    else
      puts '  Not dimensioned — run Auto Dimension on the floor face.'
      puts ''
    end
  end

  # ------------------------------------------------------------------- dialog --

  def self.last_mode
    m = Sketchup.read_default(PREF, 'mode', 'simple').to_s
    m == 'detail' ? 'detail' : 'simple'
  rescue StandardError
    'simple'
  end

  def self.remember_mode(mode)
    Sketchup.write_default(PREF, 'mode', mode.to_s == 'detail' ? 'detail' : 'simple')
  rescue StandardError
    nil
  end

  def self.open
    html = File.join(File.dirname(__FILE__), 'build-room.html')
    unless File.exist?(html)
      UI.messagebox("build-room.html is missing from\n#{File.dirname(__FILE__)}")
      return
    end
    d = UI::HtmlDialog.new(
      :dialog_title    => 'Draw floor plan',
      :preferences_key => PREF,
      :scrollable      => true, :resizable => true,
      :width => 860, :height => 640, :min_width => 520, :min_height => 420,
      :style => UI::HtmlDialog::STYLE_DIALOG
    )
    d.set_file(html)
    # Someone who lives in the take-off should not be re-simplified every time
    # they open it. The dialog opens simple and is told otherwise once it is up.
    d.add_action_callback('ready') do |_c|
      begin
        d.execute_script("WR_setMode(#{last_mode.to_json})")
      rescue StandardError
      end
    end
    d.add_action_callback('build') do |_c, payload|
      begin
        cfg = JSON.parse(payload)
        remember_mode(cfg['mode'])
        build(cfg)
      rescue StandardError => e
        UI.messagebox("Bad payload:\n#{e.message}")
      end
      d.close
    end
    d.add_action_callback('cancel') { |_c| d.close }
    d.show
  end
end

WR_BuildRoom.open unless $wr_suppress_autorun || $wr_no_autorun
