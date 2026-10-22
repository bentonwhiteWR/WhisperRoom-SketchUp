m = Sketchup.active_model
g = m.find_entity_by_persistent_id(3442566)
p = g.parent
inst = p.instances
inst.each { |i| puts "parent inst #{i.name.inspect} pid=#{i.persistent_id} mat=#{i.material&.display_name.inspect} layer=#{i.layer.name}" }
r = m.find_entity_by_persistent_id(3442119)
puts "room #{r.name} mat=#{r.material&.display_name.inspect}"
mats = Hash.new(0); r.definition.entities.each { |e| mats[[e.class.name, e.respond_to?(:material) ? e.material&.display_name : nil]] += 1 }
p mats
true
