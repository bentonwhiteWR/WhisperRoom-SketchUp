# probe-scene-annotations.rb — settles the load-bearing question in
# .forge/scoper/scene-annotations.md BEFORE anyone builds on it.
#
# THE QUESTION: does a SketchUp scene save per-ENTITY hidden state for loose
# annotation entities (Sketchup::Text screen text, leader text,
# DimensionLinear, a 3D-text group) the way it provably does for nested wall
# groups (wr-scene-walls.rb, verified 31 Aug 2026)? And does per-TAG scene
# visibility (Page#set_visibility / Page#layers) round-trip for the same
# entities? The spec recommends TAGS; this probe proves both paths so the
# choice rests on observation, not on reasoning.
#
# READ-ONLY IN SPIRIT: it builds a few probe entities, two probe scenes and one
# probe tag, exercises them, and erases every one of them in `ensure`. It
# REFUSES BY NAME unless the active model is an UNTITLED scratch model
# (Benton, 31 Aug 2026: "only load into the 'untitled' file").
#
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/scoper/probe-scene-annotations.rb"
#
# Prints a PASS/FAIL line per check and one JSON summary line at the end.
# Paste the whole console output into the DEVLOG entry for the build.

require 'json'

module WR_ProbeSceneAnnotations
  TAG = 'WR-Notes-Probe'.freeze

  def self.mask
    m = 0
    m |= PAGE_USE_HIDDEN_OBJECTS  if defined?(PAGE_USE_HIDDEN_OBJECTS)
    m |= PAGE_USE_HIDDEN_GEOMETRY if defined?(PAGE_USE_HIDDEN_GEOMETRY)
    m = PAGE_USE_HIDDEN if m.zero? && defined?(PAGE_USE_HIDDEN)
    m
  end

  def self.say(name, ok, detail = nil)
    puts format('  %-4s %s%s', ok ? 'PASS' : 'FAIL', name, detail ? " — #{detail}" : '')
    @res[name] = { 'ok' => ok, 'detail' => detail }
  end

  def self.select(model, page)
    model.pages.selected_page = page
    model.active_view.refresh
  end

  def self.run
    @res = {}
    model = Sketchup.active_model
    unless model
      puts 'PROBE REFUSED: no model is open.'
      return
    end
    unless model.path.to_s.empty?
      puts "PROBE REFUSED: the active model is #{model.path} — this probe only " \
           'runs in an UNTITLED scratch model. Switch to (or open) an Untitled ' \
           'window and load it again.'
      return
    end

    puts "probe-scene-annotations — SketchUp #{Sketchup.version}, mask=#{mask} " \
         "(HIDDEN_OBJECTS=#{defined?(PAGE_USE_HIDDEN_OBJECTS) ? PAGE_USE_HIDDEN_OBJECTS : 'n/a'}, " \
         "HIDDEN_GEOMETRY=#{defined?(PAGE_USE_HIDDEN_GEOMETRY) ? PAGE_USE_HIDDEN_GEOMETRY : 'n/a'}, " \
         "LAYER_VISIBILITY=#{defined?(PAGE_USE_LAYER_VISIBILITY) ? PAGE_USE_LAYER_VISIBILITY : 'n/a'})"

    pages     = model.pages
    prev_page = pages.selected_page
    po        = model.options['PageOptions']
    prev_tr   = (po['ShowTransition'] rescue nil)
    (po['ShowTransition'] = false) rescue nil

    made = []
    pa = pb = layer = nil
    begin
      model.start_operation('WR probe: scene annotations', true)
      layer = model.layers.add(TAG)
      ents  = model.entities
      txt   = ents.add_text('PROBE SCREEN TEXT', Geom::Point3d.new(0, 0, 0))
      lead  = ents.add_text('PROBE LEADER TEXT', Geom::Point3d.new(0, 24, 0),
                            Geom::Vector3d.new(0, 0, 12))
      dim   = ents.add_dimension_linear(Geom::Point3d.new(0, 0, 0), Geom::Point3d.new(48, 0, 0),
                                        Geom::Vector3d.new(0, -12, 0))
      g3d   = ents.add_group
      g3d.entities.add_3d_text('PROBE 3D', TextAlignLeft, 'Arial', true, false,
                               6.0, 0.0, 0.0, true, 0.0)
      g3d.name = 'label: PROBE 3D'
      [txt, lead, dim, g3d].each { |e| e.layer = layer }
      made = [txt, lead, dim, g3d]
      pa = pages.add('WR-Probe-A')
      pb = pages.add('WR-Probe-B')
      [pa, pb].each do |pg|
        pg.use_hidden_layers = true
        pg.use_hidden_objects = true if pg.respond_to?(:use_hidden_objects=)
        pg.transition_time = 0
      end
      model.commit_operation

      kinds = { 'screen_text' => txt, 'leader_text' => lead, 'linear_dim' => dim, '3d_text_group' => g3d }

      # ---- 1. TAG PATH: Page#set_visibility + Page#layers, no page.update --
      puts 'TAG PATH (recommended mechanism)'
      pa.set_visibility(layer, false)
      pb.set_visibility(layer, true)
      say('tag.page_layers_lists_hidden_tag',
          pa.layers.map { |l| l.name }.include?(TAG) && !pb.layers.map { |l| l.name }.include?(TAG),
          "A hides #{pa.layers.map(&:name).inspect}, B hides #{pb.layers.map(&:name).inspect}")
      select(model, pb)
      vis_b = layer.visible?
      select(model, pa)
      vis_a = layer.visible?
      select(model, pb)
      vis_b2 = layer.visible?
      say('tag.roundtrip_B_A_B', vis_b && !vis_a && vis_b2,
          "B=#{vis_b} A=#{vis_a} B=#{vis_b2} (expect true/false/true)")
      # Does hiding the tag actually hide each kind? (visible? on the entity
      # is the tag-independent flag, so check the tag the entity sits on.)
      select(model, pa)
      say('tag.entities_follow_tag', kinds.values.all? { |e| e.valid? && e.layer == layer && !layer.visible? })
      # Untagged / Layer0: can it be hidden at all? (Decides whether loose
      # text on Untagged can ever be per-scene without moving it to a set.)
      l0 = model.layers[0]
      begin
        l0.visible = false
        l0_hidable = !l0.visible?
        l0.visible = true
        say('tag.untagged_can_hide', l0_hidable, "Untagged visible? after hide = #{!l0_hidable}")
      rescue StandardError => e
        say('tag.untagged_can_hide', false, "raised #{e.class}: #{e.message}")
      end
      pa.set_visibility(layer, true)
      layer.visible = true

      # ---- 2. PER-ENTITY PATH: hidden= + page.update(mask) ---------------
      puts "PER-ENTITY PATH (walls mechanism, page.update(#{mask}))"
      select(model, pa)
      kinds.each_value { |e| e.hidden = true }
      pa.update(mask)
      select(model, pb)
      on_b = kinds.map { |k, e| [k, e.hidden?] }.to_h
      select(model, pa)
      on_a = kinds.map { |k, e| [k, e.hidden?] }.to_h
      kinds.each do |k, _e|
        say("entity.#{k}", on_b[k] == false && on_a[k] == true,
            "B hidden?=#{on_b[k]} A hidden?=#{on_a[k]} (expect false/true)")
      end
      # camera untouched by the update mask?
      cam_before = pa.camera ? [pa.camera.eye.to_a, pa.camera.target.to_a] : nil
      model.active_view.camera.set(Geom::Point3d.new(300, -300, 200), Geom::Point3d.new(0, 0, 0), Z_AXIS)
      pa.update(mask)
      cam_after = pa.camera ? [pa.camera.eye.to_a, pa.camera.target.to_a] : nil
      say('entity.update_mask_leaves_camera', cam_before == cam_after,
          "before=#{cam_before.inspect} after=#{cam_after.inspect}")
      kinds.each_value { |e| e.hidden = false }
      pa.update(mask)
    rescue StandardError => e
      (model.abort_operation rescue nil)
      puts "PROBE RAISED: #{e.class}: #{e.message}"
      puts e.backtrace.first(6).map { |l| "    #{l}" }.join("\n") if e.backtrace
      @res['raised'] = { 'ok' => false, 'detail' => "#{e.class}: #{e.message}" }
    ensure
      begin
        model.start_operation('WR probe: clean up', true)
        [pa, pb].compact.each { |pg| (pages.erase(pg) rescue nil) }
        made.each { |e| (model.entities.erase_entities(e) rescue nil) if e && e.valid? }
        (model.layers.remove(layer) rescue nil) if layer
        model.commit_operation
      rescue StandardError => e
        (model.abort_operation rescue nil)
        puts "CLEANUP PROBLEM: #{e.class}: #{e.message} — check for WR-Probe-* scenes, " \
             "'PROBE' entities and the #{TAG} tag by hand."
      end
      (po['ShowTransition'] = prev_tr) rescue nil unless prev_tr.nil?
      (pages.selected_page = prev_page) rescue nil if prev_page && prev_page.valid?
      model.active_view.refresh rescue nil
      puts 'SUMMARY ' + { 'sketchup' => Sketchup.version, 'mask' => mask, 'checks' => @res }.to_json
    end
  end
end

WR_ProbeSceneAnnotations.run
