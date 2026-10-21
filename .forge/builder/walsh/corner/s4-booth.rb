# Walsh corner: step 4. Move the Platform-copy booth assembly (booth + platform + ramp + its lights) as a unit
# into the new corner, back on the exterior wall, W0 end at the corner wall, shell 11 5/8" off both.
# Rigid move T_delta = T_new * T_cur^-1, where T_cur is the 12 Oct booth-local frame (shell SW corner at
# room-local (61.89, 11.63), axis-aligned; notes.md "Shell") and T_new puts that frame on (s, d).
# RAMP_DIR 'open' (default): the ramp is also mirrored about the platform centre (booth-local x = 144) so it
# runs toward the open end; 'corner' leaves it where Benton drew it (toward the corner wall).
# $walsh_dry = true -> report only.
load File.join(File.dirname(__FILE__), 'geom.rb')
DRY = defined?($walsh_dry) ? $walsh_dry : false
wc = WalshCorner
m = Sketchup.active_model
o = m.get_attribute('WalshCorner', 'origin') or raise 'run s2-retag.rb first'
pids = m.get_attribute('WalshCorner', 'movers') || []
raise 'already moved (WalshCorner/moved set); Ctrl+Z first' if m.get_attribute('WalshCorner', 'moved') && !DRY
ents = m.entities.select { |e| pids.include?(e.persistent_id) }
# lights over the old Platform booth travel with it
o3 = Geom::Point3d.new(*o)
SHELL0 = [61.89, 11.63]
c = wc::CFG
t_cur = Geom::Transformation.translation(Geom::Vector3d.new(o[0] + SHELL0[0], o[1] + SHELL0[1], o[2]))
org = wc.p(c['SHELL_OFF'], c['SHELL_OFF'])
xa = Geom::Vector3d.new(wc::SH[0], wc::SH[1], 0)
ya = Geom::Vector3d.new(wc::NH[0], wc::NH[1], 0)
t_new = Geom::Transformation.axes(Geom::Point3d.new(o[0] + org[0], o[1] + org[1], o[2]), xa, ya, Z_AXIS)
t_delta = t_new * t_cur.inverse
mirror = Geom::Transformation.new([-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 2.0 * 144.0, 0, 0, 1])
t_ramp = t_new * mirror * t_cur.inverse
nm = ->(e) { e.is_a?(Sketchup::Group) ? e.name.to_s : "#{e.name} #{e.definition.name}" }
local = ->(e) { b = e.bounds; [b.min.transform(t_cur.inverse), b.max.transform(t_cur.inverse)] }
# Everything wholly in front of the booth's N face is the platform + ramp. Mirroring ALL of it about the
# platform centre (x = 144) maps the platform (122-166) onto itself and the ramp (74-122) onto 166-214,
# whether Benton drew them as one group or two.
ramps = ents.select { |e| local.(e)[0].y > c['BD'] - 2 }
puts "moving #{ents.size}: " + ents.map { |e| "#{nm.(e)}[#{local.(e).map { |q| q.to_a.first(2).map { |v| v.to_f.round(1) } }}]" }.join('; ')
puts "in front of N face (mirrored if RAMP_DIR open): #{ramps.map { |e| nm.(e) }}"
raise 'nothing found in front of the N face: platform/ramp not in the mover set' if ramps.empty? && c['RAMP_DIR'] == 'open'
ramps = [] unless c['RAMP_DIR'] == 'open'
if DRY
  puts 'DRY: nothing moved'
else
m.start_operation('Walsh corner: move booth', true)
begin
  ents.each { |e| e.transform!(ramps.include?(e) ? t_ramp : t_delta) }
  m.set_attribute('WalshCorner', 'moved', true)
  m.set_attribute('WalshCorner', 't_delta', t_delta.to_a)
  m.commit_operation
rescue Exception => e
  m.abort_operation
  raise
end
m.save
# verification by bounds in the (s, d) frame (take-off coords, world minus O)
sd = lambda do |pt|
  x = pt.x - o[0] - wc::C[0]
  y = pt.y - o[1] - wc::C[1]
  [x * wc::SH[0] + y * wc::SH[1], x * wc::NH[0] + y * wc::NH[1]]
end
ents.each do |e|
  b = e.definition.bounds
  cs = (0..7).map { |i| sd.(b.corner(i).transform(e.transformation)) }
  puts format('  %-40s s %.1f..%.1f  d %.1f..%.1f  z %.1f..%.1f', nm.(e)[0, 40], cs.map(&:first).min, cs.map(&:first).max,
              cs.map(&:last).min, cs.map(&:last).max, b.min.z - o[2], b.max.z - o[2])
end
g = wc.solve
puts "walls: front d=#{g[:d_f].round(2)} (s 0..#{g[:s_step]}), zone d=#{g[:d_z].round(2)} (s #{g[:s_step]}..#{g[:s_ang]}), angled s=#{g[:s_ang]}"
puts "saved #{m.path}"
end
