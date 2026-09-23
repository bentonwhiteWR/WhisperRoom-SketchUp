$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/build-booth-components.rb'
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-overlays.rb'
m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
bt = b.transformation; bi = bt.inverse
dir = 'P:/Sketchup/NewMasterComponentList'
defs = {}
%w[Audimute2x4 Audimute1x4 Audimute1x2].each { |n| defs[n] = m.definitions[n] || m.definitions.load(File.join(dir, n + '.skp')) }
gx = defs.transform_values { |d| WR_Overlays.geom_extents(d) }
gx.each { |n, g| puts "#{n} geom lo=#{g[:lo].map { |v| v.round(2) }} hi=#{g[:hi].map { |v| v.round(2) }}" }
UP = Geom::Vector3d.new(0, 0, 1)
CEIL = 81.56
# world-space wall: face coordinate, into-room normal, run axis
WALLS = {
  back:  { n: Geom::Vector3d.new(1, 0, 0),  face: 6.3 },
  left:  { n: Geom::Vector3d.new(0, 1, 0),  face: 9.0 },
  right: { n: Geom::Vector3d.new(0, -1, 0), face: 122.4 }
}
lay = m.layers['WR-Booth-Acoustic'] || m.layers.add('WR-Booth-Acoustic')
placed = []
# place a part so its GEOMETRY spans run [r0, r0+w] along the wall's run axis (world x or y), top at ztop
place = lambda do |name, wall, r0, ztop, horizontal = false|
  w = WALLS[wall]; n = w[:n]; g = gx[name]
  if horizontal # local z (long) along the wall, local x up
    xa = UP; ya = n; za = xa * ya
  else          # local x along the wall, local z up
    ya = n; za = UP; xa = ya * za
  end
  rot = Geom::Transformation.axes(ORIGIN, xa, ya, za)
  pts = [g[:lo], g[:hi]].product([g[:lo], g[:hi]], [g[:lo], g[:hi]]).map { |a, c, d| Geom::Point3d.new(a[0], c[1], d[2]).transform(rot) }
  run_is_x = n.x.abs < 0.5
  rmin = pts.map { |p| run_is_x ? p.x : p.y }.min
  nvals = pts.map { |p| run_is_x ? p.y : p.x }
  back = (run_is_x ? n.y : n.x) > 0 ? nvals.min : nvals.max
  zmax = pts.map(&:z).max
  d_run = r0 - rmin; d_n = w[:face] - back; d_z = ztop - zmax
  v = run_is_x ? Geom::Vector3d.new(d_run, d_n, d_z) : Geom::Vector3d.new(d_n, d_run, d_z)
  world = Geom::Transformation.translation(v) * rot
  inst = b.definition.entities.add_instance(defs[name], bi * world)
  inst.layer = lay; inst.name = "#{name} #{wall}"
  wr = pts.map { |p| p.transform(Geom::Transformation.translation(v)) }
  placed << format('%-12s %-5s run %.2f..%.2f  z %.2f..%.2f', name, wall, *(run_is_x ? wr.map(&:x).minmax : wr.map(&:y).minmax), *wr.map(&:z).minmax)
end

m.start_operation('Audimute acoustic package (back + left walls)', true)
top = CEIL; r1 = CEIL - 48; r2 = r1 - 12
# BACK wall, 96 wide centred on the usable run 11.9..119.6 -> 17.75..113.75
y = 17.75
[['Audimute1x4', 12], ['Audimute2x4', 24], ['Audimute2x4', 24], ['Audimute2x4', 24], ['Audimute1x4', 12]].each { |nm, wd| place.call(nm, :back, y, top); y += wd }
[r1, r2].each { |zt| 4.times { |i| place.call('Audimute1x2', :back, 17.75 + 24 * i, zt) } }
# LEFT wall rows under a 72-wide foam band at x 15..87 (staggered)
place.call('Audimute1x4', :left, 15, r1, true); place.call('Audimute1x2', :left, 63, r1)
place.call('Audimute1x2', :left, 15, r2);       place.call('Audimute1x4', :left, 39, r2, true)
# RIGHT (far short) wall: the 2 spare 1x2, top-aligned, centred on x 51
place.call('Audimute1x2', :right, 27, top); place.call('Audimute1x2', :right, 51, top)

# FOAM moves (world bounds targets)
foams = b.definition.entities.grep(Sketchup::ComponentInstance).select { |e| e.definition.name == 'Foam' }
wb = lambda { |e| bb = Geom::BoundingBox.new; (0..7).each { |k| bb.add(e.definition.bounds.corner(k).transform(bt * e.transformation)) }; bb }
move_to = lambda do |e, min_pt|
  bb = wb.call(e); v = Geom::Vector3d.new(min_pt[0] - bb.min.x, min_pt[1] - bb.min.y, min_pt[2] - bb.min.z)
  e.transform!(bi * Geom::Transformation.translation(v) * bt)
end
spin = lambda do |e, deg|
  c = wb.call(e).center
  e.transform!(bi * Geom::Transformation.rotation(c, UP, deg.degrees) * bt)
end
left_f = foams.select { |e| wb.call(e).min.y < 12 }.sort_by { |e| wb.call(e).min.x }
back_f = foams.select { |e| wb.call(e).max.x < 12 }.sort_by { |e| wb.call(e).min.y }
raise "foam count left=#{left_f.length} back=#{back_f.length}" unless left_f.length == 2 && back_f.length == 2
fz = r1  # band bottom
move_to.call(left_f[0], [15, 9.0, fz]); move_to.call(left_f[1], [63, 9.0, fz])
spin.call(back_f[0], -90); move_to.call(back_f[0], [39, 9.0, fz])
spin.call(back_f[1], 90);  move_to.call(back_f[1], [39, 120.4, 17.81])
m.commit_operation
puts placed
(left_f + back_f).each { |e| bb = wb.call(e); puts format('Foam -> [%.2f..%.2f, %.2f..%.2f, %.2f..%.2f]', bb.min.x, bb.max.x, bb.min.y, bb.max.y, bb.min.z, bb.max.z) }
nil
