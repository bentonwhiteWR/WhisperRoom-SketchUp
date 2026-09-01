# @title Probe V-Ray colour settings...
# @cat V-Ray renders
# @rank 90
#
# READ-ONLY. Dumps every colour/gamma-related V-Ray setting in the current
# scene to the Ruby Console. Writes nothing, renders nothing, changes nothing.
#
# WHY THIS EXISTS. Measured 1 Sep 2026 on Benton's own pair: the proposal
# package's saved PNG has mean luminance 0.159 and a MAXIMUM of 0.68 — it
# never reaches white — while the same frame rendered by hand reads ~0.35
# and touches 1.0. Apply an sRGB transfer curve to the saved file and it
# lands exactly on the hand render. The file also carries NO gAMA, sRGB or
# iCCP chunk, so nothing tells a viewer it is linear.
#
# Benton: "when I see the vray window rendering, it looks correctly bright.
# Just the finished file doesn't look good." That is the shape of a display
# transform the VFB applies and the saved file does not inherit.
#
# save_vfb_image(:apply_color_corrections => true) did NOT change it —
# byte-different file, identical luminance (mean 0.1585 both runs) — so that
# option is not the knob. This probe finds the one that is, instead of
# guessing at plugin names one release at a time.
#
# Extensions > Developer > Ruby Console, then run it from the panel, or:
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/probe-vray-color.rb"

require 'sketchup.rb'

module WR_ProbeVRayColor
  # Everything plausibly involved in how a rendered pixel becomes a file
  # pixel. Missing plugins are reported as missing, not skipped silently —
  # which one is absent is itself the answer on some builds.
  PLUGINS = %w[
    /SettingsColorMapping
    /SettingsVFB
    /SettingsOutput
    /SettingsImageSampler
    /SettingsEXR
    /SettingsPNG
    /SettingsJPEG
    /RenderChannelDenoiser
    /CameraPhysical
    /SettingsCameraDof
    /SettingsEnvironment
  ].freeze

  # Keys worth calling out by name if they exist — the usual suspects for a
  # linear file out of a corrected viewer.
  HOT = %w[
    gamma type adaptation_only linearWorkflow subpixel_mapping clamp_output
    clamp_level affect_background mode display_correction srgb
    force_srgb display_srgb use_display_correction img_noAlpha
    img_file_needFrameNumber bitmap_gamma color_space
    exposure iso f_number shutter_speed white_balance
  ].freeze

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
    if scene.nil?
      puts 'No V-Ray scene on the active context.'
      return
    end

    puts ''
    puts '=' * 74
    puts 'V-RAY COLOUR PROBE — read-only'
    puts '=' * 74

    PLUGINS.each do |name|
      pl = (scene[name] rescue nil)
      if pl.nil?
        puts format('  %-26s NOT IN THIS SCENE', name)
        next
      end
      puts ''
      puts "  #{name}"
      keys = nil
      # Different builds expose the key list differently; try the documented
      # routes in order and say which one worked, so the next person knows.
      %i[keys parameter_names properties each_key].each do |m|
        next unless pl.respond_to?(m)
        begin
          keys = pl.send(m)
          keys = keys.to_a if keys.respond_to?(:to_a)
          puts "      (keys via ##{m})"
          break
        rescue Exception
          keys = nil
        end
      end
      if keys.nil? || keys.empty?
        puts '      no key list available — probing the named suspects only'
        keys = HOT
      end
      keys.each do |k|
        v = (pl[k] rescue :unreadable)
        next if v == :unreadable && !HOT.include?(k.to_s)
        star = HOT.include?(k.to_s) ? '*' : ' '
        puts format('    %s %-30s %s', star, k, v.inspect)
      end
    end

    puts ''
    puts '  renderer responds to:'
    r = (ctx.renderer rescue nil)
    if r
      ms = r.methods.map(&:to_s).select do |m|
        m =~ /save|image|vfb|color|colour|gamma|srgb|correct/i
      end.sort
      puts '    ' + (ms.empty? ? '(nothing matching save/image/vfb/color/gamma)' : ms.join(', '))
    else
      puts '    (no renderer on the context)'
    end
    puts ''
    puts '  Lines marked * are the ones I care about. Copy this whole block back.'
    puts '=' * 74
    puts ''
  rescue Exception => e
    puts "PROBE FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5).join("\n") if e.backtrace
  end
end

WR_ProbeVRayColor.run unless $wr_suppress_autorun || $wr_no_autorun
