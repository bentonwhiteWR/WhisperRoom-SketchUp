sc = VRay::Context.active.scene
s = sc['/SunLight']
t = s[:transform]
m = t.matrix rescue nil
fmtv = lambda { |v| v.respond_to?(:x) ? format('(%.3f,%.3f,%.3f)', v.x, v.y, v.z) : v.inspect[0, 80] }
puts "enabled=#{s[:enabled]} mult=#{s[:intensity_multiplier]} invisible=#{s[:invisible]} custom_orient=#{s[:use_custom_orientation]}"
if m
  puts "transform rows: #{[m[0], m[1], m[2]].map { |r| fmtv.call(r) }.join(' ')}  offset #{fmtv.call(t.offset)}"
else
  puts "transform: #{t.inspect[0, 300]}"
end
tt = s[:target_transform]
puts "target_transform: #{tt.inspect[0, 300]}"
d = Sketchup.active_model.shadow_info['SunDirection']
puts "SketchUp SunDirection #{fmtv.call(d)}  shadows=#{Sketchup.active_model.shadow_info['DisplayShadows']}"
puts "methods on transform: #{(t.public_methods - Object.public_methods).first(20).inspect}"
:ok
