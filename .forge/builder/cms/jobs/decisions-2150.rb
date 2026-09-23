# Benton's decisions, 22 Sep ~21:50:
#  a. 09 perimeter drawn in brand orange #ee6216, dashed: rebuilt as flat orange DASH STRIPS (faces,
#     outlines hidden) -- the style draws every edge one colour, and changing the style would touch
#     every scene. Same rectangle (X 1.32-181.32, Y 138.74-270.74), same tag.
#  c. "08-interior corner" -> package mode render (ev 14.73).
#  f. NEW scene "01b-angled room r": a photographer standing in the room near the Wall B / Wall C corner,
#     every room wall shown, 65 deg height fov, aspect 0 (stable), no AUTO-SET stamp, mode render ev 14.73.
#     Existing scenes are NOT touched (Benton: keep them; revert record scene-backup-20260922-2148.json).
m = Sketchup.active_model
v = m.active_view
ps = m.pages
m.options['PageOptions']['TransitionTime'] = 0.0
b = m.entities.find { |e| e.respond_to?(:name) && e.name == 'MDL 96144 E (components)' }
bt = b.transformation
inv = bt.inverse
out = {}
before = ps.map(&:name)
m.start_operation('CMS: decisions 21:50', true)
begin
  # a. orange dashed perimeter
  g = b.definition.entities.find { |e| e.is_a?(Sketchup::Group) && e.name == '18 in clearance perimeter' }
  raise 'no perimeter group' unless g
  g.entities.clear!
  mat = m.materials['CMS Perimeter Orange'] || m.materials.add('CMS Perimeter Orange')
  mat.color = Sketchup::Color.new(0xee, 0x62, 0x16)
  r = [1.32, 138.74, 181.32, 270.74]
  z = 6.81 + 0.35
  dash, gap, wd = 6.0, 4.0, 0.9
  runs = [[[r[0], r[1]], [r[2], r[1]]], [[r[2], r[1]], [r[2], r[3]]], [[r[2], r[3]], [r[0], r[3]]], [[r[0], r[3]], [r[0], r[1]]]]
  n = 0
  runs.each do |(a, c)|
    len = Math.hypot(c[0] - a[0], c[1] - a[1])
    ux, uy = (c[0] - a[0]) / len, (c[1] - a[1]) / len
    nx, ny = -uy * wd / 2, ux * wd / 2
    s = 0.0
    while s < len
      e = [s + dash, len].min
      p0 = [a[0] + ux * s, a[1] + uy * s]; p1 = [a[0] + ux * e, a[1] + uy * e]
      pts = [[p0[0] + nx, p0[1] + ny, z], [p1[0] + nx, p1[1] + ny, z], [p1[0] - nx, p1[1] - ny, z], [p0[0] - nx, p0[1] - ny, z]]
      f = g.entities.add_face(pts.map { |p| Geom::Point3d.new(*p).transform(inv) })
      if f
        f.material = mat; f.back_material = mat
        f.edges.each { |ed| ed.hidden = true }
        n += 1
      end
      s += dash + gap
    end
  end
  out['perimeter_dashes'] = n
  # c. 08 in the package as a render
  p8 = ps['08-interior corner']
  p8.set_attribute('WR_ProposalPackage', 'mode', 'render')
  p8.set_attribute('WR_ProposalPackage', 'ev', 14.73)
  # f. new hero, inside the room
  name = '01b-angled room r'
  pg = ps[name] || ps.add(name)
  ps.selected_page = pg
  room = m.entities.find { |e| e.respond_to?(:name) && e.name == 'CMS Classroom' }
  room.definition.entities.grep(Sketchup::Group).each { |gg| gg.hidden = false; gg.entities.grep(Sketchup::Group).each { |c| c.hidden = false } if gg.name == 'Walls' }
  eye = Geom::Point3d.new(9.0, 9.0, 60.0)
  tgt = Geom::Point3d.new(118.0, 205.0, 62.0)
  cam = Sketchup::Camera.new(eye, tgt, Z_AXIS)
  cam.perspective = true
  cam.fov = 65.0
  v.camera = cam
  v.refresh
  %i[use_axes= use_rendering_options= use_shadow_info= use_section_planes=].each { |mm| pg.send(mm, false) }
  pg.use_camera = true
  pg.use_hidden_layers = true
  pg.use_hidden_objects = true
  pg.update(PAGE_USE_CAMERA | PAGE_USE_HIDDEN_OBJECTS | PAGE_USE_LAYER_VISIBILITY)
  { 'WR Lights' => true, 'CMS Room Dims (EST)' => false, 'WR-Dims-Booth' => false, 'WR-Dims' => false, 'WR-Dims-Doors' => false,
    'WR-Notes' => false, 'CMS Booth Interior Dims' => false, 'CMS Booth 18in Perimeter' => false }.each do |tn, vis|
    l = m.layers[tn]
    pg.set_visibility(l, vis) if l
  end
  pg.set_attribute('WR_ProposalPackage', 'mode', 'render')
  pg.set_attribute('WR_ProposalPackage', 'ev', 14.73)
  pg.set_attribute('wr_cms', 'role', 'hero-in-room')
  m.commit_operation
rescue Exception
  m.abort_operation
  raise
end
c = ps['01b-angled room r'].camera
out['new_scene'] = { 'fov' => c.fov.round(2), 'aspect' => c.aspect_ratio, 'height' => c.fov_is_height?, 'eye' => c.eye.to_a.map { |x| x.to_f.round(1) },
                     'hidden_objects' => ((ps['01b-angled room r'].hidden_entities || []).size rescue nil),
                     'autoset' => ps['01b-angled room r'].get_attribute('WR_AutoSet', 'plate') }
out['added_scenes'] = ps.map(&:name) - before
out['p8_mode'] = ps['08-interior corner'].get_attribute('WR_ProposalPackage', 'mode')
out
