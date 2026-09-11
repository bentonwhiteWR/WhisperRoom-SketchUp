# verify-caster-lift.rb — the LIVE half of the caster-plate datum fix (1.49.0).
#
# WHY IT EXISTS. Benton, 10 Sep 2026: "I told you earlier that the CP raises
# the booth 3 3/4". I was wrong, it actually raises it 4 3/4". ... That would
# make an enhanced booth, with CP 7'5 1/16"." 7'-5 1/16" is 89.0625, which is
# the drawn Enhanced height 84.3125 plus a FULL 4.75 of plate. Until 1.49.0 the
# builder measured that 4.75 to the STANDARD floor instead of to the bottom of
# the floor STACK, so on an Enhanced booth the IEP mat sank 0.3125 into the
# plate's tray floor and the booth read 88.75 = 7'-4 3/4".
#
# The arithmetic is proven offline — scripts/rbtest-overlays.py pins
# booth_lift and the 89.0625 total, scripts/rbtest-boothdims.py pins what a
# dimension then reads, and both mutants were killed. What CANNOT be proven
# outside SketchUp is that the REAL plate parts, seated by the real
# place_casters and lifted by the real build_booth, land where that arithmetic
# says: the plate bottom exactly on the ground and the tray top exactly under
# the mat. That is this script, and it needs the part share.
#
#   1. Open (or switch to) an UNTITLED model. This script REFUSES anywhere
#      else — it builds a whole booth and then erases it.
#   2. Extensions > Developer > Ruby Console.
#   3. load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/verify-caster-lift.rb"
#
# It prints one PASS/FAIL line per check and a JSON summary line. Paste the
# whole output back. It erases the booth it built in `ensure`, and says so by
# name if the cleanup itself fails.
#
# WHAT IT CANNOT CHECK. Whether the plate LOOKS seated — a gap hidden inside
# the tray is a taste call and is warned about by name at build time. It checks
# the planes: plate bottom on the ground, stack underside on the tray floor,
# ceiling top at 89.0625, nothing below z 0.

require 'json'

