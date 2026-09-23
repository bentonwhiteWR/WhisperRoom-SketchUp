# "08-interior corner" (Benton, 22 Sep): camera INSIDE the booth in the NW back corner (vent wall side, away
# from the door/window wall), photo B's heading, pitch, roll and lens, eye 57.7 in above the booth floor.
# Stored the STABLE way (the scene-zoom root cause): aspect 0, fov as HEIGHT -- photo B's 102.31 horizontal
# at 4:3 = 85.93 height. NOT stamped WR_AutoSet, so AUTO-SET apply/update never touches it.
m = Sketchup.active_model
v = m.active_view
ps = m.pages
m.options['PageOptions']['TransitionTime'] = 0.0
pb = ps['Photo B - corner view'].camera
dir = pb.direction
up = pb.up
raise "photo B camera not restored (aspect #{pb.aspect_ratio})" unless pb.aspect_ratio > 1.3
# booth floor: top of the IEP floor = lowest Z of the inner (ENH) wall parts
b = m.entities.find { |e| e.respond_to?(:name) && e.name == 'MDL 96144 E (components)' }
t = b.transformation
fz = b.definition.entities.select { |e| e.respond_to?(:definition) && e.definition.name =~ /\AENH .*(Panel|VNT|Door)/ }
      .map { |e| 8.times.map { |k| e.bounds.corner(k).transform(t).z }.min }.min
eye = Geom::Point3d.new(31.0, 240.0, fz + pb.eye.z)   # NW back corner, 6-7 in off the foam faces
tgt = eye.offset(dir, 100.0)
cam = Sketchup::Camera.new(eye, tgt, up)
cam.perspective = true
cam.fov = 2.0 * Math.atan(Math.tan(pb.fov.degrees / 2.0) / pb.aspect_ratio) * 180.0 / Math::PI   # 85.93
# every room piece visible (the scene stores its hidden state: nothing hidden)
room = m.entities.find { |e| e.respond_to?(:name) && e.name == 'CMS Classroom' }
room.definition.entities.grep(Sketchup::Group).each { |g| g.hidden = false; g.entities.grep(Sketchup::Group).each { |c| c.hidden = false } if g.name == 'Walls' }
m.layers['CMS Room Dims (EST)'].visible = false
m.layers['WR Lights'].visible = true
v.camera = cam
v.refresh
name = '08-interior corner'
pg = ps[name] || ps.add(name)
ps.selected_page = pg
v.camera = cam
v.refresh
%i[use_axes= use_rendering_options= use_shadow_info= use_section_planes=].each { |mm| pg.send(mm, false) }
pg.use_camera = true
pg.use_hidden_layers = true
pg.use_hidden_objects = true if pg.respond_to?(:use_hidden_objects=)
pg.update(PAGE_USE_CAMERA | PAGE_USE_HIDDEN_OBJECTS | PAGE_USE_LAYER_VISIBILITY)
pg.set_visibility(m.layers['CMS Room Dims (EST)'], false)
pg.set_attribute('wr_cms', 'role', 'interior-corner')
c = pg.camera
{ 'eye' => c.eye.to_a.map { |x| x.to_f.round(1) }, 'floor_z' => fz.to_f.round(2), 'fov' => c.fov.round(2), 'aspect' => c.aspect_ratio,
  'height' => c.fov_is_height?, 'heading' => (Math.atan2(c.direction.x, c.direction.y) * 180 / Math::PI).round(2),
  'pitch' => (Math.asin(c.direction.z) * 180 / Math::PI).round(2), 'roll' => (Math.asin(c.xaxis.z) * 180 / Math::PI).round(3),
  'autoset_stamp' => pg.get_attribute('WR_AutoSet', 'plate'), 'pages' => ps.count }
