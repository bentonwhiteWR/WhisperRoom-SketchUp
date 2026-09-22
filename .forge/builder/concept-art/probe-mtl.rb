sc = VRay::Context.active.scene
sc.each do |p|
  next unless p.category.to_s == 'material'
  line = "MTL #{p.name} [#{p.type}]"
  if p.type.to_s == 'MtlSingleBRDF'
    b = (p[:brdf] rescue nil)
    if b.is_a?(VRay::Scene::Plugin)
      vals = []
      [:diffuse, :reflect, :reflect_glossiness, :fresnel, :fresnel_ior, :bump_map, :opacity, :refract, :coat_amount, :sheen_color].each do |k|
        v = (b[k] rescue '?')
        v = v.is_a?(VRay::Scene::Plugin) ? "plg(#{v.type})" : (v.respond_to?(:r) ? format('(%.2f,%.2f,%.2f)', v.r, v.g, v.b) : v.inspect[0, 40])
        vals << "#{k}=#{v}"
      end
      line += ' ' + vals.join(' ')
    end
  end
  puts line
end
m = Sketchup.active_model
room = m.entities.find { |e| e.respond_to?(:name) && e.name == 'Room' }
room.definition.entities.each do |e|
  next unless e.respond_to?(:bounds)
  dn = e.respond_to?(:definition) ? e.definition.name : ''
  puts "ROOM child #{e.class.name.split('::').last} #{(e.name rescue '').inspect} def=#{dn.inspect} layer=#{e.layer.name} mat=#{e.material ? e.material.name : nil}" unless e.is_a?(Sketchup::Edge) || e.is_a?(Sketchup::Face)
end
puts "ROOM faces=#{room.definition.entities.grep(Sketchup::Face).length}"
m.definitions.each { |d| puts "DEF #{d.name} inst=#{d.instances.length} img=#{d.image?} faces=#{d.entities.grep(Sketchup::Face).length}" if d.instances.length > 0 && !(d.name =~ /Panel|Seal|FL|CL|STDSS|Foam/) }
:ok
