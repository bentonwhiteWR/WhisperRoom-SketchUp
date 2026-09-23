$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/build-booth-components.rb'
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-overlays.rb'
m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
ents = b.definition.entities
outer = ents.find { |e| e.respond_to?(:definition) && e.definition.name == '46Panel3236WDO' }
inner = ents.find { |e| e.respond_to?(:definition) && e.definition.name == 'ENH 41.5Panel3236WDO' }
raise 'window panels not found' unless outer && inner
walls = ents.select { |e| e.respond_to?(:definition) && e.layer.name == 'WR-Booth-Walls' }
cb = Geom::BoundingBox.new; walls.each { |w| cb.add(w.bounds) }
centre = cb.center
frame = lambda do |inst|
  bb = inst.bounds
  ex = bb.width; ey = bb.height
  naxis = ex < ey ? :x : :y
  run = naxis == :x ? :y : :x
  pc = bb.center
  room = naxis == :x ? (centre.x > pc.x ? 1 : -1) : (centre.y > pc.y ? 1 : -1)
  lo = naxis == :x ? bb.min.x : bb.min.y
  hi = naxis == :x ? bb.max.x : bb.max.y
  r0 = run == :x ? bb.min.x : bb.min.y
  r1 = run == :x ? bb.max.x : bb.max.y
  { :naxis => naxis, :run => run, :room => room, :room_face => (room > 0 ? hi : lo), :out_face => (room > 0 ? lo : hi), :r0 => r0, :r1 => r1 }
end
fo = frame.call(outer); fi = frame.call(inner)
md = m.definitions['MJP'] or raise 'MJP def missing'
gx = WR_Overlays.geom_extents(md)
ax = WR_Overlays.axes_for(gx[:e], WR_Overlays::MJP_W, nil, WR_Overlays::MJP_T)
run_c = (fo[:r0] + fo[:r1]) / 2.0
proud = WR_Overlays.host_proud(inner.definition.name, true)
it = { :run => fi[:run], :naxis => fi[:naxis], :run_c => run_c, :face => fi[:room_face] + fi[:room] * proud, :room => fi[:room], :z_c => nil, :z_top => WR_Overlays::MJP_TOP_Z }
ot = { :run => fo[:run], :naxis => fo[:naxis], :run_c => run_c, :face => fo[:out_face], :room => fo[:room], :z_c => nil, :z_top => WR_Overlays::MJP_TOP_Z }
puts "outer #{fo.inspect}\ninner #{fi.inspect}\nproud(iep)=#{proud} run_c=#{run_c.round(2)} top_z=#{WR_Overlays::MJP_TOP_Z}"
lay = m.layers['WR-Booth-Options']
b.definition.entities.grep(Sketchup::ComponentInstance).select { |e| e.name.start_with?("MJP interior (window", "MJP exterior (window") }.each(&:erase!)
m.start_operation('Add MJP (window wall)', true)
tri = WR_Overlays.wall_transform(gx, ax, it, WR_Overlays::FACE_ROOM[:mjp], false, WR_Overlays::MJP_SPIN180)
puts 'interior ' + WR_Overlays.add(b.definition, md, tri, 'MJP interior (window wall)', lay)
tro = WR_Overlays.wall_transform(gx, ax, ot, WR_Overlays::FACE_ROOM[:mjp], true, WR_Overlays::MJP_SPIN180)
puts 'exterior ' + WR_Overlays.add(b.definition, md, tro, 'MJP exterior (window wall)', lay)
m.commit_operation
nil
