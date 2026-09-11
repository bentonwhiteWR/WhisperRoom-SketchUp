load 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-OneDrive-Documents-Claude-Sketchup/9b940cf8-f4c1-482d-86e5-25eb21d96e0b/scratchpad/cyc/lib.rb'
r = WR_DropLights.remove_rig!(CYC.model)
puts "REMOVE: erased=#{r['erased']} plugins_deleted=#{r['plugins_deleted']} plugins_left=#{r['plugins_left']}"
c0 = CYC.census
puts "STEP0 clean: vray=#{c0['vray_lights'].length} rig_entities=#{c0['rig_entities']}"
st = WR_DropLights.default_settings
CYC.drop(st)
c1 = CYC.census
puts "STEP1 dropped: vray=#{c1['vray_lights'].length} rig_entities=#{c1['rig_entities']} top=#{c1['top'].length}"
Sketchup.undo
c2 = CYC.census
puts "STEP2 after UNDO: vray=#{c2['vray_lights'].length} rig_entities=#{c2['rig_entities']} top=#{c2['top'].inspect}"
puts "   plugins still in scene: #{c2['vray_lights'].map { |x| x[0] }.inspect}"
CYC.drop(st)
c3 = CYC.census
puts "STEP3 re-dropped: vray=#{c3['vray_lights'].length} rig_entities=#{c3['rig_entities']} top=#{c3['top'].length}"
puts "   plugins: #{c3['vray_lights'].map { |x| [x[0], x[2]] }.inspect}"
nil
