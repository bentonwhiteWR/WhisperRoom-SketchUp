# @title Bulk Name After Scenes...
# @cat Tidy up the model
# @rank 2
# @icon names-bulk
#
# The whole gap list in one window. Every scene that has no component of its
# name is resolved to a best-guess part, the pairings are shown as a TABLE, and
# only the rows you tick are applied.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/bulk-name-after-scenes.rb"
#
# WHY IT EXISTS. name-selection-after-scene.rb is the safe tool and stays the
# safe tool: you point at a part, it names it, no inference. But twenty-five
# scenes means twenty-five rounds of scene-click, part-click, run. This is the
# same job with the clicking collapsed into one review pass.
#
# THE REVIEW TABLE IS THE FEATURE, NOT A CONFIRMATION STEP. There is no code
# path in this file that renames anything without the table having been shown
# and rows having been ticked. That is deliberate and it is the entire reason
# this script is allowed to exist beside the deliberately-dumb single-item tool.
# Every guessing scheme in this project has at some point picked the wrong part
# and written a file under someone else's name; the guess is still made here,
# but it is made in front of you and it does not become a rename until you say
# so.
#
# THE GUESS IS NOT NEW CODE. subject_for, geometry_subject_for, view_direction,
# fallback_for, ray_box_entry, ray_offsets, top_level_index, pick_instance and
# near_misses are COPIED VERBATIM out of save-scene-components.rb, along with
# scene_label, AUTONAME, definition_of and definition_name. Two measured dry
# runs over 112 scenes are behind the shape of that resolver and none of that
# evidence was re-gathered here, so none of it was re-litigated here either.
# The copy is a real cost — two files now hold one rule and they can drift. It
# is taken because save-scene-components.rb RUNS ON LOAD (it ends by calling
# WR_SaveSceneComponents.run), so `load`ing it to borrow a method would open its
# export dialog. If that ever changes, delete these copies and require it.
#
# CONFIDENCE IS SHOWN BECAUSE IT VARIES ENORMOUSLY. The resolver reports how it
# got its answer and the table repeats that verbatim in the Notes column, sorted
# so the weak rows are at the TOP where they get looked at rather than buried
# under a screen of good ones:
#
#   RAY      the scene camera's ray struck this part. The strong tier.
#   BOUNDS   the ray missed every face but passed through this part's box.
#   OFF-AXIS nothing was hit; this part sits nearest the line of sight. A guess.
#   TARGET   the scene has no usable view direction at all. A weaker guess.
#   NONE     no component found. Never approvable, never pre-ticked.
#
# ONLY RAY ROWS ARE PRE-TICKED, and even those only when they carry no warning.
# Everything below RAY starts unticked on purpose: on this model's parallel
# projections the eye is effectively at infinity, so the fallback tiers are
# arithmetic, not evidence. Tick them once you have looked.
#
# NAMES ARE READ BACK, same rule and same reason as the single-item tool.
# ComponentDefinition#name= does not raise when the name is taken — the docs say
# plainly "if it's not [unique] the name will automatically be made unique". A
# "#2" suffix is not a rename, it is a second copy of the problem this script
# exists to clear. So every name is read back after assignment and a uniquified
# result is refused.
#
# COLLISIONS SKIP THE ROW, THEY DO NOT ABORT THE BATCH — and this DELIBERATELY
# DIFFERS from name-selection-after-scene.rb, which aborts the whole operation.
# Aborting is right when the operation is one rename: you learn the name is
# taken, you free it, you press the button again. It is maddening across
# twenty-five rows, where one taken name would throw away twenty-four good
# renames. So a row that cannot take its EXACT name is put back the way it was,
# left out, and named in the closing report. What is NOT done is accept the
# uniquified name — that is still refused, it is only the blast radius that
# shrank. If a row cannot even be put back, THAT does abort the whole batch,
# because a definition left holding a name nobody asked for is the one outcome
# worse than doing nothing.
#
# COLLISIONS INSIDE THE BATCH ARE CAUGHT AT REVIEW TIME. Two scenes with the
# same label both want the same name and only one can have it; two scenes that
# resolved to the SAME part want to rename one definition twice, and the second
# would silently undo the first. Neither is visible in a per-row rename — they
# only exist as a set — so both are detected while the table is being built,
# flagged in it, and dropped as a group at Apply rather than half-applied.
#
# ONE UNDO STEP. Every approved row goes inside one model.start_operation, so a
# single Ctrl+Z reverses the entire batch.
#
# GROUPS. A group's DEFINITION name is what save-scene-components.rb matches on,
# but Entity Info shows the group's INSTANCE name. So for a group this sets
# both, exactly as name-selection-after-scene.rb does. Component instance names
# are left alone — an instance name on a component is a separate, meaningful
# field and is not ours to overwrite.
#
# SHOW is read-only. The Show link on a row activates that scene and selects the
# proposed part so a doubtful match can be eyeballed. It moves the camera and
# the selection and touches nothing else; it is not on the apply path.

