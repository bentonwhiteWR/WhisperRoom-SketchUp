# @title Name scenes after their parts...
# @cat Tidy up the model
# @rank 3
# @icon scene-parts
#
# The reverse of Name Parts After Their Scenes: every scene in scope is renamed
# after the part its camera looks at. Pairings are shown as a TABLE first, and
# only the rows you tick are applied.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/name-scenes-after-parts.rb"
#
# WHY IT EXISTS. A master model collects hundreds of close-up scenes that are
# born "Scene 355", "Scene 356"... and only become useful once each one carries
# the name of the part it shows — that name is the exported file name. The
# door-scene one-off (.forge/builder/door-scenes/name-scenes-from-parts.rb) did
# this for one range of one model with a message box; this is the same job as a
# panel tool, with the stronger resolver and a review table.
#
# SCOPE. Two choices at the top of the window, remembered between runs:
#
#   Unnamed scenes  every scene still carrying a SketchUp default name —
#                   "Scene 12", and "Scene 12 (2)" (SketchUp's own duplicate
#                   suffix). The rule is UNNAMED_SCENE below; it is exact and
#                   case-sensitive, so a scene somebody typed as "scene 12" or
#                   "Scene 12 copy" counts as named. A non-English SketchUp
#                   ("Szene 12") is not recognised — use Positions there.
#   Positions       scene POSITIONS as the Scenes panel numbers them, 1-based:
#                   "355-422, 430, 440-445". Same number rule as export-scenes.rb
#                   (a reversed range is turned round, 0 and anything past the
#                   last scene are clamped and REPORTED, never silently dropped
#                   or wrapped to the end of the list). No scene-name text
#                   search here: a name is exactly what this tool replaces.
#
# THE GUESS IS NOT NEW CODE. subject_for, geometry_subject_for, view_direction,
# fallback_for, ray_box_entry, ray_offsets, top_level_index, pick_instance and
# near_misses are COPIED VERBATIM out of save-scene-components.rb (by way of
# bulk-name-after-scenes.rb, which holds the identical copy), along with
# scene_label, AUTONAME, definition_of and definition_name. Two measured dry
# runs over 112 scenes are behind the shape of that resolver and none of that
# evidence was re-gathered here, so none of it was re-litigated here either.
# The copy is a real cost — three files now hold one rule and they can drift.
# It is taken because save-scene-components.rb RUNS ON LOAD (it ends by calling
# WR_SaveSceneComponents.run), so `load`ing it to borrow a method would open its
# export dialog; bulk-name-after-scenes.rb runs on load for the same reason. If
# that ever changes, delete these copies and require it. The door-scene one-off
# used "nearest instance to the camera target"; that is only the resolver's
# last-resort TARGET tier here, deliberately.
#
# THE NAME a scene gets is the part's DEFINITION name, else its INSTANCE name
# (a group's definition is nearly always "Group#3"), and SketchUp placeholders
# — Component#12, Group#3 — count as no name at all. A part with neither is a
# NONE row: never approvable.
#
# CONFIDENCE IS SHOWN BECAUSE IT VARIES ENORMOUSLY, exactly as in the bulk tool:
#
#   RAY      the scene camera's ray struck this part. The strong tier.
#   BOUNDS   the ray missed every face but passed through this part's box.
#   OFF-AXIS nothing was hit; this part sits nearest the line of sight. A guess.
#   TARGET   the scene has no usable view direction at all. A weaker guess.
#   NAME     the scene is already called after a top-level definition.
#   NONE     no named part found. Never approvable, never pre-ticked.
#
# ONLY RAY ROWS ARE PRE-TICKED, and only when nothing is wrong with them. Weak
# tiers start unticked: tick them once you have looked (Show activates the
# scene and selects the part). Rows are sorted weakest-first.
#
# ===========================================================================
# COLLISIONS — THE RULE CHOSEN
#
# Scene names must be unique, and SketchUp does not refuse a duplicate, it
# quietly makes one up. So every name is decided HERE, in the table, before
# anything is written:
#
#   * Several scenes looking at the SAME part is normal (open / closed / close
#     up), so it is NOT an error. They are NUMBERED in the preview: the first
#     gets the bare name, the next "Name (2)", then "Name (3)" — SketchUp's own
#     duplicate-scene spelling, so the result reads the way a person expects,
#     but chosen up front and shown on the row. " (n)" rather than " n" because
#     part names end in digits ("Std wall 46") and "Std wall 46 2" misreads.
#   * A name held by a scene that is NOT being renamed (out of scope, or a NONE
#     row) is never taken: the row moves on to the next free number.
#   * Stability: a scene ALREADY called "Name" or "Name (k)" for its own part
#     keeps that name and is listed as already named — a second run renames
#     nothing.
#   * Names are compared ignoring case, as prefix-scenes.rb does.
#
# Numbering assumes every resolvable row will be applied. If you UNTICK a row,
# its scene keeps its current name; at Apply, any ticked row whose name is
# held by a scene that is not being renamed is SKIPPED with that reason (never
# renumbered behind your back — what Apply writes is only ever what the table
# showed).
#
# TWO PASSES. Every approved scene first gets a unique temporary name, then its
# final one, so a swap (A -> B while B -> A) never collides half-way.
#
# NAMES ARE READ BACK after both passes. If SketchUp gave any scene a name other
# than the one asked for, the WHOLE batch is aborted (this differs from the bulk
# tool's per-row put-back: with two passes, a single row cannot be put back
# without possibly colliding with a name another row just took). Everything is
# pre-checked, so this is the "should never happen" branch.
#
# ONE UNDO STEP. Every approved row goes inside one model.start_operation.

