# @title Export This View...
# @cat Export art
#
# Save what is on screen right now as one PNG, named after the current scene.
#
# The one-off partner to export-component-art.rb. That one walks every scene and
# writes the lot; this one writes exactly one image — for when you have fixed a
# component, changed a camera, or added a part and want that single file
# replaced without re-rendering the other hundred.
#
# IT MATCHES THE BATCH BY DEFAULT. Output folder, width and transparency are
# seeded from whatever export-component-art.rb last used, so a one-off drops
# straight back into the set. If the folder has a manifest.json from a batch
# run, the script compares its own pixel size against it and WARNS on a
# mismatch — an image at a different aspect will not composite, and that is
# invisible until it is on the page.
#
# The name defaults to the selected scene. With no scene selected it falls back
# to the model title, and either way the field is editable, so a one-off that
# does not correspond to a scene is just a matter of typing the name.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/export-this-view.rb"

require 'sketchup.rb'
require 'fileutils'
require 'json'

module WR_ExportView
  PREF  = 'WR_ExportView'.freeze
  BATCH = 'WR_ComponentArt'.freeze     # seed from the batch exporter's settings

  FALLBACK = { 'dir' => 'C:/Users/bento/Desktop/ProposalFiles/ComponentArt',
               'width' => '2400', 'trans' => 'Yes' }.freeze

  def self.norm(p)
    p.to_s.strip.tr('\\', '/')
  end

  # The file is named after the scene, verbatim — only the characters Windows
  # genuinely refuses get replaced. Spaces are kept.
  FORBIDDEN = /[<>:"\/\\|?*\x00-\x1f]/.freeze

  def self.sanitize(s)
    out = s.to_s.strip.gsub(FORBIDDEN, '-')
    out.sub(/[. ]+\z/, '')
  end

  # This script's own setting if it has one, else the batch exporter's, else the
  # fallback. So the first one-off after a batch lands in the same folder at the
  # same size without being told.
  def self.seed(key)
    v = Sketchup.read_default(PREF, key, '').to_s
    return v unless v.empty?
    v = Sketchup.read_default(BATCH, key, '').to_s
    v.empty? ? FALLBACK[key].to_s : v
  end

  def self.current_name(model)
    pg = model.pages.selected_page
    return sanitize(pg.name.to_s) if pg && !pg.name.to_s.strip.empty?
    t = sanitize(model.title.to_s)
    t.empty? ? 'view' : t
  end

  def self.ask(model)
    keys = %w[name dir width trans over]
    prompts = ['File name (no .png)',
               'Output folder — blank to browse',
               'Image width (px)',
               'Transparent background',
               'Overwrite if it already exists']
    defaults = [current_name(model), seed('dir'), seed('width'), seed('trans'),
                Sketchup.read_default(PREF, 'over', 'Yes').to_s]
    lists = ['', '', '', 'Yes|No', 'Yes|No']
    res = UI.inputbox(prompts, defaults, lists, 'Export This View')
    return nil unless res
    cfg = {}
    keys.each_with_index { |k, i| cfg[k] = res[i].to_s.strip }

    if cfg['dir'].empty?
      picked = (UI.select_directory(:title => 'Where should the image go?') rescue nil)
      return nil if picked.nil? || picked.to_s.empty?
      cfg['dir'] = norm(picked)
    else
      cfg['dir'] = norm(cfg['dir'])
    end

    cfg['name'] = sanitize(cfg['name'])
    if cfg['name'].empty?
      UI.messagebox('That name has no usable characters in it.')
      return nil
    end

    %w[dir width trans over].each { |k| Sketchup.write_default(PREF, k, cfg[k]) }
    cfg
  end

  # If a batch wrote a manifest here, this image has to match its pixel size or
  # it will not composite with the rest. Cheap to check, invisible if missed.
  def self.batch_mismatch(dir, w, h)
    man = File.join(dir, 'manifest.json')
    return nil unless File.exist?(man)
    data = JSON.parse(File.read(man))
    bw = data['width'].to_i
    bh = data['height'].to_i
    return nil if bw.zero? || bh.zero?
    return nil if bw == w && bh == h
    "the batch in this folder is #{bw} x #{bh}, this image would be #{w} x #{h}"
  rescue StandardError
    nil
  end

  def self.run
    model = Sketchup.active_model
    view  = model.active_view

    cfg = ask(model)
    return unless cfg

    width  = cfg['width'].to_i
    width  = 2400 if width < 200 || width > 6000
    height = (width * view.vpheight.to_f / view.vpwidth.to_f).round
    trans  = cfg['trans'] == 'Yes'

    warn = batch_mismatch(cfg['dir'], width, height)
    if warn
      ans = UI.messagebox("Size does not match the batch in that folder —\n#{warn}.\n\n" \
                          "An image at a different aspect will not composite.\n" \
                          "Resize the SketchUp window, or carry on anyway?",
                          MB_OKCANCEL)
      return if ans == IDCANCEL
    end

    FileUtils.mkdir_p(cfg['dir'])
    path = File.join(cfg['dir'], "#{cfg['name']}.png")
    renamed = nil
    if File.exist?(path)
      if cfg['over'] == 'Yes'
        # Windows will not let write_image replace a file another program holds
        # open, and write_image just returns false. Delete it first so the real
        # reason surfaces instead of a mystery failure.
        begin
          File.delete(path)
        rescue StandardError => e
          UI.messagebox("Cannot overwrite:\n#{path}\n\n#{e.message}\n\n" \
                        "It is probably open in an image viewer. Close it and retry.")
          return
        end
      else
        n = 2
        n += 1 while File.exist?(File.join(cfg['dir'], "#{cfg['name']}-#{n}.png"))
        path = File.join(cfg['dir'], "#{cfg['name']}-#{n}.png")
        renamed = File.basename(path)
      end
    end

    ro = model.rendering_options
    prev_ro = trans ? { 'DrawGround'  => ro['DrawGround'],
                        'DrawHorizon' => ro['DrawHorizon'],
                        'DisplayFog'  => ro['DisplayFog'] } : {}
    ok = false
    begin
      if trans
        ro['DrawGround']  = false
        ro['DrawHorizon'] = false
        ro['DisplayFog']  = false
      end
      view.refresh
      ok = view.write_image(:filename    => path,
                            :width       => width,
                            :height      => height,
                            :antialias   => true,
                            :transparent => trans)
    ensure
      prev_ro.each { |k, v| ro[k] = v }
    end

    puts ''
    if ok
      puts 'EXPORT THIS VIEW'
      puts "  scene   #{model.pages.selected_page ? model.pages.selected_page.name : '(no scene selected — live camera)'}"
      puts "  file    #{path}"
      puts "  size    #{width} x #{height} px, #{trans ? 'transparent' : 'opaque'}"
      puts "  NOTE    #{warn}" if warn
      puts ''
      msg = "Written:\n#{File.basename(path)}\n\n#{width} x #{height} px"
      msg += trans ? ', transparent' : ''
      if renamed
        msg += "\n\nNOTE: that name already existed and Overwrite was off, " \
               "so it was saved as #{renamed} instead."
      end
      UI.messagebox(msg)
    else
      puts "EXPORT THIS VIEW — write_image returned false for #{path}"
      puts '  Usually the width: try 2400 or lower, some GPUs fail above ~4000.'
      puts ''
      UI.messagebox("SketchUp could not write that image.\n\nTry a smaller width — " \
                    "above about 4000 px fails on some GPUs.")
    end
  rescue StandardError => e
    UI.messagebox("Export This View failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end
end

WR_ExportView.run
