# Probe: page stored with an aspect-carrying (horizontal-fov) camera, then selected + view.refresh.
m = Sketchup.active_model
v = m.active_view
ps = m.pages
sel = ps.selected_page
m.options['PageOptions']['TransitionTime'] = 0.0
f = ->(c) { [c.fov.round(2), c.aspect_ratio.round(4), c.fov_is_height?] }
out = {}
begin
  s = Sketchup::Camera.new(Geom::Point3d.new(-89.8, -52.6, 61.0), Geom::Point3d.new(91.3, 204.0, 44.0), Z_AXIS)
  s.aspect_ratio = 4.0 / 3.0
  s.fov = 35.0
  v.camera = s
  pg = ps.add('ZZ fov probe 6')
  pg.update(PAGE_USE_CAMERA)
  out['stored'] = f.call(pg.camera)
  ps.selected_page = sel
  v.refresh
  ps.selected_page = pg
  v.refresh
  out['after_select_refresh_page'] = f.call(pg.camera)
  out['view'] = f.call(v.camera)
ensure
  z = ps['ZZ fov probe 6']
  ps.erase(z) if z
  ps.selected_page = sel if sel && sel.valid?
end
out
