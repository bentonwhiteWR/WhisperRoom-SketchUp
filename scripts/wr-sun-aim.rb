# @title Light It From Here...
# @cat V-Ray renders
# @rank 2
#
# wr-sun-aim.rb — snap the SUN to the camera's current view. THE MODEL NEVER
# MOVES.
#
#   Extensions > Developer > Ruby Console, then:
#     load "C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-sun-aim.rb"
#
# ===========================================================================
# WHY THIS EXISTS
#
# reorient-model.rb documents the habit this replaces: orbit to a shot that
# looks right, notice the lighting is wrong, and "fix" it by rotating the
# whole model until the sun lands somewhere better. That drags every wall,
# every dimension entity and every saved scene camera along with it, for a
# problem that was never about the geometry.
#
# The sun is a SETTING (ShadowInfo), not a lit thing glued to the model. This
# button reads where the camera is looking, works out where the sun would
# have to be to light that, and writes ONLY shadow_info — NorthAngle and the
# time of day. Nothing under model.entities is touched, no scene camera is
# touched, and undo removes exactly one operation.
#
# ===========================================================================
# THE 30 DEGREE OFFSET IS DELIBERATE — DO NOT SIMPLIFY IT AWAY
#
# Put the sun exactly where "light it from here" sounds like it means — dead
# behind the camera, shining straight down the same line the camera is
# looking along — and every face the camera can see gets hit square-on by the
# light. Square-on light has no falloff across the face, so nothing in the
# shot reads as a solid: a booth panel looks like a flat orange card because
# there is no shaded side to prove it has depth. This is the exact failure
# on-camera flash has in real photography, for the same optical reason.
#
# The fix is an azimuth offset: swing the sun's compass bearing to one side
# of "dead behind the camera" before setting it. One face stays lit, an
# adjacent face falls into shadow, and the shadow edge is what the eye reads
# as an edge. ~30 degrees is a reasonable default for a booth-sized subject —
# enough to separate the faces, not so much that the shot goes to mostly-
# shadow. It is exposed as a signed number in the dialog (negative swings to
# the other side) so it can be tuned per shot; it is NOT hard-coded and must
# not become hard-coded later. Removing the offset control removes the whole
# reason this script exists over just setting NorthAngle to the camera
# azimuth directly.
#
# ===========================================================================
# TWO THINGS VERIFIED BEFORE WRITING THIS, AND HOW
#
# 1. DOES NorthAngle COMPOSE ADDITIVELY WITH THE DATE/TIME AZIMUTH?
#
#    Checked against the real SketchUp Ruby API docs (ruby.sketchup.com) and
#    the SketchUp Help Center, not memory. The documented ShadowInfo keys
#    confirm NorthAngle, SunDirection and ShadowTime all exist and behave as
#    expected, but the Ruby API reference does not state HOW NorthAngle and
#    the astronomically-computed azimuth combine. The Help Center's own
#    description of the Shadow dialog's North Angle field says it is "the
#    angle... measured clockwise from Virtual North to the orange axis" —
#    which strongly implies a straight additive rotation of the whole sun
#    position — but "implies" is not "confirmed", and this is exactly the
#    kind of numeric, version-specific behaviour that is dangerous to trust
#    from fluency alone.
#
#    So this script does NOT hard-code a formula. `calibrate` nudges
#    NorthAngle by a known step directly in the live model, reads
#    SunDirection back before and after, and measures what actually moved.
#    That is the one function the composition rule lives in
#    (WR_SunAim.calibrate) — if a future SketchUp build changes the
#    relationship, this is the only place that needs to change, and a run
#    that disagrees with its own measurement flags itself LOW CONFIDENCE in
#    the report window rather than silently reporting a wrong azimuth.
#
# 2. DOES A SCENE STORE ITS OWN SHADOW SETTINGS?
#
#    Yes — confirmed against the Ruby API docs for Sketchup::Page: a page has
#    its own #shadow_info, and #use_shadow_info? / #use_shadow_info= control
#    whether that page remembers shadow settings (NorthAngle included) the
#    way it remembers a camera. In practice (SketchUp community reports, not
#    tested here) this works reliably only when the page's transition time is
#    0 — with a transition running, the model's live ShadowInfo can overwrite
#    what the page saved. PRACTICAL UPSHOT: once wr-mode.rb or the proposal
#    scenes give each plate its own scene with transitions off, each plate
#    CAN carry its own sun position independent of the others. This script
#    does not attempt that itself — it edits the model's live shadow_info
#    only, which is what the ACTIVE view uses regardless of scenes.
#
# ===========================================================================
# ONE ASSUMPTION THIS SCRIPT MAKES THAT IS NOT VERIFIED, AND WHERE TO FIX IT
#
# "Light it from here" is read as: put the sun roughly WHERE THE CAMERA IS
# STANDING (so it lights the faces the camera sees, the way on-camera flash
# or a light next to the photographer would), not roughly where the camera is
# LOOKING. That is the SUN_BEHIND_CAMERA constant below, and it is a DERIVED
# choice, not an observed one — nobody has looked at a real render from this
# script yet. If the first real run lights the wrong side of the booth (the
# far side lights up instead of the near side facing the camera), flip
# SUN_BEHIND_CAMERA to false — that is the one line to change, nothing else
# in the geometry needs touching.
#
# ===========================================================================
# THE OPEN QUESTION THIS SCRIPT DELIBERATELY DOES NOT ANSWER
#
# Whether V-Ray's SunLight reads SketchUp's shadow_info or holds its own
# independent direction is UNKNOWN. probe-vray.rb exists to answer that and
# has not been run. This script calls no V-Ray API at all, on purpose — the
# math for "where should the sun be" is the same either way; only the
# question of whether writing shadow_info is enough to move a V-Ray render is
# still open.
#
# ===========================================================================
# THIS SCRIPT HAS NOT BEEN RUN
#
# There is no ruby.exe on this machine outside SketchUp, so nothing here has
# executed. `python scripts/rbparse.py` confirms it is syntactically valid
# CRuby 3.2 — the same parser SketchUp 2024 ships — but a clean parse is not
# evidence the math or the API calls are correct. Everything below fails
# loudly into the report window or the console rather than doing nothing.

