m = Sketchup.active_model
tgt = m.materials['[Color_I06]']
users = Hash.new(0)
m.definitions.each do |d|
  d.entities.each do |e|
    if (e.is_a?(Sketchup::Face) && (e.material == tgt || e.back_material == tgt)) ||
       ((e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.material == tgt)
      users[d.name] += 1
    end
  end
end
puts "Color_I06 users: #{users.inspect}"
sc = VRay::Context.active.scene
p = sc['/Standard Light']
p.each { |k, v, *_| puts "  #{k} = #{v.respond_to?(:r) ? format('(%.3f,%.3f,%.3f)', v.r, v.g, v.b) : v.inspect[0, 90]}" }
:ok
