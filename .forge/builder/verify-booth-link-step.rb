# verify-booth-link-step.rb — the LIVE half of the step + caster-plate fix
# (11 Sep 2026). Same shape as verify-caster-lift.rb; read that header for the
# coordinate-space lesson its first run taught.
#
# WHY IT EXISTS. Benton, 11 Sep 2026: "Take a look at the load booth link. The
# Step is not loading at all. Also, booths with a CP need to start up higher
# when loaded. They need to load up 4 3/4" higher than they are."
#
# ONE CAUSE, BOTH SYMPTOMS (reproduced offline in the CRuby 3.2 DLL, see
# .forge/fixer/repro-step-nameerror.py). place_step's console line named
# `fl_bottom`, a local of place_all, so the first build that got the step past
# every gate raised NameError AFTER the plates were in and BEFORE add(). The
# exception escaped place_all to build_booth's rescue, which dropped place_all's
# return value and casters_in with it, so the ground pass lifted the booth by
# the NO-caster 1.3125 instead of 6.0625: no step, and a plated booth 4.75 low
# with its plates hanging under the floor. verify-caster-lift.rb could not see
# it because its build has no step.
#
# What is proven offline: place_step runs end to end against real Geom stubs
# and lands the box step_seat predicts (rbtest-overlays.py group 8), and
# place_all now fences the step so no step failure can discard casters_in
# again. What CANNOT be proven outside SketchUp is that the REAL Step.skp on
# the share loads, measures, and lands where that arithmetic says next to the
# REAL door, on a booth that really is lifted 6.0625. That is this script.
#
#   1. Open (or switch to) an UNTITLED model. This script REFUSES anywhere
#      else — it builds two whole booths and erases them.
#   2. Extensions > Developer > Ruby Console.
#   3. load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/verify-booth-link-step.rb"
#      (on the laptop: "C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/verify-booth-link-step.rb")
#
# It prints one PASS/FAIL line per check and a JSON summary line. Paste the
# whole output back — INCLUDING the builder's own lines above the checks: the
# one that matters is `STEP  Step.skp … threshold …`, and the one that must
# NOT appear is `OVERLAYS FAILED`.
#
# NOT MEASURED HERE, BENTON'S EYE ONLY: which way the tread faces
# (STEP_FRONT_AWAY) and whether the step belongs under the leaf instead of
# the frame (STEP_ALONG_OFFSET). Both are one-line constants in wr-overlays.rb.

require 'json'

