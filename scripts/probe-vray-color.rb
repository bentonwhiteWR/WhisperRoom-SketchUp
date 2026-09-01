# @title Probe V-Ray colour settings...
# @cat V-Ray renders
# @rank 90
#
# READ-ONLY. Dumps the V-Ray colour/gamma path to the Ruby Console. Writes
# nothing, renders nothing, changes nothing.
#
# WHY THIS EXISTS. Measured 1 Sep 2026 on Benton's own pair: the proposal
# package's saved PNG has mean luminance 0.159 and a MAXIMUM of 0.68 — it
# never reaches white — while the same frame by hand reads ~0.35 and touches
# 1.0. Apply an sRGB transfer curve to the saved file and it lands exactly on
# the hand render. The file carries NO gAMA, sRGB or iCCP chunk, so nothing
# tells a viewer it is linear. Benton: "when I see the vray window rendering,
# it looks correctly bright. Just the finished file doesn't look good."
#
# RUN 1 (1 Sep) told us two things and both are acted on here:
#
#   1. Every plugin key came back :unreadable — because the keys were passed
#      as STRINGS. proposal-package.rb has always used SYMBOLS (`pl[:gamma]`).
#      Both are tried now, and which one worked is printed.
#   2. The renderer's own method list is where the answer actually lives:
#        vfb_settings / vfb_settings=      apply_settings_vfb
#        fill_settings_vfb                 vfb_persistent_state
#        load_color_corrections_preset     save_color_corrections_preset
#      The VFB's display correction is a VFB setting, not a scene plugin, and
#      save_vfb_image saves the buffer. So vfb_settings is dumped in full.
#
# Extensions > Developer > Ruby Console, then run it from the panel, or:
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/probe-vray-color.rb"

require 'sketchup.rb'

module WR_ProbeVRayColor
  # Methods, not constants: re-running this in one session used to print four
  # "already initialized constant" warnings before it got to the answer.
  def self.plugins
    %w[
      /SettingsColorMapping /SettingsVFB /SettingsOutput /SettingsPNG
      /SettingsJPEG /SettingsEXR /SettingsImageSampler /CameraPhysical
      /RenderChannelDenoiser /SettingsEnvironment /SettingsRTEngine
      /SettingsOptions
    ]
  end

  def self.hot
    %w[
      gamma type adaptation_only linearWorkflow subpixel_mapping clamp_output
      clamp_level affect_background mode display_correction srgb force_srgb
      display_srgb use_display_correction img_noAlpha bitmap_gamma
      color_space exposure iso f_number shutter_speed white_balance
      img_width img_height
    ]
  end

  # Read one key both ways. Returns [value, how] or [:unreadable, nil].
  def self.read_key(pl, k)
    begin
      v = pl[k.to_sym]
      return [v, 'sym'] unless v.nil?
    rescue Exception
      nil
    end
    begin
      v = pl[k.to_s]
      return [v, 'str'] unless v.nil?
    rescue Exception
      nil
    end
    [:unreadable, nil]
  end

  def self.dump_value(label, v)
    s = v.inspect
    s = s[0, 4000] + " ...(truncated, #{v.inspect.length} chars)" if s.length > 4000
    puts "  #{label} = #{s}"
  end

  def self.run
    unless defined?(VRay) && defined?(VRay::Context)
      puts 'V-Ray is not loaded in this SketchUp session.'
      return
    end
    ctx = (VRay::Context.active rescue nil)
    if ctx.nil?
      puts 'VRay::Context.active is nil — open the Asset Editor once, then re-run.'
      return
    end
    scene = (ctx.scene rescue nil)
    rend  = (ctx.renderer rescue nil)

    puts ''
    puts '=' * 74
    puts 'V-RAY COLOUR PROBE 2 — read-only'
    puts '=' * 74

    # ---- 1. the VFB settings blob: the most likely home of the answer ----
    puts ''
    puts '-- RENDERER / VFB --------------------------------------------------'
    if rend.nil?
      puts '  no renderer on the context'
    else
      %i[vfb_settings vfb_persistent_state].each do |m|
        next unless rend.respond_to?(m)
        begin
          dump_value(m.to_s, rend.send(m))
        rescue Exception => e
          puts "  #{m} raised #{e.class}: #{e.message}"
        end
      end
      %i[fill_settings_vfb].each do |m|
        next unless rend.respond_to?(m)
        puts "  #{m} arity #{(rend.method(m).arity rescue '?')}"
      end
      # What does save_vfb_image actually accept? Its arity tells us whether
      # options are a hash argument at all on this build.
      if rend.respond_to?(:save_vfb_image)
        puts "  save_vfb_image arity #{(rend.method(:save_vfb_image).arity rescue '?')}"
        begin
          puts "  save_vfb_image params #{rend.method(:save_vfb_image).parameters.inspect}"
        rescue Exception
          nil
        end
      end
    end

    # ---- 2. the scene plugins, keys tried as symbol AND string ----
    puts ''
    puts '-- SCENE PLUGINS ---------------------------------------------------'
    if scene.nil?
      puts '  no V-Ray scene on the active context'
    else
      plugins.each do |name|
        pl = (scene[name] rescue nil)
        if pl.nil?
          puts format('  %-24s NOT IN THIS SCENE', name)
          next
        end
        found = []
        hot.each do |k|
          v, how = read_key(pl, k)
          found << format('    %-26s %-6s %s', k, how, v.inspect) unless v == :unreadable
        end
        if found.empty?
          puts format('  %-24s present, but no probed key was readable', name)
          puts format('        (class %s)', pl.class)
        else
          puts "  #{name}"
          puts found.join("\n")
        end
      end
    end

    puts ''
    puts '  Copy this whole block back.'
    puts '=' * 74
    puts ''
  rescue Exception => e
    puts "PROBE FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(6).join("\n") if e.backtrace
  end
end

WR_ProbeVRayColor.run unless $wr_suppress_autorun || $wr_no_autorun
