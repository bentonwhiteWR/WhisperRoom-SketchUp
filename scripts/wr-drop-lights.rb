# @title Drop Interior Lights
# @cat V-Ray renders
# @rank 3
#
# wr-drop-lights.rb — put a ceiling light inside each selected room or booth
# so V-Ray interiors stop rendering as black holes.
#
#   Select the room groups (or the booth), press the button. That is the whole
#   UI, on purpose. Benton, 2026-08-27: "I just want it to be a very simple,
#   minimalistic skill and nothing too complicated." Moving a light is the Move
#   tool; deleting one is the eraser; brightness is the Asset Editor. SketchUp
#   itself is the lighting-designer UI, so this file never grows one.
#
#   Extensions > Developer > Ruby Console, then:
#     load "C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-drop-lights.rb"
#
# ===========================================================================
# WHY A SEED COMPONENT AND NOT THE V-RAY API
#
# The documented V-Ray Ruby API has NO light class — see
# reference/vray-ruby-api.md: the whole surface is Context/Scene/Renderer/
# Exporter, and its own ModelExporter#subscribe section admits that anything
# injected into the render scene that is not in the SketchUp model is wiped on
# every re-export. So a scripted light would be invisible in SketchUp,
# unmovable, and gone on the next render unless re-injected forever.
#
# But a V-Ray light IS a SketchUp component instance carrying the extension's
# attributes. Save one as a .skp once, and placing copies is plain
# model.definitions.load + add_instance — the exact idiom merge-scenes.rb and
# build-booth-components.rb already use. Copies share one light asset, so one
# intensity slider in the Asset Editor tunes every room at once. Full
# reasoning: .forge/researcher/interior-lighting-options.md.
#
# ===========================================================================
# THE SEED IS BENTON'S TO AUTHOR — THIS SCRIPT REFUSES UNTIL IT EXISTS
#
#   scripts/vray-seeds/WR Interior Light.skp
#
# Author it ONCE, on the render machine (V-Ray must be installed):
#   1. V-Ray toolbar > Rectangle Light. Size it 24" x 48" (a standard ceiling
#      troffer), facing DOWN, drawn AT THE COMPONENT ORIGIN so placement here
#      is a pure translation.
#   2. Set intensity by eye on one test render.
#   3. Right-click > Save As... > this repo, scripts/vray-seeds/, exactly
#      "WR Interior Light.skp".
# Until that file exists the button refuses BY NAME (GOAL rule: no silent
# fallback, no faked component). NOTE install-plugin.py bundles only the .rb
# files, not subfolders — the seed rides in with a repo checkout (git pull),
# which every machine that renders has.
#
# ===========================================================================
# WHAT A PRESS DOES — ONE OPERATION, ONE Ctrl+Z
#
#   1. Reads the selection. Keeps groups and component instances only — it
#      never guesses which things in a model are rooms.
#   2. Removes any lights IT previously dropped inside the selected things
#      (found by their WR_DropLights attribute), so a re-press re-places
#      rather than double-lights.
#   3. Drops one instance 6" under the top of each selected thing's bounding
#      box — below an open-top room's wall line and a booth's tray ceiling in
#      the common cases; if it lands inside a ceiling panel, Move tool. A room
#      longer than 12' in plan gets two lights at the third-points of its long
#      axis (one troffer in a 22' UTHSC room reads as a single hotspot).
#      No other layout logic, deliberately.
#   4. Tags them "WR Lights" so they are easy to find and select as a set.
#
# Lights go in the CURRENT drawing context, not inside the room group —
# client drawing groups stay untouched, and coordinates agree with the
# selection's own bounding boxes, which are reported in that same context.
#
# ===========================================================================
# TWO INTERACTIONS TO KNOW ABOUT, NOT SOLVED WITH UI
#
# - Hiding the "WR Lights" tag almost certainly turns the lights OFF in the
#   render too — V-Ray skips hidden geometry (community-reported, unverified).
#   The tag exists for FINDING the lights, not per-scene dimming. Plain-export
#   scenes can hide it harmlessly; no plain SketchUp export ever sees a V-Ray
#   light anyway — those images are brightened by shadow Dark/DisplayShadows
#   (wr-shading.rb / wr-mode.rb), a different lever this tool does not touch.
# - wr-mode.rb snapshots tag visibility per mode, so after the first
#   draft/render toggle with lights present the tag state rides along free.
#
# ===========================================================================
# THIS SCRIPT HAS NOT BEEN RUN
#
# No SketchUp and no V-Ray on the machine that wrote it. python
# scripts/rbparse.py proves it parses (the same CRuby 3.2 SketchUp ships) and
# the light_points math ran green outside SketchUp, but no instance has been
# placed and no render seen. The load-bearing unverified claim — a
# definitions.load-ed copy of a rectangle-light component still emits — is
# step 2 of the researcher's verification list. Everything below fails loudly
# to the console and a messagebox rather than doing nothing.

