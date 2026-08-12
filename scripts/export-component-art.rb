# @title Export Component Art...
# @cat Export art
#
# One transparent PNG per scene, for the whole model, in one pass — the art
# handoff for the orchestrator's new component style.
#
# Sibling of export-scenes.rb. That one makes PROPOSAL plates: five scenes,
# opaque, into ProposalFiles. This one makes COMPONENT ART: every scene, real
# alpha, plus a manifest.
#
# SHADING. Style, Shadow Dark and Recover come from wr-shading.rb and MUST match
# whatever angled-component-art.rb was run with, or the flat set and the Iso30
# set will not sit together in the booth builder. Both default to the Interior
# style and Dark 45.
#
# The dialog opens on "Dry run = Yes" the first time. That prints the full
# scene -> filename table and writes nothing. Check a few names before
# committing 100-odd files to a handoff.
#
# The HX tagging that used to live here — a sidecar of scene names from the
# height-extension merge, and an -HX filename suffix — is gone. It was for one
# merge that has already happened; carrying it meant two dialog fields and a
# fallback rule that could silently mistag, for a job nobody is going to run
# again. Recover it from git if that ever changes.
#
# SCALE. Set "View height" to a number of inches and every scene is rendered at
# that vertical extent, in parallel projection — a 22 inch panel and a 46 inch
# wall then come out at genuinely different sizes, which is the point. Leave it
# on "scene" to keep each scene's own saved zoom, the old behaviour.
#
# What has to match the Iso30 set is PX PER INCH, not the view height, because
# the two exporters do not share a canvas: the angled one is square and this one
# takes its aspect from the viewport. The console prints the number to type.
#
# BEFORE YOU RUN: size the SketchUp window to the aspect you want. Image height
# comes from the viewport aspect and every image in the run inherits it — and it
# also decides the px-per-inch you get from a given view height. The scene
# directions are all front/side already, so nothing rotates and nothing is
# re-aimed; only the projection and the zoom are overwritten.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/export-component-art.rb"

require 'sketchup.rb'
require 'fileutils'
require 'json'

# The shading contract, shared with angled-component-art.rb. Loaded rather than
# required so an edit takes effect without restarting SketchUp, same as every
# other script here.
load File.join(File.dirname(__FILE__), 'wr-shading.rb')

