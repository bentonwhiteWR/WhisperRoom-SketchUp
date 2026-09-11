# verify-autoset.rb — the LIVE half of the AUTO-SET (1.48.0) acceptance list.
#
# Everything in this feature that is pure Ruby is already proven offline
# (scripts/rbtest-autoset.py, 63 checks, nine mutants killed by name). Everything
# that needs a real SketchUp — a real page saving a real hidden flag, a real
# attribute dictionary surviving a re-run, a real camera — is proven HERE, by
# you, because there is no bridge from the assistant's session into your
# SketchUp window.
#
#   1. Open (or switch to) an UNTITLED model. This script REFUSES anywhere
#      else — it builds probe rooms, probe booths, probe tags and probe scenes.
#   2. Extensions > Developer > Ruby Console.
#   3. load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/verify-autoset.rb"
#
# It prints one PASS/FAIL line per check and a JSON summary line. Paste the
# whole output back.
#
# IT CLEANS UP AFTER ITSELF in `ensure`: every scene, entity and tag it made is
# erased and the scene you were on is reselected. If cleanup itself fails it
# says so by name rather than leaving you to find out.
#
# 1.48.1 ADDED SECTION 0, THE ZERO-SCENE MODEL. AUTO-SET creates a booth's
# proposal scenes and lives inside the proposal-package window, which until
# 1.48.1 refused to open on a model with no scenes — so the feature was locked
# behind the door it unlocks. Section 0 walks the whole open path on a model
# with ZERO pages and ends by creating the first scenes from nothing, then
# removes them so every check after it runs on exactly the model it used to.
# IT OPENS AND CLOSES THE REAL PROPOSAL-PACKAGE WINDOW — expect it to appear
# and vanish. It runs ONLY if the model has no scenes when you load this (it
# will not delete scenes you own to manufacture that), and prints SKIPPED
# otherwise: use File > New to cover it.
#
# WHAT IT CANNOT CHECK. Whether a plate LOOKS right — framing is a taste call
# and always was. It checks the mechanism: the names, the marks, the stamp, what
# each scene hides, what survives a re-run, and what Remove leaves alone.

require 'json'

