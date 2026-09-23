m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
bt = b.transformation; bi = bt.inverse
sel = b.definition.entities.grep(Sketchup::ComponentInstance).select { |e| e.name =~ /^Audimute/ || e.definition.name == 'Foam' }
raise "found #{sel.length}, expected 25" unless sel.length == 25
m.start_operation('Lower acoustic panels 1 in', true)
sel.each { |e| e.transform!(bi * Geom::Transformation.translation([0, 0, -1]) * bt) }
m.commit_operation
zs = sel.map { |e| bb = Geom::BoundingBox.new; (0..7).each { |k| bb.add(e.definition.bounds.corner(k).transform(bt * e.transformation)) }; bb }
puts format('highest top now %.2f (ceiling 81.56), lowest bottom %.2f (raised floor 4.06)', zs.map { |x| x.max.z }.max, zs.map { |x| x.min.z }.min)
nil
