# Walsh v3 step 4: place the booth. End-on to the exterior (diagonal) wall: E end (booth-local x = 170) 1" off
# the exterior wall face, long axis square to it, W door end toward the south wall; N (windows) toward the
# apex. Booth-local x -> -NH (d = 171 - x), y -> +SH (s = S0 + y). Keeps the build's z lift. Rigid move only.
load File.join(File.dirname(__FILE__), 'geom.rb')
wc = WalshCorner
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
S0 = defined?($walsh_s0) ? $walsh_s0.to_f : 47.0
GAP = 1.0
o = m.get_attribute('WalshCorner', 'origin')
b = m.entities.find { |e| e.persistent_id == m.get_attribute('WalshRM', 'booth_pid') } or raise 'booth not found'
z0 = b.transformation.origin.z
org = wc.p(S0, GAP + 170.0)
t = Geom::Transformation.axes(Geom::Point3d.new(o[0] + org[0], o[1] + org[1], o[2] + z0),
                              Geom::Vector3d.new(-wc::NH[0], -wc::NH[1], 0), Geom::Vector3d.new(wc::SH[0], wc::SH[1], 0), Z_AXIS)
m.start_operation('Walsh v3: place booth', true)
begin
  b.transformation = t
  b.name = 'Booth - MDL 96168 S RM (21 Oct link)'
  m.set_attribute('WalshRM', 's0', S0)
  m.commit_operation
rescue Exception => e
  m.abort_operation
  raise
end
WalshRM.save(m)
# measure: every vertex of the booth in (s, d)
ss = []
ds = []
zs = []
walk = lambda do |ents, tr|
  ents.each do |e|
    if e.respond_to?(:definition)
      walk.(e.definition.entities, tr * e.transformation)
    elsif e.is_a?(Sketchup::Edge)
      e.vertices.each do |v|
        p = v.position.transform(tr)
        s, d = WalshRM.sd(p.x.to_f - o[0], p.y.to_f - o[1])
        ss << s
        ds << d
        zs << p.z.to_f
      end
    end
  end
end
walk.(b.definition.entities, b.transformation)
puts format('booth all geometry: s %.2f..%.2f  d %.2f..%.2f  z %.2f..%.2f', ss.min, ss.max, ds.min, ds.max, zs.min, zs.max)
[[S0, 'S face (corner side)'], [S0 + 47, 'W1 door, corner-side jamb'], [S0 + 96, 'W1 door, apex-side jamb'], [S0 + 98, 'N face']].each do |s, n|
  puts format('  %-28s s %.2f  room depth %.2f  clear beyond the W end (d 171) %.2f', n, s, wc.d_on_y(s, wc::Y_S), wc.d_on_y(s, wc::Y_S) - 171.0)
end
puts "saved #{m.path}"
