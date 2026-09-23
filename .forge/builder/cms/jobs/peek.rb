# Viewport PNG into the booth through its window (S1). Light widgets and the room-dims tag hidden for the
# shot, restored in an ensure. $cms_view = [eye, target, fov, path]
m = Sketchup.active_model
v = m.active_view
eye, tgt, fov, path = $cms_view
lights = m.entities.select { |e| e.get_attribute('wr_cms_lights', 'plugin') }
dl = m.layers['CMS Room Dims (EST)']
was = dl.visible?
begin
  lights.each { |e| e.hidden = true }
  dl.visible = false
  c = Sketchup::Camera.new(Geom::Point3d.new(*eye), Geom::Point3d.new(*tgt), Z_AXIS)
  c.fov = fov
  v.camera = c
  ok = v.write_image(filename: path, width: 1600, height: 1100, antialias: true, transparent: false)
ensure
  lights.each { |e| e.hidden = false }
  dl.visible = was
end
[ok, path]
