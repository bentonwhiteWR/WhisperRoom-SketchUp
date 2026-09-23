m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
bt = b.transformation; bi = bt.inverse
aud = b.definition.entities.grep(Sketchup::ComponentInstance).select { |e| e.name =~ /^Audimute/ }
nrm = { 'back' => Geom::Vector3d.new(1, 0, 0), 'left' => Geom::Vector3d.new(0, 1, 0), 'right' => Geom::Vector3d.new(0, -1, 0) }
moves = []
aud.each(&:hidden=.to_proc.curry[true]) rescue aud.each { |e| e.hidden = true }
plan = aud.map do |e|
  n = nrm[e.name.split.last]
  body = e.definition.entities.grep(Sketchup::ComponentInstance).max_by { |i| i.definition.bounds.width * i.definition.bounds.depth }
  bb = Geom::BoundingBox.new; db = body.definition.bounds
  (0..7).each { |k| bb.add(db.corner(k).transform(bt * e.transformation * body.transformation)) }
  back = n.x.abs > 0.5 ? (n.x > 0 ? bb.min.x : bb.max.x) : (n.y > 0 ? bb.min.y : bb.max.y)
  c = bb.center
  hit = m.raytest([c, n.reverse], true)
  face = hit && (n.x.abs > 0.5 ? hit[0].x : hit[0].y)
  [e, n, back, face, hit ? hit[1].last.class.name.split('::').last + ' in ' + (hit[1][-2].respond_to?(:definition) ? hit[1][-2].definition.name : '?') : 'miss']
end
aud.each { |e| e.hidden = false }
m.start_operation('Press Audimute panels onto the wall', true)
plan.each do |e, n, back, face, what|
  next unless face
  d = face - back
  v = n.x.abs > 0.5 ? Geom::Vector3d.new(d, 0, 0) : Geom::Vector3d.new(0, d, 0)
  e.transform!(bi * Geom::Transformation.translation(v) * bt)
  moves << format('%-18s moved %+.3f  (wall hit: %s)', e.name, d, what)
end
m.commit_operation
puts moves
nil
