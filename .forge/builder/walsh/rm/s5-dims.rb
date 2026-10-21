# Walsh v3 step 5: floor dims (numbers only) for the RM layout + the booth door swing arc. One group,
# so a re-run is one erase. Room walls (WR-Dims), room doors off their corners (WR-Dims-Doors), booth
# overall / gaps / booth door off its corner (WR-Dims-Booth / WR-Dims-Doors). Booth door geometry is
# measured live: frame booth-local y 47-96, leaf hinge at the y-53.73 jamb (S side), leaf 35.37 wide, outswing.
load File.join(File.dirname(__FILE__), 'geom.rb')
wc = WalshCorner
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
o = m.get_attribute('WalshCorner', 'origin')
s0 = m.get_attribute('WalshRM', 's0').to_f
raise 'place the booth first' unless s0 > 0
NAME = 'RM Dims 21 Oct'
m.entities.grep(Sketchup::Group).select { |g| g.name == NAME }.each(&:erase!)
lay = ->(n) { m.layers[n] || m.layers.add(n) }
t_w = lay.('WR-Dims'); t_d = lay.('WR-Dims-Doors'); t_b = lay.('WR-Dims-Booth'); t_door = lay.('WR-Doors')
z = o[2] + 0.05
W = ->(xy) { Geom::Point3d.new(o[0] + xy[0], o[1] + xy[1], z) }
S = ->(s, d) { W.(wc.p(s, d)) }
SHv = Geom::Vector3d.new(wc::SH[0], wc::SH[1], 0)
NHv = Geom::Vector3d.new(wc::NH[0], wc::NH[1], 0)
b = m.entities.find { |e| e.persistent_id == m.get_attribute('WalshRM', 'booth_pid') } or raise 'booth not found'
w1 = b.entities.find { |e| e.name.split(' ').first == 'W1' } or raise 'W1 not found'
fr = w1.definition.entities.find { |e| e.respond_to?(:definition) && e.definition.name =~ /door frame/i } or raise 'frame'
hinges = fr.definition.entities.select { |e| e.respond_to?(:definition) && e.definition.name =~ /Hinge/ }
fb = Geom::BoundingBox.new
(0..7).each { |i| fb.add(fr.definition.bounds.corner(i).transform(w1.transformation * fr.transformation)) }
hy = hinges.map { |h| h.bounds.center.transform(w1.transformation * fr.transformation).y }.sum / hinges.size
leaf = w1.definition.entities.find { |e| e.respond_to?(:definition) && e.definition.name !~ /frame/i } or raise 'leaf'
lb = Geom::BoundingBox.new
(0..7).each { |i| lb.add(leaf.definition.bounds.corner(i).transform(w1.transformation * leaf.transformation)) }
j0 = fb.min.y.to_f; j1 = fb.max.y.to_f
hinge_y = (hy - lb.min.y).abs < (hy - lb.max.y).abs ? lb.min.y.to_f : lb.max.y.to_f
free_y = hinge_y == lb.min.y.to_f ? lb.max.y.to_f : lb.min.y.to_f
rad = (free_y - hinge_y).abs
puts format('booth door frame y %.2f..%.2f, leaf y %.2f..%.2f, hinge at y %.2f, leaf %.2f', j0, j1, lb.min.y, lb.max.y, hinge_y, rad)
room = WalshRM.room   # A, C, G, SW, WTOP
gx = room[2][0]
made = []
m.start_operation('Walsh v3: dims', true)
begin
  grp = m.entities.add_group
  grp.name = NAME
  e = grp.entities
  dim = lambda do |a, bb, dir, dist, tag|
    v = Geom::Vector3d.new(dir.x, dir.y, 0); v.length = dist
    d = e.add_dimension_linear(a, bb, v); d.layer = tag
    made << [tag.name, a.distance(bb).to_f.round(2)]
    d
  end
  out_c = SHv.reverse
  ext = NHv.reverse
  dG = wc.d_on_y(0, wc::Y_S)
  # corner wall (existing, square to the exterior wall)
  dim.(S.(0, 0), S.(0, dG), out_c, 20, t_w)
  # exterior wall: booth chain (row 1) + overall (row 2)
  dim.(S.(0, 0), S.(s0, 0), ext, 20, t_b)
  dim.(S.(s0, 0), S.(s0 + 98, 0), ext, 20, t_b)
  dim.(S.(s0 + 98, 0), W.(wc::A), ext, 20, t_b)
  dim.(S.(0, 0), W.(wc::A), ext, 48, t_w)
  # booth length (170) + 1" off the exterior wall, beside the N face
  dim.(S.(s0 + 98, 0), S.(s0 + 98, 1), SHv, 24, t_b)
  dim.(S.(s0 + 98, 1), S.(s0 + 98, 171), SHv, 24, t_b)
  # booth door off the booth corner, along the W end (d 171), outside the booth
  sj0 = s0 + j0; sj1 = s0 + j1
  dim.(S.(s0, 171), S.(sj0, 171), NHv, 46, t_d)
  dim.(S.(sj0, 171), S.(sj1, 171), NHv, 46, t_d)
  dim.(S.(sj1, 171), S.(s0 + 98, 171), NHv, 46, t_d)
  # south wall: doors row (corner -> jamb -> width) + overall
  dn = Geom::Vector3d.new(0, -1, 0)
  ys = wc::Y_S
  [[0.0, 4.0], [4.0, 40.0], [gx - 48.0, gx - 12.0], [gx - 12.0, gx]].each { |a, bb| dim.(W.([a, ys]), W.([bb, ys]), dn, 20, t_d) }
  dim.(W.([0.0, ys]), W.([gx, ys]), dn, 48, t_w)
  # west + NW
  dim.(W.([0.0, ys]), W.(wc::WTOP), Geom::Vector3d.new(-1, 0, 0), 20, t_w)
  nw = Geom::Vector3d.new(-(wc::A[1] - wc::WTOP[1]), wc::A[0] - wc::WTOP[0], 0)
  dim.(W.(wc::WTOP), W.(wc::A), nw, 20, t_w)
  # booth door swing arc (plan symbol): hinge at the W face, leaf radius, closed along +s -> open along +d
  sh = s0 + hinge_y
  ctr = S.(sh, 170.5)
  sgn = free_y > hinge_y ? 1.0 : -1.0
  xa = Geom::Vector3d.new(wc::SH[0] * sgn, wc::SH[1] * sgn, 0)
  nrm = xa * NHv
  arc = if nrm.z > 0
          e.add_arc(ctr, xa, Z_AXIS, rad, 0, Math::PI / 2)
        else
          e.add_arc(ctr, xa, Z_AXIS.reverse, rad, 0, Math::PI / 2)
        end
  e.add_line(ctr, S.(sh, 170.5 + rad)).layer = t_door
  arc.each { |ed| ed.layer = t_door }
  dmax = arc.flat_map { |ed| ed.vertices.map { |v| WalshRM.sd(v.position.x - o[0], v.position.y - o[1])[1] } }.max
  puts format('swing arc hinge s %.2f, reaches d %.2f; room depth there %.2f', sh, dmax, wc.d_on_y(sh, wc::Y_S))
  m.commit_operation
rescue Exception => ex
  m.abort_operation
  puts "FAILED #{ex.class}: #{ex.message}"; puts ex.backtrace.first(4)
  raise
end
WalshRM.save(m)
made.each { |tg, v| puts "  #{tg.ljust(14)} #{wc.ft(v)}  (#{v})" }
puts "#{made.size} dims; saved #{m.path}"
