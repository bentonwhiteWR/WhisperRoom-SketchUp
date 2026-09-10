# @title Hide notes & dimensions per scene...
# @cat Scenes and images
# @rank 5
#
# Pick which NOTES, DIMENSIONS and 3D LABELS are hidden on the scene you are
# looking at — the annotation twin of "Hide walls per scene". Benton, 9 Sep
# 2026: "Sometimes I have tons of text I want on one scene, but not another."
# Tick a row, hit Apply, and that scene remembers. Click the next scene tab
# and the callouts come back, because that scene remembered its own answer.
#
# ONE LIST, ONE RULE: ticked = hidden when this scene exports. Same polarity
# as the walls picker, deliberately, because the two sit side by side in the
# proposal package window.
#
# TWO MECHANISMS UNDER IT, AND THE OPERATOR NEVER PICKS BETWEEN THEM. This is
# the part that is not obvious, and the reason the tool is shaped this way:
#
#   SETS are tags in the WR-Dims* / WR-Notes* family. A scene saves per-TAG
#   visibility, so one flag hides three hundred callouts at every nesting
#   depth, it is reusable on a dozen scenes, and — the part that matters most
#   — the proposal package's client-safe pass can find it by name.
#     Apply writes:  layer.visible = false + page.set_visibility(layer, false)
#
#   CALLOUTS are single entities. A scene ALSO saves per-ENTITY hidden state
#   for Sketchup::Text (screen and leader), DimensionLinear / DimensionRadial
#   and a 3D-text group, through the walls' own call page.update(384).
#     Apply writes:  entity.hidden = true + page.update(update_mask)
#
# BOTH ARE OBSERVED, not reasoned about — probe-scene-annotations.rb, run live
# in SketchUp 26.2.243 on 9 Sep 2026 (output pasted verbatim into the DEVLOG
# entry for 1.20.0). Every entity.* check passed, the tag path round-trips,
# and mask 384 leaves the scene's saved camera byte-identical.
#
# AND ONE CHECK FAILED, WHICH IS WHY THIS TOOL IS A HYBRID AND NOT A TAG
# PICKER. `tag.untagged_can_hide` FAILED: SketchUp will not hide the Untagged
# tag. Hand-placed text lands on whatever tag is active, which is normally
# Untagged, so most of the text already in Benton's models is UNREACHABLE by
# the tag mechanism. A picker that offered "Untagged" as a set would tick a
# box and do nothing at all, which is the single outcome this tool forbids.
# So Untagged callouts are listed INDIVIDUALLY under "Not in a set", with
# all / none links so a batch hide is still one click, and MOVE SELECTION
# INTO A SET is there for anyone who wants a reusable set instead.
#
# WHY SETS STILL EXIST. Hiding hundreds of callouts with one flag, reusing
# that across scenes, and being covered by the client-safe pass are all things
# a tag does that per-entity flags do not. New sets are named WR-Notes-<name>
# so they stay inside the family every consumer matches live
# (WR_ProposalScenes.annot_tags) — a set outside it would leak past
# client-safe, which is defect D5 all over again.
#
# A SCENE THAT DOES NOT SAVE HIDDEN OBJECTS (or hidden tags) cannot put a
# callout back when it is selected. Scenes save both by default; any that have
# either switched off are named in a banner with a one-click fix, and Apply
# turns both on for the scene it is writing.
#
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/wr-scene-annotations.rb"

require 'sketchup.rb'
require 'json'

wr_sa_autorun_was = $wr_no_autorun
$wr_no_autorun = true
begin
  # proposal-scenes.rb owns the tag family (ANNOT_TAGS, ANNOT_RE, annot_tags,
  # annot_set_name). Loaded as a library only — a LOCAL holds the flag so a
  # nested load cannot clobber it (the 2026-08-27 dead-button bug).
  load File.join(File.dirname(__FILE__), 'proposal-scenes.rb')
ensure
  $wr_no_autorun = wr_sa_autorun_was
end

