# @title Dimension selected room
# @cat Add dimensions
# @icon dim-room
#
# Select a room (its group, or its floor), press this, and every wall run is
# dimensioned. No switch, no prompts: press it again and that room's set is
# replaced, never doubled.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/dimension-room-now.rb"
#
# Benton, 14 Sep 2026: "id like a button that just dimensions an entire room.
# Right now there is one, "dimension the room" but that has an on/off trigger.
# Not very useful. I want to be able to select a room, press the button, and
# it set all the dimensions of the walls. Maybe 3ft away from the edge on the
# outside ones."
#
# NOT A SECOND DIMENSIONER. The geometry — runs, winding, closure, the chain,
# the overall, the doors off their corners — is auto-dimension.rb's
# WR_AutoDimension.dimension_face, called with three standoffs and a door list.
# The old "Dimension the room..." ability is untouched and still toggles.
#
# WHERE THE ROWS SIT
#   chain    36 in outside the wall's EXTERIOR face  = interior face + thick + 36
#   doors    13 in beyond the chain   (the ability's own 33 - 20)
#   overall  28 in beyond the chain   (the ability's own 48 - 20)
# The thickness is READ off the room's wall faces (WR-Room tag), never assumed.
# When no wall can be read it falls back to 4 in — Benton's default — and says
# so on the console and in the result line.
#
# OWNERSHIP IS A STAMP, NOT A TAG. Every dimension and construction point this
# draws carries WR_RoomDims/own and WR_RoomDims/room = the room's persistent id.
# A rerun erases exactly those for that room. It draws on WR-Dims /
# WR-Dims-Doors like the ability, so the proposal scenes still hide it on the
# plates that hide dimensions — which also means switching the old ability on
# or off clears these, because that ability owns those two tags outright.
#
# ANCHORS. Each dimension hangs on a ConstructionPoint at the world corner,
# the route dimension-whisperroom.rb proved, not on a vertex inside the room
# group (never verified, and wrong the moment the group has been moved). The
# set does not follow a room that is moved afterwards; press again.

