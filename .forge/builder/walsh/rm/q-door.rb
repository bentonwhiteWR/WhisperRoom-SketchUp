m = Sketchup.active_model
b = m.entities.find { |e| e.persistent_id == m.get_attribute('WalshRM', 'booth_pid') }
w1 = b.entities.find { |e| e.name.split(' ').first == 'W1' }
puts "W1 #{w1.definition.name}"
walk = lambda do |ents, tr, dep|
  ents.each do |e|
    next unless e.respond_to?(:definition)
    t = tr * e.transformation
    bb = Geom::BoundingBox.new
    (0..7).each { |i| bb.add(e.definition.bounds.corner(i).transform(t)) }
    puts format('%s%-30s %-24s x %6.2f..%6.2f y %6.2f..%6.2f z %6.2f..%6.2f', '  ' * dep, e.definition.name[0, 30], e.name[0, 24], bb.min.x, bb.max.x, bb.min.y, bb.max.y, bb.min.z, bb.max.z)
    walk.(e.definition.entities, t, dep + 1) if dep < 2
  end
end
walk.(w1.definition.entities, w1.transformation, 0)
