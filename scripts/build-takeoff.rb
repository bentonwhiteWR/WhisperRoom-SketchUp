# @title Build from take-off...
# @cat Draw the room
#
# Every room in a validated take-off lock file, built in one go — polygons,
# doors, per-room ceiling slabs, obstruction massing, dimensions, and an
# ASSUMED note in the model at every value somebody guessed.
#
# INPUT IS THE LOCK FILE, NEVER THE TAKE-OFF ITSELF. `takeoff.lock.json` is
# what `python scripts/takeoff-check.py clients/<job>/takeoff.json` writes
# after every invariant holds (chains close, parts sum, doors have positions,
# ceilings exist). Ruby never re-parses a dimension string — the grammar
# lives in the dialog JS and the checker Python, held identical by
# scripts/takeoff-vectors.json — so everything here is float inches with the
# assumed/default flags already attached.
#
# The geometry is WR_BuildRoom's own (polygon, mitre, wall_run, door, band —
# loaded from build-room.rb with its autorun suppressed), applied per room at
# an offset. There is no second wall builder to drift.
#
# WHAT REFUSES, BY NAME (class Refused; the bridge turns a raise into
# status:"error" with this message, the panel path shows a messagebox):
#   - a lock file that is not format 1, or whose room has no closed polygon
#   - a room with no ceiling (the checker cannot emit one, but this script
#     does not trust its caller — AC-7/AC-8 force garbage past the checker)
#   - a door whose cut would touch a corner (the old silent
#     leaf-in-solid-wall defect, now a named refusal — same rule as
#     WR_BuildRoom.door_errors)
#   - two doors on one run with different heights (wall_run cuts every
#     header on a run at one height; mixed heights would build one of them
#     wrong, so the limit is stated instead of silently misbuilt)
#   - a door taller than its room's ceiling, and a bulkhead (or window sill)
#     whose underside sits at or above the ceiling. Both are impossible
#     statements a transcription error produces, and both used to yield
#     plausible-looking output instead of a refusal: the leaf built THROUGH
#     the ceiling plane, and the bulkhead massing was silently dropped by a
#     zero-height guard, so the room looked finished while missing a feature
#     the client named (eval/floorplans/synthetic-headroom, F2/F3, 31 Aug
#     2026). Same doctrine as the corner door: refuse before building.
#
# NEVER INVENT A PLACEMENT NUMBER, ENFORCED: every value the lock flags
# assumed/default gets a text note on WR-Notes at the feature itself —
# the exact pattern build-room.rb already uses for the 96" house-default
# ceiling — and the same inventory prints in the report. An invented number
# can still exist, but it cannot exist unmarked.
#
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/build-takeoff.rb"
#   WR_BuildTakeoff.build_from("C:/.../clients/uic-daley-library/takeoff.lock.json")
#
# Bridge use: set ENV['WR_TAKEOFF'] to the lock path and load with autorun
# enabled, or call build_from directly.

require 'json'

