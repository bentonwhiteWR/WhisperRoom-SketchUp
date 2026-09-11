# @title Hide walls per scene...
# @cat Scenes and images
# @rank 5
#
# Pick which WHOLE walls are hidden on the scene you are looking at. Click a
# scene tab, move walls between the two groups — "Shown in this scene" and
# "HIDDEN in this scene" — hit Apply, and that scene remembers. Click the
# next scene tab and the walls come back, because that scene remembered its
# own answer. Benton, 2026-08-31: "we need to be sure that we can 'hide a
# wall' in the proposal package. Not half a wall, an entire one."
#
# HOW IT ACTUALLY WORKS, because the mechanism is not obvious and getting it
# wrong here would mean walls leaking between proposal images:
#
#   A SketchUp scene saves PER-ENTITY hidden state, nested groups included.
#   Verified live (31 Aug 2026, SketchUp 2026): hide the "Wall 2" groups
#   inside a room's Walls container, page.update, and selecting another
#   scene shows them while coming back hides them again. So hiding a wall
#   per scene needs NO per-wall tags and no exporter cooperation — the scene
#   itself carries it, and proposal-package.rb picks it up for free because
#   it selects each scene before exporting it.
#
#   Apply saves ONLY the hidden state into the scene:
#   page.update(PAGE_USE_HIDDEN_OBJECTS | PAGE_USE_HIDDEN_GEOMETRY). The
#   camera you may have orbited since selecting the scene is NOT saved —
#   verified live that the page camera is untouched by that mask.
#
# WHY THE TWO GROUPS ARE LISTS IN THIS DIALOG AND NOT TWO CONTAINER GROUPS
# IN THE OUTLINER. Benton asked for walls "grouped in 'walls - Shown' /
# 'walls - hidden'". A scene does not remember which container an entity
# lives in — parentage is global — so two physical groups could only hold
# ONE answer for the whole model, not one per scene. The hidden flag is the
# thing scenes do remember, so the two groups live here as the two columns,
# and the Outliner still tells the truth at a glance: a hidden wall shows
# greyed out on the scene that hides it.
#
# WHAT COUNTS AS "AN ENTIRE WALL". build-room.rb / build-takeoff.rb name
# every piece after its wall run: "Wall 3", "Header 3", "Opening 3",
# "Door leaf 3", "Swing 3" — plus "Wall 3 (upper)" in a legacy model built
# before the two-band split was removed on 31 Aug 2026. One wall in this
# dialog is ALL of those pieces for one run of one room, so hiding it never
# strands a door leaf floating in space where its wall used to be. Rooms drawn by hand or
# by an older script have no such names — run "Name walls for the scene
# picker" (wr-name-walls.rb) once and they appear here too.
#
# THE SELECTION FALLBACK at the bottom exists for everything the naming
# convention does not cover: select any group(s) in the model and hide or
# show exactly those in the current scene. Same mechanism, no names needed.
#
# A SCENE THAT DOES NOT SAVE HIDDEN OBJECTS cannot put walls back when it
# is selected — walls hidden elsewhere would stay hidden on it. Scenes save
# that property by default; any that have it switched off are named in a
# banner with a one-click fix.
#
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/wr-scene-walls.rb"

require 'sketchup.rb'
require 'json'

