# Walsh corner: step 4 (as found). Re-place the PLATFORM booth group: its local frame IS the shell frame
# (x 0..170 W->E, y 0..98 S->N, observed), so set its transformation to the (s, d) frame with the shell
# 11 5/8" off the corner wall and the exterior wall. Keep its z (1.313, observed). With RAMP_DIR 'open',
# mirror Component#17 (platform tiles booth-local x 120.37-166.37, ramp 74.77-120.37, observed) about the
# platform centre x = 143.37 so the ramp runs toward the open end. Rigid; nothing else touched.
load File.join(File.dirname(__FILE__), 'geom.rb')
DRY = defined?($walsh_dry) ? $walsh_dry : false
wc = WalshCorner
m = Sketchup.active_model
o = m.get_attribute('WalshCorner', 'origin') or raise 'run s2b-retag.rb first'
raise 'already moved (WalshCorner/moved set); Ctrl+Z first' if m.get_attribute('WalshCorner', 'moved') && !DRY
pid = (m.get_attribute('WalshCorner', 'movers') || [])[0]
pb = m.entities.find { |e| e.persistent_id == pid } or raise 'PLATFORM booth not found'
c17 = pb.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Component#17' } or raise 'no Component#17'
c = wc::CFG
z0 = pb.transformation.origin.z
org = wc.p(c['SHELL_OFF'], c['SHELL_OFF'])
t_new = Geom::Transformation.axes(Geom::Point3d.new(o[0] + org[0], o[1] + org[1], o[2] + z0),
                                  Geom::Vector3d.new(wc::SH[0], wc::SH[1], 0), Geom::Vector3d.new(wc::NH[0], wc::NH[1], 0), Z_AXIS)
mc = (c['PLAT'][0] + c['PLAT'][1]) / 2.0
mirror = Geom::Transformation.new([-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 2.0 * mc, 0, 0, 1])
puts "booth z #{z0.to_f.round(3)}; new origin take-off #{org.map { |v| v.round(3) }}; mirror about x #{mc}"
unless DRY
  m.start_operation('Walsh corner: move booth', true)
  begin
    pb.transformation = t_new
    c17.transform!(mirror) if c['RAMP_DIR'] == 'open'
    m.set_attribute('WalshCorner', 'moved', true)
    m.commit_operation
  rescue Exception => e
    m.abort_operation
    raise
  end
  WalshCorner.save(m)
end
sd = lambda do |pt|
  x = pt.x - o[0] - wc::C[0]
  y = pt.y - o[1] - wc::C[1]
  [x * wc::SH[0] + y * wc::SH[1], x * wc::NH[0] + y * wc::NH[1]]
end
rep = lambda do |label, ent, tr|
  b = ent.definition.bounds
  cs = (0..7).map { |i| b.corner(i).transform(tr) }
  q = cs.map { |p| sd.(p) }
  puts format('  %-22s s %.2f..%.2f  d %.2f..%.2f  z %.2f..%.2f', label, q.map(&:first).min, q.map(&:first).max,
              q.map(&:last).min, q.map(&:last).max, cs.map(&:z).min - o[2], cs.map(&:z).max - o[2])
end
rep.('booth (all)', pb, pb.transformation)
pb.entities.each do |e|
  next unless e.respond_to?(:definition)
  next unless %w[N3 W0 S0 E0].include?(e.name) || e == c17
  rep.(e == c17 ? 'platform+ramp' : e.name, e, pb.transformation * e.transformation)
end
c17.definition.entities.each do |e|
  next unless e.respond_to?(:definition)
  rep.(e.definition.name, e, pb.transformation * c17.transformation * e.transformation) if e.definition.name =~ /ramp|#243/
end
g = wc.solve
puts "walls: front d=#{g[:d_f].round(2)} (s 0..#{g[:s_step]}), zone d=#{g[:d_z].round(2)} (s #{g[:s_step]}..#{g[:s_ang]}), angled s=#{g[:s_ang]}, zone #{g[:zone].map { |v| v.round(2) }}"
puts "saved #{m.path}" unless DRY
