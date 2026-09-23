# Viewport PNG of the booth in the room (dims tag hidden for the shot, then restored). $cms_view = [eye, target, fov, path]
m = Sketchup.active_model
v = m.active_view
eye, tgt, fov, path = $cms_view
dl = m.layers['CMS Room Dims (EST)']
was = dl.visible?
dl.visible = false
c = Sketchup::Camera.new(Geom::Point3d.new(*eye), Geom::Point3d.new(*tgt), Z_AXIS)
c.fov = fov
v.camera = c
ok = v.write_image(filename: path, width: 1600, height: 1000, antialias: true, transparent: false)
dl.visible = was
[ok, path]