module WR_BuildTakeoff
  TOL = 0.02
  GAP = 48.0            # side-by-side spacing when the file gives no origins
  MASSING_H = 24.0      # heater massing height — a constant of the massing
                        # representation (its job is footprint), not a claim
                        # about the heater; stated in reference/takeoff-format.md
  SLAB = 4.0            # ceiling slab thickness, cosmetic like wall thickness

  class Refused < StandardError; end

  # ------------------------------------------------------------- loading --

  def self.room_builder
    unless defined?(WR_BuildRoom)
      was = $wr_suppress_autorun
      $wr_suppress_autorun = true
      begin
        load File.join(File.dirname(__FILE__), 'build-room.rb')
      ensure
        $wr_suppress_autorun = was
      end
    end
    WR_BuildRoom
  end

  def self.read_lock(path)
    raise Refused, "no such lock file: #{path}" unless File.exist?(path)
    data = JSON.parse(File.read(path))
    raise Refused, "#{File.basename(path)} is not a take-off lock (format 1)" \
      unless data.is_a?(Hash) && data['format'] == 1
    rooms = data['rooms']
    raise Refused, 'lock file has no rooms' if !rooms.is_a?(Array) || rooms.empty?
    data
  end

  # ---------------------------------------------------------- validation --
  #
  # The checker already enforced all of this; re-checking here is what makes
  # "force it past the checker" fail by name instead of building wrong
  # geometry. Pure data in, messages out — liftable by rbtest.

  def self.lock_errors(data)
    errs = []
    (data['rooms'] || []).each do |room|
      name = room['name'].to_s
      runs = room['runs'] || []
      errs << "#{name}: no runs" and next if runs.empty?
      unless runs.all? { |r| r['in'].to_f > 0 && WR_BuildRoom::DIR.key?(r['d']) }
        errs << "#{name}: a run has no positive length or a bad direction"
        next
      end
      x = 0.0
      y = 0.0
      runs.each do |r|
        v = WR_BuildRoom::DIR[r['d']]
        x += v[0] * r['in'].to_f
        y += v[1] * r['in'].to_f
      end
      if x.abs > TOL || y.abs > TOL
        errs << format('%s: runs do not close (out %.2f" east-west, %.2f" ' \
                       'north-south) — the checker would never emit this; ' \
                       'the lock file has been hand-edited or corrupted',
                       name, x.abs, y.abs)
      end
      unless room['ceiling'] && room['ceiling']['in'].to_f > 0
        errs << "#{name}: no ceiling height — measure it, or record an " \
                'assumption in the take-off and re-run the checker'
      end
      ceil = room['ceiling'] ? room['ceiling']['in'].to_f : 0.0
      by_run = {}
      (room['doors'] || []).each_with_index do |d, j|
        i = d['run'].to_i
        if i < 0 || i >= runs.length
          errs << "#{name} door #{j}: run #{i} does not exist"
          next
        end
        len = runs[i]['in'].to_f
        at = d['at_in'].to_f
        w = d['w_in'].to_f
        if at < TOL || at + w > len - TOL
          errs << format('%s door %d touches the corner of run %d (at %.1f" ' \
                         '+ width %.1f" vs run %.1f") — the wall cut cannot ' \
                         'reach a corner; move it or shrink it',
                         name, j, i, at, w, len)
        end
        h = d['h_in'].to_f
        if ceil > 0 && h > ceil + TOL
          errs << format('%s door %d is taller than its ceiling (leaf %.1f" '                          'vs ceiling %.1f") - it would build through the '                          'ceiling plane; one of the two numbers is misread',
                         name, j, h, ceil)
        end
        (by_run[i] ||= []) << h
      end
      by_run.each do |i, hs|
        if hs.uniq.length > 1
          errs << "#{name}: doors on run #{i} have different heights " \
                  "(#{hs.uniq.join(', ')}) — one cut height per run; " \
                  'this build refuses rather than cutting one of them wrong'
        end
      end
      # A hanging feature entirely above the ceiling is not a feature with
      # zero height, it is a statement that cannot be true: head/sill and
      # ceiling cannot both be right. Dropping it silently (the old
      # behaviour, via build_feature's zero-height guard) left the room
      # looking finished while missing something the client named.
      (room['features'] || []).each_with_index do |f, j|
        next unless ceil > 0
        case f['type']
        when 'bulkhead'
          head = f['head_in'].to_f
          if head >= ceil - TOL
            errs << format('%s bulkhead %d has its head at or above the '                            'ceiling (head %.1f" vs ceiling %.1f") - '                            'nothing would hang below the ceiling; one of '                            'the two numbers is misread',
                           name, j + 1, head, ceil)
          end
        when 'window'
          sill = (f['sill_in'] || 0.0).to_f
          if sill >= ceil - TOL
            errs << format('%s window %d has its sill at or above the '                            'ceiling (sill %.1f" vs ceiling %.1f") - one '                            'of the two numbers is misread',
                           name, j + 1, sill, ceil)
          end
        end
      end
    end
    errs
  end

  # ------------------------------------------------------------ building --

  def self.build_from(path)
    br = room_builder
    data = read_lock(path)
    errs = lock_errors(data)
    unless errs.empty?
      raise Refused, "take-off refused, nothing was built:\n" + errs.join("\n")
    end

    model = Sketchup.active_model
    begin
      model.options['UnitsOptions']['LengthFormat'] = Length::Architectural
    rescue StandardError
    end

    # Load the dimensioner up front (autorun suppressed) so every note and
    # report line can format inches architecturally from the first room on.
    begin
      $wr_suppress_autorun = true
      load File.join(File.dirname(__FILE__), 'auto-dimension.rb')
    ensure
      $wr_suppress_autorun = false
    end

    t_floor = br.tag(model, 'WR-Floor', [230, 230, 230])
    t_wall  = br.tag(model, 'WR-Room', [120, 128, 140])
    t_up    = br.tag(model, 'WR-Room-Upper', [176, 182, 190])
    t_door  = br.tag(model, 'WR-Doors', [238, 98, 22])
    t_leaf  = br.tag(model, 'WR-Doors-Leaf', [200, 130, 60])
    t_note  = br.tag(model, 'WR-Notes', [90, 90, 96])
    t_ceil  = br.tag(model, 'WR-Ceiling', [200, 205, 212])
    t_obst  = br.tag(model, 'WR-Obstruction', [160, 120, 90])

    # Idempotent for bridge re-runs: a room built from this file before is
    # replaced, not duplicated.
    names = data['rooms'].map { |r| r['name'].to_s }
    model.start_operation('Build take-off', true)
    model.entities.grep(Sketchup::Group).select do |g|
      names.include?(g.get_attribute('wr_takeoff', 'room').to_s)
    end.each { |g| g.erase! if g.valid? }
    model.entities.grep(Sketchup::Text).select do |t|
      names.include?(t.get_attribute('wr_takeoff', 'room').to_s)
    end.each { |t| t.erase! if t.valid? }

    cursor = 0.0
    built = []
    floors = []
    data['rooms'].each do |room|
      name = room['name'].to_s
      runs = room['runs'].map { |r| { 'd' => r['d'], 'v' => r['in'].to_f } }
      pts = br.polygon(runs)
      raise Refused, "#{name}: runs do not close" if pts.nil?

      xs = pts.map(&:x)
      origin = room['origin'] || [cursor - xs.min, 0.0]
      ox = origin[0].to_f
      oy = origin[1].to_f
      cursor = ox + xs.max + GAP unless room['origin']
      pts = pts.map { |p| br.pt(p.x + ox, p.y + oy) }

      thick = (room['thick_in'] || 4.0).to_f
      ceil  = room['ceiling']['in'].to_f
      sill  = (room['sill_in'] || 48.0).to_f
      ccw   = br.signed_area(pts) > 0
      outer = br.mitre(pts, ccw, thick)
      doors = (room['doors'] || []).map do |d|
        { 'run' => d['run'].to_i, 'at' => d['at_in'].to_f, 'w' => d['w_in'].to_f }
      end

      g = model.entities.add_group
      g.name = name
      g.set_attribute('wr_takeoff', 'room', name)
      g.set_attribute('wr_takeoff', 'origin', [ox, oy])

      fg = g.entities.add_group
      floor = fg.entities.add_face(pts)
      if floor
        floor.reverse! if floor.normal.z < 0
        fg.name = 'Floor'
        fg.layer = t_floor
        fg.material = br.material(model, br::MAT_FLOOR)
      end

      wg = g.entities.add_group
      wg.name = 'Walls'
      wg.layer = t_wall
      walls = 0
      pts.size.times do |i|
        run_doors = doors.select { |d| d['run'] == i }
        door_h = (room['doors'] || []).select { |d| d['run'].to_i == i }
                                      .map { |d| d['h_in'].to_f }.first || 80.0
        walls += br.wall_run(wg, pts, outer, i, ccw, thick, ceil,
                             run_doors, door_h, sill, t_up)
      end
      wg.material = br.material(model, br::MAT_WALL)

      dg = g.entities.add_group
      dg.name = 'Doors'
      mat_door = br.material(model, br::MAT_DOOR)
      (room['doors'] || []).each do |d|
        br.door(dg, pts, d['run'].to_i, ccw, thick, d['at_in'].to_f,
                d['w_in'].to_f, d['h_in'].to_f, d['hinge'].to_s,
                t_door, t_leaf, mat_door)
      end

      # The ceiling slab, at THIS room's own ceiling height — the 31 Aug
      # client's headline data was per-room ceilings, and the old path could
      # not draw them at all (DEVLOG.md:833).
      cg = g.entities.add_group
      if br.quad(cg.entities, pts, ceil, ceil + SLAB)
        cg.name = 'Ceiling'
        cg.layer = t_ceil
      else
        cg.erase! if cg.valid?
      end

      # Features build as flagged massing on WR-Obstruction — footprint
      # honesty, not furniture.
      (room['features'] || []).each_with_index do |f, j|
        build_feature(br, g, pts, ccw, f, j, ceil, t_obst, name)
      end

      place_notes(model, g, pts, ccw, room, data['assumed_inventory'] || [],
                  name, t_note)

      # Dimension it, the way build-room finishes.
      if floor
        begin
          dims = ::WR_AutoDimension.dimension_face(floor)
          floors << [name, dims]
        rescue StandardError => e
          puts "  (#{name}: dimensioning skipped: #{e.class}: #{e.message})"
        end
      end
      built << [name, pts.size, walls, (room['doors'] || []).size, ceil]
    end
    model.commit_operation
    model.active_view.zoom_extents
    report(data, built)
    { 'rooms' => built.map { |b| b[0] }, 'count' => built.size }
  rescue Refused
    model.abort_operation if model
    raise
  end

  def self.build_feature(br, parent, pts, ccw, f, j, ceil, t_obst, name)
    i = f['run'].to_i
    n = pts.size
    a = pts[i]
    b = pts[(i + 1) % n]
    u = (b - a).normalize
    nv = br.outward(pts, i, ccw)
    inward = Geom::Vector3d.new(-nv.x, -nv.y, 0)
    from = f['from_in'].to_f
    case f['type']
    when 'heater'
      span = f['length_in'].to_f
      dep = f['depth_in'].to_f
      z0, z1 = 0.0, MASSING_H
    when 'bulkhead'
      span = f['length_in'].to_f
      # Spans the room: as deep as the room extends inward from this run.
      dep = pts.map { |p| (p - a) % inward }.max
      z0 = f['head_in'].to_f
      z1 = ceil
    when 'window'
      span = f['width_in'].to_f
      dep = 1.0
      z0 = (f['sill_in'] || 0.0).to_f
      z1 = ceil
    else
      return
    end
    # DISTRUST THE CALLER, same as lock_errors being re-run on a forced
    # lock: a feature that resolves to no volume is an impossible statement,
    # not a no-op. This used to be `return` - which is exactly how the
    # 9'-0" bulkhead in an 8'-0" room vanished without a word (F2,
    # eval/floorplans/synthetic-headroom). The raise aborts the whole
    # operation in build_from, so the model is left untouched.
    if span <= TOL || dep <= TOL || z1 - z0 <= TOL
      raise Refused, format('%s %s %d cannot exist as stated (span %.1f", '                             'depth %.1f", %.1f" up to %.1f" against '                             'ceiling %.1f") - refused rather than silently '                             'dropped: the room would look finished while '                             'missing a feature the client named',
                            name, f['type'], j + 1, span, dep, z0, z1, ceil)
    end
    c0 = a.offset(u, from)
    poly = [c0, c0.offset(u, span),
            c0.offset(u, span).offset(inward, dep), c0.offset(inward, dep)]
    g = parent.entities.add_group
    if br.quad(g.entities, poly, z0, z1)
      g.name = "#{f['type'].capitalize} #{j + 1}"
      g.layer = t_obst
    else
      g.erase! if g.valid?
    end
  end

  # Every assumed/default value of this room gets a text IN THE MODEL, at the
  # door for door values, stacked above the room for the rest — the same
  # loudness the 96" house-default ceiling already gets in build-room.rb.
  def self.place_notes(model, group, pts, ccw, room, inventory, name, t_note)
    mine = inventory.select { |a| a['path'].to_s.start_with?(name + ' ') }
    return if mine.empty?
    doors = room['doors'] || []
    stack = 0
    ys = pts.map(&:y)
    xs = pts.map(&:x)
    mine.each do |a|
      short = a['path'].to_s.sub(name + ' ', '')
      msg = format('%s %s (%s) — %s. Confirm before quoting.',
                   short, a['kind'].to_s.upcase,
                   defined?(::WR_AutoDimension) ?
                     ::WR_AutoDimension.arch(a['value_in'].to_f) :
                     format('%.1f"', a['value_in'].to_f),
                   a['reason'])
      pos = nil
      if (m = short.match(/^door (\d+)/)) && (d = doors[m[1].to_i])
        i = d['run'].to_i
        aa = pts[i]
        bb = pts[(i + 1) % pts.size]
        u = (bb - aa).normalize
        pos = aa.offset(u, d['at_in'].to_f + d['w_in'].to_f / 2.0)
        pos = Geom::Point3d.new(pos.x, pos.y, d['h_in'].to_f + 6.0)
      else
        pos = Geom::Point3d.new(xs.min, ys.max + 20.0 + stack * 14.0, 0)
        stack += 1
      end
      begin
        t = model.entities.add_text(msg, pos)
        t.layer = t_note
        t.set_attribute('wr_takeoff', 'room', name)
      rescue StandardError
      end
    end
  end

  def self.report(data, built)
    puts ''
    puts "BUILD TAKE-OFF  #{data['job']}"
    puts ''
    built.each do |name, nruns, walls, ndoors, ceil|
      puts format('  %-12s %d runs, %d wall solids, %d door(s), ceiling %s',
                  name, nruns, walls, ndoors,
                  defined?(::WR_AutoDimension) ? ::WR_AutoDimension.arch(ceil) :
                    format('%.0f"', ceil))
    end
    inv = data['assumed_inventory'] || []
    puts ''
    if inv.empty?
      puts '  ASSUMED / DEFAULT — none. Every value is measured or stated.'
    else
      puts "  ASSUMED / DEFAULT — #{inv.size} value(s), noted IN THE MODEL, " \
           'confirm before quoting:'
      inv.each do |a|
        puts format('    %s %s — %.1f" (%s)', a['kind'].to_s.upcase,
                    a['path'], a['value_in'].to_f, a['reason'])
      end
    end
    puts ''
  end

  # -------------------------------------------------------------- dialog --

  def self.open
    path = ENV['WR_TAKEOFF']
    if path.nil? || path.empty?
      path = UI.openpanel('Pick a take-off lock file (takeoff.lock.json — ' \
                          'run takeoff-check.py first)', '', 'Lock files|*.lock.json||')
    end
    return unless path
    build_from(path)
  rescue Refused => e
    UI.messagebox(e.message)
    puts "REFUSED: #{e.message}"
  rescue StandardError => e
    UI.messagebox("Build take-off failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(6)
  end
end

WR_BuildTakeoff.open unless $wr_suppress_autorun || $wr_no_autorun
