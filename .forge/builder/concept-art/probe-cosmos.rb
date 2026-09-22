sc = VRay::Context.active.scene
sc.each do |p|
  next unless p.type.to_s == 'CosmosAsset'
  puts "PLUGIN #{p.name}"
  p.each { |k, v, *_| puts "   #{k} = #{v.inspect[0, 200]}" }
  p.each_parent({}) { |q| puts "   parent #{q.name} #{q.type}" } rescue puts("   parents: #{$!}")
end
m = Sketchup.active_model
m.definitions.each do |d|
  dicts = (d.attribute_dictionaries || []).map(&:name)
  if dicts.any? { |n| n =~ /vray|cosmos/i }
    puts "DEF #{d.name.inspect} inst=#{d.instances.length} dicts=#{dicts.inspect} faces=#{d.entities.grep(Sketchup::Face).length}"
    (d.attribute_dictionaries || []).each do |ad|
      next unless ad.name =~ /vray|cosmos/i
      ad.each_pair { |k, v| puts "     #{ad.name}.#{k} = #{v.to_s[0, 300]}" }
    end
  end
end
:ok