require 'sketchup.rb'
require 'json'

module WR_SunAim
  PREF = 'WR_SunAim'.freeze

  # See "THE 30 DEGREE OFFSET IS DELIBERATE" above before changing this.
  DEFAULT_OFFSET_DEG = 30.0

  # How far NorthAngle is nudged, in the live model, to measure how it moves
  # the sun. See "DOES NorthAngle COMPOSE ADDITIVELY" above.
  CALIB_STEP_DEG = 10.0

  # A measured step within this many degrees of CALIB_STEP_DEG counts as
  # confirming a clean linear (additive) relationship. Anything looser gets
  # reported LOW CONFIDENCE rather than silently trusted.
  CALIB_TOLERANCE_DEG = 2.0

  DEFAULT_HOUR = 10.0

  # ==========================================================================
  # THE MODEL IS PINNED TO KNOXVILLE, EST. Benton, 2026-08-27: "do something to
  # just set this time in EST permanently."
  # ==========================================================================
  #
  # Sun ELEVATION is a function of date, latitude and time zone. This tool only
  # ever solved AZIMUTH, so a model carrying a stale or unset geo-location put
  # the sun below the horizon and rendered black while the dialog reported a
  # clean aim - which is exactly what happened, and cost an afternoon.
  #
  # Every booth this shop draws is quoted, built and installed out of Knoxville,
  # and every render is a daylight product shot rather than a site-accurate
  # solar study. So there is no case here for a per-model location, and leaving
  # it to whatever a model was last saved with is how it broke. The zone is
  # pinned on every press.
  #
  # WHAT IS AND IS NOT OVERWRITTEN, and the asymmetry is deliberate:
  #   TZOffset  is ALWAYS written. That is what "permanently EST" was asked for,
  #             and a wrong zone is the defect being fixed.
  #   Latitude
  #   Longitude are written ONLY when the model has none. A model that has been
  #             deliberately geo-located to a CLIENT SITE keeps its location -
  #             silently dragging a surveyed site back to Knoxville would be a
  #             worse bug than the one this fixes.
  #
  # EST, not EDT. -5 year round, deliberately: the difference is one hour of sun
  # angle on a product shot nobody is reading a sundial off, and a DST rule that
  # has to be right twice a year is a second thing to get wrong.
  EST_TZ_OFFSET = -5.0
  KNOXVILLE_LAT = 35.9606
  KNOXVILLE_LNG = -83.9207

  # See "ONE ASSUMPTION THIS SCRIPT MAKES" above. Flip this single line if a
  # real render comes back lit from the wrong side.
  SUN_BEHIND_CAMERA = true

  # ------------------------------------------------------------- geometry --

  def self.norm360(deg)
    d = deg.to_f % 360.0
    d += 360.0 if d < 0
    d
  end

  # Shortest signed difference a - b, in (-180, 180].
  def self.ang_diff(a, b)
    d = norm360(a - b)
    d -= 360.0 if d > 180.0
    d
  end

  # Azimuth of a vector's horizontal (x, y) component, degrees, 0..360, using
  # a plain atan2(y, x) convention. This does NOT need to match SketchUp's own
  # "clockwise from Virtual North" convention — camera_azimuth and every sun
  # azimuth this file computes all go through this one function, so whatever
  # convention it uses, it is used consistently and the internal math is
  # self-consistent regardless.
  #
  # Returns nil when the vector is (near) vertical — straight up or straight
  # down — where azimuth is not meaningfully defined. That happens for the
  # camera when looking near-straight down at a plan, and for the sun very
  # near the zenith.
  def self.azimuth_of(vec)
    x = vec.x.to_f
    y = vec.y.to_f
    return nil if x.abs < 1.0e-6 && y.abs < 1.0e-6
    norm360(Math.atan2(y, x) * 180.0 / Math::PI)
  end

  # Elevation in degrees above the horizon, from a (not-necessarily-unit)
  # direction vector. nil if the vector is degenerate.
  def self.elevation_of(vec)
    x = vec.x.to_f
    y = vec.y.to_f
    z = vec.z.to_f
    mag = Math.sqrt(x * x + y * y + z * z)
    return nil if mag < 1.0e-9
    ratio = (z / mag)
    ratio = 1.0 if ratio > 1.0
    ratio = -1.0 if ratio < -1.0
    Math.asin(ratio) * 180.0 / Math::PI
  end

  def self.camera_azimuth(view)
    azimuth_of(view.camera.direction)
  end

  # ---------------------------------------------------------- calibration --
  #
  # Measures, in the live model, how many degrees the sun's world azimuth
  # actually moves per degree of NorthAngle, and in which rotational sense.
  # See the header comment — this is the one function the composition rule
  # lives in. Leaves NorthAngle exactly where it found it.
  def self.calibrate(model)
    si = model.shadow_info
    orig = si['NorthAngle'].to_f
    begin
      si['NorthAngle'] = 0.0
      az0 = azimuth_of(si['SunDirection'])
      si['NorthAngle'] = CALIB_STEP_DEG
      az1 = azimuth_of(si['SunDirection'])
    ensure
      si['NorthAngle'] = orig
    end

    if az0.nil? || az1.nil?
      return { :ok => false,
               :reason => 'the sun is too near the zenith at this date/time/location ' \
                          'for an azimuth to be measurable' }
    end

    delta = ang_diff(az1, az0)
    sign = delta >= 0 ? 1.0 : -1.0
    slack = (delta.abs - CALIB_STEP_DEG).abs
    { :ok => true, :az0 => az0, :sign => sign, :slack => slack,
      :confident => slack < CALIB_TOLERANCE_DEG }
  end

  # NorthAngle that puts the sun's world azimuth at target_az, given a
  # calibration from #calibrate. world_az(NA) ~= az0 + sign * NA (mod 360),
  # so NA = sign * (target_az - az0) (mod 360) — sign is +-1.0, so this is
  # its own inverse.
  def self.solve_north_angle(calib, target_az)
    norm360(calib[:sign] * (target_az.to_f - calib[:az0]))
  end

  # --------------------------------------------------------------- action --

  # Does the whole thing: reads the camera, calibrates, solves, writes
  # shadow_info, reads the result back, and reports what actually happened
  # rather than what was asked for. One start_operation/commit_operation, so
  # Ctrl+Z undoes calibration probes, the time change and the NorthAngle
  # change together as a single step.
  def self.light_it_from_here(model, view, offset_deg, hour)
    return { :ok => false, :reason => 'no active model' } if model.nil?
    return { :ok => false, :reason => 'no active view' } if view.nil?

    cam_az = camera_azimuth(view)
    if cam_az.nil?
      return { :ok => false,
               :reason => 'the camera is looking straight up or straight down — ' \
                          'azimuth is undefined from this view. Orbit to an angled view and try again.' }
    end

    base = SUN_BEHIND_CAMERA ? norm360(cam_az + 180.0) : cam_az
    target_az = norm360(base + offset_deg.to_f)

    si = model.shadow_info
    result = nil
    model.start_operation('Light it from here (sun aim)', true)
    begin
      calib = calibrate(model)
      unless calib[:ok]
        model.abort_operation
        return calib.merge(:ok => false)
      end

      # PIN THE ZONE FIRST, BEFORE THE TIME IS COMPUTED OR THE SUN IS READ.
      # Order matters: TZOffset moves the sun, so writing it after solving the
      # azimuth would invalidate the solve that was just done.
      geo_note = []
      begin
        had_tz = (si['TZOffset'] rescue nil)
        si['TZOffset'] = EST_TZ_OFFSET
        geo_note << format('TZ %s -> %g (EST, pinned)',
                           had_tz.nil? ? '(unset)' : had_tz.to_s, EST_TZ_OFFSET)
      rescue StandardError => e
        geo_note << "TZOffset would not write: #{e.class}: #{e.message}"
      end
      begin
        lat = (si['Latitude'] rescue nil)
        lng = (si['Longitude'] rescue nil)
        # "No location" is nil, or the 0,0 the API reports for an ungeolocated
        # model. A real site is never at Null Island.
        # ALWAYS WRITTEN, NOT ONLY WHEN UNSET, AND THE FIRST VERSION OF THIS
        # BLOCK HAD IT WRONG. It wrote Knoxville only if the model had no
        # location - which sounds careful and is useless here, because SketchUp
        # pre-fills its Geo-location dialog with BOULDER, CO on a model that is
        # "not geo-located". Accept that default by reflex and the model now HAS
        # a location, so the careful version would have kept Boulder while
        # pinning the zone to EST: a two-hour error, and a sun placed for the
        # wrong latitude, with nothing on screen saying so.
        #
        # Every render this shop makes is a daylight product shot of a booth
        # built and shipped out of Knoxville. There is no case for a per-model
        # location, so it is pinned rather than negotiated. A genuine
        # site-accurate solar study is a different job and wants a different
        # tool; it must not be something you get by accident from a stale
        # default.
        si['Latitude']  = KNOXVILLE_LAT
        si['Longitude'] = KNOXVILLE_LNG
        was = (lat.nil? || lng.nil?) ? '(none)' : format('%.4f, %.4f', lat.to_f, lng.to_f)
        geo_note << format('location %s -> Knoxville %.4f, %.4f (pinned)',
                           was, KNOXVILLE_LAT, KNOXVILLE_LNG)
      rescue StandardError => e
        geo_note << "location would not write: #{e.class}: #{e.message}"
      end

      t0 = (si['ShadowTime'] rescue nil)
      base_time = t0.is_a?(Time) ? t0 : Time.now
      h = hour.to_f
      h = DEFAULT_HOUR unless h.finite? && h >= 0.0 && h <= 24.0
      hh = h.to_i
      mm = ((h - hh) * 60.0).round
      # ====================================================================
      # ShadowTime IS UTC. Time.new IS NOT. THAT IS THE WHOLE BUG.
      # ====================================================================
      #
      # Benton, 2026-08-27, after a V-Ray render came out black with the dialog
      # reporting a clean aim and a sun elevation of -8.0 at 12:30: "the time of
      # day part of the tool is totally broken. thats whats going on." He is
      # right, and this is where.
      #
      # `Time.new(y, m, d, hh, mm, 0)` builds a time in the SYSTEM's local zone.
      # SketchUp's ShadowTime is a UTC Time whose FIELDS carry the model's local
      # wall clock - which is why the Shadows dialog shows 12:30 for a value
      # whose UTC hour is 12. Handing it a system-local Time means the zone
      # offset is baked into the value before SketchUp ever sees it, and the
      # solar engine then reads those shifted fields as the wall clock. On this
      # machine that is a five-hour push: ask for 12:30 and the sun is placed
      # for 17:30, which in November is past sunset. Hence -8.0, hence black.
      #
      # It also means the tool behaved DIFFERENTLY on different machines, and
      # identically-set sliders would have produced different renders on
      # Benton's laptop and desktop if their zones ever differed. Nothing in the
      # old code could have caught that; there was no read-back.
      #
      # Time.utc is the documented idiom and the fix. The date still comes from
      # whatever the model already had - this tool sets the hour, never the day.
      new_time = Time.utc(base_time.year, base_time.month, base_time.day, hh, mm, 0)
      time_stuck = nil
      begin
        si['ShadowTime'] = new_time
      rescue StandardError => e
        time_stuck = "#{e.class}: #{e.message}"
      end

      # READ IT BACK AND REPORT WHAT SKETCHUP ACTUALLY HOLDS.
      #
      # The same discipline `calibrate` already uses on NorthAngle: do not
      # assume a write landed, measure it. If the hour SketchUp reports differs
      # from the hour that was asked for, the zone handling is still wrong and
      # the number says so instead of a black render saying it three steps
      # later. This is also how the Time.utc fix gets CONFIRMED rather than
      # believed - nothing here can run SketchUp.
      got_t = (si['ShadowTime'] rescue nil)
      hour_readback = if got_t.is_a?(Time)
                        g = got_t.utc rescue got_t
                        (g.hour + g.min / 60.0)
                      end
      hour_drift = hour_readback.nil? ? nil : (hour_readback - h)

      orig_na = si['NorthAngle'].to_f
      na = solve_north_angle(calib, target_az)
      si['NorthAngle'] = na

      achieved = azimuth_of(si['SunDirection'])
      elev = elevation_of(si['SunDirection'])
      err = achieved.nil? ? nil : ang_diff(achieved, target_az).abs

      model.commit_operation

      result = {
        :ok => true,
        :camera_azimuth => cam_az,
        :sun_behind_camera => SUN_BEHIND_CAMERA,
        :offset => offset_deg.to_f,
        :target_azimuth => target_az,
        :north_angle_before => orig_na,
        :north_angle_after => na,
        :achieved_azimuth => achieved,
        :error_deg => err,
        :elevation_deg => elev,
        :calibration_confident => calib[:confident],
        :calibration_slack => calib[:slack],
        :time_set => new_time.strftime('%Y-%m-%d %H:%M'),
        :time_stuck => time_stuck,
        :geo_note => geo_note,
        :hour_asked => h,
        :hour_readback => hour_readback,
        :hour_drift => hour_drift,
        # THE THREE SETTINGS THIS TOOL DOES NOT WRITE, REPORTED SO A BLACK
        # RENDER IS SELF-DIAGNOSING.
        #
        # Elevation is a function of DATE, LATITUDE and TIMEZONE. This tool
        # solves azimuth only - it sets the hour and leaves the date exactly as
        # the model has it - so when the sun comes out below the horizon the
        # cause is always one of these three and never the offset slider. They
        # were invisible before, which is how "light it from here" could report
        # a successful aim and a -8 degree sun in the same breath.
        :latitude  => (si['Latitude']  rescue nil),
        :longitude => (si['Longitude'] rescue nil),
        :tz_offset => (si['TZOffset']  rescue nil),
        :city      => (si['City']      rescue nil)
      }
    rescue StandardError => e
      model.abort_operation
      result = { :ok => false, :reason => "#{e.class}: #{e.message}" }
    end
    result
  end

  # ------------------------------------------------------------------ UI --

  def self.run
    model = Sketchup.active_model
    if model.nil?
      UI.messagebox('No active model.')
      return
    end

    si = model.shadow_info
    cur_hour = begin
      t = si['ShadowTime']
      t.is_a?(Time) ? (t.hour + t.min / 60.0) : DEFAULT_HOUR
    rescue StandardError
      DEFAULT_HOUR
    end
    cur_hour = DEFAULT_HOUR unless cur_hour.finite? && cur_hour.between?(0.0, 24.0)

    d = UI::HtmlDialog.new(
      :dialog_title    => 'Light It From Here',
      :preferences_key => 'com.whisperroom.sunaim',
      :scrollable      => true,
      :resizable       => true,
      :width           => 400,
      :height          => 560,
      :min_width       => 360,
      :min_height      => 460,
      :style           => UI::HtmlDialog::STYLE_DIALOG
    )
    d.set_html(html(cur_hour))

    d.add_action_callback('apply') do |_c, json|
      opts = begin
        JSON.parse(json.to_s)
      rescue StandardError
        {}
      end
      m = Sketchup.active_model
      v = (m.active_view rescue nil)
      result = light_it_from_here(m, v, opts['offset'], opts['hour'])
      if result[:ok]
        puts ''
        puts 'LIGHT IT FROM HERE'
        puts format('  camera azimuth       %.1f deg', result[:camera_azimuth])
        puts format('  offset               %+.1f deg (%s)', result[:offset],
                    SUN_BEHIND_CAMERA ? 'sun placed behind the camera' : 'sun placed toward the camera target')
        puts format('  target sun azimuth   %.1f deg', result[:target_azimuth])
        puts format('  NorthAngle           %.1f deg -> %.1f deg', result[:north_angle_before], result[:north_angle_after])
        puts format('  achieved sun azimuth %s', result[:achieved_azimuth].nil? ? 'unreadable' : format('%.1f deg (off target by %.2f deg)', result[:achieved_azimuth], result[:error_deg].to_f))
        puts format('  elevation            %s', result[:elevation_deg].nil? ? 'unreadable' : format('%.1f deg', result[:elevation_deg]))
        (result[:geo_note] || []).each { |g| puts "  geo                  #{g}" }
        puts format('  hour asked           %.2f', result[:hour_asked]) unless result[:hour_asked].nil?
        puts format('  hour SketchUp holds  %s%s',
                    result[:hour_readback].nil? ? 'unreadable' : format('%.2f', result[:hour_readback]),
                    (result[:hour_drift] && result[:hour_drift].abs > 0.02) ?
                      format('   *** DRIFT %+.2f h - the zone handling is STILL wrong', result[:hour_drift]) : '')
        puts format('  location             %s lat %s  lng %s  TZ %s',
                    result[:city] || '(none set)',
                    result[:latitude] || '?', result[:longitude] || '?',
                    result[:tz_offset] || '?')
        # BELOW THE HORIZON IS NIGHT, AND NIGHT RENDERS BLACK.
        #
        # Benton, 2026-08-27, on a V-Ray render that came out entirely black:
        # "help me out here. Its like no light renders now." The dialog was
        # reporting a clean aim and a sun elevation of -8.0 at 12:30, and
        # nothing connected the two. It does now.
        if !result[:elevation_deg].nil? && result[:elevation_deg] <= 0.0
          puts ''
          puts '  *** THE SUN IS BELOW THE HORIZON. It is night in this model and'
          puts '      any render will come out black no matter where the sun is'
          puts '      AIMED. Azimuth is what this tool sets; elevation comes from'
          puts '      the DATE, the LATITUDE and the TIME ZONE above, and this'
          puts '      tool writes none of them - it keeps the date the model'
          puts '      already had. Fix it in Window > Model Info > Geo-location'
          puts '      (or Window > Shadows for the date), then press the button'
          puts '      again. A midday sun in Knoxville reads about 35 to 70 deg.'
        end
        puts format('  time set             %s', result[:time_set])
        puts format('  calibration          %s (slack %.2f deg)', result[:calibration_confident] ? 'confident' : 'LOW CONFIDENCE', result[:calibration_slack].to_f)
        puts "  *** ShadowTime would not write: #{result[:time_stuck]}" if result[:time_stuck]
      else
        puts ''
        puts "LIGHT IT FROM HERE — did not run: #{result[:reason]}"
      end
      d.execute_script("WR.report(#{result.to_json})")
    end

    d.add_action_callback('close') { |_c| d.close }
    d.show
    nil
  end

  def self.html(cur_hour)
    <<-HTML
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Light It From Here</title>
<style>
  :root { --bg:#f4f5f6; --surface:#fff; --ink:#1c2327; --muted:#66727a;
          --faint:#9aa4ab; --line:#e2e6e9; --accent:#ee6216; --soft:#fdeee4;
          --bad:#b0402c; --badbg:#fbe9e5; }
  * { box-sizing:border-box; margin:0; }
  html,body { height:100%; }
  body { font:13px/1.45 "Segoe UI",system-ui,sans-serif; background:var(--bg);
         color:var(--ink); display:flex; flex-direction:column; overflow:hidden; }
  ::-webkit-scrollbar { width:9px; height:9px; }
  ::-webkit-scrollbar-thumb { background:#c9d0d5; border-radius:5px; }

  .top { padding:12px 14px 4px; }
  .top .t { font-weight:650; font-size:14px; }
  .top .c { color:var(--muted); font-size:11.5px; margin-top:2px; }

  .card { margin:10px 14px; padding:12px 13px; background:var(--surface);
          border:1px solid var(--line); border-radius:9px; }
  .field { margin-bottom:12px; }
  .field:last-child { margin-bottom:0; }
  .field label { display:flex; justify-content:space-between; align-items:baseline;
                 font-size:11px; font-weight:650; letter-spacing:.04em; color:var(--muted); }
  .field label .val { font-variant-numeric:tabular-nums; color:var(--ink); font-weight:650; }
  .field input[type=range] { width:100%; margin-top:6px; accent-color:var(--accent); }
  .field .hint { color:var(--faint); font-size:10.5px; margin-top:3px; }
  .field input[type=number] { width:100%; margin-top:6px; padding:6px 8px; font:inherit;
    border:1px solid var(--line); border-radius:6px; }

  .go { margin:0 14px 10px; width:calc(100% - 28px); padding:10px; font:inherit;
        font-weight:650; border:0; border-radius:8px; background:var(--accent);
        color:#fff; cursor:pointer; }
  .go:hover { filter:brightness(1.05); }
  .go:active { filter:brightness(0.95); }
  .go-hint { margin:-4px 14px 10px; color:var(--faint); font-size:10.5px; }

  .wrap { flex:1 1 auto; overflow:auto; margin:0 14px 14px; }
  #out .row { display:flex; justify-content:space-between; gap:10px; padding:6px 0;
              border-bottom:1px solid var(--line); font-size:12.5px; }
  #out .row .k { color:var(--muted); }
  #out .row .v { font-weight:600; text-align:right; }
  #out .bad { padding:10px; background:var(--badbg); color:var(--bad); border-radius:8px;
              font-size:12.5px; }
  #out .flag { padding:8px 10px; background:var(--badbg); color:var(--bad); border-radius:6px;
               font-size:11.5px; margin-top:8px; }
  #out .empty { color:var(--faint); font-size:12px; padding:6px 0; }
