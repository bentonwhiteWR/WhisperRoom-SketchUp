# @title Merge Scenes...
#
# Bring one .skp into another AND keep the incoming file's scenes.
#
# SketchUp does not do this on its own. File > Import brings in geometry,
# component definitions, materials and tags — but scenes live on the model, not
# inside a component, so they are dropped. This script carries them across.
#
# WHY IT IS TWO PASSES
#
# There is no API for reading the pages of a file that is not open, and
# SketchUp on Windows only has one model open at a time. So:
#
#   PASS 1  open the INCOMING file (e.g. BoothBuilder HX), run this, choose
#           "Export scenes". It writes <file>-scenes.json next to the .skp.
#
#   PASS 2  open the HOST file (e.g. MASTERCOMPONENTSV1), run this, choose
#           "Import + rebuild scenes". It loads the .skp as a component, places
#           it clear of what is already there, and recreates every scene with
#           its camera moved by exactly the same amount.
#
# THE OFFSET IS DERIVED, NOT TYPED. You give a gap; the script works out where
# the incoming geometry actually landed and moves every camera by that same
# vector. Eye and target both move, so the view direction is untouched and each
# scene frames exactly what it framed before. Change the gap and the scenes
# still line up, because nothing about the framing was ever hard-coded.
#
# WHAT TRAVELS: scene name, description, camera (position, direction, up,
# perspective/parallel, field of view or view height), and which tags are hidden
# in that scene. Tags are matched BY NAME, which works because the import merges
# the incoming file's tags into the host by name.
#
# WHAT DOES NOT: styles, shadow settings, section planes, and any scene property
# that depends on a style. Those are model-level in the source file and there is
# no sane way to merge them. Every one of them is listed in the console report
# rather than silently dropped.
#
# Run it from the WhisperRoom panel, or by hand:
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/merge-scenes.rb"
#
# Ctrl+Z undoes a pass-2 import in one step.

require 'sketchup.rb'
require 'json'

