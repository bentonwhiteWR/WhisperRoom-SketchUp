# wr-shading.rb — the ONE shading contract every component-art exporter uses.
#
# NOT A COMMAND. This is a library, loaded by export-component-art.rb and
# angled-component-art.rb. It is in wr_tools' SKIP list so it does not appear in
# the panel as something to run.
#
# ---------------------------------------------------------------------------
# WHY THIS FILE EXISTS
#
# The flat walk-around set and the angled Iso30 set are shown side by side in
# the booth builder, and the flat set came out visibly lighter. Two exporters,
# two different contracts:
#
#   - export-component-art.rb ACTIVATES each scene, so each scene's stored
#     style applies. angled-component-art.rb never activates a scene — it reads
#     the stored camera and renders under whatever style the viewport happens to
#     hold. Same model, two different styles, no warning. This is the same root
#     cause as the missing-edge-lines batch.
#   - angled-component-art.rb ran the brightness recovery pass; the flat one had
#     no recovery step at all.
#   - Neither touched shadow_info, so face shading was left to whatever the
#     model was last saved with.
#
# Matching them by eye means re-tuning after every model save. Matching them by
# construction means both scripts push THIS contract, both read it back, and
# both report what they actually got.
#
# ---------------------------------------------------------------------------
# WHAT IS AND IS NOT FIXABLE HERE
#
# A flat elevation puts the face perpendicular to the camera, where it catches
# the most light. An Iso30 view puts every visible face oblique, so all of them
# read darker — that is geometry, not a material. Lightening the material in
# SketchUp would fix the iso and blow out the elevation, because the material is
# shared. The lever that actually flattens the difference is the shadow
# settings' DARK value: it lifts the unlit faces toward the lit ones without
# touching the material.
#
# DARK IS THE ONE NUMBER TO TUNE. Both exporters expose it as a dialog field,
# both default to the same value, and both print what they got. Raise it toward
# 70 and the angled set climbs toward the flat set. Nothing else needs changing,
# and nothing about the model needs saving.
#
# The Light/Dark VALUES here are a starting point, not a measurement — no Ruby
# runs outside SketchUp, so they have never been rendered. The KEYS are the
# mechanism and they are read back after every write, so a key this SketchUp
# build refuses shows up as stuck instead of failing silently.

require 'sketchup.rb'

