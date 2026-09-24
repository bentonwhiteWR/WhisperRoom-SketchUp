# Tampa Prep render driver: one V-Ray production frame of a PAGE, the way proposal-package.rb renders a
# row (select the page, set the camera from page.camera, render_production at the camera AS CONFIGURED --
# no exposure write), started in one short bridge job and polled in later short jobs.
# Only /SettingsOutput size is written (restore! puts back the recorded 1600x900).
module WR_TampaRender
  ORIG_SIZE = [1600, 900].freeze   # observed in survey.json before any test
  def self.ctx;   VRay::Context.active; end
  def self.scene; ctx.scene; end
  def self.rend;  ctx.renderer; end
  def self.model; Sketchup.active_model; end

  def self.stop!
    st = (rend.state rescue nil).to_s
    VRay::Command.stop_current_render if st =~ /render|prepar/i
    { 'before' => st }
  end

  def self.size!(w, h)
    sc = scene
    sc.change { so = sc['/SettingsOutput']; so[:img_width] = w.to_i; so[:img_height] = h.to_i }
    so = sc['/SettingsOutput']
    got = [so[:img_width].to_i, so[:img_height].to_i]
    raise "size did not stick: #{got}" if got != [w.to_i, h.to_i]
    got
  end

  # Stage in its OWN job (select the page, set its camera, refresh), render in a LATER job, so the
  # viewport has settled before V-Ray exports the camera.
  def self.stage!(page_name, w = 800, h = 450)
    st = (rend.state rescue nil).to_s
    raise "renderer busy (#{st}) - stop it first" if st =~ /render|prepar/i
    size!(w, h)
    m = model
    pg = m.pages[page_name] or raise "no page #{page_name.inspect}"
    m.options['PageOptions']['TransitionTime'] = 0.0
    m.pages.selected_page = pg
    m.active_view.camera = pg.camera
    m.active_view.refresh
    stray_cam!(pg.camera, w.to_f / h.to_f)
    { 'page' => pg.name, 'eye' => m.active_view.camera.eye.to_a.map { |v| v.to_f.round(1) } }
  end

  # THE STRAY CAMERA (found 24 Sep). This model's V-Ray scene carries a second set of top-level plugins
  # (/RenderView#1, /CameraPhysical#1, /SettingsOutput#1, /SunLight#1 ... and a /SettingsOptions named
  # "12ftx12ftCustomBoothAssemblyStandardCompleteskp", i.e. imported with a component). Production renders
  # go through /RenderView#1, which sits at the ORIGIN (identity) -- every frame came back as blurry floor
  # squares whatever the camera. For TESTS ONLY, /RenderView#1 is aimed at the page camera and
  # /CameraPhysical#1 stops forcing its 90 deg fov. restore! puts both back exactly as found.
  RV1_ORIG = { fov: 0.785398006439209 }.freeze
  def self.stray_cam!(cam, aspect)
    sc = scene
    return nil unless sc['/RenderView#1']
    e = cam.eye; d = (cam.target - cam.eye).normalize
    rt = (d * cam.up).normalize; up = (rt * d).normalize
    v = ->(a) { VRay::Vector.new(a.x.to_f, a.y.to_f, a.z.to_f) }
    t = VRay::Transform.new(VRay::Matrix.new(v.(rt), v.(up), VRay::Vector.new(-d.x, -d.y, -d.z)), v.(e))
    hfov = cam.fov_is_height? ? 2.0 * Math.atan(Math.tan(cam.fov.degrees / 2.0) * aspect) : cam.fov.degrees
    sc.change do
      sc['/RenderView#1'][:transform] = t
      sc['/RenderView#1'][:fov] = hfov
      sc['/CameraPhysical#1'][:specify_fov] = false if sc['/CameraPhysical#1']
    end
    hfov
  end

  def self.stray_restore!
    sc = scene
    return nil unless sc['/RenderView#1']
    id = VRay::Transform.new(VRay::Matrix.new(VRay::Vector.new(1, 0, 0), VRay::Vector.new(0, 1, 0), VRay::Vector.new(0, 0, 1)), VRay::Vector.new(0, 0, 0))
    sc.change do
      sc['/RenderView#1'][:transform] = id
      sc['/RenderView#1'][:fov] = RV1_ORIG[:fov]
      sc['/CameraPhysical#1'][:specify_fov] = true if sc['/CameraPhysical#1']
    end
    [sc['/RenderView#1'][:transform].to_a.flatten.map { |x| x.is_a?(Numeric) ? x : x.to_a }, sc['/RenderView#1'][:fov], sc['/CameraPhysical#1'][:specify_fov]]
  end

  def self.start!
    st = (rend.state rescue nil).to_s
    raise "renderer busy (#{st}) - stop it first" if st =~ /render|prepar/i
    @latched = false
    @t0 = Time.now
    VRay::Command.render_production(:context => ctx)
    loop do
      s = (rend.state rescue nil).to_s
      (@latched = true; break) if s =~ /render|prepar/i
      break if Time.now - @t0 > 20.0
      sleep(0.05)
    end
    { 'latched' => @latched, 'state' => (rend.state rescue nil).to_s }
  end

  def self.poll
    st = (rend.state rescue nil).to_s
    { 'state' => st, 'latched' => @latched, 'done' => (@latched && st =~ /\Aidle(Done|Stopped)\z/ ? true : false),
      'elapsed_s' => (@t0 ? (Time.now - @t0).round(1) : nil) }
  end

  def self.save!(path)
    raise 'never latched' unless @latched
    raise "not finished: #{rend.state}" unless rend.state.to_s =~ /\Aidle/
    ok = rend.save_vfb_image(path, :skip_alpha => true, :no_alpha => true)
    hdr = path.sub(/\.png\z/i, '.hdr')
    ok3 = (rend.save_vfb_image(hdr, :skip_alpha => true, :no_alpha => true) rescue "RAISED #{$!.class}")
    { 'png' => ok, 'hdr' => ok3, 'render_s' => (Time.now - @t0).round(1) }
  end

  # Put back what the survey recorded: output size, the selected page, and the viewport camera.
  def self.restore!(page_name, eye, target, fov)
    size!(*ORIG_SIZE)
    stray = stray_restore!
    m = model
    m.pages.selected_page = m.pages[page_name]
    c = Sketchup::Camera.new(Geom::Point3d.new(*eye), Geom::Point3d.new(*target), Z_AXIS)
    c.fov = fov
    m.active_view.camera = c
    { 'page' => m.pages.selected_page.name, 'size' => ORIG_SIZE, 'stray' => stray }
  end
end
