# @title Auto Dimension...
#
# Chain-dimension a room to the house standard: every in-line wall run on all
# four sides, an overall outside the chain, and every door off its wall corner.
#
# THE INTERIOR FLOOR FACE IS THE TRUTH. Everything is derived from its outer
# loop, so the dimensions can never disagree with the geometry.
#
# Three things this refuses to get wrong, because all three have cost time
# before (see reference/sketchup-drawing.md):
#
#   1. WINDING is computed, never assumed. Two rooms in one script wound
#      opposite ways and the hard-coded normal built one of them inward.
#   2. CHAINS MUST CLOSE and the script says so out loud, per axis. A chain
#      that does not close means a wall face was misread — better to be told
#      than to publish a plausible wrong number.
#   3. A CHAIN LINE CARRIES SEGMENT LENGTHS, never running totals. Mixing the
#      two is a real drafting error and gets read as fact.
#
# Also callable from another script — build-room.rb finishes by using it:
#
#   $wr_suppress_autorun = true
#   load '.../auto-dimension.rb'
#   WR_AutoDimension.dimension_face(face)
#
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/auto-dimension.rb"

module WR_AutoDimension
  SEG_OFF   = 12.0     # segment chain, closest to the building
  OVR_OFF   = 34.0     # overall, outside the chain
  DOOR_OFF  = 23.0     # doors, between the two and on their own tag
  TOL       = 0.02     # inches — below this two points are the same point

  TAG_DIM   = 'WR-Dims'.freeze
  TAG_DOOR  = 'WR-Dims-Doors'.freeze
  SRC_DOOR  = 'WR-Doors'.freeze   # what the script reads doors from

  # ------------------------------------------------------------------ finding --

  # The floor face: the largest horizontal face at the lowest level in whatever
  # was handed to us. Lowest, so a ceiling can never win.
  def self.floor_face(model)
    pool = []
    sel = model.selection
    src = sel.empty? ? model.entities : sel.to_a
    collect(src, pool, 0)
    flat = pool.select { |f| f.normal.parallel?(Z_AXIS) && f.area > 100.0 }
    return nil if flat.empty?
    lowest = flat.map { |f| f.bounds.min.z }.min
    flat.select { |f| (f.bounds.min.z - lowest).abs < 1.0 }.max_by(&:area)
  end

  def self.collect(ents, pool, depth)
    return if depth > 4
    ents.each do |e|
      case e
      when Sketchup::Face then pool << e
      when Sketchup::Group then collect(e.entities, pool, depth + 1)
      when Sketchup::ComponentInstance then collect(e.definition.entities, pool, depth + 1)
      end
    end
  end

  # ------------------------------------------------------------------- runs --

  # Outer loop -> a list of runs, with collinear edges merged so an in-line wall
  # reads as one dimension rather than however many edges SketchUp split it into.
  def self.runs_of(face)
    pts = face.outer_loop.vertices.map { |v| v.position }
    pts = dedupe(pts)
    return [] if pts.size < 3

    merged = []
    n = pts.size
    n.times do |i|
      a = pts[i]
      b = pts[(i + 1) % n]
      v = b - a
      next if v.length < TOL
      if !merged.empty? && merged.last[:vec].parallel?(v) &&
         merged.last[:vec].samedirection?(v)
        merged.last[:b] = b
        merged.last[:vec] = merged.last[:b] - merged.last[:a]
      else
        merged << { :a => a, :b => b, :vec => v }
      end
    end
    # The last run can be collinear with the first once the loop wraps.
    if merged.size > 2 && merged.last[:vec].parallel?(merged.first[:vec]) &&
       merged.last[:vec].samedirection?(merged.first[:vec])
      merged.first[:a] = merged.last[:a]
      merged.first[:vec] = merged.first[:b] - merged.first[:a]
      merged.pop
    end
    merged
  end

  def self.dedupe(pts)
    out = []
    pts.each { |p| out << p if out.empty? || out.last.distance(p) > TOL }
    out.pop if out.size > 1 && out.first.distance(out.last) < TOL
    out
  end

  # Signed area in plan. Its SIGN is the winding, which is the whole point —
  # it is what tells us which way is out, and it cannot be hard-coded.
  def self.signed_area(runs)
    a = 0.0
    runs.each do |r|
      a += (r[:a].x * r[:b].y - r[:b].x * r[:a].y)
    end
    a / 2.0
  end

  # Outward normal for a run, derived from the winding rather than guessed.
  def self.outward(run, ccw)
    v = run[:vec]
    n = ccw ? Geom::Vector3d.new(v.y, -v.x, 0) : Geom::Vector3d.new(-v.y, v.x, 0)
    n.length > 0 ? n.normalize : Geom::Vector3d.new(0, -1, 0)
  end

  # ------------------------------------------------------------------- output --

  def self.tag(model, name, rgb)
    l = model.layers[name] || model.layers.add(name)
    (l.color = Sketchup::Color.new(*rgb)) rescue nil
    l
  end

  def self.dim(ents, a, b, vec, layer)
    d = ents.add_dimension_linear(a, b, vec)
    d.layer = layer if d
    d
  rescue StandardError
    nil
  end

  # ---------------------------------------------------------------- the doors --

  # Doors come off the WR-Doors tag, not from looking for gaps in walls. A gap
  # might be a modelling mistake; a tagged door is a stated fact.
  def self.doors_on(model)
    out = []
    model.entities.each do |e|
      next unless e.respond_to?(:layer) && e.layer && e.layer.name == SRC_DOOR
      out << e
    end
    out
  end

  # Which run does this door sit on, and where along it? Corner -> near jamb,
  # then the opening width, which is how a booth actually gets placed.
  def self.door_on_run(door, runs)
    c = door.bounds.center
    best = nil
    runs.each_with_index do |r, i|
      v = r[:vec]
      len = v.length.to_f
      next if len < TOL
      u = v.normalize
      t = (c - r[:a]).dot(u)
      next if t < -6.0 || t > len + 6.0
      perp = ((c - r[:a]) - Geom::Vector3d.new(u.x * t, u.y * t, u.z * t)).length.to_f
      best = [perp, i, t] if best.nil? || perp < best[0]
    end
    return nil if best.nil? || best[0] > 24.0
    r = runs[best[1]]
    u = r[:vec].normalize
    # Project the door's own footprint onto the run to get both jambs.
    bb = door.bounds
    ts = [bb.min, bb.max,
          Geom::Point3d.new(bb.min.x, bb.max.y, bb.min.z),
          Geom::Point3d.new(bb.max.x, bb.min.y, bb.min.z)].map { |p| (p - r[:a]).dot(u) }
    { :run => best[1], :t0 => ts.min, :t1 => ts.max }
  end

  # ------------------------------------------------------------------ closure --

  # Segments must sum to the overall. Reported per axis, and reported as a
  # FAILURE when it fails rather than quietly drawing something plausible.
  def self.closure(runs, bb)
    ex = 0.0; wx = 0.0; ny = 0.0; sy = 0.0
    skew = 0
    runs.each do |r|
      v = r[:vec]
      if v.y.abs < TOL
        v.x > 0 ? ex += v.x : wx += -v.x
      elsif v.x.abs < TOL
        v.y > 0 ? ny += v.y : sy += -v.y
      else
        skew += 1
      end
    end
    {
      :east => ex, :west => wx, :north => ny, :south => sy,
      :dx => (ex - wx), :dy => (ny - sy),
      :overall_x => bb.width.to_f, :overall_y => bb.height.to_f,
      :gap_x => (ex - bb.width.to_f), :gap_y => (ny - bb.height.to_f),
      :skew => skew
    }
  end

  # ---------------------------------------------------------------- the work --

  # Public: dimension one floor face. build-room.rb calls this directly.
  def self.dimension_face(face, opts = {})
    model = face.model
    runs  = runs_of(face)
    raise 'could not read a closed outer loop off that face' if runs.size < 3

    ccw = signed_area(runs) > 0
    bb  = face.bounds
    ents = model.entities

    t_dim  = tag(model, TAG_DIM,  [40, 40, 40])
    t_door = tag(model, TAG_DOOR, [238, 98, 22])

    made = 0
    table = []

    # 1. The segment chain — one dimension per in-line run, on every side.
    runs.each_with_index do |r, i|
      n = outward(r, ccw)
      off = Geom::Vector3d.new(n.x * SEG_OFF, n.y * SEG_OFF, 0)
      made += 1 if dim(ents, r[:a], r[:b], off, t_dim)
      table << [i + 1, r[:vec].length.to_f, direction_of(r[:vec])]
    end

    # 2. The overall, outside the chain. Two dimensions, not a bounding box.
    z = bb.min.z
    ox = OVR_OFF
    made += 1 if dim(ents,
                     Geom::Point3d.new(bb.min.x, bb.min.y, z),
                     Geom::Point3d.new(bb.max.x, bb.min.y, z),
                     Geom::Vector3d.new(0, -ox, 0), t_dim)
    made += 1 if dim(ents,
                     Geom::Point3d.new(bb.min.x, bb.min.y, z),
                     Geom::Point3d.new(bb.min.x, bb.max.y, z),
                     Geom::Vector3d.new(-ox, 0, 0), t_dim)

    # 3. Doors, on their own tag so they read as secondary.
    doors = 0
    doors_on(model).each do |d|
      hit = door_on_run(d, runs)
      next unless hit
      r = runs[hit[:run]]
      u = r[:vec].normalize
      n = outward(r, ccw)
      off = Geom::Vector3d.new(n.x * DOOR_OFF, n.y * DOOR_OFF, 0)
      j0 = r[:a].offset(u, hit[:t0])
      j1 = r[:a].offset(u, hit[:t1])
      made += 1 if dim(ents, r[:a], j0, off, t_door)      # corner -> near jamb
      made += 1 if dim(ents, j0, j1, off, t_door)         # opening width
      doors += 1
    end

    { :runs => runs, :table => table, :made => made, :doors => doors,
      :closure => closure(runs, bb), :ccw => ccw, :bounds => bb }
  end

  def self.direction_of(v)
    return 'E' if v.y.abs < TOL && v.x > 0
    return 'W' if v.y.abs < TOL && v.x < 0
    return 'N' if v.x.abs < TOL && v.y > 0
    return 'S' if v.x.abs < TOL && v.y < 0
    'skew'
  end

  def self.arch(inches)
    neg = inches < 0
    n = inches.abs
    ft = (n / 12.0).floor
    ins = n - ft * 12.0
    s = format("%d'-%s\"", ft, (ins.round(1) % 1 == 0 ? ins.round.to_s : format('%.1f', ins)))
    neg ? "-#{s}" : s
  end

  # ------------------------------------------------------------------- entry --

  def self.run
    model = Sketchup.active_model
    face = floor_face(model)
    if face.nil?
      UI.messagebox("No floor face found.\n\nSelect the room (or its floor) and try again.")
      return
    end

    existing = model.entities.grep(Sketchup::DimensionLinear)
                    .select { |d| d.layer && d.layer.name.start_with?('WR-Dims') }
    unless existing.empty?
      ans = UI.messagebox("#{existing.size} WR-Dims dimension(s) already in this model.\n\n" \
                          "Erase them first? (No = add alongside, which will double up.)",
                          MB_YESNOCANCEL)
      return if ans == IDCANCEL
      model.start_operation('Clear dimensions', true)
      existing.each { |d| d.erase! if d.valid? }
      model.commit_operation if ans == IDYES
      model.abort_operation if ans == IDNO
    end

    model.start_operation('Auto dimension', true)
    res = dimension_face(face)
    model.commit_operation
    report(res)
  rescue StandardError => e
    model.abort_operation if model
    UI.messagebox("Auto dimension failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end

  def self.report(res)
    c = res[:closure]
    puts ''
    puts 'AUTO DIMENSION'
    puts ''
    puts "  #{res[:runs].size} wall runs, #{res[:made]} dimensions, #{res[:doors]} door(s) dimensioned"
    puts "  winding #{res[:ccw] ? 'CCW' : 'CW'} — outward normals derived from it, not assumed"
    puts ''
    puts '  RUN TABLE — precise, because the drawing rounds to the inch'
    res[:table].each do |i, len, dir|
      puts format('    %2d  %-4s %9.2f"   %s', i, dir, len, arch(len))
    end
    puts ''
    puts '  CHAIN CLOSURE — segments must sum to the overall'
    puts format('    east  %9.2f"   west  %9.2f"   difference %+.3f"', c[:east], c[:west], c[:dx])
    puts format('    north %9.2f"   south %9.2f"   difference %+.3f"', c[:north], c[:south], c[:dy])
    puts format('    overall %.2f" x %.2f"', c[:overall_x], c[:overall_y])
    puts format('    chain vs overall:  x %+.3f"   y %+.3f"', c[:gap_x], c[:gap_y])
    ok = c[:dx].abs < 0.05 && c[:dy].abs < 0.05 &&
         c[:gap_x].abs < 0.05 && c[:gap_y].abs < 0.05
    if c[:skew] > 0
      puts ''
      puts "    #{c[:skew]} run(s) are NOT axis-aligned, so the per-axis closure above"
      puts '    excludes them and does not prove anything. Check those runs by hand.'
    elsif ok
      puts '    -> CLOSES. Every chain agrees with its overall.'
    else
      puts '    -> DOES NOT CLOSE. A wall face has been misread somewhere —'
      puts '       find it before this drawing goes anywhere near a client.'
    end
    puts ''
    puts "  Dimensions on #{TAG_DIM}; doors on #{TAG_DOOR} so they read as secondary."
    puts '  Chain lines carry SEGMENT lengths. For distance from a datum, add an'
    puts '  ordinate dimension separately — never mix the two on one line.'
    puts ''
  end
end

WR_AutoDimension.run unless $wr_suppress_autorun