module WR_VerifyAutoSet
  DIR   = File.expand_path('../../../scripts', __FILE__).freeze
  # MUST be the name WR_AutoSet::SHOWN_BY_PLATE['05-plan'] actually allows.
  # It was 'WR-Notes-VerifyPlan' on the first live run (10 Sep 2026) and
  # annot.plan_shows_dims_doors_and_the_plan_set FAILED because of it: the
  # allowlist showed WR-Dims and WR-Dims-Doors and hid the unknown set, which
  # is the allowlist WORKING. The fixture was asserting that an invented tag
  # name would be shown. Using the real name means this check now proves the
  # plan plate shows its plan set, instead of proving a typo stays hidden.
  TAG_P = 'WR-Notes-Plan'.freeze
  ROOM  = 'WR-Verify room'.freeze
  B1    = 'MDL 9901 E VERIFY'.freeze
  B2    = 'MDL 9902 E VERIFY'.freeze
  MINE  = 'WR-Verify My test'.freeze     # the hand-made scene that must survive

  def self.say(name, ok, detail = nil)
    puts format('  %-4s %s%s', ok ? 'PASS' : 'FAIL', name, detail ? " — #{detail}" : '')
    @res[name] = { 'ok' => !!ok, 'detail' => detail }
    ok
  end

  def self.sel(page)
    @model.pages.selected_page = page
    @model.active_view.refresh
  end

  def self.hidden?(e)
    e.valid? && e.hidden?
  rescue StandardError
    nil
  end

  def self.cam_tuple(c)
    return nil unless c
    (c.eye.to_a + c.target.to_a).map { |v| v.round(2) }
  rescue StandardError
    nil
  end

  # A box group, so everything in the fixture is real geometry with real bounds.
  def self.box(ents, x0, y0, x1, y1, h, name = nil)
    g = ents.add_group
    f = g.entities.add_face([x0, y0, 0], [x1, y0, 0], [x1, y1, 0], [x0, y1, 0])
    f.pushpull(h)
    g.name = name if name
    g
  end

  # A room whose walls are NAMED the way wr-scene-walls.rb wants them
  # (PIECE_RE = /\A(Wall|Header|...) (\d+)/), so the wall picker has rows.
  # 20 ft x 16 ft, walls 4 in thick, 8 ft high — Benton's defaults.
  def self.make_room(ents)
    room = ents.add_group
    w = 240.0
    d = 192.0
    t = 4.0
    h = 96.0
    re = room.entities
    box(re, 0,     0,     w,     t,     h, 'Wall 1')
    box(re, 0,     d - t, w,     d,     h, 'Wall 2')
    box(re, 0,     0,     t,     d,     h, 'Wall 3')
    box(re, w - t, 0,     w,     d,     h, 'Wall 4')
    room.name = ROOM
    room
  end

  # A booth-shaped group with a DOOR-tagged plate on its -Y face and a
  # VENT-tagged plate on its +Y face, so tag_az has something real to read.
  def self.make_booth(ents, name, ox, oy)
    g  = ents.add_group
    ge = g.entities
    box(ge, ox, oy, ox + 96.0, oy + 60.0, 84.0, 'shell')
    door = box(ge, ox + 30.0, oy - 2.0, ox + 66.0, oy, 84.0, 'door frame')
    vent = box(ge, ox + 40.0, oy + 60.0, ox + 56.0, oy + 62.0, 20.0, 'vent')
    door.layer = @model.layers.add('WR-Booth-Door')
    vent.layer = @model.layers.add('WR-Booth-Vent')
    g.name = name
    g
  end

  def self.tag_names_hidden(page)
    page.layers.map { |l| l.name.to_s }
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
           'tags, rooms and booths. Switch to (or open) an Untitled window and ' \
           'load it again.'
      return
    end

    was = $wr_no_autorun
    $wr_no_autorun = true
    begin
      load File.join(DIR, 'proposal-package.rb')    # pulls in wr-autoset.rb
    ensure
      $wr_no_autorun = was
    end

    puts "verify-autoset — SketchUp #{Sketchup.version}, plugin " \
         "#{File.read(File.join(DIR, 'wr_tools', 'VERSION')).strip rescue '?'}, " \
         "mask=#{WR_SceneWalls.update_mask}"

    pages     = @model.pages
    prev_page = pages.selected_page
    prev_tr   = (@model.options['PageOptions']['ShowTransition'] rescue nil)
    made      = []
    made_pg   = []
    layer_p   = nil
    b1 = b2 = room = nil

    begin
      # ---------------------------------------------------------- fixture --
      @model.start_operation('WR verify: fixture', true)
      room = make_room(@model.entities)
      b1   = make_booth(@model.entities, B1, 24.0, 24.0)
      b2   = make_booth(@model.entities, B2, 130.0, 24.0)
      made.concat([room, b1, b2])

      layer_p = @model.layers.add(TAG_P)
      dims    = @model.layers.add('WR-Dims')
      doors   = @model.layers.add('WR-Dims-Doors')
      notes   = @model.layers.add('WR-Notes')

      t_dim  = @model.entities.add_text("20'-0\"", [60, 0, 100]);   t_dim.layer  = dims
      t_door = @model.entities.add_text("3'-0\"", [60, 10, 100]);   t_door.layer = doors
      # THE D5 STRING ITSELF. This is the banner that went out on a client
      # image on 30 Aug 2026; no auto-set plate may show it.
      t_note = @model.entities.add_text("Ceiling 8'-0\" - HOUSE DEFAULT, not measured.",
                                        [60, 20, 100])
      t_note.layer = notes
      t_plan = @model.entities.add_text('VERIFY plan note', [60, 30, 100])
      t_plan.layer = layer_p
      # Loose / Untagged callouts. SketchUp refuses to hide the Untagged tag,
      # which is the entire reason the annotation rule is an allowlist.
      t_l1 = @model.entities.add_text('VERIFY loose one', [60, 40, 100])
      t_l2 = @model.entities.add_text('VERIFY loose two', [60, 50, 100])
      made.concat([t_dim, t_door, t_note, t_plan, t_l1, t_l2])
      @model.commit_operation

      loose_ents = [t_l1, t_l2]

      # ------------------ 0. THE ZERO-SCENE MODEL (1.48.1) ---------------
      #
      # THE BUG THIS SECTION EXISTS FOR. WR_ProposalPackage.run refused to
      # open at all on a model whose `pages` was empty, and pointed at 'Set up
      # the five proposal plates'. But AUTO-SET -- the feature that CREATES a
      # booth's proposal scenes -- lives INSIDE that window. So a fresh model
      # with a booth placed and no scenes yet, exactly the state AUTO-SET
      # exists to solve, could not reach it. Benton, within minutes of 1.48.0:
      # "but I cant open up proposal package if there isnt any scenes".
      #
      # The fixture above makes GEOMETRY ONLY -- no pages -- so right here the
      # model still has however many scenes it had when you loaded this. The
      # section runs only if that is ZERO, because it must not delete scenes
      # you own to manufacture the condition; on a model that already has
      # scenes it prints SKIPPED and records nothing, so the run stays clean.
      # File > New gives you the model it wants.
      #
      # IT OPENS AND CLOSES THE REAL PROPOSAL-PACKAGE WINDOW. That is the
      # point: the door being unlocked cannot be proven from a pure method.
      # It closes it again before moving on.
      if pages.count.zero?
        say('empty.decision_is_open',
            WR_ProposalPackage.open_decision(true, 0) == :open,
            WR_ProposalPackage.open_decision(true, 0).inspect)
        say('empty.no_model_is_still_refused',
            WR_ProposalPackage.open_decision(false, 0) == :refuse)

        # Everything the window reads on OPEN, against a model with no pages.
        # The old `return` was doing defensive duty for all of this.
        say('empty.gather_is_an_empty_list',
            WR_ProposalPackage.gather(@model) == [],
            WR_ProposalPackage.gather(@model).inspect)
        say('empty.plan_names_of_nothing_is_nothing',
            WR_ProposalPackage.plan_names([]) == {})
        est = WR_ProposalPackage.state(@model)
        say('empty.state_builds', est.is_a?(Hash) && est['rows'] == [],
            est.is_a?(Hash) ? est.keys.inspect : est.class.to_s)
        say('empty.state_still_carries_the_material_slots',
            est['slots'].is_a?(Array) && !est['slots'].empty?,
            est['slots'].inspect)
        say('empty.nothing_to_undo_yet', est['undo'].nil?, est['undo'].inspect)
        ers = WR_AutoSet.row_states(@model)
        say('empty.row_states_reports_zero_scenes',
            ers['_n'] == 0 && ers['_deep'] == false, ers.inspect)

        # The HTML the window is built from, on this state. The empty grid has
        # to SAY WHAT TO DO NEXT and the disabled Export has to carry its
        # reason -- but the strings live in the JS, so what is checked here is
        # that the document builds and still carries the elements that render
        # them. jstest-proposal-dialog.js runs the script itself and asserts
        # the text.
        ehtml = WR_ProposalPackage.html('(verify)', est, '', '2400', 'Ask', true, true, '')
        say('empty.dialog_html_builds', ehtml.to_s.length > 1000, ehtml.to_s.length.to_s)
        say('empty.dialog_carries_the_disabled_reason_element',
            ehtml.to_s.include?('id="whynot"'))
        say('empty.dialog_carries_the_autoset_bar',
            ehtml.to_s.include?('id="autoset"'))

        # AUTO-SET's own payload, resolved against a model with no scenes --
        # the popover has to draw before there is anything to draw beside.
        ap = WR_ProposalPackage.autoset_payload(@model, B2)
        say('empty.autoset_payload_builds', ap['plan'] && ap['plan']['rows'],
            ap['note'].inspect)
        say('empty.autoset_plan_has_no_existing_scenes',
            ap['plan']['existing'] == 0 &&
              ap['plan']['rows'].none? { |r| r['exists'] },
            ap['plan']['existing'].inspect)

        # THE DOOR ITSELF. run() on a model with zero scenes must open a live
        # window rather than a message box.
        begin
          WR_ProposalPackage.run
          dlg = WR_ProposalPackage.instance_variable_get(:@dlg)
          say('empty.the_window_OPENS_with_no_scenes',
              WR_ProposalPackage.dialog_alive?(dlg), dlg.inspect)
          (dlg.close rescue nil) if dlg
          say('empty.the_window_closes_again',
              !WR_ProposalPackage.dialog_alive?(dlg))
        rescue StandardError => e
          say('empty.the_window_OPENS_with_no_scenes', false,
              "#{e.class}: #{e.message}")
        end

        # AND THE POINT OF ALL OF IT: the first scenes in the model, made from
        # nothing, by the feature that was locked behind the door. Removed
        # again immediately so the model is back to zero pages and every check
        # below runs exactly as it did before this section existed.
        n0 = pages.count
        eok, emsg, = WR_AutoSet.apply(@model, b2, { 'mode' => 'create', 'renders' => 1 })
        say('empty.AUTOSET_creates_the_first_scenes_from_nothing', eok, emsg)
        say('empty.five_plates_where_there_were_none', pages.count == n0 + 5,
            "#{n0} -> #{pages.count}")
        etok = b2.get_attribute('WR_AutoSet', 'token', nil)
        say('empty.the_new_scenes_are_stamped',
            !etok.nil? && WR_AutoSet.token_pages(pages.to_a, etok).length == 5,
            etok.inspect)
        est2 = WR_ProposalPackage.state(@model)
        say('empty.the_grid_now_has_rows_to_review',
            est2['rows'].length == 5 && est2['rows'].all? { |r| r['file'].to_s != '' ||
                                                                r['mode'] == 'skip' },
            est2['rows'].map { |r| [r['n'], r['mode'], r['file']] }.inspect)
        WR_AutoSet.apply(@model, b2, { 'mode' => 'remove' })
        say('empty.section_left_the_model_as_it_found_it', pages.count == n0,
            "#{pages.count} scene(s), token=" +
              b2.get_attribute('WR_AutoSet', 'token', nil).inspect)
      else
        puts "  SKIP empty-model section — this model already has "              "#{pages.count} scene(s). It is NOT exercised. Run this in a "              'fresh Untitled model (File > New) to cover the zero-scene path.'
      end

      # A scene Benton made by hand, present throughout. Nothing in this
      # feature may touch it — not update, not remove, not undo.
      mine_pg = pages.add(MINE)
      made_pg << mine_pg
      mine_name_at_start = mine_pg.name.to_s

      say('fixture.walls_named', WR_SceneWalls.scan(@model)[:walls].length == 4,
          "#{WR_SceneWalls.scan(@model)[:walls].length} wall unit(s)")
      say('fixture.two_booths', WR_ProposalPackage.booth_groups(@model).length >= 2,
          WR_ProposalPackage.booth_groups(@model).inspect)

      # ---------------------------------------------- 1. the resolver -----
      @model.selection.clear
      @model.selection.add(b1)
      got, note = WR_AutoSet.resolve_booth(@model)
      say('resolve.selection_wins', got == b1, note.inspect)
      @model.selection.clear
      @model.selection.add([b1, b2])
      got2, note2 = WR_AutoSet.resolve_booth(@model)
      say('resolve.two_booths_refused', got2.nil? && note2.to_s.include?('Select one'),
          note2.inspect)
      @model.selection.clear
      got3, = WR_AutoSet.resolve_booth(@model, B2)
      say('resolve.by_name', got3 == b2)
      say('resolve.choices_lists_both',
          WR_AutoSet.booth_choices(@model).map { |c| c['name'] }.include?(B1))

      # ------------------------------------------- 2. the door is READ ----
      daz = WR_AutoSet.tag_az(b1, 'WR-Booth-Door')
      vaz = WR_AutoSet.tag_az(b1, 'WR-Booth-Vent')
      # The door plate is on -Y of the booth, so the door heading is ~-90.
      say('door.read_from_tag', !daz.nil? && (daz + 90.0).abs < 25.0, daz.inspect)
      say('vent.read_from_tag', !vaz.nil? && (vaz - 90.0).abs < 25.0, vaz.inspect)

      # -------------------------------------- 3. booth 1: create the set --
      ok, msg, = WR_AutoSet.apply(@model, b1, { 'mode' => 'create', 'renders' => 2 })
      say('create.ok', ok, msg)
      tok1 = b1.get_attribute('WR_AutoSet', 'token', nil)
      say('create.token_on_booth', tok1.to_s == B1, tok1.inspect)
      set1 = WR_AutoSet.token_pages(pages.to_a, tok1)
      made_pg.concat(set1)
      say('create.five_pages', set1.length == 5, set1.map { |p| p.name }.inspect)
      say('create.named_after_the_booth',
          set1.map { |p| p.name.to_s }.sort ==
            WR_AutoSet.plate_ids(false).map { |id| "#{B1} #{id}" }.sort,
          set1.map { |p| p.name.to_s }.inspect)
      modes = set1.map { |p| WR_ProposalPackage.mode_of(p) }
      say('create.two_render_three_image',
          modes.count('render') == 2 && modes.count('image') == 3, modes.inspect)
      say('create.renders_are_exterior_and_front',
          set1.select { |p| WR_ProposalPackage.mode_of(p) == 'render' }
              .map { |p| WR_AutoSet.page_stamp(p)['plate'] }.sort ==
            ['01-exterior', '03-front'],
          set1.map { |p| [WR_AutoSet.page_stamp(p)['plate'], WR_ProposalPackage.mode_of(p)] }.inspect)
      say('create.stamp_carries_the_centre',
          set1.all? { |p| WR_AutoSet.page_stamp(p)['centre'].to_s.split(',').length == 3 })
      say('create.my_test_untouched_by_create',
          mine_pg.valid? && mine_pg.name.to_s == mine_name_at_start)

      # ---------------------- 4. THE ANNOTATION RULE, ON REAL PAGES ------
      # The highest-risk claim in the whole feature: a plate shows only the
      # sets it names, and every loose Untagged callout is hidden.
      bad_note  = []
      bad_loose = []
      shown_map = {}
      set1.each do |pg|
        sel(pg)
        plate = WR_AutoSet.page_stamp(pg)['plate']
        hid   = tag_names_hidden(pg) || []
        bad_note << plate unless hid.include?('WR-Notes')
        bad_loose << plate unless loose_ents.all? { |e| hidden?(e) }
        shown_map[plate] = (%w[WR-Dims WR-Dims-Doors WR-Notes] + [TAG_P]) - hid
      end
      say('annot.WR_Notes_hidden_on_every_plate', bad_note.empty?,
          bad_note.empty? ? 'the D5 banner is hidden on all five' : bad_note.inspect)
      say('annot.loose_callouts_hidden_on_every_plate', bad_loose.empty?,
          bad_loose.empty? ? 'both Untagged callouts hidden on all five' : bad_loose.inspect)
      say('annot.dimensioned_shows_dims_and_doors',
          shown_map['02-dimensioned'].sort == ['WR-Dims', 'WR-Dims-Doors'],
          shown_map['02-dimensioned'].inspect)
      say('annot.exterior_shows_nothing', shown_map['01-exterior'] == [],
          shown_map['01-exterior'].inspect)
      say('annot.front_shows_nothing', shown_map['03-front'] == [],
          shown_map['03-front'].inspect)
      say('annot.plan_shows_dims_doors_and_the_plan_set',
          shown_map['05-plan'].sort == ['WR-Dims', 'WR-Dims-Doors', TAG_P].sort,
          shown_map['05-plan'].inspect)
      say('annot.every_plate_saves_hidden_state',
          WR_SceneAnnotations.pages_not_saving(@model).reject { |n| n == MINE }.empty?,
          WR_SceneAnnotations.pages_not_saving(@model).inspect)

      # ------------------------------- 5. THE WALL RULE, ON REAL PAGES ---
      units    = WR_SceneWalls.scan(@model)[:walls]
      hid_by   = {}
      set1.each do |pg|
        sel(pg)
        plate = WR_AutoSet.page_stamp(pg)['plate']
        hid_by[plate] = units.count { |u| u[:pieces].all? { |g| hidden?(g) } }
      end
      say('walls.plan_hides_nothing', hid_by['05-plan'] == 0, hid_by.inspect)
      say('walls.exterior_hides_some_but_not_all',
          hid_by['01-exterior'] > 0 && hid_by['01-exterior'] < units.length,
          hid_by.inspect)
      say('walls.objects_never_auto_hidden',
          set1.all? { |pg| sel(pg); !hidden?(b1) && !hidden?(b2) })

      # ------------------------------------ 6. booth 2: no collision -----
      ok2, msg2, = WR_AutoSet.apply(@model, b2, { 'mode' => 'create', 'renders' => 2 })
      say('second.ok', ok2, msg2)
      tok2 = b2.get_attribute('WR_AutoSet', 'token', nil)
      set2 = WR_AutoSet.token_pages(pages.to_a, tok2)
      made_pg.concat(set2)
      say('second.token_differs', tok2.to_s != tok1.to_s, [tok1, tok2].inspect)
      say('second.five_more_pages', set2.length == 5)
      say('second.no_name_collision',
          (set1.map { |p| p.name.to_s } & set2.map { |p| p.name.to_s }).empty?)
      say('second.booth_ones_set_untouched',
          WR_AutoSet.token_pages(pages.to_a, tok1).length == 5)
      say('second.appended_after_the_first',
          pages.to_a.index(set2.first) > pages.to_a.index(set1.last),
          "#{pages.to_a.index(set1.last)} then #{pages.to_a.index(set2.first)}")

      # ---------------- 7. a hand-renamed scene, and a nudged camera -----
      hero = set1.find { |p| WR_AutoSet.page_stamp(p)['plate'] == '01-exterior' }
      hero.name = 'Hero for Steve'
      sel(hero)
      v = @model.active_view
      v.camera.set(v.camera.eye.offset(Geom::Vector3d.new(11, 7, 3)),
                   v.camera.target, v.camera.up)
      hero.update(PAGE_USE_CAMERA) if defined?(PAGE_USE_CAMERA)
      nudged = cam_tuple(hero.camera)
      n_before = pages.count

      ok3, msg3, = WR_AutoSet.apply(@model, b1, { 'mode' => 'update', 'renders' => 2,
                                                  'reaim' => false })
      say('update.ok', ok3, msg3)
      say('update.no_new_pages', pages.count == n_before, "#{n_before} -> #{pages.count}")
      say('update.renamed_scene_not_renamed_back', hero.valid? && hero.name.to_s == 'Hero for Steve',
          hero.name.to_s)
      say('update.nudged_camera_preserved', cam_tuple(hero.camera) == nudged,
          "#{nudged.inspect} vs #{cam_tuple(hero.camera).inspect}")
      say('update.my_test_still_untouched',
          mine_pg.valid? && mine_pg.name.to_s == mine_name_at_start)

      # -------------------------------------- 8. the booth has moved -----
      @model.start_operation('WR verify: move the booth', true)
      b1.transform!(Geom::Transformation.translation(Geom::Vector3d.new(36, 0, 0)))
      @model.commit_operation
      pl = WR_AutoSet.plan(@model, b1, {})
      say('moved.detected', pl['movedfar'] == true, pl['moved'].inspect)
      say('moved.reports_the_distance', pl['moved'].to_f > 1.0)
      @model.start_operation('WR verify: move it back', true)
      b1.transform!(Geom::Transformation.translation(Geom::Vector3d.new(-36, 0, 0)))
      @model.commit_operation

      # ------------------------------------- 9. the review columns -------
      t0 = Time.now
      rs = WR_AutoSet.row_states(@model)
      ms = Time.now - t0
      say('rows.deep_read_ran', rs['_deep'] == true, rs['_deep'].inspect)
      say('rows.every_scene_has_a_walls_cell',
          (1..pages.count).all? { |n| rs[n] && !rs[n]['walls'].nil? })
      say('rows.every_scene_has_an_annots_cell',
          (1..pages.count).all? { |n| rs[n] && rs[n]['annots'] && rs[n]['annots']['label'] })
      hero_n = pages.to_a.index(hero) + 1
      say('rows.a_clean_plate_is_not_flagged_orange',
          rs[hero_n]['annots']['warn'] == false, rs[hero_n]['annots'].inspect)
      mine_n = pages.to_a.index(mine_pg) + 1
      # THE HAND-MADE SCENE IS THE ORANGE CASE. It was never written by
      # auto-set, so both loose callouts are still showing on it — which is
      # exactly the signal the column exists to raise.
      say('rows.a_scene_showing_loose_callouts_IS_flagged_orange',
          rs[mine_n]['annots']['warn'] == true, rs[mine_n]['annots'].inspect)
      # THE MEASUREMENT THE SPEC FLAGGED AS ASSUMED. Report the number.
      say('rows.cost_measured', true,
          format('%d scene(s), deep read %.3f s (budget %.1f s) — %s', pages.count, ms,
                 WR_AutoSet::DEEP_BUDGET,
                 ms > WR_AutoSet::DEEP_BUDGET ? 'OVER BUDGET, deep read switches off' : 'inside budget'))

      # --------------------------------------------- 10. undo one run ----
      WR_AutoSet.deep = true
      n_pre = pages.count
      ok4, msg4, = WR_AutoSet.apply(@model, b2, { 'mode' => 'add', 'renders' => 1 })
      say('add.second_set_for_the_same_booth', ok4, msg4)
      added = pages.count - n_pre
      say('add.five_more', added == 5, added.to_s)
      made_pg.concat(pages.to_a)
      say('undo.available', !WR_AutoSet.undo_summary(@model).nil?,
          WR_AutoSet.undo_summary(@model).inspect)
      uok, umsg = WR_AutoSet.undo_last(@model)
      say('undo.ok', uok, umsg)
      say('undo.erased_what_it_created', pages.count == n_pre,
          "#{n_pre} -> #{pages.count}")
      say('undo.my_test_survived_the_undo',
          mine_pg.valid? && mine_pg.name.to_s == mine_name_at_start)

      # ----------------------------------------------- 11. remove --------
      n_pre2 = pages.count
      rok, rmsg, = WR_AutoSet.apply(@model, b1, { 'mode' => 'remove' })
      say('remove.ok', rok, rmsg)
      say('remove.only_this_booths_five', pages.count == n_pre2 - 5,
          "#{n_pre2} -> #{pages.count}")
      say('remove.my_test_survived_remove',
          mine_pg.valid? && mine_pg.name.to_s == mine_name_at_start)
      say('remove.booth_twos_set_survived',
          WR_AutoSet.token_pages(pages.to_a, tok2).length == 5)
      say('remove.token_cleared_off_the_booth',
          b1.get_attribute('WR_AutoSet', 'token', nil).nil?)

      # ------------------------------------------- 12. the orphan case ---
      @model.start_operation('WR verify: delete booth 2', true)
      @model.entities.erase_entities(b2)
      @model.commit_operation
      b2 = nil
      say('orphan.detected', WR_AutoSet.orphan_tokens(@model).include?(tok2.to_s),
          WR_AutoSet.orphan_tokens(@model).inspect)
    rescue StandardError => e
      (@model.abort_operation rescue nil)
      puts "VERIFY RAISED: #{e.class}: #{e.message}"
      puts e.backtrace.first(10).map { |l| "    #{l}" }.join("\n") if e.backtrace
      @res['raised'] = { 'ok' => false, 'detail' => "#{e.class}: #{e.message}" }
    ensure
      begin
        @model.start_operation('WR verify: clean up', true)
        @model.selection.clear
        # Every page this script could possibly have made: its own list plus
        # anything still carrying a verify stamp or a verify name.
        (made_pg + @model.pages.to_a).uniq.each do |pg|
          next unless pg && (pg.valid? rescue false)
          nm = pg.name.to_s
          st = (WR_AutoSet.page_stamp(pg) rescue nil)
          next unless nm == MINE || nm.include?('VERIFY') || nm == 'Hero for Steve' ||
                      (st && st['token'].to_s.include?('VERIFY'))
          (@model.pages.erase(pg) rescue nil)
        end
        made.each { |e| (@model.entities.erase_entities(e) rescue nil) if e && (e.valid? rescue false) }
        [TAG_P, 'WR-Dims', 'WR-Dims-Doors', 'WR-Notes',
         'WR-Booth-Door', 'WR-Booth-Vent'].each do |n|
          l = @model.layers[n]
          (@model.layers.remove(l, true) rescue nil) if l
        end
        @model.commit_operation
      rescue StandardError => e
        (@model.abort_operation rescue nil)
        puts "CLEANUP PROBLEM: #{e.class}: #{e.message} — check for WR-Verify-* / " \
             "'VERIFY' scenes, entities and tags by hand."
      end
      (@model.options['PageOptions']['ShowTransition'] = prev_tr) rescue nil unless prev_tr.nil?
      (@model.pages.selected_page = prev_page) rescue nil if prev_page && (prev_page.valid? rescue false)
      (@model.active_view.refresh rescue nil)
      fails = @res.reject { |_k, v| v['ok'] }.keys
      puts fails.empty? ? "ALL #{@res.size} CHECKS PASS" :
                          "#{fails.size} of #{@res.size} FAILED: #{fails.join(', ')}"
      puts 'SUMMARY ' + { 'sketchup' => Sketchup.version,
                          'checks' => @res }.to_json
    end
  end
end

WR_VerifyAutoSet.run
