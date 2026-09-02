# @title Make this view the Front...
# @cat Draw the room
#
# Spin a whole model onto the world axes so SketchUp's
# Front view actually shows the front, WITHOUT re-aiming a single scene.
#
#   Extensions > Developer > Ruby Console, then:
#     load "C:/Users/bento/Documents/Claude/Sketchup/scripts/reorient-model.rb"
#
# ---------------------------------------------------------------------------
# WHY THIS EXISTS
#
# SketchUp's Standard Views are hard-wired to the world axes. Front ALWAYS
# means looking along +Y; there is no preference and no API call that redefines
# it. So when a model was built a quarter turn out, "press Left to see the
# front" is not a setting that can be fixed — the model itself has to come
# round to meet the axes.
#
# Rotating the geometry on its own would leave every saved scene pointing at
# where the model used to be. So this rotates THE GEOMETRY AND EVERY SCENE
# CAMERA BY THE SAME ANGLE. Each scene then frames exactly what it framed
# before — same angle, same zoom — while the model is now square to the world.
# Nothing has to be re-aimed by hand.
#
# ---------------------------------------------------------------------------
# WHAT IT TOUCHES, AND THE TWO THINGS THAT WOULD OTHERWISE BITE
#
# GEOMETRY. Everything in model.entities, walked directly rather than through
# a select-all. Select-all skips anything hidden or on a hidden tag, and those
# would be left behind at the old angle — a fault you would not see until you
# turned the tag back on weeks later. Locked entities are unlocked, rotated,
# and re-locked.
#
# SCENE CAMERAS. eye, target and up all rotate. Field of view and parallel-
# projection height are read before and written back after, because Camera#set
# is documented to take eye/target/up and nothing else — it should leave them
# alone, but "should" is not a thing to rely on for a whole file.
#
#   Writing to a stored page camera is the one call here I could not test
#   outside SketchUp. So every camera is READ BACK after it is written and the
#   result is reported per scene. If the write does not take, this script says
#   so plainly instead of leaving you with a rotated model and stale scenes.
#
# THE SUN. This is the one that would quietly ruin the component art. Shading
# is lit by the sun, the sun is fixed to world north, so rotating the model
# would change which faces are lit and every future export would no longer
# match the existing set. NorthAngle is therefore rotated by the SAME amount,
# which puts the sun back in the same relationship to the model and leaves the
# shading contract in wr-shading.rb intact.
#
# WHAT IT DOES NOT TOUCH
#   Component DEFINITION axes. Only instances move. A component's own internal
#   front stays where the author put it, which is correct — the definitions are
#   shared with the part library and must not drift.
#
# Rotation is about the WORLD ORIGIN. A model far from the origin will swing a
# long way; the new bounding box is printed so you can see where it landed.
#
module WR_Reorient

  PREF = 'WR_Reorient'.freeze

  # Which standard view is currently showing the front, and the rotation about
  # Z that brings that face round to -Y where Front expects it.
  #
  #   Left  shows the front -> the face points -X -> +90 deg puts it at -Y
  #   Right shows the front -> the face points +X -> -90 deg
  #   Back  shows the front -> the face points +Y -> 180 deg
  TURNS = {
    'Left is really the Front'  =>  90.0,
    'Right is really the Front' => -90.0,
    'Back is really the Front'  => 180.0
  }.freeze

  def self.read_pref(k, fallback)
    v = Sketchup.read_default(PREF, k, fallback).to_s
    v.empty? ? fallback : v
  rescue Exception
    fallback
  end

  def self.ask
    keys = %w[turn cams north dry]
    res = UI.inputbox(
      ['Which view is showing the front now?',
       'Rotate the saved scene cameras too',
       'Rotate north as well (keeps shading identical)',
       'Dry run — report only, change nothing'],
      [read_pref('turn', 'Left is really the Front'),
       read_pref('cams', 'Yes'),
       read_pref('north', 'Yes'),
       'Yes'],
      [TURNS.keys.join('|'), 'Yes|No', 'Yes|No', 'Yes|No'],
      'Make this view the Front')
    return nil unless res
    cfg = {}
    keys.each_with_index { |k, i| cfg[k] = res[i].to_s.strip }
    keys.each { |k| (Sketchup.write_default(PREF, k, cfg[k]) rescue nil) }
    cfg
  end

  def self.bounds_line(model)
    bb = model.bounds
    return '  (model is empty)' unless bb.valid?
    format('  bounds  x %.1f..%.1f   y %.1f..%.1f   z %.1f..%.1f',
           bb.min.x.to_f, bb.max.x.to_f, bb.min.y.to_f,
           bb.max.y.to_f, bb.min.z.to_f, bb.max.z.to_f)
  end

  # Every scene camera, rotated by the same transform as the geometry.
  # Returns [updated, failed, skipped] so the caller can report honestly.
  def self.turn_cameras(model, tr)
    ok = 0
    bad = []
    skipped = 0
    model.pages.each do |page|
      begin
        unless page.respond_to?(:use_camera?) && page.use_camera?
          skipped += 1
          next
        end
        cam = page.camera
        if cam.nil?
          skipped += 1
          next
        end
        persp  = (cam.perspective? rescue true)
        fov    = (cam.fov rescue nil)
        height = (cam.height rescue nil)
        want   = cam.eye.transform(tr)

        cam.set(cam.eye.transform(tr), cam.target.transform(tr), cam.up.transform(tr))

        # Put back whatever `set` may have disturbed.
        begin
          cam.perspective = persp
          if persp
            cam.fov = fov if fov
          elsif height
            cam.height = height
          end
        rescue StandardError
          nil
        end

        # READ IT BACK. A stored page camera is the one thing here that could
        # silently refuse the write, and a rotated model with stale scenes is
        # far worse than a clear failure.
        got = page.camera.eye
        if (got.distance(want)).abs < 0.05
          ok += 1
        else
          bad << page.name
        end
      rescue StandardError => e
        bad << "#{page.name} (#{e.class})"
      end
    end
    [ok, bad, skipped]
  end

  def self.run
    cfg = ask
    return if cfg.nil?

    model = Sketchup.active_model
    deg   = TURNS[cfg['turn']]
    if deg.nil?
      UI.messagebox("Unrecognised option: #{cfg['turn']}")
      return
    end

    tr = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0),
                                       Geom::Vector3d.new(0, 0, 1),
                                       deg.degrees)

    ents   = model.entities.to_a
    pages  = model.pages.count
    locked = ents.select { |e| (e.respond_to?(:locked?) && e.locked?) rescue false }

    puts ''
    puts '=' * 72
    puts "MAKE THIS VIEW THE FRONT — #{cfg['turn']}  (#{deg.round} deg about Z)"
    puts '=' * 72
    puts "  top-level entities  #{ents.length}#{locked.empty? ? '' : "  (#{locked.length} locked, will be unlocked and re-locked)"}"
    puts "  scenes              #{pages}#{cfg['cams'] == 'Yes' ? ' — cameras WILL be rotated with the model' : ' — cameras NOT touched, every scene will be aimed wrong'}"
    north = (model.shadow_info['NorthAngle'] rescue nil)
    puts "  north angle         #{north.nil? ? 'unreadable' : north.round(1)}" \
         "#{cfg['north'] == 'Yes' ? " -> #{north.nil? ? '?' : ((north + deg) % 360).round(1)}  (keeps shading identical)" : ' — NOT changed, shading WILL shift'}"
    puts bounds_line(model)

    if cfg['dry'] == 'Yes'
      puts ''
      puts '  DRY RUN — nothing changed. Set Dry run to No to apply.'
      puts '=' * 72
      puts ''
      return
    end

    if ents.empty?
      puts '  Nothing to rotate.'
      return
    end

    model.start_operation('Reorient model to the world axes', true)
    begin
      locked.each { |e| (e.locked = false) rescue nil }
      model.entities.transform_entities(tr, ents)
      locked.each { |e| (e.locked = true) rescue nil }

      cam_ok = 0
      cam_bad = []
      cam_skip = 0
      if cfg['cams'] == 'Yes' && pages > 0
        cam_ok, cam_bad, cam_skip = turn_cameras(model, tr)
      end

      if cfg['north'] == 'Yes' && !north.nil?
        begin
          model.shadow_info['NorthAngle'] = (north + deg) % 360
        rescue StandardError => e
          puts "  *** could not set NorthAngle: #{e.class}: #{e.message}"
        end
      end

      model.commit_operation
      model.active_view.zoom_extents

      puts ''
      puts "  rotated #{ents.length} top-level entities by #{deg.round} deg about the world origin."
      if cfg['cams'] == 'Yes' && pages > 0
        puts "  scene cameras: #{cam_ok} of #{pages} updated and VERIFIED by reading them back"
        puts "                 #{cam_skip} skipped (scene does not save a camera)" if cam_skip > 0
        unless cam_bad.empty?
          puts ''
          puts "  *** #{cam_bad.length} SCENE CAMERA(S) DID NOT TAKE THE ROTATION:"
          cam_bad.each { |n| puts "        #{n}" }
          puts '  *** Those scenes now point at where the model used to be.'
          puts '  *** Fix: open each one, orbit to the view you want, right-click'
          puts '  *** the scene tab and Update. Or Ctrl+Z this whole run.'
        end
      end
      puts bounds_line(model)
      puts ''
      puts '  Front view should now show the front. Check it before saving —'
      puts '  Ctrl+Z undoes the whole thing in one step.'
      puts '=' * 72
      puts ''
    rescue StandardError => e
      model.abort_operation
      puts "FAILED: #{e.class}: #{e.message}"
      puts e.backtrace.first(8).map { |l| "  #{l}" }.join("\n")
      puts '  Nothing was changed.'
    end
  end
end

WR_Reorient.run unless $wr_no_autorun
