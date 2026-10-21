# Walsh v3 step 2: the Tech Lab with NO new (black) walls. Polygon A -> C -> G -> SW -> WTOP (take-off frame,
# placed at WalshCorner/origin). Exterior wall, corner wall (kept as an ordinary room wall, see notes),
# south wall with door 24 and the pocket door (both estimated positions), west wall, NW angled wall.
# House walls 4" built outward, mitred. 8'-0" ceiling (assumed). New group only.
load File.join(File.dirname(__FILE__), 'geom.rb')
$wr_suppress_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/build-room.rb'
$wr_suppress_autorun = false
br = WR_BuildRoom
wc = WalshCorner
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
NAME = 'Tech Lab 13 - RM 21 Oct'
raise "#{NAME} already exists; Ctrl+Z first" if m.entities.grep(Sketchup::Group).any? { |g| g.name == NAME }
o = m.get_attribute('WalshCorner', 'origin') or raise 'no WalshCorner/origin'
t_floor = br.tag(m, 'WR-Floor', [230, 230, 230])
t_wall  = br.tag(m, 'WR-Room', [120, 128, 140])
t_door  = br.tag(m, 'WR-Doors', [238, 98, 22])
t_leaf  = br.tag(m, 'WR-Doors-Leaf', [200, 130, 60])
t_ceil  = br.tag(m, 'WR-Ceiling', [200, 205, 212])
mat_w = br.material(m, br::MAT_WALL)
mat_f = br.material(m, br::MAT_FLOOR)
mat_d = br.material(m, br::MAT_DOOR)
T = wc::THICK
pts = WalshRM.room.map { |x, y| br.pt(x, y) }
gx = pts[2].x.to_f
doors = [{ 'run' => 2, 'at' => gx - 40.0, 'w' => 36.0, 'hinge' => 'far', 'name' => 'Door 24' },
         { 'run' => 2, 'at' => wc::CFG['POCKET_DOOR_FROM_G'], 'w' => wc::CFG['POCKET_DOOR_W'], 'hinge' => 'near',
           'name' => 'Door 2 (east, estimated)' }]
errs = br.door_errors(pts, doors)
raise errs.join('; ') unless errs.empty?
m.start_operation('Walsh v3: room', true)
begin
  ccw = br.signed_area(pts) > 0
  outer = br.mitre(pts, ccw, T)
  g = m.entities.add_group
  g.name = NAME
  g.transformation = Geom::Transformation.translation(Geom::Vector3d.new(o[0], o[1], o[2]))
  fg = g.entities.add_group
  ff = fg.entities.add_face(pts)
  ff.reverse! if ff.normal.z < 0
  ff.material = mat_f
  fg.name = 'Floor'
  fg.layer = t_floor
  wg = g.entities.add_group
  wg.name = 'Walls'
  wg.layer = t_wall
  pts.size.times do |i|
    before = wg.entities.to_a
    br.wall_run(wg, pts, outer, i, ccw, T, wc::CEIL, doors.select { |d| d['run'] == i }, wc::DOOR_H)
    (wg.entities.to_a - before).each { |e| e.material = mat_w }
  end
  dg = g.entities.add_group
  dg.name = 'Doors'
  doors.each do |d|
    before = dg.entities.to_a
    br.door(dg, pts, d['run'], ccw, T, d['at'], d['w'], wc::DOOR_H, d['hinge'], t_door, t_leaf, mat_d)
    (dg.entities.to_a - before).each { |e| e.name = "#{d['name']} - #{e.name}" }
  end
  cg = g.entities.add_group
  br.quad(cg.entities, pts, wc::CEIL, wc::CEIL + wc::SLAB)
  cg.name = 'Ceiling (8\'-0" assumed)'
  cg.layer = t_ceil
  m.set_attribute('WalshRM', 'room_pid', g.persistent_id)
  m.commit_operation
rescue Exception => e
  m.abort_operation
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(6)
  raise
end
WalshRM.save(m)
n = pts.size
pts.each_with_index do |p, i|
  q = pts[(i + 1) % n]
  puts format('run %d  %s -> %s  %.2f in  %s', i, p.to_a.first(2).map { |v| v.to_f.round(2) }.inspect,
              q.to_a.first(2).map { |v| v.to_f.round(2) }.inspect, (q - p).length.to_f, wc.ft((q - p).length.to_f))
end
puts "doors #{doors.map { |d| [d['name'], d['at'].round(2), d['w']] }.inspect}"
dg.entities.each { |e| puts "  #{e.name} #{e.bounds.min.to_a.first(2).map { |v| v.to_f.round(1) }}..#{e.bounds.max.to_a.first(2).map { |v| v.to_f.round(1) }}" }
puts "saved #{m.path}"
