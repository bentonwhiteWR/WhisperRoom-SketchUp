# Benton, 22 Sep: halve V-Ray "Rectangle Light#11" and "#9" (the two daylight-on-backdrop panels) so the
# window backdrop reads instead of blowing out. In place (no re-place, names kept); instance stamps updated.
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/wr-drop-lights.rb' unless defined?(WR_DropLights)
sc = VRay::Context.active.scene
m = Sketchup.active_model
out = []
['/Rectangle Light#9', '/Rectangle Light#11'].each do |n|
  p = sc[n]
  raise "no plugin #{n}" unless p
  before = p[:intensity].to_f
  errs = WR_DropLights.write_params(sc, p, [[:intensity, before * 0.5]])
  inst = m.entities.find { |e| e.get_attribute('wr_cms_lights', 'plugin') == n }
  if inst
    inst.set_attribute('wr_cms_lights', 'written', (before * 0.5).round)
    inst.set_attribute('wr_cms_lights', 'lm_product', (before * 0.5 / 320.0).round)
  end
  out << [n, inst && inst.get_attribute('wr_cms_lights', 'name'), before, errs]
end
out
