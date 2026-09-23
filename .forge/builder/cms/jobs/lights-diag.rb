# READ-ONLY light diagnosis.
m = Sketchup.active_model
sc = VRay::Context.active.scene
lt = m.layers['WR Lights']
d = m.attribute_dictionary('WR_Mode')
plugins = []
sc.each { |p| plugins << [p.name, p.type.to_s, (p[:intensity] rescue nil), (p[:enabled] rescue nil), (p[:invisible] rescue nil)] if p.category.to_s =~ /light/i }
mine = m.entities.select { |e| e.get_attribute('wr_cms_lights', 'plugin') }
b = m.entities.find { |e| e.respond_to?(:name) && e.name == 'MDL 96144 E (components)' }
sl = b.definition.entities.select { |e| e.respond_to?(:definition) && e.definition.name == 'Component#127' }
booth_std = b.definition.entities.select { |e| e.respond_to?(:definition) && e.definition.name =~ /Standard Light/ }
{ 'wr_mode_current' => (d && d['current']), 'wr_lights_tag_visible' => lt && lt.visible?,
  'pages_hiding_wr_lights' => m.pages.select { |p| p.use_hidden_layers? && p.layers.include?(lt) }.map(&:name).size,
  'pages_showing_wr_lights' => m.pages.select { |p| p.use_hidden_layers? && !p.layers.include?(lt) }.map(&:name),
  'pages_no_tag_state' => m.pages.reject(&:use_hidden_layers?).map(&:name),
  'my_instances' => mine.size, 'my_hidden' => mine.count(&:hidden?), 'my_layers' => mine.map { |e| e.layer.name }.tally,
  'my_plugins_present' => mine.count { |e| sc[e.get_attribute('wr_cms_lights', 'plugin')] },
  'rect9_11' => ['/Rectangle Light#9', '/Rectangle Light#11'].map { |n| [n, sc[n] && sc[n][:intensity]] },
  'studio_light_instances' => sl.size, 'studio_hidden' => sl.count(&:hidden?), 'studio_layer' => sl.map { |e| e.layer.name }.uniq,
  'studio_sphere_def' => (m.definitions['Sphere Light#8'] ? m.definitions['Sphere Light#8'].instances.size : nil),
  'booth_standard_lights' => booth_std.map { |e| [e.layer.name, e.hidden?] },
  'vray_light_plugins' => plugins.size, 'plugins' => plugins.map { |x| x[0..2] } }
