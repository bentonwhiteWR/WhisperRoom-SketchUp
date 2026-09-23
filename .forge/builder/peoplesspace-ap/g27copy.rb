m = Sketchup.active_model
d27 = m.definitions['Group#27']; d28 = m.definitions['Group#28']
g27 = d27.instances.first
src = d28.entities.grep(Sketchup::ComponentInstance).select { |e| e.name =~ /^Audimute/ || e.definition.name == 'Foam' }
old = d27.entities.grep(Sketchup::ComponentInstance).select { |e| e.definition.name == 'Foam' || e.name =~ /^Audimute/ }
raise "source has #{src.length} pieces, expected 25" unless src.length == 25
m.start_operation('Right-door booth: acoustic layout copied from the worked booth', true)
old.each(&:erase!)
src.each do |e|
  c = d27.entities.add_instance(e.definition, e.transformation)
  c.layer = e.layer; c.name = e.name
end
m.commit_operation
now = d27.entities.grep(Sketchup::ComponentInstance).select { |e| e.name =~ /^Audimute/ || e.definition.name == 'Foam' }
puts "deleted #{old.length} old foam; Group#27 now holds #{now.map { |e| e.definition.name }.tally.inspect}"
# seat check: ray from each panel's centre toward its wall, in world, against Group#27
bt = g27.transformation
dirs = { 'back' => [-1, 0, 0], 'left' => [0, -1, 0], 'right' => [0, 1, 0] }
now.each { |e| e.hidden = true }
res = now.map do |e|
  bb = Geom::BoundingBox.new; (0..7).each { |k| bb.add(e.definition.bounds.corner(k).transform(bt * e.transformation)) }
  wall = e.name =~ /^Audimute/ ? e.name.split.last : (bb.width < 3 ? 'back' : (bb.center.y < 60 ? 'left' : 'right'))
  v = Geom::Vector3d.new(*dirs[wall]).transform(bt)
  hit = m.raytest([bb.center, v], true)
  back = [bb.min, bb.max].map { |p| p.to_a }.transpose  # [[minx,maxx],[miny,maxy],[minz,maxz]]
  axis = v.x.abs > 0.5 ? 0 : 1
  near = v.to_a[axis] < 0 ? back[axis][0] : back[axis][1]
  [e.definition.name, wall, hit ? (near - hit[0].to_a[axis]).abs.round(2) : 'miss', hit ? (hit[1][-2].respond_to?(:definition) ? hit[1][-2].definition.name : '?') : '']
end
now.each { |e| e.hidden = false }
res.group_by { |r| r[0..1] }.each { |k, rs| puts "#{k.join(' ')} x#{rs.length}: bounds-to-wall #{rs.map { |r| r[2] }.uniq.inspect}  wall hit #{rs.map { |r| r[3] }.uniq.first(2).inspect}" }
nil
