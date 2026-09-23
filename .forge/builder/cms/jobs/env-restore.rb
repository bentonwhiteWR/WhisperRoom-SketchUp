# Restore the sun / sky / environment scalars and the SketchUp shadow time from an env-backup JSON.
# $cms_env_path = the .json. Restores SunLight + Environment Sky numeric/boolean/colour params and the
# SettingsEnvironment *_tex_tex_on / *_mult / override_* flags (plugin links are not rewritten -- they
# were never changed), and shadow_info. Corridor visibility per scene: restore scenes with
# jobs/scene-restore.rb (scene-backup JSON) -- the corridor is part of each scene's hidden set.
require 'json'
m = Sketchup.active_model
sc = VRay::Context.active.scene
rec = JSON.parse(File.read($cms_env_path))
put = lambda do |pn, h, filt|
  p = sc[pn]
  sc.change do
    h.each do |k, v|
      next unless filt.call(k, v)
      begin
        p[k.to_sym] = v.is_a?(Hash) && v['color'] ? VRay::Color.new(*v['color'][0, 3]) : v
      rescue StandardError
        nil
      end
    end
  end
end
scal = ->(_k, v) { v.is_a?(Numeric) || v == true || v == false || (v.is_a?(Hash) && v['color']) }
put.call('/SunLight', rec['SunLight'], scal)
put.call('/Environment Sky', rec['EnvironmentSky'], scal)
put.call('/SettingsEnvironment', rec['SettingsEnvironment'], ->(k, v) { k =~ /_tex_tex_on\z|_mult\z|\Aoverride_|\Ause_/ && scal.call(k, v) })
si = m.shadow_info
rec['shadow_info'].each do |k, v|
  next if v.nil?
  begin
    si[k] = k == 'ShadowTime' ? Time.parse(v) : v
  rescue StandardError
    nil
  end
end
{ 'sun_mult' => sc['/SunLight'][:intensity_multiplier], 'sun_enabled' => sc['/SunLight'][:enabled], 'shadow_time' => si['ShadowTime'].to_s }
