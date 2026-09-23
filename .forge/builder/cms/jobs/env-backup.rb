# Revert record for the SUN / SKY / ENVIRONMENT + the corridor block's per-scene visibility.
# $cms_env_path = output .json. Read-only on the model. Restore: jobs/env-restore.rb.
require 'json'
m = Sketchup.active_model
sc = VRay::Context.active.scene
ser = lambda do |p|
  h = {}
  p.each do |k, v, *_|
    h[k.to_s] = if v.is_a?(VRay::Scene::Plugin) then { 'plugin' => v.name.to_s }
                elsif v.respond_to?(:r) && v.respond_to?(:g) then { 'color' => [v.r, v.g, v.b, (v.respond_to?(:a) ? v.a : nil)] }
                elsif v.is_a?(Numeric) || v == true || v == false || v.is_a?(String) then v
                else { 'inspect' => v.inspect[0, 120] } end
  end
  h
end
si = m.shadow_info
sik = %w[DisplayShadows Latitude Longitude NorthAngle ShadowTime TZOffset UseSunForAllShading Light Dark DaylightSavings City Country]
corr = ['corridor', 'Door leaf 4 entry']
room = m.entities.find { |e| e.respond_to?(:name) && e.name == 'CMS Classroom' }
w = room.definition.entities.find { |g| g.respond_to?(:name) && g.name == 'Walls' }
f4 = w.definition.entities.find { |g| g.respond_to?(:name) && g.name == 'Wall 4 fittings' }
cg = f4.definition.entities.select { |e| e.respond_to?(:definition) && corr.include?(e.name.to_s) }
rec = { 'written' => Time.now.to_s,
        'SunLight' => ser.call(sc['/SunLight']), 'EnvironmentSky' => ser.call(sc['/Environment Sky']),
        'SettingsEnvironment' => ser.call(sc['/SettingsEnvironment']),
        'shadow_info' => sik.each_with_object({}) { |k, h| v = (si[k] rescue nil); h[k] = v.is_a?(Time) ? v.utc.to_s : v },
        'corridor_blocks' => cg.map { |g| { 'name' => g.name, 'pid' => g.persistent_id, 'global_hidden' => g.hidden? } },
        'corridor_hidden_per_scene' => m.pages.map { |p| [p.name, ((p.hidden_entities rescue nil) || []).select { |e| cg.include?(e) }.map(&:name)] }.to_h }
File.write($cms_env_path, JSON.pretty_generate(rec))
{ 'written' => $cms_env_path, 'sun_enabled' => rec['SunLight']['enabled'], 'sun_mult' => rec['SunLight']['intensity_multiplier'],
  'sun_size' => rec['SunLight']['size_multiplier'], 'sky_model' => rec['SunLight']['sky_model'], 'shadow_time' => rec['shadow_info']['ShadowTime'] }
