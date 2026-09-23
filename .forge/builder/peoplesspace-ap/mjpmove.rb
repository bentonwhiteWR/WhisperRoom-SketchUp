m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
m.start_operation('Seat MJP boxes on wall faces', true)
b.definition.entities.grep(Sketchup::ComponentInstance).each do |i|
  d = { 'MJP interior (window wall)' => -1.5, 'MJP exterior (window wall)' => 0.75 }[i.name]
  i.transform!(Geom::Transformation.translation([0, d, 0])) if d
end
m.commit_operation
nil
