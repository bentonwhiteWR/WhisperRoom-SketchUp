# @title Export the proposal plates...
# @cat Scenes and images
# @rank 3
#
# Batch-export scenes to PNG. The proposal-plate exporter: opaque backgrounds,
# into ProposalFiles, named for the plate order that proposal-v2.json expects.
#
#   01-exterior  02-dimensioned  03-side  04-ventilation  05-plan
#
# Core logic came from WhisperRoomQuote\tools\sketchup-scene-export\quick-export.rb.
# That original is untouched.
#
# THE FILE IS NAMED AFTER THE SCENE, VERBATIM. Only the characters Windows
# genuinely refuses are replaced. Spaces, brackets and ampersands are kept as
# the scene has them. This script used to fold spaces into hyphens and strip
# anything non-alphanumeric, so "01 Exterior View" landed as
# "01-Exterior-View" and a file could not be matched back to its scene by eye.
#
# BEFORE YOU RUN: size the SketchUp window to the aspect you want. Height comes
# from the viewport and every image in the run inherits it.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/export-scenes.rb"

require 'sketchup.rb'
require 'fileutils'

# The folder field is a dropdown of folders used before, plus a Browse entry.
load File.join(File.dirname(__FILE__), 'wr-folder.rb')

module WR_ExportScenes
  PREF = 'WR_ExportScenes'.freeze

  DEFAULTS = {
    'scenes' => 'all',
    'dir'    => 'C:/Users/bento/Desktop/ProposalFiles',
    'width'  => '2400',
    'bg'     => 'Opaque',
    'over'   => 'No',
    'dry'    => 'No'
  }.freeze

  # Only what Windows actually forbids in a filename.
  FORBIDDEN = /[<>:"\/\\|?*\x00-\x1f]/.freeze

  # ------------------------------------------------------------------- input --

  def self.ask
    keys = %w[scenes dir width bg over dry]
    prompts = ['Scenes — all / current / 1-7,12 / text',
               'Output folder',
               'Image width (px)',
               'Background',
               'Overwrite files already there',
               'Dry run — list only, write nothing']
    defaults = keys.map do |k|
      v = Sketchup.read_default(PREF, k, DEFAULTS[k]).to_s
      v.empty? ? DEFAULTS[k] : v
    end
    lists = ['', '', '', 'Opaque|Transparent', 'Yes|No', 'Yes|No']
    di = keys.index('dir')
    defaults[di], lists[di] = WR_Folder.field('scenes', DEFAULTS['dir'])

    res = UI.inputbox(prompts, defaults, lists, 'Export Scenes')
    return nil unless res
    cfg = {}
    keys.each_with_index { |k, i| cfg[k] = res[i].to_s.strip }

    cfg['dir'] = WR_Folder.resolve(cfg['dir'], 'scenes', 'Where should the images go?')
    return nil if cfg['dir'].nil?

    keys.each { |k| Sketchup.write_default(PREF, k, cfg[k]) }
    cfg
  end


  def self.sanitize(s)
    out = s.to_s.strip.gsub(FORBIDDEN, '-')
    out.sub(/[. ]+\z/, '')      # Windows silently drops a trailing dot or space
  end

  # --------------------------------------------------------------- selection --
  #
  #   all              every scene
  #   current          the one selected right now
  #   1-7,12           scene numbers, as printed in the table
  #   exterior         any scene whose name contains that text
  #
  # Anything matching nothing is reported rather than quietly skipped.
  def self.select_pages(model, spec)
    pages = model.pages.to_a
    s = spec.to_s.strip.downcase
    return [pages, 'all'] if s.empty? || s == 'all' || s == '*'

    if s == 'current' || s == 'this'
      pg = model.pages.selected_page
      return [[], 'current — but no scene is selected'] if pg.nil?
      return [[pg], "current scene: #{pg.name}"]
    end

    picked = []
    misses = []
    s.split(',').map(&:strip).reject(&:empty?).each do |tok|
      hit = if tok =~ /\A(\d+)\s*-\s*(\d+)\z/
              a = Regexp.last_match(1).to_i
              b = Regexp.last_match(2).to_i
              a, b = b, a if a > b
              # Scene numbers are 1-indexed here, exactly as printed in the
              # table — but `pages` is a 0-indexed Ruby array, and Ruby's
              # pages[-1] is the LAST scene rather than an error. So an
              # unclamped 0 in a range ("0-5", an easy slip in a 1-based list)
              # used to quietly append the final scene of the model to the
              # export. Clamp to the real bounds first, and report whatever
              # fell off either end instead of dropping it silently — the user
              # asked for those numbers and is owed a word about them.
              lo = a < 1 ? 1 : a
              hi = b > pages.size ? pages.size : b
              if lo > hi
                []  # wholly outside the list — the empty-hit branch reports tok
              else
                misses << "#{a}-#{lo - 1}" if a < lo
                misses << "#{hi + 1}-#{b}" if b > hi
                (lo..hi).map { |n| pages[n - 1] }.compact
              end
            elsif tok =~ /\A\d+\z/
              n = tok.to_i
              [n >= 1 ? pages[n - 1] : nil].compact
            else
              pages.select { |p| p.name.to_s.downcase.include?(tok) }
            end
      hit.empty? ? misses << tok : picked.concat(hit)
    end
    picked = picked.compact.uniq
    note = spec.to_s.strip
    note += "  — nothing matched #{misses.join(', ')}" unless misses.empty?
    [picked, note]
  end

  # -------------------------------------------------------------------- run --

  def self.run
    model = Sketchup.active_model
    view  = model.active_view
    pages = model.pages

    if pages.count.zero?
      UI.messagebox("No scenes in this model.\n\n" \
                    "Add scenes first (View > Animation > Add Scene).")
      return
    end

    cfg = ask
    return unless cfg

    chosen, pick_note = select_pages(model, cfg['scenes'])
    if chosen.empty?
      UI.messagebox("No scenes selected by \"#{cfg['scenes']}\".\n\n" \
                    "Use all, current, numbers like 1-7,12, or text from a scene name.")
      return
    end

    width  = cfg['width'].to_i
    width  = 2400 if width < 200 || width > 6000
    height = (width * view.vpheight.to_f / view.vpwidth.to_f).round
    trans  = cfg['bg'] == 'Transparent'
    over   = cfg['over'] == 'Yes'
    dry    = cfg['dry'] == 'Yes'

    index = {}
    pages.to_a.each_with_index { |p, i| index[p.name.to_s] = i + 1 }

    used = {}
    plan = chosen.map do |page|
      base = sanitize(page.name)
      base = "scene-#{index[page.name.to_s] || 0}" if base.empty?
      if used.key?(base)          # two scenes can share a name after sanitising
        used[base] += 1
        base = "#{base} (#{used[base]})"
      else
        used[base] = 1
      end
      { :page => page, :n => index[page.name.to_s] || 0, :base => base }
    end

    puts ''
    puts "EXPORT SCENES#{dry ? '   —   DRY RUN, nothing written' : ''}"
    puts ''
    puts "  out      #{cfg['dir']}"
    puts "  picked   #{pick_note}"
    puts "  size     #{width} x #{height} px, #{trans ? 'transparent' : 'opaque'}"
    puts "  scenes   #{plan.size} of #{pages.count}"
    puts ''
    plan.each { |p| puts format('    %3d  %-40s -> %s.png', p[:n], p[:page].name, p[:base]) }
    puts ''
    puts '  The number on the left is the scene number — use it in the Scenes field.'
    puts '  Filenames are the scene names verbatim; only characters Windows forbids'
    puts '  are replaced.'
    puts ''

    if dry
      UI.messagebox("Dry run: #{plan.size} scene(s).\n\nCheck the console, then run " \
                    "again with Dry run = No.")
      return
    end

    FileUtils.mkdir_p(cfg['dir'])

    page_opts = model.options['PageOptions']
    prev_tt   = page_opts['TransitionTime']
    page_opts['TransitionTime'] = 0        # else write_image can catch a tween

    ro = model.rendering_options
    prev_ro = trans ? { 'DrawGround'  => ro['DrawGround'],
                        'DrawHorizon' => ro['DrawHorizon'],
                        'DisplayFog'  => ro['DisplayFog'] } : {}
    prev_page = pages.selected_page

    written = 0
    skipped = 0
    failed  = []

    begin
      plan.each_with_index do |p, i|
        path = File.join(cfg['dir'], "#{p[:base]}.png")
        if !over && File.exist?(path)
          skipped += 1
          puts "  skip  #{p[:base]}.png (already there)"
          next
        end

        pages.selected_page = p[:page]

        # A scene can restore its own style, so force these AFTER the switch.
        if trans
          ro['DrawGround']  = false
          ro['DrawHorizon'] = false
          ro['DisplayFog']  = false
        end

        view.refresh
        Sketchup.status_text = "Exporting #{i + 1} of #{plan.size}: #{p[:page].name}"

        ok = view.write_image(:filename    => path,
                              :width       => width,
                              :height      => height,
                              :antialias   => true,
                              :transparent => trans)
        if ok
          written += 1
          puts format('  ok    %-40s -> %s.png', p[:page].name, p[:base])
        else
          failed << p[:page].name
          puts "  FAIL  #{p[:page].name}"
        end
      end
    ensure
      prev_ro.each { |k, v| ro[k] = v }
      page_opts['TransitionTime'] = prev_tt
      pages.selected_page = prev_page if prev_page
      Sketchup.status_text = ''
    end

    msg  = "#{written} written, #{skipped} skipped, #{failed.size} failed\n\n"
    msg << "#{cfg['dir']}\n#{width} x #{height} px, #{trans ? 'transparent' : 'opaque'}"
    msg << "\n\nFailed: #{failed.join(', ')}" unless failed.empty?
    puts ''
    puts msg
    UI.messagebox(msg)
  rescue StandardError => e
    UI.messagebox("Export Scenes failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end
end

WR_ExportScenes.run
