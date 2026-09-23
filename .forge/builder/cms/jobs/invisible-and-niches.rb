# (1) every CMS rig light: invisible = true, affectReflections = false, in place (intensity unchanged);
# (2) carpet into both radiator niches, in place, via features.rb niche_floors!.
$wr_no_autorun = true
D = 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/'
load D + 'scripts/wr-drop-lights.rb' unless defined?(WR_DropLights)
load D + '.forge/builder/cms/room.rb'
m = Sketchup.active_model
sc = VRay::Context.active.scene
out = { 'lights' => [] }
m.entities.select { |e| e.get_attribute('wr_cms_lights', 'plugin') }.each do |i|
  p = sc[i.get_attribute('wr_cms_lights', 'plugin')]
  next out['lights'] << [i.get_attribute('wr_cms_lights', 'name'), 'NO PLUGIN'] unless p
  errs = WR_DropLights.write_params(sc, p, [[:invisible, true], [:affectReflections, false]])
  i.set_attribute('wr_cms_lights', 'invisible', true)
  out['lights'] << [i.get_attribute('wr_cms_lights', 'name'), errs.empty? ? 'ok' : errs]
end
m.start_operation('CMS: carpet into radiator niches', true)
begin
  room = m.entities.find { |e| e.respond_to?(:name) && e.name == 'CMS Classroom' }
  out['niche_faces'] = WR_CMS.niche_floors!(room.definition.entities.parent.instances.first == room ? room : room)
  m.commit_operation
rescue Exception
  m.abort_operation
  raise
end
fl = m.entities.find { |e| e.respond_to?(:name) && e.name == 'CMS Classroom' }.definition.entities.find { |g| g.respond_to?(:name) && g.name == 'Floor' }
out['floor_faces'] = fl.definition.entities.grep(Sketchup::Face).map { |f| [f.area.round, f.bounds.max.x.to_f.round(1)] }
out
