m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
rm = b.definition.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'RM96120VSS' }
hs = b.definition.entities.grep(Sketchup::ComponentInstance).select { |e| e.name == 'HEPA (intake)' }
raise "expected 4 HEPAs, found #{hs.length}" unless hs.length == 4
len = m.definitions['HEPA'].bounds.depth
m.start_operation('HEPA: flip back, butt to duct box end', true)
hs.each do |h|
  h.transform!(Geom::Transformation.rotation(h.bounds.center, Z_AXIS, 180.degrees))
  v = h.transformation.zaxis; v.length = len
  h.transform!(Geom::Transformation.translation(v))
end
m.commit_operation
# clash test: hose vertices (booth-local) inside each HEPA's own local box
hose_pts = []
rm.definition.entities.each do |a|
  next unless a.respond_to?(:definition) && a.definition.name != 'VSS duct box'
  t = rm.transformation * a.transformation
  a.definition.entities.grep(Sketchup::Face).each { |f| f.vertices.each { |vx| hose_pts << vx.position.transform(t) } }
end
hd = m.definitions['HEPA'].bounds
hs.each do |h|
  inv = h.transformation.inverse
  hits = hose_pts.count { |p| q = p.transform(inv); q.x.between?(hd.min.x, hd.max.x) && q.y.between?(hd.min.y, hd.max.y) && q.z.between?(hd.min.z, hd.max.z) }
  near = hose_pts.map { |p| q = p.transform(inv); dx = [hd.min.x - q.x, 0, q.x - hd.max.x].max; dy = [hd.min.y - q.y, 0, q.y - hd.max.y].max; dz = [hd.min.z - q.z, 0, q.z - hd.max.z].max; Math.sqrt(dx*dx + dy*dy + dz*dz) }.min
  wb = Geom::BoundingBox.new; (0..7).each { |k| wb.add(hd.corner(k).transform(b.transformation * h.transformation)) }
  puts format('HEPA world [%.1f..%.1f, %.1f..%.1f, %.1f..%.1f]  hose vertices inside: %d  nearest hose: %.2f in', wb.min.x, wb.max.x, wb.min.y, wb.max.y, wb.min.z, wb.max.z, hits, near.to_f)
end
m.active_view.camera = Sketchup::Camera.new([130, 20, 116], [45, 90, 86], [0, 0, 1])
nil
