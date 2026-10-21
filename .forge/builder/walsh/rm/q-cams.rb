m = Sketchup.active_model
m.pages.each do |p|
  c = p.camera
  puts "#{p.name} | mode=#{p.get_attribute('WR_ProposalPackage','mode')} persp=#{c.perspective?} eye=#{c.eye.to_a.map{|v|v.to_f.round(1)}} tgt=#{c.target.to_a.map{|v|v.to_f.round(1)}} fov=#{(c.fov rescue 0).round(1)} h=#{(c.height rescue 0).to_f.round(1)} ar=#{c.aspect_ratio}"
end
bb = Geom::BoundingBox.new
m.entities.each { |e| next unless e.respond_to?(:bounds); next if e.hidden? || !e.layer.visible?; puts "  vis top #{e.typename} #{e.name} layer=#{e.layer.name} bb=#{e.bounds.min.to_a.map{|v|v.to_f.round}}..#{e.bounds.max.to_a.map{|v|v.to_f.round}}" if e.is_a?(Sketchup::Group)||e.is_a?(Sketchup::ComponentInstance) }
