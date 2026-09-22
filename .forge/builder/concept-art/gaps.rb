# Booth-to-wall gaps measured from GEOMETRY (the walls' own world boxes), what
# sits in them, and the trimmed foam vs the desk. Read-only.
m = Sketchup.active_model
booth = m.entities.find { |e| e.respond_to?(:name) && e.name =~ /\AMDL 96120/ }
b = booth.bounds
loft = m.entities.find { |e| e.is_a?(Sketchup::Group) && e.name == 'Loft' }
walls = loft.entities.find { |c| c.is_a?(Sketchup::Group) && c.name == 'Walls' }
tr = loft.transformation * walls.transformation
wbox = lambda do |ent, t|
  bb = Geom::BoundingBox.new
  8.times { |k| bb.add(ent.bounds.corner(k).transform(t)) }
  bb
end
w1 = wbox.call(walls.entities.find { |g| g.name == 'Wall 1' }, tr)
w4 = wbox.call(walls.entities.find { |g| g.name == 'Wall 4' }, tr)
ng = w1.min.y - b.max.y
wg = b.min.x - w4.max.x
puts format('booth x %.3f..%.3f y %.3f..%.3f (ramp incl.)', b.min.x, b.max.x, b.min.y, b.max.y)
puts format('NORTH gap: wall 1 interior face y %.3f - booth north face y %.3f = %.3f in', w1.min.y, b.max.y, ng)
puts format('WEST gap:  booth west face x %.3f - wall 4 interior face x %.3f = %.3f in', b.min.x, w4.max.x, wg)
# anything (top-level, visible, not lights/booth/room/ground) in either gap
zones = { 'north gap' => [b.min.x, b.max.y, b.max.x, w1.min.y], 'west gap' => [w4.max.x, b.min.y, b.min.x, b.max.y] }
hits = []
m.entities.each do |e|
  next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
  next if e == booth || e == loft || e.name == 'Exterior ground' || e.layer.name == 'WR Lights' || !e.visible?
  eb = e.bounds
  zones.each do |zn, (x0, y0, x1, y1)|
    ox = [eb.max.x, x1].min - [eb.min.x, x0].max
    oy = [eb.max.y, y1].min - [eb.min.y, y0].max
    hits << "#{e.name.empty? ? e.definition.name : e.name} in #{zn}" if ox > 0.01 && oy > 0.01
  end
end
walls.entities.grep(Sketchup::Group).each do |p|
  next if p.name =~ /\AWall [14]\z/ || p.name == 'Ceiling'
  eb = wbox.call(p, tr)
  zones.each do |zn, (x0, y0, x1, y1)|
    ox = [eb.max.x, x1].min - [eb.min.x, x0].max
    oy = [eb.max.y, y1].min - [eb.min.y, y0].max
    hits << "#{p.name} in #{zn}" if ox > 0.01 && oy > 0.01
  end
end
puts "IN THE GAPS: #{hits.empty? ? 'nothing' : hits.join('; ')}"
# door approach: floor in front of the ramp to the south wall
w3 = wbox.call(walls.entities.find { |g| g.name == 'Wall 3' }, tr)
puts format('door/ramp side: %.1f in of floor from the ramp end to the south wall', b.min.y - w3.max.y)
# trimmed foam vs desk, after the move
bt = booth.transformation
f = m.find_entity_by_persistent_id(3122476)
d = m.find_entity_by_persistent_id(3122480)
fb = wbox.call(f, bt)
dt = bt * d.transformation
over = []
d.definition.entities.each do |c|
  next unless c.is_a?(Sketchup::Group) || c.is_a?(Sketchup::ComponentInstance) || c.is_a?(Sketchup::Face)
  cb = Geom::BoundingBox.new
  8.times { |k| cb.add(c.bounds.corner(k).transform(dt)) }
  ox = [fb.max.x, cb.max.x].min - [fb.min.x, cb.min.x].max
  oy = [fb.max.y, cb.max.y].min - [fb.min.y, cb.min.y].max
  oz = [fb.max.z, cb.max.z].min - [fb.min.z, cb.min.z].max
  over << c.to_s if ox > 0.001 && oy > 0.001 && oz > 0.001
end
db = wbox.call(d, bt)
puts format('foam "%s" z %.4f..%.4f; desk top z %.4f; desk parts overlapping: %s', f.definition.name, fb.min.z, fb.max.z, db.max.z, over.empty? ? 'NONE' : over.join(', '))
:ok
