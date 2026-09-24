# READ-ONLY survey of the Tampa model: pages, lights, environment, camera.
require 'json'
m = Sketchup.active_model
sc = VRay::Context.active.scene
ser = lambda do |p|
  h = {}
  p.each do |k, v, *_|
    h[k.to_s] = if v.is_a?(VRay::Scene::Plugin) then "plugin:#{v.name}"
                elsif v.respond_to?(:r) && v.respond_to?(:g) then [v.r, v.g, v.b].map { |x| x.round(3) }
                elsif v.is_a?(Numeric) || v == true || v == false || v.is_a?(String) then v
                else v.inspect[0, 100] end
  end
  h
end
pp = 'WR_ProposalPackage'
pages = m.pages.map do |p|
  { 'name' => p.name, 'mode' => p.get_attribute(pp, 'mode'), 'ev' => p.get_attribute(pp, 'ev'),
    'uses_layers' => p.use_hidden_layers?, 'hidden_layers' => (p.use_hidden_layers? ? p.layers.map(&:name) : nil),
    'uses_hidden' => (p.use_hidden_objects? rescue nil), 'n_hidden' => ((p.hidden_entities rescue nil) || []).size,
    'eye' => p.camera.eye.to_a.map { |v| v.to_f.round(1) }, 'target' => p.camera.target.to_a.map { |v| v.to_f.round(1) },
    'fov' => (p.camera.perspective? ? p.camera.fov.round(1) : 'ortho'), 'uses_shadow' => (p.use_shadow_info? rescue nil) }
end
insts = []
walk = lambda do |ents, tr, path, hid|
  ents.each do |e|
    next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
    d = e.respond_to?(:definition) ? e.definition : nil
    t = tr * e.transformation
    nm = "#{path}/#{e.name.to_s.empty? ? d.name : e.name}"
    if d && d.name =~ /light|sphere|dome|rect|ies|omni|spot|mesh ?light/i && d.entities.grep(Sketchup::Face).empty?
      insts << { 'path' => nm, 'def' => d.name, 'layer' => e.layer.name, 'hidden' => e.hidden?, 'anc_hidden' => hid,
                 'origin' => t.origin.to_a.map { |v| v.to_f.round(1) } }
    end
    walk.call(d.entities, t, nm, hid || e.hidden?) if d && path.count('/') < 8
  end
end
walk.call(m.entities, Geom::Transformation.new, '', false)
lights = []
sc.each do |p|
  next unless p.category.to_s =~ /light/i
  h = ser.call(p)
  keep = %w[enabled intensity units color color_colortex_on invisible affectReflections affectSpecular affectDiffuse
            shadows radius u_size v_size subdivs noDecay texture_colortex_on use_dome_tex dome_spherical intensity_multiplier
            size_multiplier sky_model filter_color turbidity ozone]
  lights << { 'name' => p.name, 'type' => p.type.to_s }.merge(h.select { |k, _| keep.include?(k) })
end
cp = ser.call(sc['/CameraPhysical']).select { |k, _| %w[f_number ISO shutter_speed exposure white_balance vignetting type specify_fov].include?(k) }
out = { 'page_selected' => (m.pages.selected_page.name rescue nil),
        'view_cam' => [m.active_view.camera.eye.to_a.map { |v| v.to_f.round(2) }, m.active_view.camera.target.to_a.map { |v| v.to_f.round(2) }, m.active_view.camera.fov],
        'selection' => m.selection.size, 'modified' => m.modified?,
        'pages' => pages, 'light_instances' => insts, 'vray_lights' => lights, 'camera_physical' => cp,
        'settings_env' => ser.call(sc['/SettingsEnvironment']),
        'env_sky' => (sc['/Environment Sky'] ? ser.call(sc['/Environment Sky']) : nil),
        'output' => ser.call(sc['/SettingsOutput']).select { |k, _| k =~ /img_(width|height)/ },
        'shadow' => %w[ShadowTime NorthAngle Latitude Longitude DisplayShadows].map { |k| [k, (m.shadow_info[k].to_s rescue nil)] }.to_h,
        'renderer_state' => (VRay::Context.active.renderer.state.to_s rescue nil),
        'top' => m.entities.select { |e| e.respond_to?(:definition) }.map { |e| [e.name, e.definition.name, e.layer.name, e.bounds.min.to_a.map { |v| v.to_f.round(1) }, e.bounds.max.to_a.map { |v| v.to_f.round(1) }] } }
File.write($tl_out, JSON.pretty_generate(out))
{ 'written' => $tl_out, 'lights' => lights.size, 'insts' => insts.size }
