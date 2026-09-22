# Trim the ONE foam sheet the booth's desk runs through (Benton, 22 Sep 2026).
# make_unique on that instance only; CUT the geometry at the desk-top plane
# (intersect, erase below, cap the section) so the wedge pattern never stretches.
m = Sketchup.active_model
inst = m.find_entity_by_persistent_id(3122476)
raise 'foam instance pid 3122476 not found' if inst.nil?
raise "pid 3122476 is #{inst.definition.name}, not Foam" unless inst.definition.name =~ /\AFoam/
desk = m.find_entity_by_persistent_id(3122480)
raise 'desk pid 3122480 not found' if desk.nil?
booth = m.entities.find { |e| e.is_a?(Sketchup::Group) && e.definition.entities.include?(inst) }
raise 'booth group containing the foam not found' if booth.nil?
bt = booth.transformation
wbox = lambda do |ent|
  bb = Geom::BoundingBox.new
  8.times { |k| bb.add(ent.bounds.corner(k).transform(bt)) }
  bb
end
dbb = wbox.call(desk)
zc = dbb.max.z.to_f
puts format('desk world z %.4f .. %.4f  x %.3f .. %.3f', dbb.min.z, dbb.max.z, dbb.min.x, dbb.max.x)
fb0 = wbox.call(inst)
puts format('foam BEFORE world z %.4f .. %.4f  x %.3f .. %.3f  y %.3f .. %.3f', fb0.min.z, fb0.max.z, fb0.min.x, fb0.max.x, fb0.min.y, fb0.max.y)
shared = inst.definition.instances.length
m.start_operation('WR concept: trim foam on the desk wall', true)
begin
  inst.make_unique
  d = inst.definition
  d.name = 'Foam (desk wall, trimmed)'
  t = bt * inst.transformation
  ti = t.inverse
  p = Geom::Point3d.new((fb0.min.x + fb0.max.x) / 2.0, (fb0.min.y + fb0.max.y) / 2.0, zc).transform(ti)
  n = Z_AXIS.transform(ti)
  n.normalize!
  u = n.axes[0]
  w = n.axes[1]
  big = 400.0
  corners = [[1, 1], [-1, 1], [-1, -1], [1, -1]].map do |a, b|
    p.offset(Geom::Vector3d.new(u.x * a * big + w.x * b * big, u.y * a * big + w.y * b * big,
                                u.z * a * big + w.z * b * big))
  end
  tmp = d.entities.add_group
  tmp.entities.add_face(corners)
  ident = Geom::Transformation.new
  d.entities.intersect_with(false, ident, d.entities, ident, true, [tmp])
  tmp.erase!
  eps = 0.001
  dist = lambda { |v| (v.position - p).dot(n) }
  below = d.entities.grep(Sketchup::Face).select do |f|
    ds = f.vertices.map { |v| dist.call(v) }
    ds.max <= eps && ds.min < -eps
  end
  d.entities.erase_entities(below) unless below.empty?
  loose = d.entities.grep(Sketchup::Edge).select do |e|
    e.faces.empty? && e.vertices.all? { |v| dist.call(v) < eps } &&
      !e.vertices.all? { |v| dist.call(v).abs < eps }
  end
  d.entities.erase_entities(loose) unless loose.empty?
  on_plane = d.entities.grep(Sketchup::Edge).select { |e| e.vertices.all? { |v| dist.call(v).abs < eps } }
  before_faces = d.entities.grep(Sketchup::Face).length
  on_plane.each { |e| e.find_faces if e.valid? }
  foam_mat = m.materials['[Color_I06]']
  caps = d.entities.grep(Sketchup::Face).select { |f| f.vertices.all? { |v| dist.call(v).abs < eps } }
  caps.each do |f|
    f.reverse! if f.normal.dot(n) > 0
    f.material = foam_mat
  end
  m.commit_operation
  puts "made unique (definition was shared by #{shared}); now '#{d.name}' x#{d.instances.length}; the other #{shared - 1} sheets keep 'Foam'"
  puts "cut: #{below.length} faces below the plane erased, #{loose.length} loose edges erased, #{on_plane.length} section edges, #{caps.length} cap face(s) (faces #{before_faces} -> #{d.entities.grep(Sketchup::Face).length})"
rescue Exception
  m.abort_operation
  raise
end
fb = wbox.call(inst)
puts format('foam AFTER  world z %.4f .. %.4f  x %.3f .. %.3f  y %.3f .. %.3f', fb.min.z, fb.max.z, fb.min.x, fb.max.x, fb.min.y, fb.max.y)
# overlap check against every desk part (world boxes of the desk's children)
dt = bt * desk.transformation
hits = []
desk.definition.entities.each do |c|
  next unless c.respond_to?(:bounds) && (c.is_a?(Sketchup::Group) || c.is_a?(Sketchup::ComponentInstance) || c.is_a?(Sketchup::Face))
  cb = Geom::BoundingBox.new
  8.times { |k| cb.add(c.bounds.corner(k).transform(dt)) }
  ox = [fb.max.x, cb.max.x].min - [fb.min.x, cb.min.x].max
  oy = [fb.max.y, cb.max.y].min - [fb.min.y, cb.min.y].max
  oz = [fb.max.z, cb.max.z].min - [fb.min.z, cb.min.z].max
  hits << format('%s (%.3f x %.3f x %.3f)', (c.respond_to?(:definition) ? c.definition.name : c.class.name), ox, oy, oz) if ox > 0.001 && oy > 0.001 && oz > 0.001
end
puts "desk parts overlapping the trimmed foam volume: #{hits.empty? ? 'NONE' : hits.join('; ')}"
[inst.definition.name, fb.min.z.to_f.round(4), zc.round(4)]
