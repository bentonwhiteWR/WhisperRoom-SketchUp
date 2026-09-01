# @title Split existing walls at sill (LEGACY, EDITS MODEL)...
# @cat V-Ray renders
# @rank 6
#
# SUPERSEDED, 31 Aug 2026 — KEPT, NOT WIRED INTO ANYTHING NEW.
# build-room.rb and build-takeoff.rb no longer band walls: a wall is ONE
# solid, floor to ceiling, and a whole wall is hidden per scene by
# wr-scene-walls.rb (a SketchUp scene remembers per-entity hidden state, so
# no per-band tag is needed). Benton, 31 Aug 2026: "There is a lower and
# upper half. I dont want that." Nothing built from now on needs this
# script, and running it on a new room re-introduces exactly the split that
# was removed — including the header shards over doorways.
#
# It survives because it is the only tool that can put a model back into
# the old shape, and because a model already split still renders the way it
# always did. If you want a wall down for a render, reach for
# wr-scene-walls.rb (hide the whole wall) or wr-lower-walls.rb (cut chosen
# walls to a curb) instead.
#
# WHAT IT DOES. Existing rooms — anything drawn before two-band walls
# existed, and everything drawn after they were removed — have each wall
# (and each door header) as a SINGLE solid, floor to ceiling. This script
# finds those solids and cuts each one in two at a sill height, tagging the
# upper piece WR-Room-Upper so a scene can hide it to "lower" the walls.
# Run it once per model. Running it again on a model it has already split
# is a no-op — see ALREADY SPLIT, below.
#
# THIS GENUINELY EDITS GEOMETRY, unlike every other script this workspace
# ships. That is exactly why it is not part of the render-prep flow, is not
# something an exporter calls, and defaults to a DRY RUN that changes
# nothing and only prints what it would do. Read the dry run before turning
# it off.
#
# HOW A WALL IS RECOGNISED — every check has to pass, or the group is
# skipped and named in the report rather than guessed at:
#
#   - It is a Sketchup::Group (not a component instance) with no nested
#     group or component instance inside it — a leaf, exactly what
#     `quad()` in build-room.rb produces via add_group + add_face +
#     pushpull, and exactly what a container group like "Walls" is not.
#   - Its own tag is Layer0 (untagged, inheriting a parent's tag — how
#     build-room.rb leaves a wall or header group) or WR-Room itself.
#     A group explicitly tagged WR-Floor, WR-Doors, WR-Doors-Leaf,
#     WR-Notes or WR-Room-Upper is never a candidate.
#   - Its faces include exactly one horizontal face at the group's lowest
#     point (the bottom cap) and exactly one at its highest point (the top
#     cap), and those two caps share the same outline in plan — the
#     signature of a straight vertical extrusion. A wall with a jog, a
#     taper, or any shape pushpull would not produce on its own fails this
#     check and is skipped, named, and left alone.
#
# This is deliberately narrower than "anything wall-shaped." A model drawn
# by a different script with different group names or a different geometry
# routine (csusb-rooms.rb is one) will not be picked up here. That is the
# point — SILENTLY MANGLING A CLIENT DRAWING IS THE WORST OUTCOME AVAILABLE,
# worse than doing nothing and saying so.
#
# ALREADY SPLIT. A group already tagged WR-Room-Upper is skipped outright —
# it is the result of a previous run, or of a room build-room.rb already
# built in two bands, and this script has nothing left to do to it.
#
# THE DOOR-HEADER LOOK DECISION IS THE SAME ONE build-room.rb DOCUMENTS. A
# header (its bottom cap well above the floor) still gets tested against the
# same sill: if the sill is below the header's bottom, the whole header
# moves to WR-Room-Upper and the doorway reads clean when that tag is
# hidden; if the sill lands inside the header's height, the header splits
# and a shard stays behind. Read build-room.rb's file header for the full
# explanation — it applies here unchanged.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-split-walls.rb"

require 'sketchup.rb'

