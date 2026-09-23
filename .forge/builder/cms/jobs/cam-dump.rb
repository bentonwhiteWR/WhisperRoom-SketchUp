# READ-ONLY: every scene's stored camera + flags, and the viewport.
m = Sketchup.active_model
v = m.active_view
r = ->(p) { p.to_a.map { |x| x.to_f.round(1) } }
rows = m.pages.map do |pg|
  c = pg.camera
  b = m.entities.find { |e| e.respond_to?(:name) && e.name == 'MDL 96144 E (components)' }
  dist = c.eye.distance(b.bounds.center).to_f.round(1)
  { 'name' => pg.name, 'use_camera' => pg.use_camera?, 'persp' => c.perspective?, 'fov' => (c.fov.round(2) rescue nil),
    'fov_is_height' => (c.fov_is_height? rescue nil), 'aspect' => c.aspect_ratio.round(4), 'image_width' => (c.image_width.round(2) rescue nil),
    'focal' => (c.focal_length.round(2) rescue nil), 'height' => (c.perspective? ? nil : c.height.to_f.round(1)),
    'eye' => r.call(c.eye), 'target' => r.call(c.target), 'up' => c.up.to_a.map { |x| x.round(3) }, 'dist_to_booth_ctr' => dist,
    'mode' => pg.get_attribute('WR_ProposalPackage', 'mode'), 'plate' => pg.get_attribute('WR_AutoSet', 'plate'),
    'autoset_version' => pg.get_attribute('WR_AutoSet', 'version') }
end
{ 'viewport' => [v.vpwidth, v.vpheight], 'current' => { 'fov' => v.camera.fov.round(2), 'aspect' => v.camera.aspect_ratio }, 'pages' => rows }
