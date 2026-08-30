# @title Look-development matrix (dev)...
# @shelf dev
# @cat V-Ray renders
# @rank 9
#
# lookdev-matrix.rb — render a MATRIX OF SMALL THUMBNAILS so a look can be
# art-directed at seconds per guess instead of minutes.
#
# WHY THIS EXISTS
# ---------------
# Pass 2 tuned the renders blind: every guess cost a six-minute render at
# 1200x900, so nobody could compare two options side by side and the look was
# never actually directed, only survived. MEASURED 30 Aug 2026 on this machine,
# this model, at Benton's own Medium quality:
#
#     1600x900   53.07 s
#      400x225    5.07 s
#
# Ten times faster, and 400x225 is the SAME 16:9 shape as his output, so a
# thumbnail crops identically to the frame it stands for. Twenty-plus options
# for less than the cost of one full render.
#
# WHAT IT DOES NOT DO
# -------------------
# It does not choose. It renders every arm of a sweep, names the file after its
# variables, records what actually landed, and puts the model back exactly as
# it found it. The picking is Benton's.
#
# HOW IT IS DRIVEN
# ----------------
# Data-driven, from a JSON spec written by scripts/lookdev-drive.py. Ruby holds
# no matrix of its own — it applies one frame's settings, renders it, and
# appends one JSON line of what it MEASURED (never what it asked for) to
# _frames.jsonl. Composing the matrix, running image-qa and assembling the
# results file is the Python side's job.
#
# THE SNAPSHOT IS THE SAFETY. capture! records every parameter this file is
# capable of touching BEFORE the first frame, and writes it to disk as well as
# holding it in memory: if a bridge job dies mid-sweep, restore! still has
# something to put back. Nothing here writes outside VRay and shadow_info, and
# every restore is read back and reported.
module WR_LookDev

  OUT_DIR   = 'C:/Users/bento/Desktop/BridgeTest-lookdev'.freeze
  SNAP_FILE = File.join(OUT_DIR, '_snapshot.json').freeze
  JSONL     = File.join(OUT_DIR, '_frames.jsonl').freeze

  # A SECOND SWEEP NEEDS A SECOND FOLDER, not a second copy of this file.
  # out_dir= is how the sun-off sweep (scripts/sunoff-drive.py) reuses this
  # harness without forking it; unset, everything below behaves exactly as it
  # did for the look-development matrix.
  def self.out_dir;      @out_dir || OUT_DIR;                     end
  def self.snap_file;    File.join(out_dir, '_snapshot.json');    end
  def self.jsonl;        File.join(out_dir, '_frames.jsonl');     end
  def self.out_dir=(d)
    require 'fileutils'
    FileUtils.mkdir_p(d)
    @out_dir = d
  end

  # The light rig, grouped. OBSERVED 30 Aug 2026 by walking the model: every
  # Rectangle Light sits at z = 96 in (the room ceiling) EXCEPT #14 at
  # z = 78.3 in, which is inside the booth. /Standard Light has no instance the
  # walk could find and carries intensity 2500 — far the largest number in the
  # rig — so it gets its OWN group rather than being folded into a guess about
  # which space it lights.
  ROOM_LIGHTS = ['/Rectangle Light#8',  '/Rectangle Light#9',
                 '/Rectangle Light#10', '/Rectangle Light#11',
                 '/Rectangle Light#12', '/Rectangle Light#13',
                 '/Rectangle Light#15'].freeze
  BOOTH_LIGHTS    = ['/Rectangle Light#14'].freeze
  STANDARD_LIGHTS = ['/Standard Light'].freeze
  ALL_LIGHTS      = (ROOM_LIGHTS + BOOTH_LIGHTS + STANDARD_LIGHTS).freeze

  # How long a render is allowed to take to REPORT ITSELF STARTED before the
  # frame is failed as never-started. render_production returns as soon as the
  # export is queued, so this is generous by design.
  START_WINDOW_S = 20.0

  # The four /SettingsEnvironment slots that scale what the environment
  # contributes: background, global illumination, reflections, refractions.
  # All four move together -- scaling GI but leaving the background at full
  # would give a room lit as if there were no sky, photographed against one.
  ENV_TEX_MULTS = [:bg_tex_mult, :gi_tex_mult,
                   :reflect_tex_mult, :refract_tex_mult].freeze

  EV_F_NUMBER = 8.0
  EV_ISO      = 100.0

  def self.ctx;   VRay::Context.active;     end
  def self.scene; c = ctx; c && c.scene;    end
  def self.rend;  c = ctx; c && c.renderer; end

  # ------------------------------------------------------------- helpers --

  def self.shutter_for_ev(ev, f = EV_F_NUMBER)
    2.0**((ev * 1.0) - (Math.log(f * f) / Math.log(2.0)))
  end

  def self.ev_of(f, sp)
    return nil unless f.is_a?(Numeric) && sp.is_a?(Numeric)
    return nil unless f > 0 && sp > 0
    Math.log((f * 1.0) * (f * 1.0) * (sp * 1.0)) / Math.log(2.0)
  end

  # Solar elevation and azimuth in degrees, from SketchUp's own sun vector —
  # the thing V-Ray's SunLight is driven by. Reported for every frame so that
  # "low sun" is a MEASURED angle rather than a time of day anyone has to
  # take on trust.
  def self.sun_angles
    d = Sketchup.active_model.shadow_info['SunDirection']
    return [nil, nil] if d.nil?
    [Math.asin(d.z / d.length) * 180.0 / Math::PI,
     Math.atan2(d.x, d.y) * 180.0 / Math::PI]
  rescue Exception
    [nil, nil]
  end

  def self.r2(x)
    return nil unless x.is_a?(Numeric)
    (x * 100.0).round / 100.0
  end

  # ------------------------------------------------------------ snapshot --

  # Every [plugin, key] this file is capable of writing. Snapshotting the WHOLE
  # list, not just the keys a given frame touches, is deliberate: a sweep
  # changes different parameters on different frames, and a partial snapshot
  # restores a blend of two arms rather than the model as it was found.
  def self.snap_pairs
    p = [['/SettingsOutput', :img_width], ['/SettingsOutput', :img_height],
         ['/SettingsOutput', :show_safe_frames],
         ['/SettingsImageSampler', :progressive_maxTime],
         ['/SettingsImageSampler', :progressive_threshold],
         ['/SettingsImageSampler', :progressive_maxSubdivs],
         ['/SunLight', :enabled], ['/SunLight', :intensity_multiplier],
         ['/Environment Sky', :intensity_multiplier],
         # THE KNOB THAT ACTUALLY CONTROLS THE SKY LIGHT. See ENV_TEX_MULTS.
         ['/SettingsEnvironment', :bg_tex_mult],
         ['/SettingsEnvironment', :gi_tex_mult],
         ['/SettingsEnvironment', :reflect_tex_mult],
         ['/SettingsEnvironment', :refract_tex_mult],
         ['/CameraPhysical', :f_number], ['/CameraPhysical', :ISO],
         ['/CameraPhysical', :shutter_speed]]
    ALL_LIGHTS.each { |l| p << [l, :enabled]; p << [l, :intensity] }
    p
  end

  # Keys that are SNAPSHOTTED FOR THE RECORD BUT NEVER WRITTEN BACK, because
  # writing them wedges SketchUp (see safe_frames!). Restoring a value that is
  # already correct is not worth a hung application, and this sweep never
  # changes it in the first place.
  NEVER_WRITE = ['/SettingsOutput|show_safe_frames'].freeze

  # EVERY shadow_info key the sun sweep can move.
  #
  # WR_SunAim.light_it_from_here does not just set a time: solve_elevation
  # bisects on LATITUDE with Longitude, TZOffset and ShadowTime all pinned to
  # an equinox epoch, and solve_north_angle then moves NorthAngle. Snapshotting
  # ShadowTime alone would restore the clock and leave the model sitting at
  # some solved latitude on the prime meridian -- a model quietly relocated by
  # a lighting sweep. All five go in the snapshot, and all five come back.
  SHADOW_KEYS = %w[ShadowTime NorthAngle Latitude Longitude TZOffset City].freeze

  # A SECOND capture! IS REFUSED, AND THAT IS THE WHOLE POINT.
  #
  # OBSERVED 30 Aug 2026, and it produced the worst kind of failure: a restore
  # that reported "restored clean" and put back the wrong model. capture! was
  # re-run part-way through the sweep, at a moment when the render size was
  # 400x225, the sampler carried the harness's 15 s budget and shadow_info sat
  # at some solved latitude on the prime meridian. Those swept values became
  # the "original", restore! faithfully restored them, checked them against
  # themselves, found no discrepancy and said so.
  #
  # A snapshot is only a snapshot if it is taken once, before anything moves.
  # Re-taking one is almost always a mistake, so it now has to be spelled out:
  # capture!(:force => true), which is loud enough to be noticed in a review.
  def self.capture!(opts = {})
    require 'fileutils'
    FileUtils.mkdir_p(out_dir)
    if @snap && !opts[:force]
      raise 'REFUSED: a snapshot already exists for this session. Re-capturing ' \
            'over a swept model is how a restore silently puts back the wrong ' \
            'values. Run restore! first, or capture!(:force => true) if you ' \
            'genuinely mean to redefine "original".'
    end
    sc = scene
    raise 'no V-Ray scene' if sc.nil?
    @snap = {}
    snap_pairs.each do |pl, k|
      o = (sc[pl] rescue nil)
      @snap["#{pl}|#{k}"] = o.nil? ? nil : (o[k] rescue nil)
    end
    si = Sketchup.active_model.shadow_info
    SHADOW_KEYS.each { |k| @snap["shadow|#{k}"] = (si[k].to_s rescue nil) }
    # TAG VISIBILITY, all of it.
    #
    # This is in the snapshot because of what it turned out to be hiding.
    # OBSERVED 30 Aug 2026: the tag "WR Lights" was VISIBLE=false, so all eight
    # rectangle lights were excluded from the model export and NOT ONE of them
    # reached any render. A full sweep of the room-to-booth balance -- from the
    # rig as found down to every light disabled -- produced images identical to
    # four decimal places, because every one of those renders was lit by the
    # V-Ray sun and sky alone. Any sweep that turns the tag on has to be able
    # to turn it back off.
    Sketchup.active_model.layers.each do |ly|
      @snap["tag|#{ly.name}"] = (ly.visible? ? 1 : 0)
    end
    # THE ROOM AS FOUND. Hidden-ness of every wall group, and whether the
    # sweep's own ceiling was already in the model (it should never be), so
    # restore! can put back a room rather than a room-shaped guess.
    begin
      walls_group.entities.grep(Sketchup::Group).each_with_index do |e, i|
        @snap["wall|#{i}|#{e.name}"] = (e.hidden? ? 1 : 0)
      end
    rescue Exception => e
      @snap['wall|ERROR'] = "#{e.class}: #{e.message}"
    end
    @snap['ceiling_group_preexisting'] = ceiling_group.nil? ? 0 : 1
    @snap['shadow_time'] = (si['ShadowTime'].to_s rescue nil)
    File.open(snap_file, 'w') { |f| f.write(pretty(@snap)) }
    @snap
  end

  def self.snapshot; @snap; end

  # Put everything back and SAY whether it went back. Best effort on the
  # writes, but every failure and every value that did not read back is
  # returned by name — a restore that quietly half-worked is how a model gets
  # left in a state nobody can account for.
  def self.restore!
    sc = scene
    return 'no V-Ray scene' if sc.nil?
    snap = @snap
    return 'nothing to restore (capture! was never called in this session)' if snap.nil?
    problems = []
    sc.change do
      snap.each do |k, v|
        next if k == 'shadow_time' || v.nil? || NEVER_WRITE.include?(k)
        pl, key = k.split('|')
        o = (sc[pl] rescue nil)
        next if o.nil?
        begin
          o[key.to_sym] = v
        rescue Exception => e
          problems << "#{k}: write raised #{e.class}"
        end
      end
    end
    snap.each do |k, v|
      next if k == 'shadow_time' || v.nil? || NEVER_WRITE.include?(k)
      pl, key = k.split('|')
      o = (sc[pl] rescue nil)
      next if o.nil?
      got = (o[key.to_sym] rescue :ERR)
      ok = if v.is_a?(Numeric) && got.is_a?(Numeric)
             (got.to_f - v.to_f).abs <= (v.to_f.abs * 0.001 + 0.000001)
           else
             got == v
           end
      problems << "#{k} DID NOT RESTORE: wanted #{v.inspect}, read back #{got.inspect}" unless ok
    end
    Sketchup.active_model.layers.each do |ly|
      want = snap["tag|#{ly.name}"]
      next if want.nil?
      begin
        ly.visible = (want.to_i == 1)
      rescue Exception => e
        problems << "tag #{ly.name.inspect} visibility NOT restored (#{e.class})"
      end
    end
    Sketchup.active_model.layers.each do |ly|
      want = snap["tag|#{ly.name}"]
      next if want.nil?
      got = ly.visible? ? 1 : 0
      problems << "tag #{ly.name.inspect} DID NOT RESTORE: wanted #{want}, read #{got}" if got != want.to_i
    end

    require 'time'
    si = Sketchup.active_model.shadow_info
    SHADOW_KEYS.each do |k|
      v = snap["shadow|#{k}"]
      next if v.nil? || v.to_s.empty?
      begin
        si[k] = (k == 'ShadowTime') ? Time.parse(v) :
                (k == 'City' ? v : v.to_f)
      rescue Exception => e
        problems << "shadow_info[#{k}] NOT restored (#{e.class}: #{e.message})"
      end
    end
    SHADOW_KEYS.each do |k|
      want = snap["shadow|#{k}"]
      next if want.nil? || want.to_s.empty?
      got = (si[k].to_s rescue :ERR)
      next if got == want
      if k != 'ShadowTime' && k != 'City'
        next if ((got.to_f - want.to_f).abs <= 0.0001)
      end
      problems << "shadow_info[#{k}] DID NOT RESTORE: wanted #{want.inspect}, read back #{got.inspect}"
    end
    # THE ROOM. The sweep's ceiling comes OUT unless it was already there
    # (it never is), and every wall goes back to the hidden-ness it was found
    # with -- by index AND name, so a renamed or reordered wall is reported
    # rather than silently skipped.
    begin
      if snap['ceiling_group_preexisting'].to_i == 0
        n = remove_ceiling!
        problems << "ceiling group STILL PRESENT after remove_ceiling!" unless ceiling_group.nil?
        @ceiling_removed = n
        # AND THE MATERIAL. Erasing the group leaves the SketchUp material
        # behind -- OBSERVED 30 Aug 2026, the model came back with 37
        # materials where it was found with 36, and only an independent count
        # caught it. Removing the material is safe (it is this harness's own,
        # nothing else uses it); DELETING ITS V-RAY PLUGIN IS NOT, and is
        # deliberately not attempted -- see MATTE_SUPPORTED.
        mat = (Sketchup.active_model.materials[CEIL_MTL] rescue nil)
        unless mat.nil?
          begin
            m2 = Sketchup.active_model
            m2.start_operation('WR sweep material cleanup', true)
            m2.materials.remove(mat)
            m2.commit_operation
          rescue Exception => e
            problems << "sweep ceiling material NOT removed (#{e.class}: #{e.message})"
          end
          problems << "sweep ceiling material #{CEIL_MTL.inspect} STILL PRESENT" unless
            (Sketchup.active_model.materials[CEIL_MTL] rescue nil).nil?
        end
      end
      wg = walls_group
      groups = wg.entities.grep(Sketchup::Group)
      groups.each_with_index do |e, i|
        want = snap["wall|#{i}|#{e.name}"]
        if want.nil?
          problems << "wall #{i} #{e.name.inspect} was NOT in the snapshot"
          next
        end
        e.hidden = (want.to_i == 1)
      end
      groups.each_with_index do |e, i|
        want = snap["wall|#{i}|#{e.name}"]
        next if want.nil?
        got = e.hidden? ? 1 : 0
        problems << "wall #{i} #{e.name.inspect} DID NOT RESTORE: wanted hidden=#{want}, read #{got}" if got != want.to_i
      end
    rescue Exception => e
      problems << "room restore raised #{e.class}: #{e.message}"
    end

    written = snap.keys.reject { |k| k == 'shadow_time' || NEVER_WRITE.include?(k) }.length
    return "restored clean (#{written} keys put back)" if problems.empty?
    problems.join('; ')
  end

  # ------------------------------------------------- the host room itself --
  #
  # WHY THE ROOM IS A VARIABLE AND NOT A FIXTURE.
  #
  # OBSERVED 30 Aug 2026: the "Studio Room" group is a four-walled box that
  # stops at z = 96 in with NO CEILING and no ceiling tag. Every render this
  # project has judged was therefore lit in large part by sky light falling
  # straight down through an open roof -- free, directionless fill that no
  # real room has. Any verdict on the light rig taken against that room is a
  # verdict about a room that does not exist.
  #
  # "Just add a ceiling" is NOT automatically the fix, because a lot of
  # WhisperRoom drawings are deliberately 2- or 3-sided host rooms, with walls
  # left out so the camera can see in (Benton, 30 Aug 2026). So the enclosure
  # is swept, not assumed: walls 4 or 3, ceiling present or absent, and the
  # sky itself takeable to zero.
  #
  # THE WALL THAT COMES OUT is Wall 2 -- the east pair, x = 240..244. BOTH
  # saved cameras sit inside the room just west of it (exterior eye x = 232,
  # interior eye x = 196, OBSERVED from the page cameras), so it is the wall
  # the camera would be looking THROUGH in a 3-sided drawing. It is behind
  # both cameras, so removing it changes the light in frame without changing
  # what is composed.
  CEIL_GROUP  = 'WR Sweep Ceiling'.freeze
  CEIL_MTL    = 'WR Sweep Ceiling'.freeze
  ROOM_Z      = 96.0
  ROOM_MIN    = [-4.0, -4.0].freeze
  ROOM_MAX    = [244.0, 196.0].freeze
  OPEN_WALLS  = ['Wall 2', 'Wall 2 (upper)'].freeze

  # A CAMERA-INVISIBLE CEILING IS NOT AVAILABLE ON THIS BUILD, and this is
  # where the evidence lives so nobody spends the afternoon again.
  #
  # The V-Ray CORE mechanism exists and was found: MtlRenderStats carries
  # camera_visibility / gi_visibility / reflections_visibility /
  # refractions_visibility / shadows_visibility, and every V-Ray material in
  # this scene carries an empty "renderStats" USERDATA slot that names one.
  # Setting camera_visibility = 0 on a ceiling's material is exactly the
  # architectural matte trick.
  #
  # It cannot be driven. OBSERVED FOUR TIMES, 30 Aug 2026, each costing a
  # SketchUp force-kill and restart:
  #
  #   sc.change { sc.delete('/<a material bound to live geometry>') }   HANGS
  #   sc.change { rs = sc.create(:MtlRenderStats,n); rs[:camera_visibility]=0 } HANGS
  #   sc.create(:MtlRenderStats,n) outside a change, then rs[:...] = 0  HANGS
  #   sc.change { rs = sc.create(...); rs[:base_mtl] = '/Aluminum'; ... } HANGS
  #
  # The create ALONE returns (1.7 s), and writing a parameter on an ALREADY
  # EXISTING, already-bound material plugin returns (0.02 s). It is writing a
  # parameter on a NEWLY CREATED material-category plugin that never comes
  # back: Ruby stops answering the bridge, no modal is on screen (the window
  # list was enumerated, there is none), and SketchUp must be killed.
  #
  # Nor is it in the product UI: V-Ray for SketchUp's localisation strings
  # carry "V-Ray Object Visibility: Enabled / Disabled" and nothing about
  # matte, camera visibility or render stats, and VRay::ObjectProperties
  # exposes only get/set_object_visibility -- a BINARY toggle that removes the
  # object from the render entirely, which is the same as not having a ceiling.
  #
  # So this harness REFUSES to render a "matte" ceiling rather than fake one.
  # The supported stand-in it offers instead is 'sky_multiplier' => 0.0: the
  # free sky light is removed at the environment rather than blocked by
  # geometry. That is honest about what it does and what it does not -- it
  # kills the skylight but provides NO bounce surface, whereas a real ceiling
  # both blocks and bounces. The two arms bracket the matte ceiling: a matte
  # ceiling would be the 'ceiling' arm's light with the 'open' arm's picture.
  MATTE_SUPPORTED = false

  def self.walls_group
    m  = Sketchup.active_model
    sr = m.entities.grep(Sketchup::Group).find { |g| g.name == 'Studio Room' }
    raise 'no group named "Studio Room" -- the room axis cannot be swept' if sr.nil?
    w = sr.entities.grep(Sketchup::Group).find { |g| g.name == 'Walls' }
    raise 'no "Walls" group inside "Studio Room"' if w.nil?
    w
  end

  def self.ceiling_group
    Sketchup.active_model.entities.grep(Sketchup::Group).find { |g| g.name == CEIL_GROUP }
  end

  # Built ONCE and then hidden or shown per frame, rather than created and
  # erased per frame: less model churn, and hiding is exactly right here
  # because a hidden group is genuinely absent from the export, which is what
  # "no ceiling" means.
  def self.ensure_ceiling!
    g = ceiling_group
    return g unless g.nil?
    m = Sketchup.active_model
    m.start_operation('WR sweep ceiling', true)
    mat = m.materials[CEIL_MTL] || m.materials.add(CEIL_MTL)
    mat.color = Sketchup::Color.new(228, 228, 224)
    g = m.entities.add_group
    g.name = CEIL_GROUP
    f = g.entities.add_face([[ROOM_MIN[0], ROOM_MIN[1], ROOM_Z],
                             [ROOM_MAX[0], ROOM_MIN[1], ROOM_Z],
                             [ROOM_MAX[0], ROOM_MAX[1], ROOM_Z],
                             [ROOM_MIN[0], ROOM_MAX[1], ROOM_Z]])
    f.reverse! if f.normal.z > 0     # the lit face points DOWN into the room
    f.material = mat
    f.back_material = mat
    m.commit_operation
    g
  end

  def self.remove_ceiling!
    m  = Sketchup.active_model
    gs = m.entities.grep(Sketchup::Group).select { |g| g.name == CEIL_GROUP }
    return 0 if gs.empty?
    m.start_operation('WR sweep ceiling remove', true)
    n = gs.length
    gs.each(&:erase!)
    m.commit_operation
    n
  end

  # Apply one room arm and REPORT WHAT THE MODEL NOW HOLDS, read back rather
  # than echoed, so the record says what was rendered.
  def self.room!(spec)
    return nil if spec.nil?
    ceil  = (spec['ceiling'] || 'none').to_s
    walls = (spec['walls'] || 4).to_i
    if ceil == 'matte' && !MATTE_SUPPORTED
      raise 'REFUSED: a camera-invisible ("matte") ceiling is not available ' \
            'in V-Ray for SketchUp on this build -- see MATTE_SUPPORTED for ' \
            'the four hangs that established it. Use ceiling "none" with ' \
            'sky_multiplier 0.0 for the supported stand-in.'
    end
    g = (ceil == 'none') ? ceiling_group : ensure_ceiling!
    m = Sketchup.active_model
    m.start_operation('WR sweep room', true)
    g.hidden = (ceil == 'none') unless g.nil?
    wg = walls_group
    wg.entities.grep(Sketchup::Group).each do |e|
      next unless OPEN_WALLS.include?(e.name)
      e.hidden = (walls < 4)
    end
    m.commit_operation
    room_measured(ceil, walls)
  end

  def self.room_measured(asked_ceiling = nil, asked_walls = nil)
    g  = ceiling_group
    wg = (walls_group rescue nil)
    present = wg.nil? ? [] :
      wg.entities.grep(Sketchup::Group).reject { |e| e.hidden? }.map { |e| e.name }
    { 'ceiling_asked'    => asked_ceiling,
      'walls_asked'      => asked_walls,
      'ceiling_in_model' => !g.nil?,
      'ceiling_hidden'   => (g.nil? ? nil : g.hidden?),
      'ceiling_renders'  => (!g.nil? && !g.hidden?),
      'wall_groups_visible' => present.length,
      'walls_visible'    => present.uniq.sort.join(','),
      'open_wall_hidden' => (wg.nil? ? nil :
        wg.entities.grep(Sketchup::Group).any? { |e| OPEN_WALLS.include?(e.name) && e.hidden? }) }
  end

  # ---------------------------------------------- THE ASSERTION THAT COUNTS --
  #
  # The single most expensive mistake this project has made was rendering a
  # whole stage of a light sweep with the tag that carries every light HIDDEN.
  # Sixty-eight frames were rendered before anyone noticed that not one of
  # them contained artificial light. A hidden tag is not exported, so the
  # intensities being swept were numbers in a settings file that no render
  # ever saw, and the arms came back identical to four decimal places.
  #
  # So this does not warn and it does not fix up quietly. It RAISES, before
  # render_production is called, and the frame is failed by name. A frame that
  # cannot contain the lights it is a study of is a wasted frame, and the
  # harness's job is to refuse to produce one.
  LIGHT_TAG = 'WR Lights'.freeze

  def self.assert_lights_visible!
    m  = Sketchup.active_model
    ly = m.layers[LIGHT_TAG]
    raise "REFUSED TO RENDER: this model has no tag named #{LIGHT_TAG.inspect}" if ly.nil?
    unless ly.visible?
      raise "REFUSED TO RENDER: the tag #{LIGHT_TAG.inspect} is HIDDEN. A light " \
            'on a hidden tag is excluded from the V-Ray export, so this frame ' \
            'would contain NO artificial light at all -- exactly the failure ' \
            'that wasted 68 frames on 30 Aug 2026.'
    end
    on = m.entities.grep(Sketchup::ComponentInstance)
          .select { |e| e.layer && e.layer.name == LIGHT_TAG && e.visible? }
    if on.length < 8
      raise "REFUSED TO RENDER: tag #{LIGHT_TAG.inspect} is visible but only " \
            "#{on.length} light instances are visible in the model (expected 8). " \
            'Something else is hiding the rig.'
    end
    on.length
  end

  # --------------------------------------------------------------- apply --

  # One frame's settings. Everything in `set` is optional, and anything absent
  # is LEFT AS IT IS rather than defaulted — that is how a later stage carries
  # an earlier stage's winner: by simply not mentioning it.
  def self.apply!(set)
    sc = scene
    m  = Sketchup.active_model

    if set['shadow_time']
      require 'time'
      m.shadow_info['ShadowTime'] = Time.parse(set['shadow_time'])
    end

    # THE SUN GOES THROUGH "LIGHT IT FROM HERE", NOT THROUGH A CLOCK.
    #
    # scripts/wr-sun-aim.rb already owns this problem and owns it better than
    # a time-of-day sweep could: it solves for an ELEVATION directly, keeps the
    # deliberate azimuth offset that stops every visible face being lit
    # square-on, measures what it actually achieved instead of trusting the
    # arithmetic, and writes shadow_info and nothing else. Setting a date and
    # hour here instead would have been a worse version of a tool that is
    # already in the repo.
    #
    # It runs OUTSIDE any VRay::Scene#change -- it opens its own SketchUp
    # start_operation, and nesting that inside a V-Ray transaction is not a
    # combination anything here has any reason to trust.
    #
    # match_cam TRUE is the tool's current default and reproduces what the
    # renders do today: on a level camera, camera_elevation is ~0, which
    # clamp_elev lifts to ELEV_MIN = 8 degrees -- the hard raking sun. That is
    # a usage mode, not a defect, and passing match_cam FALSE with an explicit
    # elev_deg is exactly the control this sweep needs.
    # Tag visibility, before anything else -- a light on a hidden tag is not
    # exported, so no amount of intensity writing can make it matter.
    if set['tags']
      set['tags'].each do |name, vis|
        ly = (m.layers[name] rescue nil)
        next if ly.nil?
        ly.visible = (vis ? true : false)
      end
    end

    # THE ROOM ITSELF, before the sun and before the lights: it is geometry,
    # and geometry is what the other two are measured against.
    @room = set['room'] ? room!(set['room']) : room_measured
    @lights_visible = nil

    @sun_aim = nil
    if set['sun_aim']
      sa = set['sun_aim']
      @sun_aim = WR_SunAim.light_it_from_here(
        m, m.active_view,
        sa['offset_deg'] || WR_SunAim::DEFAULT_OFFSET_DEG,
        sa['match_cam'] ? true : false,
        sa['elev_deg'])
    end

    sc.change do
      sun = (sc['/SunLight'] rescue nil)
      if sun
        sun[:enabled] = (set['sun_enabled'] ? true : false) unless set['sun_enabled'].nil?
        sun[:intensity_multiplier] = set['sun_multiplier'].to_f if set['sun_multiplier']
      end
      sky = (sc['/Environment Sky'] rescue nil)
      sky[:intensity_multiplier] = set['sky_multiplier'].to_f if sky && set['sky_multiplier']

      # THE SKY'S BRIGHTNESS IS NOT /Environment Sky[intensity_multiplier].
      #
      # OBSERVED 30 Aug 2026, and it cost twenty frames: writing
      # /Environment Sky[:intensity_multiplier] = 0.0 READS BACK 0.0 and
      # changes the render NOT AT ALL. Twenty "no sky" frames came back
      # identical to their sky-on twins to four decimal places -- the same
      # species of null experiment as the hidden light tag, and caught the
      # same way, by noticing two arms that could not legitimately match.
      #
      # /Environment Sky is a TexSky whose intensity_multiplier is only in
      # play for the sun-driven sky model; the environment's contribution to
      # the render is scaled by /SettingsEnvironment's PER-SLOT multipliers.
      # Setting all four to 0 measured mean luminance 0.2741 against 0.4557
      # with them at 1 -- same frame, same rig, sun off. That is the knob.
      se = (sc['/SettingsEnvironment'] rescue nil)
      if se && set['env_mult']
        m = set['env_mult'].to_f
        ENV_TEX_MULTS.each { |k| se[k] = m }
      end

      # Light groups carry a MULTIPLIER on the intensity the rig was FOUND at,
      # so a sweep arm is a ratio against Benton's own rig rather than against
      # numbers invented here. 0 switches the group off outright.
      { 'room' => ROOM_LIGHTS, 'booth' => BOOTH_LIGHTS,
        'standard' => STANDARD_LIGHTS }.each do |grp, list|
        mult = set['lights'] && set['lights'][grp]
        next if mult.nil?
        list.each do |ln|
          o = (sc[ln] rescue nil)
          next if o.nil?
          base = @snap && @snap["#{ln}|intensity"]
          base = (base || (o[:intensity] rescue 0.0)).to_f
          if mult.to_f <= 0.0
            o[:enabled] = false
          else
            o[:enabled]   = true
            o[:intensity] = base * mult.to_f
          end
        end
      end

      if set['ev']
        cp = (sc['/CameraPhysical'] rescue nil)
        if cp
          cp[:f_number]      = EV_F_NUMBER
          cp[:ISO]           = EV_ISO
          cp[:shutter_speed] = shutter_for_ev(set['ev'].to_f)
        end
      end
    end

    # SIZE AND TIME BUDGET LAST, IN THEIR OWN scene.change, AND READ BACK.
    #
    # OBSERVED 30 Aug 2026, and it cost an hour: writing img_width/img_height
    # in the SAME scene.change as show_safe_frames silently loses the size.
    # Turning safe frames on wakes V-Ray's own aspect/resolution manager,
    # which re-syncs the resolution from the Asset Editor and overwrites the
    # numbers written a moment earlier in the same transaction. The first
    # sweep asked for 400x225, the VFB rendered 1600x900, and nothing said so.
    #
    # So: safe frames is NOT a per-frame setting (see safe_frames!), and the
    # size is written on its own and VERIFIED. A frame that cannot be made to
    # render at the size it was asked for RAISES -- a thumbnail sweep whose
    # thumbnails are secretly full-size is worse than no sweep at all.
    size_budget!(set)
    true
  end

  # The one guard that turns an hour of wasted rendering into an immediate,
  # named failure.
  def self.size_budget!(set)
    sc = scene
    w = set['w'] && set['w'].to_i
    h = set['h'] && set['h'].to_i
    budget = set['max_minutes']
    return true if w.nil? && h.nil? && budget.nil?
    sc.change do
      so = (sc['/SettingsOutput'] rescue nil)
      if so
        so[:img_width]  = w if w
        so[:img_height] = h if h
      end
      # A THUMBNAIL SWEEP NEEDS A TIME BUDGET. Benton's own quality leaves
      # progressive_maxTime at 0.0, which means NO LIMIT: the render stops
      # only when every bucket reaches progressive_maxSubdivs. That is right
      # for a final frame and fatal for a sweep -- the first arm of stage 1
      # ran past fifteen minutes before this budget existed. The budget is
      # the harness's, it is logged per frame, and capture!/restore! puts
      # Benton's 0.0 back.
      smp = (sc['/SettingsImageSampler'] rescue nil)
      smp[:progressive_maxTime] = budget.to_f if smp && budget
    end
    return true if w.nil? && h.nil?
    so = (sc['/SettingsOutput'] rescue nil)
    gw = (so && (so[:img_width]  rescue nil)).to_i
    gh = (so && (so[:img_height] rescue nil)).to_i
    if (w && gw != w) || (h && gh != h)
      raise "RENDER SIZE DID NOT STICK: asked for #{w}x#{h}, V-Ray reads " \
            "#{gw}x#{gh}. Refusing to render -- a sweep at the wrong size " \
            'is a sweep that answers a different question.'
    end
    true
  end

  # SAFE FRAME CANNOT BE SET FROM THIS API. DO NOT TRY.
  #
  # OBSERVED TWICE, 30 Aug 2026, and it cost two SketchUp restarts:
  #
  #   sc.change { sc['/SettingsOutput'][:show_safe_frames] = 1 }
  #
  # never returns. Ruby wedges inside the write, the bridge times out at its
  # ceiling, no modal dialog is on screen, the SketchUp main window still
  # reports enabled, and the only way out is to kill the process. The likely
  # mechanism is that toggling safe frames makes V-Ray rebuild its viewport
  # widgets (VRay::Command.rebuild_viewport_widgets exists) and that rebuild
  # cannot complete while it is being driven from inside a scene transaction
  # on the same thread.
  #
  # It is READ freely -- measured is welcome to report it -- but it is never
  # written. Benton wants Safe Frame on; that is a click in the V-Ray UI, and
  # the handoff says where. A tool that wedges SketchUp is not an improvement
  # over a checkbox.
  def self.safe_frames!(_on)
    raise 'REFUSED: writing /SettingsOutput[show_safe_frames] wedges SketchUp '           'on this build (observed twice, 30 Aug 2026). Set Safe Frame in the '           'V-Ray UI instead - see .forge/builder/HANDOFF-lookdev.md.'
  end

  # --------------------------------------------------------------- render --

  # What ACTUALLY landed, read back out of the scene after apply! — this is
  # what goes into the record, never the spec's asking price.
  def self.measured
    sc = scene
    el, az = sun_angles
    cp = (sc['/CameraPhysical'] rescue nil)
    so = (sc['/SettingsOutput'] rescue nil)
    out = {
      'img_width'    => (so && (so[:img_width]  rescue nil)),
      'img_height'   => (so && (so[:img_height] rescue nil)),
      'safe_frames'  => (so && (so[:show_safe_frames] rescue nil)),
      'sun_enabled'  => (sc['/SunLight'][:enabled] rescue nil),
      'sun_mult'     => (sc['/SunLight'][:intensity_multiplier] rescue nil),
      'sky_mult'     => (sc['/Environment Sky'][:intensity_multiplier] rescue nil),
      # WHAT THE ENVIRONMENT ACTUALLY CONTRIBUTES. sky_mult above is recorded
      # for the record and is NOT the control -- see apply!.
      'env_bg_tex_mult'      => (sc['/SettingsEnvironment'][:bg_tex_mult] rescue nil),
      'env_gi_tex_mult'      => (sc['/SettingsEnvironment'][:gi_tex_mult] rescue nil),
      'env_reflect_tex_mult' => (sc['/SettingsEnvironment'][:reflect_tex_mult] rescue nil),
      'env_refract_tex_mult' => (sc['/SettingsEnvironment'][:refract_tex_mult] rescue nil),
      'sun_elev_deg' => r2(el),
      'sun_aim'      => sun_aim_record,
      'sun_azi_deg'  => r2(az),
      'shadow_time'  => Sketchup.active_model.shadow_info['ShadowTime'].to_s,
      'progressive_maxTime'    => (sc['/SettingsImageSampler'][:progressive_maxTime] rescue nil),
      'progressive_threshold'  => (sc['/SettingsImageSampler'][:progressive_threshold] rescue nil),
      'progressive_maxSubdivs' => (sc['/SettingsImageSampler'][:progressive_maxSubdivs] rescue nil),
      'f_number'     => (cp && (cp[:f_number] rescue nil)),
      'ISO'          => (cp && (cp[:ISO] rescue nil)),
      'shutter'      => (cp && (cp[:shutter_speed] rescue nil))
    }
    out['ev'] = r2(ev_of(out['f_number'], out['shutter']))
    lights = {}
    ALL_LIGHTS.each do |ln|
      o = (sc[ln] rescue nil)
      next if o.nil?
      lights[ln] = { 'enabled'   => (o[:enabled]   rescue nil),
                     'intensity' => (o[:intensity] rescue nil) }
    end
    out['lights'] = lights
    # THE FIELD THAT EXPLAINS THE RIG. A light on a hidden tag is not exported,
    # so if this reads false the intensities above are numbers in a settings
    # file that no render ever saw.
    out['tag_wr_lights_visible'] =
      (Sketchup.active_model.layers['WR Lights'].visible? rescue nil)
    # NOT the tag alone. The tag being visible is necessary and not sufficient
    # -- an instance can be hidden in its own right -- so the number of light
    # instances that would actually export is counted and recorded per frame.
    out['visible_light_instances'] = @lights_visible
    out['room'] = (@room || room_measured)
    out['room_total_intensity']  = r2(ROOM_LIGHTS.inject(0.0)  { |a, l| a + li(sc, l) })
    out['booth_total_intensity'] = r2(BOOTH_LIGHTS.inject(0.0) { |a, l| a + li(sc, l) })
    out['standard_total_intensity'] = r2(STANDARD_LIGHTS.inject(0.0) { |a, l| a + li(sc, l) })
    bt = out['booth_total_intensity']
    out['room_over_booth'] = (bt && bt > 0) ? r2(out['room_total_intensity'] / bt) : nil
    out
  end

  # What the sun solver was ASKED for and what it ACHIEVED, side by side.
  # solve_elevation bisects against a pinned epoch and clamp_elev floors the
  # request at ELEV_MIN (8) and ceilings it at ELEV_MAX (85), so the two can
  # legitimately differ -- and a sweep that only recorded the request would be
  # quietly reporting a sun that is not the one in the picture.
  def self.sun_aim_record
    r = @sun_aim
    return nil if r.nil?
    { 'ok'                => r[:ok],
      'reason'            => r[:reason],
      'matched_camera'    => r[:matched_camera],
      'elev_requested'    => r2(r[:wanted_elevation]),
      'elev_achieved'     => r2(r[:elevation_deg]),
      'elev_error'        => r2(r[:elevation_error]),
      'offset_deg'        => r2(r[:offset]),
      'camera_azimuth'    => r2(r[:camera_azimuth]),
      'target_azimuth'    => r2(r[:target_azimuth]),
      'achieved_azimuth'  => r2(r[:achieved_azimuth]),
      'azimuth_error'     => r2(r[:error_deg]),
      'solved_latitude'   => r2(r[:solved_latitude]),
      'north_angle_after' => r2(r[:north_angle_after]),
      'calibration_confident' => r[:calibration_confident] }
  end

  # An intensity only counts toward a group total if the light is actually on.
  def self.li(sc, name)
    o = (sc[name] rescue nil)
    return 0.0 if o.nil?
    return 0.0 unless (o[:enabled] rescue false)
    (o[:intensity] rescue 0.0).to_f
  end

  # Point the viewport at a named page's camera. A render of the WRONG view is
  # worse than a missing one, so a page that is not there RAISES rather than
  # quietly rendering whatever the viewport happens to be holding.
  def self.aim!(page_name)
    m  = Sketchup.active_model
    pg = m.pages[page_name]
    raise "no page named #{page_name.inspect}" if pg.nil?
    raise "page #{page_name.inspect} saves no camera" if pg.camera.nil?
    m.active_view.camera = pg.camera
    pg.name
  end

  # WAIT FOR THE RENDER WITHOUT USING renderer.wait.
  #
  # HONEST PROVENANCE, because the first diagnosis here was WRONG. When the
  # first sweep wedged, `rend.wait` was blamed: Ruby was somewhere inside a
  # frame for twenty minutes while the VFB's own Render menu showed "Stop
  # rendering" and "Abort rendering" both greyed out, i.e. V-Ray thought the
  # render was over. Isolating it afterwards showed the real culprit was the
  # show_safe_frames write in the same apply! (see safe_frames!), which wedges
  # on its own with no render involved at all. `rend.wait` is NOT convicted.
  #
  # Polling is kept anyway, for two reasons that stand on their own: it is
  # what proposal-package.rb already does, and unlike `wait` it can impose a
  # ceiling. `wait` offers no timeout, so a frame that never completes takes
  # the whole sweep with it -- which is precisely the failure that cost this
  # pass two SketchUp restarts, whatever caused it.
  #
  # So: poll instead, on the renderer's OWN state, with a hard ceiling. A
  # frame that never reports finished is failed BY NAME and the sweep moves
  # on — one bad thumbnail costs one thumbnail, never the whole matrix.
  # Returns [seconds, why] where why is :ended, :timeout or :no_poll_surface.
  def self.await_render(timeout_s)
    t0 = Time.now
    unless rend.respond_to?(:state) || rend.respond_to?(:sequence_ended?)
      return [nil, :no_poll_surface]
    end

    # PHASE 1 -- WAIT UNTIL IT IS ACTUALLY RENDERING.
    #
    # This phase exists because leaving it out silently ruined a whole sweep.
    # After a frame completes the renderer sits at :idleDone with
    # sequence_ended? true, and those are exactly the values that mean
    # "finished". Poll for them straight after render_production and the very
    # first read matches -- so the wait returns in 0.0 s, save_vfb_image
    # dutifully writes out the PREVIOUS frame's pixels, and six arms of a sun
    # sweep come back as six identical files with six identical QA scores and
    # nothing anywhere saying a render never happened. OBSERVED 30 Aug 2026.
    #
    # So the completion test is not "is it idle" but "was it running, and is
    # it idle NOW". A frame that never starts is failed by name.
    seen_running = false
    until seen_running
      st = (rend.state rescue nil)
      seen_running = true if st.to_s =~ /render/i
      break if seen_running
      return [Time.now - t0, :never_started] if Time.now - t0 > START_WINDOW_S
      sleep(0.05)
    end

    # PHASE 2 -- wait for it to finish, with a hard ceiling.
    loop do
      st = (rend.state rescue nil)
      if st.to_s =~ /idle|done|stop/i
        return [Time.now - t0, :ended]
      end
      return [Time.now - t0, :timeout] if Time.now - t0 > timeout_s
      sleep(0.1)
    end
  end

  # Render one frame.
  def self.frame!(spec)
    t_apply = Time.now
    aim!(spec['camera'])
    apply!(spec['set'] || {})
    # THE REFUSAL, and it is deliberately BEFORE the timer and before the
    # render. spec['require_lights'] is set by every sun-off frame, because a
    # sun-off frame with no rig in it is not a dark picture of the booth -- it
    # is a picture of nothing, and it would be indistinguishable from a
    # correctly rendered failure. The frame is failed by name instead.
    @lights_visible = assert_lights_visible! if spec['require_lights']
    apply_s = Time.now - t_apply

    path = File.join(out_dir, spec['file'])
    File.delete(path) if File.exist?(path)

    t0 = Time.now
    VRay::Command.render_production(:context => ctx)
    render_s, why = await_render(spec['timeout_s'] || 180)
    render_s = Time.now - t0 if render_s.nil?

    saved = begin
      rend.save_vfb_image(path, :skip_alpha => true, :no_alpha => true)
    rescue Exception => e
      "RAISED:#{e.class}: #{e.message}"
    end
    total_s = Time.now - t0

    rec = { 'id' => spec['id'], 'stage' => spec['stage'],
            'vars' => spec['vars'], 'camera' => spec['camera'],
            'file' => spec['file'], 'path' => path,
            'saved' => saved,
            'bytes' => (File.exist?(path) ? File.size(path) : -1),
            'render_end'     => why.to_s,
            'apply_seconds'  => r2(apply_s),
            'render_seconds' => r2(render_s),
            'wall_seconds'   => r2(total_s),
            'measured' => measured }
    File.open(jsonl, 'a') { |f| f.puts(compact_json(rec)) }
    rec
  end

  # Run a list of frames in one call. Returns a SHORT summary — the detail is
  # in the JSONL, because a bridge job's return value is not the place for it.
  def self.run!(specs)
    ok = 0
    bad = []
    specs.each do |s|
      begin
        r = frame!(s)
        if r['saved'] == true && r['bytes'].to_i > 0
          ok += 1
        else
          bad << "#{s['id']}: saved=#{r['saved'].inspect} bytes=#{r['bytes']}"
        end
      rescue Exception => e
        bad << "#{s['id']}: RAISED #{e.class}: #{e.message}"
      end
    end
    { 'ok' => ok, 'failed' => bad }
  end

  # ----------------------------------------------------------------- json --
  #
  # Hand-rolled, and deliberately so: this only ever writes flat-ish hashes of
  # strings, numbers, booleans and nil, and depending on a JSON library being
  # present in SketchUp's Ruby is a dependency this does not need.

  def self.compact_json(o)
    case o
    when Hash    then '{' + o.map { |k, v| jstr(k.to_s) + ':' + compact_json(v) }.join(',') + '}'
    when Array   then '[' + o.map { |v| compact_json(v) }.join(',') + ']'
    when String  then jstr(o)
    when Symbol  then jstr(o.to_s)
    when Float   then (o.nan? || o.infinite?) ? 'null' : o.to_s
    when Numeric then o.to_s
    when TrueClass, FalseClass then o.to_s
    when NilClass then 'null'
    else jstr(o.to_s)
    end
  end

  BS = 92.chr.freeze     # a literal backslash, without a nest of escapes

  def self.jstr(s)
    out = s.to_s.gsub(BS, BS + BS).gsub('"', BS + '"')
    out = out.gsub("\n", BS + 'n').gsub("\r", BS + 'r').gsub("\t", BS + 't')
    '"' + out + '"'
  end

  def self.pretty(h)
    "{\n" + h.map { |k, v| '  ' + jstr(k.to_s) + ': ' + compact_json(v) }.join(",\n") + "\n}\n"
  end
end