module WR_MergeScenes
  PREF     = 'WR_MergeScenes'.freeze
  FORMAT   = 1                      # sidecar schema version
  DEFAULTS = {
    'step'   => 'Export scenes from THIS file',
    'json'   => '',
    'skp'    => '',
    'gap'    => '200',              # feet of clear air between the two lots
    'dir'    => 'Up (+Z)',
    'expl'   => 'Yes',
    'prefix' => ''
  }.freeze

  # ------------------------------------------------------------------- input --

  def self.ask
    keys = %w[step json skp gap dir expl prefix]
    prompts = ['Step',
               'Scene file (.json) — blank to browse',
               'SketchUp file to import — blank to browse',
               'Gap between the two lots (feet)',
               'Place the incoming lot',
               'Explode the placed instance once',
               'Prefix for incoming scene names']
    defaults = keys.map do |k|
      v = Sketchup.read_default(PREF, k, DEFAULTS[k]).to_s
      v.empty? ? DEFAULTS[k] : v
    end
    lists = ['Export scenes from THIS file|Import + rebuild scenes',
             '', '', '',
             'Up (+Z)|Beside (+X)|Behind (+Y)',
             'Yes|No', '']
    res = UI.inputbox(prompts, defaults, lists, 'Merge Scenes')
    return nil unless res
    out = {}
    keys.each_with_index { |k, i| out[k] = res[i].to_s.strip }
    keys.each { |k| Sketchup.write_default(PREF, k, out[k]) }
    out
  end

  def self.norm(path)
    path.to_s.strip.tr('\\', '/')
  end

  # ------------------------------------------------------------------ pass 1 --

  # A page's own camera is readable without selecting the page, which avoids the
  # scene-transition animation entirely. Tag visibility is not: it is only ever
  # the model's live state, so the page has to be selected to read it. Transition
  # time goes to zero first so that is instant rather than a slideshow.
  def self.export(model, out_path)
    pages = model.pages
    if pages.count.zero?
      UI.messagebox("This file has no scenes to export.\n\nOpen the file whose " \
                    "scenes you want to keep, then run this again.")
      return nil
    end

    opts = model.options['PageOptions']
    prev_tt = (opts['TransitionTime'] rescue nil)
    (opts['TransitionTime'] = 0) rescue nil
    prev_page = pages.selected_page

    scenes = []
    begin
      pages.each do |pg|
        pages.selected_page = pg
        cam = pg.camera
        scenes << {
          'name'        => pg.name,
          'description' => pg.description.to_s,
          'eye'         => xyz(cam.eye),
          'target'      => xyz(cam.target),
          'up'          => [cam.up.x.to_f, cam.up.y.to_f, cam.up.z.to_f],
          'perspective' => cam.perspective?,
          'fov'         => (cam.perspective? ? cam.fov.to_f : nil),
          'height'      => (cam.perspective? ? nil : cam.height.to_f),
          'aspect'      => cam.aspect_ratio.to_f,
          'hidden_tags' => model.layers.reject(&:visible?).map(&:name).sort,
          'use_camera'  => pg.use_camera?,
          'use_tags'    => pg.use_hidden_layers?,
          'use_render'  => pg.use_rendering_options?,
          'use_shadow'  => pg.use_shadow_info?,
          'use_axes'    => pg.use_axes?
        }
      end
    ensure
      pages.selected_page = prev_page if prev_page
      (opts['TransitionTime'] = prev_tt) rescue nil
    end

    data = {
      'format'  => FORMAT,
      'source'  => model.path.to_s,
      'title'   => model.title.to_s,
      'units'   => 'inches',
      'scenes'  => scenes
    }
    File.open(out_path, 'w') { |f| f.write(JSON.pretty_generate(data)) }
    scenes
  end

  def self.xyz(p)
    [p.x.to_f, p.y.to_f, p.z.to_f]     # inches, which is what the API works in
  end

  def self.default_json_for(model)
    p = model.path.to_s
    return '' if p.empty?
    norm(p).sub(/\.skp\z/i, '') + '-scenes.json'
  end

  # ------------------------------------------------------------------ pass 2 --

  # Where to put the incoming lot so it cannot land on top of what is already
  # here. Returns the translation actually applied, which is the ONLY thing the
  # cameras are moved by — so the two can never disagree.
  def self.placement(model, defn, gap_in, dir)
    host = model.bounds
    inc  = defn.bounds
    empty = host.width.to_f.abs < 1e-6 && host.height.to_f.abs < 1e-6

    return Geom::Vector3d.new(0, 0, 0) if empty && gap_in <= 0

    case dir
    when /Beside/
      Geom::Vector3d.new(host.max.x - inc.min.x + gap_in, 0, 0)
    when /Behind/
      Geom::Vector3d.new(0, host.max.y - inc.min.y + gap_in, 0)
    else
      Geom::Vector3d.new(0, 0, host.max.z - inc.min.z + gap_in)
    end
  end

  def self.apply_camera(cam, s, off)
    eye = Geom::Point3d.new(*s['eye']).offset(off)
    tgt = Geom::Point3d.new(*s['target']).offset(off)
    up  = Geom::Vector3d.new(*s['up'])
    up  = Z_AXIS if up.length.to_f < 1e-9
    cam.set(eye, tgt, up)
    cam.perspective = s['perspective'] ? true : false
    if s['perspective']
      cam.fov = s['fov'].to_f if s['fov'].to_f > 0
    else
      cam.height = s['height'].to_f if s['height'].to_f > 0
    end
    (cam.aspect_ratio = s['aspect'].to_f) rescue nil
  end

  # pages.add snapshots the CURRENT camera and tag visibility, so each scene is
  # rebuilt by putting the model into that state and then adding the page. Same
  # pattern proposal-scenes.rb uses.
  def self.rebuild(model, scenes, off, prefix)
    view  = model.active_view
    pages = model.pages
    made    = []
    renamed = []
    missing = []

    all_tags = model.layers.map(&:name)

    scenes.each do |s|
      want_hidden = s['hidden_tags'] || []
      (want_hidden - all_tags).each { |n| missing << n unless missing.include?(n) }

      model.layers.each { |l| l.visible = !want_hidden.include?(l.name) }

      apply_camera(view.camera, s, off)
      view.refresh

      name = prefix.empty? ? s['name'] : "#{prefix}#{s['name']}"
      if pages[name]
        n = 2
        n += 1 while pages["#{name} (#{n})"]
        renamed << [name, "#{name} (#{n})"]
        name = "#{name} (#{n})"
      end

      pg = pages.add(name)
      next if pg.nil?
      pg.description            = s['description'].to_s
      pg.use_camera             = s['use_camera'].nil? ? true : s['use_camera']
      pg.use_hidden_layers      = s['use_tags'].nil? ? true : s['use_tags']
      pg.use_rendering_options  = s['use_render'] ? true : false
      pg.use_shadow_info        = s['use_shadow'] ? true : false
      pg.use_axes               = s['use_axes'] ? true : false
      made << name
    end

    [made, renamed, missing]
  end

  # UI.inputbox has no file browser, so a bare filename typed off Explorer is the
  # obvious mistake — and a bare name resolves against SketchUp's working
  # directory, which is never where the file is. Try the folders it is actually
  # likely to be in, and only then open a real file dialog.
  def self.locate(path, title, filter, *dirs)
    dirs = dirs.compact.map { |d| norm(d) }.reject(&:empty?)
    p = norm(path)
    return p if !p.empty? && File.exist?(p)
    unless p.empty?
      base = File.basename(p)
      dirs.each do |d|
        cand = File.join(d, base)
        return cand if File.exist?(cand)
      end
    end
    picked = (UI.openpanel(title, dirs.first.to_s, filter) rescue nil)
    picked.nil? || picked.to_s.empty? ? nil : norm(picked)
  end

  def self.import(model, cfg)
    model_dir = model.path.to_s.empty? ? '' : File.dirname(norm(model.path))

    skp = locate(cfg['skp'], 'Choose the SketchUp file to import',
                 'SketchUp Files|*.skp||', model_dir)
    if skp.nil?
      UI.messagebox("No SketchUp file chosen — nothing imported.")
      return nil
    end
    json = locate(cfg['json'], 'Choose the exported scene file (.json)',
                  'JSON Files|*.json||', File.dirname(skp), model_dir)
    if json.nil?
      UI.messagebox("No scene file chosen.\n\nRun pass 1 in the other file " \
                    "first — it writes <file>-scenes.json next to the .skp.")
      return nil
    end
    Sketchup.write_default(PREF, 'skp', skp)
    Sketchup.write_default(PREF, 'json', json)

    data = JSON.parse(File.read(json))
    if data['format'].to_i != FORMAT
      UI.messagebox("That scene file is format #{data['format']}, this script " \
                    "writes #{FORMAT}. Re-export it.")
      return nil
    end
    scenes = data['scenes'] || []

    gap_in = cfg['gap'].to_f * 12.0            # feet -> inches, the API's unit
    gap_in = 0.0 if gap_in < 0

    prev_page = model.pages.selected_page
    prev_cam  = (model.active_view.camera.clone rescue nil)
    prev_vis  = model.layers.map { |l| [l.name, l.visible?] }

    model.start_operation('Merge file and scenes', true)

    defn = model.definitions.load(skp)
    if defn.nil?
      model.abort_operation
      UI.messagebox("SketchUp could not load:\n#{skp}")
      return nil
    end

    off = placement(model, defn, gap_in, cfg['dir'])
    inst = model.entities.add_instance(defn, Geom::Transformation.translation(off))
    inst.name = data['title'].to_s.empty? ? 'Imported' : data['title'].to_s

    exploded = 0
    if cfg['expl'] == 'Yes'
      bits = inst.explode
      exploded = bits.nil? ? 0 : bits.grep(Sketchup::Group).size +
                                 bits.grep(Sketchup::ComponentInstance).size
    end

    made, renamed, missing = rebuild(model, scenes, off, cfg['prefix'].to_s)

    model.commit_operation

    # Put the view back where it was — rebuilding scenes moved it a lot.
    model.layers.each do |l|
      pair = prev_vis.find { |n, _v| n == l.name }
      l.visible = pair[1] if pair
    end
    if prev_page
      model.pages.selected_page = prev_page
    elsif prev_cam
      model.active_view.camera = prev_cam
    end

    report_import(defn, off, gap_in, cfg, made, renamed, missing, exploded, scenes.size)
    made
  rescue StandardError => e
    model.abort_operation if model
    UI.messagebox("Merge failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
    nil
  end

  # ------------------------------------------------------------------- entry --

  def self.run
    model = Sketchup.active_model
    cfg = ask
    return unless cfg

    if cfg['step'].start_with?('Export')
      out = norm(cfg['json'])
      out = default_json_for(model) if out.empty?
      if out.empty?
        UI.messagebox("Save this file first — I need its path to name the " \
                      "scene file next to it.")
        return
      end
      scenes = export(model, out)
      return if scenes.nil?
      Sketchup.write_default(PREF, 'json', out)
      report_export(model, out, scenes)
    else
      import(model, cfg)
    end
  rescue StandardError => e
    UI.messagebox("Merge Scenes failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end

  # ------------------------------------------------------------------ report --

  def self.report_export(model, path, scenes)
    puts ''
    puts "MERGE SCENES — exported #{scenes.size} scene(s)"
    puts ''
    puts "  from  #{model.title}"
    puts "  to    #{path}"
    puts ''
    scenes.each do |s|
      puts format('    %-34s %s, %d tag(s) hidden', s['name'],
                  s['perspective'] ? 'perspective' : 'parallel',
                  (s['hidden_tags'] || []).size)
    end
    puts ''
    puts '  NOW: open the host file and run this again with'
    puts '       Step = "Import + rebuild scenes".'
    puts ''
  end

  def self.report_import(defn, off, gap_in, cfg, made, renamed, missing, exploded, wanted)
    puts ''
    puts "MERGE SCENES — imported #{defn.name}, rebuilt #{made.size} of #{wanted} scene(s)"
    puts ''
    puts format('  placed        %s, %.1f ft of gap', cfg['dir'], gap_in / 12.0)
    puts format('  offset        %.1f, %.1f, %.1f ft   <- every camera moved by exactly this',
                off.x.to_f / 12.0, off.y.to_f / 12.0, off.z.to_f / 12.0)
    puts format('  exploded      %s%s', cfg['expl'],
                exploded > 0 ? " -> #{exploded} object(s) now at top level" : '')
    puts ''
    unless renamed.empty?
      puts '  RENAMED — the host already had a scene with these names:'
      renamed.each { |a, b| puts "    #{a}  ->  #{b}" }
      puts '    Set a prefix and re-run if you would rather they were grouped.'
      puts ''
    end
    unless missing.empty?
      puts '  TAGS NAMED IN A SCENE BUT NOT IN THIS MODEL:'
      missing.each { |n| puts "    #{n}" }
      puts '    Those scenes will show more than they did in the source file.'
      puts ''
    end
    puts '  NOT CARRIED ACROSS — model-level in the source file, no way to merge:'
    puts '    styles, shadow settings, fog, section planes, model axes.'
    puts '    Scene name, description, camera and hidden tags all came over.'
    puts ''
    puts '  CHECK ONE SCENE BEFORE TRUSTING THE REST. Click an imported scene:'
    puts '    it should frame the same component it framed in the source file,'
    puts '    just higher up. If it aims at empty space, the offset is wrong and'
    puts '    Ctrl+Z puts everything back in one step.'
    puts ''
  end
end

WR_MergeScenes.run
