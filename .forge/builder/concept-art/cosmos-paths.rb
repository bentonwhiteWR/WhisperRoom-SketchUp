sc = VRay::Context.active.scene
m = Sketchup.active_model
['Chair Lounge 009', 'Sofa Sectional 001', 'Table Coffee 001', 'Indoor Plant 004', 'Indoor Plant 007',
 'Zody Executive 4D Arms Metal Base', 'Lyft Single Desk', 'Lamp Floor 16-45', 'Lamp Ceiling 35-59'].each do |n|
  p = sc["/#{n}"]
  if p.nil?
    puts "#{n}: NO PLUGIN"
    next
  end
  paths = (p[:resolve_paths] rescue []) || []
  miss = paths.reject { |f| File.exist?(f) }
  d = m.definitions[n]
  b = d.bounds
  puts "#{n}: #{paths.length} files, #{miss.length} missing#{miss.empty? ? '' : ' e.g. ' + miss.first.to_s[-80..-1].to_s}; defbox x#{b.min.x.to_f.round(1)}..#{b.max.x.to_f.round(1)} y#{b.min.y.to_f.round(1)}..#{b.max.y.to_f.round(1)} z#{b.min.z.to_f.round(1)}..#{b.max.z.to_f.round(1)}"
end
:ok
