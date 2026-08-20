# @title Toggle Draft / Render mode...
# @cat Tidy up the model
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
#   - the active style
#   - shadow_info (DisplayShadows, UseSunForAllShading, Light, Dark)
#
# BOTH STATES ARE REMEMBERED, NOT ASSUMED
#
# Before applying the target mode, this script snapshots whatever the model
# is ACTUALLY showing right now and saves it as "the state this mode was left
# in" — in an attribute dictionary, so it survives a save. The very first
# toggle a model ever sees has no such snapshot to draw on, so a small,
# clearly-commented default is used instead (dims on for draft, dims off for
# render, shadows on for a photographic look). Every toggle after that
# restores exactly what was there before, including any hand-tweaked style or
# shadow setting from the last time this mode was active — never a hard-coded
# default fighting a choice Benton already made in the viewport.
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

$wr_no_autorun_was = $wr_no_autorun
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
  $wr_no_autorun = $wr_no_autorun_was
end

module WR_Mode
  %w[DICT DIM_TAGS DEFAULT].each { |c| remove_const(c) if const_defined?(c, false) }

  DICT = 'WR_Mode'.freeze

  DIM_TAGS = WR_ProposalScenes::DIM_TAGS

  # Used only the very first time a model enters a mode with no stored
  # snapshot yet. Not a measurement, not a claim about what any given model
  # should look like — a starting point that gets overwritten by the real
  # state the moment the model leaves that mode again.
  DEFAULT = {
    'draft'  => { 'dims'   => DIM_TAGS.each_with_object({}) { |n, h| h[n] = true },
                  'style'  => nil,
                  'shadow' => { 'DisplayShadows' => true, 'UseSunForAllShading' => false,
                                'Light' => WR_Shading::DEF_LIGHT, 'Dark' => WR_Shading::DEF_DARK } },
    'render' => { 'dims'   => DIM_TAGS.each_with_object({}) { |n, h| h[n] = false },
                  'style'  => nil,
                  'shadow' => { 'DisplayShadows' => true, 'UseSunForAllShading' => false,
                                'Light' => WR_Shading::DEF_LIGHT, 'Dark' => WR_Shading::DEF_DARK } }
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
    d = model.attribute_dictionaries[DICT] || model.attribute_dictionaries.add(DICT)
    d[mode] = snap.to_json
    d['current'] = current
  end

  # ---------------------------------------------------------------- reading --

  def self.snapshot(model)
    ro_style = (model.styles.selected_style.name rescue nil)
    si = model.shadow_info
    { 'dims'   => DIM_TAGS.each_with_object({}) { |n, h| l = model.layers[n]; h[n] = l ? l.visible? : nil },
      'style'  => ro_style,
      'shadow' => WR_Shading::SHADOW_KEYS.each_with_object({}) { |k, h| h[k] = (si[k] rescue nil) } }
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
        save(model, other, snapshot(model), other)
      end

      mat_result = target == 'render' ? WR_MaterialsSwap.to_render(model) : WR_MaterialsSwap.to_draft(model)

      target_snap = st[target] || DEFAULT[target]
      stuck = apply_snapshot(model, target_snap)

      # Read back what actually landed, not what was asked for, so a stuck
      # shadow key doesn't get silently recorded as "restores exactly" next
      # time this mode is entered.
      save(model, target, snapshot(model), target)
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

  def self.report(result)
    lines = ['']
    lines << "MODE — now #{result[:to].upcase} (was #{(result[:from] || 'unknown').to_s.upcase})"
    lines.concat(WR_MaterialsSwap.report_lines('materials', result[:materials]))
    unless result[:stuck].empty?
      lines << '  *** style/shadow keys that would not take:'
      result[:stuck].each { |s| lines << "        #{s}" }
    end
    lines << ''
    lines.each { |l| puts l }
    UI.messagebox(lines.join("\n"))
  end
end

WR_Mode.run unless $wr_no_autorun