module WR_Shading
  # Every one of these fills or tints the WHOLE frame, so any left on means
  # write_image returns an opaque image. The alpha channel came back 191
  # everywhere until these were found. None of them change the geometry's own
  # appearance, so turning them off still honours "use the model's own style".
  #
  # remove_const rather than `unless defined?`. The guard silences the reload
  # warning and also freezes the value for the session — edit a number, reload,
  # nothing happens. That cost four rounds on wr-deck.rb before it was spotted.
  # This way the values update on reload and there is still no warning.
  %w[TRANSPARENCY DEF_LIGHT DEF_DARK SHADOW_KEYS KEEP].each do |c|
    remove_const(c) if const_defined?(c, false)
  end

  TRANSPARENCY = { 'DrawGround'        => false,
                   'DrawHorizon'       => false,
                   'DisplayFog'        => false,
                   'DisplayWatermarks' => false,
                   'AmbientOcclusion'  => false }.freeze

  # SketchUp's own default is Light 80 / Dark 45. Starting there means turning
  # this contract on does not silently restyle a library that already looks
  # right — it makes the two exporters IDENTICAL first, which is the actual
  # goal, and leaves the brightness match to one number.
  DEF_LIGHT = 80
  DEF_DARK  = 45

  SHADOW_KEYS = %w[DisplayShadows UseSunForAllShading Light Dark].freeze

  def self.dark_value(v)
    n = v.to_s.strip.empty? ? DEF_DARK : v.to_i
    return DEF_DARK if n < 0 || n > 100
    n
  end

  # UseSunForAllShading OFF is deliberate. With it on, face brightness tracks
  # the sun's position, so the same part shot on two different dates does not
  # match — and the date is a model property nobody thinks to check.
  def self.shadow_want(dark)
    { 'DisplayShadows'      => false,
      'UseSunForAllShading' => false,
      'Light'               => DEF_LIGHT,
      'Dark'                => dark_value(dark) }
  end

  # ------------------------------------------------------------------ styles --

  # The dropdown both scripts offer, in the same order, so a run of one can be
  # reproduced by the other by picking the same entry.
  KEEP = "Leave the style alone (the model's own)".freeze

  def self.style_options(model)
    out = [KEEP]
    begin
      model.styles.each { |s| out << "Style: #{s.name}" }
    rescue StandardError
      nil
    end
    out
  end

  def self.find_style(model, name)
    hit = nil
    model.styles.each { |s| hit = s if s.name == name }
    hit
  rescue StandardError
    nil
  end

  # ------------------------------------------------------------ apply / pop --

  # Sets each key and READS IT BACK. A rescue that swallows a failed write is
  # how a setting can look applied and not be — which is exactly what happened
  # with the watermark. Anything that refuses to change is returned so the
  # caller can print it rather than lose it.
  def self.apply(model, dark)
    stuck = []
    ro = model.rendering_options
    TRANSPARENCY.each do |k, v|
      begin
        ro[k] = v
      rescue StandardError => e
        stuck << "#{k}: write raised #{e.class}"
        next
      end
      got = (ro[k] rescue :unreadable)
      stuck << "#{k}: wanted #{v.inspect}, still #{got.inspect}" unless got == v
    end
    si = model.shadow_info
    shadow_want(dark).each do |k, v|
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
  rescue StandardError => e
    ["apply failed: #{e.class}: #{e.message}"]
  end

  # Remembers everything apply() will touch, selects a named style if one was
  # asked for, then applies. The caller MUST pop in an ensure block.
  def self.push(model, style_mode, dark)
    saved = { :ro => {}, :si => {}, :style => nil, :dark => dark_value(dark) }
    ro = model.rendering_options
    si = model.shadow_info
    TRANSPARENCY.each_key { |k| saved[:ro][k] = (ro[k] rescue nil) }
    SHADOW_KEYS.each      { |k| saved[:si][k] = (si[k] rescue nil) }

    if style_mode.to_s =~ /\AStyle: (.+)\z/
      name = Regexp.last_match(1)
      st = find_style(model, name)
      if st.nil?
        puts "  *** STYLE NOT IN THIS MODEL: #{name.inspect} — using the active style."
      else
        saved[:style] = (model.styles.selected_style.name rescue nil)
        begin
          model.styles.selected_style = st
        rescue StandardError => e
          saved[:style] = nil
          puts "  *** COULD NOT SELECT STYLE #{name.inspect}: #{e.class} — using the active style."
        end
      end
    end

    stuck = apply(model, dark)
    unless stuck.empty?
      puts '  *** SHADING KEYS THAT WOULD NOT TAKE:'
      stuck.each { |s| puts "        #{s}" }
      puts '  *** these have to be changed in the style itself; the API will not do it.'
    end
    saved
  end

  def self.pop(model, saved)
    return if saved.nil?
    ro = model.rendering_options
    si = model.shadow_info
    (saved[:ro] || {}).each { |k, v| (ro[k] = v) rescue nil unless v.nil? }
    (saved[:si] || {}).each { |k, v| (si[k] = v) rescue nil unless v.nil? }
    if saved[:style]
      st = find_style(model, saved[:style])
      (model.styles.selected_style = st) rescue nil if st
    end
  rescue StandardError
    nil
  end

  # --------------------------------------------------------------- recovery --

  # SketchUp 24's new graphics engine composites 75% black over write_image
  # output. fix-angled-alpha.py inverts it. The flat exporter never ran this,
  # which is one half of why the two sets did not match; it runs it now.
  def self.recover(dir)
    fixer = File.join(File.dirname(__FILE__), 'fix-angled-alpha.py')
    unless File.exist?(fixer)
      puts "  RECOVERY SKIPPED — #{fixer} is missing."
      return false
    end
    cmd = "python \"#{fixer.tr('/', '\\')}\" \"#{dir.to_s.tr('/', '\\')}\" --inplace"
    puts "  recovering brightness: #{cmd}"
    ok = system(cmd)
    if ok
      puts '  recovery done — files corrected in place.'
    else
      puts '  *** RECOVERY FAILED. Is python on PATH? Run it by hand:'
      puts "      #{cmd}"
      puts '  *** The PNGs are exported but still 75% dark until you do.'
    end
    ok
  rescue StandardError => e
    puts "  recovery error: #{e.class}: #{e.message}"
    false
  end

  # ------------------------------------------------------------- reporting --

  # What the contract ACTUALLY produced, read live. Both scripts print this, so
  # a mismatch between the two sets is a diff of two console blocks rather than
  # a judgement about which image looks lighter.
  def self.describe(model)
    ro = model.rendering_options
    si = model.shadow_info
    lines = ["style              #{(model.styles.selected_style.name rescue 'unknown')}"]
    TRANSPARENCY.each_key do |k|
      lines << format('  %-20s %s', k, (ro[k] rescue 'unreadable').to_s)
    end
    SHADOW_KEYS.each do |k|
      lines << format('  %-20s %s', k, (si[k] rescue 'unreadable').to_s)
    end
    lines
  rescue StandardError => e
    ["describe failed: #{e.class}: #{e.message}"]
  end
end
