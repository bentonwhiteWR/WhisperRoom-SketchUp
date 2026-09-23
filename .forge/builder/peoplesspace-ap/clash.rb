m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
rm = b.definition.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'RM96120VSS' }
hs = b.definition.entities.grep(Sketchup::ComponentInstance).select { |e| e.name == 'HEPA (intake)' }
hd = m.definitions['HEPA'].bounds
rm.definition.entities.each do |a|
  next unless a.respond_to?(:definition) && a.definition.name != 'VSS duct box'
  t = rm.transformation * a.transformation
  a.definition.entities.grep(Sketchup::Face).each do |f|
    pts = f.vertices.map { |vx| vx.position.transform(t) }
    hs.each_with_index do |h, i|
      inv = h.transformation.inverse
      ins = pts.select { |p| q = p.transform(inv); q.x.between?(hd.min.x, hd.max.x) && q.y.between?(hd.min.y, hd.max.y) && q.z.between?(hd.min.z, hd.max.z) }
      next if ins.empty?
      (($hit ||= {})[[a.definition.name, i, f.material&.display_name]] ||= Geom::BoundingBox.new).add(ins.map { |p| p.transform(b.transformation) })
    end
  end
end
$hit.each { |k, bb| puts format('%s HEPA#%d mat=%s  world [%.1f..%.1f, %.1f..%.1f, %.1f..%.1f]', k[0], k[1], k[2].inspect, bb.min.x, bb.max.x, bb.min.y, bb.max.y, bb.min.z, bb.max.z) }
$hit = nil
nil
