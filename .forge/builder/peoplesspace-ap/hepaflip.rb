m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
hs = b.definition.entities.grep(Sketchup::ComponentInstance).select { |e| e.name == 'HEPA (intake)' }
raise "expected 4 HEPAs, found #{hs.length}" unless hs.length == 4
m.start_operation('Flip HEPA filters 180', true)
hs.each do |h|
  before = h.bounds
  h.transform!(Geom::Transformation.rotation(h.bounds.center, Z_AXIS, 180.degrees))
  a = h.bounds
  puts format('moved %.3f  filter up? %s', before.center.distance(a.center), h.transformation.xaxis.z.round(3) == 1.0)
end
m.commit_operation
m.active_view.camera = Sketchup::Camera.new([130, 20, 116], [45, 90, 86], [0, 0, 1])
nil
