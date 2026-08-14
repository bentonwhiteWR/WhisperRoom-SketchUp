# @title Elevation Export...
# @cat Export art
#
# Straight-on orthographic views of every scene's component — front, back, left,
# right, top, bottom — at ONE shared scale across the whole run.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/elevation-export.rb"
#
# WHY THIS EXISTS RATHER THAN JUST EXPORTING THE SCENES
#
# Exporting the scenes as they sit takes a picture of wherever the camera
# happened to be left. Every part then lands at its own scale and its own
# rotation, and they cannot be composited beside each other — a 46 inch wall and
# the 46 inch vent next to it come out different sizes. That is exactly what got
# a batch of the angled art rejected.
#
# So this script does not use the scene's camera to take the picture. It uses the
# scene's camera ONLY to work out which component the scene is about, then aims
# its own camera at that component from a true axis direction, with a view height
# that is measured ONCE across every part in the run and then held fixed.
#
# The consequence worth understanding: parts come out at CONSISTENT SCALE, not
# consistent size. A 16 inch panel fills less of its frame than a 46 inch one,
# and that is the point — an inch is the same number of pixels in every file, so
# they composite.
#
# WHAT IT DOES NOT CHANGE
#
# No scene is activated and no scene's camera is edited. The model's own camera
# is saved and restored, as is the style. Components are hidden and revealed
# during the run and put back exactly as found.

require 'sketchup.rb'
require 'fileutils'

# The folder field is a dropdown of folders used before, plus a Browse entry.
load File.join(File.dirname(__FILE__), 'wr-folder.rb')

