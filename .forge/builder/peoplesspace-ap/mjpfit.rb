m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
bt = b.transformation
md = m.definitions['MJP']
gx = WR_Overlays.geom_extents(md)
b.definition.entities.grep(Sketchup::ComponentInstance).select { |e| e.name.start_with?('MJP interior (window', 'MJP exterior (window') }.each do |inst|
  t = inst.transformation
  ys = []; xs = []; zs = []
  [gx[:lo], gx[:hi]].product([gx[:lo], gx[:hi]], [gx[:lo], gx[:hi]]).each { |a, bb2, c| q = Geom::Point3d.new(a[0], bb2[1], c[2]).transform(t); xs << q.x; ys << q.y; zs << q.z }
  interior = inst.name.start_with?('MJP interior')
  back = interior ? ys.min : ys.max        # local: room is +y
  mid = Geom::Point3d.new((xs.min + xs.max) / 2, 0, zs.max - 1.0)
  # ray from 10 in into the room (or outside), toward the wall, in world coords, hiding the part itself
  inst.hidden = true
  start_l = Geom::Point3d.new(mid.x, interior ? back + 10 : back - 10, mid.z)
  dir_l = Geom::Vector3d.new(0, interior ? -1 : 1, 0)
  hit = m.raytest([start_l.transform(bt), dir_l.transform(bt)], true)
  inst.hidden = false
  if hit
    wl = hit[0].transform(bt.inverse)
    puts format('%-28s geom-back y=%.3f  wall face y=%.3f  gap=%.3f  hit=%s  geom z %.2f..%.2f x %.2f..%.2f', inst.name, back, wl.y, back - wl.y, hit[1].last.class, zs.min, zs.max, xs.min, xs.max)
  else
    puts "#{inst.name}: no hit"
  end
end
nil
