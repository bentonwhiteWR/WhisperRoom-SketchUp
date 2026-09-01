# @title Name walls for the scene picker...
# @cat Scenes and images
# @rank 6
#
# ONE-TIME RETROFIT, sibling of wr-split-walls.rb. "Hide walls per scene"
# (wr-scene-walls.rb) lists a wall by its NAME — "Wall 3", the way
# build-room.rb and build-takeoff.rb have always named them. A room drawn by
# hand, or by an older script, has unnamed wall groups, so the picker cannot
# list it. This script finds those wall solids and names them "Wall 1..N",
# walking the room counter-clockwise, so the picker picks them up.
#
# IT CHANGES NAMES ONLY. No geometry is cut, no group is moved, no tag is
# touched — a name on a group is metadata, and SketchUp scenes, dimensions
# and materials never depend on it. It still DEFAULTS TO A DRY RUN, per the
# precedent wr-split-walls.rb set for anything that writes into a client
# model: read the printed plan first, then re-run with Dry run off.
#
# HOW A WALL IS RECOGNISED — the same narrow test wr-split-walls.rb and
# wr-lower-walls.rb use, duplicated rather than shared for the reason those
# files give about standing alone. A candidate is a leaf group (no nested
# group/component), tagged Layer0 or WR-Room (never WR-Floor, WR-Doors,
# WR-Doors-Leaf, WR-Notes, WR-Ceiling, or the cutaway/upper tags), whose
# faces are one bottom cap and one top cap sharing the same plan outline —
# a straight vertical extrusion. Anything else is skipped AND NAMED in the
# report, because silently mangling a client drawing is the worst outcome
# available.
#
# A group already named like a piece ("Wall 2", "Header 1 (upper)", ...) is
# left exactly as it is — build-room output, or a previous run of this.
# Numbering starts after the highest "Wall N" already present in the same
# container, so a half-named room never gets duplicate numbers.
#
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/wr-name-walls.rb"

require 'sketchup.rb'

