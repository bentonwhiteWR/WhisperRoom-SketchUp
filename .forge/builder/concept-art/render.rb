# Concept-art render driver: one V-Ray frame per call, started in one short
# bridge job and POLLED in later short jobs (the bridge cannot time a job out,
# so nothing here blocks for the length of a render).
#
#   load '.../render.rb'                                   (defines, runs nothing)
#   WR_ConceptRender.settings!(1024, 576, 1.5, 0.03)        (size, minutes, noise)
#   WR_ConceptRender.sun!(195.0, 14.0)                       (model-frame az / elevation)
#   WR_ConceptRender.start!('MDL 96120 E (components) 01-angled r')
#   WR_ConceptRender.poll                                    (repeat until :done)
#   WR_ConceptRender.save!('C:/.../frame.png')               (LINEAR buffer + .exr)
#
# Hazards this respects (reference/vray-ruby-api.md, HANDOFF-lookdev/sunoff):
#   * never renderer.in_process? / dr_enabled? (they raise here);
#   * finished = :idleDone AFTER the frame was seen running (latched in start!);
#   * the camera is set from page.camera directly with TransitionTime 0, so
#     the export cannot catch a camera mid-tween;
#   * /SettingsOutput size is written alone and READ BACK; show_safe_frames
#     is never written (it wedges SketchUp);
#   * save_vfb_image writes the LINEAR buffer: the PNG reads dark until it is
#     sRGB-encoded (done in post, finish.py), exactly as proposal-package.rb
#     documents under THE DARK RENDERS.
module WR_ConceptRender
  def self.ctx;   VRay::Context.active; end
  def self.scene; ctx.scene; end
  def self.rend;  ctx.renderer; end
  def self.model; Sketchup.active_model; end

  def self.settings!(w, h, minutes, threshold, denoise = true)
    sc = scene
    sc.change do
      so = sc['/SettingsOutput']
      so[:img_width]  = w.to_i
      so[:img_height] = h.to_i
    end
    sc.change do
      smp = sc['/SettingsImageSampler']
      smp[:progressive_maxTime]   = minutes.to_f
      smp[:progressive_threshold] = threshold.to_f
      dn = sc['/RenderChannelDenoiser']
      dn[:enabled] = denoise ? true : false if dn
    end
    so = sc['/SettingsOutput']
    got = [so[:img_width].to_i, so[:img_height].to_i]
    raise "RENDER SIZE DID NOT STICK: asked #{w}x#{h}, V-Ray reads #{got.join('x')}" if got != [w.to_i, h.to_i]
    smp = sc['/SettingsImageSampler']
    { 'size' => got, 'maxTime' => smp[:progressive_maxTime], 'threshold' => smp[:progressive_threshold],
      'denoiser' => (sc['/RenderChannelDenoiser'][:enabled] rescue nil) }
  end

  # Exposure through the physical camera: shutter for a given EV at f/8 ISO 100.
  def self.ev!(ev)
    sc = scene
    sc.change do
      cp = sc['/CameraPhysical']
      cp[:f_number] = 8.0
      cp[:ISO] = 100.0
      cp[:shutter_speed] = 2.0**(ev.to_f - Math.log2(64.0))
    end
    cp = sc['/CameraPhysical']
    Math.log2(cp[:f_number]**2 * cp[:shutter_speed])
  end

  # Put the sun at a model-frame azimuth (deg clockwise from +Y) and elevation
  # by solving ShadowTime for the elevation and NorthAngle for the azimuth,
  # then MEASURING SunDirection — the returned numbers are read back, not asked.
  def self.sun!(az_deg, el_deg, lat = 35.96, month = 10, day = 15)
    si = model.shadow_info
    si['Latitude'] = lat
    si['Longitude'] = -83.92
    si['TZOffset'] = -5.0
    si['NorthAngle'] = 0.0
    best = nil
    (12 * 60..19 * 60).step(2) do |mins|
      si['ShadowTime'] = Time.utc(2026, month, day, mins / 60, mins % 60, 0)
      d = si['SunDirection']
      el = Math.asin(d.z / d.length) * 180.0 / Math::PI
      next if el < 0
      best = [mins, el] if best.nil? || (el - el_deg).abs < (best[1] - el_deg).abs
    end
    si['ShadowTime'] = Time.utc(2026, month, day, best[0] / 60, best[0] % 60, 0)
    2.times do
      d = si['SunDirection']
      az = (Math.atan2(d.x, d.y) * 180.0 / Math::PI) % 360.0
      delta = ((az_deg - az + 540.0) % 360.0) - 180.0
      si['NorthAngle'] = (si['NorthAngle'].to_f - delta) % 360.0
      d2 = si['SunDirection']
      az2 = (Math.atan2(d2.x, d2.y) * 180.0 / Math::PI) % 360.0
      # the sign of NorthAngle against azimuth is not documented; if the
      # first move went the wrong way, the second pass undoes and reverses it
      if (((az_deg - az2 + 540.0) % 360.0) - 180.0).abs > delta.abs + 0.5
        si['NorthAngle'] = (si['NorthAngle'].to_f + 2 * delta) % 360.0
      end
    end
    si['DisplayShadows'] = true
    d = si['SunDirection']
    { 'az' => ((Math.atan2(d.x, d.y) * 180.0 / Math::PI) % 360.0).round(2),
      'el' => (Math.asin(d.z / d.length) * 180.0 / Math::PI).round(2),
      'time' => si['ShadowTime'].to_s, 'north' => si['NorthAngle'].to_f.round(2) }
  end

  def self.sun_intensity!(mult)
    sc = scene
    sc.change { sc['/SunLight'][:intensity_multiplier] = mult.to_f }
    sc['/SunLight'][:intensity_multiplier]
  end

  # Select the page (so its hidden walls / ceiling apply), then set the camera
  # from page.camera directly. Returns the eye for the record.
  def self.aim!(page_name)
    m = model
    pg = m.pages[page_name]
    raise "no page #{page_name.inspect}" if pg.nil?
    m.options['PageOptions']['TransitionTime'] = 0.0
    m.pages.selected_page = pg
    m.active_view.camera = pg.camera
    pg.camera.eye.to_a.map { |v| v.to_f.round(1) }
  end

  # The room pieces AUTO-SET hides per scene: every group inside Loft > Walls
  # (wall pieces, windows, slats, the ceiling).
  def self.room_pieces
    loft = model.entities.find { |e| e.is_a?(Sketchup::Group) && e.name == 'Loft' }
    return [] if loft.nil?
    walls = loft.entities.find { |c| c.is_a?(Sketchup::Group) && c.name == 'Walls' }
    walls ? walls.entities.grep(Sketchup::Group) : []
  end

  # A page's scene state WITHOUT selecting the page. Selecting it applies the
  # page's stored state on a LATER view update - its hidden walls, and its own
  # sun, which then overwrites the sun set for the render (observed 22 Sep
  # 2026: shadow_info back at the page's defaults after the job had set its
  # own). So: the page's own hidden_entities are applied to the room pieces
  # here, synchronously, and the camera comes straight from page.camera.
  def self.stage_page!(page_name)
    m = model
    pg = m.pages[page_name]
    raise "no page #{page_name.inspect}" if pg.nil?
    hid = pg.hidden_entities rescue []
    n = 0
    room_pieces.each do |g|
      want = hid.include?(g)
      n += 1 if want
      g.hidden = want if g.hidden? != want
    end
    m.active_view.camera = pg.camera
    { 'eye' => pg.camera.eye.to_a.map { |v| v.to_f.round(1) }, 'hidden_room_pieces' => n }
  end

  # Everything back on, for whoever is watching the viewport.
  def self.show_room!
    room_pieces.each { |g| g.hidden = false if g.hidden? }
    true
  end

  # Aim at an explicit camera (concept shots that are not AUTO-SET pages).
  def self.aim_cam!(eye, target, fov)
    c = Sketchup::Camera.new(Geom::Point3d.new(*eye), Geom::Point3d.new(*target), Z_AXIS)
    c.fov = fov
    model.active_view.camera = c
    eye
  end

  # Start the render and wait (at most ~20 s, inside this one job) until it is
  # SEEN running. That latch is what makes a later :idleDone mean "finished".
  def self.start!(page_name = nil)
    aim!(page_name) if page_name
    @latched = false
    @t0 = Time.now
    VRay::Command.render_production(:context => ctx)
    loop do
      st = (rend.state rescue nil).to_s
      if st =~ /render|prepar/i
        @latched = true
        break
      end
      break if Time.now - @t0 > 20.0
      sleep(0.05)
    end
    { 'latched' => @latched, 'state' => (rend.state rescue nil).to_s,
      'after_s' => (Time.now - @t0).round(1) }
  end

  def self.poll
    st = (rend.state rescue nil).to_s
    done = @latched && st == 'idleDone'
    { 'state' => st, 'latched' => @latched, 'done' => done,
      'elapsed_s' => (@t0 ? (Time.now - @t0).round(1) : nil) }
  end

  def self.save!(path)
    raise 'render never latched as running - refusing to save a stale buffer' unless @latched
    raise "not finished: #{rend.state}" unless rend.state.to_s == 'idleDone'
    File.delete(path) if File.exist?(path)
    ok = rend.save_vfb_image(path, :skip_alpha => true, :no_alpha => true)
    exr = path.sub(/\.png\z/i, '.exr')
    File.delete(exr) if File.exist?(exr)
    ok2 = (rend.save_vfb_image(exr, :skip_alpha => true) rescue "RAISED #{$!.class}")
    # Radiance .hdr too: float, and readable by this machine's OpenCV (its
    # build has no OpenEXR - observed 22 Sep 2026)
    hdr = path.sub(/\.png\z/i, '.hdr')
    File.delete(hdr) if File.exist?(hdr)
    ok3 = (rend.save_vfb_image(hdr, :skip_alpha => true, :no_alpha => true) rescue "RAISED #{$!.class}")
    { 'png' => ok, 'png_bytes' => (File.exist?(path) ? File.size(path) : -1),
      'exr' => ok2, 'exr_bytes' => (File.exist?(exr) ? File.size(exr) : -1),
      'hdr' => ok3, 'hdr_bytes' => (File.exist?(hdr) ? File.size(hdr) : -1),
      'render_s' => (Time.now - @t0).round(1) }
  end
end
