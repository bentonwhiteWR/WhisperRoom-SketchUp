# Re-write the CMS rig lights whose plugin no longer matches lights.rb (the "write did not persist"
# hazard: plugin re-synced to V-Ray factory defaults -- invisible false, intensity 30). Values come from
# the instance stamps written at placement (lm_product, kelvin, invisible). Nothing is deleted.
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/wr-drop-lights.rb' unless defined?(WR_DropLights)
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/cms/lights.rb'
m = Sketchup.active_model
sc = VRay::Context.active.scene
fixed = []
m.entities.select { |e| e.get_attribute('wr_cms_lights', 'plugin') }.each do |i|
  pn = i.get_attribute('wr_cms_lights', 'plugin')
  p = sc[pn]
  next unless p
  want = i.get_attribute('wr_cms_lights', 'written').to_f
  inv = i.get_attribute('wr_cms_lights', 'invisible') ? true : false
  next if (p[:intensity].to_f - want).abs < 1 && ((p[:invisible] ? true : false) == inv)
  bad = WR_CMS_Lights.write!(p, inv, i.get_attribute('wr_cms_lights', 'lm_product').to_f, i.get_attribute('wr_cms_lights', 'kelvin').to_i)
  fixed << [i.get_attribute('wr_cms_lights', 'name'), pn, bad]
end
fixed