module WR_NameWalls
  TOL  = 0.02
  PREF = 'WR_NameWalls'.freeze
  PIECE_RE = /\A(Wall|Header|Opening|Door leaf|Swing) (\d+)(\s|\z)/
  NEVER_TAGS = %w[WR-Floor WR-Doors WR-Doors-Leaf WR-Notes WR-Ceiling
                  WR-Room-Upper WR-Room-Cutaway WR-Obstruction].freeze

  # ------------------------------------------------------------ recognition --
  # Duplicated from wr-lower-walls.rb — see its header for why not shared.

  def self.ring(face)
    face.outer_loop.vertices.map { |v| [v.position.x, v.position.y] }
  end

  def self.close?(p, q)
    (p[0] - q[0]).abs < TOL && (p[1] - q[1]).abs < TOL
  end

  def self.same_ring?(a, b)
    return false unless a.size == b.size
    n = a.size
    [b, b.reverse].any? do |cand|
      n.times.any? { |off| n.times.all? { |i| close?(a[i], cand[(i + off) % n]) } }
    end
  end

  def self.wall_shaped?(g)
    return false if g.entities.any? { |c| c.is_a?(Sketchup::Group) || c.is_a?(Sketchup::ComponentInstance) }
    faces = g.entities.grep(Sketchup::Face)
    return false if faces.empty?
    bb = g.bounds
    z0 = bb.min.z
    z1 = bb.max.z
    return false if z1 - z0 < TOL
    at = lambda { |z| faces.select { |f| f.vertices.all? { |v| (v.position.z - z).abs < TOL } } }
    bots = at.call(z0)
    tops = at.call(z1)
    return false unless bots.size == 1 && tops.size == 1
    # A floor or ceiling slab passes the extrusion test too — it is one. The
    # difference is proportion: a wall is TALLER than its thinnest plan
    # dimension (a 4" thick wall stands 96"), a slab is not (a 4" slab spans
    # feet). This keeps an untagged hand-drawn floor from being named Wall N.
    min_plan = [bb.max.x - bb.min.x, bb.max.y - bb.min.y].min
    return false unless (z1 - z0) > min_plan - TOL
    same_ring?(ring(bots.first), ring(tops.first))
  rescue StandardError
    false
  end

  def self.tag_ok?(g)
    t = g.layer ? g.layer.name.to_s : 'Layer0'
    !NEVER_TAGS.include?(t)
  end

  # ---------------------------------------------------------------- plan --

  Plan = Struct.new(:group, :container_label, :new_name)

  # Candidates grouped by the Entities collection they live in, so numbering
  # is per room (or per Walls container), never across rooms.
  def self.scan(model)
    plans = []
    skips = []
    walk = lambda do |ents, path, depth|
      groups = ents.grep(Sketchup::Group)
      cands = []
      groups.each do |g|
        nm = g.name.to_s
        if nm =~ PIECE_RE
          next # already named — build-room output or a previous run
        elsif wall_shaped?(g) && tag_ok?(g)
          cands << g
        else
          walk.call(g.entities, path + [nm.empty? ? '(unnamed)' : nm], depth + 1) if depth < 2
        end
      end
      next if cands.empty?
      label = path.empty? ? 'model root' : path.join(' / ')
      # Number counter-clockwise around the shared centroid so "Wall 1..N"
      # reads like a walk around the room, and start after any number the
      # container already uses.
      taken = groups.map { |g| g.name.to_s =~ /\AWall (\d+)/ ? Regexp.last_match(1).to_i : 0 }.max || 0
      cx = cands.map { |g| g.bounds.center.x }.sum / cands.size
      cy = cands.map { |g| g.bounds.center.y }.sum / cands.size
      ordered = cands.sort_by do |g|
        c = g.bounds.center
        Math.atan2(c.y - cy, c.x - cx)
      end
      ordered.each_with_index do |g, i|
        plans << Plan.new(g, label, "Wall #{taken + i + 1}")
      end
    end
    # Skips are collected separately so the report can name what was seen
    # and refused: any group that holds faces but failed the wall test.
    check_skips = lambda do |ents, path, depth|
      ents.grep(Sketchup::Group).each do |g|
        nm = g.name.to_s
        next if nm =~ PIECE_RE
        if !g.entities.grep(Sketchup::Face).empty? && !wall_shaped?(g) && depth > 0
          skips << "#{(path + [nm.empty? ? '(unnamed group)' : nm]).join(' / ')}: not a clean vertical extrusion"
        end
        check_skips.call(g.entities, path + [nm.empty? ? '(unnamed)' : nm], depth + 1) if depth < 2
      end
    end
    walk.call(model.entities, [], 0)
    check_skips.call(model.entities, [], 0)
    [plans, skips]
  end

  # ----------------------------------------------------------------- run --

  def self.read_pref(k, dflt)
    v = Sketchup.read_default(PREF, k, dflt)
    v.nil? ? dflt : v
  rescue StandardError
    dflt
  end

  def self.run
    model = Sketchup.active_model
    unless model
      UI.messagebox('No model is open.')
      return
    end
    dflt = read_pref('dry', 'Yes')
    res = UI.inputbox(['Dry run (print the plan, change nothing)'], [dflt],
                      ['Yes|No'], 'Name walls for the scene picker')
    return unless res
    dry = res[0].to_s == 'Yes'
    Sketchup.write_default(PREF, 'dry', res[0].to_s) rescue nil

    plans, skips = scan(model)
    puts ''
    puts "NAME WALLS — #{plans.size} unnamed wall solid(s) found" \
         "#{dry ? ' (DRY RUN, nothing changed)' : ''}:"
    plans.each { |p| puts "    #{p.container_label}  ->  #{p.new_name}" }
    skips.each { |s| puts "    SKIPPED  #{s}" }
    if plans.empty?
      msg = 'Nothing to name — every wall solid this recognises is already named.'
      msg += "\n\n#{skips.size} group(s) were skipped; the Ruby Console names them." unless skips.empty?
      UI.messagebox(msg)
      return
    end
    if dry
      puts '  This was a dry run. Re-run with "Dry run: No" to write the names.'
      UI.messagebox("DRY RUN — #{plans.size} wall(s) would be named. " \
                    "The plan is in the Ruby Console (Extensions > Developer). " \
                    'Re-run with "Dry run: No" to write the names.')
      return
    end
    model.start_operation('Name walls for the scene picker', true)
    begin
      plans.each { |p| p.group.name = p.new_name if p.group.valid? }
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      UI.messagebox("Naming failed and was rolled back: #{e.class}: #{e.message}")
      return
    end
    puts "  #{plans.size} wall(s) named. One Ctrl+Z undoes all of it."
    UI.messagebox("#{plans.size} wall(s) named. They now appear in " \
                  "\"Hide walls per scene\". One Ctrl+Z undoes all of it.")
  end
end

WR_NameWalls.run unless $wr_suppress_autorun || $wr_no_autorun
