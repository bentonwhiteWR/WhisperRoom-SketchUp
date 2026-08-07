# @title Orbit Export...
#
# Photograph a part — or every part of an assembly — from every angle, in one
# run, and write a manifest describing what came out.
#
# This is the piece the assembly manual is built on. export-scenes.rb can only
# export scenes that already exist, so 24 angles meant hand-building 24 scenes
# per part. This walks the camera instead.
#
#   booth-builder #d= link
#     -> gen-booth.py --design      (already exists)
#     -> build-booth.rb             (already exists)
#     -> THIS                       -> images + manifest.json
#     -> the manual
#
# THE POINT IS CONSTANT SCALE. A manual is unreadable if a part changes size as
# it turns, or if two parts on facing pages are at different scales. So the
# camera uses parallel projection with a FIXED view height computed once for the
# whole run — not zoom_extents, which reframes every shot. See SCALE below.
#
# STYLE IS YOURS. Set the style you want in SketchUp before running — edges on
# or off, shaded or hidden-line. The script only forces ground, horizon and fog
# off so transparency works, and puts them back afterwards.
#
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/orbit-export.rb"

require 'json'
require 'fileutils'

module WR_OrbitExport
  DEG      = Math::PI / 180.0
  PREF     = 'WR_OrbitExport'.freeze
  MAX_WARN = 400            # ask twice above this many images

  DEFAULTS = {
    'subject'  => 'Each part in selection',
    'az_step'  => '15',
    'els'      => '0,30,60',
    'width'    => '1200',
    'scale'    => 'One scale for the whole run',
    'margin'   => '8',
    'dir'      => 'C:/Users/bento/Desktop/ProposalFiles/PartArt'
  }.freeze

  # ------------------------------------------------------------------ input --

  def self.remembered(key)
    v = Sketchup.read_default(PREF, key, DEFAULTS[key])
    v.to_s.empty? ? DEFAULTS[key] : v.to_s
  end

  def self.ask
    prompts = ['Subject', 'Azimuth step (deg)', 'Elevations (deg, comma)',
               'Image width (px)', 'Scale', 'Margin (%)', 'Output folder']
    keys    = %w[subject az_step els width scale margin dir]
    defaults = keys.map { |k| remembered(k) }
    lists = [
      'Each part in selection|Selection as one|Whole model',
      '', '', '',
      'One scale for the whole run|Each part fills the frame',
      '', ''
    ]
    res = UI.inputbox(prompts, defaults, lists, 'Orbit Export')
    return nil unless res
    out = {}
    keys.each_with_index { |k, i| out[k] = res[i].to_s.strip }
    keys.each { |k| Sketchup.write_default(PREF, k, out[k]) }
    out
  end

  # ----------------------------------------------------------------- subject --

  # What we are photographing, as [label, entity_or_nil] pairs. A nil entity
  # means "everything visible", which is the whole-model case.
  def self.subjects(model, mode)
    sel = model.selection
    case mode
    when 'Whole model'
      [['model', nil]]
    when 'Selection as one'
      return nil if sel.empty?
      [[name_of(sel.first, 'selection'), sel.to_a]]
    else
      # Each part: the direct children of the selected container, or the
      # selected entities themselves if several are picked.
      if sel.empty?
        UI.messagebox("Select the booth (or the parts) first.")
        return nil
      end
      if sel.count == 1 && sel.first.respond_to?(:entities)
        kids = sel.first.entities.select { |e|
          e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        }
        if kids.empty?
          [[name_of(sel.first, 'part'), [sel.first]]]
        else
          kids.map { |k| [name_of(k, 'part'), [k]] }
        end
      else
        sel.to_a.map { |e| [name_of(e, 'part'), [e]] }
      end
    end
  end

  def self.name_of(e, fallback)
    n = e.respond_to?(:name) ? e.name.to_s : ''
    n = e.definition.name.to_s if n.empty? && e.respond_to?(:definition)
    n.strip.empty? ? fallback : n.strip
  end

  def self.slug(s)
    t = s.gsub(/[^0-9A-Za-z._ -]+/, '-').gsub(/\s+/, '-').gsub(/-+/, '-')
    t = t.sub(/\A-+/, '').sub(/-+\z/, '')
    t.empty? ? 'part' : t
  end

  # Bounding box of a list of entities, or of the whole model.
  def self.bounds_of(model, ents)
    bb = Geom::BoundingBox.new
    if ents.nil?
      bb.add(model.bounds)
    else
      ents.each { |e| bb.add(e.bounds) }
    end
    bb
  end

  # --------------------------------------------------------------- isolation --

  # Hide everything in the subject's own container except the subject, so a part
  # is photographed alone. Returns what to restore.
  def self.isolate(all_entities, keep)
    saved = []
    all_entities.each do |e|
      next unless e.respond_to?(:hidden?)
      next if keep.include?(e)
      saved << [e, e.hidden?]
      e.hidden = true unless e.hidden?
    end
    saved
  end

  def self.restore(saved)
    saved.each { |e, was| (e.hidden = was) if e.valid? }
  end

  # ------------------------------------------------------------------- camera --

  def self.aim(view, centre, dist, az, el, height, aspect)
    a = az * DEG
    e = el * DEG
    dir = Geom::Vector3d.new(Math.cos(e) * Math.cos(a),
                             Math.cos(e) * Math.sin(a),
                             Math.sin(e))
    eye = centre.offset(dir, dist)
    up  = (el.abs >= 89.0) ? Geom::Vector3d.new(0, 1, 0) : Geom::Vector3d.new(0, 0, 1)
    cam = view.camera
    cam.set(eye, centre, up)
    # Parallel projection with an explicit height is the only way to guarantee
    # the same scale in every frame — perspective distance does not, because the
    # part's depth changes as it turns.
    cam.perspective = false
    cam.aspect_ratio = aspect
    cam.height = height
    cam
  end

  # ---------------------------------------------------------------------- run --

  def self.run
    model = Sketchup.active_model
    view  = model.active_view

    cfg = ask
    return unless cfg

    subs = subjects(model, cfg['subject'])
    return if subs.nil? || subs.empty?

    az_step = cfg['az_step'].to_f
    az_step = 15.0 if az_step <= 0 || az_step > 180
    azs = (0...(360.0 / az_step).round).map { |i| (i * az_step).round }
    els = cfg['els'].split(',').map { |s| s.strip.to_f }.reject { |v| v.abs > 89.9 }
    els = [30.0] if els.empty?
    width = cfg['width'].to_i
    width = 1200 if width < 64 || width > 4000
    height = width                      # square: parts sit in a grid in the manual
    margin = cfg['margin'].to_f
    margin = 8.0 if margin < 0 || margin > 60
    run_scale = cfg['scale'].start_with?('One')
    dir = cfg['dir'].tr('\\', '/')

    total = subs.size * azs.size * els.size
    if total > MAX_WARN
      go = UI.messagebox("That is #{total} images (#{subs.size} parts x #{azs.size} " \
                         "azimuths x #{els.size} elevations).\n\nCarry on?", MB_YESNO)
      return unless go == IDYES
    end

    FileUtils.mkdir_p(dir)

    # One view height for the whole run, from the largest part, so nothing
    # changes size between shots. Diagonal rather than width, because the part
    # turns and its widest silhouette is the diagonal.
    boxes = subs.map { |(_, ents)| bounds_of(model, ents) }
    diags = boxes.map { |bb| bb.diagonal.to_f }
    run_h = diags.max * (1.0 + margin / 100.0)
    dist_base = diags.max * 3.0 + 120.0     # ortho: distance only affects clipping

    ro = model.rendering_options
    prev_ro = { 'DrawGround'  => ro['DrawGround'],
                'DrawHorizon' => ro['DrawHorizon'],
                'DisplayFog'  => ro['DisplayFog'] }
    prev_cam = view.camera.clone rescue nil
    prev_sel = model.selection.to_a

    manifest = {
      'generated'   => Time.now.strftime('%Y-%m-%dT%H:%M:%S'),
      'model'       => (model.path.to_s.empty? ? '(unsaved)' : model.path),
      'title'       => model.title.to_s,
      'scale'       => run_scale ? 'run' : 'part',
      'view_height' => run_h.round(3),
      'units'       => 'inches',
      'azimuth_step' => az_step,
      'azimuths'    => azs,
      'elevations'  => els,
      'width'       => width,
      'height'      => height,
      'parts'       => []
    }

    written = 0
    failed  = []
    used    = {}

    begin
      ro['DrawGround']  = false
      ro['DrawHorizon'] = false
      ro['DisplayFog']  = false
      model.selection.clear

      subs.each_with_index do |(label, ents), si|
        base = slug(label)
        if used.key?(base)
          used[base] += 1
          base = "#{base}-#{used[base]}"
        else
          used[base] = 1
        end

        bb = boxes[si]
        centre = bb.center
        h = run_scale ? run_h : bb.diagonal.to_f * (1.0 + margin / 100.0)
        dist = dist_base + bb.diagonal.to_f

        siblings = if ents.nil?
                     []
                   elsif ents.first.parent.respond_to?(:entities)
                     ents.first.parent.entities.to_a
                   else
                     model.entities.to_a
                   end
        saved = ents.nil? ? [] : isolate(siblings, ents)

        frames = []
        begin
          els.each do |el|
            azs.each do |az|
              fn = format('%s_az%03d_el%03d.png', base, az.round, el.round.abs)
              path = File.join(dir, fn)
              aim(view, centre, dist, az, el, h, width.to_f / height)
              view.refresh
              Sketchup.status_text =
                "Orbit: #{label} — #{written + 1} of #{total}"
              ok = view.write_image(:filename    => path,
                                    :width       => width,
                                    :height      => height,
                                    :antialias   => true,
                                    :transparent => true)
              if ok
                written += 1
                frames << { 'file' => fn, 'az' => az.round, 'el' => el.round }
              else
                failed << fn
              end
            end
          end
        ensure
          restore(saved)
        end

        manifest['parts'] << {
          'name'   => label,
          'slug'   => base,
          'step'   => nil,     # fill in assembly order — the manual reads this
          'size'   => [bb.width.to_f.round(3), bb.height.to_f.round(3), bb.depth.to_f.round(3)],
          'frames' => frames
        }
      end
    ensure
      prev_ro.each { |k, v| ro[k] = v }
      view.camera = prev_cam if prev_cam
      model.selection.add(prev_sel.select(&:valid?)) unless prev_sel.empty?
      Sketchup.status_text = ''
    end

    mpath = File.join(dir, 'manifest.json')
    File.open(mpath, 'w') { |f| f.write(JSON.pretty_generate(manifest)) }

    report(manifest, dir, written, total, failed, run_scale, run_h)
  rescue StandardError => e
    UI.messagebox("Orbit export failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(6)
  end

  def self.report(m, dir, written, total, failed, run_scale, run_h)
    puts ''
    puts 'ORBIT EXPORT'
    puts ''
    puts "  #{m['parts'].size} part(s), #{m['azimuths'].size} azimuths x #{m['elevations'].size} elevations"
    puts "  #{written} of #{total} images written at #{m['width']}x#{m['height']}, transparent"
    puts "  -> #{dir}"
    puts "  -> manifest.json"
    puts ''
    if run_scale
      puts format('  ONE SCALE for the whole run: view height %.2f" (parallel projection).', run_h)
      puts '  Every part is comparable to every other. A small seal really does look small.'
    else
      puts '  EACH PART FILLS ITS FRAME. Good for a parts catalogue, wrong for an'
      puts '  assembly step where two parts appear together — they will not match.'
    end
    puts ''
    puts '  The manifest is the contract. Nothing downstream needs to know about'
    puts '  SketchUp — it reads part, step, angle and filename and builds the manual.'
    puts '  Fill in each part\'s "step" to set assembly order.'
    puts ''
    unless failed.empty?
      puts "  FAILED (#{failed.size}): #{failed.first(8).join(', ')}"
      puts '  Widths above ~4000 px fail on some GPUs — drop the width and re-run.'
      puts ''
    end
    UI.messagebox("#{written} of #{total} images written.\n\n#{dir}")
  end
end

WR_OrbitExport.run
