m = Sketchup.active_model
sc = VRay::Context.active.scene
b = $wr_ca_before
puts "wrappers: #{$wr_ca_wrappers.inspect}"
new_defs = m.definitions.reject { |d| b['defs'].include?(d.name) }
puts "new definitions: #{new_defs.length}; new materials: #{m.materials.count { |x| !b['mats'].include?(x.name) }}"
new_defs.each do |d|
  mp = d.get_attribute('VRayInfo', 'main_plugin')
  next if mp.nil?
  puts "  VRAY DEF #{d.name.inspect} class=#{d.get_attribute('VRayInfo', 'class')} plugin=#{mp} inst=#{d.instances.length} bbox=#{d.bounds.width.to_f.round(1)}x#{d.bounds.height.to_f.round(1)}x#{d.bounds.depth.to_f.round(1)}"
end
after = []
sc.each { |p| after << "#{p.name}(#{p.type})" if p.category.to_s =~ /light|geometry/ && !b['plugs'].include?(p.name) }
puts "new light/geometry plugins: #{after.inspect}"
sl = sc['/Standard Light']
puts "/Standard Light valid=#{sl && sl.valid?} int=#{sl && sl[:intensity]}"
:ok