module WR_SceneAnnotations
  # A 3D-text label is a GROUP, not a Text entity — add_3d_text builds real
  # geometry. build-room.rb, peoplesspace-alcove.rb and the take-off tools all
  # name theirs "label: <words>", so that prefix is what makes one an
  # annotation rather than a piece of the building.
  LABEL_RE = /\Alabel:\s*/.freeze
  # Annotations sit at the top level or one container in; 2 is generous and
  # bounded, and matches wr-scene-walls.rb's own DEPTH.
  DEPTH = 2
  # Row label length. The full string rides along in the tooltip.
  TRUNC = 40

  # ------------------------------------------------------------- mechanism --

  # The scene-property mask Apply saves — the walls' own, so the two features
  # can never disagree about what a scene stores. WR_SceneWalls owns it when
  # it is loaded (the proposal package loads both); the same computation is
  # inlined for a standalone load, rather than making this tool refuse to open
  # without the other one.
  def self.update_mask
    if defined?(WR_SceneWalls) && WR_SceneWalls.respond_to?(:update_mask)
      return WR_SceneWalls.update_mask
    end
    m = 0
    m |= PAGE_USE_HIDDEN_OBJECTS  if defined?(PAGE_USE_HIDDEN_OBJECTS)
    m |= PAGE_USE_HIDDEN_GEOMETRY if defined?(PAGE_USE_HIDDEN_GEOMETRY)
    m = PAGE_USE_HIDDEN if m.zero? && defined?(PAGE_USE_HIDDEN)
    m
  end

  # Scenes that will NOT restore annotations when selected, by name. BOTH
  # properties matter here where walls needed only one: sets ride on tag
  # visibility (use_hidden_layers) and single callouts on the hidden-object
  # state (use_hidden_objects).
  def self.pages_not_saving(model)
    model.pages.to_a.select do |pg|
      (pg.respond_to?(:use_hidden_layers?) && !pg.use_hidden_layers?) ||
        (pg.respond_to?(:use_hidden_objects?) && !pg.use_hidden_objects?)
    end.map { |pg| pg.name.to_s }
  rescue StandardError
    []
  end

  # ---- live preview (1.24.0) ---------------------------------------------
  #
  # WR_SceneWalls.preview_* for annotations: sets through tag visibility,
  # callouts through the entity flag, stored uniformly as "hidden?". No
  # page.set_visibility and no page.update — both of those are the commit
  # that Apply owns — and no operation: the caller wraps undo.
  def self.preview_snapshot
    snap = {}
    (@units || {}).each do |key, u|
      if u[:layer]
        l = u[:layer]
        snap[key] = l.valid? ? (l.visible? ? false : true) : nil
      else
        e = u[:ent]
        snap[key] = (e && e.valid?) ? (e.hidden? ? true : false) : nil
      end
    end
    snap
  end

  def self.preview_show(snap, picks)
    snap.each do |key, base|
      u = @units && @units[key]
      next unless u
      want = picks.key?(key) ? (picks[key] ? true : false) : base
      next if want.nil?
      if u[:layer]
        l = u[:layer]
        next unless l.valid?
        l.visible = !want
      else
        e = u[:ent]
        next unless e && e.valid?
        e.hidden = want
      end
    end
  end

  def self.preview_restore(snap)
    preview_show(snap, {})
  end

  def self.fix_pages(model)
    fixed  = []
    failed = []
    model.pages.each do |pg|
      want = false
      want = true if pg.respond_to?(:use_hidden_layers?) && !pg.use_hidden_layers?
      want = true if pg.respond_to?(:use_hidden_objects?) && !pg.use_hidden_objects?
      next unless want
      begin
        pg.use_hidden_layers  = true if pg.respond_to?(:use_hidden_layers=)
        pg.use_hidden_objects = true if pg.respond_to?(:use_hidden_objects=)
        fixed << pg.name.to_s
      rescue StandardError => e
        failed << "#{pg.name}: #{e.class}"
      end
    end
    msg = fixed.empty? ? 'Every scene already saves hidden tags and objects.' :
                         "Fixed: #{fixed.join(', ')}."
    msg += " FAILED: #{failed.join(', ')}." unless failed.empty?
    [failed.empty?, msg]
  end

  # ------------------------------------------------------------- inventory --

  # 'text' / 'dim' / '3d', or nil for anything that is not an annotation. The
  # ONE place that question is answered, so the picker, MOVE SELECTION and the
  # manifest collector cannot drift apart on what counts as a callout.
  def self.kind_of(e)
    return 'text' if e.is_a?(Sketchup::Text)
    return 'dim'  if e.is_a?(Sketchup::DimensionLinear)
    return 'dim'  if defined?(Sketchup::DimensionRadial) && e.is_a?(Sketchup::DimensionRadial)
    if e.is_a?(Sketchup::Group)
      return '3d' if (e.name.to_s rescue '') =~ LABEL_RE
    end
    nil
  rescue StandardError
    nil
  end

  # What the row says. A dimension returns its RENDERED string from #text
  # (observed, DEVLOG 1.10.8), so this never computes a number of its own.
  def self.text_of(e, kind)
    s = if kind == '3d'
          (e.name.to_s rescue '').sub(LABEL_RE, '')
        else
          (e.text.to_s rescue '')
        end
    s = s.gsub(/\s+/, ' ').strip
    s.empty? ? '(no text)' : s
  rescue StandardError
    '(unreadable)'
  end

  def self.trunc(s)
    s.length > TRUNC ? (s[0, TRUNC - 1] + "\u2026") : s
  end

  def self.tag_of(e)
    n = (e.layer ? e.layer.name.to_s : '')
    n.empty? ? 'Untagged' : n
  rescue StandardError
    'Untagged'
  end

  # Every annotation the model holds, to DEPTH. A `label:` group is an ITEM,
  # never a container to descend into.
  def self.each_annotation(ents, depth = 0, &blk)
    ents.each do |e|
      k = kind_of(e)
      if k
        blk.call(e, k)
        next
      end
      next unless depth < DEPTH
      kids = begin
        if e.is_a?(Sketchup::Group)
          e.entities
        elsif e.is_a?(Sketchup::ComponentInstance)
          e.definition.entities
        end
      rescue StandardError
        nil
      end
      each_annotation(kids, depth + 1, &blk) if kids
    end
  end

  def self.item_hash(e, k)
    full = text_of(e, k)
    { :key => "e:#{e.entityID}", :kind => k, :text => trunc(full), :full => full,
      :tag => tag_of(e), :hidden => ((e.hidden? rescue false) ? true : false),
      :ent => e }
  end

  # The whole picker's data, and the only place display strings are made.
  # Fills @units — key => { :ent } or { :layer, :members } — so Apply and
  # reveal reference the model through an id, never through a display string.
  #
  #   { :sets  => [{ :key 't:WR-Notes-Plan', :name, :counts, :hidden, :members }],
  #     :loose => [item, ...] }
  #
  # Loose = Untagged first, then any non-family tag. A family tag ALWAYS gets
  # a set row, even with nothing on it, so "there is a set for this" is
  # visible before anything has been moved into it.
  def self.inventory(model)
    @units = {}
    family = WR_ProposalScenes.annot_tags(model)
    fam_present = family.select { |n| model.layers[n] }
    by_tag = {}
    loose  = []
    each_annotation(model.entities) do |e, k|
      it = item_hash(e, k)
      @units[it[:key]] = { :ent => e }
      if fam_present.include?(it[:tag])
        (by_tag[it[:tag]] ||= []) << it
      else
        loose << it
      end
    end
    sets = fam_present.map do |n|
      layer = model.layers[n]
      mem   = by_tag[n] || []
      key   = "t:#{n}"
      @units[key] = { :layer => layer, :members => mem }
      counts = Hash.new(0)
      mem.each { |m| counts[m[:kind]] += 1 }
      { :key => key, :name => n, :hidden => (layer.visible? ? false : true),
        :count => mem.size, :counts => counts, :members => mem }
    end
    # Untagged first — it is where hand-placed text lands, so it is what the
    # operator is looking for — then the rest by tag name, each group keeping
    # the order the model walk found them in.
    loose = loose.each_with_index.sort_by do |it, i|
      [it[:tag] == 'Untagged' ? 0 : 1, it[:tag], i]
    end.map { |it, _i| it }
    { :sets => sets, :loose => loose }
  end

  # ---------------------------------------------------------------- json --

  def self.item_json(it)
    { 'key' => it[:key], 'kind' => it[:kind], 'text' => it[:text],
      'full' => it[:full], 'tag' => it[:tag], 'hidden' => it[:hidden] }
  end

  # "5 text, 2 dim" — what is ON the tag, so an empty set says so plainly
  # rather than looking like a set that failed to load.
  def self.count_label(counts)
    parts = []
    parts << "#{counts['text']} text" if counts['text'].to_i > 0
    parts << "#{counts['dim']} dim"   if counts['dim'].to_i > 0
    parts << "#{counts['3d']} 3D"     if counts['3d'].to_i > 0
    parts.empty? ? 'empty' : parts.join(', ')
  end

  def self.set_json(u)
    { 'key' => u[:key], 'name' => u[:name], 'hidden' => u[:hidden],
      'count' => u[:count], 'cnt' => count_label(u[:counts]),
      'members' => u[:members].map { |m| item_json(m) } }
  end

  def self.state_hash(model)
    inv  = inventory(model)
    page = model.pages.selected_page
    { 'scene'   => page ? page.name.to_s : nil,
      'noscene' => model.pages.count.zero?,
      'off'     => pages_not_saving(model),
      'sets'    => inv[:sets].map { |u| set_json(u) },
      'loose'   => inv[:loose].map { |it| item_json(it) } }
  end

  # ------------------------------------------------ pick it in the model --

  # Annotation entities the current selection points at — the selected
  # annotations themselves, plus any inside a selected group or component, so
  # clicking a room and pressing the button ticks that room's callouts.
  # Returns [keys, hint, others]: `hint` names the one family tag they all
  # share (or nil), and `others` counts what was selected and is NOT an
  # annotation, so the caller can say "nothing in your selection is a
  # callout" honestly instead of just showing zero.
  def self.keys_for_selection(model)
    return [[], nil, 0] unless @units
    hits   = []
    others = 0
    model.selection.to_a.each do |e|
      k = kind_of(e)
      if k
        hits << e
        next
      end
      kids = begin
        if e.is_a?(Sketchup::Group)
          e.entities
        elsif e.is_a?(Sketchup::ComponentInstance)
          e.definition.entities
        end
      rescue StandardError
        nil
      end
      if kids
        before = hits.size
        each_annotation(kids, 1) { |c, _ck| hits << c }
        others += 1 if hits.size == before
      else
        others += 1
      end
    end
    keys = hits.map { |e| "e:#{e.entityID}" }.select { |k| @units.key?(k) }.uniq
    tags = hits.map { |e| tag_of(e) }.uniq
    family = WR_ProposalScenes.annot_tags(model)
    hint = (tags.size == 1 && family.include?(tags.first)) ? tags.first : nil
    [keys, hint, others]
  end

  # The other direction: show me which one this row is. A set selects
  # everything on the tag; a callout selects that entity.
  def self.reveal(model, key)
    u = @units && @units[key]
    return [false, 'that row is stale — hit Refresh'] unless u
    live = if u[:layer]
             (u[:members] || []).map { |m| m[:ent] }.select { |e| e && e.valid? }
           else
             [u[:ent]].select { |e| e && e.valid? }
           end
    if live.empty?
      return [false, u[:layer] ? "nothing is on #{u[:layer].name} right now." :
                                 'that callout is no longer in the model']
    end
    model.selection.clear
    model.selection.add(live)
    begin
      model.active_view.zoom(live)
    rescue StandardError
      nil                       # zoom is a nicety; the selection is the point
    end
    if u[:layer]
      [true, "#{live.size} item(s) on #{u[:layer].name} selected in the model."]
    else
      [true, 'That callout is selected in the model.']
    end
  end

  # ------------------------------------------------------------- move ----

  # Re-tag the selected annotations onto a family tag, creating it if needed.
  # MEMBERSHIP IS FOR EVERY SCENE — this is model state, not scene state, and
  # the dialog says so. Anything selected that is not an annotation is REFUSED
  # BY NAME rather than silently re-tagged: a wall dragged onto WR-Notes would
  # vanish from every client image the moment client-safe ran.
  def self.move_selection_to_set(model, user_name)
    name = WR_ProposalScenes.annot_set_name(user_name)
    return [false, 'Type a name for the set first.'] if name.nil?
    sel = model.selection.to_a
    return [false, 'Nothing is selected — select the callouts in the model first.'] if sel.empty?
    move = []
    skip = []
    sel.each do |e|
      if kind_of(e)
        move << e
      else
        nm = (e.name.to_s rescue '')
        nm = (e.definition.name.to_s rescue '') if nm.empty? && e.is_a?(Sketchup::ComponentInstance)
        nm = (e.typename.to_s rescue 'entity') if nm.empty?
        skip << nm
      end
    end
    if move.empty?
      msg = 'Nothing in your selection is a note, a dimension or a 3D label.'
      msg += " Left alone: #{skip.uniq.first(4).join(', ')}." unless skip.empty?
      return [false, msg]
    end
    model.start_operation('Move annotations into a set', true)
    begin
      layer = model.layers[name] || model.layers.add(name)
      move.each { |e| e.layer = layer }
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      return [false, "Move failed and was rolled back: #{e.class}: #{e.message}"]
    end
    msg = "#{move.size} callout(s) moved into #{name} — that is for every scene."
    msg += " Not an annotation and left alone: #{skip.uniq.first(4).join(', ')}." unless skip.empty?
    [true, msg]
  end

  # Make an EMPTY set, with nothing selected. Benton, 10 Sep 2026: "I'd like
  # for there to be a way to add an annotation set from here."
  #
  # WHY THIS IS A SEPARATE CONTROL AND NOT A TWEAK TO MOVE. Until now the only
  # way to bring a set into existence was to select some callouts and move them
  # into it, because move_selection_to_set REFUSES an empty selection — and it
  # should keep refusing, since a move that moves nothing is a lie. But that
  # coupled two decisions that are not the same one: "this set should exist"
  # and "these callouts belong to it". Naming the sets up front, before there
  # is anything to put in them, is how a drawing gets planned; the tag is then
  # sitting in the list ready to be the active tag or a move target. So the
  # rule here is the mirror image: NO selection is required, and none is read.
  #
  # THE NAME IS NOT THE OPERATOR'S TO FINALISE. annot_set_name is the single
  # naming rule (proposal-scenes.rb) — a name already in the WR-Dims*/WR-Notes*
  # family is taken verbatim, anything else is slugged and prefixed WR-Notes-,
  # because a set outside that family is a set client-safe cannot see (defect
  # D5). That means the tag created is frequently NOT the string that was
  # typed, so the message reports the REAL tag name. Saying "created Plan" when
  # the model now holds "WR-Notes-Plan" is how someone goes looking in the tag
  # list for something that is not there.
  #
  # AN EXISTING SET IS A NO-OP, NOT AN ERROR. It already appears as a set row
  # (inventory lists every family tag present, members or not), so the honest
  # answer is "that one is already there" — deleting or recreating a tag that
  # may carry three hundred callouts to satisfy a button press is not a trade
  # this tool gets to make.
  def self.create_set(model, user_name)
    name = WR_ProposalScenes.annot_set_name(user_name)
    return [false, 'Type a name for the set first.'] if name.nil?
    if model.layers[name]
      return [true, "#{name} already exists — it is in the list above, and " \
                    'nothing was changed.']
    end
    model.start_operation('Create annotation set', true)
    begin
      model.layers.add(name)
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      return [false, "Create failed and was rolled back: #{e.class}: #{e.message}"]
    end
    [true, "Created #{name} — empty for now. It is in the list above and in " \
           'the move dropdown; select callouts and move them in, or draw with ' \
           'it as the active tag.']
  end

  # --------------------------------------------------------------- apply --

  # picks is { key => true(hide) / false(show) } over BOTH kinds of row, and
  # EVERY row is sent, not only the touched ones — the walls rule, so
  # unticking reliably shows again. Sets go through tag visibility, callouts
  # through the entity flag, and the scene is written once at the end.
  #
  # A ticked SET does not clear its members' own flags: the dialog greys them
  # out and keeps sending what they were, so unticking the set brings back
  # exactly the members that were showing before it was ticked.
  def self.apply(model, picks)
    page = model.pages.selected_page
    return [false, 'No scene is selected — this model has no scenes, or none is active. ' \
                   'Create/select a scene first; there is nothing to save into.'] unless page
    return [false, 'Nothing to apply.'] if picks.nil? || picks.empty?
    model.start_operation('Hide notes & dimensions per scene', true)
    begin
      r = write_scene(page, picks)
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      return [false, "Apply failed and was rolled back: #{e.class}: #{e.message}"]
    end
    msg = "Saved to scene \"#{page.name}\" — #{r[:hid_sets]} set(s) and " \
          "#{r[:hid_items]} callout(s) hidden (#{r[:sets] + r[:items]} row(s) written)."
    msg += " #{r[:gone].size} row(s) were stale and skipped — hit Refresh." unless r[:gone].empty?
    off = pages_not_saving(model)
    unless off.empty?
      msg += ' WARNING: scene(s) not saving hidden tags/objects (callouts will ' \
             "NOT come back on them): #{off.join(', ')}."
    end
    [true, msg]
  end

  # The write itself, with NO transaction of its own — the caller owns the
  # operation, which is what lets apply_all put every scene under ONE undo.
  # Same contract as WR_SceneWalls.write_scene: call it only with `page`
  # SELECTED, because page.update snapshots the model as it stands and
  # selecting the page is what restores that scene's own state for
  # everything that is not a row here.
  def self.write_scene(page, picks)
    gone      = []
    sets      = 0
    items     = 0
    hid_sets  = 0
    hid_items = 0
    picks.each do |key, hide|
      u = @units && @units[key]
      unless u
        gone << key
        next
      end
      want = hide ? true : false
      if u[:layer]
        l = u[:layer]
        next unless l.valid?
        l.visible = !want
        page.set_visibility(l, !want) if page.respond_to?(:set_visibility)
        sets += 1
        hid_sets += 1 if want
      else
        e = u[:ent]
        next unless e && e.valid?
        e.hidden = want
        items += 1
        hid_items += 1 if want
      end
    end
    # Make sure this scene will re-assert what we are about to save — BOTH
    # halves, since sets ride on tag visibility and callouts on the hidden-
    # object state.
    if page.respond_to?(:use_hidden_layers=) &&
       page.respond_to?(:use_hidden_layers?) && !page.use_hidden_layers?
      page.use_hidden_layers = true rescue nil
    end
    if page.respond_to?(:use_hidden_objects=) &&
       page.respond_to?(:use_hidden_objects?) && !page.use_hidden_objects?
      page.use_hidden_objects = true rescue nil
    end
    page.update(update_mask)
    saves = !((page.respond_to?(:use_hidden_layers?) && !page.use_hidden_layers?) ||
              (page.respond_to?(:use_hidden_objects?) && !page.use_hidden_objects?))
    { :sets => sets, :items => items, :hid_sets => hid_sets,
      :hid_items => hid_items, :gone => gone, :saves => saves }
  end

  # The SAME picks into every page given (default: every scene), one
  # operation — the walls rule, verbatim, including that it is NOT undoable
  # (page.update is outside SketchUp's undo; see WR_SceneWalls.apply_all); see
  # WR_SceneWalls.apply_all for why callers confirm first and why each page
  # is selected before it is written. Returns
  # [ok, message, { :written => [names], :unsaved => [names] }].
  def self.apply_all(model, picks, pages = nil)
    pages = (pages || model.pages.to_a).select { |pg| pg && pg.valid? }
    return [false, 'No scenes to write into.'] if pages.empty?
    return [false, 'Nothing to apply.'] if picks.nil? || picks.empty?
    start   = model.pages.selected_page
    written = []
    unsaved = []
    gone    = []
    model.start_operation('Hide notes & dimensions on every scene', true)
    begin
      pages.each do |pg|
        model.pages.selected_page = pg
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
    restore_page(model, start)
    msg = "Saved to #{written.size} scene(s). Ctrl+Z will NOT put them back — " \
          'a scene snapshot is outside SketchUp\'s undo.'
    msg += " #{gone.size} row(s) were stale and skipped — hit Refresh." unless gone.empty?
    unless unsaved.empty?
      msg += ' WARNING: scene(s) not saving hidden tags/objects (callouts will ' \
             "NOT come back on them): #{unsaved.join(', ')}."
    end
    [true, msg, { :written => written, :unsaved => unsaved }]
  end

  def self.restore_page(model, page)
    model.pages.selected_page = page if page && page.valid?
  rescue StandardError
    nil
  end

  # Same prompt as WR_SceneWalls.confirm_all?, inlined so a standalone load
  # does not need the other tool (the update_mask rule).
  def self.confirm_all?(pages, what)
    names = pages.map { |pg| pg.name.to_s }
    shown = names.first(12)
    shown << "… and #{names.size - 12} more" if names.size > 12
    UI.messagebox("Apply these #{what} picks to #{pages.size} scene(s)?\n\n" \
                  "#{shown.join("\n")}\n\n" \
                  "Each of those scenes' saved #{what} answer will be REPLACED " \
                  "by what is ticked now.\n\nCtrl+Z will NOT put them back: a scene's saved " \
                  "snapshot is outside SketchUp's undo (observed 10 Sep 2026). " \
                  "There is no way back from this button yet.",
                  MB_YESNO) == IDYES
  end

  # The immediate buttons: hide/show the SELECTED annotations in this scene,
  # no list, no keys. Walls' apply_selection filters to groups and instances;
  # this one accepts annotations — which is exactly why it lives here and
  # wr-scene-walls.rb is left alone.
  def self.apply_selection(model, hide)
    page = model.pages.selected_page
    return [false, 'No scene is selected.'] unless page
    items = model.selection.to_a.select { |e| kind_of(e) }
    if items.empty?
      return [false, 'Nothing usable selected — select the note, dimension or ' \
                     '3D label itself.']
    end
    model.start_operation(hide ? 'Hide annotations in scene' : 'Show annotations in scene', true)
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
    [true, "#{items.size} callout(s) #{hide ? 'hidden' : 'shown'} in scene \"#{page.name}\"."]
  end

  # -------------------------------------------------------------- dialog --

  def self.state_json(model)
    state_hash(model).to_json
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
        #list { padding: 4px 12px; }
        .grp { margin-bottom: 10px; }
        .grph { display: flex; align-items: baseline; gap: 10px; font-size: 11px;
                text-transform: uppercase; letter-spacing: .06em; color: #9aa5b1;
                margin: 8px 2px 3px; }
        .grph .links { margin-left: auto; text-transform: none; letter-spacing: 0; }
        .grph a { color: #9aa5b1; cursor: pointer; text-decoration: underline dotted; }
        .grph a:hover { color: #e8a06a; }
        .row { display: flex; align-items: center; gap: 8px; padding: 3px 2px;
               font-size: 12px; }
        .row:hover { background: #2b3036; }
        .row label { display: flex; align-items: center; gap: 8px; cursor: pointer;
                     flex: 1 1 auto; min-width: 0; }
        .row .txt { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .row .cnt, .row .kind { color: #8a94a0; font-size: 11px; white-space: nowrap; }
        .row .kind { font: 10px Consolas, monospace; border: 1px solid #3a4048;
                     border-radius: 3px; padding: 0 4px; }
        .row.member { padding-left: 22px; }
        .row.member.dis { opacity: .5; }
        .row.member.dis .with { color: #e8a06a; font-size: 10.5px; margin-left: auto; }
        .exp { border: 0; background: transparent; color: #8a94a0; cursor: pointer;
               font-size: 10px; width: 16px; padding: 0 2px; }
        .exp:hover { color: #e8a06a; }
        .find { font: inherit; font-size: 10px; letter-spacing: .06em; padding: 2px 7px;
                border: 1px solid #48505a; border-radius: 3px; background: #343b43;
                color: #dde3ea; cursor: pointer; }
        .find:hover { border-color: #e8a06a; color: #e8a06a; }
        .hint { color: #7b8590; font-size: 11px; padding: 2px 12px 8px; line-height: 1.45; }
        #move { border-top: 1px solid #3a4048; margin: 6px 12px; padding: 8px 0 4px;
                display: flex; gap: 6px; align-items: center; flex-wrap: wrap; }
        #move .lbl { flex: 1 1 100%; font-size: 11px; text-transform: uppercase;
                     letter-spacing: .06em; color: #9aa5b1; }
        #move select, #move input { font: inherit; font-size: 12px; padding: 4px 7px;
                border: 1px solid #48505a; border-radius: 4px; background: #2b3036;
                color: #dde3ea; }
        #move input { width: 120px; display: none; }
        #move input.show { display: inline-block; }
        #move .prefix { color: #8a94a0; font: 11.5px Consolas, monospace; display: none; }
        #move .prefix.show { display: inline; }
        /* The create row is a second full-width block inside the same flex
           strip — .lbl is already flex 1 1 100%, so it wraps on its own and
           the move controls above it do not move. Spacing only; no new
           colours, no new control styling. */
        #move .lbl.two { margin-top: 10px; }
        #foot { padding: 6px 12px 10px; }
        #foot button, #move button { font: inherit; padding: 6px 12px; margin-right: 6px;
                       border-radius: 4px; border: 1px solid #48505a;
                       background: #343b43; color: #dde3ea; cursor: pointer; }
        #apply { background: #2e5a34; border-color: #3f7a47; }
        #apply.dirty { background: #3f7a47; }
        #status { padding: 0 12px 10px; color: #9aa5b1; min-height: 16px; }
        #selrow { border-top: 1px solid #3a4048; padding: 8px 12px 4px; }
        #selrow button { font: inherit; padding: 6px 12px; margin-right: 6px;
                         border-radius: 4px; border: 1px solid #48505a;
                         background: #343b43; color: #dde3ea; cursor: pointer; }
        #empty { padding: 12px; color: #9aa5b1; display: none; }
      </style></head><body>
      <div id="bar">Scene: <span id="scene">–</span></div>
      <div id="warn"><span id="warntext"></span>
        <button onclick="sketchup.fixpages()">Fix these scenes</button></div>
      <div id="empty">No notes, dimensions or 3D labels found in this model.</div>
      <div id="list"></div>
      <div class="hint">Ticked = hidden when this scene exports. Sets hide as one;
        loose callouts hide one by one — both are saved into this scene only.
        Nothing changes until Apply. Clicking a scene tab reloads this list from
        that scene. SketchUp will not hide Untagged as a group, so loose callouts
        are hidden one at a time (or all at once with the link above).</div>
      <div id="move"></div>
      <div id="foot">
        <button id="apply" onclick="applyNow()">Apply to this scene</button>
        <button onclick="applyAll()" title="The same ticks into EVERY scene in the model — asks first. Ctrl+Z will NOT undo it: scene snapshots are outside SketchUp's undo.">Apply to every scene</button>
        <button onclick="sketchup.pick()">Use my selection</button>
        <button onclick="sketchup.refresh()">Refresh</button>
      </div>
      <div id="selrow">
        <button onclick="sketchup.selhide()">Hide selection in this scene</button>
        <button onclick="sketchup.selshow()">Show selection in this scene</button>
      </div>
      <div class="hint">The selection buttons write straight into this scene —
        for a callout you would rather click in the model than find in the list.</div>
      <div id="status"></div>
      <script>
        var S = { sets: [], loose: [], scene: null };
        var picks = {}, expanded = {};
        function esc(s){ return String(s==null?"":s).replace(/&/g,"&amp;")
          .replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;")
          .replace(/'/g,"&#39;"); }
        var KIND = { text:"text", dim:"dim", "3d":"3D" };
        function itemRow(it, member, setHidden){
          var dis = member && setHidden;
          return "<div class='row"+(member?" member":"")+(dis?" dis":"")+"'>"+
            "<label><input type='checkbox' data-key='"+esc(it.key)+"'"+
            (picks[it.key]?" checked":"")+(dis?" disabled":"")+">"+
            "<span class='kind'>"+KIND[it.kind]+"</span>"+
            "<span class='txt' title='"+esc(it.full)+"'>"+esc(it.text)+"</span>"+
            (it.tag && it.tag!=="Untagged" ? "<span class='cnt'>"+esc(it.tag)+"</span>" : "")+
            "</label>"+
            (dis ? "<span class='with'>hidden with the set</span>" : "")+
            "<button class='find' data-find='"+esc(it.key)+"'>SHOW ME</button></div>";
        }
        function render() {
          document.getElementById('scene').textContent =
            S.noscene ? 'NO SCENES IN THIS MODEL' : (S.scene || '(none selected)');
          var warn = document.getElementById('warn');
          if (S.off && S.off.length) {
            document.getElementById('warntext').textContent =
              'These scenes do not save hidden tags or objects, so callouts ' +
              'will not come back on them: ' + S.off.join(', ');
            warn.style.display = 'block';
          } else { warn.style.display = 'none'; }
          var any = (S.sets && S.sets.length) || (S.loose && S.loose.length);
          document.getElementById('empty').style.display = any ? 'none' : 'block';
          var h = "<div class='grp'><div class='grph'>Annotation sets"+
            "<span class='links'><a data-all='sets'>all</a> &middot; "+
            "<a data-none='sets'>none</a></span></div>";
          h += (S.sets||[]).map(function(u){
            var on = !!picks[u.key], ex = !!expanded[u.key];
            var r = "<div class='row'><button class='exp' data-exp='"+esc(u.key)+"'>"+
              (ex?"&#9660;":"&#9654;")+"</button>"+
              "<label><input type='checkbox' data-key='"+esc(u.key)+"'"+(on?" checked":"")+">"+
              "<span class='txt'>"+esc(u.name)+"</span>"+
              "<span class='cnt'>"+esc(u.cnt)+"</span></label>"+
              "<button class='find' data-find='"+esc(u.key)+"'>SHOW ME</button></div>";
            if(ex) r += u.members.length
              ? u.members.map(function(m){ return itemRow(m, true, on); }).join("")
              : "<div class='row member'><span class='cnt'>nothing on this tag</span></div>";
            return r;
          }).join("") + "</div>";
          h += "<div class='grp'><div class='grph'>Not in a set — tick one by one"+
            "<span class='links'><a data-all='loose'>all</a> &middot; "+
            "<a data-none='loose'>none</a></span></div>";
          h += (S.loose||[]).map(function(it){ return itemRow(it, false, false); }).join("");
          h += "</div>";
          document.getElementById('list').innerHTML = h;
          document.getElementById('move').innerHTML =
            "<span class='lbl'>Move selection into a set — optional, for every scene</span>"+
            "<select id='mset'>"+(S.sets||[]).map(function(u){
              return "<option value='"+esc(u.name)+"'>"+esc(u.name)+"</option>"; }).join("")+
            "<option value='__new'>New set&hellip;</option></select>"+
            "<span class='prefix' id='mpre'>WR-Notes-</span>"+
            "<input id='mnew' placeholder='Plan'>"+
            "<button id='mgo'>MOVE SELECTION INTO SET</button>"+
            // The create row. Its own always-visible field rather than
            // reusing the move dropdown's "New set…": creating a set has
            // nothing to do with the selection, and making someone pick
            // "New set…" out of a MOVE control to do it reads as though a
            // move is about to happen. Same input and button styling as the
            // row above — the only difference is that this one is never
            // hidden, hence the class 'show' baked in.
            "<span class='lbl two'>Create an empty set &mdash; no selection needed</span>"+
            "<span class='prefix show'>WR-Notes-</span>"+
            "<input id='cnew' class='show' placeholder='Plan'>"+
            "<button id='cgo'>CREATE SET</button>";
          wire();
        }
        function wire(){
          var root = document.body;
          Array.prototype.forEach.call(root.querySelectorAll("input[data-key]"), function(el){
            el.addEventListener("change", function(){
              picks[el.getAttribute("data-key")] = el.checked;
              markDirty();
              if(el.getAttribute("data-key").charAt(0)==="t") render();
            });
          });
          Array.prototype.forEach.call(root.querySelectorAll("[data-exp]"), function(el){
            el.addEventListener("click", function(){
              var k = el.getAttribute("data-exp"); expanded[k] = !expanded[k]; render();
            });
          });
          Array.prototype.forEach.call(root.querySelectorAll("[data-find]"), function(el){
            el.addEventListener("click", function(){
              sketchup.reveal(el.getAttribute("data-find"));
            });
          });
          Array.prototype.forEach.call(root.querySelectorAll("[data-all],[data-none]"), function(el){
            el.addEventListener("click", function(){
              var grp = el.getAttribute("data-all") || el.getAttribute("data-none"),
                  on = el.hasAttribute("data-all");
              (grp==="sets" ? (S.sets||[]) : (S.loose||[])).forEach(function(u){
                picks[u.key] = on;
              });
              markDirty(); render();
            });
          });
          var ms = document.getElementById("mset");
          if(ms) ms.addEventListener("change", function(){
            var isNew = ms.value === "__new";
            document.getElementById("mnew").className = isNew ? "show" : "";
            document.getElementById("mpre").className = "prefix" + (isNew ? " show" : "");
          });
          var mg = document.getElementById("mgo");
          if(mg) mg.addEventListener("click", function(){
            var v = document.getElementById("mset").value;
            var name = v === "__new" ? document.getElementById("mnew").value : v;
            sketchup.move(JSON.stringify({ name: name }));
          });
          var cg = document.getElementById("cgo");
          if(cg) cg.addEventListener("click", function(){
            // No field clearing here: create pushes fresh state, render()
            // rebuilds this strip from scratch, and the new set arrives as a
            // row. Ruby owns whether the name was usable, so the empty case
            // is not second-guessed in JS.
            sketchup.newset(JSON.stringify({
              name: document.getElementById("cnew").value }));
          });
          var cn = document.getElementById("cnew");
          if(cn) cn.addEventListener("keydown", function(ev){
            if(ev.key === "Enter" && cg) cg.click();   // typing a name then
          });                                          // Enter is the reflex
        }
        function markDirty() { document.getElementById('apply').className = 'dirty'; }
        function collectPicks() {
          // EVERY row is sent, not only the ticked ones, so unticking reliably
          // shows again — the walls rule. A member row behind a collapsed set
          // is not in the DOM, so its remembered pick is sent from the state.
          var out = {};
          (S.sets||[]).forEach(function(u){
            out[u.key] = !!picks[u.key];
            (u.members||[]).forEach(function(m){ out[m.key] = !!picks[m.key]; });
          });
          (S.loose||[]).forEach(function(it){ out[it.key] = !!picks[it.key]; });
          return out;
        }
        function applyNow() { sketchup.apply(JSON.stringify(collectPicks())); }
        function applyAll() { sketchup.applyall(JSON.stringify(collectPicks())); }
        function setState(json) {
          S = JSON.parse(json);
          picks = {};
          (S.sets||[]).forEach(function(u){
            if(u.hidden) picks[u.key] = true;
            (u.members||[]).forEach(function(m){ if(m.hidden) picks[m.key] = true; });
          });
          (S.loose||[]).forEach(function(it){ if(it.hidden) picks[it.key] = true; });
          document.getElementById('apply').className = '';
          render();
        }
        function setPicked(json) {
          var r = JSON.parse(json), n = 0;
          (r.keys||[]).forEach(function(k){ picks[k] = true; n++; });
          markDirty(); render();
          setStatus(n ? (n + " callout(s) ticked from your selection." +
                         (r.hint ? " All of them are on " + r.hint +
                                   " — tick the set to hide the whole set." : ""))
                      : "Nothing in your selection is a note, a dimension or a 3D label.");
        }
        function setStatus(t) { document.getElementById('status').textContent = t; }
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

  # Reload the list when the operator clicks a scene tab, so it always
  # describes the scene on screen. Unapplied picks are dropped on purpose —
  # they were picks for the scene that was just left. (Walls' rule, verbatim.)
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
      :dialog_title => 'Hide notes & dimensions per scene',
      :preferences_key => 'WR_SceneAnnotations',
      :width => 580, :height => 660, :resizable => true,
      :style => UI::HtmlDialog::STYLE_DIALOG
    )
    @dlg.set_html(html)
    @dlg.add_action_callback('apply') do |_c, payload|
      picks = JSON.parse(payload) rescue {}
      ok, msg = apply(Sketchup.active_model, picks)
      push_state(Sketchup.active_model)
      status(msg)
      puts "WR_SceneAnnotations: #{msg}" unless ok
    end
    # Every scene, one undo, confirmed by name first (see apply_all).
    @dlg.add_action_callback('applyall') do |_c, payload|
      picks = JSON.parse(payload) rescue {}
      m = Sketchup.active_model
      if confirm_all?(m.pages.to_a, 'annotation')
        _ok, msg, det = apply_all(m, picks)
        puts "WR_SceneAnnotations: #{msg}"
        (det ? det[:written] : []).each { |nm| puts "  written: #{nm}" }
      else
        msg = 'Not applied — nothing was changed.'
      end
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
    @dlg.add_action_callback('pick') do |_c|
      keys, hint, _others = keys_for_selection(Sketchup.active_model)
      payload = { 'keys' => keys, 'hint' => hint }.to_json
      @dlg.execute_script("setPicked(#{payload.inspect})")
    end
    @dlg.add_action_callback('reveal') do |_c, key|
      _ok, msg = reveal(Sketchup.active_model, key.to_s)
      status(msg)
    end
    @dlg.add_action_callback('move') do |_c, payload|
      req = (JSON.parse(payload.to_s) rescue {})
      _ok, msg = move_selection_to_set(Sketchup.active_model, req['name'])
      push_state(Sketchup.active_model)
      status(msg)
    end
    @dlg.add_action_callback('newset') do |_c, payload|
      req = (JSON.parse(payload.to_s) rescue {})
      _ok, msg = create_set(Sketchup.active_model, req['name'])
      # push_state unconditionally, success or not: inventory lists every
      # family tag present, so this is what puts the new (empty) set on
      # screen as a row — unticked, because nothing on it is hidden yet.
      push_state(Sketchup.active_model)
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

WR_SceneAnnotations.open unless $wr_suppress_autorun || $wr_no_autorun
