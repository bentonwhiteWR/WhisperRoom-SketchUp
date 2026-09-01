# @title Probe V-Ray colour settings...
# @cat V-Ray renders
# @rank 90
#
# Dumps the V-Ray colour/gamma path to the Ruby Console. Renders nothing and
# changes NO setting — but since run 3 it is no longer strictly write-free:
# when a rendered frame is sitting in the VFB it saves up to six small test
# PNGs into %TEMP%\wr-color-probe (nowhere else, never into a client folder)
# and measures each one, because those six numbers are the whole answer.
#
# RUN IT WITH A FRAME IN THE VFB — render anything by hand first, leave the
# VFB open, then run this.
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
    # A big settings blob can truncate right where the answer lives, so every
    # colour-shaped key is ALSO pulled out with its surroundings, whole.
    if v.is_a?(String) && v.length > 200
      v.scan(/.{0,60}(?:srgb|gamma|display|correct|colorspace|color_space|ocio|icc|lut).{0,80}/i) do |hit|
        puts "      colour-key context: ...#{hit}..."
      end
    end
  end

  # ---- 3. save the same frame six ways and MEASURE each one --------------
  #
  # This is the run that decides the fix's future. proposal-package.rb now
  # bakes sRGB into the saved PNG itself (wr-png-srgb.rb) because that is
  # deterministic; if ONE of the variants below already comes out at the
  # hand-render numbers (~0.35 mean, max 1.000) the post-process can be
  # retired for that call. The measured batch file reads mean 0.1585,
  # max 0.682 — that is the LINEAR signature.
  #
  #   what each answer means:
  #   - vfb-plain / vfb-acc at ~0.16      confirms the measured bug and that
  #                                       :apply_color_corrections is not the
  #                                       display transform (expected)
  #   - image-default at ~0.35            renderer.image already applies the
  #                                       display correction; save through it
  #   - image-docc-true at ~0.35          :do_color_correct IS the display
  #     (and image-docc-false at ~0.16)   transform -> save via
  #                                       image(:do_color_correct => true)
  #   - image-chsrgb-true at ~0.35        change_srgb(true) converts linear->
  #                                       sRGB -> image + change_srgb + save
  #   - everything at ~0.16               the API cannot bake the display
  #                                       transform; wr-png-srgb.rb stands as
  #                                       the permanent fix
  def self.save_and_measure(rend)
    puts ''
    puts '-- SAVED-FRAME VARIANTS (the deciding measurement) -----------------'
    if rend.nil?
      puts '  no renderer - skipped'
      return
    end
    st = (rend.state rescue :unreadable)
    puts "  renderer state #{st.inspect}"
    unless st.to_s =~ /idleDone|idleFrameDone/i
      puts '  NO FINISHED FRAME IS IN THE VFB - render something by hand,'
      puts '  leave the VFB open, and re-run this probe. Variants skipped.'
      return
    end
    dir = File.join(ENV['TEMP'] || ENV['TMP'] || Dir.pwd, 'wr-color-probe')
    begin
      require 'fileutils'
      FileUtils.mkdir_p(dir)
    rescue Exception => e
      puts "  could not make #{dir}: #{e.class}: #{e.message} - skipped"
      return
    end
    puts "  writing test PNGs to #{dir}"

    jobs = []
    jobs << ['vfb-plain', lambda { |path|
      rend.save_vfb_image(path, :skip_alpha => true, :no_alpha => true)
    }]
    jobs << ['vfb-acc', lambda { |path|
      rend.save_vfb_image(path, :skip_alpha => true, :no_alpha => true,
                                :apply_color_corrections => true)
    }]
    if rend.respond_to?(:image)
      jobs << ['image-default', lambda { |path|
        rend.image.save(path, :format => :png)
      }]
      jobs << ['image-docc-true', lambda { |path|
        rend.image(:do_color_correct => true).save(path, :format => :png)
      }]
      jobs << ['image-docc-false', lambda { |path|
        rend.image(:do_color_correct => false).save(path, :format => :png)
      }]
      jobs << ['image-chsrgb-true', lambda { |path|
        img = rend.image
        img.change_srgb(true) if img.respond_to?(:change_srgb)
        img.save(path, :format => :png)
      }]
    else
      puts '  renderer has no #image method - only the two vfb variants run'
    end

    jobs.each do |name, job|
      path = File.join(dir, "#{name}.png")
      begin
        File.delete(path) if File.exist?(path)
        ret = job.call(path)
        unless File.exist?(path)
          puts format('  %-18s returned %s but wrote NO FILE', name, ret.inspect)
          next
        end
        if defined?(WR_PNGSRGB)
          m = WR_PNGSRGB.measure_file(path)
          if m[:ok]
            puts format('  %-18s mean %.4f  max %.3f  %dx%d  declares [%s]',
                        name, m[:mean], m[:max], m[:w], m[:h],
                        m[:declared].join(','))
          else
            puts format('  %-18s saved, but unmeasurable: %s', name, m[:why])
          end
        else
          puts format('  %-18s saved (wr-png-srgb.rb not loaded - no measurement)', name)
        end
      rescue Exception => e
        puts format('  %-18s RAISED %s: %s', name, e.class, e.message)
      end
    end
    puts '  (hand-render reference: mean ~0.35, max 1.000; the dark batch'
    puts '   file: mean 0.1585, max 0.682)'
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

    # The measuring half lives in wr-png-srgb.rb; load it so the saved
    # variants below come back as NUMBERS, not filenames to inspect by hand.
    begin
      load File.join(File.dirname(__FILE__), 'wr-png-srgb.rb') unless defined?(WR_PNGSRGB)
    rescue Exception => e
      puts "note: wr-png-srgb.rb did not load (#{e.class}: #{e.message}) - " \
           'variants will be saved but not measured'
    end

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

    save_and_measure(rend)

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