require 'sketchup.rb'

module WR_DropLights
  DICT      = 'WR_DropLights'.freeze
  TAG       = 'WR Lights'.freeze
  SEED_NAME = 'WR Interior Light'.freeze

  # Inches below the top of the container's bounding box. 6 clears the wall
  # line of an open-top room and the tray-ceiling underside of a booth in the
  # common cases; it is a starting value, and every light is hand-movable.
  DROP = 6.0

  # A container whose longer plan dimension exceeds this gets two lights at
  # the third-points of the long axis instead of one in the middle. 12' —
  # above it a single troffer reads as one hotspot in the render.
  SPLIT = 144.0

  # The seed is looked for beside this script first (__dir__ is wherever
  # main.rb loaded it from — the repo checkout on a machine that has one, the
  # bundled copy otherwise), then in the known repo checkout locations, same
  # list main.rb itself uses. The bundled copy never has vray-seeds/ (see
  # header), so the fallbacks are what save a bundled-copy machine that also
  # has the repo cloned somewhere standard.
  def self.seed_candidates
    home = ENV['USERPROFILE'].to_s
    [
      File.join(__dir__.to_s, 'vray-seeds', "#{SEED_NAME}.skp"),
      File.join(home, 'Documents/Claude/Sketchup/scripts/vray-seeds', "#{SEED_NAME}.skp"),
      File.join(home, 'Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/vray-seeds', "#{SEED_NAME}.skp"),
      File.join(home, 'OneDrive/Documents/Claude/Sketchup/scripts/vray-seeds', "#{SEED_NAME}.skp"),
      File.join(home, 'OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/vray-seeds', "#{SEED_NAME}.skp")
    ].map { |p| p.tr('\\', '/') }.uniq
  end

  def self.seed_path
    seed_candidates.find { |p| File.exist?(p) }
  end

  # ------------------------------------------------------------ pure logic --

  # Where lights land inside one container's bounding box, world units in,
  # [[x, y, z], ...] out. Pure math — this is the method rbtest exercises
  # outside SketchUp, so keep the API out of it.
  def self.light_points(min_x, min_y, max_x, max_y, top_z)
    w  = max_x.to_f - min_x.to_f
    d  = max_y.to_f - min_y.to_f
    z  = top_z.to_f - DROP
    cx = (min_x.to_f + max_x.to_f) / 2.0
    cy = (min_y.to_f + max_y.to_f) / 2.0
    return [[cx, cy, z]] if (w >= d ? w : d) <= SPLIT
    if w >= d
      [[min_x + w / 3.0, cy, z], [min_x + w * 2.0 / 3.0, cy, z]]
    else
      [[cx, min_y + d / 3.0, z], [cx, min_y + d * 2.0 / 3.0, z]]
    end
  end

  # ----------------------------------------------------------------- pieces --

  def self.tag(model)
    t = model.layers[TAG] || model.layers.add(TAG)
    (t.color = Sketchup::Color.new(255, 199, 44)) rescue nil # troffer yellow
    t
  end

  # The rooms/booths to light: groups and component instances from the
  # selection, minus any light this tool itself dropped (selecting the whole
  # model and pressing again must not light the lights).
  def self.containers(model)
    model.selection.to_a
         .select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
         .reject { |e| e.get_attribute(DICT, 'seed') }
  end

  # Previously-dropped lights whose origin sits inside any of the given
  # bounding boxes — the ones a re-press replaces.
  def self.stale_lights(ents, boxes)
    ents.grep(Sketchup::ComponentInstance).select do |i|
      next false unless i.get_attribute(DICT, 'seed')
      o = i.transformation.origin
      boxes.any? { |bb| bb.contains?(o) }
    end
  end

  def self.fmt(pt)
    format('(%.1f", %.1f", %.1f")', pt[0], pt[1], pt[2])
  end

  # -------------------------------------------------------------------- run --

  def self.run
    model = Sketchup.active_model
    raise 'No model open.' unless model

    subjects = containers(model)
    if subjects.empty?
      msg = if model.selection.empty?
              'Nothing is selected.'
            else
              'The selection has no group or component in it — only loose ' \
              'geometry or previously dropped lights.'
            end
      UI.messagebox("#{msg}\n\nSelect the room or booth groups to light, " \
                    'then press Drop Interior Lights again. This tool never ' \
                    'guesses which things are rooms.')
      return
    end

    seed = seed_path
    if seed.nil?
      UI.messagebox("scripts/vray-seeds/#{SEED_NAME}.skp is missing — author " \
                    "it once on the render machine (V-Ray toolbar > Rectangle " \
                    "Light, 24\" x 48\", facing down, drawn at the origin, " \
                    "right-click > Save As) and press again.\n\nLooked in:\n" \
                    "#{seed_candidates.join("\n")}")
      puts "FAILED: seed component not found. Looked in:\n  " +
           seed_candidates.join("\n  ")
      return
    end

    model.start_operation('Drop Interior Lights', true)
    begin
      # definitions.load raises on newer SketchUps and returns nil on older
      # ones when the file is unreadable — catch both, loudly.
      defn = begin
               model.definitions.load(seed)
             rescue StandardError => e
               raise "SketchUp could not load the seed component:\n#{seed}\n#{e.message}"
             end
      raise "SketchUp could not load the seed component:\n#{seed}" if defn.nil?

      ents  = model.active_entities
      layer = tag(model)
      boxes = subjects.map(&:bounds).select(&:valid?)

      stale = stale_lights(ents, boxes)
      ents.erase_entities(stale) unless stale.empty?

      placed = 0
      puts "Drop Interior Lights — seed #{seed}"
      puts "  replaced #{stale.size} previously dropped light#{stale.size == 1 ? '' : 's'}" unless stale.empty?
      subjects.each do |s|
        bb = s.bounds
        unless bb.valid?
          puts "  SKIPPED #{s.respond_to?(:name) ? s.name.to_s : '?'} — empty bounding box"
          next
        end
        name = s.name.to_s
        name = s.definition.name.to_s if name.empty? && s.respond_to?(:definition)
        name = '(unnamed)' if name.empty?
        light_points(bb.min.x, bb.min.y, bb.max.x, bb.max.y, bb.max.z).each do |pt|
          inst = ents.add_instance(defn, Geom::Transformation.translation(Geom::Point3d.new(*pt)))
          raise "add_instance failed inside #{name}" if inst.nil?
          inst.layer = layer
          inst.set_attribute(DICT, 'seed', SEED_NAME)
          placed += 1
          puts "  #{name}  light at #{fmt(pt)}"
        end
      end
      raise 'Nothing was placed — every selected container had an empty bounding box.' if placed.zero?

      model.commit_operation
      puts "  #{placed} light#{placed == 1 ? '' : 's'} in #{subjects.size} " \
           "container#{subjects.size == 1 ? '' : 's'}. Ctrl+Z removes them all; " \
           'brightness is the one slider on the light asset in the V-Ray Asset Editor.'
    rescue StandardError => e
      model.abort_operation
      raise e
    end
  end
end

begin
  WR_DropLights.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).map { |l| "  #{l}" }.join("\n") if e.backtrace
  UI.messagebox("Drop Interior Lights failed:\n\n#{e.message}\n\nSee the Ruby Console.")
end
