$wr_no_autorun = true
unless defined?(WR_Overlays)
  load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/build-booth-components.rb'
  load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-overlays.rb'
end
m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
bt = b.transformation; bi = bt.inverse
defs = {}; gx = {}
%w[Audimute2x4 Audimute1x4 Audimute1x2].each { |n| defs[n] = m.definitions[n]; gx[n] = WR_Overlays.geom_extents(defs[n]) }
up = Geom::Vector3d.new(0, 0, 1)
walls = { back: { n: Geom::Vector3d.new(1, 0, 0), face: 6.3 }, left: { n: Geom::Vector3d.new(0, 1, 0), face: 9.0 },
          right: { n: Geom::Vector3d.new(0, -1, 0), face: 122.4 } }
lay = m.layers['WR-Booth-Acoustic']
log = []
place = lambda do |name, wall, r0, ztop, horizontal = false|
  w = walls[wall]; n = w[:n]; g = gx[name]
  ya = n.reverse                       # this part's fabric faces its local -y
  if horizontal then xa = up; za = xa * ya else za = up; xa = ya * za end
  rot = Geom::Transformation.axes(ORIGIN, xa, ya, za)
  pts = [g[:lo], g[:hi]].product([g[:lo], g[:hi]], [g[:lo], g[:hi]]).map { |a, c, d| Geom::Point3d.new(a[0], c[1], d[2]).transform(rot) }
  run_is_x = n.x.abs < 0.5
  nv = pts.map { |p| run_is_x ? p.y : p.x }
  back = (run_is_x ? n.y : n.x) > 0 ? nv.min : nv.max
  d_run = r0 - pts.map { |p| run_is_x ? p.x : p.y }.min
  v = run_is_x ? Geom::Vector3d.new(d_run, w[:face] - back, ztop - pts.map(&:z).max) : Geom::Vector3d.new(w[:face] - back, d_run, ztop - pts.map(&:z).max)
  inst = b.definition.entities.add_instance(defs[name], bi * Geom::Transformation.translation(v) * rot)
  inst.layer = lay; inst.name = "#{name} #{wall}"
  log << format('%-12s %-5s run %6.2f..%6.2f top %.2f', name, wall, r0, r0 + (horizontal ? 48 : (name == 'Audimute1x4' ? 12 : 24)), ztop)
end
wb = lambda { |e| bb = Geom::BoundingBox.new; (0..7).each { |k| bb.add(e.definition.bounds.corner(k).transform(bt * e.transformation)) }; bb }
ents = b.definition.entities.grep(Sketchup::ComponentInstance)
foams = ents.select { |e| e.definition.name == 'Foam' }
left_f  = foams.select { |e| wb.call(e).min.y < 12 }.sort_by { |e| wb.call(e).min.x }
right_f = foams.select { |e| wb.call(e).min.y > 118 }.sort_by { |e| wb.call(e).min.x }
raise "foams left=#{left_f.length} right=#{right_f.length} total=#{foams.length}" unless left_f.length == 3 && right_f.length == 3 && foams.length == 6
T = 81.56; BAND = T - 12; ROW = BAND - 48  # top row 69.56..81.56, band 21.56..69.56, bottom row 9.56..21.56
move_to = lambda { |e, p| bb = wb.call(e); e.transform!(bi * Geom::Transformation.translation(Geom::Vector3d.new(p[0] - bb.min.x, p[1] - bb.min.y, p[2] - bb.min.z)) * bt) }
spin = lambda { |e, deg| e.transform!(bi * Geom::Transformation.rotation(wb.call(e).center, up, deg.degrees) * bt) }

m.start_operation('Acoustic layout v2: mixed back band, matching side walls', true)
ents.select { |e| e.name =~ /^Audimute/ }.each(&:erase!)
# BACK: top row, band 1x4|foam|2x4|foam|1x4, bottom row
4.times { |i| place.call('Audimute1x2', :back, 17.75 + 24 * i, T) }
place.call('Audimute1x4', :back, 17.75, BAND); place.call('Audimute2x4', :back, 53.75, BAND); place.call('Audimute1x4', :back, 101.75, BAND)
4.times { |i| place.call('Audimute1x2', :back, 17.75 + 24 * i, ROW) }
spin.call(left_f[1], -90);  move_to.call(left_f[1],  [6.3, 29.75, ROW])
spin.call(right_f[1], 90);  move_to.call(right_f[1], [6.3, 77.75, ROW])
# SIDES, identical: top 2 x 1x2 (x 27..75), band foam|2x4|foam (x 15..87), bottom 1x4 flat (x 27..75)
{ left: [left_f, 9.0], right: [right_f, 120.4] }.each do |wall, (fs, y)|
  place.call('Audimute1x2', wall, 27, T); place.call('Audimute1x2', wall, 51, T)
  move_to.call(fs[0], [15, y, ROW]); move_to.call(fs[2], [63, y, ROW])
  place.call('Audimute2x4', wall, 39, BAND)
  place.call('Audimute1x4', wall, 27, ROW, true)
end
m.commit_operation
puts log
b.definition.entities.grep(Sketchup::ComponentInstance).select { |e| e.definition.name == 'Foam' }.each { |e| bb = wb.call(e); puts format('Foam [%.2f..%.2f, %.2f..%.2f, %.2f..%.2f]', bb.min.x, bb.max.x, bb.min.y, bb.max.y, bb.min.z, bb.max.z) }
puts 'counts: ' + b.definition.entities.grep(Sketchup::ComponentInstance).select { |e| e.name =~ /^Audimute/ }.map { |e| e.definition.name }.tally.inspect
nil
