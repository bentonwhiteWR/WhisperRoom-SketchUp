# @title Lower selected walls to a curb (EDITS MODEL)...
# @cat V-Ray renders
# @rank 7
#
# Cut the walls YOU SELECTED down to a short curb, so a camera can look over
# them into the room. The cut-off tops go on their own tag, WR-Room-Cutaway,
# which a scene hides — so the walls are "lowered" per scene and the model
# still carries its real geometry.
#
# WHY THIS IS NOT wr-split-walls.rb / WR-Room-Upper
#
# That mechanism splits EVERY wall in the room at one sill (48" by default)
# and hides the lot together. Benton, 2026-08-31: "If the building is 8' tall,
# I usually find the corner where the WhisperRoom is and lower those two
# adjacent walls by 7.5'. Not just hide half."
#
# Two differences, and both matter:
#
#   1. TWO WALLS, NOT ALL OF THEM. Which two is a judgement about where the
#      booth sits and where the camera goes. This script does not guess it —
#      you select the walls and it cuts exactly those. A room with a jog, an
#      L, or a booth that is not in a corner needs no special case, because
#      there is no detection to get wrong.
#
#   2. A CURB, NOT A HALF-WALL. 8' less 7'-6" leaves 6". The number this asks
#      for is the height that REMAINS, not the amount removed, so the same
#      answer reads the same on an 8' room and a 10' one.
#
# WR-Room-Upper is left completely alone. The two tags are independent and a
# model can carry both; hide either, or both.
#
# THE CUT PLANE IS ONE HEIGHT FOR THE WHOLE SELECTION
#
# Taken as the LOWEST base in the selection plus the curb height, not per
# group. That is what makes a wall built as two bands, or a wall plus its
# door header, come out level: three pieces at different z all measure from
# the same floor line and the curb is flat across the run. Per-group would
# put a 6" stub on top of a 48" band.
#
# So each selected piece meets one of three fates, and every one is reported:
#
#   entirely above the plane  -> retagged WR-Room-Cutaway whole, no new geometry
#   straddling the plane      -> split in two, top tagged, bottom left as it was
#   entirely below the plane  -> left alone (it is already curb or lower)
#
# WHAT IT REFUSES TO TOUCH — the same narrow test wr-split-walls.rb uses,
# for the same reason: silently mangling a client drawing is the worst
# outcome available. A selected group must be a leaf (no nested group or
# component inside), and its faces must include exactly one horizontal face
# at its base and one at its top sharing the same outline in plan — the
# signature of a straight vertical extrusion. Anything else is skipped and
# NAMED. Selecting a whole room container does nothing at all, on purpose:
# containers are not walls.
#
# Undo is one Ctrl+Z — the whole run is a single operation.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-lower-walls.rb"
#
# THIS FILE HAS NOT BEEN RUN. There is no ruby.exe on this machine outside
# SketchUp itself, so nothing here has executed — it has only been parsed
# with scripts/rbparse.py, which is a real syntax check but not a behaviour
# check.

require 'sketchup.rb'

