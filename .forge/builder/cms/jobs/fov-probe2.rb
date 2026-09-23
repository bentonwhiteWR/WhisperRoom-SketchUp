# Probe: does page.update(PAGE_USE_CAMERA) store fov differently from pages.add? Uses ONE temporary
# page "ZZ fov probe", erased at the end; the selected page is restored. No existing page is written.
m = Sketchup.active_model
v = m.active_view
ps = m.pages
sel = ps.selected_page
m.options['PageOptions']['TransitionTime'] = 0.0
out = {}
begin
  c = Sketchup::Camera.new(Geom::Point3d.new(-89.8, -52.6, 61.0), Geom::Point3d.new(91.3, 204.0, 44.0), Z_AXIS)
  c.fov = 35.0
  v.camera = c
  v.refresh
  pg = ps.add('ZZ fov probe')
  out['add_capture'] = [pg.camera.fov.round(2), pg.camera.aspect_ratio]
  ps.selected_page = pg
  c2 = Sketchup::Camera.new(Geom::Point3d.new(-89.8, -52.6, 61.0), Geom::Point3d.new(91.3, 204.0, 44.0), Z_AXIS)
  c2.fov = 35.0
  v.camera = c2
  v.refresh
  out['view_before_update'] = v.camera.fov.round(2)
  pg.update(PAGE_USE_CAMERA)
  out['after_update'] = [pg.camera.fov.round(2), pg.camera.aspect_ratio, pg.camera.fov_is_height?]
  # selecting the page again (what a click does)
  ps.selected_page = sel
  ps.selected_page = pg
  out['after_reselect_view'] = v.camera.fov.round(2)
ensure
  z = ps['ZZ fov probe']
  ps.erase(z) if z
  ps.selected_page = sel if sel && sel.valid?
end
out['pages'] = ps.count
out
