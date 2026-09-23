# "09-interior dims" (Benton, 22 Sep): plain SketchUp IMAGE, straight top-down, the booth's INTERIOR clear
# width and length between the IEP (inner-shell) wall faces (measured by jobs/interior-faces.rb:
# W X 22.57, E X 160.07, S Y 159.99, N Y 249.49 -> 137.50 x 89.50 in; the foam is separate 24 in sheets,
# so it is not the reference). Dims live INSIDE the booth group (they travel with it) on their own tag,
# visible only in this scene. The scene hides, in its OWN stored hidden set: the booth ceilings
# (STD/ENH 9648CL), the ceiling seam seals (STDSS CL8), Benton's studio lights (Component#127), plus
# what a top view cannot see through (the room's Ceiling + Ceiling fixtures) and the V-Ray light widgets.
# Tags hidden in this scene: room EST dims + floor note, the exterior booth dims. Camera: parallel top view
# (the stable storage), no AUTO-SET stamp, package mode = image.
m = Sketchup.active_model
v = m.active_view
ps = m.pages
name09 = '09-interior dims'
bd = 'wr_cms_bdims'
m.options['PageOptions']['TransitionTime'] = 0.0
b = m.entities.find { |e| e.respond_to?(:name) && e.name == 'MDL 96144 E (components)' }
bt = b.transformation
tag = m.layers['CMS Booth Interior Dims'] || m.layers.add('CMS Booth Interior Dims')
cms = m.layers['CMS Room Dims (EST)']
bdt = m.layers['WR-Dims-Booth']
snap = ->() { ps.reject { |p| p.name == name09 }.map { |p| [p.name, p.use_hidden_layers? ? p.layers.map(&:name).sort : :none, ((p.hidden_entities rescue nil) || []).size] } }
before = snap.call
hide_defs = /\A(STD9648CL|ENH 9648CL|STDSS CL|Component#127\z)/
booth_hide = b.definition.entities.select { |e| e.respond_to?(:definition) && e.definition.name =~ hide_defs }
room = m.entities.find { |e| e.respond_to?(:name) && e.name == 'CMS Classroom' }
walls = room.definition.entities.find { |g| g.respond_to?(:name) && g.name == 'Walls' }
room_hide = walls.definition.entities.select { |g| g.respond_to?(:name) && g.name == 'Ceiling' } +
            room.definition.entities.select { |g| g.respond_to?(:name) && g.name == 'Ceiling fixtures' }
light_hide = m.entities.select { |e| e.get_attribute('wr_cms_lights', 'plugin') }
all_hide = booth_hide + room_hide + light_hide
out = {}
m.start_operation('CMS: 09-interior dims', true)
begin
  # the two interior dims (booth-local, inside the booth group)
  be = b.definition.entities
  be.erase_entities(be.select { |e| e.valid? && e.get_attribute(bd, 'own', false) })
  fz = 6.81 + 0.25
  inv = bt.inverse
  mk = lambda do |a, c, off|
    pa = Geom::Point3d.new(*a).transform(inv)
    pc = Geom::Point3d.new(*c).transform(inv)
    # plain points: inside a group, add_dimension_linear refuses the [cpoint, point] attach form (observed)
    d = be.add_dimension_linear(pa, pc, Geom::Vector3d.new(*off).transform(inv))
    d.layer = tag
    d.set_attribute(bd, 'own', true)
    d
  end
  dw = mk.call([22.57, 185.0, fz], [160.07, 185.0, fz], [0, 0.5, 0])   # a zero offset vector is refused
  dl = mk.call([140.0, 159.99, fz], [140.0, 249.49, fz], [0.5, 0, 0])
  [dw, dl].each { |d| d.text = "<> CLEAR" rescue nil }
  out['dims'] = [dw, dl].map { |d| [d.start[1].distance(d.end[1]).to_f.round(2), d.text] }
  # every OTHER scene: the new tag hidden, stored
  ps.each { |p| p.set_visibility(tag, false) if p.name != name09 && p.use_hidden_layers? }
  # scene 09
  pg = ps[name09] || ps.add(name09)
  ps.selected_page = pg
  tag.visible = true
  was_cms, was_bdt = cms.visible?, bdt.visible?
  cms.visible = false
  bdt.visible = false
  all_hide.each { |e| e.hidden = true }
  c = b.bounds.center
  cam = Sketchup::Camera.new([c.x, c.y + 4, 1500], [c.x, c.y + 4, 0], [0, 1, 0])
  cam.perspective = false
  cam.height = 150.0
  v.camera = cam
  v.refresh
  %i[use_axes= use_rendering_options= use_shadow_info= use_section_planes=].each { |mm| pg.send(mm, false) }
  pg.use_camera = true
  pg.use_hidden_layers = true
  pg.use_hidden_objects = true
  pg.update(PAGE_USE_CAMERA | PAGE_USE_HIDDEN_OBJECTS | PAGE_USE_LAYER_VISIBILITY)
  pg.set_visibility(tag, true); pg.set_visibility(cms, false); pg.set_visibility(bdt, false)
  pg.set_attribute('WR_ProposalPackage', 'mode', 'image')
  pg.set_attribute('wr_cms', 'role', 'interior-dims')
  # global state back to neutral: nothing hidden, the new tag off (photo scenes store no tag state)
  all_hide.each { |e| e.hidden = false }
  tag.visible = false
  cms.visible = was_cms
  bdt.visible = was_bdt
  m.commit_operation
rescue Exception
  m.abort_operation
  raise
end
after = snap.call
pg = ps[name09]
changed = before.zip(after).reject { |x, y| x[0] == y[0] && x[2] == y[2] && (x[1] == :none || (y[1] - [tag.name]) == x[1]) }
out['scene'] = { 'persp' => pg.camera.perspective?, 'height' => pg.camera.height.to_f.round(1), 'aspect' => pg.camera.aspect_ratio,
                 'autoset' => pg.get_attribute('WR_AutoSet', 'plate'), 'mode' => pg.get_attribute('WR_ProposalPackage', 'mode'),
                 'hidden' => (pg.hidden_entities || []).map { |e| e.respond_to?(:definition) ? e.definition.name : e.name }.tally,
                 'tags_hidden' => pg.layers.map(&:name) }
out['other_scenes_changed_beyond_new_tag_hidden'] = changed
out['other_scenes_with_tag_state_hiding_new_tag'] = ps.count { |p| p.name != name09 && p.use_hidden_layers? && p.layers.include?(tag) }
out['pages'] = ps.count
out