module WR_VerifyBoothLinkStep
  SCRIPTS = File.expand_path('../../../scripts', __FILE__).freeze
  # Enhanced, on a plate, so the lift is the 6.0625 case (the one where the
  # mat and the plate can disagree) and the booth Benton measured at
  # 7'-5 1/16" is the one this stands the step against.
  KEY   = 'MDL 7296 E'.freeze
  WANT  = 89.0625
  TOL   = 0.005
  # The step's plan seat is a placement of a MEASURED part next to a placed
  # door; a sixteenth is the tolerance of the wall seating it copies.
  SEAT  = 0.0625

  def self.say(name, ok, detail = nil)
    puts format('  %-4s %s%s', ok ? 'PASS' : 'FAIL', name, detail ? " — #{detail}" : '')
    @res[name] = { 'ok' => !!ok, 'detail' => detail }
    ok
  end

  def self.near(got, want, tol = TOL)
    !got.nil? && (got - want).abs <= tol
  end

  # Every child's WORLD box — corners pushed through the group transform
  # (verify-caster-lift.rb's lesson: a child's bounds are its parent's frame,
  # and the parent carries the whole lift).
  def self.parts(group)
    tr = group.transformation
    out = []
    group.entities.each do |e|
      next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      n = e.name.to_s
      n = e.definition.name.to_s if n.empty? && e.respond_to?(:definition)
      b = e.bounds
      next unless b.valid?
      cs = (0..7).map { |i| b.corner(i).transform(tr) }
      out << [n, [cs.map { |c| c.x.to_f }.min, cs.map { |c| c.x.to_f }.max],
                 [cs.map { |c| c.y.to_f }.min, cs.map { |c| c.y.to_f }.max],
                 [cs.map { |c| c.z.to_f }.min, cs.map { |c| c.z.to_f }.max]]
    end
    out
  end

  def self.lowest(rows, re)
    hit = rows.select { |n, _x, _y, _z| n =~ re }
    hit.empty? ? nil : hit.map { |_n, _x, _y, z| z[0] }.min
  end

  def self.highest(rows, re)
    hit = rows.select { |n, _x, _y, _z| n =~ re }
    hit.empty? ? nil : hit.map { |_n, _x, _y, z| z[1] }.max
  end

  def self.build(model, overlay)
    before = model.entities.to_a
    WR_BuildBoothComponents.build_booth(
      KEY, {},
      'dir' => WR_BuildBoothComponents::DEFAULT_DIR,
      'hx' => false, 'dry' => false, 'overlay' => overlay)
    made = model.entities.to_a - before
    made.find { |e| e.is_a?(Sketchup::Group) }
  end

  def self.erase(model, g)
    return unless g && g.valid?
    model.start_operation('verify-booth-link-step cleanup', true)
    g.erase!
    model.commit_operation
  end

  def self.run
    model = Sketchup.active_model
    if model.path.to_s != ''
      puts 'REFUSED: this builds and erases two whole booths, so it runs only in an'
      puts "         UNTITLED model. This one is #{model.path}."
      return
    end
    @res = {}
    @booth = nil

    begin
      puts "verify-booth-link-step — #{KEY} on a caster plate WITH the step, then without"
      puts '  (build noise from the builder follows, then the checks)'

      $wr_no_autorun = true
      begin
        load File.join(SCRIPTS, 'wr-deck.rb')
        load File.join(SCRIPTS, 'wr-overlays.rb')
        load File.join(SCRIPTS, 'build-booth-components.rb')
      ensure
        $wr_no_autorun = false
      end

      # 0 — the arithmetic, in the plugin's own Ruby.
      say('step_ground_z is minus the caster lift on an Enhanced booth: -6.0625',
          near(WR_Overlays.step_ground_z(true, -1.3125), -6.0625),
          format('%.4f', WR_Overlays.step_ground_z(true, -1.3125)))
      say('the constants are the shipped ones (Step, depth 12, frame datum)',
          WR_Overlays::STEP_NAME == 'Step' && near(WR_Overlays::STEP_DEPTH, 12.0),
          format('%s %.1f offset %.2f front_away %s', WR_Overlays::STEP_NAME,
                 WR_Overlays::STEP_DEPTH, WR_Overlays::STEP_ALONG_OFFSET,
                 WR_Overlays::STEP_FRONT_AWAY))

      # 1 — THE REPORTED CASE: caster plate + step, plain door.
      puts ''
      puts '  ---- build 1: casters_plate + step ' + '-' * 40
      @booth = build(model, 'casters_plate' => true, 'step' => true)
      return unless say('build 1 produced a booth group', !@booth.nil?)

      rows = parts(@booth)
      step  = rows.find { |n, _x, _y, _z| n =~ /\AStep\s/ }
      plate_bottom = lowest(rows, /caster plate/i)
      mat_bottom   = lowest(rows, /\AFLi\s/i)
      floor_top    = highest(rows, /\A(?:STD|ENH)\s*\d{2,4}\s*FL/i)
      ceil_top     = highest(rows, /\A(?:CLi\s|(?:STD|ENH)\s*\d{2,4}\s*CL)/i)
      group_bottom = @booth.bounds.min.z.to_f

      # Defect 2 first: the booth must still be on the caster datum WITH the
      # step in the link. Before the fix this read 4.75 low (mat at 0, ceiling
      # at 84.3125) and the plates hung to -4.75.
      say('DEFECT 2: the plate bottom sits ON the ground (world z 0) with the step in the link',
          near(plate_bottom, 0.0), format('%.4f', plate_bottom.to_f))
      say("DEFECT 2: the IEP mat's underside is CP_BOOTH_LIFT (4.75) up — the booth IS lifted",
          near(mat_bottom, WR_Overlays::CP_BOOTH_LIFT), format('%.4f', mat_bottom.to_f))
      say("DEFECT 2: the ceiling top reads 7'-5 1/16\" (89.0625) — the same booth verify-caster-lift passed",
          near(ceil_top, WANT), format('%.4f', ceil_top.to_f))
      say('nothing in the booth hangs below the ground',
          group_bottom >= -TOL, format('group bottom %.4f', group_bottom))

      # Defect 1: the step is IN the model.
      unless say('DEFECT 1: a part named "Step  <door>" was placed', !step.nil?,
                 step.nil? ? 'no Step instance — look for OVERLAYS FAILED or a "STEP (sp) not placed" line above' : step[0])
        return
      end
      _n, sx, sy, sz = step
      say('the step underside sits ON the ground (world z 0)', near(sz[0], 0.0), format('%.4f', sz[0]))
      say('the step is a real part, about 5 in tall (its own measure, reported)',
          (sz[1] - sz[0]) > 2.0 && (sz[1] - sz[0]) < 8.0, format('%.4f tall', sz[1] - sz[0]))
      say('the tread is BELOW the floor top (a lip up into the booth, not a trip down)',
          !floor_top.nil? && sz[1] < floor_top + TOL,
          format('tread %.4f, floor top %.4f, lip %.4f', sz[1], floor_top.to_f, floor_top.to_f - sz[1]))

      # Where it stands, against the REAL door: centred on the frame, its
      # near face on the door's exterior face, 12 deep outward. The door is
      # the outer-shell instance "<id>  <…>Door"; the outer wall parts give
      # the booth centre so "exterior" can be told from "interior".
      outer = rows.select { |n, _x, _y, _z| n =~ /\A[NSEW]\d+\s\s/ }
      door  = outer.find { |n, _x, _y, _z| n =~ /Door/i }
      if say('an outer door instance was found to stand the step against', !door.nil?,
             door ? door[0] : 'no "<id>  …Door" among the outer parts')
        dn, dx, dy, dz = door
        wall = dn[0, 1]
        cx = (outer.map { |_n, x, _y, _z| x[0] }.min + outer.map { |_n, x, _y, _z| x[1] }.max) / 2.0
        cy = (outer.map { |_n, _x, y, _z| y[0] }.min + outer.map { |_n, _x, y, _z| y[1] }.max) / 2.0
        run_x = %w[N S].include?(wall)
        door_c  = run_x ? (dx[0] + dx[1]) / 2.0 : (dy[0] + dy[1]) / 2.0
        step_c  = run_x ? (sx[0] + sx[1]) / 2.0 : (sy[0] + sy[1]) / 2.0
        # The door's EXTERIOR face is its extreme on the side away from the centre.
        face    = case wall
                  when 'N' then dy[1]
                  when 'S' then dy[0]
                  when 'E' then dx[1]
                  else          dx[0]
                  end
        near_f  = case wall
                  when 'N' then sy[0]
                  when 'S' then sy[1]
                  when 'E' then sx[0]
                  else          sx[1]
                  end
        depth   = run_x ? sy[1] - sy[0] : sx[1] - sx[0]
        outside = case wall
                  when 'N' then sy[0] >= cy
                  when 'S' then sy[1] <= cy
                  when 'E' then sx[0] >= cx
                  else          sx[1] <= cx
                  end
        say("the step is centred on the door FRAME along the #{wall} wall (STEP_ALONG_OFFSET #{WR_Overlays::STEP_ALONG_OFFSET})",
            near(step_c - door_c, WR_Overlays::STEP_ALONG_OFFSET, SEAT),
            format('step centre %.3f, door centre %.3f', step_c, door_c))
        say("the step's near face is ON the door's exterior face",
            near(near_f, face, SEAT), format('step %.3f vs door face %.3f', near_f, face))
        say('the step stands OUTSIDE the booth', outside,
            format('booth centre (%.1f, %.1f)', cx, cy))
        say('and is about 12 in deep (its own measure, reported)',
            near(depth, WR_Overlays::STEP_DEPTH, 1.0), format('%.3f', depth))
      end

      erase(model, @booth)
      @booth = nil

      # 2 — THE GATE: step in the link, NO plate → no step, booth on the
      # no-caster datum (mat underside on the ground).
      puts ''
      puts '  ---- build 2: step WITHOUT a caster plate ' + '-' * 34
      @booth = build(model, 'step' => true)
      return unless say('build 2 produced a booth group', !@booth.nil?)
      rows = parts(@booth)
      say('no step without a plate (refused by name — expect a "STEP (sp) not placed: no caster plate" line above)',
          rows.none? { |n, _x, _y, _z| n =~ /\AStep\s/ })
      say("the IEP mat's underside is on the ground (1.3125 lift, no caster datum)",
          near(lowest(rows, /\AFLi\s/i), 0.0), format('%.4f', lowest(rows, /\AFLi\s/i).to_f))
    rescue Exception => e
      puts "  FAIL run aborted — #{e.class}: #{e.message}"
      puts e.backtrace.first(6).map { |l| "       #{l}" }.join("\n")
      @res['run'] = { 'ok' => false, 'detail' => "#{e.class}: #{e.message}" }
    ensure
      begin
        erase(model, @booth)
      rescue StandardError => e
        puts "  CLEANUP FAILED — a booth is still in the model: #{e.message}"
      end
      n = (@res || {}).length
      bad = (@res || {}).reject { |_k, v| v['ok'] }.keys
      puts format('  %d check(s), %d failed', n, bad.length)
      puts 'VERIFY-BOOTH-LINK-STEP ' + JSON.generate('checks' => n, 'failed' => bad)
    end
  end
end

WR_VerifyBoothLinkStep.run
