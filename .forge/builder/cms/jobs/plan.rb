# One-screen top-down plan with the EST. dimensions. Everything is rolled back afterwards.
m = Sketchup.active_model
v = m.active_view
old = v.camera
out = 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/cms/compare/plan-top-EST.png'
m.start_operation('CMS plan shot (rolled back)', true)
begin
  sp = m.entities.add_section_plane([0, 0, 80], [0, 0, -1])
  sp.activate
  m.rendering_options['DisplaySectionPlanes'] = false rescue nil
  bb = Geom::BoundingBox.new
  m.entities.each { |e| bb.add(e.bounds) if e.valid? && !e.is_a?(Sketchup::SectionPlane) }
  c = bb.center
  c = Geom::Point3d.new(c.x, c.y - bb.height * 0.04, 0)
  cam = Sketchup::Camera.new([c.x, c.y, 2000], [c.x, c.y, 0], [0, 1, 0])
  cam.perspective = false
  cam.height = [bb.height, bb.width * 1500.0 / 1900.0].max * 1.14
  v.camera = cam
  ok = v.write_image(filename: out, width: 1900, height: 1500, antialias: true, transparent: false)
  res = [ok, bb.width.to_f.round, bb.height.to_f.round]
ensure
  m.abort_operation
  v.camera = old
end
res
