m = Sketchup.active_model
b = m.entities.find { |e| e.persistent_id == m.get_attribute('WalshRM', 'booth_pid') }
bad = m.entities.find { |e| e.persistent_id == m.get_attribute('WalshRM', 'bad_booth_pid') }
puts "new #{b.name} pid #{b.persistent_id} layer #{b.layer.name} | bad #{bad.name} layer #{bad.layer.name} vis #{bad.layer.visible?}"
rows = []
b.entities.each do |c|
  next unless c.respond_to?(:definition)
  tok = c.name.split(' ').first.to_s
  next unless tok =~ /\A[NSEW]\d\z/
  bb = c.bounds
  rows << format('  %-4s %-34s %-30s x %7.2f..%7.2f  y %6.2f..%6.2f', tok, c.name[0, 34], c.definition.name[0, 30], bb.min.x, bb.max.x, bb.min.y, bb.max.y)
end
puts rows.sort
puts "top-level children: #{b.entities.grep(Sketchup::ComponentInstance).size + b.entities.grep(Sketchup::Group).size}"
