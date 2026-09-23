m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
rm = b.definition.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'RM96120VSS' }
def walk(ents, tr, d)
  ents.each do |e|
    if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      t = tr * e.transformation; db = e.definition.bounds; bb = Geom::BoundingBox.new
      (0..7).each { |i| bb.add(db.corner(i).transform(t)) }
      puts format('%s%-40s [%.1f..%.1f, %.1f..%.1f, %.1f..%.1f] faces=%d', '  '*d, e.definition.name[0,40], bb.min.x, bb.max.x, bb.min.y, bb.max.y, bb.min.z, bb.max.z, e.definition.entities.grep(Sketchup::Face).length)
      walk(e.definition.entities, t, d+1) if d < 4
    end
  end
end
walk(rm.definition.entities, b.transformation * rm.transformation, 0)
# VSS duct box definition: which faces are open? list face normals & areas of its own geometry
vd = m.definitions['VSS duct box']
bb = vd.bounds
puts format('VSS duct box def bounds %.2f x %.2f x %.2f  min(%.2f,%.2f,%.2f)', bb.width, bb.height, bb.depth, bb.min.x, bb.min.y, bb.min.z)
vd.entities.grep(Sketchup::Face).sort_by { |f| -f.area }.first(12).each { |f| puts format('  face n=%s area=%.1f c=%s', f.normal.to_a.map { |v| v.round(2) }.inspect, f.area, f.bounds.center.to_a.map { |v| v.to_f.round(1) }.inspect) }
nil