module WR_Elevation
  PREF = 'WR_Elevation'.freeze

  Z_AXIS = Geom::Vector3d.new(0, 0, 1)
  Y_AXIS = Geom::Vector3d.new(0, 1, 0)

  # Eye direction FROM the target, and the up hint for that direction.
  #
  # SketchUp's own convention: Front looks from -Y toward +Y, Right looks from
  # +X. These match the standard views on the Views toolbar, so a part that
  # looks right in the Front view here looks the same as Camera > Standard >
  # Front.
  #
  # Top and Bottom MUST NOT use Z as the up hint — it is parallel to the view
  # direction and the camera cannot be built from it. They use Y instead, which
  # is why this is a table rather than a constant.
  DIRS = {
    'Front'  => [[0, -1, 0], :z],
    'Back'   => [[0,  1, 0], :z],
    'Left'   => [[-1, 0, 0], :z],
    'Right'  => [[1,  0, 0], :z],
    'Top'    => [[0, 0,  1], :y],
    'Bottom' => [[0, 0, -1], :y]
  }.freeze

  SETS = {
    'Front'                 => %w[Front],
    'Back'                  => %w[Back],
    'Left'                  => %w[Left],
    'Right'                 => %w[Right],
    'Top'                   => %w[Top],
    'Bottom'                => %w[Bottom],
    'Front + Back'          => %w[Front Back],
    'Left + Right'          => %w[Left Right],
    'All four sides'        => %w[Front Back Left Right],
    'All six'               => %w[Front Back Left Right Top Bottom]
  }.freeze

  # Ground, horizon, fog, watermarks and ambient occlusion all fill or tint the
  # whole frame, and any one of them left on means write_image comes back
  # OPAQUE. Straight from angled-component-art.rb, where each of these cost real
  # time to find. None of them change how the geometry itself looks, so turning
  # them off still honours "use the model's own style".
  TRANSPARENCY = { 'DrawGround'        => false,
                   'DrawHorizon'       => false,
                   'DisplayFog'        => false,
                   'DisplayWatermarks' => false,
                   'AmbientOcclusion'  => false }.freeze

  LINE_ART = { 'RenderMode' => 1, 'Texture' => false, 'DisplayFog' => false,
               'DrawGround' => false, 'DrawHorizon' => false, 'DepthCue' => false,
               'DrawProfilesOnly' => false, 'DrawSilhouette' => false,
               'ExtendLines' => false, 'DisplayColorByLayer' => false }.freeze
  SHADED   = { 'RenderMode' => 2, 'Texture' => false, 'DisplayFog' => false,
               'DrawGround' => false, 'DrawHorizon' => false, 'DepthCue' => false }.freeze

  AUTONAME = /\A(Component|Group)#\d+\z/.freeze
  FORBIDDEN = /[<>:"\/\\|?*\x00-\x1f]/.freeze

  DEFAULTS = {
    'view'  => 'Right',
    'pick'  => 'all',
    'dir'   => '',
    'px'    => '2400',
    'height' => 'auto',
    'frame' => 'Part centred',
    'name'  => 'Definition name',
    'style' => "Leave the style alone (the model's own)",
    'over'  => 'Yes',
    'recov' => 'Yes',
    'dry'   => 'Yes'
  }.freeze

  # ------------------------------------------------------------------- input --

  def self.ask
    keys = %w[view pick dir px height frame name style over recov dry]
    prompts = ['View',
               'Scenes — all / current / 1-7,12 / text',
               'Output folder',
               'Canvas (px, square)',
               'View height — auto, or inches',
               'Frame on',
               'Name files after',
               'Style',
               'Overwrite files already there',
               'Recover brightness after export (new graphics engine)',
               'Dry run — measure and list only']
    defaults = keys.map do |k|
      v = read_pref(k)
      v.empty? ? DEFAULTS[k] : v
    end
    lists = [SETS.keys.join('|'),
             '', '', '', '',
             'Part centred|Insertion point at centre (registration)',
             'Definition name|Scene name',
             "Leave the style alone (the model's own)|Shaded, no textures|Line art (hidden line, no shadows)",
             'Yes|No', 'Yes|No', 'Yes|No']
    di = keys.index('dir')
    defaults[di], lists[di] = WR_Folder.field('elev', DEFAULTS['dir'])

    res = UI.inputbox(prompts, defaults, lists, 'Elevation Export')
    return nil unless res

    cfg = {}
    keys.each_with_index { |k, i| cfg[k] = res[i].to_s.strip }
    cfg['dir'] = WR_Folder.resolve(cfg['dir'], 'elev', 'Where should the elevation images go?')
    return nil if cfg['dir'].nil?
    keys.each { |k| write_pref(k, cfg[k]) }
    cfg
  end

  # read_default EVALS what was stored and write_default does not escape quotes,
  # so a value with a quote in it comes back a SyntaxError — which is not a
  # StandardError and escapes an ordinary rescue. This is the trap that took
  # wr_tools down; strip quotes going in, rescue Exception coming out.
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
    out.sub(/[. ]+\z/, '')
  end

  # --------------------------------------------------------------- selection --

  def self.select_pages(model, spec)
    pages = model.pages.to_a
    s = spec.to_s.strip.downcase
    return [pages, "all #{pages.size} scenes"] if s.empty? || s == 'all' || s == '*'

    if s == 'current' || s == 'this'
      pg = model.pages.selected_page
      return [[], 'current — but no scene is selected'] if pg.nil?
      return [[pg], "current: #{pg.name}"]
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
  # The scene's camera is used ONLY for this: its target names the subject. Top
  # level only — descending would resolve to some sub-part of the right
  # component rather than the component.
  def self.subject_for(model, page)
    cam = (page.camera rescue nil)
    return [nil, nil, 'scene has no camera'] if cam.nil?
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
    return [nil, nil, 'no component found near the scene camera'] if best.nil?
    how = bestd < 0.001 ? 'camera inside it' : format('%.0f in from target', bestd)
    [best, best.bounds, how]
  end

  # "(Left46Door)" is a label wrapped in brackets and the brackets are noise.
  # "16PanelSolid (2)" is SketchUp's own duplicate-scene suffix and the brackets
  # are part of the name — stripping the closing one there produced 66 files
  # called "16PanelSolid (2.png", with an open bracket and no close.
  #
  # So only unwrap when the WHOLE name is wrapped, which means the first closing
  # bracket has to be the last character. "(Left46Door) (2)" opens and closes but
  # is not wrapped, and is left alone.
  def self.scene_label(page)
    n = page.name.to_s.strip
    if n.start_with?('(') && n.end_with?(')') && n.index(')') == n.length - 1
      n = n[1..-2].to_s.strip
    end
    n
  end

  def self.subject_name(e, page, by_definition)
    label = scene_label(page)
    return label unless by_definition
    if e.is_a?(Sketchup::ComponentInstance)
      n = (e.definition.name.to_s.strip rescue '')
      return n unless n.empty? || n =~ AUTONAME
    end
    n = (e.name.to_s.strip rescue '')
    return n unless n.empty? || n =~ AUTONAME
    label
  end

  def self.datum_of(e, by_insertion)
    if by_insertion && (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group))
      o = (e.transformation.origin rescue nil)
      return [o, 'insertion point'] if o && e.bounds.contains?(o)
    end
    [e.bounds.center, 'bounds centre']
  end

  # ------------------------------------------------------------------ camera --

  # Right and up for a view, in world space. right = forward x up_hint, then up
  # is rebuilt from right so the two are square whatever the hint was.
  def self.basis(view_name)
    d, hint = DIRS[view_name]
    fwd = Geom::Vector3d.new(-d[0], -d[1], -d[2])
    fwd.normalize!
    up_hint = hint == :y ? Y_AXIS : Z_AXIS
    right = fwd.cross(up_hint)
    right.normalize!
    up = right.cross(fwd)
    up.normalize!
    [fwd, right, up]
  end

  # Half-extents of a bounding box on screen, in inches, for this view.
  def self.needed(bb, view_name, target)
    _f, right, up = basis(view_name)
    wx = 0.0
    wy = 0.0
    8.times do |i|
      c = bb.corner(i)
      v = Geom::Vector3d.new(c.x - target.x, c.y - target.y, c.z - target.z)
      x = (v % right).abs
      y = (v % up).abs
      wx = x if x > wx
      wy = y if y > wy
    end
    [wx, wy]
  end

  # Distance does not affect scale in a parallel projection, but the camera must
  # still clear the geometry or it ends up inside the model looking at the back
  # of a face, which renders black. Scale it to the view height.
  def self.aim(view, view_name, target, view_h)
    d, = DIRS[view_name]
    dist = [view_h * 6.0, 1000.0].max
    eye = Geom::Point3d.new(target.x + d[0] * dist,
                            target.y + d[1] * dist,
                            target.z + d[2] * dist)
    _f, _r, up = basis(view_name)
    cam = view.camera
    cam.set(eye, target, up)
    cam.perspective  = false
    cam.aspect_ratio = 1.0
    cam.height       = view_h     # last: set() can reset the projection
    cam
  end

  # ------------------------------------------------------------------- style --

  def self.push_style(model, mode)
    ro = model.rendering_options
    want, shadows = case mode
                    when /Line art/ then [LINE_ART.merge(TRANSPARENCY), true]
                    when /Shaded/   then [SHADED.merge(TRANSPARENCY),   true]
                    else                 [TRANSPARENCY.dup,             false]
                    end
    saved = { :ro => {}, :shadows => nil, :touch => shadows }
    want.each_key { |k| saved[:ro][k] = (ro[k] rescue nil) }
    saved[:shadows] = (model.shadow_info['DisplayShadows'] rescue nil) if shadows
    [saved, want, shadows]
  end

  # Sets each key and READS IT BACK. A rescue that swallows a failed write is how
  # a setting looks applied and is not — which is what happened with the
  # watermark, and why the alpha channel came back opaque.
  def self.apply_style(model, want, touch_shadows = false)
    ro = model.rendering_options
    stuck = []
    want.each do |k, v|
      begin
        ro[k] = v
      rescue StandardError => e
        stuck << "#{k}: write raised #{e.class}"
        next
      end
      got = (ro[k] rescue :unreadable)
      stuck << "#{k}: wanted #{v.inspect}, still #{got.inspect}" unless got == v
    end
    (model.shadow_info['DisplayShadows'] = false) rescue nil if touch_shadows
    stuck
  end

  def self.pop_style(model, saved)
    ro = model.rendering_options
    saved[:ro].each { |k, v| (ro[k] = v) rescue nil unless v.nil? }
    if saved[:touch] && !saved[:shadows].nil?
      (model.shadow_info['DisplayShadows'] = saved[:shadows]) rescue nil
    end
  end

  # Anything open for editing fades everything else to InactiveFade, which shows
  # up as washed-out geometry in the export. Close it before rendering.
  def self.close_contexts(model)
    n = 0
    while model.active_path && n < 20
      break unless model.close_active
      n += 1
    end
    n
  rescue StandardError
    n
  end

  # SketchUp 24's new graphics engine composites a uniform 75% black layer over
  # everything write_image produces, in colour AND alpha. Exactly invertible, and
  # fix-angled-alpha.py inverts it. Files stay dark until this runs, which is at
  # the END of the run — that is expected, not a fault.
  def self.recover(cfg)
    fixer = File.join(File.dirname(__FILE__), 'fix-angled-alpha.py')
    unless File.exist?(fixer)
      puts "  RECOVERY SKIPPED — #{fixer} is missing."
      return false
    end
    cmd = "python \"#{fixer.tr('/', '\\')}\" \"#{cfg['dir'].tr('/', '\\')}\" --inplace"
    puts "  recovering brightness: #{cmd}"
    ok = system(cmd)
    if ok
      puts '  recovery done — files corrected in place.'
    else
      puts '  *** RECOVERY FAILED. Is python on PATH? Run it by hand:'
      puts "      #{cmd}"
      puts '  *** The PNGs are exported but still 75% dark until you do.'
    end
    ok
  rescue StandardError => e
    puts "  recovery error: #{e.class}: #{e.message}"
    false
  end

  # -------------------------------------------------------------------- run --

  def self.run
    model = Sketchup.active_model
    if model.nil?
      UI.messagebox('No model is open.')
      return
    end
    if model.pages.count.zero?
      UI.messagebox("This model has no scenes.\n\nAim a scene at each component first.")
      return
    end

    cfg = ask
    return if cfg.nil?

    views = SETS[cfg['view']] || %w[Front]

    # The view is NOT put in the filename. One view per run is the normal case
    # and the suffix is just noise there.
    #
    # It comes back automatically when a run covers more than one view, because
    # without it all four sides of a part would compete for one filename and
    # three of the four would be lost — either overwritten, or shunted to a -2
    # suffix that says nothing about which side it is. A silently missing side is
    # far worse than a suffix.
    multi_view = views.length > 1
    dry   = cfg['dry']  == 'Yes'
    over  = cfg['over'] == 'Yes'
    by_definition = cfg['name'].to_s.start_with?('Definition')
    by_insertion  = cfg['frame'].to_s.start_with?('Insertion')
    px = cfg['px'].to_i
    px = 2400 if px < 64

    pages, pick_note = select_pages(model, cfg['pick'])
    if pages.empty?
      UI.messagebox("No scenes matched.\n\n#{pick_note}")
      return
    end

    closed = close_contexts(model)
    puts "  closed #{closed} open editing context(s) before rendering" if closed > 0

    saved, want, shad = push_style(model, cfg['style'])
    view     = model.active_view
    prev_cam = (view.camera.clone rescue nil)

    measured = []
    begin
      # ---- pass 1: measure every part in every requested view. Nothing is
      # written, so a wrong frame costs nothing but a few seconds.
      pages.each do |page|
        subj, bb, how = subject_for(model, page)
        if subj.nil?
          measured << { :page => page, :bad => how }
          next
        end
        d, dhow = datum_of(subj, by_insertion)
        worst = 0.0
        views.each do |v|
          wx, wy = needed(bb, v, d)
          worst = wx if wx > worst
          worst = wy if wy > worst
        end
        measured << { :page => page, :subject => subj, :bounds => bb, :datum => d,
                      :name => subject_name(subj, page, by_definition),
                      :how => "#{how}, #{dhow}", :half => worst }
      end

      good = measured.reject { |m| m[:bad] }
      if good.empty?
        UI.messagebox("No scene resolved to a component.\n\nSee the Ruby Console.")
        return
      end

      # THE CONSISTENCY GUARANTEE. One height for the entire run, taken from the
      # part that needs the most room, plus 5%. Never per part — a per-part fit
      # is what makes files that cannot be composited.
      worst_half = good.map { |m| m[:half] }.max.to_f
      auto_h = [(worst_half * 2.0 * 1.05), 12.0].max
      typed = cfg['height'].to_s.strip.downcase
      view_h = if typed == 'auto' || typed.empty?
                 auto_h
               else
                 v = typed.to_f
                 v <= 0 ? auto_h : v
               end
      scale = px / view_h

      puts ''
      puts "ELEVATION EXPORT#{dry ? '   (DRY RUN, nothing written)' : ''}"
      puts ''
      puts "  views          #{views.join(', ')}"
      puts "  picked         #{pick_note}"
      puts "  out            #{cfg['dir']}"
      puts "  style          #{cfg['style']}"
      puts format('  canvas         %d x %d px, square, transparent', px, px)
      puts '  projection     PARALLEL — perspective = false, aspect_ratio = 1.0'
      puts format('  view height    %.4f in  (%s)  ->  %.4f px/in',
                  view_h, typed == 'auto' || typed.empty? ? 'auto, fitted to the whole run' : 'as typed',
                  scale)
      puts format('  auto would be  %.4f in   (the largest part needs %.4f in)', auto_h, worst_half * 2.0)
      puts "  framed on      #{by_insertion ? "each part's insertion point" : 'each part\'s bounds centre'}"
      puts "  named after    #{by_definition ? 'the component definition' : 'the scene'}"
      puts "  filenames      #{multi_view ? "<name>_<View>.png — the view is appended because this run covers #{views.length} views" : '<name>.png — no view suffix'}"
      if typed != 'auto' && !typed.empty? && view_h < auto_h
        puts ''
        puts format('  *** WARNING: %.4f in is SMALLER than the %.4f in the largest part needs.', view_h, auto_h)
        puts '  *** Parts bigger than the frame will be CLIPPED at the canvas edge.'
      end
      puts ''

      # ---- the table, which doubles as the scene-number reference
      wn = [measured.map { |m| m[:page].name.to_s.length }.max || 5, 5].max
      puts format("   %-4s %-#{wn}s  %-30s  %-11s  %s", '#', 'SCENE', 'COMPONENT', 'SIZE in', 'HOW IT RESOLVED')
      puts '   ' + '-' * (4 + wn + 30 + 11 + 22)
      idx = {}
      model.pages.to_a.each_with_index { |p, i| idx[p.name.to_s] = i + 1 }
      measured.each do |m|
        n = idx[m[:page].name.to_s] || 0
        if m[:bad]
          puts format("   %-4d %-#{wn}s  %-30s  %-11s  %s", n, m[:page].name, '—', '—', m[:bad])
        else
          puts format("   %-4d %-#{wn}s  %-30s  %-11.2f  %s",
                      n, m[:page].name, m[:name], m[:half] * 2.0, m[:how])
        end
      end

      if dry
        puts ''
        puts "  DRY RUN — nothing written. #{good.length} scenes x #{views.length} views"
        puts "            = #{good.length * views.length} images would be produced."
        puts '  Set "Dry run" to No to write them.'
        puts ''
        return
      end

      # ---- pass 2: render. Everything at top level goes hidden once, then each
      # subject is revealed for its views and hidden again — without this the
      # neighbouring parts in the row sit in frame, inches away.
      FileUtils.mkdir_p(cfg['dir'])
      written = 0
      failed  = []
      used    = {}

      tops = model.entities.select do |e|
        e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      end
      prev_hidden = tops.map { |e| [e, e.hidden?] }
      prev_lay    = model.layers.map { |l| [l, l.visible?] }

      begin
        model.layers.each { |l| (l.visible = true) rescue nil }
        tops.each { |e| (e.hidden = true) rescue nil }
        stuck = apply_style(model, want, shad)
        stuck.each { |s| puts "  STYLE DID NOT TAKE — #{s}" } unless stuck.empty?

        good.each_with_index do |m, i|
          subj = m[:subject]
          next unless subj && subj.valid?
          subj.hidden = false
          begin
            views.each do |v|
              base = sanitize(multi_view ? "#{m[:name]}_#{v}" : m[:name].to_s)
              if used.key?(base.downcase)
                k = 2
                k += 1 while used.key?("#{base}-#{k}".downcase)
                puts "  NAME CLASH  #{base}.png already used by scene ##{used[base.downcase]} — writing #{base}-#{k}.png"
                base = "#{base}-#{k}"
              end
              used[base.downcase] = i + 1

              path = File.join(cfg['dir'], "#{base}.png")
              if !over && File.exist?(path)
                puts "  skip  #{File.basename(path)}"
                next
              end
              aim(view, v, m[:datum], view_h)
              apply_style(model, want, shad)
              view.refresh
              Sketchup.status_text = "Elevation #{i + 1}/#{good.size}: #{m[:name]} #{v}"
              ok = view.write_image(:filename => path, :width => px, :height => px,
                                    :antialias => true, :transparent => true)
              if ok
                written += 1
                puts "  ok    #{File.basename(path)}"
              else
                failed << File.basename(path)
                puts "  FAIL  #{File.basename(path)}"
              end
            end
          ensure
            subj.hidden = true if subj.valid?
          end
        end
      ensure
        prev_hidden.each { |e, h| (e.hidden = h) if e.valid? }
        prev_lay.each { |l, v| (l.visible = v) rescue nil }
      end

      recover(cfg) if cfg['recov'] == 'Yes'
      write_diagnostics(cfg, views, view_h, scale, px, measured, written, failed)

      puts ''
      puts '  ' + '-' * 60
      puts "  written #{written}    failed #{failed.length}    of #{good.length * views.length} expected"
      puts "  folder  #{cfg['dir']}"
      puts format('  scale   %.4f px/in — the same in every file in this run', scale)
      puts '  ' + '-' * 60
      puts ''
    ensure
      pop_style(model, saved)
      (view.camera = prev_cam) if prev_cam
      Sketchup.status_text = ''
    end
    nil
  end

  # The scale is the thing anyone downstream needs and cannot recover from the
  # pixels alone, so it goes in a file rather than only the console.
  def self.write_diagnostics(cfg, views, view_h, scale, px, measured, written, failed)
    path = File.join(cfg['dir'], '_diagnostics.txt')
    File.open(path, 'w') do |f|
      f.puts 'ELEVATION EXPORT'
      f.puts "model        #{Sketchup.active_model.title}"
      f.puts "views        #{views.join(', ')}"
      f.puts "canvas       #{px} x #{px} px, square, transparent"
      f.puts 'projection   PARALLEL, aspect_ratio 1.0'
      f.puts format('view height  %.6f in  (%s)', view_h,
                    cfg['height'].to_s.strip.downcase == 'auto' ? 'auto, fitted across the whole run' : 'as typed')
      f.puts format('scale        %.6f px/in  — ONE scale for every file in this run', scale)
      f.puts "framed on    #{cfg['frame']}"
      f.puts "named after  #{cfg['name']}"
      f.puts "style        #{cfg['style']}"
      f.puts "written      #{written}"
      f.puts "failed       #{failed.length}#{failed.empty? ? '' : ' — ' + failed.join(', ')}"
      f.puts ''
      f.puts "scene\tcomponent\tsize_in\tresolved"
      measured.each do |m|
        if m[:bad]
          f.puts "#{m[:page].name}\t\t\t#{m[:bad]}"
        else
          f.puts format("%s\t%s\t%.4f\t%s", m[:page].name, m[:name], m[:half] * 2.0, m[:how])
        end
      end
    end
    puts "  diagnostics #{path}"
  rescue StandardError => e
    puts "  diagnostics NOT written: #{e.class}: #{e.message}"
  end
end

begin
  WR_Elevation.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Elevation Export failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console.')
end
