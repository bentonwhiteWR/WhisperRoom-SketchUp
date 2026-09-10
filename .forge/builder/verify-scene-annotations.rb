# verify-scene-annotations.rb — the LIVE half of the 1.20.0 acceptance list.
#
# Everything in this feature that is pure Ruby is already proven offline
# (scripts/rbtest-proposal.py, 100+ checks, mutation-checked). Everything that
# needs a real SketchUp — a real scene saving a real hidden flag — is proven
# HERE, by you, because there is no bridge from the assistant's session into
# your SketchUp window.
#
#   1. Open (or switch to) an UNTITLED model. This script REFUSES anywhere
#      else — it builds probe entities, probe tags and probe scenes.
#   2. Extensions > Developer > Ruby Console.
#   3. load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/verify-scene-annotations.rb"
#
# It prints one PASS/FAIL line per check and a JSON summary line, the way
# .forge/scoper/probe-scene-annotations.rb did. Paste the whole output back.
#
# IT CLEANS UP AFTER ITSELF in `ensure`: every scene, entity and tag it made
# is erased and the scene you were on is reselected. If cleanup itself fails
# it says so by name rather than leaving you to find out.

require 'json'

module WR_VerifyAnnotations
  DIR = File.expand_path('../../../scripts', __FILE__).freeze
  SET = 'WR-Notes-VerifyPlan'.freeze

  def self.say(name, ok, detail = nil)
    puts format('  %-4s %s%s', ok ? 'PASS' : 'FAIL', name, detail ? " — #{detail}" : '')
    @res[name] = { 'ok' => !!ok, 'detail' => detail }
    ok
  end

  def self.sel(page)
    @model.pages.selected_page = page
    @model.active_view.refresh
  end

  def self.cam_tuple(c)
    return nil unless c
    c.eye.to_a + c.target.to_a + c.up.to_a + [(c.perspective? ? c.fov : c.height)]
  rescue StandardError
    nil
  end

  def self.hidden?(e)
    e.valid? && e.hidden?
  rescue StandardError
    nil
  end

  def self.run
    @res   = {}
    @model = Sketchup.active_model
    unless @model
      puts 'VERIFY REFUSED: no model is open.'
      return
    end
    unless @model.path.to_s.empty?
      puts "VERIFY REFUSED: the active model is #{@model.path} — this script only " \
           'runs in an UNTITLED scratch model, because it creates probe scenes, ' \
           'tags and entities. Switch to (or open) an Untitled window and load it again.'
      return
    end

    # Load the two modules as libraries — no dialogs.
    was = $wr_no_autorun
    $wr_no_autorun = true
    begin
      load File.join(DIR, 'wr-scene-annotations.rb')
      load File.join(DIR, 'proposal-package.rb')
    ensure
      $wr_no_autorun = was
    end

    puts "verify-scene-annotations — SketchUp #{Sketchup.version}, " \
         "mask=#{WR_SceneAnnotations.update_mask}, plugin 1.20.0"

    pages     = @model.pages
    prev_page = pages.selected_page
    po        = @model.options['PageOptions']
    prev_tr   = (po['ShowTransition'] rescue nil)
    (po['ShowTransition'] = false) rescue nil

    made  = []
    pa = pb = layer = wall = nil
    begin
      # ---- fixture ----------------------------------------------------
      @model.start_operation('WR verify: build fixture', true)
      ents  = @model.entities
      layer = @model.layers.add(SET)
      loose1 = ents.add_text('VERIFY loose one',  Geom::Point3d.new(0, 0, 0))
      loose2 = ents.add_text('VERIFY loose two',  Geom::Point3d.new(0, 12, 0))
      dim    = ents.add_dimension_linear(Geom::Point3d.new(0, 0, 0),
                                         Geom::Point3d.new(48, 0, 0),
                                         Geom::Vector3d.new(0, -12, 0))
      lab = ents.add_group
      lab.entities.add_3d_text('VERIFY 3D', TextAlignLeft, 'Arial', true, false,
                               6.0, 0.0, 0.0, true, 0.0)
      lab.name = 'label: VERIFY 3D'
      m1 = ents.add_text('VERIFY member one',   Geom::Point3d.new(0, 24, 0))
      m2 = ents.add_text('VERIFY member two',   Geom::Point3d.new(0, 36, 0))
      m3 = ents.add_text('VERIFY member three', Geom::Point3d.new(0, 48, 0))
      [m1, m2, m3].each { |e| e.layer = layer }
      wall = ents.add_group
      wall.entities.add_face([[0, 0, 0], [24, 0, 0], [24, 0, 24], [0, 0, 24]])
      wall.name = 'VERIFY Wall 1'
      made = [loose1, loose2, dim, lab, m1, m2, m3, wall]
      pa = pages.add('WR-Verify-A')
      pb = pages.add('WR-Verify-B')
      [pa, pb].each do |pg|
        pg.use_hidden_layers  = true
        pg.use_hidden_objects = true if pg.respond_to?(:use_hidden_objects=)
        pg.transition_time = 0
      end
      @model.commit_operation

      key_of = lambda { |e| "e:#{e.entityID}" }
      setkey = "t:#{SET}"

      # ---- 1. inventory shape (acceptance 6) ---------------------------
      sel(pa)
      inv = WR_SceneAnnotations.inventory(@model)
      loose_keys = inv[:loose].map { |i| i[:key] }
      set_names  = inv[:sets].map  { |u| u[:name] }
      say('inventory.loose_lists_untagged',
          loose_keys.include?(key_of.call(loose1)) &&
          loose_keys.include?(key_of.call(dim)) &&
          loose_keys.include?(key_of.call(lab)),
          "loose=#{inv[:loose].size} sets=#{set_names.inspect}")
      say('inventory.no_untagged_set_row', !set_names.include?('Untagged'),
          "sets are #{set_names.inspect}")
      say('inventory.set_lists_its_members',
          (inv[:sets].find { |u| u[:name] == SET } || {})[:count] == 3)
      say('inventory.wall_is_not_an_annotation',
          !loose_keys.include?(key_of.call(wall)))

      # ---- 2. one loose callout, per scene (acceptance 2) --------------
      cam_before = cam_tuple(pa.camera)
      # orbit the viewport AFTER selecting, so acceptance 13 is a real test
      @model.active_view.camera.set(Geom::Point3d.new(300, -300, 200),
                                    Geom::Point3d.new(0, 0, 0), Z_AXIS)
      picks = {}
      inv[:loose].each { |i| picks[i[:key]] = false }
      inv[:sets].each do |u|
        picks[u[:key]] = false
        u[:members].each { |m| picks[m[:key]] = false }
      end
      picks[key_of.call(loose1)] = true
      ok, msg = WR_SceneAnnotations.apply(@model, picks)
      say('apply.returns_ok', ok, msg)
      say('camera.byte_identical_after_apply', cam_tuple(pa.camera) == cam_before,
          "before=#{cam_before.inspect} after=#{cam_tuple(pa.camera).inspect}")
      sel(pb); on_b = hidden?(loose1)
      sel(pa); on_a = hidden?(loose1)
      say('scene.loose_text_per_scene', on_b == false && on_a == true,
          "B hidden?=#{on_b} A hidden?=#{on_a} (expect false/true)")

      # ---- 3. a dimension and a 3D label, same way ---------------------
      sel(pa)
      WR_SceneAnnotations.inventory(@model)
      picks2 = picks.dup
      picks2[key_of.call(dim)] = true
      picks2[key_of.call(lab)] = true
      WR_SceneAnnotations.apply(@model, picks2)
      sel(pb); db = hidden?(dim); lb = hidden?(lab)
      sel(pa); da = hidden?(dim); la = hidden?(lab)
      say('scene.linear_dim_per_scene', db == false && da == true,
          "B=#{db} A=#{da}")
      say('scene.3d_label_per_scene', lb == false && la == true,
          "B=#{lb} A=#{la}")

      # ---- 4. the set, per tag (acceptance 4) --------------------------
      sel(pa)
      WR_SceneAnnotations.inventory(@model)
      picks3 = picks2.dup
      picks3[setkey] = true
      WR_SceneAnnotations.apply(@model, picks3)
      sel(pb); vis_b = layer.visible?
      sel(pa); vis_a = layer.visible?
      say('scene.set_hidden_per_scene', vis_b == true && vis_a == false,
          "tag visible? B=#{vis_b} A=#{vis_a} (expect true/false)")
      say('scene.page_layers_names_the_set',
          pa.layers.map { |l| l.name }.include?(SET) &&
          !pb.layers.map { |l| l.name }.include?(SET))

      # ---- 5. members keep their own flags under a hidden set (acc. 5) --
      sel(pa)
      WR_SceneAnnotations.inventory(@model)
      picks4 = picks3.dup
      picks4[key_of.call(m1)] = true    # 1 of 3 members ticked ...
      picks4[setkey] = true             # ... while the whole set is hidden
      WR_SceneAnnotations.apply(@model, picks4)
      picks5 = picks4.dup
      picks5[setkey] = false            # untick the set: m1 must STAY hidden
      WR_SceneAnnotations.apply(@model, picks5)
      say('scene.member_flag_survives_the_set',
          layer.visible? == true && hidden?(m1) == true && hidden?(m2) == false,
          "tag visible?=#{layer.visible?} m1 hidden?=#{hidden?(m1)} " \
          "m2 hidden?=#{hidden?(m2)}")

      # ---- 6. batch: all / none over the loose group (acceptance 3) ----
      sel(pa)
      inv6 = WR_SceneAnnotations.inventory(@model)
      all_on = {}
      inv6[:sets].each do |u|
        all_on[u[:key]] = false
        u[:members].each { |m| all_on[m[:key]] = false }
      end
      inv6[:loose].each { |i| all_on[i[:key]] = true }
      WR_SceneAnnotations.apply(@model, all_on)
      say('batch.all_loose_hidden',
          inv6[:loose].all? { |i| hidden?(i[:ent]) == true },
          "#{inv6[:loose].size} loose callout(s)")
      say('batch.wall_untouched', hidden?(wall) == false)
      all_off = {}
      all_on.each_key { |k| all_off[k] = false }
      WR_SceneAnnotations.apply(@model, all_off)
      say('batch.none_shows_them_again',
          inv6[:loose].all? { |i| hidden?(i[:ent]) == false })

      # ---- 7. selection round trip (acceptance 9) ----------------------
      sel(pa)
      WR_SceneAnnotations.inventory(@model)
      @model.selection.clear
      @model.selection.add([m1, m2])
      keys, hint, _others = WR_SceneAnnotations.keys_for_selection(@model)
      say('selection.keys_and_set_hint',
          keys.sort == [key_of.call(m1), key_of.call(m2)].sort && hint == SET,
          "keys=#{keys.inspect} hint=#{hint.inspect}")
      @model.selection.clear
      @model.selection.add([wall])
      wkeys, _wh, wothers = WR_SceneAnnotations.keys_for_selection(@model)
      say('selection.wall_is_not_an_annotation', wkeys.empty? && wothers > 0,
          "keys=#{wkeys.inspect} others=#{wothers}")
      _rok, rmsg = WR_SceneAnnotations.reveal(@model, key_of.call(loose1))
      say('reveal.selects_the_callout',
          @model.selection.to_a == [loose1], rmsg)

      # ---- 8. move selection into a set (acceptance 10) ----------------
      @model.selection.clear
      @model.selection.add([loose2, wall])
      mok, mmsg = WR_SceneAnnotations.move_selection_to_set(@model, 'VerifyPlan')
      say('move.moves_annotations_only',
          mok && loose2.layer.name == SET && wall.layer.name != SET, mmsg)
      say('move.names_what_it_refused', mmsg.to_s.include?('VERIFY Wall 1'), mmsg)
      loose2.layer = @model.layers[0]        # put it back for the rest

      # ---- 9. a scene that does not save (acceptance 12) ---------------
      pb.use_hidden_objects = false if pb.respond_to?(:use_hidden_objects=)
      say('pages.names_the_scene_that_will_not_save',
          WR_SceneAnnotations.pages_not_saving(@model).include?('WR-Verify-B'),
          WR_SceneAnnotations.pages_not_saving(@model).inspect)
      sel(pb)
      WR_SceneAnnotations.inventory(@model)
      WR_SceneAnnotations.apply(@model, { key_of.call(loose1) => false })
      say('pages.apply_turns_saving_back_on',
          (pb.use_hidden_objects? rescue nil) == true &&
          (pb.use_hidden_layers?  rescue nil) == true)

      # ---- 10. CLIENT-SAFE closes the Untagged hole (acceptance 8) -----
      # The pre-existing defect: annot_push hid TAGS only, so a note on
      # Untagged went out on a client image. Everything loose must now be
      # hidden — and everything must come back exactly as found.
      #
      # RETIRED 1.47.0: the client-safe mode and annot_push / annot_pop /
      # annot_reapply were removed at Benton's request ("It will never be
      # used"). On a current checkout this section is skipped by name so
      # the manifest checks below still run; the text is kept as the record
      # of what 1.20.0 proved.
      if WR_ProposalPackage.respond_to?(:annot_push)
      sel(pa)
      loose1.hidden = false
      loose2.hidden = true            # already hidden BEFORE the batch
      layer.visible = true
      before = { 'loose1' => hidden?(loose1), 'loose2' => hidden?(loose2),
                 'dim' => hidden?(dim), 'lab' => hidden?(lab),
                 'tag' => layer.visible?, 'wall' => hidden?(wall) }
      WR_ProposalPackage.instance_variable_set(:@client_safe, true)
      WR_ProposalPackage.instance_variable_set(:@annot_saved, nil)
      WR_ProposalPackage.instance_variable_set(:@annot_saved_entities, nil)
      WR_ProposalPackage.annot_push(@model, nil, 'verify.png')
      say('clientsafe.hides_untagged_callouts',
          hidden?(loose1) == true && hidden?(dim) == true && hidden?(lab) == true,
          "loose1=#{hidden?(loose1)} dim=#{hidden?(dim)} lab=#{hidden?(lab)}")
      say('clientsafe.hides_the_set_tag', layer.visible? == false)
      say('clientsafe.leaves_geometry_alone', hidden?(wall) == false)
      # ...and the record it kept is complete.
      rec = WR_ProposalPackage.instance_variable_get(:@annot_saved_entities)
      say('clientsafe.record_published_before_the_flip',
          rec.is_a?(Hash) && rec.key?(loose1.entityID) && rec.key?(dim.entityID),
          "#{rec.is_a?(Hash) ? rec.size : rec.inspect} callout(s) recorded")
      # A scene switch undoes the entity hides; annot_reapply must redo them.
      sel(pb)
      sel(pa)
      undone = hidden?(loose1) == false
      WR_ProposalPackage.annot_reapply(@model, nil, pa)
      say('clientsafe.reapply_survives_the_scene_switch',
          hidden?(loose1) == true,
          "the switch undid it: #{undone} — reapply put it back: #{hidden?(loose1)}")
      WR_ProposalPackage.annot_pop(@model, nil)
      after = { 'loose1' => hidden?(loose1), 'loose2' => hidden?(loose2),
                'dim' => hidden?(dim), 'lab' => hidden?(lab),
                'tag' => layer.visible?, 'wall' => hidden?(wall) }
      say('clientsafe.everything_put_back_as_found', before == after,
          "before=#{before.inspect} after=#{after.inspect}")
      WR_ProposalPackage.instance_variable_set(:@client_safe, false)
      else
        puts '  SKIP clientsafe.* — the client-safe mode was removed in 1.47.0'
      end

      # ---- 11. the manifest collector sees what is hidden --------------
      sel(pa)
      loose1.hidden = true
      rows = WR_ProposalPackage.collect_hidden_annotations(@model)
      say('manifest.collect_hidden_annotations',
          rows.is_a?(Array) &&
          rows.any? { |r| r['text'].to_s.include?('VERIFY loose one') },
          rows.is_a?(Array) ? "#{rows.size} row(s): #{rows.first.inspect}" : rows.inspect)
      annots = WR_ProposalPackage.collect_annotations(@model)
      say('manifest.collect_annotations_sees_the_3d_label',
          annots.any? { |r| r['kind'] == '3d_text' },
          annots.map { |r| r['kind'] }.uniq.inspect)
      loose1.hidden = false
    rescue StandardError => e
      (@model.abort_operation rescue nil)
      puts "VERIFY RAISED: #{e.class}: #{e.message}"
      puts e.backtrace.first(8).map { |l| "    #{l}" }.join("\n") if e.backtrace
      @res['raised'] = { 'ok' => false, 'detail' => "#{e.class}: #{e.message}" }
    ensure
      begin
        @model.start_operation('WR verify: clean up', true)
        @model.selection.clear
        [pa, pb].compact.each { |pg| (pages.erase(pg) rescue nil) }
        made.each { |e| (@model.entities.erase_entities(e) rescue nil) if e && e.valid? }
        (@model.layers.remove(layer) rescue nil) if layer
        @model.commit_operation
      rescue StandardError => e
        (@model.abort_operation rescue nil)
        puts "CLEANUP PROBLEM: #{e.class}: #{e.message} — check for WR-Verify-* " \
             "scenes, 'VERIFY' entities and the #{SET} tag by hand."
      end
      (po['ShowTransition'] = prev_tr) rescue nil unless prev_tr.nil?
      (pages.selected_page = prev_page) rescue nil if prev_page && prev_page.valid?
      @model.active_view.refresh rescue nil
      fails = @res.reject { |_k, v| v['ok'] }.keys
      puts fails.empty? ? "ALL #{@res.size} CHECKS PASS" :
                          "#{fails.size} of #{@res.size} FAILED: #{fails.join(', ')}"
      puts 'SUMMARY ' + { 'sketchup' => Sketchup.version,
                          'mask' => WR_SceneAnnotations.update_mask,
                          'checks' => @res }.to_json
    end
  end
end

WR_VerifyAnnotations.run
