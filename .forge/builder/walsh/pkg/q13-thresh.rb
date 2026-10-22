m = Sketchup.active_model
room = m.entities.find { |e| e.persistent_id == 3442119 }
room.definition.entities.each do |e|
  next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::Face)
  if e.is_a?(Sketchup::Face)
    puts "room face z=#{e.bounds.min.z.round(1)} area=#{e.area.round} mat=#{e.material && e.material.display_name}"
  else
    puts "grp #{e.name} tag=#{e.layer.name} mat=#{e.material && e.material.display_name}"
  end
end
doors = room.definition.entities.find { |e| e.respond_to?(:name) && e.name == 'Doors' }
doors.definition.entities.grep(Sketchup::Group).each do |d|
  d.definition.entities.grep(Sketchup::Face).each do |f|
    b = f.bounds
    next unless b.max.z < 0.5
    puts "  #{d.name}: floor face pid=#{f.persistent_id} area=#{f.area.round} mat=#{f.material && f.material.display_name} back=#{f.back_material && f.back_material.display_name} normal=#{f.normal.to_a.map { |c| c.round(2) }} bb=#{b.min.to_a.map { |c| c.round(1) }}-#{b.max.to_a.map { |c| c.round(1) }}"
  end
end
fl = nil
room.definition.entities.each { |e| fl = e if e.respond_to?(:layer) && e.layer.name == 'WR-Floor' }
puts "floor ent: #{fl && fl.typename} #{fl && (fl.respond_to?(:material) && fl.material ? fl.material.display_name : '-')}"
true
