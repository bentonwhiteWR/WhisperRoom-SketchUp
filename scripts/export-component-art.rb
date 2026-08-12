# @title Export Component Art...
# @cat Export art
#
# One transparent PNG per scene, for the whole model, in one pass — the art
# handoff for the orchestrator's new component style.
#
# Sibling of export-scenes.rb. That one makes PROPOSAL plates: five scenes,
# opaque, into ProposalFiles. This one makes COMPONENT ART: every scene, real
# alpha, plus a manifest, and it knows which scenes came from the height
# extension file so their filenames can be marked.
#
# ---------------------------------------------------------------------------
# TELLING THE HX SCENES APART — read this, it is the part that can go wrong
#
# merge-scenes.rb only renamed an incoming scene when its name ALREADY EXISTED
# in the host. So "ends in (2)" is not a reliable marker:
#
#   - an HX scene whose name was unique kept its own name, no (2)  -> MISSED
#   - a scene that was always called "... (2)" in the master       -> WRONGLY TAGGED
#
# So the real key is the scene sidecar merge-scenes.rb wrote in pass 1, which
# lists exactly the scenes that came out of the HX file. Point the dialog at it
# and the match is exact. Leave it blank and the script falls back to the (2)
# rule and says so, loudly, every run.
#
# The dialog opens on "Dry run = Yes" the first time. That prints the full
# scene -> filename -> HX table and writes nothing. Check a few names before
# committing 100-odd files to a handoff.
# ---------------------------------------------------------------------------
#
# BEFORE YOU RUN: size the SketchUp window to the aspect you want. Height comes
# from the viewport and every image in the run inherits it. The views are all
# front/side already, so nothing rotates and nothing is re-aimed.
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
    'json'   => '',
    'width'  => '2400',
    'trans'  => 'Yes',
    # Style and Dark are the shading contract. They MUST match whatever the
    # angled run used or the two sets will not sit together in the booth
    # builder — that is the whole reason wr-shading.rb exists.
    'style'  => WR_Shading::KEEP,
    'dark'   => WR_Shading::DEF_DARK.to_s,
    'recov'  => 'Yes',
    'over'   => 'No',
    'dry'    => 'Yes',
    'suffix' => 'HX',
    'man'    => 'Yes'
  }.freeze

  # ------------------------------------------------------------------- input --

  def self.ask
    keys = %w[scenes dir json width trans style dark recov over dry suffix man]
    prompts = ['Scenes — all / current / 1-7,12 / text',
               'Output folder — blank to browse',
               'HX scene list (.json) — blank uses the "(n)" rule',
               'Image width (px)',
               'Transparent background',
               'Style — must match the angled run',
               'Shadow Dark (0-100) — raise it to lift oblique faces',
               'Recover brightness after export (new graphics engine)',
               'Overwrite files already there',
               'Dry run — list only, write nothing',
               'Suffix for height-extension files',
               'Write manifest.json']
    defaults = keys.map do |k|
      v = Sketchup.read_default(PREF, k, DEFAULTS[k]).to_s
      v.empty? && k != 'json' ? DEFAULTS[k] : v
    end
    # POSITIONAL against prompts — one entry per prompt, in the same order, ''
    # where the field is free text. One missing '' shifts every dropdown below
    # it onto the wrong field, silently. Count them if you edit.
    lists = ['',                                        # scenes
             '',                                        # dir
             '',                                        # json
             '',                                        # width
             'Yes|No',                                  # trans
             WR_Shading.style_options(Sketchup.active_model).join('|'),
             '',                                        # dark
             'Yes|No',                                  # recov
             'Yes|No',                                  # over
             'Yes|No',                                  # dry
             '',                                        # suffix
             'Yes|No']                                  # man
    res = UI.inputbox(prompts, defaults, lists, 'Export Component Art')
    return nil unless res
    cfg = {}
    keys.each_with_index { |k, i| cfg[k] = res[i].to_s.strip }

    cfg['dir'] = browse_dir(cfg['dir'])
    return nil if cfg['dir'].nil?

    unless cfg['json'].empty?
      found = locate_json(cfg['json'], cfg['dir'])
      return nil if found.nil?
      cfg['json'] = found
    end

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

  # A bare filename typed off Explorer resolves against SketchUp's working
  # directory, which is never where the file is. Try the likely folders, then
  # open a real file dialog.
  def self.locate_json(path, out_dir)
    p = norm(path)
    return p if File.exist?(p)
    model = Sketchup.active_model
    dirs = [model.path.to_s.empty? ? nil : File.dirname(norm(model.path)), out_dir].compact
    base = File.basename(p)
    dirs.each do |d|
      cand = File.join(norm(d), base)
      return cand if File.exist?(cand)
    end
    picked = (UI.openpanel('Choose the exported scene list (.json)',
                           dirs.first.to_s, 'JSON Files|*.json||') rescue nil)
    if picked.nil? || picked.to_s.empty?
      UI.messagebox("Scene list not found:\n#{p}\n\nLeave the field blank to use " \
                    "the \"(n)\" rule instead.")
      return nil
    end
    norm(picked)
  end

  # ------------------------------------------------------------- the HX split --

  def self.hx_names_from(path)
    return [nil, nil] if path.to_s.empty?
    unless File.exist?(path)
      return [nil, "sidecar not found: #{path}"]
    end
    data = JSON.parse(File.read(path))
    names = (data['scenes'] || []).map { |s| s['name'].to_s }.reject(&:empty?)
    [names, "sidecar: #{File.basename(path)} (#{names.size} scene names)"]
  rescue StandardError => e
    [nil, "could not read sidecar (#{e.message})"]
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

  def self.build_plan(model, cfg, hx_names, chosen)
    suffix = cfg['suffix'].to_s.strip
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
      hx = if hx_names
             hx_names.any? { |n| raw == n || raw =~ /\A#{Regexp.escape(n)} \(\d+\)\z/ }
           else
             !(raw =~ / \(\d+\)\z/).nil?
           end
      base = sanitize(raw.sub(/ \(\d+\)\z/, ''))
      base = "scene-#{i + 1}" if base.empty?
      base = "#{base}-#{suffix}" if hx && !suffix.empty?
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
      out << { :page => page, :scene => raw, :base => base, :hx => hx, :n => n }
    end
    out
  end

  # ------------------------------------------------------------------ export --

  def self.export(model, cfg, plan, width, height)
    dir = cfg['dir']
    FileUtils.mkdir_p(dir)
    view  = model.active_view
    pages = model.pages
    trans = cfg['trans'] == 'Yes'
    over  = cfg['over'] == 'Yes'

    page_opts = model.options['PageOptions']
    prev_tt   = page_opts['TransitionTime']
    page_opts['TransitionTime'] = 0

    # THE SHADING CONTRACT. Pushed once, re-applied after every scene switch,
    # popped in the ensure below. Re-applying is not belt-and-braces: selecting
    # a page RESTORES THAT SCENE'S OWN STYLE, which is exactly how this exporter
    # and the angled one drifted apart in the first place.
    saved_shade = WR_Shading.push(model, cfg['style'], cfg['dark'])
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
            records << { 'scene' => p[:scene], 'file' => "#{p[:base]}.png", 'hx' => p[:hx] }
            next
          end
        end

        pages.selected_page = p[:page]

        # A scene restores its own style on selection, so the contract goes back
        # on AFTER the switch — otherwise the sky returns, the alpha channel
        # goes solid, and face shading reverts to whatever that scene stored.
        WR_Shading.apply(model, cfg['dark'])

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
          records << { 'scene' => p[:scene], 'file' => "#{p[:base]}.png", 'hx' => p[:hx] }
        else
          failed << p[:scene]
          puts "  FAIL  #{p[:scene]}"
        end
      end
    ensure
      WR_Shading.pop(model, saved_shade)
      page_opts['TransitionTime'] = prev_tt
      pages.selected_page = prev_page if prev_page
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
              'transparent' => trans, 'hx_suffix' => cfg['suffix'],
              'images' => records }
      File.open(File.join(dir, 'manifest.json'), 'w') { |f| f.write(JSON.pretty_generate(man)) }
      puts "  manifest.json written — #{records.size} entries, " \
           "#{records.count { |r| r['hx'] }} tagged #{cfg['suffix']}"
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

    hx_names, hx_note = hx_names_from(cfg['json'])
    hx_note ||= 'FALLBACK — any scene whose name ends in (n). See the script header.'

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

    plan = build_plan(model, cfg, hx_names, chosen)
    n_hx = plan.count { |p| p[:hx] }
    dry  = cfg['dry'] == 'Yes'

    puts ''
    puts "EXPORT COMPONENT ART#{dry ? '  —  DRY RUN, nothing will be written' : ''}"
    puts ''
    puts "  model    #{model.title}"
    puts "  out      #{cfg['dir']}"
    puts "  size     #{width} x #{height} px, #{cfg['trans'] == 'Yes' ? 'transparent' : 'opaque'}"
    puts "  scenes   #{plan.size} of #{model.pages.count}   " \
         "(#{n_hx} tagged #{cfg['suffix']}, #{plan.size - n_hx} not)"
    puts "  picked   #{pick_note}"
    puts "  HX key   #{hx_note}"
    puts "  style    #{cfg['style']}"
    puts "  dark     #{WR_Shading.dark_value(cfg['dark'])}  " \
         "(Light #{WR_Shading::DEF_LIGHT}, sun-for-shading off, shadows off)"
    puts "  recover  #{cfg['recov']}"
    puts '  >> Style, Dark and Recover must MATCH the angled run or the two sets'
    puts '  >> will not sit together in the booth builder.'
    puts ''
    plan.each do |p|
      puts format('    %3d  %-3s %-38s -> %s.png',
                  p[:n], p[:hx] ? cfg['suffix'] : '', p[:scene], p[:base])
    end
    puts ''
    puts '  The number on the left is the scene number — use it in the Scenes'
    puts '  field, e.g. "1-7,12". "all", "current" and plain text also work.'
    puts ''

    if n_hx.zero?
      puts '  *** NOTHING was tagged as height-extension. If that is wrong, point'
      puts '  *** the HX field at the sidecar merge-scenes.rb wrote in pass 1.'
      puts ''
    elsif hx_names.nil?
      puts '  *** The HX column came from the "(n)" fallback, which misses any HX'
      puts '  *** scene whose name did not clash and wrongly tags any original that'
      puts '  *** ends in (n). CHECK IT before turning Dry run off.'
      puts ''
    end

    if dry
      puts '  DRY RUN — run again with Dry run = No to export.'
      puts ''
      UI.messagebox("Dry run: #{plan.size} scene(s), #{n_hx} tagged #{cfg['suffix']}.\n\n" \
                    "Check the console table, then run again with Dry run = No.")
      return
    end

    written, skipped, failed = export(model, cfg, plan, width, height)

    msg  = "#{written} written, #{skipped} skipped, #{failed.size} failed\n\n"
    msg << "#{cfg['dir']}\n#{width} x #{height} px\n#{n_hx} tagged #{cfg['suffix']}"
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
