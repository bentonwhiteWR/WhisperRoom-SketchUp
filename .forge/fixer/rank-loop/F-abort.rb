load 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-OneDrive-Documents-Claude-Sketchup/9b940cf8-f4c1-482d-86e5-25eb21d96e0b/scratchpad/cyc/lib.rb'
m = CYC.model
r = WR_DropLights.remove_rig!(m)
puts "REMOVE: erased=#{r['erased']} plugins_deleted=#{r['plugins_deleted']} plugins_left=#{r['plugins_left']}"
c0 = CYC.census
puts "STEP0 clean: vray=#{c0['vray_lights'].length} rig_entities=#{c0['rig_entities']} top=#{c0['top'].length}"
# FORCE A ROLLBACK: reap_lights is the last call before commit_operation, so a
# raise there lands in run's rescue -> model.abort_operation, with every V-Ray
# plugin already created and configured. Restored in ensure.
WR_DropLights.singleton_class.send(:alias_method, :cyc_orig_reap, :reap_lights)
begin
  WR_DropLights.define_singleton_method(:reap_lights) { |*_a| raise 'CYC forced rollback' }
  CYC.drop(WR_DropLights.default_settings)
ensure
  WR_DropLights.singleton_class.send(:alias_method, :reap_lights, :cyc_orig_reap)
end
c1 = CYC.census
puts "STEP1 after forced ABORT: vray=#{c1['vray_lights'].length} rig_entities=#{c1['rig_entities']} top=#{c1['top'].inspect}"
puts "   orphan plugins: #{c1['vray_lights'].map { |x| [x[0], x[2], x[3]] }.inspect}"
CYC.drop(WR_DropLights.default_settings)
c2 = CYC.census
puts "STEP2 re-dropped after abort: vray=#{c2['vray_lights'].length} rig_entities=#{c2['rig_entities']} top=#{c2['top'].length}"
puts "   plugins now: #{c2['vray_lights'].map { |x| [x[0], x[2], x[3]] }.inspect}"
nil
