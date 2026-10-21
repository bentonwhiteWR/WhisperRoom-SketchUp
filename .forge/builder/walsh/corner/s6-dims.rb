# Walsh corner: step 6. Floor dims (z = floor) for the corner layout, numbers only, in one group so a re-run is
# a single erase. Every black-wall run, the corner-wall chain + overall, the south chain + doors, west/NW,
# exterior 32'-0" with the booth-gap chain, booth depth + gaps, booth door off its corner, platform/ramp.
# Placed so nothing sits above a dim line in the top view (the booth/platform/EFS hide z-0 dims).
# Offsets are worked out for RAMP_DIR 'open'; with 'corner' the zone dim moves to the pocket side.
load File.join(File.dirname(__FILE__), 'geom.rb')
wc = WalshCorner
m = Sketchup.active_model
o = m.get_attribute('WalshCorner', 'origin') or raise 'run s2-retag.rb first'
NAME = 'Corner Dims 21 Oct'
m.entities.grep(Sketchup::Group).select { |g| g.name == NAME }.each(&:erase!)
lay = lambda do |n, rgb|
  l = m.layers[n] || m.layers.add(n)
  (l.color = Sketchup::Color.new(*rgb)) rescue nil
  l
end
t_w = lay.('WR-Dims', [20, 20, 20])
t_d = lay.('WR-Dims-Doors', [238, 98, 22])
t_b = lay.('WR-Dims-Booth', [40, 90, 170])
t_n = lay.('WR-Notes', [90, 90, 96])
c = wc::CFG
g = wc.solve
z = o[2] + 0.05
W = ->(xy) { Geom::Point3d.new(o[0] + xy[0], o[1] + xy[1], z) }
S = ->(s, d) { W.(wc.p(s, d)) }
SHv = Geom::Vector3d.new(wc::SH[0], wc::SH[1], 0)
NHv = Geom::Vector3d.new(wc::NH[0], wc::NH[1], 0)
m.start_operation('Walsh corner: dims', true)
grp = m.entities.add_group
grp.name = NAME
E = grp.entities
made = []
dim = lambda do |a, b, dir, dist, tag|
  v = Geom::Vector3d.new(dir.x, dir.y, 0)
  v.length = dist
  d = E.add_dimension_linear(a, b, v)
  d.layer = tag
  made << [tag.name, a.distance(b).to_f.round(2)]
  d
