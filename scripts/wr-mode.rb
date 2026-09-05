# @title Toggle draft / render mode...
# @cat V-Ray renders
# @rank 1
#
# Draft <-> Render, one press. "Draft" is the model built to be measured:
# drafting materials, every WhisperRoom dimension tag visible. "Render" is the
# model built to be photographed: whatever V-Ray materials are filling
# wr-materials-swap.rb's slots, every dimension tag off. Today that switch
# gets made by hand from memory, which is exactly where a dimension string
# left on in a hero render comes from.
#
# THIS FILE NEVER TOUCHES A MATERIAL. It calls wr-materials-swap.rb for that
# half and only that half. An exporter that swapped materials without also
# flipping tags would ship a render-material model with dimensions still
# switched on — the two have to move together, and the way to guarantee that
# is to make one script own both and never let a caller do half the job.
#
# WHAT ELSE FLIPS
#
#   - every dimension tag in proposal-scenes.rb's DIM_TAGS list — not a
#     shorter list invented here. A tag proposal-scenes.rb knows about and
#     this one doesn't is exactly how a booth catalogue number would sneak
#     onto a clean exterior plate.
#   - the "WR Lights" tag (LIGHT_TAGS), OPPOSITE polarity to the dims:
#     hidden in draft, visible in render — so a V-Ray pass never runs with
#     the interior lights switched off and quietly renders an unlit booth.
#   - the active style
#   - shadow_info (DisplayShadows, UseSunForAllShading, Light, Dark)
#   - rendering_options' AmbientOcclusion (RO_KEYS) — the soft contact
#     shading under the booth lives HERE, not in shadow_info. Turning sun
#     shadows off alone still leaves those AO puddles in a draft view.
#
# BOTH STATES ARE REMEMBERED, NOT ASSUMED
#
# Before applying the target mode, this script snapshots whatever the model
# is ACTUALLY showing right now and saves it as "the state this mode was left
# in" — in an attribute dictionary, so it survives a save. The very first
# toggle a model ever sees has no such snapshot to draw on, so a small,
# clearly-commented default is used instead (dims on for draft, dims off for
# render, shadows on in render for a photographic look, shadows and AO off
# in draft for a flat measurable one). Every toggle after that
# restores exactly what was there before, including any hand-tweaked style or
# shadow setting from the last time this mode was active — never a hard-coded
# default fighting a choice Benton already made in the viewport.
#
# TWO EXCEPTIONS, both POLICY rather than memory:
#
#   1. LIGHT_TAGS. A light tag hidden while in render mode must never be
#      memorised as "the render state" — that records a silently-unlit
#      V-Ray pass forever — so every snapshot has its light keys pinned to
#      the mode's polarity (see pin_light_tags).
#   2. DRAFT IS FLAT (2026-08-27, Benton: "I still see shadows in draft").
#      Draft mode MEANS a clean, flat, shadow-free image, so every DRAFT
#      snapshot has DisplayShadows and AmbientOcclusion pinned OFF (see
#      pin_draft_flat) — which also heals the snapshot every already-toggled
#      model stored back when draft's default kept shadows on. RENDER
#      snapshots stay pure memory for these keys: V-Ray owns the
#      photographic look, and a shadow choice made there is respected.
#      The cost, stated plainly: shadows or AO turned on while sitting in
#      draft mode survive until the next toggle and are then forgotten —
#      they are the one viewport choice the toggle now refuses to remember.
#
# The dimension tags, style, sun position and Light/Dark values keep the
# full remember-what-was-showing contract.
#
# TOUCHES NO GEOMETRY. Fully reversible: everything this script changes is a
# tag's visibility, the selected style, a shadow_info key or a material
# assignment, all inside one start_operation, so one Ctrl+Z undoes the whole
# flip.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-mode.rb"
#
# THIS FILE HAS NOT BEEN RUN. There is no ruby.exe on this machine outside
# SketchUp, so nothing here has executed — only parsed with rbparse.py, which
# checks syntax, not behaviour.

