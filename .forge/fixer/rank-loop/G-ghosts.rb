load 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-OneDrive-Documents-Claude-Sketchup/9b940cf8-f4c1-482d-86e5-25eb21d96e0b/scratchpad/cyc/lib.rb'
m = CYC.model
c = CYC.census
puts "NOW: vray=#{c['vray_lights'].length} rig_entities=#{c['rig_entities']} top=#{c['top'].inspect}"
# owned plugin names = every entity carrying a 'plugin' attribute, anywhere
owned = {}
walk = lambda do |ents, d|
  ents.each do |e|
    next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    p = e.get_attribute(WR_DropLights::DICT, 'plugin').to_s
    owned[p] = true unless p.empty?
    walk.call(e.definition.entities, d + 1) if d < 4
  end
end
walk.call(m.entities, 0)
foreign = ['/Standard Light', '/SunLight']
sc = VRay::Context.active.scene
ghosts = c['vray_lights'].map { |x| x[0] }.reject { |n| owned[n] || foreign.include?(n) }
puts "GHOSTS (#{ghosts.length}): #{ghosts.inspect}"
deleted = []
sc.change { ghosts.each { |n| deleted << n if (sc.delete(n) rescue false) } }
puts "deleted #{deleted.length}"
c2 = CYC.census
puts "AFTER PURGE: vray=#{c2['vray_lights'].length} #{c2['vray_lights'].map { |x| x[0] }.inspect}"
# M1 reproduction: clean drop, then a second drop on top (the replace path)
CYC.drop(WR_DropLights.default_settings)
c3 = CYC.census
puts "DROP1: vray=#{c3['vray_lights'].length} dead(<=30)=#{c3['vray_lights'].select { |x| x[2].to_f <= 30.0 && !foreign.include?(x[0]) }.map { |x| x[0] }.inspect}"
CYC.drop(WR_DropLights.default_settings)
c4 = CYC.census
puts "DROP2 (replace path): vray=#{c4['vray_lights'].length} dead(<=30)=#{c4['vray_lights'].select { |x| x[2].to_f <= 30.0 && !foreign.include?(x[0]) }.map { |x| [x[0], x[2]] }.inspect}"
puts "   all: #{c4['vray_lights'].map { |x| [x[0], x[2]] }.inspect}"
nil
