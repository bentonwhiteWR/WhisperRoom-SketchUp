m = Sketchup.active_model
rt = lambda { |o, d, label| h = m.raytest([Geom::Point3d.new(*o), Geom::Vector3d.new(*d)], true); puts format('%-26s -> %s  (%s)', label, h ? h[0].to_a.map { |v| v.to_f.round(2) }.inspect : 'miss', h ? h[1].map { |e| e.respond_to?(:definition) ? e.definition.name : e.class.name.split('::').last }.join(' > ') : '') }
[[30, 60], [60, 40], [50, 100]].each do |x, y|
  rt.call([x, y, 40], [0, 0, 1], "ceiling up @#{x},#{y}")
  rt.call([x, y, 40], [0, 0, -1], "floor down @#{x},#{y}")
end
[30, 60, 100].each { |y| [20, 50, 75].each { |z| rt.call([50, y, z], [-1, 0, 0], "back wall y#{y} z#{z}") } }
[30, 60, 85].each { |x| [20, 50, 75].each { |z| rt.call([x, 65, z], [0, -1, 0], "left wall x#{x} z#{z}") } }
[20, 60].each { |z| rt.call([50, 65, z], [1, 0, 0], "front wall z#{z}"); rt.call([50, 65, z], [0, 1, 0], "right wall z#{z}") }
nil