module WR_LowerWalls
  %w[TOL PREF CUT_TAG DEFAULT_CURB].each do |c|
    remove_const(c) if const_defined?(c, false)
  end

  TOL  = 0.02
  PREF = 'WR_LowerWalls'.freeze

  # Its own tag, deliberately NOT WR-Room-Upper. That one is the room-wide
  # 48" band; this one is a per-scene cutaway of chosen walls. A model may
  # carry both and a scene may hide either.
  CUT_TAG = 'WR-Room-Cutaway'.freeze

  # 8'-0" less Benton's 7'-6" drop. Stored per machine after the first run.
  DEFAULT_CURB = 6.0

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

  # ------------------------------------------------------------ recognition --

  def self.ring(face)
    face.outer_loop.vertices.map { |v| [v.position.x, v.position.y] }
  end

  def self.close?(p, q)
    (p[0] - q[0]).abs < TOL && (p[1] - q[1]).abs < TOL
  end

  # Same polygon allowing a different start vertex or winding — pushpull can
  # reverse one cap relative to the other.
  def self.same_ring?(a, b)
    return false unless a.size == b.size
    n = a.size
    [b, b.reverse].any? do |cand|
      n.times.any? { |off| n.times.all? { |i| close?(a[i], cand[(i + off) % n]) } }
    end
  end

  # The base cap, or nil plus a reason this group is not a clean vertical
  # extrusion. Duplicated from wr-split-walls.rb rather than shared, for the
  # reason that file gives about standing alone.
  def self.base_cap(g)
    return [nil, 'it holds other groups or components — a container, not a wall'] \
      if g.entities.any? { |c| c.is_a?(Sketchup::Group) || c.is_a?(Sketchup::ComponentInstance) }
    faces = g.entities.grep(Sketchup::Face)
    return [nil, 'no faces'] if faces.empty?
    bb = g.bounds
    z0 = bb.min.z
    z1 = bb.max.z
    return [nil, 'no height'] if z1 - z0 < TOL
    at = lambda { |z| faces.select { |f| f.vertices.all? { |v| (v.position.z - z).abs < TOL } } }
    bots = at.call(z0)
    tops = at.call(z1)
    return [nil, "#{bots.size} face(s) at its base, expected 1"] unless bots.size == 1
    return [nil, "#{tops.size} face(s) at its top, expected 1"] unless tops.size == 1
    return [nil, 'base and top do not share an outline'] \
      unless same_ring?(ring(bots.first), ring(tops.first))
    [bots.first, nil]
  end

  def self.label(g)
    n = (g.name.to_s rescue '').strip
    n.empty? ? "unnamed #{g.class.to_s.sub('Sketchup::', '')}" : n
  end

  # ------------------------------------------------------------------ plan --

  Item = Struct.new(:group, :container, :z0, :z1, :ring, :mat, :layer)

  # Selected leaf groups that ARE clean vertical extrusions, plus a list of
  # everything rejected and why. The container is the Entities the group
  # actually lives in, so a replacement lands in the same place — a wall
  # inside a "Walls" group must not be rebuilt at model root.
  def self.gather(sel)
    good = []
    bad  = []
    sel.each do |e|
      unless e.is_a?(Sketchup::Group)
        bad << "#{label(e)}: not a group"
        next
      end
      cap, reason = base_cap(e)
      if reason
        bad << "#{label(e)}: #{reason}"
        next
      end
      bb = e.bounds
      pts = cap.outer_loop.vertices.map { |v| Geom::Point3d.new(v.position.x, v.position.y, bb.min.z) }
      good << Item.new(e, e.parent.entities, bb.min.z, bb.max.z, pts, e.material, e.layer)
    end
    [good, bad]
  end

  # ----------------------------------------------------------------- apply --

  def self.quad(ents, ring_pts, z0, z1)
    f = ents.add_face(ring_pts.map { |q| Geom::Point3d.new(q.x, q.y, z0) })
    return nil if f.nil?
    f.reverse! if f.normal.z < 0
    f.pushpull(z1 - z0)
    f
  end

  def self.run
    model = Sketchup.active_model
    sel   = model.selection.to_a
    if sel.empty?
      UI.messagebox("Select the wall groups you want lowered first.\n\n" \
                    "Click one wall, shift-click the other, then run this again. " \
                    "The cut-off tops go on the #{CUT_TAG} tag, which a scene hides.")
      return
    end

    good, bad = gather(sel)
    if good.empty?
      UI.messagebox("Nothing in the selection is a wall this can cut.\n\n" +
                    bad.first(10).join("\n") +
                    "\n\nSelect the wall SOLIDS themselves, not the group that holds them.")
      puts ''
      puts 'LOWER WALLS — nothing cuttable in the selection:'
      bad.each { |b| puts "    #{b}" }
      return
    end

    curb = read_pref('curb', DEFAULT_CURB).to_f
    curb = DEFAULT_CURB if curb <= 0
    res = UI.inputbox(['Curb height that REMAINS (inches)'], [curb.to_s],
                      'Lower selected walls')
    return unless res
    curb = res[0].to_f
    if curb < 0
      UI.messagebox('A curb height cannot be negative.')
      return
    end
    write_pref('curb', curb)

    # ONE plane for the whole selection — see the file header.
    floor = good.map(&:z0).min
    plane = floor + curb

    cut_tag = tag(model, CUT_TAG, [176, 120, 60])
    split = 0
    retag = 0
    left  = []

    model.start_operation('WR: lower selected walls', true)
    begin
      good.each do |it|
        if it.z1 <= plane + TOL
          left << "#{label(it.group)}: already at or below the curb"
          next
        end
        if it.z0 >= plane - TOL
          # Entirely above the plane — no cutting needed, just tag it.
          it.group.layer = cut_tag
          retag += 1
          next
        end
        base = label(it.group)
        base = 'Wall' if base.start_with?('unnamed')
        lo = it.container.add_group
        if quad(lo.entities, it.ring, it.z0, plane)
          lo.name = base
          lo.layer = it.layer
          lo.material = it.mat if it.mat
        else
          lo.erase! if lo.valid?
          left << "#{base}: the curb piece would not build — left whole"
          next
        end
        hi = it.container.add_group
        if quad(hi.entities, it.ring, plane, it.z1)
          hi.name = "#{base} (cutaway)"
          hi.layer = cut_tag
          hi.material = it.mat if it.mat
        else
          hi.erase! if hi.valid?
          lo.erase! if lo.valid?
          left << "#{base}: the cutaway piece would not build — left whole"
          next
        end
        it.group.erase! if it.group.valid?
        split += 1
      end
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      UI.messagebox("Lower walls FAILED and nothing was changed:\n\n#{e.class}: #{e.message}")
      puts "FAILED: #{e.class}: #{e.message}"
      puts e.backtrace.first(5)
      return
    end

    lines = ['LOWER WALLS',
             format('  curb %.2f" — cut plane at %.2f" (lowest selected base %.2f")',
                    curb, plane, floor),
             "  #{split} wall(s) split, #{retag} piece(s) retagged whole",
             "  the cut-off tops are on #{CUT_TAG}"]
    unless left.empty?
      lines << "  *** #{left.size} left as they were:"
      left.each { |x| lines << "        #{x}" }
    end
    unless bad.empty?
      lines << "  *** #{bad.size} selected item(s) were not walls and were skipped:"
      bad.each { |x| lines << "        #{x}" }
    end
    lines << ''
    lines << "  NEXT: hide #{CUT_TAG}, set the camera, and save that as a scene."
    lines << '  The tag is per-scene, so other scenes keep their full-height walls.'
    puts ''
    lines.each { |l| puts l }
    puts ''
    UI.messagebox(lines.join("\n"))
  rescue StandardError => e
    UI.messagebox("Lower walls failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end
end

WR_LowerWalls.run unless $wr_no_autorun