require 'sketchup.rb'
require 'json'

module WR_BulkNameAfterScenes

  TITLE = 'Bulk Name After Scenes'.freeze

  # SketchUp's own placeholder names. Treated as "no name", the same way
  # save-scene-components.rb and name-selection-after-scene.rb treat them. This
  # regex must stay identical to theirs or the gap list will not agree with the
  # exporter's.
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

  # Definition names of everything at the TOP LEVEL of the model. That is the
  # only place save-scene-components.rb looks, so it is the only place that
  # counts for the gap report. Lifted from name-selection-after-scene.rb.
  def self.top_level_names(model)
    names = {}
    model.entities.each do |e|
      next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      defn = definition_of(e)
      next if defn.nil?
      n = definition_name(defn)
      names[n] = true unless n.empty?
    end
    names
  end

  # Is this entity at the top level of the model? A part renamed while still
  # nested keeps its new name but stays invisible to the exporter.
  def self.top_level?(model, ent)
    model.entities.include?(ent)
  rescue Exception
    true
  end

  # Every scene whose label matches no top-level definition name. READ ONLY.
  # Returns [[scene_number, label, page], ...]. Same rule as the single-item
  # tool's #gaps, carrying the page along so the resolver can read its camera.
  def self.gaps(model)
    have = top_level_names(model)
    out  = []
    model.pages.each_with_index do |pg, i|
      label = scene_label(pg)
      next if label.empty?
      out << [i + 1, label, pg] unless have.key?(label)
    end
    out
  end

  # Lifted from save-scene-components.rb#rename_to, and it must stay lifted: the
  # reason it reads the name back is the reason this whole family of scripts
  # exists. Returns [name_now, warning_or_nil].
  def self.rename_to(defn, want)
    was = defn.name.to_s
    return [was, nil] if was == want
    begin
      defn.name = want
    rescue Exception => e
      return [was, "rename failed: #{e.class}: #{e.message.to_s.split("\n").first}"]
    end
    got = defn.name.to_s
    return [got, nil] if got == want
    [got, "NAME TAKEN — wanted \"#{want}\", model gave \"#{got}\""]
  end

  # ------------------------------------------------------------------ tiers --
  #
  # The resolver labels every branch it takes in the string it returns. Rather
  # than have this file re-derive confidence from geometry — a second opinion
  # that could disagree with the first — the label is read back and classified.
  # Returns [tier, confidence_rank] with 0 the weakest.
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

  # ------------------------------------------------------------------- plan --
  #
  # Builds the review table. READ ONLY — this method must never write to the
  # model, and every guard the apply path relies on is decided here so that
  # what is shown is what will happen.
  #
  # Keeps two parallel structures: @rows carries live entity references for the
  # apply path, and the returned Hash carries plain data for the window. Only
  # the Hash crosses into JavaScript.
  def self.plan(model)
    index = top_level_index(model)
    rows  = []

    gaps(model).each do |n, label, page|
      subj, how = subject_for(model, page, index)
      # A part with no readable definition is nothing we can rename, so it is
      # dropped BEFORE the tier is worked out — otherwise the table would
      # advertise a confident RAY hit on a row that cannot be approved.
      defn = subj ? definition_of(subj) : nil
      subj = nil if defn.nil?
      tier, rank = tier_of(subj, how)

      notes = []
      state = subj ? 'ok' : 'none'

      if subj
        count = (defn.instances.length rescue 1)
        notes << "definition has #{count} instances — renaming it renames all of them" if count > 1
        unless top_level?(model, subj)
          notes << 'NOT at the model top level — the exporter only scans the top level, ' \
                   'so this scene will still read as a gap after the rename'
          state = 'warn'
        end

        # Definition names are unique per model, and that includes definitions
        # that are nested or not placed at all. top_level_names cannot see
        # those, so the gap list can contain a scene whose name is already held
        # somewhere out of sight. Ask the definition list directly.
        taken = (model.definitions[label] rescue nil)
        if taken && !taken.equal?(defn)
          notes << "another definition in this model is already called \"#{label}\""
          state = 'taken'
        end
      else
        count = 0
        notes << 'no component could be resolved for this scene — name it by hand with ' \
                 'Name Selection After Scene'
      end

      rows << {
        :n     => n,
        :page  => page,
        :ent   => subj,
        :defn  => defn,
        :scene => label,
        :now   => defn ? defn.name.to_s : '',
        :kind  => subj.is_a?(Sketchup::Group) ? 'Group' : (subj ? 'Component' : ''),
        :tier  => tier,
        :rank  => rank,
        :how   => how.to_s,
        :inst  => count,
        :state => state,
        :notes => notes
      }
    end

    flag_batch_collisions(rows)

    # Weakest and most-troubled first. A twenty-five row table is a screen and a
    # half, and the rows that need a decision must not be the ones you have to
    # scroll to find.
    rows = rows.sort_by do |r|
      [problem?(r) ? 0 : 1, r[:rank], r[:n]]
    end

    @rows = rows
    to_json_plan(rows)
  end

  def self.problem?(r)
    %w[none taken dup twin].include?(r[:state])
  end

  # Collisions that exist only as a SET and are invisible row by row.
  #
  #   dup   two gap scenes carry the same label, so both want the same name and
  #         only one can have it.
  #   twin  two gap scenes resolved to the SAME part, so approving both renames
  #         one definition twice and the second silently undoes the first.
  #
  # Both are marked on every member of the group. Neither is repairable here —
  # the fix is to fix the model or approve one of them — so they are flagged and
  # dropped as a group at Apply.
  def self.flag_batch_collisions(rows)
    by_name = {}
    by_ent  = {}
    rows.each do |r|
      (by_name[r[:scene]] ||= []) << r
      next if r[:defn].nil?
      (by_ent[defn_id(r)] ||= []) << r
    end

    by_name.each do |name, group|
      next if group.length < 2
      others = group.map { |r| r[:n] }
      group.each do |r|
        r[:state] = 'dup'
        r[:notes] << "scenes #{others.join(', ')} all carry the name \"#{name}\" — " \
                     'only one of them can hold it'
      end
    end

    by_ent.each do |_id, group|
      next if group.length < 2
      others = group.map { |r| r[:n] }
      group.each do |r|
        r[:state] = 'twin' unless r[:state] == 'dup'
        r[:notes] << "scenes #{others.join(', ')} all resolved to the same part — " \
                     'approving more than one would rename it twice'
      end
    end
    rows
  end

  # Ticked by default: RAY rows with nothing wrong with them, and nothing else.
  # The fallback tiers are arithmetic, not evidence — see the header.
  def self.preticked?(r)
    r[:tier] == 'RAY' && r[:state] == 'ok'
  end

  def self.approvable?(r)
    !r[:ent].nil? && r[:state] != 'none'
  end

  # entityID on a definition that has since been deleted is not something to
  # take on trust, and the answer only has to be a stable key for grouping —
  # object_id is a good enough one when the model will not answer.
  def self.defn_id(r)
    (r[:defn].entityID rescue nil) || r[:defn].object_id
  end

  def self.to_json_plan(rows)
    out = rows.map do |r|
      {
        'n'     => r[:n],
        'scene' => r[:scene],
        'now'   => r[:now],
        'kind'  => r[:kind],
        'tier'  => r[:tier],
        'state' => r[:state],
        'how'   => r[:how],
        'inst'  => r[:inst],
        'notes' => r[:notes],
        'ok'    => approvable?(r),
        'pick'  => preticked?(r)
      }
    end
    {
      'rows'  => out,
      'total' => out.length,
      'ready' => out.count { |r| r['ok'] },
      'ray'   => out.count { |r| r['tier'] == 'RAY' },
      'weak'  => out.count { |r| r['ok'] && r['tier'] != 'RAY' },
      'none'  => out.count { |r| r['tier'] == 'NONE' },
      'bad'   => out.count { |r| %w[dup twin taken].include?(r['state']) }
    }
  end

  # ------------------------------------------------------------------ apply --
  #
  # Only ids that came back from the window get here, and only ids that were
  # approvable when the table was built survive the filter. Everything runs
  # inside ONE operation so a single Ctrl+Z reverses the batch.
  #
  # Returns [renamed, skipped, notes] where renamed is [[n, was, got], ...] and
  # skipped is [[n, scene, reason], ...].
  def self.apply(model, ids)
    want = {}
    ids.each { |i| want[i.to_i] = true }

    chosen = (@rows || []).select { |r| want[r[:n]] && approvable?(r) }
    renamed = []
    skipped = []
    notes   = []

    # Batch collisions are dropped as a GROUP rather than half-applied. They
    # were flagged in the table, so this is the second line of defence, not the
    # first — but the window cannot be trusted to have enforced it and the model
    # is what pays for a mistake here.
    seen_name = {}
    seen_ent  = {}
    chosen.each do |r|
      seen_name[r[:scene]] = (seen_name[r[:scene]] || 0) + 1
      id = defn_id(r)
      seen_ent[id] = (seen_ent[id] || 0) + 1
    end
    chosen, clashing = chosen.partition do |r|
      seen_name[r[:scene]] == 1 && seen_ent[defn_id(r)] == 1
    end
    clashing.each do |r|
      skipped << [r[:n], r[:scene],
                  'two or more approved rows want the same name or the same part — ' \
                  'approve one of them and run again']
    end

    return [renamed, skipped, notes] if chosen.empty?

    model.start_operation(TITLE, true)
    begin
      chosen.each do |r|
        defn = r[:defn]
        ent  = r[:ent]

        # The table was built at some earlier moment and the model may have
        # moved since. A stale reference is a skip, not a crash.
        unless (defn.valid? rescue false) && (ent.valid? rescue false)
          skipped << [r[:n], r[:scene], 'the part has been deleted since the table was built']
          next
        end

        was = defn.name.to_s
        if was != r[:now]
          skipped << [r[:n], r[:scene],
                      "the part was called \"#{r[:now]}\" when the table was built and is " \
                      "now called \"#{was}\" — rescan and look again"]
          next
        end
        if was == r[:scene]
          skipped << [r[:n], r[:scene], 'already named that']
          next
        end

        # Ask first. rename_to would catch a taken name anyway by reading it
        # back, but only after having assigned a uniquified one, and putting
        # that back is a repair we would rather not perform at all.
        held = (model.definitions[r[:scene]] rescue nil)
        if held && !held.equal?(defn)
          skipped << [r[:n], r[:scene],
                      "\"#{r[:scene]}\" is already held by another definition in this model"]
          next
        end

        got, warn = rename_to(defn, r[:scene])
        if warn
          # A uniquified name is not what was asked for. Put this ONE row back
          # and keep going — see the header on why this does not abort the
          # batch the way the single-item tool does.
          back, bad = rename_to(defn, was)
          if bad
            # The definition is now holding a name nobody asked for and will not
            # give it up. That is worse than doing nothing, so undo everything.
            model.abort_operation
            line = "#{TITLE}: could not undo a refused rename on scene #{r[:n]} " \
                   "(wanted \"#{was}\" back, got \"#{back}\") — WHOLE BATCH ABORTED, " \
                   'model unchanged.'
            puts line
            UI.messagebox("#{line}\n\nNothing was renamed. #{bad}")
            return [[], [[r[:n], r[:scene], line]], notes]
          end
          skipped << [r[:n], r[:scene], warn]
          next
        end

        # For a group, also set the INSTANCE name, so Entity Info and the
        # Outliner show what the exporter now matches on. Component instance
        # names are left alone.
        if ent.is_a?(Sketchup::Group)
          begin
            ent.name = r[:scene]
          rescue Exception => e
            notes << "scene #{r[:n]}: definition renamed, but the group's instance name " \
                     "could not be set (#{e.class}). Entity Info will still show the old label."
          end
        end

        notes << "scene #{r[:n]}: \"#{got}\" is NOT at the model top level — the exporter " \
                 'will still report this scene as a gap.' unless top_level?(model, ent)
        notes << "scene #{r[:n]}: \"#{got}\" has #{r[:inst]} instances — all of them are " \
                 'now called that, because they share the one definition.' if r[:inst] > 1

        renamed << [r[:n], was, got]
      end
      model.commit_operation
    rescue Exception => e
      model.abort_operation
      raise e
    end

    [renamed, skipped, notes]
  end

  # Read only. Activates a scene and selects its proposed part so a doubtful
  # row can be looked at. Deliberately not on the apply path.
  def self.peek(model, n)
    r = (@rows || []).find { |row| row[:n] == n.to_i }
    return nil if r.nil?
    begin
      model.pages.selected_page = r[:page] if r[:page]
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
    puts "#{TITLE} — #{info['total']} scene(s) with no matching top-level definition"
    puts format('  %-4s %-6s %-28s %-22s %s', '#', 'TIER', 'SCENE NAME', 'PART NOW', 'HOW')
    info['rows'].each do |r|
      puts format('  %-4d %-6s %-28s %-22s %s',
                  r['n'], r['tier'], r['scene'].to_s[0, 28],
                  r['now'].to_s[0, 22], r['how'])
      r['notes'].each { |t| puts "        NOTE  #{t}" }
    end
    puts "  #{info['ray']} by ray, #{info['weak']} by fallback, " \
         "#{info['none']} unresolved, #{info['bad']} flagged"
    puts '  NOTHING HAS CHANGED — only ticked rows in the window are applied.'
    puts '=' * 74
    nil
  end

  def self.print_result(renamed, skipped, notes)
    puts ''
    puts "#{TITLE} — renamed #{renamed.length}, skipped #{skipped.length}"
    renamed.each { |n, was, got| puts format('  %-4d OK    "%s" -> "%s"', n, was, got) }
    skipped.each { |n, scene, why| puts format('  %-4d SKIP  %s — %s', n, scene, why) }
    notes.each   { |t| puts "  NOTE  #{t}" }
    puts '  Ctrl+Z reverses the whole batch.' unless renamed.empty?
    puts ''
    nil
  end

  # ----------------------------------------------------------------- window --

  def self.run
    model = Sketchup.active_model
    if model.nil?
      UI.messagebox('No model is open.')
      return nil
    end

    if model.pages.count.zero?
      UI.messagebox("This model has no scenes.\n\n" \
                    'There is nothing to name anything after.')
      return nil
    end

    info = plan(model)
    print_plan(info)

    if info['total'].zero?
      UI.messagebox("Every scene name already matches a top-level definition.\n\n" \
                    'Nothing left to name.')
      return nil
    end

    d = UI::HtmlDialog.new(
      :dialog_title    => 'Bulk name after scenes',
      :preferences_key => 'com.whisperroom.bulknameafterscenes',
      :scrollable      => true,
      :resizable       => true,
      :width           => 940,
      :height          => 640,
      :min_width       => 660,
      :min_height      => 400,
      :style           => UI::HtmlDialog::STYLE_DIALOG
    )
    d.set_html(html(info))

    d.add_action_callback('rescan') do |_c|
      d.execute_script("render(#{plan(model).to_json})")
    end

    d.add_action_callback('peek') do |_c, n|
      peek(model, n)
    end

    d.add_action_callback('apply') do |_c, payload|
      begin
        ids = JSON.parse(payload.to_s)
        ids = [] unless ids.is_a?(Array)
        renamed, skipped, notes = apply(model, ids)
        print_result(renamed, skipped, notes)

        bits = ["Renamed #{renamed.length} part#{renamed.length == 1 ? '' : 's'}."]
        unless skipped.empty?
          shown = skipped.first(10).map { |sn, sc, why| "  #{sn}. #{sc} — #{why}" }.join("\n")
          more  = skipped.length > 10 ? "\n  (+#{skipped.length - 10} more in the Ruby Console.)" : ''
          bits << "Skipped #{skipped.length}:\n#{shown}#{more}"
        end
        left = plan(model)
        bits << "#{left['total']} scene#{left['total'] == 1 ? '' : 's'} still unmatched."
        bits << 'Ctrl+Z reverses the whole batch.' unless renamed.empty?
        UI.messagebox(bits.join("\n\n"))
        d.execute_script("render(#{left.to_json})")
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
<html lang="en"><head><meta charset="utf-8"><title>Bulk name after scenes</title>
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
  .bar { padding:0 14px 10px; display:flex; gap:8px; align-items:center; }
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
  td.tier { font-family:"Segoe UI",system-ui,sans-serif; font-size:10.5px; font-weight:700;
            letter-spacing:.06em; white-space:nowrap; }
  tr.t3 td.tier { color:var(--go); }
  tr.t2 td.tier { color:var(--warn); }
  tr.t1 td.tier { color:var(--clash); }
  tr.t0 td { color:var(--skip); }
  tr.bad { background:#fdf1ee; }
  tr.bad td.tier { color:var(--clash); }
  td.note { font-family:"Segoe UI",system-ui,sans-serif; font-size:11.5px; color:var(--muted); }
  td.note .flag { color:var(--clash); font-weight:650; }
  .look { font-family:"Segoe UI",system-ui,sans-serif; font-size:11px; color:var(--accent);
          cursor:pointer; text-decoration:underline; user-select:none; }
  .warnbox { margin:0 14px 8px; padding:9px 12px; border-radius:8px; font-size:12px;
             background:var(--soft); border:1px solid #f0c3a6; color:#8a3a22; }
  .foot { padding:0 14px 12px; color:var(--muted); font-size:11.5px; }
</style></head><body>

<div class="top">
  <span class="t">Bulk name after scenes</span>
  <button class="btn p" id="apply">Apply</button>
  <button class="btn" id="rescan">Rescan</button>
  <button class="btn" id="close">Close</button>
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
  <th style="width:38px">#</th>
  <th style="width:24%">Scene name (becomes)</th>
  <th style="width:20%">Part is called now</th>
  <th style="width:74px">Tier</th>
  <th>Why, and anything worth knowing</th>
  <th style="width:52px">&nbsp;</th>
</tr></thead><tbody id="rows"></tbody></table></div>
<div class="foot">Weakest rows are at the top on purpose. Only ticked rows are applied,
  and the whole batch is one Ctrl+Z. Show activates that scene and selects the part.</div>

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
  var RANK = { RAY: 3, BOUNDS: 2, "OFF-AXIS": 1, TARGET: 1, NAME: 3, NONE: 0 };
  var data = { rows: [] };

  function checks() {
    return Array.prototype.slice.call($rows.querySelectorAll("input[type=checkbox]"));
  }
  function picked() {
    return checks().filter(function (c) { return c.checked; })
                   .map(function (c) { return parseInt(c.value, 10); });
  }

  function tally() {
    var ids = picked();
    var byName = {}, byPart = {}, clash = 0;
    data.rows.forEach(function (r) {
      if (ids.indexOf(r.n) < 0) return;
      byName[r.scene] = (byName[r.scene] || 0) + 1;
      if (r.state === "twin" || r.state === "dup") clash++;
    });
    var dupes = Object.keys(byName).filter(function (k) { return byName[k] > 1; });

    $tally.innerHTML = "<b>" + ids.length + "</b> ticked of " + data.ready +
      " resolvable &middot; " + data.ray + " ray &middot; " + data.weak + " fallback" +
      (data.none ? " &middot; <span class='c'>" + data.none + " unresolved</span>" : "") +
      " &middot; " + data.total + " scenes";

    var msg = "";
    if (dupes.length || clash) {
      msg = "Ticked rows collide with each other. Two scenes cannot both take one name, " +
            "and one part cannot be renamed twice. Apply drops the whole colliding group " +
            "rather than half-applying it, so untick all but one of each.";
    } else if (data.none) {
      msg = data.none + " scene(s) resolved to no component at all. They cannot be ticked. " +
            "Name those by hand with Name Selection After Scene.";
    }
    $warn.style.display = msg ? "" : "none";
    $warn.textContent = msg;

    $apply.disabled = ids.length === 0;
    $apply.textContent = ids.length ? "Apply " + ids.length + " row" + (ids.length === 1 ? "" : "s")
                                    : "Apply";
  }

  window.render = function (info) {
    data = info;
    $rows.innerHTML = (info.rows || []).map(function (r) {
      var cls = "t" + (RANK[r.tier] === undefined ? 0 : RANK[r.tier]) +
                (r.state === "dup" || r.state === "twin" || r.state === "taken" ? " bad" : "");
      var box = r.ok
        ? '<input type="checkbox" value="' + r.n + '"' + (r.pick ? " checked" : "") + '>'
        : "";
      var notes = (r.notes || []).map(function (t) {
        return '<div class="flag">' + esc(t) + "</div>";
      }).join("");
      var inst = r.inst > 1 ? '<div class="flag">' + r.inst + " instances</div>" : "";
      var look = r.ok ? '<span class="look" data-n="' + r.n + '">Show</span>' : "";
      return '<tr class="' + cls + '">' +
        "<td>" + box + "</td>" +
        '<td class="n">' + r.n + "</td>" +
        "<td>" + esc(r.scene) + "</td>" +
        "<td>" + (r.now ? esc(r.now) : "&mdash;") + "</td>" +
        '<td class="tier">' + esc(r.tier) + "</td>" +
        '<td class="note">' + esc(r.how) + inst + notes + "</td>" +
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
    setAll(function (r) { return r.tier === "RAY" && r.state === "ok"; });
  });
  document.getElementById("all").addEventListener("click", function () {
    setAll(function (r) { return r.ok && r.state !== "dup" && r.state !== "twin"; });
  });

  $apply.addEventListener("click", function () {
    if (!$apply.disabled) sketchup.apply(JSON.stringify(picked()));
  });
  document.getElementById("rescan").addEventListener("click", function () {
    sketchup.rescan();
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
  WR_BulkNameAfterScenes.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Bulk Name After Scenes failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console.')
end
