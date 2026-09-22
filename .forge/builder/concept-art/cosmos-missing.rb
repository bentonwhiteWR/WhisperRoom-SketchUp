sc = VRay::Context.active.scene
['Indoor Plant 004', 'Sofa Sectional 001', 'Table Coffee 001', 'Zody Executive 4D Arms Metal Base'].each do |n|
  p = sc['/' + n]
  miss = (p[:resolve_paths] || []).reject { |f| File.exist?(f) }
  puts n
  miss.each { |f| puts '   ' + f.tr(92.chr, '/').split('/')[-3..-1].join('/') }
end
:ok