require 'sketchup.rb'
require 'json'

# The saved value MUST be a local, not a global. A nested load below runs this
# same dance on $wr_no_autorun and would clobber a shared $wr_no_autorun_was,
# so the ensure would 'restore' true and this file's own autorun would never
# fire - a panel button that does nothing, silently. (2026-08-27)
wr_mode_autorun_was = $wr_no_autorun
$wr_no_autorun = true
begin
  load File.join(File.dirname(__FILE__), 'wr-materials-swap.rb')
  load File.join(File.dirname(__FILE__), 'wr-shading.rb')
  # proposal-scenes.rb IS a command (it has its own autorun line), so it is
  # loaded under the same guard purely to reuse its DIM_TAGS constant and stay
  # the single source of truth CLAUDE.md asks for — never a second, shorter
  # list invented here that quietly drifts from the real one.
  load File.join(File.dirname(__FILE__), 'proposal-scenes.rb')
ensure
  $wr_no_autorun = wr_mode_autorun_was
end

module WR_Mode
  %w[DICT DIM_TAGS NOTE_TAGS ANNOT_TAGS LIGHT_TAGS RO_KEYS DEFAULT].each { |c| remove_const(c) if const_defined?(c, false) }

  DICT = 'WR_Mode'.freeze

  DIM_TAGS = WR_ProposalScenes::DIM_TAGS

  # WR-Notes -- build-room.rb's ceiling banner and anything else written as a
  # construction note. DEFECT D5, OBSERVED 30 Aug 2026: this tag was in NO
  # mode's tag list, so no mode ever hid it and the banner "Ceiling 8'-0" -
  # HOUSE DEFAULT, not measured. Confirm before quoting." was exported onto a
  # client image. It shares DIM_TAGS' polarity (shown in draft, hidden in
  # render), so ANNOT_TAGS is what the mode machinery manages from 1.9.3 on.
  # DIM_TAGS is still exported unchanged for wr-preflight.rb and
  # proposal-scenes.rb, which mean dimensions specifically.
  NOTE_TAGS  = WR_ProposalScenes::NOTE_TAGS
  ANNOT_TAGS = WR_ProposalScenes::ANNOT_TAGS

  # Interior-light tags (wr-drop-lights.rb). OPPOSITE polarity to DIM_TAGS:
  # hidden in draft, visible in render. Getting this backwards makes the
  # V-Ray pass render an unlit booth — a silent, plausible-looking failure.
  LIGHT_TAGS = ['WR Lights'].freeze

  # model.rendering_options keys under mode management. AmbientOcclusion is
  # the soft contact shading under the booth — a rendering option, NOT a
  # shadow_info key, which is why turning DisplayShadows off never removed
  # it. Same key name wr-shading.rb's TRANSPARENCY set already writes; the
  # apply read-back below reports it as stuck if this SketchUp build does
  # not know the key, rather than silently doing nothing.
  RO_KEYS = ['AmbientOcclusion'].freeze

  # Used only the very first time a model enters a mode with no stored
  # snapshot yet. Not a measurement, not a claim about what any given model
  # should look like — a starting point that gets overwritten by the real
  # state the moment the model leaves that mode again. (For draft's shadow
  # and AO keys the pin_draft_flat policy makes the same OFF choice on
  # every entry, not just the first — see the header.)
  DEFAULT = {
    'draft'  => { 'dims'   => ANNOT_TAGS.each_with_object({}) { |n, h| h[n] = true }
                              .merge(LIGHT_TAGS.each_with_object({}) { |n, h| h[n] = false }),
                  'style'  => nil,
                  # Draft is the flat, measurable look: no sun shadows, no AO.
                  'shadow' => { 'DisplayShadows' => false, 'UseSunForAllShading' => false,
                                'Light' => WR_Shading::DEF_LIGHT, 'Dark' => WR_Shading::DEF_DARK },
                  'ro'     => { 'AmbientOcclusion' => false } },
    'render' => { 'dims'   => ANNOT_TAGS.each_with_object({}) { |n, h| h[n] = false }
                              .merge(LIGHT_TAGS.each_with_object({}) { |n, h| h[n] = true }),
                  'style'  => nil,
                  'shadow' => { 'DisplayShadows' => true, 'UseSunForAllShading' => false,
                                'Light' => WR_Shading::DEF_LIGHT, 'Dark' => WR_Shading::DEF_DARK },
                  # An empty hash on purpose: a first entry into render leaves
                  # AO exactly as the viewport sits — V-Ray owns that look.
                  'ro'     => {} }
  }.freeze

  # --------------------------------------------------------------- storage --

  def self.data(model)
    d = model.attribute_dictionary(DICT)
    return { 'current' => nil, 'draft' => nil, 'render' => nil } if d.nil?
    { 'current' => d['current'],
      'draft'   => (d['draft']  ? JSON.parse(d['draft'])  : nil),
      'render'  => (d['render'] ? JSON.parse(d['render']) : nil) }
  rescue StandardError
    { 'current' => nil, 'draft' => nil, 'render' => nil }
  end

  def self.save(model, mode, snap, current)
    # Sketchup::AttributeDictionaries has NO #add — set_attribute creates the
    # dictionary on demand and is what the rest of this toolset uses.
    model.set_attribute(DICT, mode, snap.to_json)
    model.set_attribute(DICT, 'current', current)
  end

  # ---------------------------------------------------------------- reading --

  def self.snapshot(model)
    ro_style = (model.styles.selected_style.name rescue nil)
    si = model.shadow_info
    ro = model.rendering_options
    { 'dims'   => (ANNOT_TAGS + LIGHT_TAGS).each_with_object({}) { |n, h| l = model.layers[n]; h[n] = l ? l.visible? : nil },
      'style'  => ro_style,
      'shadow' => WR_Shading::SHADOW_KEYS.each_with_object({}) { |k, h| h[k] = (si[k] rescue nil) },
      'ro'     => RO_KEYS.each_with_object({}) { |k, h| h[k] = (ro[k] rescue nil) } }
  end

  # LIGHT_TAGS are POLICY, never memory: hidden in draft, visible in
  # render, whatever the tag happened to be showing when a mode was left.
  # Without this pin, hiding "WR Lights" while IN render mode gets
  # memorised as render state by the leave-mode snapshot and re-applied on
  # every future entry into render — a silently unlit V-Ray pass that
  # persists itself forever (and survives the missing-key backfill, which
  # fills only ABSENT keys). So every snapshot is pinned at both ends:
  # before it is saved and before it is applied — the apply-side pin also
  # heals snapshots a pre-fix plugin already poisoned. The DIM_TAGS keys
  # keep the full remember-what-was-showing contract; only light keys are
  # pinned.
  def self.pin_light_tags(snap, mode)
    return snap if snap.nil? || snap['dims'].nil?
    LIGHT_TAGS.each { |n| snap['dims'][n] = (mode == 'render') }
    snap
  end

  # DRAFT'S FLATNESS IS POLICY TOO (exception 2 in the header). A draft
  # snapshot has DisplayShadows and every RO_KEYS key pinned OFF — creating
  # the sub-hashes when a pre-fix snapshot lacks them, which is exactly how
  # a snapshot stored under the old shadows-on default gets healed on its
  # next apply instead of preserving the fault forever. A render snapshot
  # passes through untouched: those keys stay pure memory there. Sun
  # position (UseSunForAllShading) and Light/Dark are NOT pinned — they do
  # not put shadows on the floor and stay remembered.
  def self.pin_draft_flat(snap, mode)
    return snap if snap.nil? || mode != 'draft'
    (snap['shadow'] ||= {})['DisplayShadows'] = false
    ro = (snap['ro'] ||= {})
    RO_KEYS.each { |k| ro[k] = false }
    snap
  end

  # Every snapshot point applies BOTH policy pins through this one call, so
  # no future call site can pick up one pin and forget the other.
  def self.pin_policy(snap, mode)
    pin_draft_flat(pin_light_tags(snap, mode), mode)
  end

  # Stamp LIGHT_TAGS into every saved scene at this mode's polarity. Failures
  # are collected, not raised: a page that refuses the write is a cosmetic
  # problem on one scene, and aborting the whole mode switch over it would be
  # worse. Returns the pages that refused, so a caller can say so.
  def self.stamp_light_pages(model, mode)
    want = (mode == 'render')
    bad  = []
    LIGHT_TAGS.each do |n|
      l = model.layers[n]
      next if l.nil?
      model.pages.each do |pg|
        begin
          pg.set_visibility(l, want)
        rescue StandardError => e
          bad << "#{pg.name}/#{n}: #{e.class}"
        end
      end
    end
    puts "  light tags: #{bad.size} scene stamp(s) refused — #{bad.join(', ')}" unless bad.empty?
    bad
  rescue StandardError => e
    puts "  light tags: could not stamp the scenes (#{e.class}: #{e.message})"
    []
  end

  def self.apply_snapshot(model, snap)
    return if snap.nil?
    (snap['dims'] || {}).each { |n, v| l = model.layers[n]; (l.visible = v) if l && !v.nil? }
    if snap['style']
      st = WR_Shading.find_style(model, snap['style'])
      (model.styles.selected_style = st) rescue nil if st
    end
    si = model.shadow_info
    stuck = []
    (snap['shadow'] || {}).each do |k, v|
      next if v.nil?
      begin
        si[k] = v
      rescue StandardError => e
        stuck << "shadow #{k}: write raised #{e.class}"
        next
      end
      got = (si[k] rescue :unreadable)
      stuck << "shadow #{k}: wanted #{v.inspect}, still #{got.inspect}" unless got == v
    end
    # AO and friends live in rendering_options, not shadow_info — same
    # write-then-read-back discipline, because an unknown key here fails
    # SILENTLY (the []= just does nothing) and only the read-back shows it.
    ro = model.rendering_options
    (snap['ro'] || {}).each do |k, v|
      next if v.nil?
      begin
        ro[k] = v
      rescue StandardError => e
        stuck << "render-option #{k}: write raised #{e.class}"
        next
      end
      got = (ro[k] rescue :unreadable)
      stuck << "render-option #{k}: wanted #{v.inspect}, still #{got.inspect}" unless got == v
    end
    stuck
  end

  # ------------------------------------------------------------- direction --

  # Explicit direction, not a toggle — the caller says which mode it wants.
  # wr-preflight.rb and wr-pack-export.rb both need "make sure this is
  # render" rather than "flip whatever it currently is", because a naive
  # toggle called twice by mistake would put a model back in draft with
  # nobody the wiser.
  def self.to_mode(model, target)
    other = target == 'draft' ? 'render' : 'draft'
    st = data(model)

    model.start_operation("WR Mode: #{target.capitalize}", true)
    begin
      # Save whatever the model is actually showing right now as the OTHER
      # mode's snapshot, if it is currently in that other mode (or if this is
      # the very first toggle and nothing has been recorded at all — in which
      # case "whatever is showing now" is as good a guess at "draft" as any).
      current = st['current']
      if current == other || current.nil?
        save(model, other, pin_policy(snapshot(model), other), other)
      end

      mat_result = target == 'render' ? WR_MaterialsSwap.to_render(model) : WR_MaterialsSwap.to_draft(model)

      # Deep-copy the DEFAULT (JSON round-trip) so the pin below can never
      # write into the shared frozen constant's inner hashes.
      target_snap = st[target] || JSON.parse(DEFAULT[target].to_json)

      # Pin the policy keys to this mode's polarity — this both fills keys
      # missing from older snapshots AND overrides a wrong state a pre-fix
      # plugin memorised: a hidden light tag in render (pin_light_tags), or
      # shadows/AO on in draft (pin_draft_flat — every model toggled before
      # 2026-08-27 stored its draft snapshot with shadows on). Dim keys are
      # left exactly as the snapshot recorded them.
      pin_policy(target_snap, target)

      stuck = apply_snapshot(model, target_snap)

      # AND INTO EVERY SAVED SCENE, OR THE HIDE LASTS UNTIL THE NEXT CLICK.
      #
      # A SketchUp page restores its own saved tag visibility when it is
      # activated. wr-drop-lights.rb stamps "WR Lights" VISIBLE into every
      # scene on purpose (stamp_tag_into_pages) so a V-Ray pass can never
      # render silently unlit -- which also meant that toggling to draft hid
      # the lights and the tool-owned ceiling in the viewport, and clicking any
      # scene tab brought them straight back. The tag was right; the pages
      # outvoted it.
      #
      # So the pages are stamped to the SAME polarity the mode just applied:
      # hidden in draft, visible in render. That keeps the never-unlit
      # guarantee exactly as it was for render, and makes the draft hide
      # survive a scene click. Only LIGHT_TAGS are stamped -- the annotation
      # tags keep their per-scene memory, which is a real part of a drawing.
      stamp_light_pages(model, target)

      # Read back what actually landed, not what was asked for, so a stuck
      # shadow key doesn't get silently recorded as "restores exactly" next
      # time this mode is entered — pinned too, so a light tag or shadow/AO
      # state a stuck write left wrong cannot be memorised either.
      save(model, target, pin_policy(snapshot(model), target), target)
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      raise e
    end

    { :from => current, :to => target, :materials => mat_result, :stuck => (stuck || []) }
  end

  def self.to_render(model)
    to_mode(model, 'render')
  end

  def self.to_draft(model)
    to_mode(model, 'draft')
  end

  def self.current(model)
    data(model)['current'] || 'unknown (never toggled)'
  end

  # ------------------------------------------------------------------ panel --

  # The toggle a person actually presses: flip to whichever mode it is not
  # currently in. Anything needing a specific direction should call to_render
  # / to_draft above instead of this.
  def self.run
    model = Sketchup.active_model
    cur = data(model)['current']
    target = cur == 'render' ? 'draft' : 'render'
    result = to_mode(model, target)
    report(result)
  rescue StandardError => e
    UI.messagebox("Mode toggle failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end

  def self.onoff(v)
    return 'ON'  if v == true
    return 'OFF' if v == false
    'unreadable'
  end

  def self.report(result)
    lines = ['']
    lines << "MODE — now #{result[:to].upcase} (was #{(result[:from] || 'unknown').to_s.upcase})"
    # The model is passed so a zero-match sweep is diagnosed here too -- the
    # Ruby Console has to tell the same story as the Proposal Package log.
    lines.concat(WR_MaterialsSwap.report_lines('materials', result[:materials],
                                               Sketchup.active_model))
    # What the viewport is ACTUALLY showing now, read back from the model
    # rather than echoed from the request — so "shadows OFF" here is a
    # fact, and a key that refused shows up both as ON here and by name in
    # the stuck list below.
    begin
      m = Sketchup.active_model
      sh = (m.shadow_info['DisplayShadows'] rescue nil)
      ao = (m.rendering_options['AmbientOcclusion'] rescue nil)
      lines << "  shadows #{onoff(sh)}, ambient occlusion #{onoff(ao)}" \
               "#{result[:to] == 'draft' ? ' (draft policy: both OFF)' : ''}"
    rescue StandardError
      nil
    end
    unless result[:stuck].empty?
      lines << '  *** shadow / render-option keys that would not take:'
      result[:stuck].each { |s| lines << "        #{s}" }
    end
    lines << ''
    lines.each { |l| puts l }
    UI.messagebox(lines.join("\n"))
  end
end

WR_Mode.run unless $wr_no_autorun