module WR_SceneWalls
  PIECE_RE = /\A(Wall|Header|Opening|Door leaf|Swing) (\d+)(\s|\z)/
  DEPTH    = 2   # room -> Walls/Doors -> piece is 2; hand-named walls may sit at 1

  # ------------------------------------------------------------- mechanism --

  # The scene-property mask Apply saves. 2020+ splits hidden state into
  # geometry and objects (groups are objects); the legacy PAGE_USE_HIDDEN is
  # the fallback for anything older. Values observed live in SketchUp 2026:
  # 128 | 256.
  def self.update_mask
    m = 0
    m |= PAGE_USE_HIDDEN_OBJECTS  if defined?(PAGE_USE_HIDDEN_OBJECTS)
    m |= PAGE_USE_HIDDEN_GEOMETRY if defined?(PAGE_USE_HIDDEN_GEOMETRY)
    m = PAGE_USE_HIDDEN if m.zero? && defined?(PAGE_USE_HIDDEN)
    m
  end

  # Scenes that will NOT restore walls when selected, by name.
  def self.pages_not_saving_hidden(model)
    model.pages.to_a.select do |pg|
      pg.respond_to?(:use_hidden_objects?) && !pg.use_hidden_objects?
    end.map { |pg| pg.name.to_s }
  rescue StandardError
    []
  end

  # ------------------------------------------------------------- inventory --

  # Walk a room's subtree for named pieces. A group whose name matches the
  # piece pattern is a piece; anything else descends until DEPTH.
  #
  # `tr` is the transformation that carries a piece's PARENT space out to
  # MODEL space -- the room's own transformation, times every container's
  # between the room and the piece -- and it is handed to the block as a
  # fourth argument. It exists because a nested group's #bounds is reported
  # in its parent's space, not the model's (the same trap side_of names
  # below). Blocks that only want (g, kind, n) still work: Ruby drops the
  # extra argument.
  def self.each_piece(ents, depth = 0, tr = nil, &blk)
    ents.grep(Sketchup::Group).each do |g|
      nm = g.name.to_s
      if nm =~ PIECE_RE
        blk.call(g, Regexp.last_match(1), Regexp.last_match(2).to_i, tr)
      elsif depth < DEPTH
        each_piece(g.entities, depth + 1, compose(tr, g.transformation), &blk)
      end
    end
  end

  # parent * child: the child's transformation carried out through its
  # parent's. nil on either side means identity.
  def self.compose(parent, child)
    return child if parent.nil?
    return parent if child.nil?
    parent * child
  rescue StandardError
    parent
  end

  # The MODEL-space centre of a wall's solids, as [x, y, z].
  #
  # THIS IS WHAT THE CAMERA CONE NEEDS AND DID NOT HAVE (1.57.1). A nested
  # group's #bounds is in its PARENT'S space -- so a wall inside Room > Walls
  # reports where it sits relative to the Room group, and a Room that has
  # been MOVED (or built by build-takeoff.rb at a GAP offset) puts every one
  # of its walls somewhere else in the model than its bounds say. The cone
  # rule in wr-autoset.rb compared those local centres against a booth
  # centre and a camera eye that are in model space, and on Benton's model
  # (11 Sep 2026, "it didnt hide the wall that was right behind it") found
  # no wall in the cone on any of ten plates. The fixture room in
  # verify-autoset.rb sits at the origin with an identity transformation,
  # which is the one case where local and model space agree -- so every
  # harness check passed.
  #
  # Each solid's eight bounding corners are carried out through `trs[i]`
  # (each_piece's parent-to-model transformation for that piece) and the
  # box of all of them is taken; the centre of that box is exact under any
  # affine transformation, rotation included. nil when nothing could be
  # read, and the caller falls back to the old local read rather than
  # dropping the wall.
  def self.model_centre(pieces, trs)
    bb = Geom::BoundingBox.new
    pieces.each_with_index do |g, i|
      next unless g.valid?
      tr = trs[i]
      b  = g.bounds
      8.times { |k| bb.add(tr ? b.corner(k).transform(tr) : b.corner(k)) }
    end
    return nil unless bb.valid?
    bb.center.to_a.map { |v| v.to_f }
  rescue StandardError
    nil
  end

  # Compass hint for a wall, relative to its room's own bounding box. A HINT
  # only — it assumes the intermediate containers (Walls, Doors) carry an
  # identity transform, which is what the build tools produce, and returns ''
  # rather than guess when the wall sits at the middle. Both centers are
  # taken in ROOM-LOCAL space: room.bounds is in MODEL space, and comparing
  # the two made every wall of an offset room read "south" (observed live,
  # 31 Aug 2026, on the take-off rooms built at GAP offsets).
  def self.side_of(room, wall_pieces)
    rb = Geom::BoundingBox.new
    room.entities.each { |e| rb.add(e.bounds) }
    c = rb.center
    b = Geom::BoundingBox.new
    wall_pieces.each { |g| b.add(g.bounds) }
    v = b.center - c
    return '' if v.length < 6.0
    if v.x.abs > v.y.abs
      v.x > 0 ? 'east' : 'west'
    else
      v.y > 0 ? 'north' : 'south'
    end
  rescue StandardError
    ''
  end

  # Every whole wall the model knows by name, one entry per (room, run).
  # Fills @units — key => { :pieces, :wall_pieces, ... } — which apply() uses
  # so the dialog can reference a wall without trusting a display string.
  # `hidden` is the state of the wall BANDS (a wall with a door has no lower
  # band under the header; the header rides along). `mixed` says the bands
  # disagree with each other — Apply self-heals it either way.
  # ONE SCAN, TWO LISTS, ONE @units. Every caller goes through here so the
  # key index is built exactly once — calling inventory and then an object
  # scan separately would reset @units and strand half the keys.
  #
  #   { :walls   => [wall unit, ...],     the named Wall/Header/Door pieces
  #     :objects => [object unit, ...] }  everything else at the top level
  def self.scan(model)
    @units = {}
    # Sequenced on purpose, not written as one hash literal: object_units
    # reads the @wall_rooms set that wall_units fills, and leaning on
    # left-to-right evaluation of hash values to enforce that is the kind of
    # ordering dependency that survives until someone reformats the line.
    walls = wall_units(model)
    { :walls => walls, :objects => object_units(model) }
  end

  # Unchanged contract for every existing caller (proposal-package.rb called
  # this before objects existed): the walls, and @units freshly built.
  def self.inventory(model)
    scan(model)[:walls]
  end

  def self.wall_units(model)
    @wall_rooms = {}
    out = []
    roots = model.entities.grep(Sketchup::Group)
    roots.each do |room|
      per_run = Hash.new { |h, k| h[k] = { :wall => [], :extra => [], :wtr => [] } }
      room_tr = (room.transformation rescue nil)
      each_piece(room.entities, 0, room_tr) do |g, kind, n, tr|
        if kind == 'Wall'
          per_run[n][:wall] << g
          per_run[n][:wtr]  << tr
        else
          per_run[n][:extra] << g
        end
      end
      next if per_run.values.all? { |u| u[:wall].empty? }
      label = room.name.to_s.strip
      label = 'unnamed room' if label.empty?
      per_run.keys.sort.each do |n|
        u = per_run[n]
        next if u[:wall].empty?
        key   = "#{room.entityID}:#{n}"
        states = u[:wall].map { |g| g.hidden? }
        unit  = { :key => key, :room => label, :wall => n,
                  :side => side_of(room, u[:wall]),
                  :hidden => states.all?,
                  :mixed => states.uniq.size > 1,
                  # The wall BANDS only, in MODEL space: the door leaf and its
                  # swing are :extra and would drag the centre into the room.
                  :centre => model_centre(u[:wall], u[:wtr]),
                  :pieces => u[:wall] + u[:extra] }
        @units[key] = unit
        out << unit
        # This room is spoken for: object_units must not list it again, or
        # the same container gets two rows with two different answers.
        @wall_rooms[room.entityID] = true
      end
    end
    out
  end

  # ------------------------------------------------------------- objects --
  #
  # THE BOOTH IS A GROUP, NOT A COMPONENT INSTANCE. Observed 10 Sep 2026 in
  # Entity Info with Benton's booth selected: header "Group (1 in model)",
  # Instance "MDL 96120 E (components)", Tag Untagged. So the filter here is
  # NOT the entity type — it is "a top-level container that is not already a
  # wall row". Both Sketchup::Group and Sketchup::ComponentInstance qualify;
  # filtering on type would have listed nothing useful and missed the exact
  # object he was pointing at.
  #
  # TOP LEVEL ONLY, and that is a correctness rule, not laziness. A container
  # nested inside a ComponentDefinition is PART of that definition, so hiding
  # it hides it in every placement of the parent — a model-wide change
  # wearing a per-scene costume. Nested containers stay reachable through the
  # selection buttons, and both dialogs say so on screen.
  #
  # A room that produced wall rows is excluded: its walls are already listed
  # piece by piece, and a row hiding the whole room on top of them would be
  # two controls fighting over one set of entities.

  # The name a person would call this thing. Instance name first — that is
  # what Entity Info shows and what the build tools set — then the definition
  # name, then nothing, and the caller decides what "nothing" reads as.
  def self.object_name(e)
    nm = (e.name.to_s.strip rescue '')
    return nm unless nm.empty?
    (e.definition.name.to_s.strip rescue '')
  rescue StandardError
    ''
  end

  def self.object_unit(key, label, items)
    states = items.map { |e| ((e.hidden? rescue false) ? true : false) }
    unit = { :key => key, :kind => 'object', :label => label,
             :count => items.size, :hidden => states.all?,
             :mixed => states.uniq.size > 1, :pieces => items }
    @units[key] = unit
    unit
  end

  # Objects grouped BY NAME, so three things called "Task chair" are one row
  # that hides all three and SAYS it is three. Unnamed containers are NOT
  # collapsed together — one tick hiding every nameless thing in the model is
  # exactly the silent over-reach this picker forbids — so each gets its own
  # row carrying its entity id, which is the only thing telling them apart.
  def self.object_units(model)
    named = {}
    order = []
    solo  = []
    model.entities.each do |e|
      next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      next if @wall_rooms && @wall_rooms[e.entityID]
      nm = object_name(e)
      if nm.empty?
        solo << e
      else
        order << nm unless named.key?(nm)
        (named[nm] ||= []) << e
      end
    end
    out = order.sort_by { |n| n.downcase }.map do |nm|
      object_unit("o:n:#{nm}", nm, named[nm])
    end
    solo.each do |e|
      what = e.is_a?(Sketchup::ComponentInstance) ? 'component' : 'group'
      out << object_unit("o:e:#{e.entityID}", "unnamed #{what} ##{e.entityID}", [e])
    end
    out
  end

  # What a row calls itself, for the SHOW ME message. The one place a unit
  # becomes words, so two dialogs cannot describe the same row differently.
  def self.unit_label(u)
    return "#{u[:room]} Wall #{u[:wall]}" unless u[:kind] == 'object'
    u[:count].to_i > 1 ? "#{u[:label]} (#{u[:count]})" : u[:label].to_s
  end

  # ------------------------------------------------- pick it in the model --
  #
  # "Wall 4" means nothing until you have gone digging for it (Benton, 1 Sep
  # 2026). So the picker works the other way round too: click the wall in the
  # viewport and let the model say which one it is, or click a row and have
  # the model show you.
  #
  # Both directions match on ENTITY IDs through the containment tree, because
  # what the operator has selected is rarely the exact group the inventory
  # holds — clicking once selects the room or the Walls container, and
  # double-clicking in selects something under the wall.

  # Every entity id at or under ent, to a sane depth.
  def self.subtree_ids(ent, out = {}, depth = 0)
    out[ent.entityID] = true
    return out if depth > 5
    ents = nil
    ents = ent.entities if ent.respond_to?(:entities)
    ents = ent.definition.entities if ents.nil? && ent.respond_to?(:definition)
    (ents || []).each do |c|
      next unless c.is_a?(Sketchup::Group) || c.is_a?(Sketchup::ComponentInstance)
      subtree_ids(c, out, depth + 1)
    end
    out
  rescue StandardError
    out
  end

  # Wall keys the current model selection points at. Empty is a real answer
  # and the caller says so rather than guessing.
  def self.keys_for_selection(model)
    return [] unless @units
    sel = model.selection.to_a.select do |e|
      e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    end
    return [] if sel.empty?
    raw = {}
    sel.each { |e| raw[e.entityID] = true }
    under = {}
    sel.each { |e| subtree_ids(e, under) }
    hits = []
    @units.each do |key, u|
      u[:pieces].each do |g|
        next unless g.valid?
        # selected the wall, the Walls container or the whole room ...
        hit = under[g.entityID]
        # ... or picked something inside the wall.
        hit ||= subtree_ids(g).keys.any? { |id| raw[id] }
        if hit
          hits << key
          break
        end
      end
    end
    hits.uniq
  end

  # The other direction: show me which one Wall 4 is.
  def self.reveal(model, key)
    u = @units && @units[key]
    return [false, 'that wall is stale — hit Refresh'] unless u
    live = u[:pieces].select { |g| g.valid? }
    return [false, 'that wall is no longer in the model'] if live.empty?
    model.selection.clear
    model.selection.add(live)
    begin
      model.active_view.zoom(live)
    rescue StandardError
      nil                       # zoom is a nicety; the selection is the point
    end
    [true, "#{unit_label(u)} selected in the model."]
  end

  # --------------------------------------------------------------- apply --

  # Set the hidden flag on every piece of every named wall, then save ONLY
  # the hidden state into the currently selected scene. picks is
  # { key => true(hide) / false(show) }. Returns [ok, message].
  def self.apply(model, picks)
    page = model.pages.selected_page
    return [false, 'No scene is selected — this model has no scenes, or none is active. ' \
                   'Create/select a scene first; there is nothing to save into.'] unless page
    return [false, 'Nothing to apply.'] if picks.nil? || picks.empty?
    before = snapshot_keys(picks.keys)   # UNDO LAST APPLY (1.26.1)
    model.start_operation('Hide walls per scene', true)
    begin
      r = write_scene(page, picks)
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      return [false, "Apply failed and was rolled back: #{e.class}: #{e.message}"]
    end
    remember_write(model, 'wall', [{ :page => page, :name => page.name.to_s, :before => before }])
    msg = "Saved to scene \"#{page.name}\" — #{r[:changed]} piece(s) set."
    msg += " #{r[:gone].size} wall(s) were stale and skipped — hit Refresh." unless r[:gone].empty?
    off = pages_not_saving_hidden(model)
    unless off.empty?
      msg += " WARNING: scene(s) not saving hidden objects (walls will NOT " \
             "come back on them): #{off.join(', ')}."
    end
    [true, msg]
  end

  # The write itself, with NO transaction of its own — the caller owns the
  # operation, which is what lets apply_all put every scene under ONE undo
  # instead of one per scene. Flags every piece per picks, makes sure the
  # page will re-assert hidden objects, then snapshots into the page.
  #
  # Call it only with `page` SELECTED. page.update records the model's
  # hidden state as it stands, and selecting the page is what restores that
  # scene's own state for everything that is NOT a row here (geometry hidden
  # by hand, say). Writing into an unselected page would stamp the current
  # scene's hidden state on it for all of those — silently.
  def self.write_scene(page, picks)
    gone = []
    changed = 0
    picks.each do |key, hide|
      unit = @units && @units[key]
      unless unit
        gone << key
        next
      end
      unit[:pieces].each do |g|
        next unless g.valid?
        g.hidden = hide ? true : false
        changed += 1
      end
    end
    # Make sure this scene will re-assert what we are about to save.
    if page.respond_to?(:use_hidden_objects=) &&
       page.respond_to?(:use_hidden_objects?) && !page.use_hidden_objects?
      page.use_hidden_objects = true rescue nil
    end
    page.update(update_mask)
    saves = !(page.respond_to?(:use_hidden_objects?) && !page.use_hidden_objects?)
    { :changed => changed, :gone => gone, :saves => saves }
  end

  # The SAME picks into every page given (default: every scene in the
  # model), one operation. NOT undoable: page.update is outside SketchUp's
  # undo stack (Benton, 10 Sep 2026: "It said I could ctrl+z and that didnt
  # work"; the API's only undo note on Page covers Axes/Camera/
  # RenderingOptions/ShadowInfo, 2026.0+). Ctrl+Z reverts the pieces'
  # hidden FLAGS and leaves every snapshot as written, which the next scene
  # click re-asserts — it looks like nothing happened. Benton, 10 Sep 2026: "would like for
  # there to be an 'apply to all scenes' button as well."
  #
  # This overwrites the saved wall answer of every scene it touches — scenes
  # the operator set up earlier and is not looking at included — so callers
  # CONFIRM first (confirm_all?) and this method does not; it is mechanism.
  # Each page is selected before it is written, for the reason on
  # write_scene, and the operator is put back on the scene they started on.
  # Returns [ok, message, { :written => [names], :unsaved => [names] }] —
  # :unsaved are pages that still refuse to save hidden objects after the
  # write, so walls will NOT come back on them and the caller must name them.
  def self.apply_all(model, picks, pages = nil)
    pages = (pages || model.pages.to_a).select { |pg| pg && pg.valid? }
    return [false, 'No scenes to write into.'] if pages.empty?
    return [false, 'Nothing to apply.'] if picks.nil? || picks.empty?
    start   = model.pages.selected_page
    written = []
    unsaved = []
    gone    = []
    entries = []                          # UNDO LAST APPLY (1.26.1)
    model.start_operation('Hide walls on every scene', true)
    begin
      pages.each do |pg|
        model.pages.selected_page = pg
        entries << { :page => pg, :name => pg.name.to_s, :before => snapshot_keys(picks.keys) }
        r = write_scene(pg, picks)
        written << pg.name.to_s
        unsaved << pg.name.to_s unless r[:saves]
        gone |= r[:gone]
      end
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      restore_page(model, start)
      return [false, 'Apply to every scene failed and was rolled back: ' \
                     "#{e.class}: #{e.message}"]
    end
    remember_write(model, 'wall', entries)
    restore_page(model, start)
    msg = "Saved to #{written.size} scene(s). Ctrl+Z will NOT put them back — " \
          'UNDO LAST APPLY will.'
    msg += " #{gone.size} wall(s) were stale and skipped — hit Refresh." unless gone.empty?
    unless unsaved.empty?
      msg += " WARNING: scene(s) not saving hidden objects (walls will NOT " \
             "come back on them): #{unsaved.join(', ')}."
    end
    [true, msg, { :written => written, :unsaved => unsaved }]
  end

  # ---- UNDO LAST APPLY (1.26.1) -------------------------------------------
  #
  # Ctrl+Z cannot reverse a scene write — page.update is outside SketchUp's
  # undo stack (1.25.2; Benton: "It said I could ctrl+z and that didnt
  # work"). So every apply RECORDS what it is about to overwrite, and this
  # puts it back. The record is one entry per written page: the page, its
  # name, and a snapshot of every written key taken with that page SELECTED
  # (the same read the picker shows), so putting it back is the write path
  # with yesterday's answer — nothing new is trusted.
  #
  # ONE step, this SketchUp session, this model. It lives on the module, so
  # it survives closing a picker, the proposal package window, and a script
  # reload; it does not survive SketchUp closing, a newer apply replaces it,
  # and putting it back uses it up. Not covered: the selection buttons
  # (apply_selection), which write whatever is selected, not units.
  def self.last_write
    @last_write
  end

  def self.model_key(model)
    model.guid
  rescue StandardError
    model.object_id
  end

  def self.remember_write(model, what, entries)
    return if entries.nil? || entries.empty?
    @last_write = { :model => model_key(model), :what => what,
                    :pages => entries, :at => Time.now }
  end

  # The written keys' current state, read with the page SELECTED. Keys the
  # index does not know are left out — there is nothing to put back for them.
  def self.snapshot_keys(keys)
    snap = preview_snapshot
    out  = {}
    keys.each { |k| out[k] = snap[k] unless snap[k].nil? }
    out
  end

  # For a button label: what the last record would put back, or nil.
  def self.undo_summary(model)
    lw = @last_write
    return nil unless lw && lw[:model] == model_key(model)
    names = lw[:pages].select { |e| e[:page].valid? }.map { |e| e[:name] }
    return nil if names.empty?
    { 'what' => lw[:what], 'scenes' => names,
      'at' => lw[:at].strftime('%H:%M'), 'module' => 'WR_SceneWalls' }
  rescue StandardError
    nil
  end

  # write_scene's twin for a recorded snapshot: the same flags, the same
  # page save-flag fixes, the same page.update — with `page` SELECTED.
  def self.write_snapshot(page, before)
    preview_show(before, {})              # per piece, exactly as recorded
    if page.respond_to?(:use_hidden_objects=) &&
       page.respond_to?(:use_hidden_objects?) && !page.use_hidden_objects?
      page.use_hidden_objects = true rescue nil
    end
    page.update(update_mask)
  end

  def self.undo_last(model)
    lw = @last_write
    return [false, 'Nothing to put back — no apply has been recorded in this ' \
                   'SketchUp session.'] unless lw
    unless lw[:model] == model_key(model)
      return [false, 'The last apply was on a different model — nothing put back.']
    end
    entries = lw[:pages].select { |e| e[:page] && e[:page].valid? }
    return [false, 'The scenes the last apply wrote to no longer exist.'] if entries.empty?
    scan(model)                      # rebuild the key index; keys are entityIDs
    start = model.pages.selected_page
    put   = []
    model.start_operation('Put back wall answers per scene', true)
    begin
      entries.each do |e|
        model.pages.selected_page = e[:page]
        write_snapshot(e[:page], e[:before])
        put << e[:name]
      end
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      restore_page(model, start)
      return [false, "Put back failed and was rolled back: #{e.class}: #{e.message}"]
    end
    restore_page(model, start)
    @last_write = nil
    [true, "Put back the saved wall answer on #{put.size} scene(s): " \
           "#{put.join(', ')} (as it was at #{lw[:at].strftime('%H:%M')}). " \
           'That was the one step there is — it is used up.']
  end

  def self.restore_page(model, page)
    model.pages.selected_page = page if page && page.valid?
  rescue StandardError
    nil
  end

  # The blast radius, by name, before apply_all runs. A UI.messagebox rather
  # than a JS confirm(): CEF's HtmlDialog does not reliably show one.
  def self.confirm_all?(pages, what)
    names = pages.map { |pg| pg.name.to_s }
    shown = names.first(12)
    shown << "… and #{names.size - 12} more" if names.size > 12
    UI.messagebox("Apply these #{what} picks to #{pages.size} scene(s)?\n\n" \
                  "#{shown.join("\n")}\n\n" \
                  "Each of those scenes' saved #{what} answer will be REPLACED " \
                  "by what is ticked now.\n\nCtrl+Z will NOT put them back (a scene's saved " \
                  "snapshot is outside SketchUp's undo). UNDO LAST APPLY puts this " \
                  "one back - one step, this SketchUp session only.",
                  MB_YESNO) == IDYES
  end

  # The fallback for unnamed geometry: hide/show the SELECTED groups (and
  # component instances) in the current scene. Same save, no names needed.
  def self.apply_selection(model, hide)
    page = model.pages.selected_page
    return [false, 'No scene is selected.'] unless page
    items = model.selection.to_a.select do |e|
      e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    end
    return [false, 'Nothing usable selected — select the wall group(s) themselves.'] if items.empty?
    model.start_operation(hide ? 'Hide selection in scene' : 'Show selection in scene', true)
    begin
      items.each { |e| e.hidden = hide }
      if page.respond_to?(:use_hidden_objects=) &&
         page.respond_to?(:use_hidden_objects?) && !page.use_hidden_objects?
        page.use_hidden_objects = true rescue nil
      end
      page.update(update_mask)
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      return [false, "Failed and was rolled back: #{e.class}: #{e.message}"]
    end
    [true, "#{items.size} item(s) #{hide ? 'hidden' : 'shown'} in scene \"#{page.name}\"."]
  end

  # ---- live preview (1.24.0) ---------------------------------------------
  #
  # The proposal package's pickers show a tick in the viewport BEFORE Apply.
  # These three read and set the pieces' hidden flags and nothing else: no
  # page.update (that is a commit), no operation (the caller owns undo).
  # The snapshot is per PIECE, because a unit can be mixed.
  def self.preview_snapshot
    snap = {}
    (@units || {}).each do |key, u|
      snap[key] = u[:pieces].map { |g| g.valid? ? (g.hidden? ? true : false) : nil }
    end
    snap
  end

  # Every unit to picks[key] where given, and back to its snapshot where
  # not — so the same call with {} IS the restore, and repeated calls with
  # the full pick set cannot drift.
  def self.preview_show(snap, picks)
    snap.each do |key, base|
      u = @units && @units[key]
      next unless u
      want = picks.key?(key) ? (picks[key] ? true : false) : nil
      u[:pieces].each_with_index do |g, i|
        next unless g.valid?
        v = want.nil? ? base[i] : want
        g.hidden = v unless v.nil?
      end
    end
  end

  def self.preview_restore(snap)
    preview_show(snap, {})
  end

  def self.fix_pages(model)
    fixed = []
    failed = []
    model.pages.each do |pg|
      next unless pg.respond_to?(:use_hidden_objects?) && !pg.use_hidden_objects?
      begin
        pg.use_hidden_objects = true
        fixed << pg.name.to_s
      rescue StandardError => e
        failed << "#{pg.name}: #{e.class}"
      end
    end
    msg = fixed.empty? ? 'Every scene already saves hidden objects.' :
                         "Fixed: #{fixed.join(', ')}."
    msg += " FAILED: #{failed.join(', ')}." unless failed.empty?
    [failed.empty?, msg]
  end

  # -------------------------------------------------------------- dialog --

  # The one JSON shape both this dialog and the proposal package's popover
  # build their object rows from, so the two lists cannot drift apart.
  def self.object_json(u)
    { 'key' => u[:key], 'label' => u[:label], 'count' => u[:count],
      'hidden' => u[:hidden] ? true : false, 'mixed' => u[:mixed] ? true : false }
  end

  def self.state_json(model)
    st    = scan(model)
    page  = model.pages.selected_page
    { 'scene'   => page ? page.name.to_s : nil,
      'noscene' => model.pages.count.zero?,
      'off'     => pages_not_saving_hidden(model),
      'undo'    => undo_summary(model),
      'units'   => st[:walls].map do |u|
        { 'key' => u[:key], 'room' => u[:room], 'wall' => u[:wall],
          'side' => u[:side], 'hidden' => u[:hidden], 'mixed' => u[:mixed],
          'pieces' => u[:pieces].size }
      end,
      'objects' => st[:objects].map { |u| object_json(u) } }.to_json
  end

  def self.html
    <<~HTML
      <!DOCTYPE html><html><head><meta charset="utf-8"><style>
        body { font: 13px "Segoe UI", sans-serif; margin: 0; background: #22262b;
               color: #dde3ea; }
        #bar { padding: 10px 12px 6px; }
        #scene { font-weight: 600; }
        #warn { background: #5b3a1e; color: #ffd9a8; padding: 6px 12px; display: none; }
        #warn button { margin-left: 8px; }
        #cols { display: flex; gap: 10px; padding: 8px 12px; }
        .col { flex: 1; background: #2b3036; border: 1px solid #3a4048;
               border-radius: 6px; min-height: 220px; padding: 6px; }
        .col h3 { margin: 2px 4px 8px; font-size: 12px; text-transform: uppercase;
                  letter-spacing: .04em; color: #9aa5b1; }
        .col.hiddencol h3 { color: #e8a1a1; }
        .roomhdr { font-size: 11px; color: #8a94a0; margin: 8px 4px 2px; }
        .chip { display: block; width: 100%; text-align: left; margin: 2px 0;
                padding: 5px 8px; border-radius: 4px; border: 1px solid #48505a;
                background: #343b43; color: #dde3ea; cursor: pointer; font: inherit; }
        .chip:hover { background: #3e4750; }
        .chip .side { color: #8a94a0; font-size: 11px; }
        .chip.mixed { border-color: #b58840; }
        #foot { padding: 6px 12px 10px; }
        #foot button { font: inherit; padding: 6px 12px; margin-right: 6px;
                       border-radius: 4px; border: 1px solid #48505a;
                       background: #343b43; color: #dde3ea; cursor: pointer; }
        #apply { background: #2e5a34; border-color: #3f7a47; }
        #apply.dirty { background: #3f7a47; }
        #status { padding: 0 12px 10px; color: #9aa5b1; min-height: 16px; }
        #selrow { border-top: 1px solid #3a4048; padding: 8px 12px 4px; }
        .hint { color: #7b8590; font-size: 11px; padding: 2px 12px 8px; }
        #empty { padding: 12px; color: #9aa5b1; display: none; }
        /* The objects list is deliberately a TICK LIST and not more chips.
           A chip moving between two columns is the walls idiom and it works
           because a wall is either up or down; an object row also has to
           carry a copy count and a SHOW ME, which is exactly the annotations
           picker's row and it already reads well. Same dark tokens as the
           rest of this dialog, no new colours. */
        #objwrap { border-top: 1px solid #3a4048; margin: 4px 12px 0; padding-top: 6px; }
        .objh { display: flex; align-items: baseline; gap: 10px; font-size: 11px;
                text-transform: uppercase; letter-spacing: .06em; color: #9aa5b1;
                margin: 2px 2px 3px; }
        .objh .links { margin-left: auto; text-transform: none; letter-spacing: 0; }
        .objh a { color: #9aa5b1; cursor: pointer; text-decoration: underline dotted; }
        .objh a:hover { color: #e8a06a; }
        .orow { display: flex; align-items: center; gap: 8px; padding: 3px 2px;
                font-size: 12px; }
        .orow:hover { background: #2b3036; }
        .orow label { display: flex; align-items: center; gap: 8px; cursor: pointer;
                      flex: 1 1 auto; min-width: 0; }
        .orow .txt { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .orow .cnt { color: #8a94a0; font-size: 11px; white-space: nowrap; }
        .orow .mix { color: #e8a06a; font-size: 10.5px; white-space: nowrap; }
        .find { font: inherit; font-size: 10px; letter-spacing: .06em; padding: 2px 7px;
                border: 1px solid #48505a; border-radius: 3px; background: #343b43;
                color: #dde3ea; cursor: pointer; }
        .find:hover { border-color: #e8a06a; color: #e8a06a; }
      </style></head><body>
      <div id="bar">Scene: <span id="scene">–</span></div>
      <div id="warn"><span id="warntext"></span>
        <button onclick="sketchup.fixpages()">Fix these scenes</button></div>
      <div id="empty">No named walls found. Rooms drawn by the WR tools have them;
        for anything else run <b>Name walls for the scene picker</b> once, or use
        the selection buttons below.</div>
      <div id="cols">
        <div class="col" id="shown"><h3>Shown in this scene</h3></div>
        <div class="col hiddencol" id="hidden"><h3>Hidden in this scene</h3></div>
      </div>
      <div class="hint">Click a wall to move it across. Nothing changes until Apply.
        Clicking a scene tab reloads this list from that scene.</div>
      <div id="objwrap">
        <div class="objh">Objects &mdash; booth, furniture, anything that is not a named wall
          <span class="links"><a data-oall="1">all</a> &middot;
            <a data-onone="1">none</a></span></div>
        <div id="objs"></div>
        <div class="hint">Ticked = hidden when this scene exports &mdash; the opposite
          arrangement to the wall chips above, because an object is one row and not
          two columns. TOP-LEVEL objects only: something nested inside a component
          is not listed here, because hiding it would hide it in every copy of the
          parent rather than just on this scene. Use the selection buttons below for
          those.</div>
      </div>
      <div id="foot">
        <button id="apply" onclick="applyNow()">Apply to this scene</button>
        <button onclick="applyAll()" title="The same ticks into EVERY scene in the model — asks first. Ctrl+Z will NOT undo it; Undo last apply will.">Apply to every scene</button>
        <button id="undolast" onclick="sketchup.undolast()" disabled
                title="Nothing to put back yet">Undo last apply</button>
        <button onclick="sketchup.refresh()">Refresh</button>
      </div>
      <div id="selrow">
        <button onclick="sketchup.selhide()">Hide selection in this scene</button>
        <button onclick="sketchup.selshow()">Show selection in this scene</button>
      </div>
      <div class="hint">The selection buttons work on whatever is selected in the
        model — for walls the picker does not know by name.</div>
      <div id="status"></div>
      <script>
        var S = { units: [], objects: [], scene: null };
        var opicks = {};
        function esc(s){ return String(s==null?"":s).replace(/&/g,"&amp;")
          .replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;")
          .replace(/'/g,"&#39;"); }
        function renderObjects() {
          var box = document.getElementById('objs'), objs = S.objects || [];
          if (!objs.length) {
            box.innerHTML = "<div class='orow'><span class='cnt'>nothing at the " +
              "top level that is not already a wall above</span></div>";
          } else {
            box.innerHTML = objs.map(function (u) {
              return "<div class='orow'><label>" +
                "<input type='checkbox' data-okey='" + esc(u.key) + "'" +
                (opicks[u.key] ? " checked" : "") + ">" +
                "<span class='txt' title='" + esc(u.label) + "'>" + esc(u.label) +
                "</span>" +
                (u.count > 1 ? "<span class='cnt'>" + u.count + " copies</span>" : "") +
                "</label>" +
                (u.mixed ? "<span class='mix'>copies disagree &mdash; ticking sets them all</span>" : "") +
                "<button class='find' data-ofind='" + esc(u.key) + "'>SHOW ME</button>" +
                "</div>";
            }).join("");
          }
          Array.prototype.forEach.call(box.querySelectorAll("input[data-okey]"), function (el) {
            el.addEventListener("change", function () {
              opicks[el.getAttribute("data-okey")] = el.checked; markDirty();
            });
          });
          Array.prototype.forEach.call(box.querySelectorAll("[data-ofind]"), function (el) {
            el.addEventListener("click", function () {
              sketchup.reveal(el.getAttribute("data-ofind"));
            });
          });
        }
        function render() {
          document.getElementById('scene').textContent =
            S.noscene ? 'NO SCENES IN THIS MODEL' : (S.scene || '(none selected)');
          var warn = document.getElementById('warn');
          if (S.off && S.off.length) {
            document.getElementById('warntext').textContent =
              'These scenes do not save hidden objects, so walls will not come ' +
              'back on them: ' + S.off.join(', ');
            warn.style.display = 'block';
          } else { warn.style.display = 'none'; }
          document.getElementById('empty').style.display =
            S.units.length ? 'none' : 'block';
          ['shown', 'hidden'].forEach(function (colId) {
            var col = document.getElementById(colId);
            col.querySelectorAll('.roomhdr,.chip').forEach(function (n) { n.remove(); });
            var lastRoom = null;
            S.units.forEach(function (u) {
              if ((colId === 'hidden') !== !!u.hidden) return;
              if (u.room !== lastRoom) {
                var h = document.createElement('div');
                h.className = 'roomhdr'; h.textContent = u.room;
                col.appendChild(h); lastRoom = u.room;
              }
              var b = document.createElement('button');
              b.className = 'chip' + (u.mixed ? ' mixed' : '');
              b.innerHTML = 'Wall ' + u.wall +
                (u.side ? ' <span class="side">(' + u.side + ')</span>' : '') +
                (u.mixed ? ' <span class="side">mixed — Apply will settle it</span>' : '');
              b.onclick = function () { u.hidden = !u.hidden; u.mixed = false;
                                        markDirty(); render(); };
              col.appendChild(b);
            });
          });
          renderObjects();
        }
        function markDirty() { document.getElementById('apply').className = 'dirty'; }
        function collectPicks() {
          // EVERY row is sent, walls and objects alike, not only the touched
          // ones — that is what makes UNticking reliably show again.
          var picks = {};
          S.units.forEach(function (u) { picks[u.key] = !!u.hidden; });
          (S.objects || []).forEach(function (u) { picks[u.key] = !!opicks[u.key]; });
          return picks;
        }
        function applyNow() { sketchup.apply(JSON.stringify(collectPicks())); }
        function applyAll() { sketchup.applyall(JSON.stringify(collectPicks())); }
        function setState(json) {
          S = JSON.parse(json);
          var ub = document.getElementById('undolast');
          if (ub) {
            ub.disabled = !S.undo;
            ub.title = S.undo
              ? ("Put back the saved " + S.undo.what + " answer on " + S.undo.scenes.length +
                 " scene(s): " + S.undo.scenes.join(", ") + " (applied " + S.undo.at +
                 "). One step, this SketchUp session only. Ctrl+Z cannot do this.")
              : "Nothing to put back yet - an apply in this SketchUp session records what it overwrote.";
          }
          // Object ticks are re-read from the model on every push, exactly as
          // the wall chips are: the scene on screen is the only truth.
          opicks = {};
          (S.objects || []).forEach(function (u) { if (u.hidden) opicks[u.key] = true; });
          document.getElementById('apply').className = '';
          render();
        }
        function setStatus(t) { document.getElementById('status').textContent = t; }
        document.addEventListener('click', function (ev) {
          var el = ev.target;
          if (!el || !el.getAttribute) return;
          if (el.getAttribute('data-oall') || el.getAttribute('data-onone')) {
            var on = !!el.getAttribute('data-oall');
            (S.objects || []).forEach(function (u) { opicks[u.key] = on; });
            markDirty(); renderObjects();
          }
        });
        window.addEventListener('load', function () { sketchup.ready(); });
      </script></body></html>
    HTML
  end

  def self.push_state(model)
    return unless @dlg && @dlg.visible?
    @dlg.execute_script("setState(#{state_json(model).inspect})")
  end

  def self.status(text)
    return unless @dlg && @dlg.visible?
    @dlg.execute_script("setStatus(#{text.to_s.inspect})")
  end

  # Reload the wall lists when the operator clicks a scene tab, so the two
  # columns always describe the scene on screen. Unapplied picks are dropped
  # on purpose — they were picks for the scene that was just left.
  class FrameWatcher
    def initialize(&blk)
      @blk = blk
    end

    def frameChange(_from, to, _pct)
      @blk.call(to)
    rescue StandardError
      nil
    end
  end

  def self.open
    model = Sketchup.active_model
    unless model
      UI.messagebox('No model is open.')
      return
    end
    if @dlg && @dlg.visible?
      @dlg.bring_to_front
      push_state(model)
      return
    end
    @dlg = UI::HtmlDialog.new(
      :dialog_title => 'Hide walls per scene',
      :preferences_key => 'WR_SceneWalls',
      :width => 560, :height => 620, :resizable => true,
      :style => UI::HtmlDialog::STYLE_DIALOG
    )
    @dlg.set_html(html)
    @dlg.add_action_callback('apply') do |_c, payload|
      picks = JSON.parse(payload) rescue {}
      ok, msg = apply(Sketchup.active_model, picks)
      push_state(Sketchup.active_model)
      status(msg)
      puts "WR_SceneWalls: #{msg}" unless ok
    end
    # Every scene, one undo, confirmed by name first (see apply_all).
    @dlg.add_action_callback('applyall') do |_c, payload|
      picks = JSON.parse(payload) rescue {}
      m = Sketchup.active_model
      if confirm_all?(m.pages.to_a, 'wall')
        _ok, msg, det = apply_all(m, picks)
        puts "WR_SceneWalls: #{msg}"
        (det ? det[:written] : []).each { |nm| puts "  written: #{nm}" }
      else
        msg = 'Not applied — nothing was changed.'
      end
      push_state(m)
      status(msg)
    end
    # UNDO LAST APPLY (1.26.1): the way back that Ctrl+Z is not.
    @dlg.add_action_callback('undolast') do |_c|
      m = Sketchup.active_model
      _ok, msg = undo_last(m)
      puts "WR_SceneWalls: #{msg}"
      push_state(m)
      status(msg)
    end
    @dlg.add_action_callback('ready') do |_c|
      # Also the liveness probe: this only fires if the HTML parsed and the
      # script ran to its load handler, so a scripted check can read it.
      @js_ready = true
      push_state(Sketchup.active_model)
    end
    @dlg.add_action_callback('refresh') do |_c|
      push_state(Sketchup.active_model)
      status('Reloaded.')
    end
    # SHOW ME on an object row. The standalone dialog never needed this
    # before — a wall chip is its own affordance — but an object row has to
    # be able to say "this one, here".
    @dlg.add_action_callback('reveal') do |_c, key|
      _ok, msg = reveal(Sketchup.active_model, key.to_s)
      status(msg)
    end
    @dlg.add_action_callback('selhide') do |_c|
      _ok, msg = apply_selection(Sketchup.active_model, true)
      push_state(Sketchup.active_model)
      status(msg)
    end
    @dlg.add_action_callback('selshow') do |_c|
      _ok, msg = apply_selection(Sketchup.active_model, false)
      push_state(Sketchup.active_model)
      status(msg)
    end
    @dlg.add_action_callback('fixpages') do |_c|
      _ok, msg = fix_pages(Sketchup.active_model)
      push_state(Sketchup.active_model)
      status(msg)
    end
    @last_page = model.pages.selected_page
    watcher = FrameWatcher.new do |to|
      if to && to != @last_page
        @last_page = to
        push_state(Sketchup.active_model)
      end
    end
    @watch_id = Sketchup::Pages.add_frame_change_observer(watcher)
    @dlg.set_on_closed do
      if @watch_id
        Sketchup::Pages.remove_frame_change_observer(@watch_id) rescue nil
        @watch_id = nil
      end
    end
    @dlg.show
    push_state(model)
  end
end

WR_SceneWalls.open unless $wr_suppress_autorun || $wr_no_autorun
