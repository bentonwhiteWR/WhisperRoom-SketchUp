m = Sketchup.active_model
d = m.definitions['HEPA']
out = []
walk = lambda do |ents, t|
  ents.each do |e|
    if e.is_a?(Sketchup::Face)
      bb = Geom::BoundingBox.new; e.vertices.each { |v| bb.add(v.position.transform(t)) }
      n = e.normal.transform(t).normalize
      out << [n.to_a.map { |v| v.round(2) }, e.area.round(2), [bb.min.x, bb.max.x, bb.min.y, bb.max.y, bb.min.z, bb.max.z].map { |v| v.to_f.round(2) }]
    elsif e.respond_to?(:definition)
      walk.call(e.definition.entities, t * e.transformation)
    end
  end
end
walk.call(d.entities, Geom::Transformation.new)
out.select { |n, a, _| a > 1.0 }.sort_by { |n, a, b| [n.to_s, b[4]] }.each { |r| puts r.inspect }
nil
