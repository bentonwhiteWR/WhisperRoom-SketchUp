m = Sketchup.active_model
m.materials.each do |mt|
  c = mt.color
  tx = mt.texture ? File.basename(mt.texture.filename.to_s) : '-'
  puts "MAT #{mt.name.inspect} rgb=#{[c.red,c.green,c.blue]} a=#{mt.alpha.round(2)} tex=#{tx}"
end
d = m.definitions['Foam']
if d
  mats = Hash.new(0)
  d.entities.grep(Sketchup::Face).each { |f| mats[f.material ? f.material.name : 'nil'] += 1 }
  puts "FOAM faces=#{d.entities.grep(Sketchup::Face).length} mats=#{mats.inspect} bounds=#{d.bounds.width.to_f.round(2)}x#{d.bounds.height.to_f.round(2)}x#{d.bounds.depth.to_f.round(2)}"
  g = m.entities.find { |e| e.respond_to?(:name) && e.name =~ /96120/ }
  g.definition.entities.each { |c| puts "  inst #{c.name} mat=#{c.material ? c.material.name : 'nil'}" if c.respond_to?(:definition) && c.definition.name == 'Foam' }
end
:ok
