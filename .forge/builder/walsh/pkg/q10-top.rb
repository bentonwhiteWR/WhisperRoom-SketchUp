m = Sketchup.active_model
m.entities.each do |e|
  next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
  vis = e.layer.visible? && !e.hidden?
  b = e.bounds
  puts "#{vis ? 'VIS ' : 'hid '} pid=#{e.persistent_id} #{e.typename} #{(e.name.empty? ? e.definition.name : e.name)[0,60].inspect} tag=#{e.layer.name} bb=#{b.min.to_a.map(&:round)}-#{b.max.to_a.map(&:round)}"
end
h = Hash.new(0); m.entities.each { |e| h["#{e.typename}/#{e.layer.name}/#{e.layer.visible? && !e.hidden?}"] += 1 unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
puts h.inspect
puts "active_path=#{m.active_path.inspect} modified=#{m.modified?}"
true
