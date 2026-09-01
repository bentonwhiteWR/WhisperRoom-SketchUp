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
# every piece after its wall run: "Wall 3", "Wall 3 (upper)", "Header 3",
# "Opening 3", "Door leaf 3", "Swing 3". One wall in this dialog is ALL of
# those pieces for one run of one room, so hiding it never strands a door
# leaf floating in space where its wall used to be. Rooms drawn by hand or
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
  def self.each_piece(ents, depth = 0, &blk)
    ents.grep(Sketchup::Group).each do |g|
      nm = g.name.to_s
      if nm =~ PIECE_RE
        blk.call(g, Regexp.last_match(1), Regexp.last_match(2).to_i)
      elsif depth < DEPTH
        each_piece(g.entities, depth + 1, &blk)
      end
    end
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
  def self.inventory(model)
    @units = {}
    out = []
    roots = model.entities.grep(Sketchup::Group)
    roots.each do |room|
      per_run = Hash.new { |h, k| h[k] = { :wall => [], :extra => [] } }
      each_piece(room.entities) do |g, kind, n|
        (kind == 'Wall' ? per_run[n][:wall] : per_run[n][:extra]) << g
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
                  :pieces => u[:wall] + u[:extra] }
        @units[key] = unit
        out << unit
      end
    end
    out
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
    gone = []
    changed = 0
    model.start_operation('Hide walls per scene', true)
    begin
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
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      return [false, "Apply failed and was rolled back: #{e.class}: #{e.message}"]
    end
    msg = "Saved to scene \"#{page.name}\" — #{changed} piece(s) set."
    msg += " #{gone.size} wall(s) were stale and skipped — hit Refresh." unless gone.empty?
    off = pages_not_saving_hidden(model)
    unless off.empty?
      msg += " WARNING: scene(s) not saving hidden objects (walls will NOT " \
             "come back on them): #{off.join(', ')}."
    end
    [true, msg]
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

  def self.state_json(model)
    units = inventory(model)
    page  = model.pages.selected_page
    { 'scene'   => page ? page.name.to_s : nil,
      'noscene' => model.pages.count.zero?,
      'off'     => pages_not_saving_hidden(model),
      'units'   => units.map do |u|
        { 'key' => u[:key], 'room' => u[:room], 'wall' => u[:wall],
          'side' => u[:side], 'hidden' => u[:hidden], 'mixed' => u[:mixed],
          'pieces' => u[:pieces].size }
      end }.to_json
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
      <div id="foot">
        <button id="apply" onclick="applyNow()">Apply to this scene</button>
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
        var S = { units: [], scene: null };
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
        }
        function markDirty() { document.getElementById('apply').className = 'dirty'; }
        function applyNow() {
          var picks = {};
          S.units.forEach(function (u) { picks[u.key] = !!u.hidden; });
          sketchup.apply(JSON.stringify(picks));
        }
        function setState(json) {
          S = JSON.parse(json);
          document.getElementById('apply').className = '';
          render();
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
