# @title Save Scene Components...
# @cat Component art (web catalog)
#
# One .skp per scene. Each scene is aimed at a component; this walks the scene
# list, works out which component each one is looking at, and saves that
# component's definition to its own file named after the SCENE.
#
# The scene->component resolution WAS lifted from angled-component-art.rb. As
# of Aug 2026 it no longer is: this script casts a ray along the scene camera's
# view direction and takes the first component it strikes, because the shared
# nearest-to-target-point rule put ceiling geometry into four shipped floor
# files. See the comment above subject_for for the evidence. angled-component-art
# .rb still uses the old rule, so the two can now disagree.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/save-scene-components.rb"
#
# WHAT save_as ACTUALLY WRITES, because this catches people out:
#
#   It saves the DEFINITION, in the definition's own axes. An instance's
#   transformation — its position in the row, and any rotation or scale applied
#   to that instance — is NOT baked in. Two scenes pointing at two instances of
#   the same definition therefore produce two identical files under two names.
#   The run reports every time that happens rather than letting it look like two
#   different parts.
#
#   It also saves the definition UNDER ITS OWN NAME. Name the file after the
#   scene and you get LeftWADoor.skp containing a component called
#   "Component#41", which is useless to anyone who opens it and useless to a
#   right-click Save As, whose default filename comes from that name. Hence the
#   Rename option below.
#
# THE RENAME OPTION CHANGES YOUR MODEL, and it is the only thing here that does.
# Everything else reads page.camera and calls save_as; no scene is activated, no
# camera moves, no geometry is touched. With Rename on, each resolved definition
# is renamed to match its file, inside one operation, so a single Ctrl+Z puts
# every name back. It defaults to No.
#
# WHAT RENAMING DOES NOT DO, so the expectation is right going in: SketchUp does
# not keep an external component in sync. Editing the definition in the master
# does not rewrite the .skp, and editing the .skp does not update the master —
# there is no API for that and no setting for it. What renaming buys is that
# right-click > Save As on that instance offers the correct filename instead of
# "Component#41", so updating one part is a two-click job rather than a re-run of
# the whole batch.
#
# Whether save_as ALSO links the definition to the file it wrote is version
# dependent, so the run does not claim either way — it reads ComponentDefinition
# #path back after every save and prints what it got. Believe the column, not
# the documentation.

require 'sketchup.rb'
require 'fileutils'

# The folder field is a dropdown of folders used before, plus a Browse entry.
load File.join(File.dirname(__FILE__), 'wr-folder.rb')

