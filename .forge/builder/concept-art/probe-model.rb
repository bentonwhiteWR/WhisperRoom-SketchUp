# Read-only: describe the live model top level + booth group children.
m = Sketchup.active_model
puts "title=#{m.title.inspect} path=#{m.path.inspect} modified=#{m.modified?}"
puts "units=#{m.options['UnitsOptions']['LengthFormat']}"
m.entities.each do |e|
  next unless e.respond_to?(:bounds)
  nm = e.respond_to?(:name) ? e.name : ''
  dn = e.respond_to?(:definition) ? e.definition.name : ''
  b = e.bounds
  puts "TOP #{e.class.name.split('::').last} name=#{nm.inspect} def=#{dn.inspect} layer=#{e.layer.name} min=#{b.min.to_a.map{|v| v.to_f.round(2)}} max=#{b.max.to_a.map{|v| v.to_f.round(2)}}"
end
g = m.entities.find { |e| e.respond_to?(:name) && e.name =~ /96120/ }
if g
  ents = g.respond_to?(:definition) ? g.definition.entities : g.entities
  puts "BOOTH children=#{ents.length}"
  ents.each do |c|
    next unless c.respond_to?(:definition) || c.is_a?(Sketchup::Group)
    dn = c.respond_to?(:definition) ? c.definition.name : ''
    b = c.bounds
    puts "  #{c.class.name.split('::').last} name=#{c.name.inspect} def=#{dn.inspect} layer=#{c.layer.name} vis=#{c.visible?} min=#{b.min.to_a.map{|v| v.to_f.round(1)}} max=#{b.max.to_a.map{|v| v.to_f.round(1)}}"
  end
end
puts "pages=#{m.pages.map(&:name).inspect}"
puts "layers=#{m.layers.map{|l| "#{l.name}:#{l.visible?}"}.inspect}"
puts "materials=#{m.materials.length}"
:ok
