load 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-OneDrive-Documents-Claude-Sketchup/9b940cf8-f4c1-482d-86e5-25eb21d96e0b/scratchpad/cyc/lib.rb'
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/wr-drop-lights.rb'   # the PATCHED rule
$wr_no_autorun = nil
m = CYC.model
r = WR_DropLights.remove_rig!(m)
puts "REMOVE: erased=#{r['erased']} plugins_deleted=#{r['plugins_deleted']} plugins_left=#{r['plugins_left']}"
c0 = CYC.census
puts "CLEAN: vray=#{c0['vray_lights'].length} rig_entities=#{c0['rig_entities']} top=#{c0['top'].length}"
raise "not clean: #{c0['vray_lights'].inspect}" unless c0['vray_lights'].length == 2 && c0['rig_entities'] == 0
CYC.drop(WR_DropLights.default_settings)
a = WR_DropLights.audit_scene(m)
puts "AUDIT: ok=#{a['ok']} rig=#{a['rig']} model=#{a['model']} ghosts=#{a['ghosts'].inspect} dead=#{a['dead'].inspect} wrong=#{a['wrong'].inspect} missing=#{a['missing'].inspect}"
a['lines'].each { |l| puts "   #{l}" }
key = m.entities.grep(Sketchup::ComponentInstance).find { |e| e.get_attribute(WR_DropLights::DICT, 'role') == 'key' }
puts "KEY ENTITY at #{key ? key.bounds.center.to_a.map { |v| v.round(1) }.inspect : 'NONE'}, lumens attr #{key && key.get_attribute(WR_DropLights::DICT, 'lumens')}"
nil