module WR_VerifyCasterLift
  SCRIPTS = File.expand_path('../../../scripts', __FILE__).freeze
  # Enhanced, so the mat is in play — a Standard booth cannot tell the two
  # datums apart (its stack bottom IS its floor underside) and would pass
  # either way. 7296 E is the booth Benton measured.
  KEY     = 'MDL 7296 E'.freeze
  # The drawn Enhanced height (dimension-whisperroom.rb HEIGHT_ENH) and
  # Benton's total. TOL is a sixteenth of a sixteenth: these are seated parts,
  # not measured ones, so anything but an exact landing is a defect.
  DRAWN   = 84.3125
  WANT    = 89.0625
  TOL     = 0.005

  def self.say(name, ok, detail = nil)
    puts format('  %-4s %s%s', ok ? 'PASS' : 'FAIL', name, detail ? " — #{detail}" : '')
    @res[name] = { 'ok' => !!ok, 'detail' => detail }
    ok
  end

  def self.near(got, want)
    !got.nil? && (got - want).abs <= TOL
  end

  # Every leaf instance in the booth group, as [name, world bounds].
  def self.parts(group)
    out = []
    group.entities.each do |e|
      next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      n = e.name.to_s
      n = e.definition.name.to_s if n.empty? && e.respond_to?(:definition)
      b = e.bounds
      out << [n, b.min.z.to_f, b.max.z.to_f]
    end
    out
  end

  def self.lowest(rows, re)
    hit = rows.select { |n, _z0, _z1| n =~ re }
    return nil if hit.empty?
    hit.map { |_n, z0, _z1| z0 }.min
  end

  def self.highest(rows, re)
    hit = rows.select { |n, _z0, _z1| n =~ re }
    return nil if hit.empty?
    hit.map { |_n, _z0, z1| z1 }.max
  end

  def self.run
    model = Sketchup.active_model
    if model.path.to_s != ''
      puts 'REFUSED: this builds and erases a whole booth, so it runs only in an'
      puts "         UNTITLED model. This one is #{model.path}."
      return
    end
    @res = {}
    @booth = nil
    before = model.entities.to_a

    begin
      puts "verify-caster-lift — #{KEY} on a caster plate, 1.49.0 datum"
      puts '  (build noise from the builder follows, then the checks)'

      $wr_no_autorun = true
      begin
        load File.join(SCRIPTS, 'wr-deck.rb')
        load File.join(SCRIPTS, 'wr-overlays.rb')
        load File.join(SCRIPTS, 'build-booth-components.rb')
      ensure
        $wr_no_autorun = false
      end

      # 0 — the pure arithmetic, in the REAL Ruby the plugin runs, not the
      # minimal VM the offline harness boots. Cheap, and it catches a file that
      # loaded from somewhere other than this checkout.
      say('booth_lift grounds the floor STACK on the tray floor: 6.0625 on an Enhanced booth',
          near(WR_Overlays.booth_lift(true, -1.3125), 6.0625),
          format('%.4f', WR_Overlays.booth_lift(true, -1.3125)))
      say('and 5.75 on a Standard one',
          near(WR_Overlays.booth_lift(true, -1.0), 5.75),
          format('%.4f', WR_Overlays.booth_lift(true, -1.0)))
      say("the constants still sum: plate = lift + tray",
          near(WR_Overlays::CP_PLATE_HEIGHT,
               WR_Overlays::CP_BOOTH_LIFT + WR_Overlays::CP_TRAY_DEPTH),
          format('%.2f = %.2f + %.2f', WR_Overlays::CP_PLATE_HEIGHT,
                 WR_Overlays::CP_BOOTH_LIFT, WR_Overlays::CP_TRAY_DEPTH))

      # 1 — the real build, with the caster plate on.
      WR_BuildBoothComponents.build_booth(
        KEY, {},
        'dir' => WR_BuildBoothComponents::DEFAULT_DIR,
        'hx' => false, 'dry' => false,
        'overlay' => { 'casters_plate' => true })

      made = model.entities.to_a - before
      @booth = made.find { |e| e.is_a?(Sketchup::Group) }
      unless say('the build produced a booth group', !@booth.nil?,
                 "#{made.length} new top-level entit(ies)")
        return
      end

      rows = parts(@booth)
      plate_bottom = lowest(rows, /caster plate/i)
      mat_bottom   = lowest(rows, /\AFLi\s/i)
      std_bottom   = lowest(rows, /\A(?:STD|ENH)\s*\d{2,4}\s*FL/i)
      ceil_top     = highest(rows, /\A(?:CLi\s|(?:STD|ENH)\s*\d{2,4}\s*CL)/i)
      group_bottom = @booth.bounds.min.z.to_f

      say('a caster plate was actually placed', !plate_bottom.nil?,
          plate_bottom.nil? ? 'no part named "caster plate" in the group — is the CP set on the share?' : nil)
      say('the plate bottom sits ON the ground plane (world z 0)',
          near(plate_bottom, 0.0), format('%.4f', plate_bottom.to_f))
      say('nothing in the booth hangs below the ground',
          group_bottom >= -TOL, format('group bottom %.4f', group_bottom))
      say("the IEP mat's underside seats on the tray floor, CP_BOOTH_LIFT up",
          near(mat_bottom, WR_Overlays::CP_BOOTH_LIFT), format('%.4f', mat_bottom.to_f))
      say('the standard floor underside is the mat thickness above that',
          near(std_bottom, WR_Overlays::CP_BOOTH_LIFT + 0.3125),
          format('%.4f', std_bottom.to_f))
      say("the ceiling top reads Benton's 7'-5 1/16\" (89.0625) off the ground",
          near(ceil_top, WANT), format('%.4f', ceil_top.to_f))
      say('and that is the drawn Enhanced height plus a FULL 4.75 of plate',
          near(ceil_top.to_f - DRAWN, WR_Overlays::CP_BOOTH_LIFT),
          format('%.4f', ceil_top.to_f - DRAWN))
      say('NOT the pre-1.49.0 88.75 (7\'-4 3/4"), which is what a plate seated ' \
          'under the standard floor reads',
          !near(ceil_top, 88.75), format('%.4f', ceil_top.to_f))
    rescue Exception => e
      puts "  FAIL run aborted — #{e.class}: #{e.message}"
      puts e.backtrace.first(6).map { |l| "       #{l}" }.join("\n")
      @res['run'] = { 'ok' => false, 'detail' => "#{e.class}: #{e.message}" }
    ensure
      begin
        if @booth && @booth.valid?
          model.start_operation('verify-caster-lift cleanup', true)
          @booth.erase!
          model.commit_operation
        end
      rescue StandardError => e
        puts "  CLEANUP FAILED — the booth is still in the model: #{e.message}"
      end
      n = (@res || {}).length
      bad = (@res || {}).reject { |_k, v| v['ok'] }.keys
      puts format('  %d check(s), %d failed', n, bad.length)
      puts 'VERIFY-CASTER-LIFT ' + JSON.generate('checks' => n, 'failed' => bad)
    end
  end
end

WR_VerifyCasterLift.run
