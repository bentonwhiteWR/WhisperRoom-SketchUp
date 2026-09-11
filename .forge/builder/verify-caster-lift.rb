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
# FIRST LIVE RUN, 10 Sep 2026 — Benton ran it, 12 checks, 5 failed, AND THE
# GEOMETRY WAS ALREADY RIGHT. The script was reading child bounds without the
# group transform, so it reported booth-LOCAL numbers: plate -6.0625, mat
# -1.3125, standard floor -1.0000, ceiling top 83.0000. Add the 6.0625 lift
# the build log printed on the same run and every one of them is the right
# world figure, the ceiling top landing on 89.0625 exactly. The one check that
# used the group's own bounds ('nothing hangs below the ground') passed at
# 0.0000, which is the tell. Fixed in parts() below; the frame check added
# beside it fails loudly if that reader ever slips back into local space.
# Nothing in the product code was changed for this — wr-overlays and
# build-booth-components were producing Benton's number all along.
#
# THE PLATE'S WHEELS. Benton, same run: "also, the CP wheels may not be
# PERFECTLY heighted to say that dimension. Just an fyi." 4.75 is the DESIGN
# datum and this script checks the model against it. A physical plate whose
# wheels sit a fraction off is not a defect in the model and nothing here
# should be adjusted to chase one.
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

  # THE COORDINATE SPACE, and the first live run got it wrong (10 Sep 2026).
  # Entity#bounds on a CHILD is in its PARENT's frame — booth-local here — and
  # the booth group carries the whole caster lift in its own transformation.
  # So a raw child read is short by exactly the lift, and the first run
  # reported -6.0625 / -1.3125 / -1.0000 / 83.0000: every number right, every
  # one of them in the wrong frame, five FAILs against geometry that was
  # already producing Benton's figure. The group's OWN bounds are world, which
  # is why 'nothing hangs below the ground' passed at exactly 0.0000 while the
  # rest failed — that check is the known-good reference, and the frame check
  # below ties this reader back to it.
  #
  # Every z here is therefore pushed through the group transform first. Bounds
  # are axis-aligned and the lift is a pure translation, but the corners are
  # transformed rather than the min/max offset, so a build that ever rotates
  # or scales the group reads correctly instead of plausibly.
  def self.parts(group)
    tr = group.transformation
    out = []
    group.entities.each do |e|
      next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      n = e.name.to_s
      n = e.definition.name.to_s if n.empty? && e.respond_to?(:definition)
      b = e.bounds
      next unless b.valid?
      zs = (0..7).map { |i| b.corner(i).transform(tr).z.to_f }
      out << [n, zs.min, zs.max]
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
      # THE FRAME CHECK. The group's own bounds are world by definition; the
      # per-part reader above has to agree with them or it is reading the
      # booth's local frame, which is the defect the first live run had.
      say("the per-part reader is in the same frame as the group's own bounds",
          near(group_bottom, plate_bottom.to_f),
          format('group %.4f vs plate %.4f', group_bottom, plate_bottom.to_f))
      say("the IEP mat's underside seats on the tray floor, CP_BOOTH_LIFT up",
          near(mat_bottom, WR_Overlays::CP_BOOTH_LIFT), format('%.4f', mat_bottom.to_f))
      say('the standard floor underside is the mat thickness above that',
          near(std_bottom, WR_Overlays::CP_BOOTH_LIFT + 0.3125),
          format('%.4f', std_bottom.to_f))
      say("the ceiling top reads Benton's 7'-5 1/16\" (89.0625) off the ground",
          near(ceil_top, WANT), format('%.4f', ceil_top.to_f))
      # MEASURED END TO END, not off the ground: plate bottom to ceiling top
      # is the booth's own height and does not care where z 0 is, so it stands
      # even if the group is one day placed somewhere other than the origin.
      # It is also the figure Benton reads off a drawing.
      span = (ceil_top.nil? || plate_bottom.nil?) ? nil : ceil_top - plate_bottom
      say("plate bottom to ceiling top measures 7'-5 1/16\" (89.0625)",
          near(span, WANT), span.nil? ? 'not measurable' : format('%.4f', span))
      say('and that is the drawn Enhanced height plus a FULL 4.75 of plate',
          near(span.to_f - DRAWN, WR_Overlays::CP_BOOTH_LIFT),
          format('%.4f', span.to_f - DRAWN))
      # The pre-1.49.0 seating read 88.75 end to end. Asserting the SPAN is
      # 0.3125 OVER it, rather than merely 'not 88.75', keeps this a real
      # measurement of both ends instead of a restatement of the check above.
      say('a full 0.3125 over the pre-1.49.0 88.75 (7 ft 4 3/4 in) — the mat that used to sit buried in the tray',
          near(span.to_f - 88.75, 0.3125), format('%.4f over 88.75', span.to_f - 88.75))
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
