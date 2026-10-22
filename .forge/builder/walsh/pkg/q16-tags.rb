# Read-only: per-scene tag visibility + ceiling/floor state of the v3 room.
m = Sketchup.active_model
room = m.entities.find { |e| e.persistent_id == 3442119 }
ceil = room.definition.entities.find { |e| e.respond_to?(:name) && e.name.start_with?('Ceiling') }
flr  = room.definition.entities.find { |e| e.respond_to?(:name) && e.name == 'Floor' }
[ceil, flr].each do |g|
  puts "#{g.name} #{g.typename} tag=#{g.layer.name} hid=#{g.hidden?} pid=#{g.persistent_id}"
  g.definition.entities.grep(Sketchup::Face).each { |f| puts "   face n=#{f.normal.to_a.map { |x| x.round(2) }} z=#{f.bounds.min.z.round} area=#{(f.area/144).round}sf mat=#{f.material&.name} back=#{f.back_material&.name} tag=#{f.layer.name} hid=#{f.hidden?}" }
  g.definition.entities.grep(Sketchup::Group).each { |s| puts "   sub #{s.name} tag=#{s.layer.name} hid=#{s.hidden?}" }
end
pre = 'Booth - MDL 96168 S RM (21 Oct link) '
names = %w[WR-Ceiling WR-Room WR-Floor WR-Room-New]
puts "global: " + names.map { |n| l = m.layers[n]; "#{n}=#{l ? l.visible? : 'none'}" }.join(' ')
m.pages.each do |p|
  hl = (p.layers || []).map(&:name)
  puts "#{p.name.sub(pre,'')}: page-hidden tags=#{hl.inspect}"
end
puts "vray env? " + (m.attribute_dictionaries ? m.attribute_dictionaries.map(&:name).grep(/vray|VRay/i).inspect : '-')
true
