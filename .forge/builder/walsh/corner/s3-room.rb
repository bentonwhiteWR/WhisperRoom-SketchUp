# Walsh corner: step 3. Build the ARCHITECT-MATCHED Tech Lab (21 Oct) next to nothing else: one new group
# placed at the old Platform room's origin O (recorded by s2-retag.rb), house walls (4" outward, mitred),
# floor, ceiling, door 24, and the pocket behind the new zigzag walls (stub + south run + approx 3'-0" door).
# New-construction (black) walls go on tag 'WR-Room-New'. Never touches anything outside its own group.
load File.join(File.dirname(__FILE__), 'geom.rb')
$wr_suppress_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/build-room.rb'
$wr_suppress_autorun = false
br = WR_BuildRoom
wc = WalshCorner
m = Sketchup.active_model
NAME = 'Tech Lab 13 - Corner 21 Oct'
raise 'run s2-retag.rb first (no WalshCorner/origin)' unless m.get_attribute('WalshCorner', 'origin')
raise "#{NAME} already exists; erase it (Ctrl+Z) before re-running" if m.entities.grep(Sketchup::Group).any? { |g| g.name == NAME }
o = m.get_attribute('WalshCorner', 'origin')
t_floor = br.tag(m, 'WR-Floor', [230, 230, 230])
t_wall  = br.tag(m, 'WR-Room', [120, 128, 140])
t_new   = br.tag(m, 'WR-Room-New', [30, 30, 30])
t_door  = br.tag(m, 'WR-Doors', [238, 98, 22])
t_leaf  = br.tag(m, 'WR-Doors-Leaf', [200, 130, 60])
t_ceil  = br.tag(m, 'WR-Ceiling', [200, 205, 212])
mat_w = br.material(m, br::MAT_WALL)
mat_f = br.material(m, br::MAT_FLOOR)
mat_d = br.material(m, br::MAT_DOOR)
T = wc::THICK
NEW_RUNS = [1, 2, 3, 4, 5].freeze     # corner, front, step, zone, angled
m.start_operation('Walsh corner: room', true)
begin
  pts = wc.techlab.map { |x, y| br.pt(x, y) }
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
  foot = pts[6]
  doors = [{ 'run' => 6, 'at' => foot.x - 40.0, 'w' => 36.0 }]     # door 24 stays at x 4-40 (assumed)
  pts.size.times do |i|
    before = wg.entities.to_a
    br.wall_run(wg, pts, outer, i, ccw, T, wc::CEIL, doors.select { |d| d['run'] == i }, wc::DOOR_H)
    (wg.entities.to_a - before).each do |e|
      e.material = mat_w
      next unless NEW_RUNS.include?(i)
      e.layer = t_new
      e.name = "NEW #{e.name}"
    end
  end
  dg = g.entities.add_group
  dg.name = 'Doors'
  br.door(dg, pts, 6, ccw, T, doors[0]['at'], 36.0, wc::DOOR_H, 'far', t_door, t_leaf, mat_d)
  cg = g.entities.add_group
  br.quad(cg.entities, pts, wc::CEIL, wc::CEIL + wc::SLAB)
  cg.name = 'Ceiling'
  cg.layer = t_ceil

  # ---- pocket behind the zigzag (walls approximate beyond the stated 9'-1") ----
  k = wc.pocket
  P = ->(xy, z = 0.0) { br.pt(xy[0], xy[1], z) }
  pg = g.entities.add_group
  pg.name = 'Pocket (behind new walls)'
  pf = pg.entities.add_group
  f2 = pf.entities.add_face(k[:floor].map { |q| P.(q) })
  if f2
    f2.reverse! if f2.normal.z < 0
    f2.material = mat_f
  end
  pf.name = 'Pocket floor'
  pf.layer = t_floor
  solid = lambda do |poly, z0, z1, name, tag|
    s = pg.entities.add_group
    br.quad(s.entities, poly.map { |q| P.(q) }, z0, z1)
    s.name = name
    s.layer = tag
    s.material = mat_w
    s
  end
  solid.(k[:stub], 0.0, wc::CEIL, 'NEW Corner wall stub', t_new)
  ys = wc::Y_S
  gx = k[:gi][0]
  dx1 = gx - wc::CFG['POCKET_DOOR_FROM_G']
  dx0 = dx1 - wc::CFG['POCKET_DOOR_W']
  fe = k[:fe]
  fo = k[:fo]
  solid.([fe, [dx0, ys], [dx0, ys - T], fo], 0.0, wc::CEIL, 'Pocket south wall W', t_wall)
  solid.([[dx0, ys], [dx1, ys], [dx1, ys - T], [dx0, ys - T]], wc::DOOR_H, wc::CEIL, 'Pocket door header', t_wall)
  solid.([[dx1, ys], k[:cs], k[:go], [dx1, ys - T]], 0.0, wc::CEIL, 'Pocket south wall E', t_wall)
  # pocket door: hinge at the east jamb (G side), swings north into the pocket. APPROXIMATE (scaled).
  hinge = P.([dx1, ys])
  lg = pg.entities.add_group
  lf = lg.entities.add_face([hinge, hinge.offset(Y_AXIS, 36.0), hinge.offset(Y_AXIS, 36.0).offset(X_AXIS, -1.5), hinge.offset(X_AXIS, -1.5)])
  if lf
    lf.reverse! if lf.normal.z < 0
    lf.pushpull(wc::DOOR_H)
  end
  lg.name = 'Pocket door leaf (approx)'
  lg.layer = t_leaf
  lg.material = mat_d
  ag = pg.entities.add_group
  arc = (0..12).map { |j| a = Math::PI / 2 * j / 12; br.pt(dx1 - 36.0 * Math.cos(a), ys + 36.0 * Math.sin(a)) }
  arc.each_cons(2) { |a1, a2| ag.entities.add_line(a1, a2) }
  ag.name = 'Pocket door swing'
  ag.layer = t_leaf
  m.set_attribute('WalshCorner', 'room_pid', g.persistent_id)
  m.commit_operation
rescue Exception => e
  m.abort_operation
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(6)
  raise
end
m.save
puts "built #{NAME}: #{g.entities.size} groups, walls=#{wg.entities.size}, new-tag walls=#{wg.entities.count { |e| e.layer == t_new } + 1}"
puts "bounds #{g.bounds.min.to_a.map { |v| v.to_f.round(1) }} .. #{g.bounds.max.to_a.map { |v| v.to_f.round(1) }}"
puts wc.table
puts "saved #{m.path}"