module WR_ComponentArt
  PREF = 'WR_ComponentArt'.freeze

  DEFAULTS = {
    'scenes' => 'all',
    'dir'    => 'C:/Users/bento/Desktop/ProposalFiles/ComponentArt',
    'width'  => '2400',
    # Vertical extent of the frame, in inches, forced onto every scene's camera.
    # This is what makes one part comparable to another and to the Iso30 set.
    # "scene" keeps each scene's own saved zoom, which is what this exporter did
    # before and is still the right answer for a one-off.
    'view'   => 'scene',
    'trans'  => 'Yes',
    # Style and Dark are the shading contract. They MUST match whatever the
    # angled run used or the two sets will not sit together in the booth
    # builder — that is the whole reason wr-shading.rb exists. Interior is the
    # style this library is shot in; angled-component-art.rb defaults to the
    # same string.
    'style'  => 'Style: Interior',
    'dark'   => WR_Shading::DEF_DARK.to_s,
    'recov'  => 'Yes',
    'over'   => 'No',
    'dry'    => 'Yes',
    'man'    => 'Yes'
  }.freeze

  # ------------------------------------------------------------------- input --

  def self.ask
    keys = %w[scenes dir width view trans style dark recov over dry man]
    prompts = ['Scenes — all / current / 1-7,12 / text',
               'Output folder — blank to browse',
               'Image width (px)',
               'View height — "scene", or inches (pins the scale)',
               'Transparent background',
               'Style — must match the angled run',
               'Shadow Dark (0-100) — raise it to lift oblique faces',
               'Recover brightness after export (new graphics engine)',
               'Overwrite files already there',
               'Dry run — list only, write nothing',
               'Write manifest.json']
    defaults = keys.map do |k|
      v = Sketchup.read_default(PREF, k, DEFAULTS[k]).to_s
      v.empty? ? DEFAULTS[k] : v
    end
    # POSITIONAL against prompts — one entry per prompt, in the same order, ''
    # where the field is free text. One missing '' shifts every dropdown below
    # it onto the wrong field, silently. Count them if you edit.
    lists = ['',                                        # scenes
             '',                                        # dir
             '',                                        # width
             '',                                        # view
             'Yes|No',                                  # trans
             WR_Shading.style_options(Sketchup.active_model).join('|'),
             '',                                        # dark
             'Yes|No',                                  # recov
             'Yes|No',                                  # over
             'Yes|No',                                  # dry
             'Yes|No']                                  # man
    res = UI.inputbox(prompts, defaults, lists, 'Export Component Art')
    return nil unless res
    cfg = {}
    keys.each_with_index { |k, i| cfg[k] = res[i].to_s.strip }

    cfg['dir'] = browse_dir(cfg['dir'])
    return nil if cfg['dir'].nil?

    keys.each { |k| Sketchup.write_default(PREF, k, cfg[k]) }
    cfg
  end

  def self.norm(p)
    p.to_s.strip.tr('\\', '/')
  end

  def self.browse_dir(path)
    p = norm(path)
    return p unless p.empty?
    picked = (UI.select_directory(:title => 'Where should the images go?') rescue nil)
    picked.nil? || picked.to_s.empty? ? nil : norm(picked)
  end

  # THE FILE IS NAMED AFTER THE SCENE, verbatim. Only the characters Windows
  # genuinely refuses are replaced; spaces, brackets, ampersands and the rest
  # are kept exactly as the scene has them.
  #
  # This used to fold spaces into hyphens and strip anything non-alphanumeric,
  # so "01 Exterior View" landed as "01-Exterior-View" and you could not match a
  # file back to its scene by eye. Don't reintroduce that.
  FORBIDDEN = /[<>:"\/\\|?*\x00-\x1f]/.freeze

  def self.sanitize(s)
    out = s.to_s.strip.gsub(FORBIDDEN, '-')
    out.sub(/[. ]+\z/, '')       # Windows silently drops a trailing dot or space
  end

  # Which scenes to do. Understands:
  #   all              every scene (the default)
  #   current          just the one selected right now
  #   1-7,12,20-24     scene numbers, 1-based, as printed in the table
  #   door             any scene whose name contains that text, case-insensitive
  # Numbers and text can be mixed in one list. Anything that matches nothing is
  # reported rather than silently skipped, and the table always shows exactly
  # what will be written — so a typo is visible before anything is exported.
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
      if tok =~ /\A(\d+)\s*-\s*(\d+)\z/
        a = Regexp.last_match(1).to_i
        b = Regexp.last_match(2).to_i
        a, b = b, a if a > b
        hit = (a..b).map { |n| pages[n - 1] }.compact
        misses << tok if hit.empty?
        picked.concat(hit)
      elsif tok =~ /\A\d+\z/
        n = tok.to_i
        pg = (n >= 1 ? pages[n - 1] : nil)
        pg ? picked << pg : misses << tok
      else
        hit = pages.select { |p| p.name.to_s.downcase.include?(tok) }
        misses << "\"#{tok}\"" if hit.empty?
        picked.concat(hit)
      end
    end
    picked = picked.compact.uniq
    note = spec.to_s.strip
    note += "  — nothing matched #{misses.join(', ')}" unless misses.empty?
    [picked, note]
  end

  def self.build_plan(model, cfg, chosen)
    index  = {}
    model.pages.to_a.each_with_index do |p, i|
      key = begin
              p.persistent_id
            rescue StandardError
              p.name
            end
      index[key] = i + 1
    end
    used = {}
    out  = []
    chosen.each_with_index do |page, i|
      raw = page.name.to_s
      base = sanitize(raw.sub(/ \(\d+\)\z/, ''))
      base = "scene-#{i + 1}" if base.empty?
      if used.key?(base)             # two names can sanitize to one string
        used[base] += 1
        base = "#{base}-#{used[base]}"
      else
        used[base] = 1
      end
      key = begin
              page.persistent_id
            rescue StandardError
              page.name
            end
      n = index[key] || (i + 1)
      out << { :page => page, :scene => raw, :base => base, :n => n }
    end
    out
  end

  # -------------------------------------------------------------------- scale --
  #
  # PIN THE SCALE, KEEP THE DIRECTION.
  #
  # Selecting a scene restores that scene's whole camera — where it looks from
  # AND how far in it is zoomed. The direction is the point of the scene and must
  # survive. The zoom is not: saved per scene by hand, it made a 22 inch panel
  # and a 46 inch wall come out the same size on screen, so nothing in the flat
  # library was comparable to anything else, or to the Iso30 set.
  #
  # So after the scene is selected, only the projection and the vertical extent
  # are overwritten. Camera#height is the frame's height in INCHES and only means
  # anything in parallel projection, so perspective goes off first — the order
  # matters, and setting height on a perspective camera silently does nothing.
  #
  # px per inch = image height in px / view height in inches. That is the number
  # to match against the angled set, NOT the view height, because the two
  # exporters do not use the same canvas.
  def self.view_height(spec)
    s = spec.to_s.strip
    return nil if s.empty? || s.downcase == 'scene'
    v = s.to_f
    v > 0 ? v : nil
  end

  def self.pin_camera(view, view_h)
    return if view_h.nil?
    cam = view.camera
    cam.perspective = false if cam.perspective?
    cam.height = view_h
  rescue StandardError => e
    puts "  *** could not pin the camera: #{e.class}: #{e.message}"
  end

  # ------------------------------------------------------------- diagnostics --
  #
  # The angled exporter has written one of these for a while; this one did not,
  # and the cost showed. When the flat set looked wrong beside the angled set
  # there was no way to tell whether the contract had even been applied to it —
  # the only evidence was the pixels, and pixels cannot say what the style was.
  #
  # The block is deliberately the same shape as the angled exporter's, so the
  # two can be diffed line for line rather than read and compared by eye.
  def self.dump_diagnostics(model, cfg, plan, width, height, stuck)
    path = File.join(cfg['dir'], '_diagnostics.txt')
    view = model.active_view
    File.open(path, 'w') do |f|
      f.puts 'EXPORT COMPONENT ART — diagnostics'
      f.puts "model      #{model.title}"
      f.puts "style opt  #{cfg['style']}"
      f.puts "dark       #{WR_Shading.dark_value(cfg['dark'])} (Light #{WR_Shading::DEF_LIGHT})"
      f.puts "recover    #{cfg['recov']}"
      f.puts "canvas     #{width} x #{height} px  (aspect from the viewport, " \
             "#{view.vpwidth}x#{view.vpheight})"
      f.puts "scenes     #{plan.size}"
      f.puts ''
      # SCALE IS NOT CONTROLLED HERE, and that is worth saying out loud. The
      # angled exporter fixes a view height in inches so every part is drawn at
      # one scale. This one uses each scene's STORED camera, so magnification is
      # whatever the scene was saved at — which is why the fabric texture reads
      # coarser here than in the angled set even when the tone matches.
      f.puts 'CAMERA'
      cam = view.camera
      vh = view_height(cfg['view'])
      f.puts "  perspective              #{(cam.perspective? rescue 'unreadable')}"
      f.puts "  height (parallel, in)    #{(cam.height rescue 'n/a')}"
      if vh
        f.puts format('  view height PINNED       %.3f in -> %.3f px per inch', vh, height / vh)
        f.puts '  Direction still comes from each scene. Only projection and'
        f.puts '  vertical extent are overwritten.'
      else
        f.puts '  view height              scene (each scene\'s own saved zoom)'
        f.puts '  NOTE parts are NOT at a common scale in this run.'
      end
      f.puts ''
      f.puts 'SHADING CONTRACT AS RENDERED — diff this block against the angled run'
      WR_Shading.describe(model).each { |l| f.puts "  #{l}" }
      f.puts ''
      if stuck.nil? || stuck.empty?
        f.puts '  all contract keys applied cleanly'
      else
        f.puts '  COULD NOT SET:'
        stuck.each { |s| f.puts "    #{s}" }
        f.puts '  -> these must be changed in the style itself; the API will not do it.'
      end
      f.puts ''
      f.puts 'SCENE -> FILE'
      plan.each { |p| f.puts format('  %3d  %-40s -> %s.png', p[:n], p[:scene], p[:base]) }
    end
    puts "  diagnostics  #{path}"
  rescue StandardError => e
    puts "  diagnostics NOT written: #{e.class}: #{e.message}"
  end

  # ------------------------------------------------------------------ export --

  def self.export(model, cfg, plan, width, height)
    dir = cfg['dir']
    FileUtils.mkdir_p(dir)
    view  = model.active_view
    pages = model.pages
    trans = cfg['trans'] == 'Yes'
    over  = cfg['over'] == 'Yes'
    view_h = view_height(cfg['view'])
    prev_cam = (view.camera.clone rescue nil)

    page_opts = model.options['PageOptions']
    prev_tt   = page_opts['TransitionTime']
    page_opts['TransitionTime'] = 0

    # THE SHADING CONTRACT. Pushed once, re-applied after every scene switch,
    # popped in the ensure below. Re-applying is not belt-and-braces: selecting
    # a page RESTORES THAT SCENE'S OWN STYLE, which is exactly how this exporter
    # and the angled one drifted apart in the first place.
    saved_shade = WR_Shading.push(model, cfg['style'], cfg['dark'])
    stuck = WR_Shading.apply(model, cfg['dark'])
    puts '  shading contract in force:'
    WR_Shading.describe(model).each { |l| puts "    #{l}" }
    puts ''

    prev_page = pages.selected_page

    written = 0
    skipped = 0
    failed  = []
    records = []

    begin
      plan.each_with_index do |p, i|
        path = File.join(dir, "#{p[:base]}.png")
        replaced = false
        if File.exist?(path)
          if over
            # write_image will NOT replace a file that another program holds
            # open — it just returns false with no reason. Delete it first so
            # a lock reports itself instead of looking like "overwrite is
            # broken", which is exactly how this was reported.
            begin
              File.delete(path)
              replaced = true
            rescue StandardError => e
              failed << "#{p[:base]}.png (locked: #{e.message})"
              puts "  LOCKED #{p[:base]}.png — #{e.message}"
              puts '         close it in any image viewer and re-run'
              next
            end
          else
            skipped += 1
            puts "  skip  #{p[:base]}.png (already there — Overwrite is No)"
            records << { 'scene' => p[:scene], 'file' => "#{p[:base]}.png" }
            next
          end
        end

        pages.selected_page = p[:page]

        # A scene restores its own style AND its own camera on selection, so
        # both go back after the switch — otherwise the sky returns, the alpha
        # channel goes solid, face shading reverts to whatever that scene
        # stored, and the zoom is whatever it was saved at.
        WR_Shading.apply(model, cfg['dark'])
        pin_camera(view, view_h)

        view.refresh
        Sketchup.status_text = "Exporting #{i + 1} of #{plan.size}: #{p[:scene]}"

        ok = view.write_image(:filename    => path,
                              :width       => width,
                              :height      => height,
                              :antialias   => true,
                              :transparent => trans)
        if ok
          written += 1
          puts format('  %-9s %-38s -> %s.png',
                      replaced ? 'REPLACED' : 'ok', p[:scene], p[:base])
          records << { 'scene' => p[:scene], 'file' => "#{p[:base]}.png" }
        else
          failed << p[:scene]
          puts "  FAIL  #{p[:scene]}"
        end
      end
      # Written from INSIDE the block, after the last image, so the contract and
      # the camera it records are the ones that actually rendered — not the
      # state the model was in before the run, and not the state after pop.
      dump_diagnostics(model, cfg, plan, width, height, stuck)
    ensure
      WR_Shading.pop(model, saved_shade)
      page_opts['TransitionTime'] = prev_tt
      if prev_page
        pages.selected_page = prev_page   # restores its own camera with it
      elsif prev_cam
        (view.camera = prev_cam) rescue nil
      end
      Sketchup.status_text = ''
    end

    # The other half of why the two sets did not match: the angled exporter ran
    # this and the flat one never did. Same fixer, same flag, same folder.
    WR_Shading.recover(dir) if cfg['recov'] == 'Yes' && written > 0

    if cfg['man'] == 'Yes'
      man = { 'format' => 1, 'model' => model.title.to_s,
              'model_path' => model.path.to_s,
              'generated' => Time.now.strftime('%Y-%m-%d %H:%M'),
              'width' => width, 'height' => height,
              'transparent' => trans,
              'style' => cfg['style'], 'dark' => WR_Shading.dark_value(cfg['dark']),
              'images' => records }
      File.open(File.join(dir, 'manifest.json'), 'w') { |f| f.write(JSON.pretty_generate(man)) }
      puts "  manifest.json written — #{records.size} entries"
    end

    [written, skipped, failed]
  end

  # ------------------------------------------------------------------- entry --

  def self.run
    model = Sketchup.active_model
    if model.pages.count.zero?
      UI.messagebox("No scenes in this model.\n\nNothing to export.")
      return
    end

    cfg = ask
    return unless cfg

    view   = model.active_view
    width  = cfg['width'].to_i
    width  = 2400 if width < 200 || width > 6000
    height = (width * view.vpheight.to_f / view.vpwidth.to_f).round

    chosen, pick_note = select_pages(model, cfg['scenes'])
    if chosen.empty?
      UI.messagebox("No scenes selected by \"#{cfg['scenes']}\".\n\n" \
                    "Use all, current, numbers like 1-7,12, or text that appears " \
                    "in a scene name.")
      return
    end

    plan = build_plan(model, cfg, chosen)
    dry  = cfg['dry'] == 'Yes'

    puts ''
    puts "EXPORT COMPONENT ART#{dry ? '  —  DRY RUN, nothing will be written' : ''}"
    puts ''
    puts "  model    #{model.title}"
    puts "  out      #{cfg['dir']}"
    puts "  size     #{width} x #{height} px, #{cfg['trans'] == 'Yes' ? 'transparent' : 'opaque'}"
    vh = view_height(cfg['view'])
    if vh
      puts format('  scale    view height %.3f in -> %.3f px per inch  (PINNED, ' \
                  "every scene the same)", vh, height / vh)
    else
      puts '  scale    each scene\'s OWN saved zoom — parts are NOT comparable to'
      puts '           each other or to the Iso30 set. Type a view height in inches'
      puts '           to pin it.'
    end
    # px per inch is the number that has to match, not the view height: the two
    # exporters do not share a canvas. The Iso30 set is square, this one is not.
    puts format('           to match an Iso30 run of %d px at view height V, ' \
                'type V * %d / %d', 2400, height, 2400)
    puts format('           e.g. Iso30 at 2400 px / 160 in = 15.000 px per inch ' \
                '-> type %.3f here', 160.0 * height / 2400.0)
    puts "  scenes   #{plan.size} of #{model.pages.count}"
    puts "  picked   #{pick_note}"
    puts "  style    #{cfg['style']}"
    puts "  dark     #{WR_Shading.dark_value(cfg['dark'])}  " \
         "(Light #{WR_Shading::DEF_LIGHT}, sun-for-shading off, shadows off)"
    puts "  recover  #{cfg['recov']}"
    puts '  >> Style, Dark and Recover must MATCH the angled run or the two sets'
    puts '  >> will not sit together in the booth builder.'
    puts ''
    plan.each do |p|
      puts format('    %3d  %-38s -> %s.png', p[:n], p[:scene], p[:base])
    end
    puts ''
    puts '  The number on the left is the scene number — use it in the Scenes'
    puts '  field, e.g. "1-7,12". "all", "current" and plain text also work.'
    puts ''

    if dry
      puts '  DRY RUN — run again with Dry run = No to export.'
      puts ''
      UI.messagebox("Dry run: #{plan.size} scene(s).\n\n" \
                    "Check the console table, then run again with Dry run = No.")
      return
    end

    written, skipped, failed = export(model, cfg, plan, width, height)

    msg  = "#{written} written, #{skipped} skipped, #{failed.size} failed\n\n"
    msg << "#{cfg['dir']}\n#{width} x #{height} px"
    msg << "\n\nFailed: #{failed.join(', ')}" unless failed.empty?
    puts ''
    puts msg
    UI.messagebox(msg)
  rescue StandardError => e
    UI.messagebox("Export Component Art failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end
end

WR_ComponentArt.run
