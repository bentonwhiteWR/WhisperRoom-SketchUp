# export-scenes.rb — batch-export every scene in the open model to a PNG.
#
#   Extensions > Developer > Ruby Console, then:
#     load "C:/Users/bento/Documents/Claude/Sketchup/scripts/export-scenes.rb"
#
# Core logic is lifted from WhisperRoomQuote\tools\sketchup-scene-export\quick-export.rb.
# That original is untouched — it exports booth COMPONENT art (transparent, named
# to import-art.py's MAP keys). This copy is pointed at ProposalFiles and defaults
# to opaque backgrounds, which is what a proposal plate wants.
#
# THE FILENAME IS THE SCENE NAME. Name scenes in plate order and they drop straight
# into proposal-v2.json:  01-exterior  02-dimensioned  03-side  04-ventilation  05-plan
#
# BEFORE YOU RUN: resize the SketchUp window to the aspect you want. Height is
# derived from the viewport, and every image in the run inherits it.

OUT_DIR   = 'C:/Users/bento/Desktop/ProposalFiles/ImageExports'
CLIENT    = ''      # optional subfolder, e.g. 'CSUSB' -> ...\ImageExports\CSUSB
WIDTH     = 2400    # px. Above ~4000 can fail on some GPUs.
ANTIALIAS = true

# false = sky/ground render as the scene has them -> opaque. Right for proposal
#         plates showing a booth in a room.
# true  = ground, horizon and fog hidden -> real alpha. Right for component art.
TRANSPARENT = false

OVERWRITE = false   # false = skip scenes already exported, so a run is resumable

# ─────────────────────────────────────────────────────────────────────────
require 'fileutils'

model = Sketchup.active_model
view  = model.active_view
pages = model.pages

if pages.count.zero?
  UI.messagebox("No scenes in this model.\n\nAdd scenes first (View > Animation > Add Scene).")
else
  dir = CLIENT.strip.empty? ? OUT_DIR : File.join(OUT_DIR, CLIENT.strip)
  FileUtils.mkdir_p(dir)

  # A non-zero transition lets write_image catch a half-finished tween.
  page_opts       = model.options['PageOptions']
  prev_transition = page_opts['TransitionTime']
  page_opts['TransitionTime'] = 0

  ro = model.rendering_options
  prev_ro = TRANSPARENT ? {
    'DrawGround'  => ro['DrawGround'],
    'DrawHorizon' => ro['DrawHorizon'],
    'DisplayFog'  => ro['DisplayFog']
  } : {}

  prev_page = pages.selected_page
  height    = (WIDTH * view.vpheight.to_f / view.vpwidth.to_f).round

  written = 0
  skipped = 0
  failed  = []
  used    = {}

  begin
    pages.each_with_index do |page, i|
      base = page.name.strip
                 .gsub(/[^0-9A-Za-z._ -]+/, '-')
                 .gsub(/\s+/, '-')
                 .gsub(/-+/, '-')
                 .sub(/\A-+/, '')
                 .sub(/-+\z/, '')
      base = "scene-#{i + 1}" if base.empty?

      # two scene names can sanitize to the same string — don't clobber
      if used.key?(base)
        used[base] += 1
        base = "#{base}-#{used[base]}"
      else
        used[base] = 1
      end

      path = File.join(dir, "#{base}.png")

      if !OVERWRITE && File.exist?(path)
        skipped += 1
        puts "  skip  #{base}.png (already there)"
        next
      end

      pages.selected_page = page

      # A scene can restore its own style, so re-apply AFTER the switch.
      if TRANSPARENT
        ro['DrawGround']  = false
        ro['DrawHorizon'] = false
        ro['DisplayFog']  = false
      end

      view.refresh
      Sketchup.status_text = "Exporting scene #{i + 1} of #{pages.count}: #{page.name}"

      ok = view.write_image(
        :filename    => path,
        :width       => WIDTH,
        :height      => height,
        :antialias   => ANTIALIAS,
        :transparent => TRANSPARENT
      )

      if ok
        written += 1
        puts "  ok    #{page.name}  ->  #{base}.png"
      else
        failed << page.name
        puts "  FAIL  #{page.name}"
      end
    end
  ensure
    prev_ro.each { |k, v| ro[k] = v }
    page_opts['TransitionTime'] = prev_transition
    pages.selected_page = prev_page if prev_page
    Sketchup.status_text = ''
  end

  msg  = "#{written} written, #{skipped} skipped, #{failed.size} failed\n\n"
  msg << "#{dir}\n#{WIDTH} x #{height} px, "
  msg << (TRANSPARENT ? "transparent" : "opaque background")
  msg << "\n\nFailed: #{failed.join(', ')}" unless failed.empty?
  puts ""
  puts msg
  UI.messagebox(msg)
end