require 'sketchup.rb'
require 'json'

module WR_NameScenesAfterParts

  TITLE = 'Name Scenes After Parts'.freeze
  PREF  = 'WR_NameScenesAfterParts'.freeze

  # SketchUp's own placeholder names. Treated as "no name", the same way
  # save-scene-components.rb and name-selection-after-scene.rb treat them. This
  # regex must stay identical to theirs.
  AUTONAME = /\A(Component|Group)#\d+\z/.freeze

  # ------------------------------------------------- copied from the exporter
  #
  # Everything between here and the "end of copy" marker is save-scene-
  # components.rb's, verbatim. Do not improve it in place. See the header.

  # "(LeftWADoorWithRamp)" -> "LeftWADoorWithRamp". Only unwrap when the WHOLE
  # name is wrapped, which means the first closing bracket is the last
  # character. "16PanelSolid (2)" is SketchUp's own duplicate-scene suffix, not
  # a label — stripping its closing bracket leaves a filename with an open
  # bracket and no close, which is what happened to 66 real files.
  def self.scene_label(page)
    n = page.name.to_s.strip
    if n.start_with?('(') && n.end_with?(')') && n.index(')') == n.length - 1
      n = n[1..-2].to_s.strip
    end
    n
  end

  # Both ComponentInstance and Group expose #definition (Group#definition since
  # SU 2015).
  def self.definition_of(e)
    e.definition
  rescue Exception
    nil
  end

  def self.definition_name(defn)
    n = (defn.name.to_s.strip rescue '')
    n =~ AUTONAME ? '' : n
  end

  # Top-level instances and groups by definition name.
  def self.top_level_index(model)
    idx = {}
    model.entities.each do |e|
      next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      defn = definition_of(e)
      next if defn.nil?
      n = definition_name(defn)
      next if n.empty?
      (idx[n] ||= []) << e
    end
    idx
  end

  # Deterministic pick among instances sharing one definition name: leftmost,
  # then front, then lowest, then entityID so the order never depends on the
  # order model.entities happens to yield.
  def self.pick_instance(list)
    list.min_by do |e|
      b = (e.bounds rescue nil)
      if b && b.valid?
        [b.min.x.to_f, b.min.y.to_f, b.min.z.to_f, e.entityID.to_i]
      else
        [1.0e18, 1.0e18, 1.0e18, e.entityID.to_i]
      end
    end
  end

  # Definition names that differ from the wanted one only by SketchUp's own
  # uniquing suffix. Named, never used.
  def self.near_misses(index, want)
    return [] if want.to_s.empty?
    re = /\A#{Regexp.escape(want)}#\d+\z/
    index.keys.select { |k| k =~ re }.sort
  end

  # Resolution order: exact definition-name match first, geometry only when
  # nothing carries the name. Every row this script shows is by definition a
  # no-name-match row, so in practice this always falls through to geometry —
  # the name tier is kept because removing it would make this a different
  # method from the one it was copied from.
  def self.subject_for(model, page, index = nil)
    index ||= top_level_index(model)
    want = scene_label(page)

    unless want.empty?
      hits = index[want]
      if hits && !hits.empty?
        subj = pick_instance(hits)
        if hits.length == 1
          return [subj, 'name match']
        end
        x = (subj.bounds.min.x.to_f rescue 0.0)
        return [subj, format('name match (%d instances - took the leftmost at x=%.0f in)',
                             hits.length, x)]
      end
    end

    lead = want.empty? ? 'no scene label' : 'no name match'
    near = near_misses(index, want)
    unless near.empty?
      lead += '; model has ' + near.map { |n| n.inspect }.join(', ')
    end

    subj, how = geometry_subject_for(model, page)
    [subj, "#{lead}; #{how}"]
  end

  # Sketchup::Model#raytest(ray, wysiwyg_flag = true): ray is [Point3d, Vector3d];
  # the return is nil or [Point3d, Array<Drawingelement>] where the array is the
  # INSTANCE PATH of the entity hit, outermost first. We scan for the first
  # instance/group rather than taking path[0] blind, so a path that also carries
  # the Face still resolves. wysiwyg defaults to true — hidden geometry is not
  # intersected, which is what we want.
  def self.geometry_subject_for(model, page)
    cam = (page.camera rescue nil)
    return [nil, 'scene has no camera'] if cam.nil?

    eye = cam.eye
    dir = view_direction(cam)

    if dir
      hit = (model.raytest([eye, dir]) rescue nil)
      if hit.is_a?(Array) && hit[1].is_a?(Array)
        subj = hit[1].find do |e|
          e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
        end
        if subj
          d = (eye.distance(hit[0]).to_f rescue 0.0)
          return [subj, format('ray hit at %.0f in', d)]
        end
      end
    end

    fallback_for(model, cam, eye, dir)
  end

  # cam.direction is documented only as "a Vector3d in the direction the Camera
  # is pointing" — normalisation is not promised, and raytest needs a non-zero
  # vector or it reinterprets the second element as a point to aim through.
  def self.view_direction(cam)
    d = (cam.direction rescue nil)
    d = nil if d && !d.valid?
    if d.nil?
      v = (cam.target - cam.eye rescue nil)
      d = v if v && v.valid?
    end
    return nil if d.nil?
    (d.normalize rescue d)
  end

  # 1. Any part whose BOUNDING BOX the ray passes through, nearest first.
  # 2. Otherwise the part with the smallest PERPENDICULAR distance from the ray
  #    line. Parts behind the camera are ranked last.
  # 3. Only with no usable direction at all, nearest to the target point.
  def self.fallback_for(model, cam, eye, dir)
    t = cam.target
    best_box = nil; best_box_d = nil
    best_perp = nil; best_perp_d = nil; best_perp_ahead = false
    best_pt = nil;  best_pt_d = nil

    model.entities.each do |e|
      next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      bb = (e.bounds rescue nil)
      next if bb.nil? || !bb.valid?
      c = bb.center

      pd = bb.contains?(t) ? 0.0 : t.distance(c).to_f
      if best_pt_d.nil? || pd < best_pt_d
        best_pt_d = pd; best_pt = e
      end

      next if dir.nil?

      tb = ray_box_entry(eye, dir, bb)
      if tb && (best_box_d.nil? || tb < best_box_d)
        best_box_d = tb; best_box = e
      end

      along, perp = ray_offsets(eye, dir, c)
      ahead = along > 0.0
      better = if best_perp.nil?
                 true
               elsif ahead != best_perp_ahead
                 ahead
               else
                 perp < best_perp_d
               end
      if better
        best_perp = e; best_perp_d = perp; best_perp_ahead = ahead
      end
    end

    if best_box
      return [best_box, format('fallback: ray crosses bounds %.0f in ahead', best_box_d)]
    end
    if best_perp
      tag = best_perp_ahead ? 'ahead' : 'BEHIND camera'
      return [best_perp, format('fallback: %.0f in off ray axis, %s', best_perp_d, tag)]
    end
    if best_pt
      return [best_pt, format('fallback: %.0f in from target, no view direction', best_pt_d)]
    end
    [nil, 'no component found near the scene camera']
  end

  # Slab test: distance along a unit ray at which it enters this bounding box,
  # or nil if it never does. 0.0 means the eye is already inside the box.
  def self.ray_box_entry(eye, dir, bb)
    o = eye.to_a
    d = dir.to_a
    lo = bb.min.to_a
    hi = bb.max.to_a
    tmin = -1.0e18
    tmax =  1.0e18
    3.times do |ax|
      oa = o[ax].to_f
      da = d[ax].to_f
      la = lo[ax].to_f
      ha = hi[ax].to_f
      if da.abs < 1.0e-9
        return nil if oa < la || oa > ha    # parallel to this slab and outside
      else
        t1 = (la - oa) / da
        t2 = (ha - oa) / da
        t1, t2 = t2, t1 if t1 > t2
        tmin = t1 if t1 > tmin
        tmax = t2 if t2 < tmax
        return nil if tmin > tmax
      end
    end
    return nil if tmax < 0.0                # box is wholly behind the camera
    tmin > 0.0 ? tmin : 0.0
  end

  # [distance along the ray, perpendicular distance from the ray line] for a
  # point, with dir a unit vector. Plain floats (inches) rather than Length
  # arithmetic, which does not survive squaring cleanly.
  def self.ray_offsets(eye, dir, pt)
    vx = pt.x.to_f - eye.x.to_f
    vy = pt.y.to_f - eye.y.to_f
    vz = pt.z.to_f - eye.z.to_f
    along = (vx * dir.x.to_f) + (vy * dir.y.to_f) + (vz * dir.z.to_f)
    sq = (vx * vx) + (vy * vy) + (vz * vz) - (along * along)
    sq = 0.0 if sq < 0.0                    # rounding only
    [along, Math.sqrt(sq)]
  end

  # ------------------------------------------------------- end of copy -------

  # Is this entity at the top level of the model? Lifted from
  # bulk-name-after-scenes.rb (outside its copy block there too).
  def self.top_level?(model, ent)
    model.entities.include?(ent)
  rescue Exception
    true
  end

  # =================================================== PURE (rbtest-lifted) ==
  #
  # Data in, data out, no SketchUp API. scripts/rbtest-name-scenes.py lifts
  # this block verbatim and runs it in SketchUp's own CRuby.

  # SketchUp's default scene name: "Scene 12", and "Scene 12 (2)" for its own
  # duplicate suffix. Exact and case-sensitive on purpose — see the header.
  UNNAMED_SCENE = /\AScene \d+(?: \(\d+\))?\z/.freeze

  def self.unnamed_scene?(name)
    n = name.to_s.strip
    n.empty? || !(n =~ UNNAMED_SCENE).nil?
  end

  # "355-422, 430" -> [[355..422 and 430 as Integers, in the order given,
  # de-duplicated], [tokens that matched nothing]]. 1-based, as the Scenes
  # panel numbers them. The clamping rule is export-scenes.rb#select_pages's:
  # 0 must never wrap to the last scene, and what falls off either end is
  # reported, not dropped. Returns positions, not pages, so it stays pure.
  def self.parse_positions(spec, count)
    picked = []
    misses = []
    spec.to_s.split(/[,;]/).map(&:strip).reject(&:empty?).each do |tok|
      if tok =~ /\A(\d+)\s*-\s*(\d+)\z/
        a = Regexp.last_match(1).to_i
        b = Regexp.last_match(2).to_i
        a, b = b, a if a > b
        lo = a < 1 ? 1 : a
        hi = b > count ? count : b
        if lo > hi
          misses << tok
        else
          misses << "#{a}-#{lo - 1}" if a < lo
          misses << "#{hi + 1}-#{b}" if b > hi
          (lo..hi).each { |n| picked << n }
        end
      elsif tok =~ /\A\d+\z/
        n = tok.to_i
        if n >= 1 && n <= count
          picked << n
        else
          misses << tok
        end
      else
        misses << tok
      end
    end
    [picked.uniq, misses]
  end

  # The name a part gives a scene: definition name, else instance name, with
  # SketchUp placeholders treated as no name. nil when there is nothing usable.
  def self.part_label(defn_name, inst_name)
    [defn_name, inst_name].each do |raw|
      n = raw.to_s.strip
      return n unless n.empty? || n =~ AUTONAME
    end
    nil
  end

  # THE COLLISION RULE (see the header). rows: [[key, current_name, base], ...]
  # in scene-position order; base nil for a row that will not be renamed.
  # reserved: names held by scenes that are NOT being renamed. Returns
  # { key => final_name } for every row with a base.
  #
  # Pass 1 lets a row that already holds base or "base (k)" keep it, so a
  # second run is a no-op. Pass 2 numbers the rest in position order.
  def self.assign_names(rows, reserved)
    taken = {}
    reserved.each { |n| taken[n.to_s.downcase] = true }
    out = {}
    rows.each do |key, now, base|
      next if base.nil?
      cur = now.to_s
      own = cur == base || !(cur =~ /\A#{Regexp.escape(base)} \(\d+\)\z/).nil?
      next unless own
      next if taken[cur.downcase]
      taken[cur.downcase] = true
      out[key] = cur
    end
    rows.each do |key, _now, base|
      next if base.nil? || out.key?(key)
      cand = base
      k = 2
      while taken[cand.downcase]
        cand = "#{base} (#{k})"
        k += 1
      end
      taken[cand.downcase] = true
      out[key] = cand
    end
    out
  end

  # ================================================= END OF THE PURE BLOCK ==

  # ------------------------------------------------------------------ prefs --

  def self.read_pref(key, fallback)
    v = Sketchup.read_default(PREF, key, fallback)
    v.nil? ? fallback : v.to_s
  rescue StandardError
    fallback
  end

  def self.write_pref(key, value)
    Sketchup.write_default(PREF, key, value.to_s)
  rescue StandardError
    nil
  end

  def self.saved_scope
    mode = read_pref('mode', 'unnamed')
    mode = 'unnamed' unless %w[unnamed positions].include?(mode)
    { 'mode' => mode, 'spec' => read_pref('spec', '') }
  end

  # ------------------------------------------------------------------ tiers --
  #
  # The resolver labels every branch it takes in the string it returns; the
  # label is read back and classified rather than re-derived. Same table as
  # bulk-name-after-scenes.rb#tier_of. Returns [tier, confidence_rank].
  def self.tier_of(subj, how)
    return ['NONE', 0] if subj.nil?
    h = how.to_s
    return ['RAY', 3]      if h.include?('ray hit at')
    return ['BOUNDS', 2]   if h.include?('ray crosses bounds')
    return ['OFF-AXIS', 1] if h.include?('off ray axis')
    return ['TARGET', 1]   if h.include?('no view direction')
    return ['NAME', 3]     if h.start_with?('name match')
    ['NONE', 0]
  end

  def self.part_name(ent)
    return nil if ent.nil?
    defn = definition_of(ent)
    dn = defn ? definition_name(defn) : ''
    part_label(dn, (ent.name.to_s rescue ''))
  end

  # Which scenes, as [[position, page], ...], plus a one-line note.
  def self.scope_pages(model, scope)
    pages = model.pages.to_a
    if scope['mode'] == 'positions'
      nums, misses = parse_positions(scope['spec'], pages.length)
      note = if scope['spec'].to_s.strip.empty?
               'type scene positions, e.g. 355-422, 430'
             else
               "positions #{scope['spec'].to_s.strip}"
             end
      note += " — nothing at #{misses.join(', ')} (model has #{pages.length} scenes)" unless misses.empty?
      [nums.map { |n| [n, pages[n - 1]] }, note]
    else
      sel = []
      pages.each_with_index { |pg, i| sel << [i + 1, pg] if unnamed_scene?(pg.name) }
      [sel, "unnamed scenes (\"Scene N\") — #{sel.length} of #{pages.length}"]
    end
  end

  # ------------------------------------------------------------------- plan --
  #
  # Builds the review table. READ ONLY. Every name Apply will write is decided
  # here, so what is shown is what will happen. @rows carries live references
  # for the apply path; only the returned Hash crosses into JavaScript.
  def self.plan(model, scope)
    index = top_level_index(model)
    picked, note = scope_pages(model, scope)
    in_scope = {}
    picked.each { |_n, pg| in_scope[pg.object_id] = true }

    rows = []
    picked.each do |n, page|
      subj, how = subject_for(model, page, index)
      base = part_name(subj)
      subj = nil if base.nil?
      tier, rank = tier_of(subj, how)
      notes = []
      if subj.nil?
        notes << 'no named part could be resolved — the scene keeps its name'
      elsif !top_level?(model, subj)
        notes << 'part is not at the model top level'
      end
      rows << { :n => n, :page => page, :ent => subj, :now => page.name.to_s,
                :base => base, :tier => tier, :rank => rank, :how => how.to_s,
                :notes => notes }
    end

    # Names that stay put: every scene outside the scope, and in-scope scenes
    # nothing could be resolved for.
    reserved = []
    model.pages.each { |pg| reserved << pg.name.to_s unless in_scope[pg.object_id] }
    rows.each { |r| reserved << r[:now] if r[:base].nil? }

    names = assign_names(rows.map { |r| [r[:n], r[:now], r[:base]] }, reserved)

    by_base = {}
    rows.each { |r| (by_base[r[:base].downcase] ||= []) << r[:n] if r[:base] }

    rows.each do |r|
      r[:new] = names[r[:n]]
      if r[:base].nil?
        r[:state] = 'none'
      elsif r[:new] == r[:now]
        r[:state] = 'same'
        r[:notes] << 'already named after this part'
      else
        r[:state] = 'ok'
        r[:notes] << "\"#{r[:base]}\" is taken, so this one is numbered" if r[:new] != r[:base]
      end
      if r[:base]
        sib = by_base[r[:base].downcase] - [r[:n]]
        r[:notes] << "scene#{sib.length == 1 ? '' : 's'} #{sib.join(', ')} look at the same part" unless sib.empty?
      end
    end

    rows = rows.sort_by { |r| [r[:state] == 'none' ? 0 : 1, r[:rank], r[:n]] }
    @rows = rows
    to_json_plan(rows, scope, note)
  end

  def self.approvable?(r)
    r[:state] == 'ok'
  end

  def self.preticked?(r)
    r[:tier] == 'RAY' && r[:state] == 'ok' &&
      r[:notes].none? { |t| t.include?('top level') }
  end

  def self.to_json_plan(rows, scope, note)
    out = rows.map do |r|
      { 'n' => r[:n], 'now' => r[:now], 'new' => r[:new].to_s, 'tier' => r[:tier],
        'state' => r[:state], 'how' => r[:how], 'notes' => r[:notes],
        'ok' => approvable?(r), 'pick' => preticked?(r) }
    end
    {
      'scope' => scope, 'note' => note, 'rows' => out,
      'total' => out.length,
      'ready' => out.count { |r| r['ok'] },
      'ray'   => out.count { |r| r['ok'] && r['tier'] == 'RAY' },
      'weak'  => out.count { |r| r['ok'] && r['tier'] != 'RAY' },
      'same'  => out.count { |r| r['state'] == 'same' },
      'none'  => out.count { |r| r['state'] == 'none' }
    }
  end

  # ------------------------------------------------------------------ apply --
  #
  # Returns [renamed, skipped, notes]: renamed [[n, was, got], ...], skipped
  # [[n, was, reason], ...].
  def self.apply(model, ids)
    want = {}
    ids.each { |i| want[i.to_i] = true }
    chosen  = (@rows || []).select { |r| want[r[:n]] && approvable?(r) }
    renamed = []
    skipped = []
    notes   = []

    # Stale rows: the table was built at some earlier moment.
    chosen = chosen.select do |r|
      if !(r[:page].valid? rescue false)
        skipped << [r[:n], r[:now], 'scene deleted since the table was built']
        false
      elsif r[:page].name.to_s != r[:now]
        skipped << [r[:n], r[:now], "scene is now called \"#{r[:page].name}\" — rescan"]
        false
      else
        true
      end
    end

    # A ticked row may not take a name held by any scene that is NOT being
    # renamed — including a row you left unticked. Skip, never renumber.
    loop do
      moving = {}
      chosen.each { |r| moving[r[:page].object_id] = true }
      held = {}
      model.pages.each do |pg|
        held[pg.name.to_s.downcase] = pg.name.to_s unless moving[pg.object_id]
      end
      bad, chosen = chosen.partition { |r| held.key?(r[:new].downcase) }
      break if bad.empty?
      bad.each do |r|
        skipped << [r[:n], r[:now],
                    "\"#{r[:new]}\" is held by a scene that is not being renamed " \
                    '(unticked or out of scope) — tick it too, or rename it']
      end
      # Skipping a row keeps ITS name, which may now block another: go again.
    end

    # In-batch duplicates cannot happen by construction; refuse rather than trust.
    count = Hash.new(0)
    chosen.each { |r| count[r[:new].downcase] += 1 }
    dup, chosen = chosen.partition { |r| count[r[:new].downcase] > 1 }
    dup.each { |r| skipped << [r[:n], r[:now], "two ticked rows both want \"#{r[:new]}\""] }

    return [renamed, skipped, notes] if chosen.empty?

    original = chosen.map { |r| [r[:page], r[:now]] }
    stamp = Time.now.to_i
    model.start_operation(TITLE, true)
    begin
      # Pass 1: unique temporary names, so swaps never collide mid-way.
      chosen.each_with_index { |r, k| r[:page].name = "__wr_nsap_#{stamp}_#{k}" }
      # Pass 2: final names.
      chosen.each { |r| r[:page].name = r[:new] }

      wrong = chosen.reject { |r| r[:page].name.to_s == r[:new] }
      unless wrong.empty?
        model.abort_operation
        restore(original)
        lines = wrong.map { |r| "scene #{r[:n]}: wanted \"#{r[:new]}\", SketchUp gave \"#{r[:page].name}\"" }
        return [[], wrong.map { |r| [r[:n], r[:now], 'WHOLE BATCH ABORTED — ' + lines.join('; ')] }, notes]
      end
      model.commit_operation
    rescue Exception => e
      model.abort_operation
      restore(original)
      raise e
    end

    chosen.each { |r| renamed << [r[:n], r[:now], r[:page].name.to_s] }
    [renamed, skipped, notes]
  end

  # abort_operation should already have put every name back; this checks, and
  # repairs any it did not, so no scene is ever left on a temporary name.
  def self.restore(original)
    original.each do |pg, was|
      begin
        pg.name = was if (pg.valid? rescue false) && pg.name.to_s != was
      rescue Exception => e
        puts "#{TITLE}: could not restore \"#{was}\": #{e.class}: #{e.message}"
      end
    end
  end

  # Read only. Activates a scene and selects its part so a doubtful row can be
  # looked at. Not on the apply path.
  def self.peek(model, n)
    r = (@rows || []).find { |row| row[:n] == n.to_i }
    return nil if r.nil?
    begin
      model.pages.selected_page = r[:page] if r[:page] && (r[:page].valid? rescue false)
    rescue Exception
      nil
    end
    begin
      model.selection.clear
      model.selection.add(r[:ent]) if r[:ent] && (r[:ent].valid? rescue false)
    rescue Exception
      nil
    end
    nil
  end

  # ---------------------------------------------------------------- console --

  def self.print_plan(info)
    puts ''
    puts '=' * 74
    puts "#{TITLE} — #{info['note']}"
    puts format('  %-4s %-8s %-26s %-26s %s', '#', 'TIER', 'SCENE NOW', 'BECOMES', 'HOW')
    info['rows'].each do |r|
      puts format('  %-4d %-8s %-26s %-26s %s', r['n'], r['tier'], r['now'].to_s[0, 26],
                  r['new'].to_s[0, 26], r['how'])
      r['notes'].each { |t| puts "        NOTE  #{t}" }
    end
    puts "  #{info['ray']} by ray, #{info['weak']} by fallback, #{info['same']} already named, " \
         "#{info['none']} unresolved"
    puts '  NOTHING HAS CHANGED — only ticked rows in the window are applied.'
    puts '=' * 74
    nil
  end

  def self.print_result(renamed, skipped, notes)
    puts ''
    puts "#{TITLE} — renamed #{renamed.length}, skipped #{skipped.length}"
    renamed.each { |n, was, got| puts format('  %-4d OK    "%s" -> "%s"', n, was, got) }
    skipped.each { |n, was, why| puts format('  %-4d SKIP  %s — %s', n, was, why) }
    notes.each   { |t| puts "  NOTE  #{t}" }
    puts '  Ctrl+Z reverses the whole batch.' unless renamed.empty?
    puts ''
    nil
  end

  # ----------------------------------------------------------------- window --

  def self.scope_from(payload)
    s = (JSON.parse(payload.to_s) rescue {})
    s = {} unless s.is_a?(Hash)
    mode = %w[unnamed positions].include?(s['mode']) ? s['mode'] : 'unnamed'
    { 'mode' => mode, 'spec' => s['spec'].to_s }
  end

  def self.run
    model = Sketchup.active_model
    if model.nil?
      UI.messagebox('No model is open.')
      return nil
    end
    if model.pages.count.zero?
      UI.messagebox("This model has no scenes.\n\nThere is nothing to rename.")
      return nil
    end

    scope = saved_scope
    info  = plan(model, scope)
    print_plan(info)

    d = UI::HtmlDialog.new(
      :dialog_title    => 'Name scenes after their parts',
      :preferences_key => 'com.whisperroom.namescenesafterparts',
      :scrollable      => true,
      :resizable       => true,
      :width           => 980,
      :height          => 660,
      :min_width       => 680,
      :min_height      => 400,
      :style           => UI::HtmlDialog::STYLE_DIALOG
    )
    d.set_html(html(info))

    d.add_action_callback('rescan') do |_c, payload|
      begin
        scope = scope_from(payload)
        write_pref('mode', scope['mode'])
        write_pref('spec', scope['spec'])
        info = plan(model, scope)
        print_plan(info)
        d.execute_script("render(#{info.to_json})")
      rescue Exception => e
        puts "FAILED: #{e.class}: #{e.message}"
        puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
      end
    end

    d.add_action_callback('peek') { |_c, n| peek(model, n) }

    d.add_action_callback('apply') do |_c, payload|
      begin
        ids = JSON.parse(payload.to_s)
        ids = [] unless ids.is_a?(Array)
        renamed, skipped, notes = apply(model, ids)
        print_result(renamed, skipped, notes)
        bits = ["Renamed #{renamed.length} scene#{renamed.length == 1 ? '' : 's'}."]
        unless skipped.empty?
          shown = skipped.first(10).map { |sn, was, why| "  #{sn}. #{was} — #{why}" }.join("\n")
          more  = skipped.length > 10 ? "\n  (+#{skipped.length - 10} more in the Ruby Console.)" : ''
          bits << "Skipped #{skipped.length}:\n#{shown}#{more}"
        end
        bits << 'Ctrl+Z reverses the whole batch.' unless renamed.empty?
        UI.messagebox(bits.join("\n\n"))
        d.execute_script("render(#{plan(model, scope).to_json})")
      rescue Exception => e
        puts "FAILED: #{e.class}: #{e.message}"
        puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
        UI.messagebox("Apply failed:\n\n#{e.class}: #{e.message}\n\n" \
                      'Full backtrace is in the Ruby Console. Ctrl+Z if anything looks changed.')
      end
    end

    d.add_action_callback('close') { |_c| d.close }
    d.show
    nil
  end

  # ------------------------------------------------------------------- html --

  def self.html(info)
    data = info.to_json
    <<-HTML
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Name scenes after their parts</title>
<style>
  :root { --bg:#f4f5f6; --surface:#fff; --ink:#1c2327; --muted:#66727a;
          --faint:#9aa4ab; --line:#e2e6e9; --accent:#ee6216; --soft:#fdeee4;
          --go:#2e7d46; --warn:#a5701c; --clash:#b0402c; --skip:#9aa4ab; }
  * { box-sizing:border-box; margin:0; }
  html,body { height:100%; }
  body { font:13px/1.45 "Segoe UI",system-ui,sans-serif; background:var(--bg);
         color:var(--ink); display:flex; flex-direction:column; overflow:hidden; }
  .top { padding:12px 14px 6px; display:flex; gap:8px; align-items:center; }
  .top .t { font-weight:650; margin-right:auto; }
  .btn { font:inherit; font-size:12px; padding:6px 12px; border:1px solid var(--line);
         border-radius:6px; background:var(--surface); color:var(--ink); cursor:pointer; }
  .btn:hover { border-color:var(--accent); }
  .btn.p { background:var(--accent); border-color:var(--accent); color:#fff; }
  .btn.p:disabled { background:var(--skip); border-color:var(--skip); cursor:default; }
  .bar { padding:0 14px 10px; display:flex; gap:8px; align-items:center; flex-wrap:wrap; }
  .scope { padding:0 14px 8px; display:flex; gap:12px; align-items:center; font-size:12px; }
  .scope label { display:flex; gap:5px; align-items:center; cursor:pointer; }
  .scope .note { color:var(--muted); margin-left:auto; }
  input[type=text] {
    font:13px ui-monospace,Consolas,monospace; padding:5px 9px; width:240px;
    border:1px solid var(--line); border-radius:6px; background:var(--surface); color:var(--ink);
  }
  input[type=text]:focus { outline:2px solid var(--accent); outline-offset:-1px; }
  input[type=text]:disabled { color:var(--faint); background:var(--bg); }
  .tally { font-size:12px; color:var(--muted); margin-left:auto; }
  .tally b { color:var(--ink); }
  .tally .c { color:var(--clash); font-weight:650; }
  .wrap { flex:1 1 auto; overflow:auto; margin:0 14px 8px; }
  table { width:100%; border-collapse:collapse; background:var(--surface);
          border:1px solid var(--line); border-radius:9px; overflow:hidden; }
  th { text-align:left; font-size:10.5px; letter-spacing:.08em; text-transform:uppercase;
       color:var(--faint); font-weight:700; padding:8px 10px;
       border-bottom:1px solid var(--line); position:sticky; top:0; background:var(--surface); }
  td { padding:6px 10px; border-bottom:1px solid var(--line); font-size:12.5px;
       font-family:ui-monospace,Consolas,monospace; vertical-align:top; }
  tr:last-child td { border-bottom:0; }
  td.n { color:var(--faint); text-align:right; }
  td.arrow { color:var(--faint); padding:6px 0; }
  td.tier { font-family:"Segoe UI",system-ui,sans-serif; font-size:10.5px; font-weight:700;
            letter-spacing:.06em; white-space:nowrap; }
  tr.t3 td.tier { color:var(--go); }
  tr.t2 td.tier { color:var(--warn); }
  tr.t1 td.tier { color:var(--clash); }
  tr.t0 td, tr.same td { color:var(--skip); }
  td.note { font-family:"Segoe UI",system-ui,sans-serif; font-size:11.5px; color:var(--muted); }
  td.note .flag { color:var(--clash); font-weight:650; }
  .look { font-family:"Segoe UI",system-ui,sans-serif; font-size:11px; color:var(--accent);
          cursor:pointer; text-decoration:underline; user-select:none; }
  .warnbox { margin:0 14px 8px; padding:9px 12px; border-radius:8px; font-size:12px;
             background:var(--soft); border:1px solid #f0c3a6; color:#8a3a22; }
  .empty { padding:18px; text-align:center; color:var(--muted);
           font-family:"Segoe UI",system-ui,sans-serif; }
  .foot { padding:0 14px 12px; color:var(--muted); font-size:11.5px; }
</style></head><body>

<div class="top">
  <span class="t">Name scenes after their parts</span>
  <button class="btn p" id="apply">Apply</button>
  <button class="btn" id="close">Close</button>
</div>

<div class="scope">
  <label><input type="radio" name="mode" value="unnamed"> Unnamed scenes (Scene N)</label>
  <label><input type="radio" name="mode" value="positions"> Positions</label>
  <input type="text" id="spec" placeholder="355-422, 430, 440-445" spellcheck="false" autocomplete="off">
  <button class="btn" id="rescan">Scan</button>
  <span class="note" id="note"></span>
</div>

<div class="bar">
  <button class="btn" id="none">Tick none</button>
  <button class="btn" id="ray">Tick ray hits</button>
  <button class="btn" id="all">Tick everything resolved</button>
  <span class="tally" id="tally"></span>
</div>

<div class="warnbox" id="warn" style="display:none"></div>
<div class="wrap"><table id="tbl"><thead><tr>
  <th style="width:34px">&nbsp;</th>
  <th style="width:46px">#</th>
  <th style="width:21%">Scene now</th>
  <th style="width:18px">&nbsp;</th>
  <th style="width:24%">Becomes</th>
  <th style="width:74px">Tier</th>
  <th>Why, and anything worth knowing</th>
  <th style="width:52px">&nbsp;</th>
</tr></thead><tbody id="rows"></tbody></table></div>
<div class="foot"># is the scene's position in the Scenes panel. Weakest rows are at the top.
  Only ticked rows are applied, and the whole batch is one Ctrl+Z. Numbered names
  assume every resolved row is applied; an unticked row keeps its name, and a ticked
  row that would collide with it is skipped, not renumbered.</div>

<script>
(function () {
  "use strict";
  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
  }

  var $rows = document.getElementById("rows");
  var $tally = document.getElementById("tally");
  var $warn = document.getElementById("warn");
  var $apply = document.getElementById("apply");
  var $spec = document.getElementById("spec");
  var $note = document.getElementById("note");
  var RANK = { RAY: 3, BOUNDS: 2, "OFF-AXIS": 1, TARGET: 1, NAME: 3, NONE: 0 };
  var data = { rows: [] };

  function mode() {
    var m = document.querySelector("input[name=mode]:checked");
    return m ? m.value : "unnamed";
  }
  function scan() {
    sketchup.rescan(JSON.stringify({ mode: mode(), spec: $spec.value }));
  }

  function checks() {
    return Array.prototype.slice.call($rows.querySelectorAll("input[type=checkbox]"));
  }
  function picked() {
    return checks().filter(function (c) { return c.checked; })
                   .map(function (c) { return parseInt(c.value, 10); });
  }

  function tally() {
    var ids = picked();
    $tally.innerHTML = "<b>" + ids.length + "</b> ticked of " + data.ready +
      " to rename &middot; " + data.ray + " ray &middot; " + data.weak + " fallback &middot; " +
      data.same + " already named" +
      (data.none ? " &middot; <span class='c'>" + data.none + " unresolved</span>" : "") +
      " &middot; " + data.total + " in scope";
    var msg = "";
    if (data.none) {
      msg = data.none + " scene(s) resolved to no named part. They keep their names and " +
            "cannot be ticked.";
    }
    $warn.style.display = msg ? "" : "none";
    $warn.textContent = msg;
    $apply.disabled = ids.length === 0;
    $apply.textContent = ids.length ? "Apply " + ids.length + " row" + (ids.length === 1 ? "" : "s")
                                    : "Apply";
  }

  window.render = function (info) {
    data = info;
    var sc = info.scope || { mode: "unnamed", spec: "" };
    document.querySelectorAll("input[name=mode]").forEach(function (r) {
      r.checked = r.value === sc.mode;
    });
    if (document.activeElement !== $spec) $spec.value = sc.spec || "";
    $spec.disabled = sc.mode !== "positions";
    $note.textContent = info.note || "";

    if (!(info.rows || []).length) {
      $rows.innerHTML = '<tr><td colspan="8" class="empty">No scenes in scope.</td></tr>';
      tally();
      return;
    }
    $rows.innerHTML = info.rows.map(function (r) {
      var cls = "t" + (RANK[r.tier] === undefined ? 0 : RANK[r.tier]) +
                (r.state === "same" ? " same" : "");
      var box = r.ok
        ? '<input type="checkbox" value="' + r.n + '"' + (r.pick ? " checked" : "") + '>'
        : "";
      var notes = (r.notes || []).map(function (t) {
        return '<div class="flag">' + esc(t) + "</div>";
      }).join("");
      var look = r.tier !== "NONE" ? '<span class="look" data-n="' + r.n + '">Show</span>' : "";
      return '<tr class="' + cls + '">' +
        "<td>" + box + "</td>" +
        '<td class="n">' + r.n + "</td>" +
        "<td>" + esc(r.now) + "</td>" +
        '<td class="arrow">&rarr;</td>' +
        "<td>" + (r.new ? esc(r.new) : "&mdash;") + "</td>" +
        '<td class="tier">' + esc(r.tier) + "</td>" +
        '<td class="note">' + esc(r.how) + notes + "</td>" +
        "<td>" + look + "</td></tr>";
    }).join("");
    tally();
  };

  $rows.addEventListener("change", tally);
  $rows.addEventListener("click", function (ev) {
    var el = ev.target;
    if (el && el.className === "look") sketchup.peek(el.getAttribute("data-n"));
  });

  function setAll(fn) {
    var by = {};
    data.rows.forEach(function (r) { by[r.n] = r; });
    checks().forEach(function (c) {
      var r = by[parseInt(c.value, 10)];
      c.checked = !!(r && fn(r));
    });
    tally();
  }
  document.getElementById("none").addEventListener("click", function () {
    setAll(function () { return false; });
  });
  document.getElementById("ray").addEventListener("click", function () {
    setAll(function (r) { return r.tier === "RAY" && r.ok; });
  });
  document.getElementById("all").addEventListener("click", function () {
    setAll(function (r) { return r.ok; });
  });

  document.querySelectorAll("input[name=mode]").forEach(function (r) {
    r.addEventListener("change", function () {
      $spec.disabled = mode() !== "positions";
      if (mode() === "positions") $spec.focus();
      scan();
    });
  });
  $spec.addEventListener("keydown", function (ev) { if (ev.key === "Enter") scan(); });
  document.getElementById("rescan").addEventListener("click", scan);

  $apply.addEventListener("click", function () {
    if (!$apply.disabled) sketchup.apply(JSON.stringify(picked()));
  });
  document.getElementById("close").addEventListener("click", function () { sketchup.close(); });

  render(#{data});
}());
</script>
</body></html>
    HTML
  end
end

begin
  WR_NameScenesAfterParts.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Name Scenes After Parts failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console.')
end
