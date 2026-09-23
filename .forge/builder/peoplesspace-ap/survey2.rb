m = Sketchup.active_model
def fmt(b) ; format('[%.1f..%.1f, %.1f..%.1f, %.1f..%.1f]', b.min.x.to_f,b.max.x.to_f,b.min.y.to_f,b.max.y.to_f,b.min.z.to_f,b.max.z.to_f); end
def walk(ents, tr, depth, maxd)
  ents.each do |e|
    next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    t = tr * e.transformation
    bb = Geom::BoundingBox.new; db=e.definition.bounds; (0..7).each { |i| bb.add(db.corner(i).transform(t)) }
    puts "#{'  '*depth}#{e.definition.name[0,60]} {#{e.layer.name}} #{fmt(bb)}#{e.hidden? ? ' HID' : ''}"
    walk(e.definition.entities, t, depth+1, maxd) if depth < maxd && e.definition.name !~ /wall|panel|seal|hinge|corner|ceiling|floor/i
  end
end
[['Group#28',2],['Group241',2]].each do |n,d|
  g = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == n && !e.hidden? }
  puts "== #{n}"; walk(g.definition.entities, g.transformation, 0, d)
end
nil
