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
# 1.50.0 REBUILT THE PLATES AND ADDED SECTION 13, THE CAMERA. The 1.48.0
# plates came back from Benton's first real run wrong in two separate ways, and
# only one of them was the numbers in the table: the aim was computed correctly
# and then NEVER SAVED ONTO THE PAGE on the create path, so all five scenes
# wore whatever camera the viewport happened to have. Nothing in this file
# noticed, because nothing in it had ever read a created page's camera back.
# Section 13 does exactly that — it reads page.camera off each fresh plate and
# measures where the eye actually stands. It is the half rbtest-autoset.py
# cannot reach: the offline harness proves aim() computes the right eye, this
# proves SketchUp kept it.
#
# The plate ids also changed (01-front / 02-angled / 03-high / 04-side /
# 05-ventilation / 06-plan / 07-interior), so a run makes SIX scenes now, not
# five, and every count below moved with it.
#
# 1.56.0 REORDERED THE PLATES AND CHANGED WHAT A RENDER IS. Benton, 11 Sep
# 2026: angled first, then front (01-angled / 02-front; the rest kept their
# ids), and a render is an EXTRA scene placed IN FRONT of its image, walked
# down the plate order -- the count adds scenes and converts nothing, and zero
# means zero. The interior is still the opt-in extra, always a render, never
# counted. Sections 3, 6, 7, 13, `dual.*`, `zero.*` and the new `migrate.*`
# pin all of that on real pages; every scene count is asked of the table for
# the render count that run used, never a literal.
#
# 1.57.0 MADE THE SIDE PLATE CHOOSE ITS SIDE: a window first, then the side
# with more distinct parts, then door +90 as before. Section 14 (`side.*`)
# builds a THIRD booth with a window panel on its door -90 side, because
# neither fixture booth had anything in a side wall and the rule could not
# otherwise be exercised; booth 1 is checked to be unchanged.
#
# 1.57.1 ADDED SECTION 15 for the two defects Benton found on 11 Sep 2026 with
# a real MDL 96144 E in a real room: the ventilation plate hid no wall
# ("all shown" on ten rows) and shot the side with one vent instead of the
# back with three. A FOURTH booth with three vents on +Y and one on +X sits
# inside a SECOND room shaped like build-room.rb's output (Room > Walls >
# Wall N) that has been MOVED, so its walls' bounds are in the room's space
# and not the model's -- the case the origin-sitting fixture room can never
# exercise. `roomx.*` pins the model-space wall centres and the hidden wall;
# `vent.*` pins the anchor wall, the swing hand, the log line and the re-run.
#
# WHAT IT CANNOT CHECK. Whether a plate LOOKS right — framing is a taste call
# and always was. It checks the mechanism: the names, the marks, the stamp, what
# each scene hides, what survives a re-run, what Remove leaves alone, and now
# where each camera ended up.

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
  B3    = 'MDL 9903 E VERIFY'.freeze     # the one with a WINDOW on its door -90 side
  B4    = 'MDL 9904 E VERIFY'.freeze     # three vents on +Y, one on +X; lives in the MOVED room
  ROOM2 = 'Room'.freeze                  # build-room.rb's default name, as on Benton's model
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
  #
  # IT BUILDS UPWARD, AND THAT TOOK A LIVE RUN TO FIND. SketchUp orients a face
  # drawn flat on the ground plane with its FRONT pointing DOWN, whatever order
  # the points are given in, and pushpull follows the face normal. So
  # `f.pushpull(h)` sank every box in this fixture to z -h..0: the live run of
  # 1.50.0 reported the booth centre at z -42.0 and the room walls hanging
  # below the ground plane. Nothing that compares one fixture bound against
  # another noticed, because the whole model was mirrored consistently -- but
  # the first check to assert an ABSOLUTE height ("a standing eye is ~5'-6" off
  # the floor") read -14.8 and failed a camera that was correct.
  #
  # Pushing along the sign of the normal puts the model the right way up, which
  # is also how build-booth.rb and build-room.rb really build. The checks
  # below ALSO measure off the booth's own bounds rather than trusting z 0 --
  # belt and braces, for the same reason verify-caster-lift.rb needed fixing on
  # 9 Sep: a fixture that lies makes a correct tool look broken.
  def self.box(ents, x0, y0, x1, y1, h, name = nil)
    g = ents.add_group
    f = g.entities.add_face([x0, y0, 0], [x1, y0, 0], [x1, y1, 0], [x0, y1, 0])
    f.pushpull(f.normal.z < 0 ? -h : h)
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

  # A ROOM SHAPED LIKE BENTON'S, AND MOVED (1.57.1). build-room.rb makes
  # Room > Walls > "Wall N" -- one container deeper than make_room -- and a
  # room a person has dragged into place carries a NON-IDENTITY
  # transformation, so every wall's #bounds (parent space) sits somewhere
  # other than where the wall stands in the model. The fixture above is at
  # the origin with identity transforms, the one case where the two agree,
  # which is why `walls.ventilation_hides_at_least_one` passed while
  # Benton's plate looked straight into a wall. Built at the origin in local
  # space, then MOVED to (ox, oy) the way the Move tool would.
  def self.make_room_moved(ents, ox, oy)
    room = ents.add_group
    w = 240.0
    d = 192.0
    t = 4.0
    h = 96.0
    walls = room.entities.add_group
    re = walls.entities
    box(re, 0,     0,     w,     t,     h, 'Wall 1')      # -Y
    box(re, 0,     d - t, w,     d,     h, 'Wall 2')      # +Y
    box(re, 0,     0,     t,     d,     h, 'Wall 3')      # -X
    box(re, w - t, 0,     w,     d,     h, 'Wall 4')      # +X
    walls.name = 'Walls'
    room.name  = ROOM2
    room.transform!(Geom::Transformation.new(Geom::Point3d.new(ox, oy, 0)))
    room
  end

  # A booth-shaped group with a DOOR-tagged plate on its -Y face and a
  # VENT-tagged plate on its +Y face, so tag_az has something real to read.
  # THE DOOR IS DELIBERATELY OFF-CENTRE ALONG ITS WALL (1.51.0). It used to sit
  # dead centre, which is the one position where the 1.50.x tag_az bug -- a
  # bearing to the door's CENTRE rather than the normal of its wall -- has zero
  # error. That is why every check passed while Benton's MDL 96120 S, whose
  # door is about 36 in off centre, came out with 01-front and 02-angled
  # apparently swapped. A fixture that only tests the easy position is not
  # testing the thing.
  # `window` adds a WINDOW PANEL on the -X face (the door -90 side, since the
  # door faces -Y), named the way the booth builders name one -- the slot,
  # two spaces, the component: "W0  46Panel3236WDO". It is on no tag, which
  # is how a real window panel arrives too (the builder puts windows on
  # WR-Booth-Walls; there is no window tag). Section 14 is the only user.
  # `split_vents` (1.57.1) replaces the single +Y vent with THREE on +Y and
  # ONE on +X, named the way build-booth-components.rb names them, the +X
  # one placed FIRST -- Benton's MDL 96144 E, "Right (E0), Back (N0), Back
  # (N1), Back (N2)", whose vent plate shot the side with one vent because
  # the first-walked part won a tie.
  def self.make_booth(ents, name, ox, oy, window = false, split_vents = false)
    g  = ents.add_group
    ge = g.entities
    box(ge, ox, oy, ox + 96.0, oy + 60.0, 84.0, 'shell')
    if split_vents
      e0 = box(ge, ox + 96.0, oy + 20.0, ox + 98.0, oy + 36.0, 20.0, 'E0  40VNT')
      n0 = box(ge, ox + 10.0, oy + 60.0, ox + 26.0, oy + 62.0, 20.0, 'N0  40VNT')
      n1 = box(ge, ox + 40.0, oy + 60.0, ox + 56.0, oy + 62.0, 20.0, 'N1  40VNT')
      n2 = box(ge, ox + 70.0, oy + 60.0, ox + 86.0, oy + 62.0, 20.0, 'N2  40VNT')
      vt = @model.layers.add('WR-Booth-Vent')
      [e0, n0, n1, n2].each { |v| v.layer = vt }
    end
    box(ge, ox - 2.0, oy + 14.0, ox, oy + 46.0, 84.0, 'W0  46Panel3236WDO') if window
    door = box(ge, ox + 54.0, oy - 2.0, ox + 90.0, oy, 84.0, 'door frame')
    # A DOOR LEAF, SWUNG OPEN, TAGGED THE SAME. Benton, 10 Sep 2026: "Front
    # should find the door frame really, rather than the door." The booth data
    # has a DRFRM slot (the frame, in the wall) and a leaf that can be drawn
    # open — and a leaf drawn open sits well off the wall plane, which drags
    # the tagged centroid into mid-air. Until this fixture carried BOTH, that
    # whole class of error was invisible here.
    leaf = box(ge, ox + 90.0, oy - 38.0, ox + 93.0, oy, 84.0, 'door leaf')
    vent = split_vents ? nil : box(ge, ox + 40.0, oy + 60.0, ox + 56.0, oy + 62.0, 20.0, 'vent')
    door.layer = @model.layers.add('WR-Booth-Door')
    leaf.layer = @model.layers['WR-Booth-Door']
    vent.layer = @model.layers.add('WR-Booth-Vent') if vent
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
      # A LOOSE DIMENSION ON NO TAG. Since 1.51.0 a loose row is judged by its
      # KIND: a dimension is a dimension and is shown, loose TEXT is unknown
      # content and stays hidden. The fixture needs one of each or it cannot
      # tell the two rules apart.
      t_ld = begin
        @model.entities.add_dimension_linear([120, 0, 0], [180, 0, 0], [0, -12, 0])
      rescue StandardError
        nil
      end
      made.concat([t_dim, t_door, t_note, t_plan, t_l1, t_l2])
      made << t_ld if t_ld
      @model.commit_operation

      # loose_ents stays TEXT ONLY -- it is the D5 guard's subject, and the
      # loose dimension is tracked separately because it is meant to SHOW.
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
        # THE COUNT COMES FROM THE PLATE TABLE, NOT A LITERAL. These three
        # were written when a default run made five plates and produced three
        # false failures the day the set became six (live, 10 Sep 2026). The
        # number of plates is AUTO-SET's to decide; what this section is
        # actually testing is that a model with ZERO pages ends up with a full
        # set of them, so ask the table.
        want_n = WR_AutoSet.plate_ids(false).length
        n0 = pages.count
        eok, emsg, = WR_AutoSet.apply(@model, b2, { 'mode' => 'create', 'renders' => 1 })
        say('empty.AUTOSET_creates_the_first_scenes_from_nothing', eok, emsg)
        say('empty.every_plate_where_there_were_none', pages.count == n0 + want_n,
            "#{n0} -> #{pages.count}, table wants #{want_n}")
        etok = b2.get_attribute('WR_AutoSet', 'token', nil)
        say('empty.the_new_scenes_are_stamped',
            !etok.nil? && WR_AutoSet.token_pages(pages.to_a, etok).length == want_n,
            "#{etok.inspect}, #{WR_AutoSet.token_pages(pages.to_a, etok.to_s).length} stamped")
        est2 = WR_ProposalPackage.state(@model)
        say('empty.the_grid_now_has_rows_to_review',
            est2['rows'].length == want_n && est2['rows'].all? { |r| r['file'].to_s != '' ||
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

      # IDENTITY, NOT A BARE TOTAL. This asked for "4 wall units in the model"
      # and the 1.50.0 live run answered 6 -- and a total cannot say WHICH six,
      # so it could neither be trusted nor diagnosed. What the fixture actually
      # promises is that make_room's four named walls are each found, in the
      # room it built them in; anything else the model happens to carry is not
      # this check's business. The detail prints every unit found, so if there
      # really are two strangers in there the next run names them.
      all_units = WR_SceneWalls.scan(@model)[:walls]
      mine_units = all_units.select { |u| u[:room].to_s == ROOM }
      say('fixture.walls_named',
          mine_units.map { |u| u[:wall] }.sort == [1, 2, 3, 4],
          all_units.map { |u| [u[:room], u[:wall]] }.inspect)
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
      # THE COUNT COMES FROM DEFAULT_RENDERS, NOT A LITERAL 2. This asked for 2
      # and the 1.53.0 live run produced THREE renders -- correctly. The knob
      # answers "how many of the ORDINARY plates", and since 02-angled came off
      # the ladder and its render half is forced, 2 off the ladder plus the
      # forced one is 3. The ladder is not over-promoting (rbtest ld1/ld3 pin
      # that); the fixture was asking for a number that changed meaning.
      # Asking for the real default keeps this section testing what a DEFAULT
      # RUN costs, which is the thing worth guarding.
      ok, msg, = WR_AutoSet.apply(@model, b1,
                                  { 'mode' => 'create',
                                    'renders' => WR_AutoSet::DEFAULT_RENDERS })
      say('create.ok', ok, msg)
      tok1 = b1.get_attribute('WR_AutoSet', 'token', nil)
      say('create.token_on_booth', tok1.to_s == B1, tok1.inspect)
      set1 = WR_AutoSet.token_pages(pages.to_a, tok1)
      made_pg.concat(set1)
      # THE COUNT COMES FROM THE PLATE TABLE, not a literal -- 1.53.0 made
      # 02-angled a DUAL plate, so a default run is seven pages, not six, and
      # a hard-coded number would have produced another wave of false failures.
      want_n = WR_AutoSet.plate_ids(false).length
      say('create.a_page_per_plate', set1.length == want_n,
          "#{set1.length} pages, table wants #{want_n}: #{set1.map { |p| p.name }.inspect}")
      say('create.named_after_the_booth',
          set1.map { |p| p.name.to_s }.sort ==
            WR_AutoSet.plate_ids(false).map { |id| "#{B1} #{id}" }.sort,
          set1.map { |p| p.name.to_s }.inspect)
      modes = set1.map { |p| WR_ProposalPackage.mode_of(p) }
      # A DEFAULT RUN IS DEFAULT_RENDERS RENDERS -- one, the angled -- and the
      # six image plates. That number is Benton's spend: if it ever moves,
      # someone changed what a default run costs. (Under the pre-1.56 ladder
      # it was two: the forced angled plus ventilation.)
      say('create.a_default_run_is_DEFAULT_RENDERS_renders',
          modes.count('render') == WR_AutoSet::DEFAULT_RENDERS &&
            modes.count('image') == want_n - WR_AutoSet::DEFAULT_RENDERS,
          "#{modes.inspect}, DEFAULT_RENDERS #{WR_AutoSet::DEFAULT_RENDERS}")
      say('create.the_default_render_is_the_angled_pair',
          set1.select { |p| WR_ProposalPackage.mode_of(p) == 'render' }
              .map { |p| WR_AutoSet.page_stamp(p)['plate'] } == ['01-angled r'],
          set1.map { |p| [WR_AutoSet.page_stamp(p)['plate'], WR_ProposalPackage.mode_of(p)] }.inspect)
      # THE TAB ORDER IS THE EXPORT ORDER, so the pages must land in plate
      # order: angled render, angled, front, high, side, ventilation, plan.
      say('create.scenes_land_in_plate_order',
          pages.to_a.select { |p| set1.include?(p) }
               .map { |p| WR_AutoSet.page_stamp(p)['plate'] } == WR_AutoSet.plate_ids(false),
          pages.to_a.select { |p| set1.include?(p) }
               .map { |p| WR_AutoSet.page_stamp(p)['plate'] }.inspect)
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
          bad_note.empty? ? "the D5 banner is hidden on all #{set1.length}" : bad_note.inspect)
      say('annot.loose_callouts_hidden_on_every_plate', bad_loose.empty?,
          bad_loose.empty? ? "both Untagged text callouts hidden on all #{set1.length}" : bad_loose.inspect)
      # DIMENSIONS ARE SHOWN ON EVERY PLATE (1.51.0). Benton, 10 Sep 2026:
      # "Also please dont hide any of the dimensions on the auto set." The two
      # checks that used to assert a plate showed NOTHING are now the two that
      # assert it shows the dimensions -- that expectation moved on purpose.
      %w[01-angled 02-front 03-high 04-side 05-ventilation 06-plan].each do |pl|
        say("annot.#{pl.tr('-', '_')}_shows_the_dimensions",
            (['WR-Dims', 'WR-Dims-Doors'] - shown_map[pl].to_a).empty?,
            shown_map[pl].inspect)
      end
      # The NOTE set is still per-plate and still opt-in: the plan names it,
      # nothing else does -- the angled RENDER scene included.
      say('annot.only_the_plan_shows_the_plan_note',
          shown_map['06-plan'].include?(TAG_P) &&
            %w[01-angled\ r 01-angled 02-front 03-high 04-side 05-ventilation]
              .none? { |pl| shown_map[pl].to_a.include?(TAG_P) },
          shown_map.map { |k, v| [k, v] }.inspect)
      # AND THE LOOSE DIMENSION SHOWS, while the loose TEXT does not. Both
      # halves, because "show the dimensions" must not become "show anything".
      if t_ld
        # THE DETAIL IS A FACT, NOT A FAILURE MESSAGE. say() prints the detail
        # on PASS as well as FAIL, so a failure-phrased string made this read
        # "PASS ... - a loose dimension entity was hidden on a plate" in the
        # 1.53.0 live run: the verdict said one thing and the text said the
        # opposite. A check whose text contradicts its verdict is worse than no
        # check.
        ld_hidden = set1.select { |pg| sel(pg); hidden?(t_ld) }
                        .map { |pg| WR_AutoSet.page_stamp(pg)['plate'] }
        say('annot.a_loose_DIMENSION_is_shown', ld_hidden.empty?,
            ld_hidden.empty? ? 'shown on all of them' :
                               "hidden on: #{ld_hidden.inspect}")
      else
        puts '  SKIP annot.a_loose_DIMENSION_is_shown - add_dimension_linear unavailable'
      end
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
      say('walls.plan_hides_nothing', hid_by['06-plan'] == 0, hid_by.inspect)
      say('walls.angled_hides_some_but_not_all',
          hid_by['01-angled'] > 0 && hid_by['01-angled'] < units.length,
          hid_by.inspect)
      # BENTON'S OWN WORDS ABOUT THE BACK SHOT: "this usually requires a
      # hidden wall". The cone rule is what does that, and it only fires if
      # the plate's camera actually landed on the page (section 13).
      say('walls.ventilation_hides_at_least_one',
          hid_by['05-ventilation'] > 0, hid_by.inspect)
      say('walls.objects_never_auto_hidden',
          set1.all? { |pg| sel(pg); !hidden?(b1) && !hidden?(b2) })

      # ------------------------------------ 6. booth 2: no collision -----
      # TWO RENDERS: "if two renders were selected, then it would add a
      # rendered front" -- so this set is EIGHT pages, and the count is asked
      # of the table for 2, never assumed equal to the default run's.
      ok2, msg2, = WR_AutoSet.apply(@model, b2, { 'mode' => 'create', 'renders' => 2 })
      say('second.ok', ok2, msg2)
      tok2 = b2.get_attribute('WR_AutoSet', 'token', nil)
      set2 = WR_AutoSet.token_pages(pages.to_a, tok2)
      made_pg.concat(set2)
      want_2 = WR_AutoSet.plate_ids(false, 2).length
      say('second.token_differs', tok2.to_s != tok1.to_s, [tok1, tok2].inspect)
      say('second.a_page_per_plate_at_two_renders', set2.length == want_2,
          "#{set2.length} pages, table wants #{want_2} at 2 renders")
      st2 = pages.to_a.select { |p| set2.include?(p) }.map { |p| WR_AutoSet.page_stamp(p)['plate'] }
      say('second.two_renders_add_the_front_render_before_the_front_image',
          st2 == WR_AutoSet.plate_ids(false, 2) &&
            st2.index('02-front r') == st2.index('02-front') - 1,
          st2.inspect)
      say('second.exactly_two_render_rows',
          set2.count { |p| WR_ProposalPackage.mode_of(p) == 'render' } == 2 &&
            set2.select { |p| WR_ProposalPackage.mode_of(p) == 'render' }
                .map { |p| WR_AutoSet.page_stamp(p)['plate'] }.sort == ['01-angled r', '02-front r'],
          set2.map { |p| [WR_AutoSet.page_stamp(p)['plate'], WR_ProposalPackage.mode_of(p)] }.inspect)
      say('second.no_name_collision',
          (set1.map { |p| p.name.to_s } & set2.map { |p| p.name.to_s }).empty?)
      say('second.booth_ones_set_untouched',
          WR_AutoSet.token_pages(pages.to_a, tok1).length == want_n)
      say('second.appended_after_the_first',
          pages.to_a.index(set2.first) > pages.to_a.index(set1.last),
          "#{pages.to_a.index(set1.last)} then #{pages.to_a.index(set2.first)}")

      # ---------------- 7. a hand-renamed scene, and a nudged camera -----
      hero = set1.find { |p| WR_AutoSet.page_stamp(p)['plate'] == '01-angled' }
      hero.name = 'Hero for Steve'
      sel(hero)
      v = @model.active_view
      v.camera.set(v.camera.eye.offset(Geom::Vector3d.new(11, 7, 3)),
                   v.camera.target, v.camera.up)
      hero.update(PAGE_USE_CAMERA) if defined?(PAGE_USE_CAMERA)
      nudged = cam_tuple(hero.camera)
      n_before = pages.count

      # SAME COUNT AS THE SET WAS MADE WITH, so an Update adds nothing. (Since
      # 1.56.0 a higher count ADDS scenes -- that case is 7b below.)
      ok3, msg3, = WR_AutoSet.apply(@model, b1, { 'mode' => 'update',
                                                  'renders' => WR_AutoSet::DEFAULT_RENDERS,
                                                  'reaim' => false })
      say('update.ok', ok3, msg3)
      say('update.no_new_pages', pages.count == n_before, "#{n_before} -> #{pages.count}")
      say('update.renamed_scene_not_renamed_back', hero.valid? && hero.name.to_s == 'Hero for Steve',
          hero.name.to_s)
      say('update.nudged_camera_preserved', cam_tuple(hero.camera) == nudged,
          "#{nudged.inspect} vs #{cam_tuple(hero.camera).inspect}")
      say('update.my_test_still_untouched',
          mine_pg.valid? && mine_pg.name.to_s == mine_name_at_start)

      # ------------- 7b. raising the count on an existing set (1.56.0) ----
      # A render is a scene, so Update at 2 on a set made at 1 must ADD exactly
      # one page -- the front render -- and put it in front of the front image.
      # Pages#add's index argument is documented but UNOBSERVED on this build;
      # add_page falls back to append, and apply then SAYS the set is out of
      # order. Both halves are checked separately so the log says which
      # happened.
      n_7b = pages.count
      ok3b, msg3b, = WR_AutoSet.apply(@model, b1, { 'mode' => 'update', 'renders' => 2,
                                                    'reaim' => false })
      say('update.raising_the_count_ok', ok3b, msg3b)
      say('update.raising_the_count_adds_exactly_one_scene', pages.count == n_7b + 1,
          "#{n_7b} -> #{pages.count}")
      fr_pg = WR_AutoSet.page_for_plate(pages.to_a, tok1, '02-front r')
      fi_pg = WR_AutoSet.page_for_plate(pages.to_a, tok1, '02-front')
      made_pg << fr_pg if fr_pg
      say('update.the_added_scene_is_the_front_render',
          !fr_pg.nil? && WR_ProposalPackage.mode_of(fr_pg) == 'render' &&
            fr_pg.name.to_s == "#{B1} 02-front r",
          fr_pg ? [fr_pg.name.to_s, WR_ProposalPackage.mode_of(fr_pg)].inspect : 'no 02-front r page')
      in_place = fr_pg && fi_pg && pages.to_a.index(fr_pg) == pages.to_a.index(fi_pg) - 1
      say('update.added_render_sits_before_its_image', in_place ? true : false,
          fr_pg && fi_pg ? "render at #{pages.to_a.index(fr_pg)}, image at #{pages.to_a.index(fi_pg)}" \
                         : 'page missing')
      say('update.out_of_order_is_SAID_when_it_happens',
          in_place || msg3b.to_s.include?('not in plate order'), msg3b.to_s)
      say('update.hero_still_untouched_by_the_second_update',
          hero.valid? && hero.name.to_s == 'Hero for Steve' && cam_tuple(hero.camera) == nudged)

      # ------------- 7c. lowering it again leaves the render, and says so --
      n_7c = pages.count
      ok3c, msg3c, = WR_AutoSet.apply(@model, b1, { 'mode' => 'update',
                                                    'renders' => WR_AutoSet::DEFAULT_RENDERS,
                                                    'reaim' => false })
      say('update.lowering_the_count_ok', ok3c, msg3c)
      say('update.lowering_the_count_erases_nothing',
          pages.count == n_7c && fr_pg && fr_pg.valid?, "#{n_7c} -> #{pages.count}")
      say('update.the_left_over_render_is_NAMED_in_the_summary',
          msg3c.to_s.include?('not part of this run') && msg3c.to_s.include?("#{B1} 02-front r"),
          msg3c.to_s)

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
      #
      # THE ORANGE CASE IS MANUFACTURED, NOT HOPED FOR. The check below exists
      # to prove the review grid flags a scene that is about to put an
      # UNTAGGED callout on a customer image -- the one thing the annotation
      # allowlist cannot catch, because SketchUp refuses to hide the Untagged
      # tag. On the 1.50.0 live run it reported {"loose"=>0, "warn"=>false}:
      # by then every apply had hidden both callouts model-wide, MINE had
      # never saved a hidden-object state of its own, and the condition the
      # check tests simply did not exist in the model. It failed for the right
      # reason -- but it would equally have PASSED for the wrong one if the
      # assertion had been loosened, so the fixture is what gets fixed.
      #
      # Make both callouts visible with MINE selected and save that into the
      # page, then assert loose > 0 FIRST. A fixture that did not take now
      # fails by its own name instead of quietly making the real check vacuous.
      sel(mine_pg)
      @model.start_operation('WR verify: leave a loose callout showing', true)
      loose_ents.each { |e| (e.hidden = false) if e && (e.valid? rescue false) }
      @model.commit_operation
      mine_pg.use_hidden_objects = true if mine_pg.respond_to?(:use_hidden_objects=)
      mine_pg.update(WR_SceneWalls.update_mask)

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
      say('rows.the_orange_fixture_really_shows_a_loose_callout',
          rs[mine_n]['annots']['loose'].to_i > 0, rs[mine_n]['annots'].inspect)
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
      say('add.a_page_per_plate', added == want_n, added.to_s)
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
      n_tok1 = WR_AutoSet.token_pages(pages.to_a, tok1).length   # 7 + the 7b front render
      rok, rmsg, = WR_AutoSet.apply(@model, b1, { 'mode' => 'remove' })
      say('remove.ok', rok, rmsg)
      # REMOVE TAKES EVERY STAMPED PAGE, the left-over render included. It
      # matches on TOKEN, never on plate, so it cannot leave an orphan behind.
      say('remove.only_this_booths_pages', pages.count == n_pre2 - n_tok1,
          "#{n_pre2} -> #{pages.count}, expected -#{n_tok1}")
      say('remove.my_test_survived_remove',
          mine_pg.valid? && mine_pg.name.to_s == mine_name_at_start)
      say('remove.booth_twos_set_survived',
          WR_AutoSet.token_pages(pages.to_a, tok2).length == want_2)
      say('remove.token_cleared_off_the_booth',
          b1.get_attribute('WR_AutoSet', 'token', nil).nil?)

      # ------------------------- 13. THE CAMERA ACTUALLY LANDED ----------
      #
      # THE CHECK THIS FILE WAS MISSING, AND THE REASON 1.48.0 SHIPPED WRONG.
      # rbtest-autoset.py proves aim() computes the right eye. Nothing proved
      # SketchUp KEPT it: on the create path auto-set aimed the view and let
      # `pages.add` snapshot it, never calling page.update(PAGE_USE_CAMERA),
      # and every plate came out wearing the viewport's camera instead of its
      # own. These checks read page.camera back off a freshly created set and
      # measure where the eye stands relative to the booth.
      #
      # A brand-new set is made for this on booth 1, because sections 7-11
      # have been nudging and removing the earlier ones.
      cok, cmsg, = WR_AutoSet.apply(@model, b1, { 'mode' => 'create', 'renders' => 2 })
      say('cam.fresh_set_made', cok, cmsg)
      cset = WR_AutoSet.token_pages(pages.to_a, b1.get_attribute('WR_AutoSet', 'token', nil))
      made_pg.concat(cset)
      bc, br, bbx = WR_AutoSet.booth_frame(b1)
      # THE DATUM IS THE BOOTH'S OWN FLOOR, NOT z ZERO. "A standing eye is
      # 5'-6" off the floor" is only checkable against a known floor, and the
      # 1.50.0 live run proved this fixture's was not where the check assumed
      # (see box() -- everything was built downward, booth centre z -42). Two
      # checks failed on a camera that was correct, which is exactly what
      # verify-caster-lift.rb did on 9 Sep by reading booth-local bounds. Ask
      # the booth where its own floor is and the question stops depending on
      # how the fixture happened to be extruded.
      floor = bbx.min.z.to_f
      by_plate = {}
      cset.each { |pg| by_plate[WR_AutoSet.page_stamp(pg)['plate'].to_s] = pg }

      # eye relative to the booth centre: bearing, ground run, height off zero
      shot = lambda do |id|
        c = by_plate[id] && by_plate[id].camera
        next nil unless c
        e = c.eye.to_a
        dx = e[0] - bc[0]
        dy = e[1] - bc[1]
        { 'az'    => (Math.atan2(dy, dx) * 180.0 / Math::PI),
          'run'   => Math.sqrt((dx * dx) + (dy * dy)),
          'z'     => e[2],
          'persp' => c.perspective?,
          'fov'   => (c.perspective? ? c.fov : nil) }
      end

      say('cam.every_plate_saved_a_camera',
          WR_AutoSet.plate_ids(false).all? { |id| !shot.call(id).nil? },
          by_plate.keys.inspect)

      # THE TOP-DOWN IS THE ONE PARALLEL PLATE, AND ONLY IT. Benton, 10 Sep
      # 2026: "The top down should actually be the only one in parellel
      # projection so change that too." This check used to read
      # cam.no_plate_is_parallel; that rule was REFINED by him, not abandoned,
      # so both halves are asserted rather than the check being dropped.
      flat = WR_AutoSet.plate_ids(false).reject { |id| shot.call(id)['persp'] }
      say('cam.only_the_plan_is_parallel', flat == ['06-plan'], flat.inspect)

      # THE PLATES ARE NOT ALL THE SAME SHOT. This is the 1.48.0 defect stated
      # as a check: if the aim never lands, every eye is identical.
      # THE DUAL PAIR SHARES A CAMERA BY DESIGN, so it is excluded here rather
      # than this check being weakened -- dual.identical_cameras is the one
      # that asserts the pair matches, and this one still catches the 1.48.0
      # defect (every plate wearing the viewport's camera) for everything else.
      distinct = WR_AutoSet.plate_ids(false).reject { |id| WR_AutoSet.dual_render?(id) }
      eyes = distinct.map { |id| by_plate[id].camera.eye.to_a.map { |v| v.round(1) } }
      say('cam.plates_have_DIFFERENT_cameras', eyes.uniq.length == eyes.length,
          distinct.zip(eyes).inspect)

      # THE DOOR BEARING IS A WALL NORMAL, NOT A BEARING TO THE DOOR. The
      # fixture's door is deliberately off-centre along its wall now, which is
      # the case that broke on Benton's 96120 S: the old rule returned the
      # bearing to the door's centre and swung ~30 deg off the wall. An
      # axis-aligned booth's door wall normal must land on a multiple of 90.
      # THE FRAME, NOT THE LEAF. With both tagged, the picker must still
      # return the part in the wall plane — the swung leaf is 38 in off it.
      fanch = WR_AutoSet.tag_anchor(b1, 'WR-Booth-Door')
      say('door.anchor_found', !fanch.nil?, fanch.inspect)
      # AGAINST THE SHELL, NOT THE UNION BOX. b1.bounds.min.y is -14 and that
      # is the swung leaf, not a wall: the door wall is the shell's -Y face at
      # y 24, and the frame (y 22..24, centre 23) sits 1 in proud of it. This
      # check carried the exact union-box mistake 1.54.0 took out of the
      # production code and failed a correct anchor on 1.53.0 and 1.54.0.
      shell = b1.entities.grep(Sketchup::Group).find { |g| g.name.to_s == 'shell' }
      shell_bb = shell ? shell.bounds : bbx
      wall_y = shell_bb.min.y.to_f
      say('door.anchor_is_on_the_door_wall',
          !fanch.nil? && (fanch[0][1] - wall_y).abs < 6.0,
          fanch.nil? ? 'nil' : format('frame y %.1f vs shell -Y face y %.1f (union min y %.1f is the leaf)',
                                      fanch[0][1], wall_y, b1.bounds.min.y.to_f))
      say('door.bearing_is_a_wall_normal',
          !daz.nil? && ((daz.to_f + 360.0) % 90.0).abs < 0.01,
          "#{daz.inspect} - should be a multiple of 90 on an axis-aligned booth")
      say('door.bearing_is_the_minus_Y_wall', !daz.nil? && (daz.to_f + 90.0).abs < 0.01,
          daz.inspect)

      # FRONT ON, square to the door. daz was read off the tag in section 2.
      fs = shot.call('02-front')
      fpg = by_plate['02-front']
      # SQUARE TO THE DOOR means the eye stands on the door wall's normal
      # THROUGH THE FRAME -- which is what the plate is aimed at (:aim_at =>
      # :door) and what cam.front_targets_the_door_frame asserts. This used
      # to take the bearing from the BOOTH CENTRE, and the fixture's frame is
      # 24 in off centre by design, so the centre reads -84.7 for an eye that
      # is exactly on the normal (eye x 96.0 = frame x 96.0). It contradicted
      # cam.front_is_NOT_aimed_at_the_booth_centre two checks down.
      fbear = if fpg && fanch
                Math.atan2(fpg.camera.eye.y - fanch[0][1],
                           fpg.camera.eye.x - fanch[0][0]) * 180.0 / Math::PI
              end
      say('cam.front_is_square_to_the_door',
          !daz.nil? && !fbear.nil? &&
            (((fbear - daz).abs + 180.0) % 360.0 - 180.0).abs < 1.0,
          "eye at #{fbear.nil? ? 'nil' : fbear.round(1)} deg from the frame, " \
          "door normal #{daz.to_f.round(1)} deg (from the booth centre it reads " \
          "#{fs['az'].round(1)}, which is the off-centre door, not an error)")
      say('cam.front_is_standing_height',
          (fs['z'] - floor) > 36.0 && (fs['z'] - floor) < 110.0,
          format('%.1f in above the booth floor (eye z %.1f, floor %.1f)',
                 fs['z'] - floor, fs['z'], floor))
      # IN FRONT OF THE DOOR FRAME, not in front of the booth's middle. The
      # fixture's door is off-centre along its wall, so these differ.
      fpg = by_plate['02-front']
      say('cam.front_targets_the_door_frame',
          !fanch.nil? && fpg && (fpg.camera.target.x - fanch[0][0]).abs < 2.0,
          fpg ? format('target x %.1f vs frame x %.1f', fpg.camera.target.x,
                       fanch.nil? ? -999.0 : fanch[0][0]) : 'no front page')
      say('cam.front_is_NOT_aimed_at_the_booth_centre',
          fpg && (fpg.camera.target.x - bc[0]).abs > 2.0,
          fpg ? format('target x %.1f vs booth centre x %.1f',
                       fpg.camera.target.x, bc[0]) : 'no front page')

      say('cam.front_stands_back', fs['run'] > 120.0 && fs['run'] < 400.0,
          format('%.1f in = %.1f ft back', fs['run'], fs['run'] / 12.0))

      # TOP DOWN. The eye is OVER the booth, not beside it.
      ps = shot.call('06-plan')
      say('cam.plan_is_straight_down', ps['run'] < 1.0,
          format('%.3f in off the axis', ps['run']))
      say('cam.plan_is_above_the_booth', ps['z'] > bc[2].to_f + 60.0,
          "#{ps['z'].round(1)} in vs booth centre #{bc[2].to_f.round(1)}")
      say('cam.plan_is_above_the_roof', ps['z'] > bbx.max.z.to_f,
          "#{ps['z'].round(1)} in vs roof #{bbx.max.z.to_f.round(1)}")

      # THE HIGH SHOT: same bearing as the angled one, camera lifted.
      hs = shot.call('03-high')
      as_ = shot.call('01-angled')
      say('cam.high_is_above_the_angled_shot', hs['z'] > as_['z'] + 60.0,
          "#{hs['z'].round(1)} vs #{as_['z'].round(1)}")
      say('cam.high_keeps_the_angled_bearing', (hs['az'] - as_['az']).abs < 1.0,
          "#{hs['az'].round(1)} vs #{as_['az'].round(1)}")
      say('cam.high_is_15_to_20_ft_up',
          (hs['z'] - floor) > 150.0 && (hs['z'] - floor) < 264.0,
          format('%.1f ft above the booth floor', (hs['z'] - floor) / 12.0))

      # THE VENT SHOT looks from the vent side, not the door side.
      vs = shot.call('05-ventilation')
      say('cam.ventilation_looks_from_the_vent_side',
          !vaz.nil? && (((vs['az'] - vaz).abs + 180.0) % 360.0 - 180.0).abs < 60.0,
          "eye at #{vs['az'].round(1)} deg, vent at #{vaz.to_f.round(1)} deg")

      # ---- INSIDE THE BOOTH --------------------------------------------
      # The interior plate is off by default, so it is not in cset; aim it
      # directly and read the camera the tool would have saved.
      iv = @model.active_view
      WR_AutoSet.aim_plate(iv, '07-interior', bc, br, daz, vaz,
                           [(bbx.max.x - bbx.min.x) / 2.0, (bbx.max.y - bbx.min.y) / 2.0],
                           fanch && fanch[0])
      ic = iv.camera
      idir = ic.target - ic.eye
      # A FIXED CLEARANCE OFF THE INTERIOR FACE. Benton, 10 Sep 2026: "it
      # needed to move like 2\" more inside the booth. It was kinda stuck in
      # the wall."
      # INSIDE THE SHELL -- the real one. bbx is the UNION box (y -14..86,
      # the swung leaf to the vent housing); "inside" that is not inside the
      # booth. The shell group is the booth: y 24..84. Until 1.55.0 this
      # passed an eye at y 9, 15 in outside the door wall, because the
      # production rule stood 22 in inside the union edge, i.e. the leaf.
      say('cam.interior_eye_is_inside_the_shell',
          ic.eye.x > shell_bb.min.x && ic.eye.x < shell_bb.max.x &&
            ic.eye.y > shell_bb.min.y && ic.eye.y < shell_bb.max.y,
          format('eye %s vs shell x %.1f..%.1f y %.1f..%.1f', ic.eye.to_a.inspect,
                 shell_bb.min.x.to_f, shell_bb.max.x.to_f,
                 shell_bb.min.y.to_f, shell_bb.max.y.to_f))
      iclear = (ic.eye.y - shell_bb.min.y).abs - WR_AutoSet::BOOTH_WALL_T
      # 22 in, CLAMPED AT THE BOOTH CENTRE (interior_eye_dist never crosses
      # it). The fixture's 38 in leaf drags the union centre to y 36, only 11
      # in inside the shell's interior face, so here the clamp bites and 11
      # is the right answer; the 22 itself is pinned offline (in2/in3). The
      # detail names both so a reader is not left wondering why not 22.
      iwant = [WR_AutoSet::INTERIOR_EYE_CLEAR,
               (bc[1].to_f - shell_bb.min.y.to_f) - WR_AutoSet::BOOTH_WALL_T].min
      say('cam.interior_eye_clears_the_interior_face',
          (iclear - iwant).abs < 0.51,
          format('%.2f in clear of the shell face, wants %.2f (= min(%.0f, centre-to-face %.2f))',
                 iclear, iwant, WR_AutoSet::INTERIOR_EYE_CLEAR,
                 (bc[1].to_f - shell_bb.min.y.to_f) - WR_AutoSet::BOOTH_WALL_T))
      # THE TWO-POINT PERSPECTIVE. Benton: "I like the interior camera angle.
      # Its a good feature honestly." Level direction + world-vertical up +
      # perspective is what keeps real verticals parallel on screen. Each is
      # checked separately because none of the three looks important.
      say('cam.interior_looks_dead_level', idir.z.abs < 1.0e-6, idir.to_a.inspect)
      say('cam.interior_up_is_world_vertical',
          ic.up.to_a.map { |v| v.round(6) } == [0.0, 0.0, 1.0], ic.up.to_a.inspect)
      say('cam.interior_is_perspective', ic.perspective? == true)
      say('cam.interior_keeps_its_wide_lens',
          (ic.fov - WR_AutoSet::INTERIOR_FOV).abs < 0.01, ic.fov.inspect)

      # ---- THE DUAL ANGLED PAIR, ON REAL PAGES --------------------------
      # Benton, 10 Sep 2026: "I also always want a regular image at angled,
      # and a render at angled. Should be the same scene, except with the
      # render setting."
      ang_i = by_plate['01-angled']
      ang_r = by_plate['01-angled r']
      say('dual.both_halves_exist', !ang_i.nil? && !ang_r.nil?, by_plate.keys.inspect)
      # THE WHOLE SET, IN PLATE ORDER, for the count it was made with (2).
      cst = pages.to_a.select { |p| cset.include?(p) }.map { |p| WR_AutoSet.page_stamp(p)['plate'] }
      say('dual.set_reads_angled_r_angled_front_r_front_high_side_vent_plan',
          cst == WR_AutoSet.plate_ids(false, 2) &&
            cst == ['01-angled r', '01-angled', '02-front r', '02-front', '03-high',
                    '04-side', '05-ventilation', '06-plan'],
          cst.inspect)
      say('dual.one_image_one_render',
          ang_i && ang_r &&
            WR_ProposalPackage.mode_of(ang_i) == 'image' &&
            WR_ProposalPackage.mode_of(ang_r) == 'render',
          [ang_i && WR_ProposalPackage.mode_of(ang_i),
           ang_r && WR_ProposalPackage.mode_of(ang_r)].inspect)
      # THE SAME CAMERA, read back off the two saved pages.
      say('dual.identical_cameras',
          ang_i && ang_r && cam_tuple(ang_i.camera) == cam_tuple(ang_r.camera),
          [ang_i && cam_tuple(ang_i.camera), ang_r && cam_tuple(ang_r.camera)].inspect)
      # THE SAME WALLS AND THE SAME ANNOTATIONS. They are one shot; a
      # difference between the two halves would be a defect.
      if ang_i && ang_r
        sel(ang_i)
        wi = units.count { |u| u[:pieces].all? { |g| hidden?(g) } }
        ai = tag_names_hidden(ang_i).to_a.sort
        sel(ang_r)
        wr = units.count { |u| u[:pieces].all? { |g| hidden?(g) } }
        ar = tag_names_hidden(ang_r).to_a.sort
        say('dual.identical_walls', wi == wr, "#{wi} vs #{wr}")
        say('dual.identical_annotations', ai == ar, [ai, ar].inspect)
      end
      # ADJACENT IN THE TAB BAR, RENDER FIRST. This read image-first until
      # 1.56.0; Benton, 11 Sep 2026: "the render would go IN FRONT of the
      # image. So then the 1st scene would be render angled. 2nd scene would
      # be image angled."
      say('dual.adjacent_and_render_first',
          ang_i && ang_r &&
            pages.to_a.index(ang_r) == pages.to_a.index(ang_i) - 1,
          [ang_r && pages.to_a.index(ang_r), ang_i && pages.to_a.index(ang_i)].inspect)
      # THE SECOND PAIR, the front, is the same shape and shares a camera too.
      fr_i = by_plate['02-front']
      fr_r = by_plate['02-front r']
      say('dual.front_pair_exists_at_two_renders', !fr_i.nil? && !fr_r.nil?, by_plate.keys.inspect)
      say('dual.front_pair_render_first_and_identical_camera',
          fr_i && fr_r &&
            pages.to_a.index(fr_r) == pages.to_a.index(fr_i) - 1 &&
            WR_ProposalPackage.mode_of(fr_r) == 'render' &&
            WR_ProposalPackage.mode_of(fr_i) == 'image' &&
            cam_tuple(fr_i.camera) == cam_tuple(fr_r.camera),
          [fr_r && cam_tuple(fr_r.camera), fr_i && cam_tuple(fr_i.camera)].inspect)
      # AND THE FILENAME DOES NOT DOUBLE THE MARKER.
      dn = WR_ProposalPackage.plan_names(WR_ProposalPackage.state(@model)['rows'])
      say('dual.no_doubled_render_marker',
          dn.values.none? { |f| f.to_s =~ /r\s+r\.png\z/ },
          dn.values.select { |f| f.to_s.include?(' r') }.inspect)

      # ---- ZERO RENDERS MEANS ZERO RENDERS (1.56.0) ---------------------
      # Benton, 11 Sep 2026: "When I click '0' renders, it still makes one
      # though. Lets get that situated." On real pages: a run at 0 with no
      # interior is the six image plates and NOTHING else.
      zok, zmsg, = WR_AutoSet.apply(@model, b2, { 'mode' => 'add', 'renders' => 0 })
      say('zero.run_ok', zok, zmsg)
      ztok = b2.get_attribute('WR_AutoSet', 'token', nil)
      zset = WR_AutoSet.token_pages(pages.to_a, ztok)
      made_pg.concat(zset)
      zst = pages.to_a.select { |p| zset.include?(p) }.map { |p| WR_AutoSet.page_stamp(p)['plate'] }
      say('zero.six_image_plates_and_nothing_else',
          zst == %w[01-angled 02-front 03-high 04-side 05-ventilation 06-plan],
          zst.inspect)
      say('zero.ZERO_render_rows',
          zset.none? { |pg| WR_ProposalPackage.mode_of(pg) == 'render' },
          zset.map { |pg| [WR_AutoSet.page_stamp(pg)['plate'], WR_ProposalPackage.mode_of(pg)] }.inspect)
      say('zero.summary_says_0_render', zmsg.to_s.include?('0 render /'), zmsg.to_s)
      say('zero.summary_no_longer_describes_an_always_render',
          !zmsg.to_s.include?('always-render'), zmsg.to_s)
      WR_AutoSet.apply(@model, b2, { 'mode' => 'remove' })

      # ---- THE INTERIOR IS ALWAYS A RENDER, EXTRA, NOT COUNTED ----------
      # Benton, 10 Sep 2026: "fyi interior plate should always be a render."
      # 11 Sep 2026: "No, interior is extra and always a render." Checked at a
      # render count of ZERO, which is the case most likely to break, on a run
      # that actually PRODUCES the plate: seven pages, ONE render, the interior.
      iok, imsg, = WR_AutoSet.apply(@model, b2, { 'mode' => 'add', 'renders' => 0,
                                                  'interior' => true })
      say('forced.interior_run_ok', iok, imsg)
      itok = b2.get_attribute('WR_AutoSet', 'token', nil)
      iset = WR_AutoSet.token_pages(pages.to_a, itok)
      made_pg.concat(iset)
      ipg = iset.find { |pg| WR_AutoSet.page_stamp(pg)['plate'] == '07-interior' }
      say('forced.interior_plate_exists', !ipg.nil?,
          iset.map { |pg| WR_AutoSet.page_stamp(pg)['plate'] }.inspect)
      say('forced.interior_is_a_RENDER_at_zero_renders',
          ipg && WR_ProposalPackage.mode_of(ipg) == 'render',
          ipg ? WR_ProposalPackage.mode_of(ipg) : 'no interior page')
      say('forced.interior_is_extra_and_last',
          iset.length == WR_AutoSet.plate_ids(true, 0).length &&
            pages.to_a.select { |p| iset.include?(p) }.last == ipg,
          "#{iset.length} pages, table wants #{WR_AutoSet.plate_ids(true, 0).length}")
      # AT A COUNT OF ZERO THE INTERIOR IS THE ONLY RENDER. The angled render
      # is no longer forced, so nothing else may come out as one.
      say('forced.the_interior_is_the_ONLY_render_at_zero',
          iset.select { |pg| WR_ProposalPackage.mode_of(pg) == 'render' } == [ipg],
          iset.map { |pg| [WR_AutoSet.page_stamp(pg)['plate'],
                           WR_ProposalPackage.mode_of(pg)] }.inspect)
      say('forced.summary_breaks_out_the_interior_as_not_counted',
          imsg.to_s.include?('1 render') && imsg.to_s.include?('always a render, not counted') &&
            imsg.to_s.include?('07-interior'),
          imsg.to_s)
      WR_AutoSet.apply(@model, b2, { 'mode' => 'remove' })

      # ---- THE 1.56.0 RENUMBERING OVER A 1.53-1.55 SET ------------------
      # THE HIGHEST-RISK PATH OF THE RENUMBERING. Benton has real models with
      # sets stamped 01-front / 02-angled / 02-angled r. Manufacture one out
      # of cset by rewriting three stamps and names to the old ids, then
      # Update: nothing may be duplicated, nothing called stale, the tool's own
      # old names get renumbered, and a hand-typed name stays.
      m_front = by_plate['02-front']
      m_ang   = by_plate['01-angled']
      m_angr  = by_plate['01-angled r']
      @model.start_operation('WR verify: age three stamps to 1.55', true)
      m_front.set_attribute('WR_AutoSet', 'plate', '01-front')
      m_front.name = "#{B1} 01-front"                 # the tool's own old name
      m_ang.set_attribute('WR_AutoSet', 'plate', '02-angled')
      m_ang.name = 'Old hero, hand named'             # Benton's, must survive
      m_angr.set_attribute('WR_AutoSet', 'plate', '02-angled r')
      m_angr.name = "#{B1} 02-angled r"
      @model.commit_operation
      mpl = WR_AutoSet.plan(@model, b1, { 'renders' => 2 })
      say('migrate.plan_sees_no_stale_scenes', mpl['stale'] == [], mpl['stale'].inspect)
      say('migrate.plan_flags_the_renumber_not_a_hand_rename',
          mpl['rows'].find { |r| r['plate'] == '02-front' }['renumber'] == true &&
            mpl['rows'].find { |r| r['plate'] == '02-front' }['renamed'] == false &&
            mpl['rows'].find { |r| r['plate'] == '01-angled' }['renamed'] == true,
          mpl['rows'].map { |r| [r['plate'], r['exists'], r['renumber'], r['renamed']] }.inspect)
      n_mg = pages.count
      mok, mmsg, mlines = WR_AutoSet.apply(@model, b1, { 'mode' => 'update', 'renders' => 2,
                                                          'reaim' => false })
      say('migrate.update_ok', mok, mmsg)
      say('migrate.NO_duplicate_scenes', pages.count == n_mg, "#{n_mg} -> #{pages.count}")
      say('migrate.stamps_now_carry_the_new_ids',
          WR_AutoSet.page_stamp(m_front)['plate'] == '02-front' &&
            WR_AutoSet.page_stamp(m_ang)['plate'] == '01-angled' &&
            WR_AutoSet.page_stamp(m_angr)['plate'] == '01-angled r',
          [m_front, m_ang, m_angr].map { |p| WR_AutoSet.page_stamp(p)['plate'] }.inspect)
      say('migrate.the_tools_own_names_are_renumbered',
          m_front.name.to_s == "#{B1} 02-front" && m_angr.name.to_s == "#{B1} 01-angled r",
          [m_front.name.to_s, m_angr.name.to_s].inspect)
      say('migrate.a_hand_typed_name_is_kept',
          m_ang.name.to_s == 'Old hero, hand named', m_ang.name.to_s)
      say('migrate.nothing_called_stale',
          !mmsg.to_s.include?('no longer makes'), mmsg.to_s)
      say('migrate.log_says_renumbered',
          (mlines || []).any? { |l| l.to_s.include?('renumbered') && l.to_s.include?('since 1.56.0') },
          (mlines || []).select { |l| l.to_s.include?('1.56.0') }.inspect)

      # THE BLANK-PLATE SENTENCE. This fixture DOES carry dimension entities
      # on WR-Dims, so the note must NOT fire; the model Benton ran on carried
      # none, and that is the case the note exists for.
      cnt = WR_AutoSet.tag_counts(@model, ['WR-Dims', 'WR-Dims-Doors'])
      say('cam.tag_counts_sees_the_fixture_dimensions',
          cnt['WR-Dims'].to_i > 0, cnt.inspect)
      say('cam.no_false_blank_warning',
          WR_AutoSet.blank_plates(WR_AutoSet.plate_ids(false), [], cnt) == [] ||
            !cmsg.to_s.include?('will be BLANK'),
          cmsg.to_s)
      # And with a count of zero it DOES fire, on the plates that show dims.
      # EVERY plate, because since 1.51.0 every plate shows the dimensions --
      # so on a model with none drawn, every plate is blank and says so. That
      # is the model Benton ran auto-set on in the first place.
      say('cam.blank_warning_fires_when_nothing_is_drawn',
          WR_AutoSet.blank_plates(WR_AutoSet.plate_ids(false),
                                  [{ 'name' => 'WR-Dims' }, { 'name' => 'WR-Dims-Doors' }],
                                  { 'WR-Dims' => 0, 'WR-Dims-Doors' => 0 }) ==
            WR_AutoSet.plate_ids(false),
          WR_AutoSet.blank_plates(WR_AutoSet.plate_ids(false),
                                  [{ 'name' => 'WR-Dims' }, { 'name' => 'WR-Dims-Doors' }],
                                  { 'WR-Dims' => 0, 'WR-Dims-Doors' => 0 }).inspect)

      # ------------------- 14. THE SIDE PLATE PICKS ITS SIDE (1.57.0) ---
      #
      # Benton, 11 Sep 2026: "if it can always choose the side with more to
      # look at, a window is priority, then that would be ideal". Offline,
      # sd1-sd20 prove the rule on fake parts. This proves it on REAL groups
      # with real bounds inside a real booth transformation, and that the
      # camera SketchUp saved onto 04-side actually stands on the chosen
      # side. The eye bearing is measured from the booth centre, as in
      # section 13.
      bearing = lambda do |booth, pg|
        c = pg && pg.camera
        next nil unless c
        bc0 = WR_AutoSet.booth_frame(booth)[0]
        e = c.eye.to_a
        Math.atan2(e[1] - bc0[1], e[0] - bc0[0]) * 180.0 / Math::PI
      end
      wrap = lambda { |d| ((d + 180.0) % 360.0) - 180.0 }
      side_of = lambda do |booth|
        tk = booth.get_attribute('WR_AutoSet', 'token', nil)
        WR_AutoSet.token_pages(pages.to_a, tk).find do |pg|
          WR_AutoSet.page_stamp(pg)['plate'].to_s == '04-side'
        end
      end

      # BOOTH 1 HAS NO WINDOW ON EITHER SIDE (a shell, a door, a leaf and a
      # vent, nothing in the side walls at all): the choice is a tie, the
      # side plate stays at door +90, and the log says it is unchanged. This
      # is every booth that predates 1.57.0 and it MUST NOT MOVE.
      p1 = WR_AutoSet.side_choice(b1, WR_AutoSet.tag_anchor(b1, 'WR-Booth-Door'))
      say('side.no_window_is_a_tie_and_says_so',
          p1['sign'] == 1 && p1['why'].to_s.include?('+90 as before'), p1.inspect)
      s1 = bearing.call(b1, side_of.call(b1))
      say('side.no_window_keeps_door_plus_90',
          !s1.nil? && !daz.nil? && wrap.call(s1 - (daz + 90.0)).abs < 1.0,
          "side eye at #{s1.inspect}, door at #{daz.inspect}")
      WR_AutoSet.apply(@model, b1, { 'mode' => 'remove' })

      # BOOTH 3 CARRIES A WINDOW PANEL ON ITS DOOR -90 SIDE. The parts read
      # off the real group, the window is seen in the -X wall, the pick is
      # -1 because of it, the saved camera stands there, the plate's own log
      # line names the window, and a re-run makes the same choice.
      @model.start_operation('WR verify: booth 3', true)
      b3 = make_booth(@model.entities, B3, 24.0, 220.0, true)
      @model.commit_operation
      made << b3
      parts3 = WR_AutoSet.booth_parts(b3)
      say('side.booth_parts_sees_the_window_in_the_minus_x_wall',
          parts3.any? { |pt| pt['name'].to_s =~ /WDO/ && pt['wall'] == [-1.0, 0.0] },
          parts3.inspect)
      say('side.booth_parts_skips_the_door_tagged_parts',
          parts3.none? { |pt| pt['name'].to_s =~ /door/i }, parts3.inspect)
      dan3 = WR_AutoSet.tag_anchor(b3, 'WR-Booth-Door')
      say('side.anchor_carries_the_local_door_normal',
          dan3.is_a?(Array) && dan3[2] == [0.0, -1.0], dan3.inspect)
      p3 = WR_AutoSet.side_choice(b3, dan3)
      say('side.window_side_is_chosen',
          p3['sign'] == -1 && p3['why'].to_s.include?('window') &&
            p3['why'].to_s.include?('46Panel3236WDO'),
          p3.inspect)
      sok, smsg, slines = WR_AutoSet.apply(@model, b3, { 'mode' => 'create', 'renders' => 0 })
      say('side.window_booth_set_made', sok, smsg)
      b3set = WR_AutoSet.token_pages(pages.to_a, b3.get_attribute('WR_AutoSet', 'token', nil))
      made_pg.concat(b3set)
      daz3 = WR_AutoSet.tag_az(b3, 'WR-Booth-Door')
      s3 = bearing.call(b3, side_of.call(b3))
      say('side.camera_stands_on_the_window_side',
          !s3.nil? && !daz3.nil? && wrap.call(s3 - (daz3 - 90.0)).abs < 1.0,
          "side eye at #{s3.inspect}, door at #{daz3.inspect}")
      sline = (slines || []).find { |l| l.to_s.include?('side: door') }
      say('side.log_names_the_window_and_the_hand',
          !sline.nil? && sline.include?('door -90') && sline.include?('46Panel3236WDO'),
          sline.inspect)
      say('side.log_line_sits_under_the_side_plate',
          (slines || []).index { |l| l.to_s.include?('side: door') }.to_i >
            (slines || []).index { |l| l.to_s.include?('04-side') }.to_i,
          (slines || []).select { |l| l.to_s.include?('04-side') || l.to_s.include?('side: door') }.inspect)
      # DETERMINISTIC: Update with re-aim lands on the same side.
      WR_AutoSet.apply(@model, b3, { 'mode' => 'update', 'renders' => 0, 'reaim' => true })
      s3b = bearing.call(b3, side_of.call(b3))
      say('side.same_side_on_a_re_run',
          !s3b.nil? && !s3.nil? && wrap.call(s3b - s3).abs < 1.0,
          "#{s3.inspect} then #{s3b.inspect}")
      WR_AutoSet.apply(@model, b3, { 'mode' => 'remove' })

      # ---- 15. A ROOM SHAPED LIKE BENTON'S, MOVED; A BOOTH WITH SPLIT VENTS
      #
      # Both 11 Sep 2026 defects on one fixture, because they interact:
      # "I had a backshot, and it didnt hide the wall that was right behind
      # it" and "the ventilation scene also doesnt really go 'back' ... there
      # is one vent set on the side, but there are 3 on the back". Room >
      # Walls > Wall N carrying a translation (roomx.*), and a booth inside
      # it with three vents on +Y and one on +X (vent.*). Its vent plate
      # must anchor on +Y, swing toward +X, and STILL hide Wall 2 behind the
      # three vents. Booth 1 -- a single vent -- is checked to be unchanged.
      #
      # Booth placement: the union box centre (what the cone measures from)
      # sits ~12 in above the shell's oy because the swung leaf reaches
      # oy-38 and the vents oy+62; oy is chosen so that centre is a hair
      # BELOW Wall 4's centre line, keeping Wall 4 (behind the single vent)
      # cleanly outside the 60-degree cone at a 65-degree eye. It is not in
      # the way of the shot and it must stay up.
      rx = 600.0
      ry = 400.0
      @model.start_operation('WR verify: moved room + split-vent booth', true)
      room2 = make_room_moved(@model.entities, rx, ry)
      b4 = make_booth(@model.entities, B4, rx + 72.0, ry + 74.0, false, true)
      @model.commit_operation
      made.concat([room2, b4])

      units2 = WR_SceneWalls.scan(@model)[:walls].select { |u| u[:room].to_s == ROOM2 }
      say('roomx.four_walls_found_under_Room_Walls',
          units2.map { |u| u[:wall] }.sort == [1, 2, 3, 4],
          units2.map { |u| [u[:room], u[:wall]] }.inspect)
      w2 = units2.find { |u| u[:wall] == 2 }        # +Y, local y 188..192
      w1 = units2.find { |u| u[:wall] == 1 }        # -Y, the far wall
      w4 = units2.find { |u| u[:wall] == 4 }        # +X, behind the single vent
      say('roomx.wall_centre_is_in_MODEL_space',
          w2 && w2[:centre].is_a?(Array) &&
            (w2[:centre][1] - (ry + 190.0)).abs < 1.0 &&
            (w2[:centre][0] - (rx + 120.0)).abs < 1.0,
          "Wall 2 centre #{w2 && w2[:centre].inspect}, wants ~[#{rx + 120.0}, #{ry + 190.0}, 48]")
      say('roomx.local_bounds_would_have_been_wrong',
          w2 && (w2[:pieces][0].bounds.center.y.to_f - 190.0).abs < 1.0,
          "the piece's own bounds read y #{w2 && w2[:pieces][0].bounds.center.y.to_f} (parent space)")
      geo2 = WR_AutoSet.wall_geometry(@model).select { |u| u['room'] == ROOM2 }
      say('roomx.wall_geometry_carries_the_model_centre',
          geo2.any? { |u| u['wall'] == 2 && (u['c'][1] - (ry + 190.0)).abs < 1.0 },
          geo2.map { |u| [u['wall'], u['c']] }.inspect)

      vparts = WR_AutoSet.vent_parts(b4)
      say('vent.parts_read_off_the_real_booth',
          vparts.count { |pt| pt['wall'] == [0.0, 1.0] } == 3 &&
            vparts.count { |pt| pt['wall'] == [1.0, 0.0] } == 1,
          vparts.inspect)
      dan4 = WR_AutoSet.tag_anchor(b4, 'WR-Booth-Door')
      vc4  = WR_AutoSet.vent_choice(b4, dan4)
      say('vent.primary_is_the_wall_with_three',
          vc4['ax'] == [0.0, 1.0] && vc4['n'] == 3 && !vc4['az'].nil? &&
            (vc4['az'].to_f - 90.0).abs < 1.0,
          vc4.inspect)
      say('vent.shift_is_toward_the_single_vent',
          vc4['sec'] == [1.0, 0.0] && vc4['shift'] == -1, vc4.inspect)
      vc1 = WR_AutoSet.vent_choice(b1, WR_AutoSet.tag_anchor(b1, 'WR-Booth-Door'))
      say('vent.single_vent_booth_is_unchanged',
          vc1['shift'] == 1 && vc1['sec'].nil? && !vc1['az'].nil? &&
            !vaz.nil? && (vc1['az'].to_f - vaz.to_f).abs < 1.0 &&
            vc1['why'].to_s.include?('as before'),
          vc1.inspect)

      ok4, msg4, lines4 = WR_AutoSet.apply(@model, b4, { 'mode' => 'create', 'renders' => 0 })
      say('roomx.set_made', ok4, msg4)
      lines4 ||= []
      tok4 = b4.get_attribute('WR_AutoSet', 'token', nil)
      set4 = WR_AutoSet.token_pages(pages.to_a, tok4)
      made_pg.concat(set4)
      vent_pg = lambda do
        WR_AutoSet.token_pages(pages.to_a, tok4).find do |pg|
          WR_AutoSet.page_stamp(pg)['plate'].to_s == '05-ventilation'
        end
      end
      vpg = vent_pg.call
      say('roomx.ventilation_plate_exists', !vpg.nil?, set4.map { |pg| pg.name.to_s }.inspect)
      vb = vpg && bearing.call(b4, vpg)
      say('vent.camera_anchors_on_the_three_vent_wall',
          !vb.nil? && wrap.call(vb - 65.0).abs < 1.5,
          "eye at #{vb.inspect} deg, wants 90 - 25 = 65")
      say('vent.camera_swings_toward_the_single_vent',
          !vb.nil? && wrap.call(vb - 90.0) < 0.0 && wrap.call(vb - 90.0) > -60.0,
          "eye at #{vb.inspect} deg; +X (the single vent) is at 0")
      if vpg
        sel(vpg)
        say('roomx.ventilation_hides_the_wall_behind_the_vents',
            w2 && w2[:pieces].all? { |g| hidden?(g) },
            "Wall 2 pieces hidden: #{w2 && w2[:pieces].map { |g| hidden?(g) }.inspect}")
        say('roomx.ventilation_leaves_the_far_wall_standing',
            w1 && w1[:pieces].none? { |g| hidden?(g) })
        say('vent.wall_behind_the_single_vent_stays_up',
            w4 && w4[:pieces].none? { |g| hidden?(g) },
            'Wall 4 is at 65 deg off the eye, outside the 60-degree cone')
      end
      say('roomx.log_counts_the_wall_units',
          lines4.any? { |l| l.to_s.include?('wall unit(s) the cone rule can hide') &&
                            l.to_s.include?("#{ROOM2}: Wall 1, 2, 3, 4") },
          lines4.find { |l| l.to_s.include?('walls:') }.inspect)
      say('roomx.log_hides_wall_2_by_name',
          lines4.any? { |l| l.to_s.include?("hides #{ROOM2} Wall 2") },
          lines4.select { |l| l.to_s.include?('hides ') }.inspect)
      vline = lines4.find { |l| l.to_s.include?('vent: anchored') }
      say('vent.log_names_the_walls_and_the_swing',
          !vline.nil? && vline.include?('swung -25') && vline.include?('3 (N0  40VNT') &&
            vline.include?('against 1 on') && vline.include?('E0  40VNT'),
          vline.inspect)
      say('vent.log_line_sits_under_the_vent_plate',
          lines4.index { |l| l.to_s.include?('vent: anchored') }.to_i >
            lines4.index { |l| l.to_s.include?('05-ventilation') }.to_i,
          lines4.select { |l| l.to_s.include?('05-ventilation') || l.to_s.include?('vent: anchored') }.inspect)
      # DETERMINISTIC: Update with re-aim lands on the same wall and hand.
      WR_AutoSet.apply(@model, b4, { 'mode' => 'update', 'renders' => 0, 'reaim' => true })
      vb2 = vent_pg.call && bearing.call(b4, vent_pg.call)
      say('vent.same_choice_on_a_re_run',
          !vb2.nil? && !vb.nil? && wrap.call(vb2 - vb).abs < 1.0,
          "#{vb.inspect} then #{vb2.inspect}")
      WR_AutoSet.apply(@model, b4, { 'mode' => 'remove' })

      # THE EMPTY CASE IS SAID OUT LOUD: what the rule wanted, what it saw.
      wl0 = WR_AutoSet.walls_line([], WR_AutoSet.top_level_names(@model))
      say('roomx.no_units_is_said_out_loud',
          wl0.include?('NO wall units') && wl0.include?('"Wall 1"') &&
            wl0.include?(B4) && wl0.include?(ROOM2),
          wl0)

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
                      nm == 'Old hero, hand named' ||
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
