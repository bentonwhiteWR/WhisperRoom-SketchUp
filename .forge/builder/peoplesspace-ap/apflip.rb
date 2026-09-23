m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
bt = b.transformation; bi = bt.inverse
wb = lambda { |e| bb = Geom::BoundingBox.new; (0..7).each { |k| bb.add(e.definition.bounds.corner(k).transform(bt * e.transformation)) }; bb }
ents = b.definition.entities.grep(Sketchup::ComponentInstance)
aud = ents.select { |e| e.name =~ /^Audimute/ }
foam = ents.select { |e| e.definition.name == 'Foam' && ((bb = wb.call(e)).min.x.between?(38.9, 39.1)) }
raise "aud=#{aud.length} foam=#{foam.length}" unless aud.length == 19 && foam.length == 2
m.start_operation('Flip Audimute + moved foam to face the room', true)
(aud + foam).each do |e|
  bb = wb.call(e); c = bb.center
  e.transform!(bi * Geom::Transformation.rotation(c, Z_AXIS, 180.degrees) * bt)
  a = wb.call(e)
  raise "#{e.name} moved #{c.distance(a.center)}" if c.distance(a.center) > 0.01 && e.definition.name == 'Foam'
end
m.commit_operation
nil
