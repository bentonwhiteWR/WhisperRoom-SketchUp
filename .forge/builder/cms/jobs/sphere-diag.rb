# READ-ONLY: every sphere-light instance at top level + any sphere-like geometry near the fill positions.
m = Sketchup.active_model
sc = VRay::Context.active.scene
rows = []
m.entities.each do |e|
  next unless e.respond_to?(:definition)
  d = e.definition
  vk = (d.attribute_dictionary('VRayPlugins').keys rescue [])
  next unless d.name =~ /Sphere Light/ || e.get_attribute('wr_cms_lights', 'name').to_s =~ /fill/
  pn = vk.first
  p = pn && sc[pn]
  js = pn ? (d.attribute_dictionary('VRayPlugins')[pn].to_s) : ''
  rows << { 'def' => d.name, 'name' => e.get_attribute('wr_cms_lights', 'name'), 'plugin' => pn, 'live' => !p.nil?,
            'type' => p && p.type.to_s, 'invisible' => p && p[:invisible], 'intensity' => p && p[:intensity], 'enabled' => p && (p[:enabled] rescue nil),
            'json_invisible' => js[/"invisible":"?(\w+)/, 1], 'json_class' => js[/"class":"(\w+)/, 1],
            'def_faces' => d.entities.grep(Sketchup::Face).size, 'def_children' => d.entities.count { |x| x.respond_to?(:definition) },
            'hidden' => e.hidden?, 'layer' => e.layer.name, 'at' => e.transformation.origin.to_a.map { |x| x.to_f.round(1) },
            'dups_at_pos' => m.entities.count { |o| o != e && o.respond_to?(:transformation) && o.transformation.origin.distance(e.transformation.origin) < 0.5 } }
end
rows
