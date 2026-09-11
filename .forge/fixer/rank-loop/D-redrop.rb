load 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-OneDrive-Documents-Claude-Sketchup/9b940cf8-f4c1-482d-86e5-25eb21d96e0b/scratchpad/cyc/lib.rb'
r = WR_DropLights.remove_rig!(CYC.model)
puts "REMOVE: erased=#{r['erased']} plugins_deleted=#{r['plugins_deleted']} plugins_left=#{r['plugins_left']} ceiling_verified=#{r['ceiling_verified']} ceilings=#{r['ceiling_groups_erased']} walls=#{r['wall_groups_erased']}"
after_remove = CYC.census
puts "AFTER REMOVE: vray lights=#{after_remove['vray_lights'].length} rig_entities=#{after_remove['rig_entities']} top=#{after_remove['top'].inspect}"
st = WR_DropLights.default_settings
st['mult'] = ($cyc_mult || 1.0)
CYC.drop(st)
c = CYC.census
{ 'after_remove' => after_remove, 'after_drop' => c }