module WR_RoomDimsNow
  DICT = 'WR_RoomDims'.freeze
  WALL_TAG = 'WR-Room'.freeze
  DOOR_TAG = 'WR-Doors'.freeze

  # PURE SECTION — no SketchUp API from here to END PURE. rbtest-roomdims.py
  # lifts it verbatim. Plan points are [x, y] arrays; coerce with `* 1.0`.

  CLEAR       = 36.0   # chain row, outside the exterior face (Benton: "3ft")
  DOOR_STEP   = 13.0   # auto-dimension.rb DOOR_OFF - SEG_OFF
  OVR_STEP    = 28.0   # auto-dimension.rb OVR_OFF  - SEG_OFF
  THICK_FALLBACK = 4.0
  THICK_MAX   = 24.0   # a wall face further out than this is not this wall
  THICK_AGREE = 0.0625

  # Standoffs from the INTERIOR face, which is the line the engine offsets from.
  def self.offsets_for(thick)
    seg = thick * 1.0 + CLEAR
    { :seg => seg, :door => seg + DOOR_STEP, :ovr => seg + OVR_STEP }
  end

  # One run's wall thickness off the vertical faces around it, or nil.
  #   a, b     run endpoints [x, y], interior face
  #   n        outward unit normal [x, y]
  #   faces    [[normal [x, y], points [[x, y], ...]], ...]
  # A face counts when it is parallel to the run (either orientation — a
  # reversed face is still a wall face), lies OUTSIDE the interior line by
  # more than half an inch and no more than THICK_MAX, and overlaps the run.
  # Faces are bucketed by distance and the NEAREST bucket that covers at least
  # half the run wins: a wall split around a door still sums to its full
  # length, while the outer face of a parallel wall one jog further out only
  # overlaps this run at its end.
  def self.run_thickness(a, b, n, faces)
    ux = (b[0] - a[0]) * 1.0
    uy = (b[1] - a[1]) * 1.0
    len = Math.sqrt(ux * ux + uy * uy)
    return nil if len < 1.0
    ux /= len
    uy /= len
    cover = {}
    faces.each do |fn, pts|
      next if pts.nil? || pts.empty?
      dot = fn[0] * n[0] + fn[1] * n[1]
      next if dot.abs < 0.999
      p0 = pts[0]
      d = (p0[0] - a[0]) * n[0] + (p0[1] - a[1]) * n[1]
      next if d < 0.5 || d > THICK_MAX
      ts = pts.map { |p| (p[0] - a[0]) * ux + (p[1] - a[1]) * uy }
      lo = [ts.min, 0.0].max
      hi = [ts.max, len].min
      next if hi - lo < 0.5
      key = (d * 16.0).round
      cover[key] = (cover[key] || 0.0) + (hi - lo)
    end
    hit = cover.keys.sort.find { |k| cover[k] >= len * 0.5 }
    hit ? hit / 16.0 : nil
  end

  # The room's thickness from the per-run reads (nil = unread).
  # Returns [thick, note]; note nil when the read is clean.
  def self.room_thickness(reads)
    got = reads.compact
    return [THICK_FALLBACK, :fallback] if got.empty?
    lo = got.min
    hi = got.max
    return [hi, nil] if hi - lo <= THICK_AGREE
    # Disagreeing walls: take the thickest so no row lands inside a wall.
    [hi, :disagree]
  end

  # Closure verdict with auto-dimension.rb report's own rule and tolerance.
  def self.verdict(c)
    return :skew if c[:skew] > 0
    ok = c[:dx].abs < 0.05 && c[:dy].abs < 0.05 &&
         c[:gap_x].abs < 0.05 && c[:gap_y].abs < 0.05
    ok ? :closes : :open
  end

  def self.inches(x)
    v = (x * 1.0).round(2)
    v == v.round ? "#{v.round}\"" : "#{v}\""
  end

  # One room's result line.
  def self.line_for(name, runs, made, doors, verdict, thick, note)
    close = { :closes => 'chains close', :open => 'CHAINS DO NOT CLOSE',
              :skew => 'angled runs, closure not proven' }[verdict]
    wall = case note
           when :fallback then "walls unread, #{inches(thick)} assumed"
           when :disagree then "walls disagree, #{inches(thick)} used"
           else "walls #{inches(thick)}"
           end
    d = doors == 1 ? '1 door' : "#{doors} doors"
    "#{name}: #{runs} runs, #{made} dims, #{d}, #{close} (#{wall})"
  end

  # ---- END PURE ------------------------------------------------------------

  def self.load_engine
    return if defined?(::WR_AutoDimension) &&
              ::WR_AutoDimension.respond_to?(:door_bounds_on_run)
    was = $wr_suppress_autorun
    $wr_suppress_autorun = true
    begin
      load File.join(File.dirname(__FILE__), 'auto-dimension.rb')
    ensure
      $wr_suppress_autorun = was
    end
  end

  # Faces under `ents`, with each face's local -> world transform and the tag
  # it inherits (its own if it has one, else its nearest tagged container).
  def self.walk(ents, tr, tagname, out, depth = 0)
    return if depth > 5
    ents.each do |e|
      own = (e.layer && e.layer.name != 'Layer0' && e.layer.name != 'Untagged') ? e.layer.name : nil
      t = own || tagname
      case e
      when Sketchup::Face
        out[:faces] << [e, tr, t]
      when Sketchup::Group, Sketchup::ComponentInstance
        if t == DOOR_TAG
          out[:doors] << world_box(e.bounds, tr)
          next
        end
        sub = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
        walk(sub, tr * e.transformation, t, out, depth + 1)
      end
    end
  end

  def self.world_box(bb, tr)
    w = Geom::BoundingBox.new
    8.times { |i| w.add(bb.corner(i).transform(tr)) }
    w
  end

  # Every selected thing that holds a floor -> one target per room.
  def self.targets(model)
    base = model.edit_transform
    path = model.active_path || []
    out = []
    seen = {}
    model.selection.each do |e|
      next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) ||
                  e.is_a?(Sketchup::Face)
      next if e.get_attribute(DICT, 'own', false)
      pool = []
      ::WR_AutoDimension.collect([e], pool, 0, base)
      hit = ::WR_AutoDimension.pick_floor(pool)
      next unless hit
      # A floor picked on its own (a face, or the Floor group while editing
      # inside the room) belongs to the room being edited: read walls there.
      room = e
      room_tr = base
      if (e.is_a?(Sketchup::Face) || !holds_walls?(e)) && !path.empty?
        room = path.last
        room_tr = base * room.transformation.inverse
      end
      key = room.persistent_id.to_s
      next if seen[key]
      seen[key] = true
      out << { :room => room, :room_tr => room_tr, :face => hit[0], :tr => hit[1], :key => key }
    end
    out
  end

  def self.holds_walls?(e)
    return false if e.is_a?(Sketchup::Face)
    found = { :faces => [], :doors => [] }
    walk([e], Geom::Transformation.new, nil, found)   # tags only; space is irrelevant
    found[:faces].any? { |_, _, t| t == WALL_TAG }
  end

  def self.room_name(room)
    nm = (room.name.to_s rescue '')
    nm = (room.definition.name.to_s rescue '') if nm.empty? && room.respond_to?(:definition)
    nm = 'Room' if nm.empty?
    nm
  end

  def self.clear_room(model, key)
    n = 0
    model.entities.to_a.each do |e|
      next unless e.valid?
      next unless e.is_a?(Sketchup::DimensionLinear) || e.is_a?(Sketchup::ConstructionPoint)
      next unless e.get_attribute(DICT, 'own', false) && e.get_attribute(DICT, 'room', nil) == key
      e.erase!
      n += 1
    end
    n
  end

  def self.dimension_room(model, tg)
    ad = ::WR_AutoDimension
    found = { :faces => [], :doors => [] }
    walk([tg[:room]], tg[:room_tr], nil, found)
    walls = found[:faces].select { |_, _, t| t == WALL_TAG }
    tagged = !walls.empty?
    walls = found[:faces] unless tagged

    runs = ad.runs_of(tg[:face], tg[:tr])
    raise 'could not read a closed outer loop off that floor' if runs.size < 3
    ccw = ad.signed_area(runs) > 0
    plan = walls.map do |f, tr, _|
      nv = f.normal.transform(tr)
      next nil unless nv.z.abs < 0.01
      len = Math.sqrt(nv.x * nv.x + nv.y * nv.y)
      next nil if len < 1e-6
      [[nv.x / len, nv.y / len],
       f.outer_loop.vertices.map { |v| p = v.position.transform(tr); [p.x.to_f, p.y.to_f] }]
    end.compact
    reads = runs.map do |r|
      n = ad.outward(r, ccw)
      run_thickness([r[:a].x.to_f, r[:a].y.to_f], [r[:b].x.to_f, r[:b].y.to_f],
                    [n.x.to_f, n.y.to_f], plan)
    end
    thick, note = room_thickness(reads)
    off = offsets_for(thick)

    doors = found[:doors] + ad.doors_on(model).map(&:bounds)
    key = tg[:key]
    name = room_name(tg[:room])
    res = ad.dimension_face(tg[:face],
                            :transform => tg[:tr], :anchor => :cpoint,
                            :seg_off => off[:seg], :door_off => off[:door],
                            :ovr_off => off[:ovr], :doors => doors,
                            :own => lambda { |e|
                              e.set_attribute(DICT, 'own', true)
                              e.set_attribute(DICT, 'room', key)
                            })
    { :name => name, :res => res, :thick => thick, :note => note, :reads => reads,
      :tagged => tagged, :off => off }
  end

  # Result goes to the panel's own note line when the panel is open, the
  # status bar always, and the console as the durable copy. A messagebox only
  # for "nothing to do" with no panel on screen — and never under the bridge,
  # which raises instead of showing one.
  def self.say(msg, box = false)
    Sketchup.status_text = msg rescue nil
    shown = false
    if defined?(::WhisperRoom::Tools) && ::WhisperRoom::Tools.respond_to?(:push_note)
      dlg = ::WhisperRoom::Tools.instance_variable_get(:@dlg)
      if dlg && (dlg.visible? rescue false)
        ::WhisperRoom::Tools.push_note(msg)
        shown = true
      end
    end
    return unless box && !shown
    begin
      UI.messagebox(msg)
    rescue StandardError
      nil
    end
  end

  def self.run
    model = Sketchup.active_model
    load_engine
    tgs = targets(model)
    if tgs.empty?
      puts 'DIMENSION SELECTED ROOM — nothing selected holds a floor.'
      say('Dimension selected room: select a room (its group or its floor) first.', true)
      return false
    end

    begin
      model.options['UnitsOptions']['LengthFormat'] = Length::Architectural
    rescue StandardError
    end

    done = []
    model.start_operation('Dimension selected room', true)
    begin
      tgs.each do |tg|
        removed = clear_room(model, tg[:key])
        d = dimension_room(model, tg)
        d[:removed] = removed
        done << d
      end
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      puts "DIMENSION SELECTED ROOM FAILED: #{e.class}: #{e.message}"
      puts e.backtrace.first(6).map { |l| "  #{l}" }.join("\n") if e.backtrace
      say("Dimension selected room failed: #{e.message} (nothing was changed)", true)
      return false
    end

    lines = done.map do |d|
      r = d[:res]
      line_for(d[:name], r[:runs].size, r[:made], r[:doors],
               verdict(r[:closure]), d[:thick], d[:note])
    end
    done.each_with_index do |d, i|
      ::WR_AutoDimension.report(d[:res])
      puts "  DIMENSION SELECTED ROOM — #{lines[i]}"
      puts format('  rows from the interior face: chain %.2f", doors %.2f", overall %.2f"',
                  d[:off][:seg], d[:off][:door], d[:off][:ovr])
      puts "  per-run wall reads: #{d[:reads].map { |x| x ? x.to_s : '-' }.join(', ')}"
      puts '  (no WR-Room tag found: thickness read from every vertical face in the room)' unless d[:tagged]
      if d[:note] == :fallback
        puts "  WALL THICKNESS COULD NOT BE READ — rows placed on the #{THICK_FALLBACK}\" default."
      end
      puts "  replaced #{d[:removed]} entity(ies) this tool drew before" if d[:removed] > 0
      puts "  #{d[:res][:loose]} dimension end(s) could not anchor and are loose" if d[:res][:loose] > 0
      puts ''
    end
    say(lines.join('  |  '))
    true
  end
end

WR_RoomDimsNow.run unless $wr_suppress_autorun || $wr_no_autorun
