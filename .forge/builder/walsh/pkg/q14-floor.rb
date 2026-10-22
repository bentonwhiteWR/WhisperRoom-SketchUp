m = Sketchup.active_model
room = m.entities.find { |e| e.persistent_id == 3442119 }
fl = room.definition.entities.find { |e| e.respond_to?(:name) && e.name == 'Floor' }
fl.definition.entities.grep(Sketchup::Face).each { |f| puts "floor face area=#{f.area.round} n=#{f.normal.z.round} mat=#{f.material && f.material.name} back=#{f.back_material && f.back_material.name}" }
walls = room.definition.entities.find { |e| e.respond_to?(:name) && e.name == 'Walls' }
h = Hash.new(0); walls.definition.entities.each { |e| h[e.typename + ':' + (e.respond_to?(:material) && e.material ? e.material.name : 'nil')] += 1 }
puts h.inspect
puts "PlaneWR? #{m.materials.map(&:name).grep(/0128|White|floor/i).inspect}"
true
