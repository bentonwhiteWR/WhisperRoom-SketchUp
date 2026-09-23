# READ-ONLY: every CMS rig light -- plugin present, invisible, affectReflections, intensity vs stamp,
# and the definition's stored JSON (what V-Ray re-syncs from).
m = Sketchup.active_model
sc = VRay::Context.active.scene
ls = m.entities.select { |e| e.get_attribute('wr_cms_lights', 'plugin') }
bad = []
ls.each do |i|
  pn = i.get_attribute('wr_cms_lights', 'plugin')
  p = sc[pn]
  js = (i.definition.attribute_dictionary('VRayPlugins')[pn].to_s rescue '')
  ok = p && p[:invisible] == true && p[:affectReflections] == false &&
       (p[:intensity].to_f - i.get_attribute('wr_cms_lights', 'written').to_f).abs < 1 &&
       js[/"invisible":"?(\w+)/, 1] == '1' && js[/"affectReflections":"?(\w+)/, 1] == '0'
  bad << [i.get_attribute('wr_cms_lights', 'name'), p && p[:invisible], p && p[:affectReflections], p && p[:intensity], js[/"invisible":"?(\w+)/, 1], js[/"affectReflections":"?(\w+)/, 1]] unless ok
end
{ 'count' => ls.size, 'bad' => bad, 'studio_8' => sc['/Sphere Light#8'][:intensity], 'backdrops' => ['/Rectangle Light#19', '/Rectangle Light#21'].map { |n| [n, sc[n][:intensity], sc[n][:invisible]] } }
