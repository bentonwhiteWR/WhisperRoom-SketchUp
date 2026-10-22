m = Sketchup.active_model
def walk(ents, path, out, depth = 0)
  ents.each do |e|
    next unless e.respond_to?(:layer)
    out[e.layer.name] << path if %w[WR-Room-New WR-Obstruction WR-Ceiling Walsh\ Assembly].include?(e.layer.name)
    walk(e.definition.entities, path, out, depth + 1) if depth < 6 && (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance))
  end
end
[3442119, 3442662, 3426776].each do |pid|
  g = m.entities.find { |e| e.persistent_id == pid }
  out = Hash.new { |h, k| h[k] = [] }
  walk(g.definition.entities, g.name, out)
  puts "#{g.name}: " + out.map { |k, v| "#{k}=#{v.size}" }.join(', ')
end
true