end
begin
  sa = g[:s_ang]
  dG = wc.d_on_y(0, wc::Y_S)
  dA = wc.d_on_y(sa, wc::Y_S)
  k = wc.pocket
  tl = wc.techlab
  foot = tl[6]
  out_c = SHv.reverse                     # outside the corner wall
  # corner wall chain + overall
  dim.(S.(0, 0), S.(0, g[:d_f]), out_c, 20, t_w)
  dim.(S.(0, g[:d_f]), S.(0, dG), out_c, 20, t_w)
  dim.(S.(0, 0), S.(0, dG), out_c, 48, t_w)
  # zigzag
  # Placement worked out on plan_svg.py so no two dim lines cross and none runs into the pocket's far wall.
  dim.(S.(0, g[:d_f]), S.(g[:s_step], g[:d_f]), NHv, 14, t_w)          # front wall, pocket side
  dim.(S.(g[:s_step], g[:d_f]), S.(g[:s_step], g[:d_z]), SHv, 20, t_w) # step, alcove side
  dim.(S.(g[:s_step], g[:d_z]), S.(sa, g[:d_z]), NHv, 20, t_w)         # zone, pocket side
  dim.(S.(sa, g[:d_z]), S.(sa, dA), SHv, 20, t_w)                      # angled, Tech Lab side
  puts 'WARNING RAMP_DIR corner: placement tuned for open; check the top-down for crossings' unless c['RAMP_DIR'] == 'open'
  # south chain: doors row, walls row, overall
  sw = [0.0, wc::Y_S]
  dn = Geom::Vector3d.new(0, -1, 0)
  dim.(W.(sw), W.([4.0, wc::Y_S]), dn, 20, t_d)
  dim.(W.([4.0, wc::Y_S]), W.([40.0, wc::Y_S]), dn, 20, t_d)
  dx1 = k[:gi][0] - c['POCKET_DOOR_FROM_G']
  dx0 = dx1 - c['POCKET_DOOR_W']
  dim.(W.([dx0, wc::Y_S]), W.([dx1, wc::Y_S]), dn, 20, t_d)
  dim.(W.([dx1, wc::Y_S]), W.(k[:gi]), dn, 20, t_d)
  dim.(W.(sw), W.(foot), dn, 48, t_w)
  dim.(W.(foot), W.(k[:gi]), dn, 48, t_w)
  dim.(W.(sw), W.(k[:gi]), dn, 76, t_w)
  # west + NW (existing)
  dim.(W.(sw), W.(wc::WTOP), Geom::Vector3d.new(-1, 0, 0), 20, t_w)
  nw = Geom::Vector3d.new(-(wc::A[1] - wc::WTOP[1]), wc::A[0] - wc::WTOP[0], 0)
  dim.(W.(wc::WTOP), W.(wc::A), nw, 20, t_w)
  # exterior wall: booth-gap chain (row 1) + 32'-0" overall (row 2)
  so = c['SHELL_OFF']
  se = so + c['BL']
  ext = NHv.reverse
  dim.(S.(0, 0), S.(so, 0), ext, 20, t_b)
  dim.(S.(so, 0), S.(se, 0), ext, 20, t_b)
  dim.(S.(se, 0), W.(wc::A), ext, 20, t_b)
  dim.(S.(0, 0), W.(wc::A), ext, 48, t_w)
  # booth depth + gap off the exterior wall, at the open (E) end
  dim.(S.(se, 0), S.(se, so), SHv, 30, t_b)
  dim.(S.(se, so), S.(se, g[:d_shell]), SHv, 30, t_b)
  ds = g[:d_shell]
  # platform + ramp, measured live from what s4 moved (everything in front of the N face)
  pids = m.get_attribute('WalshCorner', 'movers') || []
  sd = lambda do |pt|
    x = pt.x - o[0] - wc::C[0]
    y = pt.y - o[1] - wc::C[1]
    [x * wc::SH[0] + y * wc::SH[1], x * wc::NH[0] + y * wc::NH[1]]
  end
  front = m.entities.select { |e| pids.include?(e.persistent_id) }.map do |e|
    b = e.definition.bounds
    (0..7).map { |i| sd.(b.corner(i).transform(e.transformation)) }
  end.select { |cs| cs.map(&:last).min > ds - 2 }.flatten(1)
  if front.empty?
    puts 'WARNING: no platform/ramp found in front of the N face; platform dims skipped'
  else
    ztop = m.entities.select { |e| pids.include?(e.persistent_id) }.select { |e| e.bounds.min.z >= o[2] - 1 }
            .map { |e| e.bounds.max.z }.select { |zz| zz < o[2] + 24 }.max || (o[2] + 8.0)
    up = ->(q) { Geom::Point3d.new(q.x, q.y, ztop + 0.1) }
    ds_ = g[:d_shell]
    # booth door N3 off the booth's NE corner (observed booth-local x 121.25-165.75), on the platform top
    dim.(up.(S.(so + 165.75, ds_ + 6)), up.(S.(se, ds_ + 6)), NHv, 1, t_d)
    dim.(up.(S.(so + 121.25, ds_ + 6)), up.(S.(so + 165.75, ds_ + 6)), NHv, 1, t_d)
    z0 = front.map(&:first).min
    z1 = front.map(&:first).max
    d1 = front.map(&:last).max
    pb = c['RAMP_DIR'] == 'open' ? so + c['PLAT'][1] : so + c['PLAT'][0]   # platform/ramp joint (scaled)
    dim.(up.(S.(z0, ds_ + 36)), up.(S.(pb, ds_ + 36)), NHv, 1, t_b)
    dim.(up.(S.(pb, ds_ + 36)), up.(S.(z1, ds_ + 36)), NHv, 1, t_b)
    puts format('platform-top dims at z %.2f above floor (measured max of the platform/ramp groups)', ztop - o[2])
    dim.(S.(z1, ds), S.(z1, d1), SHv, 20, t_b)
    puts format('platform+ramp measured: s %.2f..%.2f, d %.2f..%.2f (joint at s %.2f is the scaled 12 Oct figure)', z0, z1, ds, d1, pb)
  end
  # one note, clear of the drawing
  t = E.add_text(%(New walls square to the exterior wall. Walls the architect did not dimension are approximate. Ceiling 8'-0" assumed.),
                 W.([0.0, wc::Y_S - 120.0]))
  t.layer = t_n
  m.commit_operation
rescue Exception => e
  m.abort_operation
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(5)
  raise
end
m.save
made.each { |tg, v| puts "  #{tg.ljust(14)} #{wc.ft(v)}  (#{v})" }
puts "#{made.size} dims; saved #{m.path}"
