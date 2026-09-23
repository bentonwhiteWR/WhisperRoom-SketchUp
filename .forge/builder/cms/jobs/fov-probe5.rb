# Probe: view.camera = page.camera for a page stored HORIZONTAL with aspect 4:3; then the same after a
# view-camera edit (what render.rb match_width! does). Temporary page only.
m = Sketchup.active_model
v = m.active_view
ps = m.pages
sel = ps.selected_page
f = ->(c) { [c.fov.round(2), c.aspect_ratio.round(4), c.fov_is_height?] }
out = {}
begin
  s = Sketchup::Camera.new(Geom::Point3d.new(-89.8, -52.6, 61.0), Geom::Point3d.new(91.3, 204.0, 44.0), Z_AXIS)
  s.aspect_ratio = 4.0 / 3.0
  s.fov = 35.0
  v.camera = s
  pg = ps.add('ZZ fov probe 5')
  pg.update(PAGE_USE_CAMERA)
  out['stored'] = f.call(pg.camera)
  v.camera = Sketchup::Camera.new(Geom::Point3d.new(0, 0, 60), Geom::Point3d.new(90, 200, 40), Z_AXIS)
  v.camera = pg.camera
  out['view_after_assign'] = f.call(v.camera)
  out['page_after_assign'] = f.call(pg.camera)
  cc = v.camera
  cc.fov = 20.0
  v.camera = cc
  out['page_after_view_fov_edit'] = f.call(pg.camera)
ensure
  z = ps['ZZ fov probe 5']
  ps.erase(z) if z
  ps.selected_page = sel if sel && sel.valid?
end
out
