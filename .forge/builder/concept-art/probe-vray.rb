sc = VRay::Context.active.scene
cats = Hash.new(0)
sc.each { |p| cats["#{p.category}/#{p.type}"] += 1 }
puts "PLUGIN TYPES: #{cats.sort.map { |k, v| "#{k}=#{v}" }.join(' ')}"
names = ['/SettingsOutput', '/CameraPhysical', '/SunLight', '/SettingsEnvironment', '/Environment Sky',
         '/SettingsImageSampler', '/SettingsColorMapping', '/SettingsGI', '/SettingsLightCache', '/RenderChannelDenoiser']
names.each do |n|
  p = (sc[n] rescue nil)
  if p.nil?
    puts "#{n}: nil"
    next
  end
  keys = []
  p.each { |k, v, *_| keys << "#{k}=#{v.inspect[0, 60]}" }
  puts "#{n} [#{p.type}]: #{keys.join(' | ')[0, 1800]}"
end
sc.each do |p|
  next unless p.category.to_s =~ /light/i
  puts "LIGHT #{p.name} #{p.type} en=#{(p[:enabled] rescue '?')} int=#{(p[:intensity] rescue '?')}"
end
:ok
