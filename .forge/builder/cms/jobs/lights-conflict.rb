# READ-ONLY: light instances per V-Ray light definition, positions (duplicates), orphan plugins, tag + hidden.
m = Sketchup.active_model
sc = VRay::Context.active.scene
lt = m.layers['WR Lights']
defs = m.definitions.select { |d| (d.attribute_dictionary('VRayPlugins').keys rescue []).any? }
rows = []
defs.each do |d|
  pn = d.attribute_dictionary('VRayPlugins').keys.first
  inst = d.instances
  inst.each do |i|
    wt = i.transformation
    par = i.parent
    ptr = Geom::Transformation.new
    if par.respond_to?(:instances) && par.instances.size >= 1
      ptr = par.instances.first.transformation
    end
    o = (ptr * wt).origin
    rows << [pn, d.name, par.respond_to?(:name) ? par.name : 'MODEL', o.to_a.map { |x| x.to_f.round(1) }, i.hidden?, i.layer.name, i.get_attribute('wr_cms_lights', 'name')]
  end
end
by_pos = rows.group_by { |r| r[3] }.select { |_, v| v.size > 1 }.map { |pos, v| [pos, v.map { |r| [r[0], r[6]] }] }
plugin_names = []
sc.each { |p| plugin_names << p.name if p.category.to_s =~ /light/i }
with_def = defs.map { |d| d.attribute_dictionary('VRayPlugins').keys.first }
orph_plugins = plugin_names - with_def - ['/SunLight']
defs_no_inst = defs.select { |d| d.instances.empty? }.map(&:name)
mine = m.entities.select { |e| e.get_attribute('wr_cms_lights', 'plugin') }
{ 'defs' => defs.size, 'instances' => rows.size, 'per_def_gt1' => defs.select { |d| d.instances.size > 1 }.map { |d| [d.name, d.instances.size] },
  'duplicate_positions' => by_pos, 'plugins' => plugin_names.size, 'plugins_without_def' => orph_plugins, 'defs_without_instances' => defs_no_inst,
  'my_names' => mine.map { |e| e.get_attribute('wr_cms_lights', 'name') }.tally.select { |_, n| n > 1 }, 'my_count' => mine.size,
  'hidden_lights' => rows.select { |r| r[4] }.map { |r| [r[0], r[6]] }, 'tag_visible' => lt.visible?,
  'pages_hiding_tag' => m.pages.select { |p| p.use_hidden_layers? && p.layers.include?(lt) }.map(&:name),
  'wr_mode' => (m.attribute_dictionary('WR_Mode') && m.attribute_dictionary('WR_Mode')['current']),
  'selected' => m.pages.selected_page && m.pages.selected_page.name, 'modified' => m.modified? }
