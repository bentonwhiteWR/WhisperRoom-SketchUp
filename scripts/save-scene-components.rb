# @title Save Scene Components...
# @cat Model tools
#
# One .skp per scene. Each scene is aimed at a component; this walks the scene
# list, works out which component each one is looking at, and saves that
# component's definition to its own file named after the SCENE.
#
# The scene->component resolution is lifted from angled-component-art.rb and
# behaves identically, so a scene that framed correctly there resolves to the
# same part here. The difference is only what comes out the other end: that
# script writes PNG art, this one writes .skp components.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/save-scene-components.rb"
#
# NOTHING IN THE MODEL IS CHANGED. No scene is activated, no camera moves, no
# geometry is touched — the run reads page.camera and calls save_as. So there is
# nothing to undo, and it is safe to run on a file you have unsaved work in.
#
# WHAT save_as ACTUALLY WRITES, because this catches people out:
#
#   It saves the DEFINITION, in the definition's own axes. An instance's
#   transformation — its position in the row, and any rotation or scale applied
#   to that instance — is NOT baked in. Two scenes pointing at two instances of
#   the same definition therefore produce two identical files under two names.
#   The run reports every time that happens rather than letting it look like two
#   different parts.

require 'sketchup.rb'
require 'fileutils'

module WR_SaveSceneComponents
  PREF = 'WR_SaveSceneComponents'.freeze

  DEFAULTS = {
    'scenes' => 'all',
    'dir'    => '',
    'name'   => 'Scene name',
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
    keys = %w[scenes dir name over dry]
    prompts = ['Scenes — all / current / 1-7,12 / text',
               'Output folder — blank to browse',
               'Name each file after',
               'Overwrite files already there',
               'Dry run — list only, write nothing']
    defaults = keys.map do |k|
      v = read_pref(k)
      v.empty? ? DEFAULTS[k] : v
    end
    lists = ['', '', 'Scene name|Definition name', 'Yes|No', 'Yes|No']
    res = UI.inputbox(prompts, defaults, lists, 'Save Scene Components')
    return nil unless res

    cfg = {}
    keys.each_with_index { |k, i| cfg[k] = res[i].to_s.strip }

    cfg['dir'] = pick_dir(cfg['dir'])
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

  # Blank opens a real folder browser. A typed path is used as-is and created if
  # it is not there yet, so a new folder needs no ceremony.
  def self.pick_dir(path)
    p = path.to_s.strip.tr('\\', '/')
    if p.empty?
      picked = (UI.select_directory(:title => 'Where should the .skp files go?') rescue nil)
      return nil if picked.nil? || picked.to_s.empty?
      p = picked.to_s.tr('\\', '/')
    end
    p.sub(%r{/+\z}, '')
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
              (a..b).map { |n| pages[n - 1] }.compact
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
  # The link is the SCENE'S OWN CAMERA. Its target is aimed at the part the
  # scene is about, so the nearest top-level instance to that target IS the
  # subject.
  #
  # TOP LEVEL ONLY, deliberately. It scans model.entities and does not descend,
  # because in this file the parts are laid out at the top level and descending
  # would resolve to some sub-part of the right component instead of the
  # component. If a scene comes back unresolved on a differently-built file,
  # that is why.
  def self.subject_for(model, page)
    cam = (page.camera rescue nil)
    return [nil, 'scene has no camera'] if cam.nil?
    t = cam.target
    best = nil
    bestd = nil
    model.entities.each do |e|
      next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      bb = e.bounds
      next unless bb.valid?
      d = bb.contains?(t) ? 0.0 : t.distance(bb.center).to_f
      if bestd.nil? || d < bestd
        bestd = d
        best = e
      end
    end
    return [nil, 'no component found near the scene camera'] if best.nil?
    how = bestd < 0.001 ? 'camera inside it' : format('%.0f in from target', bestd)
    [best, how]
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
    puts '=' * 78

    rows      = []
    used      = {}   # filename -> the scene that claimed it first
    seen_defn = {}   # definition name -> first scene that resolved to it
    written   = 0
    failed    = 0

    pages.each_with_index do |page, i|
      row = { :n => i + 1, :scene => page.name.to_s, :defn => '', :file => '',
              :how => '', :status => '' }
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

      begin
        ok = defn.save_as(path)
        if ok == false
          row[:status] = 'FAILED: save_as returned false'
          failed += 1
        else
          row[:status] = 'written'
          written += 1
        end
      rescue Exception => e
        row[:status] = "FAILED: #{e.class}: #{e.message.to_s.split("\n").first}"
        failed += 1
        puts "FAILED on scene #{page.name}: #{e.class}: #{e.message}"
        puts e.backtrace.first(6).map { |l| "    #{l}" }.join("\n")
      end
    end

    report(cfg, rows, written, failed, dry)
  end

  # Every scene against the component it resolved to. This table is the point of
  # a dry run: it is what a scene-label -> component mapping gets written from,
  # and it is far easier to check here than by opening the files.
  def self.report(cfg, rows, written, failed, dry)
    wn = [rows.map { |r| r[:scene].length }.max || 5, 5].max
    wd = [rows.map { |r| r[:defn].length }.max  || 9, 9].max
    wf = [rows.map { |r| r[:file].length }.max  || 4, 4].max

    puts ''
    puts format("  %-3s %-#{wn}s  %-#{wd}s  %-#{wf}s  %-22s  %s",
                '#', 'SCENE', 'COMPONENT', 'FILE', 'STATUS', 'HOW IT RESOLVED')
    puts '  ' + '-' * (3 + wn + wd + wf + 22 + 24)
    rows.each do |r|
      puts format("  %-3d %-#{wn}s  %-#{wd}s  %-#{wf}s  %-22s  %s",
                  r[:n], r[:scene], r[:defn], r[:file], r[:status], r[:how])
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
      f.puts %w[n scene component file status how].join("\t")
      rows.each do |r|
        f.puts [r[:n], r[:scene], r[:defn], r[:file], r[:status], r[:how]].join("\t")
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
