# Read-only: the RM room lights still carry their V-Ray params (separate job from the create).
m = Sketchup.active_model
ctx = VRay::Context.active
sc = ctx.scene
DICT = 'wr_walsh_rm_lights'
ls = m.entities.select { |e| e.respond_to?(:definition) && e.get_attribute(DICT, 'plugin') }
ls.each do |i|
  pn = i.get_attribute(DICT, 'plugin')
  pl = sc[pn] rescue nil
  if pl.nil?
    puts "#{i.name}: plugin #{pn} MISSING"
  else
    puts "#{i.name}: #{pn} inv=#{pl[:invisible]} refl=#{pl[:affectReflections]} units=#{pl[:units]} int=#{pl[:intensity].round} enabled=#{(pl[:enabled] rescue '?')}"
  end
end
puts "count=#{ls.size} modified=#{m.modified?}"
true
