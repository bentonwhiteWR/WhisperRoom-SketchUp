# Read-only: every dimension in the RM dims group: id, tag, value, ends (model space), offset.
m = Sketchup.active_model
g = m.entities.grep(Sketchup::Group).find { |x| x.persistent_id == 3442717 }
t = g.transformation
puts "group origin #{t.origin.to_a.map(&:round)} identity=#{t.identity?}"
g.entities.grep(Sketchup::DimensionLinear).each do |d|
  s = d.start[1].transform(t); e = d.end[1].transform(t)
  ov = d.offset_vector
  puts format('%-8d %-16s %-14s s=%-18s e=%-18s off=%-18s tp=%s', d.persistent_id, d.layer.name, (d.text.empty? ? Sketchup.format_length(s.distance(e)) : d.text), s.to_a.map(&:round).inspect, e.to_a.map(&:round).inspect, ov.to_a.map(&:round).inspect, d.text_position)
end
true
