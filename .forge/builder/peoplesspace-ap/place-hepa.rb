m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
rm = b.definition.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'RM96120VSS' }
hepa = m.definitions['HEPA'] or raise 'HEPA definition not loaded'
boxes = rm.definition.entities.select { |e| e.respond_to?(:definition) && e.definition.name == 'VSS duct box' }
raise "expected 4 intake boxes, found #{boxes.length}" unless boxes.length == 4
layer = m.layers['WR-Booth-Options']
b.definition.entities.grep(Sketchup::ComponentInstance).select { |e| e.name == 'HEPA (intake)' }.each(&:erase!)
m.start_operation('Add HEPA filters (intake boxes)', true)
placed = []
boxes.each do |i|
  t = b.transformation * rm.transformation * i.transformation
  p_end = Geom::Point3d.new(3.92, 3.87, 49.5).transform(t)    # centre of the open (recessed) end
  bottom = Geom::Point3d.new(0.67, 3.87, 49.5).transform(t).z
  a = Geom::Vector3d.new(0, 0, 1).transform(t); a.z = 0; a.normalize!   # along the box, out of the open end
  u = Geom::Vector3d.new(0, 0, 1)
  y = a * u
  org = Geom::Point3d.new(p_end.x, p_end.y, bottom).offset(y, -3.25).offset(a, -hepa.bounds.depth)
  world = Geom::Transformation.axes(org, u, y, a)
  inst = b.definition.entities.add_instance(hepa, b.transformation.inverse * world)
  inst.layer = layer if layer
  inst.name = 'HEPA (intake)'
  bb = Geom::BoundingBox.new; (0..7).each { |k| bb.add(hepa.bounds.corner(k).transform(world)) }
  placed << format('[%.1f..%.1f, %.1f..%.1f, %.1f..%.1f]', bb.min.x, bb.max.x, bb.min.y, bb.max.y, bb.min.z, bb.max.z)
end
m.commit_operation

c = m.active_view.camera

puts placed
nil
