# Write a scene revert record: every scene's name, flags, camera, stored tag state, hidden objects
# (by persistent_id + a readable path), package mode/ev, AUTO-SET stamp and wr_cms attrs.
# $cms_backup_path = output .json. Read-only on the model. Restore with jobs/scene-restore.rb.
require 'json'
m = Sketchup.active_model
pth = lambda do |e|
  names = []
  x = e
  8.times do
    break unless x.respond_to?(:parent)
    nm = (x.respond_to?(:name) && !x.name.to_s.empty?) ? x.name : (x.respond_to?(:definition) ? x.definition.name : x.class.to_s)
    names.unshift(nm)
    par = x.parent
    break if par.is_a?(Sketchup::Model) || par.nil?
    x = par.respond_to?(:instances) ? par.instances.first : nil
    break if x.nil?
  end
  names.join('/')
end
dict = ->(pg, dn) { d = pg.attribute_dictionary(dn); d ? d.keys.each_with_object({}) { |k, h| h[k] = d[k] } : nil }
rows = m.pages.map do |pg|
  c = pg.camera
  cam = { 'eye' => c.eye.to_a.map(&:to_f), 'target' => c.target.to_a.map(&:to_f), 'up' => c.up.to_a.map(&:to_f),
          'perspective' => c.perspective?, 'fov' => (c.fov rescue nil), 'aspect_ratio' => c.aspect_ratio,
          'fov_is_height' => (c.fov_is_height? rescue nil), 'height' => (c.perspective? ? nil : c.height.to_f) }
  hid = (pg.hidden_entities rescue nil) || []
  { 'name' => pg.name,
    'flags' => { 'use_camera' => pg.use_camera?, 'use_hidden_layers' => pg.use_hidden_layers?,
                 'use_hidden_objects' => (pg.use_hidden_objects? rescue nil), 'use_hidden_geometry' => (pg.use_hidden_geometry? rescue nil),
                 'use_rendering_options' => pg.use_rendering_options?, 'use_shadow_info' => pg.use_shadow_info?,
                 'use_axes' => pg.use_axes?, 'use_section_planes' => pg.use_section_planes? },
    'camera' => cam,
    'hidden_tags' => pg.use_hidden_layers? ? pg.layers.map(&:name).sort : nil,
    'hidden_entities' => hid.map { |e| { 'pid' => (e.persistent_id rescue nil), 'path' => pth.call(e), 'class' => e.class.to_s } },
    'WR_ProposalPackage' => dict.call(pg, 'WR_ProposalPackage'), 'WR_AutoSet' => dict.call(pg, 'WR_AutoSet'), 'wr_cms' => dict.call(pg, 'wr_cms') }
end
rec = { 'written' => Time.now.to_s, 'model' => m.path, 'selected_page' => (m.pages.selected_page && m.pages.selected_page.name),
        'global_tags' => m.layers.map { |l| [l.name, l.visible?] }.to_h,
        'wr_mode_current' => (m.attribute_dictionary('WR_Mode') && m.attribute_dictionary('WR_Mode')['current']),
        'scenes' => rows }
File.write($cms_backup_path, JSON.pretty_generate(rec))
{ 'written' => $cms_backup_path, 'scenes' => rows.size, 'bytes' => File.size($cms_backup_path) }
