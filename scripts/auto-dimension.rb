# @title Dimension the room...
# @cat Add dimensions
# @ability Dimensioned
# @ability-blurb Chain-dimension the room; switch off to remove what it drew.
# @on  WR_AutoDimension.ability_on(opts)
# @off WR_AutoDimension.ability_off(opts)
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
#   4. ONE COORDINATE SPACE, and it is the world. A face inside a group stores
#      its vertices in that group's own space; the dimensions are drawn into
#      model.entities, which is world. Reading one and drawing in the other put
#      the dimensions somewhere else entirely on any room that had been moved
#      or rotated after it was drawn, and found no floor at all on a rotated
#      one. Every face now travels with the transform that makes it world.
#
# Also callable from another script — build-room.rb finishes by using it:
#
#   $wr_suppress_autorun = true
#   load '.../auto-dimension.rb'
#   WR_AutoDimension.dimension_face(face)
#
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/auto-dimension.rb"

module WR_AutoDimension
  # Standoffs. These were 12 / 34 / 23 and sat on top of the walls — Benton,
  # 1 Sep 2026: "You're usually way too close to the walls, you have to
  # manually move them." A dimension you have to drag before you can read it
  # is not dimensioned. Room to breathe, and the three bands stay distinct so
  # the chain, the overall and the doors never collide.
  SEG_OFF   = 20.0     # segment chain, closest to the building
  OVR_OFF   = 48.0     # overall, outside the chain
  DOOR_OFF  = 33.0     # doors, between the two and on their own tag
  TOL       = 0.02     # inches — below this two points are the same point

  TAG_DIM   = 'WR-Dims'.freeze
  TAG_DOOR  = 'WR-Dims-Doors'.freeze
  SRC_DOOR  = 'WR-Doors'.freeze   # what the script reads doors from

  # The two tags THIS script draws on, and the only two it may ever erase.
  #
  # This list exists because a PREFIX TEST ON A SHARED NAMESPACE is what broke:
  # ownership used to be `name.start_with?('WR-Dims')`, which was true when this
  # was the only dimension tool. It is not any more — dimension-booth.rb draws on
  # WR-Dims-Booth and dimension-selection.rb on WR-Dims-Selection — so toggling
  # this ability off silently erased both of their work, and left behind
  # dimension-booth.rb's Sketchup::Text label still asserting figures whose
  # strings were gone. A wrong-looking drawing, which is the expensive kind.
  #
  # So: exact membership, never a prefix. When a fifth WR-Dims-* tag turns up it
  # belongs to whoever draws it, and this list should not change.
  OWN_TAGS  = [TAG_DIM, TAG_DOOR].freeze

  def self.own_tag?(name)
    OWN_TAGS.include?(name.to_s)
  end

  # ------------------------------------------------------------------ finding --

  # The floor face: the largest horizontal face at the lowest level in whatever
  # was handed to us. Lowest, so a ceiling can never win.
  #
  # Returns [face, transform], NOT a bare face. The transform carries that
  # face's own geometry into WORLD coordinates, and it is the whole reason this
  # returns a pair.
  #
  # WHY: a face that lives inside a group or component stores its vertices in
  # that container's OWN coordinate system, not the model's. SketchUp says so
  # by giving Face#area an optional transformation argument "to correct for a
  # parent group's transformation" — an argument that would be meaningless if
  # the geometry were already world. So for a room group that has been moved,
  # rotated or scaled since it was drawn, every vertex, normal and bounding box
  # read off its faces is in a space that is NOT the space model.entities draws
  # dimensions in. The dimensions then land somewhere else entirely, or the
  # floor is not recognised as horizontal at all and nothing is found.
  #
  # It is silent rather than loud because a freshly drawn group has an identity
  # transformation — build-room.rb dimensions its room microseconds after
  # creating it, so the two spaces coincide and everything looks correct.
  def self.floor_face(model)
    pool = []
    sel = model.selection
    src = sel.empty? ? model.entities : sel.to_a
    collect(src, pool, 0, Geom::Transformation.new)
    flat = pool.select do |f, tr|
      f.normal.transform(tr).parallel?(Z_AXIS) && f.area(tr) > 100.0
    end
    return nil if flat.empty?
    lowest = flat.map { |f, tr| world_z(f, tr) }.min
    flat.select { |f, tr| (world_z(f, tr) - lowest).abs < 1.0 }
        .max_by { |f, tr| f.area(tr) }
  end

  # Plan height of a face already known to be horizontal in world space: every
  # vertex of it shares that height, so one transformed vertex is the whole
  # answer. Reading f.bounds.min.z would be wrong twice over — the bounds are
  # in the face's own local space, and under a rotated container a bounding
  # box's min corner is no longer the min corner of anything.
  def self.world_z(face, tr)
    v = face.outer_loop.vertices.first
    return 0.0 unless v
    v.position.transform(tr).z.to_f
  end

  # `tr` accumulates every container transform from the root down, so the pair
  # pushed at depth N carries the full local -> world product. Composition is
  # parent * child because SketchUp applies `t * point` to the point, so in
  # (parent * child) * point the child's transform is applied first — which is
  # the order the nesting means. The same idiom is used by probe-levels.rb,
  # wr-deck.rb and build-booth-components.rb in this same folder.
  def self.collect(ents, pool, depth, tr = Geom::Transformation.new)
    return if depth > 4
    ents.each do |e|
      case e
      when Sketchup::Face
        pool << [e, tr]
      when Sketchup::Group
        collect(e.entities, pool, depth + 1, tr * e.transformation)
      when Sketchup::ComponentInstance
        collect(e.definition.entities, pool, depth + 1, tr * e.transformation)
      end
    end
  end

  # ------------------------------------------------------------------- runs --

  # Outer loop -> a list of runs, with collinear edges merged so an in-line wall
  # reads as one dimension rather than however many edges SketchUp split it into.
  # `tr` is the face's local -> world transform (identity for a face drawn
  # straight into model.entities). Applying it HERE is what puts every run, and
  # therefore every dimension, door hit and overall, into one single space.
  def self.runs_of(face, tr = Geom::Transformation.new)
    pts = face.outer_loop.vertices.map { |v| v.position.transform(tr) }
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

  # A tag this script is ABOUT TO DRAW ON IS FORCED VISIBLE, and that is not a
  # nicety — it is the difference between working and appearing not to.
  #
  # A SketchUp scene stores tag visibility, and proposal-scenes.rb deliberately
  # hides WR-Dims and WR-Dims-Doors on four of its five customer plates. So
  # selecting any plate but 02-dimensioned leaves both tags hidden MODEL-WIDE.
  # Drawing onto a hidden tag then produces the worst outcome available: every
  # dimension is created correctly, the console prints a clean report, the
  # panel says the switch is on — and the viewport shows nothing whatsoever.
  # "I clicked it and nothing happened", with no error anywhere to find.
  #
  # Unhiding is also the honest thing to do: the tag is hidden because a scene
  # said so, not because anyone asked for these dimensions to be invisible. It
  # is said out loud on the console so the scene's own state is not changed
  # behind anyone's back without a trace.
  def self.tag(model, name, rgb)
    l = model.layers[name] || model.layers.add(name)
    (l.color = Sketchup::Color.new(*rgb)) rescue nil
    begin
      unless l.visible?
        l.visible = true
        puts "AUTO DIMENSION — tag #{name} was HIDDEN (a proposal scene hides it on " \
             'four of five plates). Switched back on, or the dimensions would have ' \
             'been drawn invisibly.'
      end
    rescue StandardError
      nil
    end
    l
  end

  # ------------------------------------------------------- attached dimensions --
  #
  # A dimension built from two bare Point3d values is UNATTACHED: SketchUp
  # stores the coordinates and nothing else. It does not know which wall it
  # measures, it does not follow the wall when the wall moves, and dragging it
  # to the other side leaves its extension lines reaching back the way they
  # were. Benton, 1 Sep 2026: "it's all disconnected. It's not actually
  # connected to the walls ... it's kind of shitty."
  #
  # add_dimension_linear also takes ATTACHED references — a Vertex, an Edge, a
  # ConstructionPoint, or [instance_path, one of those] for geometry inside a
  # group. Given one, SketchUp owns the relationship: the dimension follows the
  # geometry, reports its real length, and re-derives its extension lines from
  # the attachment whenever it is moved.
  #
  # So every point we dimension is resolved to a real entity first. Room
  # corners resolve to the floor face's own vertices. Door jambs fall on the
  # middle of an edge where no vertex exists, so a ConstructionPoint is made
  # there and attached to — a real entity in the same container, which moves
  # with the room.
  #
  # WHAT HAPPENS WHEN IT CANNOT ATTACH. It falls back to the bare point, which
  # is what every dimension used to be, and it is COUNTED. The report says how
  # many are floating rather than letting a silent regression look like
  # success.
  ATTACH_TOL = 0.02   # inches; the traced runs are transformed floats

  # Vertex lookup for one face, keyed loosely by transformed position.
  def self.vertex_index(face, tr)
    idx = []
    face.outer_loop.vertices.each { |v| idx << [v.position.transform(tr), v] }
    idx
  rescue StandardError
    []
  end

  # The attachable reference for a point, or nil. `path` is an InstancePath (or
  # array of instances) when the face lives inside a group; nil when it is
  # loose in model.entities.
  def self.attach_for(pt, idx, path)
    hit = nil
    idx.each do |pos, v|
      if pos.distance(pt) <= ATTACH_TOL
        hit = v
        break
      end
    end
    return nil unless hit
    path ? [path, hit] : hit
  end

  # A ConstructionPoint to hang a mid-wall dimension (a door jamb) on. Made in
  # the same entities as the geometry so it travels with it.
  def self.cpoint_for(ents, pt, path, tag)
    cp = ents.add_cpoint(pt)
    return nil unless cp
    cp.layer = tag if tag
    path ? [path, cp] : cp
  rescue StandardError
    nil
  end

  # a/b may be a Point3d or an already-resolved attachment reference.
  def self.dim(ents, a, b, vec, layer)
    d = ents.add_dimension_linear(a, b, vec)
    return nil unless d
    d.layer = layer
    # An attached dimension must never be allowed to show a typed-in string:
    # the whole point is that it reports what the geometry actually measures.
    (d.text = '') rescue nil
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

  # World-space bounding box of the traced perimeter. For a floor face the
  # outer loop IS the extent, so this equals face.bounds under an identity
  # transform and stays correct under any other.
  def self.bounds_of(runs)
    bb = Geom::BoundingBox.new
    runs.each { |r| bb.add(r[:a]); bb.add(r[:b]) }
    bb
  end

  # ---------------------------------------------------------------- the work --

  # Public: dimension one floor face. build-room.rb calls this directly.
  #
  # opts[:transform] is the face's local -> world transform. It defaults to
  # identity, which is exactly right for build-room.rb: it hands over a face in
  # a group it created moments earlier, whose transformation is still identity.
  def self.dimension_face(face, opts = {})
    model = face.model
    tr    = opts[:transform] || Geom::Transformation.new
    runs  = runs_of(face, tr)
    raise 'could not read a closed outer loop off that face' if runs.size < 3

    ccw = signed_area(runs) > 0
    # The overall must be measured in the same space the chain was, so it comes
    # off the transformed runs and not off face.bounds, which is local.
    bb  = bounds_of(runs)
    ents = model.entities

    t_dim  = tag(model, TAG_DIM,  [40, 40, 40])
    t_door = tag(model, TAG_DOOR, [238, 98, 22])

    # Attachment context. opts[:path] is the InstancePath to the face when it
    # lives in a group; nil means the face is loose in model.entities and a
    # bare Vertex is the right reference.
    path = opts[:path]
    vidx = vertex_index(face, tr)

    made = 0
    loose = 0
    table = []
    at = lambda do |pt|
      r = attach_for(pt, vidx, path)
      loose += 1 if r.nil?
      r || pt
    end

    # 1. The segment chain — one dimension per in-line run, on every side.
    runs.each_with_index do |r, i|
      n = outward(r, ccw)
      off = Geom::Vector3d.new(n.x * SEG_OFF, n.y * SEG_OFF, 0)
      made += 1 if dim(ents, at.call(r[:a]), at.call(r[:b]), off, t_dim)
      table << [i + 1, r[:vec].length.to_f, direction_of(r[:vec])]
    end

    # 2. The overall, outside the chain. Two dimensions, not a bounding box.
    z = bb.min.z
    ox = OVR_OFF
    made += 1 if dim(ents,
                     at.call(Geom::Point3d.new(bb.min.x, bb.min.y, z)),
                     at.call(Geom::Point3d.new(bb.max.x, bb.min.y, z)),
                     Geom::Vector3d.new(0, -ox, 0), t_dim)
    made += 1 if dim(ents,
                     at.call(Geom::Point3d.new(bb.min.x, bb.min.y, z)),
                     at.call(Geom::Point3d.new(bb.min.x, bb.max.y, z)),
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
      # The jambs are mid-edge, so there is no vertex to attach to: give them
      # construction points on the door tag, which move with the room.
      c0 = cpoint_for(ents, j0, path, t_door) || j0
      c1 = cpoint_for(ents, j1, path, t_door) || j1
      made += 1 if dim(ents, at.call(r[:a]), c0, off, t_door)  # corner -> near jamb
      made += 1 if dim(ents, c0, c1, off, t_door)              # opening width
      doors += 1
    end

    { :runs => runs, :table => table, :made => made, :doors => doors,
      :loose => loose,
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

  # Everything this script has ever drawn lives on one of OWN_TAGS, so it can
  # always find and remove exactly its own work — nothing a person drew, and
  # nothing another WR-Dims-* tool drew. Exact match, never a prefix.
  def self.own_dims(model)
    model.entities.grep(Sketchup::DimensionLinear)
         .select { |d| d.layer && own_tag?(d.layer.name) }
  end

  # Dimensions on some OTHER WhisperRoom dimension tag. Never touched — only
  # counted, so the person can be told they are there before this script adds
  # a second set of numbers on top of them.
  def self.other_wr_dims(model)
    model.entities.grep(Sketchup::DimensionLinear)
         .select { |d| d.layer && d.layer.name.start_with?('WR-Dims') && !own_tag?(d.layer.name) }
  end

  def self.clear_dims(model)
    dims = own_dims(model)
    return 0 if dims.empty?
    model.start_operation('Clear dimensions', true)
    n = 0
    dims.each { |d| (d.erase!; n += 1) if d.valid? }
    model.commit_operation
    n
  end

  # --- panel ability -------------------------------------------------------
  # No prompts on this path. A toggle has to be idempotent, so switching on
  # always replaces rather than asking whether to double up.

  def self.ability_on(_opts = {})
    model = Sketchup.active_model
    hit   = floor_face(model)
    if hit.nil?
      UI.messagebox("No floor face found.\n\nSelect the room (or its floor) and try again.")
      return false
    end
    face, tr = hit
    clear_dims(model)
    model.start_operation('Auto dimension', true)
    res = dimension_face(face, :transform => tr)
    model.commit_operation
    report(res)
    true
  rescue StandardError => e
    model.abort_operation if model
    UI.messagebox("Auto dimension failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    false
  end

  def self.ability_off(_opts = {})
    n = clear_dims(Sketchup.active_model)
    puts ''
    puts "AUTO DIMENSION — removed #{n} dimension(s) from #{TAG_DIM} / #{TAG_DOOR}"
    puts ''
    true
  end

  def self.run
    model = Sketchup.active_model
    hit = floor_face(model)
    if hit.nil?
      UI.messagebox("No floor face found.\n\nSelect the room (or its floor) and try again.")
      return
    end
    face, tr = hit

    # Only this script's own work is offered for erasure. Other WhisperRoom
    # dimension tools are counted and named so you know they are on the drawing,
    # then left exactly as they are — they are not this script's to remove.
    existing = own_dims(model)
    others   = other_wr_dims(model)
    other_tags = others.map { |d| d.layer.name }.uniq.sort.join(', ')
    note = ''
    unless others.empty?
      note = "\n\n#{others.size} dimension(s) on #{other_tags} belong to another " \
             'WhisperRoom tool and will NOT be touched either way.'
      puts ''
      puts "AUTO DIMENSION — #{others.size} dimension(s) from another WhisperRoom tool " \
           "(#{other_tags}) are in this model. Left untouched."
      puts ''
    end
    unless existing.empty?
      ans = UI.messagebox("#{existing.size} dimension(s) from this script " \
                          "(#{OWN_TAGS.join(' / ')}) are already in this model.\n\n" \
                          "Erase them first? (No = add alongside, which will double up.)#{note}",
                          MB_YESNOCANCEL)
      return if ans == IDCANCEL
      model.start_operation('Clear dimensions', true)
      existing.each { |d| d.erase! if d.valid? }
      model.commit_operation if ans == IDYES
      model.abort_operation if ans == IDNO
    end

    model.start_operation('Auto dimension', true)
    res = dimension_face(face, :transform => tr)
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
