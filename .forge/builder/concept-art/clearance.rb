# 18 in clear band round the booth, measured from its outermost geometry
# (ADA ramp included) — Benton, 22 Sep 2026. Read-only.
m = Sketchup.active_model
booth = m.entities.find { |e| e.respond_to?(:name) && e.name =~ /\AMDL 96120/ }
b = booth.bounds
band = 18.0
puts format('booth world plan box x %.2f..%.2f  y %.2f..%.2f  top z %.2f', b.min.x, b.max.x, b.min.y, b.max.y, b.max.z)
items = []
wb = lambda do |ent, tr|
  bb = Geom::BoundingBox.new
  8.times { |k| bb.add(ent.bounds.corner(k).transform(tr)) }
  bb
end
m.entities.each do |e|
  next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
  next if e == booth || !e.visible? || e.layer.name == 'WR Lights'
  if e.is_a?(Sketchup::Group) && e.name == 'Loft'
    walls = e.entities.find { |c| c.is_a?(Sketchup::Group) && c.name == 'Walls' }
    walls.entities.grep(Sketchup::Group).each do |p|
      next if p.name == 'Ceiling'
      items << [p.name, wb.call(p, e.transformation * walls.transformation)]
    end
    next
  end
  next if e.name == 'Exterior ground'
  nm = e.name.empty? && e.respond_to?(:definition) ? e.definition.name : e.name
  items << [nm, e.bounds]
end
viol = []
near = { 'W' => [nil, 1e9], 'E' => [nil, 1e9], 'S' => [nil, 1e9], 'N' => [nil, 1e9] }
items.each do |nm, bb|
  next if bb.min.z > b.max.z                     # overhead, not floor-standing
  dx = [bb.min.x - b.max.x, b.min.x - b.max.x > 0 ? 0 : b.min.x - bb.max.x].max
  gx = bb.min.x >= b.max.x ? bb.min.x - b.max.x : (bb.max.x <= b.min.x ? b.min.x - bb.max.x : 0.0)
  gy = bb.min.y >= b.max.y ? bb.min.y - b.max.y : (bb.max.y <= b.min.y ? b.min.y - bb.max.y : 0.0)
  inside_band = gx < band && gy < band
  viol << format('%s (gap x %.1f, y %.1f)', nm, gx, gy) if inside_band
  # per-side nearest: objects facing that side (overlapping the band span on the other axis)
  if bb.max.y > b.min.y - band && bb.min.y < b.max.y + band
    near['W'] = [nm, b.min.x - bb.max.x] if bb.max.x <= b.min.x && b.min.x - bb.max.x < near['W'][1]
    near['E'] = [nm, bb.min.x - b.max.x] if bb.min.x >= b.max.x && bb.min.x - b.max.x < near['E'][1]
  end
  if bb.max.x > b.min.x - band && bb.min.x < b.max.x + band
    near['S'] = [nm, b.min.y - bb.max.y] if bb.max.y <= b.min.y && b.min.y - bb.max.y < near['S'][1]
    near['N'] = [nm, bb.min.y - b.max.y] if bb.min.y >= b.max.y && bb.min.y - b.max.y < near['N'][1]
  end
end
near.each { |side, (nm, d)| puts format('  %s side: nearest %-28s %.1f in clear', side, nm.inspect, d) }
puts "IN THE 18 in BAND: #{viol.empty? ? 'nothing' : viol.join('; ')}"
:ok