module WR_SaveSceneComponents
  PREF = 'WR_SaveSceneComponents'.freeze

  DEFAULTS = {
    'scenes' => 'all',
    'dir'    => '',
    'name'   => 'Scene name',
    # The only option that writes to the model. Off by default for that reason.
    'ren'    => 'No',
    'over'   => 'No',
    'dry'    => 'Yes'
  }.freeze

  # Only what Windows actually forbids in a filename. Everything else — spaces,
  # brackets, ampersands — is kept exactly as the scene has it, the same rule
  # export-scenes.rb follows, so a file can be matched back to its scene by eye.
  FORBIDDEN = /[<>:"\/\\|?*\x00-\x1f]/.freeze

  # SketchUp's own auto-names carry no meaning and must never become a filename.
  AUTONAME = /\A(Component|Group)#\d+\z/.freeze

  # ------------------------------------------------------------------- input --

  def self.ask
    keys = %w[scenes dir name ren over dry]
    prompts = ['Scenes — all / current / 1-7,12 / text',
               'Output folder',
               'Name each file after',
               'Rename the component in the model to match its file',
               'Overwrite files already there',
               'Dry run — list only, write nothing']
    defaults = keys.map do |k|
      v = read_pref(k)
      v.empty? ? DEFAULTS[k] : v
    end
    lists = ['',                            # scenes
             '',                            # dir
             'Scene name|Definition name',  # name
             'No|Yes',                      # ren
             'Yes|No',                      # over
             'Yes|No']                      # dry
    di = keys.index('dir')
    defaults[di], lists[di] = WR_Folder.field('skpcomp', DEFAULTS['dir'])

    res = UI.inputbox(prompts, defaults, lists, 'Save Scene Components')
    return nil unless res

    cfg = {}
    keys.each_with_index { |k, i| cfg[k] = res[i].to_s.strip }

    cfg['dir'] = WR_Folder.resolve(cfg['dir'], 'skpcomp', 'Where should the .skp files go?')
    return nil if cfg['dir'].nil?

    keys.each { |k| write_pref(k, cfg[k]) }
    cfg
  end

  # read_default EVALS the stored string and write_default does not escape
  # quotes inside it, so anything with a quote in it comes back as a SyntaxError
  # — which is not a StandardError and so escapes a plain rescue. Strip quotes
  # going in, rescue Exception coming out. Same trap that took wr_tools down.
  def self.read_pref(k)
    Sketchup.read_default(PREF, k, DEFAULTS[k].to_s).to_s
  rescue Exception
    DEFAULTS[k].to_s
  end

  def self.write_pref(k, v)
    Sketchup.write_default(PREF, k, v.to_s.delete('"'))
  rescue Exception
    nil
  end

  def self.sanitize(s)
    out = s.to_s.strip.gsub(FORBIDDEN, '-')
    out.sub(/[. ]+\z/, '')      # Windows silently drops a trailing dot or space
  end

  # --------------------------------------------------------------- selection --
  #
  #   all              every scene
  #   current          the one selected right now
  #   1-7,12           scene numbers, as printed in the table
  #   exterior         any scene whose name contains that text
  #
  # Anything matching nothing is reported rather than quietly skipped.
  def self.select_pages(model, spec)
    pages = model.pages.to_a
    s = spec.to_s.strip.downcase
    return [pages, 'all'] if s.empty? || s == 'all' || s == '*'

    if s == 'current' || s == 'this'
      pg = model.pages.selected_page
      return [[], 'current — but no scene is selected'] if pg.nil?
      return [[pg], "current scene: #{pg.name}"]
    end

    picked = []
    misses = []
    s.split(',').map(&:strip).reject(&:empty?).each do |tok|
      hit = if tok =~ /\A(\d+)\s*-\s*(\d+)\z/
              a = Regexp.last_match(1).to_i
              b = Regexp.last_match(2).to_i
              a, b = b, a if a > b
              # Scene numbers are 1-indexed here, exactly as printed in the
              # table — but `pages` is a 0-indexed Ruby array, and Ruby's
              # pages[-1] is the LAST scene rather than an error. So an
              # unclamped 0 in a range ("0-5", an easy slip in a 1-based list)
              # used to quietly append the final scene of the model to the run.
              # Clamp to the real bounds first, and report whatever fell off
              # either end instead of dropping it silently — the user asked for
              # those numbers and is owed a word about them.
              lo = a < 1 ? 1 : a
              hi = b > pages.size ? pages.size : b
              if lo > hi
                []  # wholly outside the list — the empty-hit branch reports tok
              else
                misses << "#{a}-#{lo - 1}" if a < lo
                misses << "#{hi + 1}-#{b}" if b > hi
                (lo..hi).map { |n| pages[n - 1] }.compact
              end
            elsif tok =~ /\A\d+\z/
              n = tok.to_i
              [n >= 1 ? pages[n - 1] : nil].compact
            else
              pages.select { |p| p.name.to_s.downcase.include?(tok) }
            end
      hit.empty? ? misses << tok : picked.concat(hit)
    end
    picked = picked.compact.uniq
    note = spec.to_s.strip
    note += "  — nothing matched #{misses.join(', ')}" unless misses.empty?
    [picked, note]
  end

  # --------------------------------------------------- what the scene shows --
  #
  # In the master file every component sits in one long row and they are ALL
  # visible at once. A scene does not isolate anything — it only points the
  # camera at one of them. So "what is visible" is the whole row and is useless
  # as a link.
  #
  # The link is the SCENE'S OWN CAMERA — but it is WHAT THE CAMERA SEES, not
  # where its target point happens to land.
  #
  # WHY THIS CHANGED (Aug 2026). The original picked the top-level instance
  # whose bounds CENTRE was nearest cam.target, throwing away cam.direction
  # entirely. Over a 112-scene dry run on the master file that resolved every
  # single scene by distance — not one scene had the camera inside a part — with
  # deck (floor/ceiling) scenes landing 137-236 in from the component they were
  # assigned, and 13 scenes colliding onto a component another scene had already
  # claimed. The collisions were overwhelmingly CL/FL twins: a ceiling and its
  # matching floor share a plan position and are stacked in Z, so their centres
  # are near-equidistant from a target point and the tie goes to whichever the
  # entity list reaches first. That wrote ceiling geometry into four shipped
  # floor files.
  #
  # A ray carries the information a point does not: two parts stacked in Z
  # cannot both be the first thing a ray strikes.
  #
  # Sketchup::Model#raytest(ray, wysiwyg_flag = true) — VERIFIED against
  # ruby.sketchup.com, not memory:
  #   ray    is a two-element array [Geom::Point3d, Geom::Vector3d].
  #   return is nil, or [Geom::Point3d, Array<Sketchup::Drawingelement>] where
  #          the second element is the INSTANCE PATH of the entity hit,
  #          outermost first: [Component1, Component2, Component3...]. The docs
  #          describe the path as instances only, so the FIRST entry is the
  #          top-level subject. We scan for the first instance/group rather than
  #          taking path[0] blind, so a path that also carries the Face still
  #          resolves.
  #   wysiwyg defaults to TRUE, which means hidden geometry is NOT intersected.
  #          That is what we want: the ray should hit what a person looking at
  #          this scene would hit. Left at the default.
  #
  # TOP LEVEL ONLY, deliberately, in both the ray path and the fallback. In this
  # file the parts are laid out at the top level and descending would resolve to
  # some sub-part of the right component instead of the component itself.
  def self.subject_for(model, page)
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
  # vector or it reinterprets the second element as a point to aim through. So
  # normalise it here, and rebuild it from eye->target if it is degenerate.
  # Returns nil when no usable direction exists at all.
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

  # ------------------------------------------------------------------ fallback
  #
  # The ray can miss everything — several of these cameras are aimed past the
  # end of the row, at empty space. Nearest-to-target-point is what failed, so
  # the fallback still uses the direction rather than reverting to it:
  #
  #   1. Any part whose BOUNDING BOX the ray passes through, nearest first.
  #      This catches the case where the ray sailed between real faces (a gap in
  #      a panel, a part whose faces are hidden) but was still aimed at the part.
  #   2. Otherwise the part with the smallest PERPENDICULAR distance from the
  #      ray line — how far off-axis it sits, which is the direction-aware
  #      version of "nearest". Parts behind the camera are ranked last.
  #   3. Only with no usable direction at all does it fall back to the old
  #      nearest-to-target-point behaviour.
  #
  # Every branch labels itself in the returned string, so the dry-run table
  # says which scenes are genuinely aimed and which are still a guess.
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
      # An in-front candidate always beats a behind-the-camera one, whatever
      # their perpendicular distances.
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
  # point, with dir a unit vector. Done in plain floats (inches) rather than
  # Length arithmetic, which does not survive squaring cleanly.
  def self.ray_offsets(eye, dir, pt)
    vx = pt.x.to_f - eye.x.to_f
    vy = pt.y.to_f - eye.y.to_f
    vz = pt.z.to_f - eye.z.to_f
    along = (vx * dir.x.to_f) + (vy * dir.y.to_f) + (vz * dir.z.to_f)
    sq = (vx * vx) + (vy * vy) + (vz * vz) - (along * along)
    sq = 0.0 if sq < 0.0                    # rounding only
    [along, Math.sqrt(sq)]
  end

  # Both ComponentInstance and Group expose #definition (Group#definition since
  # SU 2015), and save_as is a ComponentDefinition method, so a group saves the
  # same way a component does.
  def self.definition_of(e)
    e.definition
  rescue Exception
    nil
  end

  def self.definition_name(defn)
    n = (defn.name.to_s.strip rescue '')
    n =~ AUTONAME ? '' : n
  end

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

  # ------------------------------------------------------------------ rename --
  #
  # Definition names are UNIQUE per model. Assigning one that is already taken
  # does not raise — SketchUp quietly makes it unique, typically by appending a
  # number — so the only way to know what a definition ended up called is to read
  # the name back afterwards. Which is what this does, and it reports a
  # difference rather than letting the model and the filename drift apart
  # silently.
  #
  # A definition already carrying the right name is left alone, so re-running is
  # free and does not churn the model.
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
    [got, "wanted \"#{want}\", model gave \"#{got}\" — that name was taken"]
  end

  # Whether save_as linked the definition to the file it just wrote. This is
  # version dependent, so it is measured rather than assumed. Returns a short
  # verdict for the table.
  def self.link_state(defn, path)
    p = (defn.path.to_s rescue '')
    return 'no link' if p.empty?
    same = p.tr('\\', '/').casecmp(path.tr('\\', '/')).zero?
    same ? 'linked' : "linked elsewhere: #{File.basename(p)}"
  rescue Exception
    'link unreadable'
  end

  # -------------------------------------------------------------------- run --

  def self.run
    model = Sketchup.active_model
    if model.nil?
      UI.messagebox('No model is open.')
      return
    end
    if model.pages.count.zero?
      UI.messagebox("This model has no scenes.\n\n" \
                    'Add scenes aimed at each component first, then run this again.')
      return
    end

    cfg = ask
    return if cfg.nil?

    pages, note = select_pages(model, cfg['scenes'])
    if pages.empty?
      UI.messagebox("No scenes matched.\n\n#{note}")
      return
    end

    dry  = cfg['dry'].to_s.downcase.start_with?('y')
    over = cfg['over'].to_s.downcase.start_with?('y')
    ren  = cfg['ren'].to_s.downcase.start_with?('y') && !dry
    by_scene = cfg['name'].to_s.downcase.include?('scene')

    unless dry
      begin
        FileUtils.mkdir_p(cfg['dir'])
      rescue Exception => e
        UI.messagebox("Cannot create the output folder:\n#{cfg['dir']}\n\n#{e.class}: #{e.message}")
        return
      end
    end

    puts ''
    puts '=' * 78
    puts "Save Scene Components  —  #{dry ? 'DRY RUN, nothing will be written' : 'writing .skp files'}"
    puts "  model    #{model.title.to_s.empty? ? '(unsaved)' : model.title}"
    puts "  folder   #{cfg['dir']}"
    puts "  scenes   #{pages.length} of #{model.pages.count}  (#{note})"
    puts "  named    after the #{by_scene ? 'scene' : 'definition'}"
    if ren
      puts '  RENAME   ON — every resolved component is renamed in the model to'
      puts '           match its file. One Ctrl+Z undoes the whole batch.'
    else
      puts "  rename   off — components keep their current names, so a file named"
      puts "           after a scene can still contain \"Component#41\""
    end
    puts '=' * 78

    # One operation for the whole batch, so undo is one keystroke rather than a
    # hundred. Only opened when something will actually be written to the model.
    model.start_operation('Rename Scene Components', true) if ren

    rows      = []
    used      = {}   # filename -> the scene that claimed it first
    seen_defn = {}   # definition name -> first scene that resolved to it
    written   = 0
    failed    = 0

    pages.each_with_index do |page, i|
      row = { :n => i + 1, :scene => page.name.to_s, :defn => '', :file => '',
              :how => '', :status => '', :link => '' }
      rows << row

      subject, how = subject_for(model, page)
      row[:how] = how
      if subject.nil?
        row[:status] = 'UNRESOLVED'
        failed += 1
        next
      end

      defn = definition_of(subject)
      if defn.nil?
        row[:status] = 'NO DEFINITION'
        failed += 1
        next
      end
      dname = definition_name(defn)
      row[:defn] = dname.empty? ? '(unnamed)' : dname

      # Two scenes resolving to one definition is legitimate — two views of the
      # same part — but it means two identical files, so say it out loud.
      if seen_defn.key?(defn.entityID)
        row[:how] += "; same component as scene ##{seen_defn[defn.entityID]}"
      else
        seen_defn[defn.entityID] = i + 1
      end

      base = sanitize(by_scene ? scene_label(page) : dname)
      base = sanitize(scene_label(page)) if base.empty?
      if base.empty?
        row[:status] = 'NO USABLE NAME'
        failed += 1
        next
      end

      # A duplicate filename would silently overwrite the earlier one, so
      # suffix it and report. Never let two scenes collapse into one file.
      name = base
      if used.key?(name.downcase)
        k = 2
        k += 1 while used.key?("#{base}-#{k}".downcase)
        name = "#{base}-#{k}"
        row[:how] += "; name taken by scene ##{used[base.downcase]}, suffixed"
      end
      used[name.downcase] = i + 1

      path = "#{cfg['dir']}/#{name}.skp"
      row[:file] = "#{name}.skp"

      if dry
        row[:status] = File.exist?(path) && !over ? 'would SKIP (exists)' : 'would write'
        next
      end

      if File.exist?(path) && !over
        row[:status] = 'SKIPPED (exists)'
        next
      end

      # RENAME BEFORE SAVING, not after. save_as writes the definition's name
      # into the file, so a rename that happened afterwards would leave the file
      # still carrying the old one and the two would disagree from birth.
      if ren
        got, warn = rename_to(defn, name)
        row[:defn] = got
        row[:how] += "; #{warn}" if warn
      end

      begin
        ok = defn.save_as(path)
        if ok == false
          row[:status] = 'FAILED: save_as returned false'
          failed += 1
        else
          row[:status] = 'written'
          row[:link] = link_state(defn, path)
          written += 1
        end
      rescue Exception => e
        row[:status] = "FAILED: #{e.class}: #{e.message.to_s.split("\n").first}"
        failed += 1
        puts "FAILED on scene #{page.name}: #{e.class}: #{e.message}"
        puts e.backtrace.first(6).map { |l| "    #{l}" }.join("\n")
      end
    end

    model.commit_operation if ren

    report(cfg, rows, written, failed, dry, ren)
  rescue Exception => e
    # A half-finished rename batch is worse than none, so abort puts every name
    # back. The files already written stay — they are correct, just incomplete.
    (Sketchup.active_model.abort_operation if ren) rescue nil
    raise e
  end

  # Every scene against the component it resolved to. This table is the point of
  # a dry run: it is what a scene-label -> component mapping gets written from,
  # and it is far easier to check here than by opening the files.
  def self.report(cfg, rows, written, failed, dry, ren = false)
    wn = [rows.map { |r| r[:scene].length }.max || 5, 5].max
    wd = [rows.map { |r| r[:defn].length }.max  || 9, 9].max
    wf = [rows.map { |r| r[:file].length }.max  || 4, 4].max

    puts ''
    puts format("  %-3s %-#{wn}s  %-#{wd}s  %-#{wf}s  %-22s  %-10s  %s",
                '#', 'SCENE', 'COMPONENT', 'FILE', 'STATUS', 'LINK', 'HOW IT RESOLVED')
    puts '  ' + '-' * (3 + wn + wd + wf + 22 + 36)
    rows.each do |r|
      puts format("  %-3d %-#{wn}s  %-#{wd}s  %-#{wf}s  %-22s  %-10s  %s",
                  r[:n], r[:scene], r[:defn], r[:file], r[:status],
                  r[:link].to_s, r[:how])
    end

    # HOW IT RESOLVED, tallied. A scene that says "ray hit" was genuinely aimed
    # at the part it got; anything saying "fallback" is still a guess and is
    # worth an eye before its file is trusted.
    rayed = rows.count { |r| r[:how].to_s.start_with?('ray hit') }
    fell  = rows.count { |r| r[:how].to_s.start_with?('fallback') }
    if (rayed + fell).positive?
      puts ''
      puts "  AIM   #{rayed} of #{rows.length} scene(s) resolved by ray hit — the camera is"
      puts '        actually pointing at the component it was given.'
      if fell.positive?
        puts "        #{fell} fell back (ray hit nothing). Those are guesses; check the"
        puts '        HOW column for each before trusting its file.'
      end
    end

    # The LINK column is the answer to "does right-click Save As know where this
    # came from". It is read back from the model, not assumed, because whether
    # save_as sets the path varies by SketchUp version.
    links = rows.map { |r| r[:link].to_s }.reject(&:empty?)
    unless links.empty?
      linked = links.count { |l| l == 'linked' }
      puts ''
      if linked == links.length
        puts "  LINK  all #{linked} saved definition(s) now point at their file."
        puts '        Right-click an instance > Save As offers that file back.'
      elsif linked.zero?
        puts "  LINK  none of the #{links.length} saved definition(s) kept a path."
        puts '        This SketchUp\'s save_as does not link. Right-click > Save As'
        puts '        will still default to the component NAME, which is why the'
        puts '        Rename option is worth turning on.'
      else
        puts "  LINK  #{linked} of #{links.length} linked. Mixed, which should not happen —"
        puts '        check the column above for the odd ones out.'
      end
    end

    if ren
      odd = rows.count { |r| r[:how].to_s.include?('that name was taken') }
      puts ''
      puts '  RENAME was ON. Ctrl+Z once puts every name back.'
      puts "  #{odd} definition(s) could not take the name asked for — see HOW." if odd.positive?
    end

    unresolved = rows.count { |r| r[:status].to_s.start_with?('UNRESOLVED', 'NO ') }
    skipped    = rows.count { |r| r[:status].to_s.include?('SKIP') }

    puts ''
    puts '  ' + '-' * 60
    if dry
      puts "  DRY RUN — nothing was written. #{rows.length} scenes examined."
      puts '  Set "Dry run" to No and run again to write the files.'
    else
      puts "  written #{written}    failed #{failed}    skipped #{skipped}    of #{rows.length} scenes"
      puts "  folder  #{cfg['dir']}"
    end
    puts "  #{unresolved} scene(s) resolved to no component." if unresolved.positive?
    puts '  ' + '-' * 60

    write_manifest(cfg, rows, dry)
    puts ''
    nil
  end

  # Tab-separated so it pastes straight into a sheet. Written on a dry run too —
  # the table is the deliverable of a dry run, so losing it to a closed console
  # would be the whole cost of the run.
  def self.write_manifest(cfg, rows, dry)
    FileUtils.mkdir_p(cfg['dir'])
    path = "#{cfg['dir']}/_scene-components#{dry ? '-dryrun' : ''}.tsv"
    File.open(path, 'w') do |f|
      f.puts %w[n scene component file status link how].join("\t")
      rows.each do |r|
        f.puts [r[:n], r[:scene], r[:defn], r[:file], r[:status],
                r[:link].to_s, r[:how]].join("\t")
      end
    end
    puts "  manifest #{path}"
  rescue Exception => e
    puts "  manifest NOT written: #{e.class}: #{e.message}"
  end
end

begin
  WR_SaveSceneComponents.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Save Scene Components failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console.')
end
