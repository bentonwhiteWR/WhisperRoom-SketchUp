# Walsh corner-platform: read-only survey of the open model.
m = Sketchup.active_model
out = []
out << "path=#{m.path} modified=#{m.modified?}"
out << "tags: " + m.layers.map { |l| "#{l.name}#{l.visible? ? '' : '(off)'}" }.join(', ')
m.entities.each do |e|
  next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
  bb = e.bounds
  nm = e.is_a?(Sketchup::Group) ? e.name : "#{e.name}<#{e.definition.name}>"
  t = e.transformation
  out << format('TOP %s | tag=%s hidden=%s | min %s max %s | xaxis %s origin %s', nm, e.layer.name, e.hidden?,
                bb.min.to_a.map { |v| v.to_f.round(2) }, bb.max.to_a.map { |v| v.to_f.round(2) },
                t.xaxis.to_a.map { |v| v.round(4) }, t.origin.to_a.map { |v| v.to_f.round(2) })
end
cnt = Hash.new(0)
m.entities.each { |e| cnt[[e.class.name.split('::').last, e.layer.name]] += 1 unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
out << "loose: #{cnt.map { |k, v| "#{k[0]}@#{k[1]}=#{v}" }.join(', ')}"
m.pages.each do |p|
  hid = p.layers.map(&:name) rescue []
  c = p.camera
  out << "SCENE #{p.name} | hidden tags=#{hid.join('/')} | eye #{c.eye.to_a.map { |v| v.to_f.round(1) }} tgt #{c.target.to_a.map { |v| v.to_f.round(1) }} persp=#{c.perspective?} | mode=#{p.get_attribute('WR_ProposalPackage', 'mode')}"
end
puts out.join("\n")
nil
