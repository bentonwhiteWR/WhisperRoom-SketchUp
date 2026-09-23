# Probe: a page camera stored HORIZONTAL (fov_is_height false, aspect 4:3), then (1) selected, (2) its
# aspect cleared, (3) selected again, (4) assigned to the view via view.camera = page.camera. Temporary page only.
m = Sketchup.active_model
v = m.active_view
ps = m.pages
sel = ps.selected_page
m.options['PageOptions']['TransitionTime'] = 0.0
out = {}
f = ->(c) { [c.fov.round(2), c.aspect_ratio.round(4), c.fov_is_height?] }
begin
  s = Sketchup::Camera.new(Geom::Point3d.new(-89.8, -52.6, 61.0), Geom::Point3d.new(91.3, 204.0, 44.0), Z_AXIS)
  s.aspect_ratio = 4.0 / 3.0
  s.fov = 35.0
  v.camera = s
  pg = ps.add('ZZ fov probe 4')
  pg.update(PAGE_USE_CAMERA)
  out['1_stored'] = f.call(pg.camera)
  ps.selected_page = sel; ps.selected_page = pg
  out['2_after_select_view'] = f.call(v.camera)
  out['2_page'] = f.call(pg.camera)
  c = pg.camera; c.aspect_ratio = 0.0
  out['3_page_after_clear'] = f.call(pg.camera)
  v.camera = pg.camera
  out['4_view_eq_page'] = f.call(v.camera)
  vc = v.camera; vc.fov = vc.fov; v.camera = vc
  out['5_page_after_view_edit'] = f.call(pg.camera)
ensure
  z = ps['ZZ fov probe 4']
  ps.erase(z) if z
  ps.selected_page = sel if sel && sel.valid?
end
out
