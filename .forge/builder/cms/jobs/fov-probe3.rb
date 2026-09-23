# Probe on the VIEW camera only: aim() (in-place: perspective, fov=35, set) starting from a view camera
# that carries aspect_ratio 1.3333 (as Photo B leaves it), and a temporary page captured from it.
m = Sketchup.active_model
v = m.active_view
ps = m.pages
sel = ps.selected_page
out = {}
begin
  start = Sketchup::Camera.new(Geom::Point3d.new(0, 0, 60), Geom::Point3d.new(90, 200, 40), Z_AXIS)
  start.aspect_ratio = 4.0 / 3.0
  start.fov = 102.3
  v.camera = start
  out['start'] = [v.camera.fov.round(2), v.camera.aspect_ratio.round(4)]
  c = v.camera
  c.perspective = true
  c.fov = 35.0
  c.set(Geom::Point3d.new(-89.8, -52.6, 61.0), Geom::Point3d.new(91.3, 204.0, 44.0), Z_AXIS)
  v.refresh
  out['after_aim_view'] = [v.camera.fov.round(2), v.camera.aspect_ratio.round(4), v.camera.fov_is_height?]
  pg = ps.add('ZZ fov probe 3')
  pg.update(PAGE_USE_CAMERA)
  out['page_stored'] = [pg.camera.fov.round(2), pg.camera.aspect_ratio.round(4), pg.camera.fov_is_height?]
  c3 = pg.camera
  c3.aspect_ratio = 0.0 rescue nil
  out['page_if_aspect_cleared'] = [c3.fov.round(2), c3.aspect_ratio]
ensure
  z = ps['ZZ fov probe 3']
  ps.erase(z) if z
  ps.selected_page = sel if sel && sel.valid?
end
out['pages'] = ps.count
out
