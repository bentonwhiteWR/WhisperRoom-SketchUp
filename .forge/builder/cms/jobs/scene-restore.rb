# RESTORE scenes from a record written by jobs/scene-backup.rb.  $cms_restore_path = the .json.
#   $cms_restore_only = ['name', ...]  (optional) restore just these scenes
# For each recorded scene that still exists (matched by NAME): flags, camera, stored tag visibility
# (every tag not in hidden_tags is stored visible), hidden objects (entities found by persistent_id; the
# global hidden state is set, the page updated with PAGE_USE_HIDDEN_OBJECTS, then every touched entity is
# returned to visible), and the WR_ProposalPackage / WR_AutoSet / wr_cms attributes (keys absent from the
# record are deleted). Scenes NOT in the record (e.g. ones created after it) are left alone and listed; a
# recorded scene that no longer exists is listed as missing, never recreated silently.
require 'json'
m = Sketchup.active_model
v = m.active_view
rec = JSON.parse(File.read($cms_restore_path))
only = $cms_restore_only
ps = m.pages
m.options['PageOptions']['TransitionTime'] = 0.0
sel = ps.selected_page
out = { 'restored' => [], 'missing' => [], 'not_in_record' => ps.map(&:name) - rec['scenes'].map { |s| s['name'] }, 'unfound_entities' => 0 }
m.start_operation('CMS: restore scenes from record', true)
begin
  rec['scenes'].each do |s|
    next if only && !only.include?(s['name'])
    pg = ps[s['name']]
    if pg.nil?
      out['missing'] << s['name']
      next
    end
    c = s['camera']
    cam = Sketchup::Camera.new(Geom::Point3d.new(*c['eye']), Geom::Point3d.new(*c['target']), Geom::Vector3d.new(*c['up']))
    cam.perspective = c['perspective']
    if c['perspective']
      cam.aspect_ratio = c['aspect_ratio'].to_f if c['aspect_ratio'].to_f > 0
      cam.fov = c['fov'].to_f
    else
      cam.height = c['height'].to_f
    end
    ps.selected_page = pg
    v.camera = cam
    ents = (s['hidden_entities'] || []).map { |h| (m.find_entity_by_persistent_id(h['pid']) rescue nil) }
    out['unfound_entities'] += ents.count(&:nil?)
    ents.compact.each { |e| e.hidden = true if e.respond_to?(:hidden=) }
    f = s['flags']
    pg.use_camera = f['use_camera']
    pg.use_hidden_layers = f['use_hidden_layers']
    pg.use_hidden_objects = f['use_hidden_objects'] if pg.respond_to?(:use_hidden_objects=) && !f['use_hidden_objects'].nil?
    %w[use_rendering_options use_shadow_info use_axes use_section_planes].each { |k| pg.send("#{k}=", f[k]) unless f[k].nil? }
    mask = PAGE_USE_CAMERA
    mask |= PAGE_USE_HIDDEN_OBJECTS if f['use_hidden_objects']
    pg.update(mask)
    if s['hidden_tags']
      hid = s['hidden_tags']
      m.layers.each { |l| pg.set_visibility(l, !hid.include?(l.name)) rescue nil }
    end
    ents.compact.each { |e| e.hidden = false if e.respond_to?(:hidden=) }
    %w[WR_ProposalPackage WR_AutoSet wr_cms].each do |dn|
      want = s[dn] || {}
      d = pg.attribute_dictionary(dn)
      (d ? d.keys : []).each { |k| d.delete_key(k) unless want.key?(k) }
      want.each { |k, val| pg.set_attribute(dn, k, val) }
    end
    out['restored'] << s['name']
  end
  m.commit_operation
rescue Exception
  m.abort_operation
  raise
end
ps.selected_page = sel if sel && sel.valid?
out
