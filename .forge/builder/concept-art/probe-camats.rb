sc = VRay::Context.active.scene
fmt = lambda do |v|
  if v.is_a?(VRay::Scene::Plugin) then "plg(#{v.type})"
  elsif v.respond_to?(:r) then format('(%.2f,%.2f,%.2f)', v.r, v.g, v.b)
  else v.inspect[0, 40] end
end
['CA Plaster Warm White', 'CA Blackened Steel', 'CA Timber Beam', 'CA Oak Slat', 'CA Ceiling Charcoal', 'Color_I06', 'Oak Honey Semigloss 300cm'].each do |n|
  p = sc["/#{n}"]
  if p.nil?
    puts "#{n}: no plugin"
    next
  end
  line = "#{n} [#{p.type}]"
  b = (p[:brdf] rescue nil)
  if b.is_a?(VRay::Scene::Plugin)
    line += " brdf=#{b.type}"
    [:diffuse, :reflect, :reflect_glossiness, :option_use_roughness, :fresnel, :fresnel_ior, :bump_map, :metalness].each do |k|
      line += " #{k}=#{fmt.call(b[k]) rescue '?'}"
    end
  end
  puts line
end
:ok
