m = Sketchup.active_model
eye = m.pages['MDL 144144 E 01-angled r'].camera.eye
hits = []
walk = lambda do |ents, tr, path|
  ents.each do |e|
    next unless e.respond_to?(:definition)
    t = tr * e.transformation
    bb = Geom::BoundingBox.new
    d = e.definition
    b = d.bounds
    8.times { |k| bb.add(b.corner(k).transform(t)) }
    nm = path + '/' + (e.name.to_s.empty? ? d.name : e.name)
    if bb.contains?(eye)
      hits << [nm, e.hidden?, e.layer.name, bb.min.to_a.map { |v| v.to_f.round }, bb.max.to_a.map { |v| v.to_f.round }]
      walk.call(d.entities, t, nm) if path.count('/') < 8
    end
  end
end
walk.call(m.entities, Geom::Transformation.new, '')
hits
