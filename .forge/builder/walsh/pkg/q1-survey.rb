m = Sketchup.active_model
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb' unless defined?(WR_ProposalPackage)
puts "path #{m.path} modified=#{m.modified?}"
m.pages.each_with_index do |p, i|
  st = p.attribute_dictionary('WR_AutoSet')
  cam = p.camera
  puts format('%2d %-55s mode=%-6s stamp=%s cam=%s', i, p.name, WR_ProposalPackage.mode_of(p),
              st ? "#{st['token']}|#{st['plate']}" : '-', cam ? (cam.perspective? ? "p#{cam.fov.round}" : 'ortho') : '-')
end
puts '--- tags'
m.layers.each { |l| puts "  #{l.name} vis=#{l.visible?} n=#{0}" }
puts '--- top-level'
m.entities.each do |e|
  next unless e.respond_to?(:layer)
  nm = (e.respond_to?(:name) ? e.name : '') rescue ''
  dn = e.respond_to?(:definition) ? e.definition.name : ''
  b = e.bounds
  puts format('  %-14s %-40s def=%-30s tag=%-30s hid=%s pid=%s bb=[%.0f,%.0f,%.0f]-[%.0f,%.0f,%.0f]', e.typename, nm.to_s[0,40], dn.to_s[0,30], e.layer.name[0,30], e.hidden?, e.persistent_id, b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z) unless e.is_a?(Sketchup::Edge) || e.is_a?(Sketchup::Face)
end
puts "edges=#{m.entities.grep(Sketchup::Edge).size} faces=#{m.entities.grep(Sketchup::Face).size}"
puts "rendering: #{m.rendering_options.to_a.select { |k,_| k =~ /Edge|Background|Sky|Ground|Face|Fog|Light|Dark/ }.inspect}"
puts "shadow: #{m.shadow_info.to_a.inspect}"
puts "style: #{m.styles.selected_style.name}  styles=#{m.styles.map(&:name).inspect}"
puts "WalshRM attrs: #{(m.attribute_dictionary('WalshRM') || {}).to_a.inspect}"
true
