m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
rm = b.definition.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'RM96120VSS' }
rm.definition.entities.each do |a|
  next unless a.respond_to?(:definition) && a.definition.name != 'VSS duct box'
  t = b.transformation * rm.transformation * a.transformation
  fs = a.definition.entities.grep(Sketchup::Face)
  next if fs.empty?
  bb = Geom::BoundingBox.new
  fs.each { |f| f.vertices.each { |v| bb.add(v.position.transform(t)) } }
  puts format('%-14s loose-geom (hose) [%.1f..%.1f, %.1f..%.1f, %.1f..%.1f]', a.definition.name, bb.min.x, bb.max.x, bb.min.y, bb.max.y, bb.min.z, bb.max.z)
end
nil
