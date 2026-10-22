m = Sketchup.active_model
g = m.find_entity_by_persistent_id(3442566); puts "path parents: #{g.parent.respond_to?(:name) ? g.parent.name : g.parent.class}"
puts "ceiling grp mat=#{g.material&.display_name.inspect} layer=#{g.layer.name}"
g.definition.entities.grep(Sketchup::Face).each { |f| puts "  face n=#{f.normal.to_a.map{|v|v.round(2)}} front=#{f.material&.display_name.inspect} back=#{f.back_material&.display_name.inspect} col=#{(f.material||f.back_material)&.color&.to_a.inspect}" }
puts "default face color=#{m.rendering_options['FaceFrontColor'].to_a} back=#{m.rendering_options['FaceBackColor'].to_a}"
true