</style></head><body>

<div class="top">
  <div class="t">Light It From Here</div>
  <div class="c">Orbit to the shot you want, then press it. The sun moves; the model does not.</div>
</div>

<div class="card">
  <div class="field">
    <label>Offset from dead-behind-camera <span class="val" id="offv">+30&deg;</span></label>
    <input type="range" id="off" min="-90" max="90" step="1" value="30">
    <div class="hint">Puts one face in shadow so the shot reads as solid, not flat.
      Negative swings the light to the other side. Do not set this to 0 for a hero shot.</div>
  </div>
  <div class="field">
    <label>Time of day <span class="val" id="hrv">10:00</span></label>
    <input type="range" id="hr" min="6" max="18" step="0.25" value="#{'%.2f' % cur_hour}">
    <div class="hint">Low, raking light near the ends of the range; high and even near midday.
      Date is left as the model already has it.</div>
  </div>
</div>

<button class="go" id="apply">Light it from here</button>
<div class="go-hint">Re-orbit and press again any time — the dialog stays open.</div>

<div class="wrap"><div id="out"><div class="empty">Nothing applied yet.</div></div></div>

<script>
(function () {
  "use strict";
  var $off = document.getElementById("off"), $offv = document.getElementById("offv");
  var $hr  = document.getElementById("hr"),  $hrv  = document.getElementById("hrv");
  var $out = document.getElementById("out");

  function hFmt(h) {
    var hh = Math.floor(h), mm = Math.round((h - hh) * 60);
    if (mm === 60) { mm = 0; hh += 1; }
    return (hh < 10 ? "0" : "") + hh + ":" + (mm < 10 ? "0" : "") + mm;
  }
  function syncOff() { $offv.textContent = (+$off.value >= 0 ? "+" : "") + $off.value + "\\u00b0"; }
  function syncHr()  { $hrv.textContent = hFmt(+$hr.value); }
  $off.addEventListener("input", syncOff);
  $hr.addEventListener("input", syncHr);
  syncOff(); syncHr();

  document.getElementById("apply").addEventListener("click", function () {
    if (window.sketchup && sketchup.apply) {
      sketchup.apply(JSON.stringify({ offset: +$off.value, hour: +$hr.value }));
    }
  });

  function fmt(v, d) {
    if (v === null || v === undefined) return "unreadable";
    return Number(v).toFixed(d === undefined ? 1 : d) + "\\u00b0";
  }

  window.WR = {
    report: function (r) {
      if (!r || !r.ok) {
        $out.innerHTML = '<div class="bad">Did not run: ' +
          (r && r.reason ? r.reason : "unknown error") + "</div>";
        return;
      }
      var rows = [
        ["Camera azimuth", fmt(r.camera_azimuth)],
        ["Sun placed", r.sun_behind_camera ? "behind the camera" : "toward the camera target"],
        ["Offset applied", (r.offset >= 0 ? "+" : "") + fmt(r.offset, 0)],
        ["Target sun azimuth", fmt(r.target_azimuth)],
        ["NorthAngle", fmt(r.north_angle_before) + " \\u2192 " + fmt(r.north_angle_after)],
        ["Achieved sun azimuth", fmt(r.achieved_azimuth) +
          (r.error_deg != null ? "  (off by " + fmt(r.error_deg, 2) + ")" : "")],
        ["Sun elevation", fmt(r.elevation_deg)],
        ["Time set", r.time_set || "unreadable"],
        ["Hour asked / held", fmt(r.hour_asked, 2) + " / " +
          (r.hour_readback == null ? "unreadable" : fmt(r.hour_readback, 2)) +
          (r.hour_drift != null && Math.abs(r.hour_drift) > 0.02 ?
            "  DRIFT " + fmt(r.hour_drift, 2) + " h" : "")],
        ["Location", (r.city || "(none set)") + "  lat " + (r.latitude == null ? "?" : fmt(r.latitude, 3)) +
          "  TZ " + (r.tz_offset == null ? "?" : r.tz_offset)]
      ];
      var html = rows.map(function (row) {
        return '<div class="row"><span class="k">' + row[0] + '</span><span class="v">' + row[1] + "</span></div>";
      }).join("");
      if (r.elevation_deg != null && r.elevation_deg <= 0) {
        html += '<div class="flag">THE SUN IS BELOW THE HORIZON (' + fmt(r.elevation_deg) +
          '). It is night in this model and the render will be BLACK however the ' +
          'sun is aimed. Elevation comes from the DATE, LATITUDE and TIME ZONE ' +
          'shown above \u2014 none of which this tool writes; it keeps the date the ' +
          'model already has. Fix those in Model Info \u203a Geo-location, or the ' +
          'date in Window \u203a Shadows, then press the button again.</div>';
      }
      if (!r.calibration_confident) {
        html += '<div class="flag">LOW CONFIDENCE calibration — NorthAngle did not move the ' +
          'sun by the expected amount when tested (slack ' + fmt(r.calibration_slack, 2) +
          '). The azimuth above may be off. Check the shadow by eye before rendering.</div>';
      }
      if (r.time_stuck) {
        html += '<div class="flag">Time of day would not write: ' + r.time_stuck + '</div>';
      }
      $out.innerHTML = html;
    }
  };
}());
</script></body></html>
    HTML
  end
end

begin
  WR_SunAim.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Light It From Here failed:\n\n#{e.class}: #{e.message}\n\nSee the Ruby Console.")
end