module WR_SplitWalls
  TOL = 0.02
  PREF = 'WR_SplitWalls'.freeze
  SKIP_TAGS = %w[WR-Floor WR-Doors WR-Doors-Leaf WR-Notes WR-Room-Upper].freeze
  MAX_DEPTH = 8

  def self.read_pref(k, dflt)
    v = Sketchup.read_default(PREF, k, dflt)
    v.nil? ? dflt : v
  rescue StandardError
    dflt
  end

  def self.write_pref(k, v)
    Sketchup.write_default(PREF, k, v)
  rescue StandardError
    nil
  end

  def self.tag(model, name, rgb)
    l = model.layers[name] || model.layers.add(name)
    (l.color = Sketchup::Color.new(*rgb)) rescue nil
    l
  end

  # -------------------------------------------------------------- discover --

  # Every leaf group in the model, at any nesting depth, paired with the
  # Entities collection it actually lives in (so a replacement can be added
  # in the same place). Depth-bounded like proposal-scenes.rb's walk, for
  # the same reason: a runaway component reference should not hang this.
  def self.candidates(entities, depth, out)
    return out if depth > MAX_DEPTH
    entities.each do |e|
      next unless e.is_a?(Sketchup::Group)
      nested_group = e.entities.any? { |c| c.is_a?(Sketchup::Group) }
      nested_inst  = e.entities.any? { |c| c.is_a?(Sketchup::ComponentInstance) }
      if nested_group || nested_inst
        candidates(e.entities, depth + 1, out)   # a container — recurse, do not treat as a wall
        next
      end
      out << [e, entities]
    end
    out
  end

  # The bottom cap, the top cap, or nil with a reason if this leaf group is
  # not a clean vertical extrusion.
  def self.caps(g)
    faces = g.entities.grep(Sketchup::Face)
    return [nil, nil, 'no faces'] if faces.empty?
    bb = g.bounds
    z0, z1 = bb.min.z, bb.max.z
    return [nil, nil, 'no height'] if z1 - z0 < TOL
    at = lambda { |z| faces.select { |f| f.vertices.all? { |v| (v.position.z - z).abs < TOL } } }
    bots, tops = at.call(z0), at.call(z1)
    return [nil, nil, "#{bots.size} face(s) at its base, expected 1"] unless bots.size == 1
    return [nil, nil, "#{tops.size} face(s) at its top, expected 1"] unless tops.size == 1
    bring = ring(bots.first)
    tring = ring(tops.first)
    return [nil, nil, 'base and top do not share an outline'] unless same_ring?(bring, tring)
    [bots.first, tops.first, nil]
  end

  def self.ring(face)
    face.outer_loop.vertices.map { |v| [v.position.x, v.position.y] }
  end

  # Same polygon, allowing a different starting vertex or winding — pushpull
  # can reverse one cap relative to the other.
  def self.same_ring?(a, b)
    return false unless a.size == b.size
    n = a.size
    [b, b.reverse].any? do |cand|
      n.times.any? do |off|
        n.times.all? { |i| close?(a[i], cand[(i + off) % n]) }
      end
    end
  end

  def self.close?(p, q)
    (p[0] - q[0]).abs < TOL && (p[1] - q[1]).abs < TOL
  end

  def self.own_tag_ok?(g)
    l = g.layer
    return true if l.nil? || l.name == 'Layer0' || l.name == 'WR-Room'
    !SKIP_TAGS.include?(l.name)
  end

  # -------------------------------------------------------------------- plan --

  Plan = Struct.new(:group, :container, :action, :reason, :z0, :z1, :ring, :mat, :sill)

  def self.plan(model, sill)
    plans = []
    candidates(model.entities, 0, []).each do |g, container|
      if g.layer && g.layer.name == 'WR-Room-Upper'
        plans << Plan.new(g, container, :already, 'already tagged WR-Room-Upper', nil, nil, nil, nil, sill)
        next
      end
      unless own_tag_ok?(g)
        plans << Plan.new(g, container, :skip, "tagged #{g.layer.name}, not a wall/header candidate",
                          nil, nil, nil, nil, sill)
        next
      end
      bot, _top, reason = caps(g)
      if reason
        plans << Plan.new(g, container, :skip, reason, nil, nil, nil, nil, sill)
        next
      end
      bb = g.bounds
      z0, z1 = bb.min.z, bb.max.z
      pts = bot.outer_loop.vertices.map { |v| Geom::Point3d.new(v.position.x, v.position.y, z0) }
      if sill <= z0 + TOL
        plans << Plan.new(g, container, :retag_upper, nil, z0, z1, pts, g.material, sill)
      elsif sill >= z1 - TOL
        plans << Plan.new(g, container, :noop, 'sill is at/above its top already', z0, z1, pts, g.material, sill)
      else
        plans << Plan.new(g, container, :split, nil, z0, z1, pts, g.material, sill)
      end
    end
    plans
  end

  # ------------------------------------------------------------------ apply --

  def self.quad(ents, ring_pts, z0, z1)
    f = ents.add_face(ring_pts.map { |q| Geom::Point3d.new(q.x, q.y, z0) })
    return nil if f.nil?
    f.reverse! if f.normal.z < 0
    f.pushpull(z1 - z0)
    f
  end

  def self.apply!(model, plans, upper_tag)
    split = 0
    retagged = 0
    plans.each do |p|
      case p.action
      when :split
        base = p.group.name.to_s
        base = 'Wall' if base.empty?
        lo = p.container.add_group
        if quad(lo.entities, p.ring, p.z0, p.sill)
          lo.name = base
          lo.layer = p.group.layer          # whatever it had — Layer0 or WR-Room
          lo.material = p.mat if p.mat
        else
          lo.erase! if lo.valid?
        end
        hi = p.container.add_group
        if quad(hi.entities, p.ring, p.sill, p.z1)
          hi.name = "#{base} (upper)"
          hi.layer = upper_tag
          hi.material = p.mat if p.mat
        else
          hi.erase! if hi.valid?
        end
        p.group.erase! if p.group.valid?
        split += 1
      when :retag_upper
        p.group.layer = upper_tag
        retagged += 1
      end
    end
    [split, retagged]
  end

  # ---------------------------------------------------------------------- run --

  def self.ask
    prompts = ['Sill height (inches or 4\'-0")', 'Dry run (no changes)']
    dflt_sill = read_pref('sill', "4'-0\"")
    dflt_dry  = read_pref('dry', 'Yes')
    lists = ['', 'Yes|No']
    res = UI.inputbox(prompts, [dflt_sill, dflt_dry], lists, 'Split existing walls at sill')
    return nil unless res
    sill = begin
      Sketchup.parse_length(res[0].to_s)
    rescue StandardError
      nil
    end
    sill ||= res[0].to_f
    return nil if sill.nil? || sill <= 0
    write_pref('sill', res[0].to_s)
    write_pref('dry', res[1].to_s)
    [sill, res[1].to_s.strip.downcase != 'no']
  end

  def self.run
    model = Sketchup.active_model
    unless model
      UI.messagebox('No model is open.')
      return
    end
    picked = ask
    return unless picked
    sill, dry = picked

    plans = plan(model, sill)
    todo = plans.select { |p| p.action == :split || p.action == :retag_upper }

    if dry
      report(plans, sill, true, 0, 0)
      return
    end

    if todo.empty?
      report(plans, sill, false, 0, 0)
      return
    end

    ans = UI.messagebox(
      "This will edit #{todo.count { |p| p.action == :split }} wall/header solid(s) and " \
      "retag #{todo.count { |p| p.action == :retag_upper }} more, across the whole model — " \
      "not just a selection.\n\n" \
      "One Ctrl+Z undoes all of it. Save or duplicate the model first if you are not sure.\n\n" \
      "Continue?", MB_YESNO)
    return unless ans == IDYES

    upper_tag = tag(model, 'WR-Room-Upper', [176, 182, 190])
    model.start_operation('Split walls at sill', true)
    split = retagged = 0
    begin
      split, retagged = apply!(model, todo, upper_tag)
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      UI.messagebox("Split failed and was rolled back:\n\n#{e.class}: #{e.message}")
      puts "FAILED: #{e.class}: #{e.message}"
      puts e.backtrace.first(6)
      return
    end
    report(plans, sill, false, split, retagged)
  end

  def self.report(plans, sill, dry, split, retagged)
    already = plans.count { |p| p.action == :already }
    noop    = plans.count { |p| p.action == :noop }
    skip    = plans.select { |p| p.action == :skip }
    would_split  = plans.count { |p| p.action == :split }
    would_retag  = plans.count { |p| p.action == :retag_upper }

    puts ''
    puts 'SPLIT EXISTING WALLS AT SILL'
    puts ''
    puts "  sill #{Sketchup.format_length(sill)}"
    if dry
      puts "  DRY RUN — nothing changed."
      puts "  would split   #{would_split}"
      puts "  would retag   #{would_retag}  (entirely above the sill already)"
    else
      puts "  split         #{split}"
      puts "  retagged      #{retagged}  (entirely above the sill already)"
    end
    puts "  already done  #{already}  (already tagged WR-Room-Upper)"
    puts "  no change     #{noop}  (sill at/above its top already)"
    puts "  skipped       #{skip.size}  (could not confidently identify as a wall/header)"
    unless skip.empty?
      puts ''
      puts '  SKIPPED, BY NAME — nothing was touched on any of these:'
      skip.each { |p| puts "    #{p.group.name.to_s.empty? ? '(unnamed group)' : p.group.name} — #{p.reason}" }
    end
    puts ''
    if dry
      puts '  This was a dry run. Turn off "Dry run" and re-run to actually edit the model.'
    end
    puts ''
  end
end

begin
  WR_SplitWalls.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Split existing walls failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console. If this happened during the ' \
                'real (non-dry) run, check Ctrl+Z before doing anything else — the ' \
                'operation should have rolled back on its own.')
end
