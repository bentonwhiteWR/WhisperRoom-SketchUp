$wr_no_autorun = true
m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
bt = b.transformation; bi = bt.inverse
faces = { 'back' => [:x, 6.3, 1], 'left' => [:y, 9.0, 1], 'right' => [:y, 122.4, -1] }
m.start_operation('Seat Audimute on wall faces', true)
b.definition.entities.grep(Sketchup::ComponentInstance).select { |e| e.name =~ /^Audimute/ }.each do |e|
  g = WR_Overlays.geom_extents(e.definition)
  t = bt * e.transformation
  pts = [g[:lo], g[:hi]].product([g[:lo], g[:hi]], [g[:lo], g[:hi]]).map { |a, c, d| Geom::Point3d.new(a[0], c[1], d[2]).transform(t) }
  ax, face, s = faces[e.name.split.last]
  vals = pts.map { |p| ax == :x ? p.x : p.y }
  back = s > 0 ? vals.min : vals.max
  d = face - back
  v = ax == :x ? Geom::Vector3d.new(d, 0, 0) : Geom::Vector3d.new(0, d, 0)
  e.transform!(bi * Geom::Transformation.translation(v) * bt) if d.abs > 0.001
  printf("%-18s gap was %+.2f\n", e.name, -d)
end
m.commit_operation
nil
