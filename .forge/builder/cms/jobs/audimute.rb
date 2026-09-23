# Copies of Benton's Audimute 2 x 4 (definition "Component#11", NOT modified) inside the booth, flush on
# the IEP inner wall faces in the 24 in gaps between the foam sheets. Instances go INSIDE the booth group
# so they travel with it. His original instance (corridor, X -59..-35) is left where he put it.
# Definition frame (measured): X 0..24 width, Z 0..48 height, Y 0..1.62 thickness; hangers on +Y, so the
# panel face is Y = 0 facing -Y and the +Y side goes against the wall.
# World targets (measured off the built parts, 22 Sep):
#   N (back) wall face Y 249.37; gaps X 55.32-79.32 and 103.32-127.32. The duct covers straddle both
#     gaps and leave 47.18 in clear; a 48 in panel is seated mid-way (z 22.51-70.51), so each touches
#     two duct-cover corners by ~0.8 x 0.4 in -- reported, not hidden.
#   E wall face X 160.00; gap Y 192.74-216.74; no vent hardware. On the foam line, z 22.56-70.56.
#   W wall face X 22.69; gap Y 192.74-216.74; the W1 hi duct cover starts at z 70.10 over Y 215.95+,
#     so the panel sits 0.5 in below the foam line, z 22.06-70.06 (clear).
m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:name) && e.name == 'MDL 96144 E (components)' }
d = m.definitions['Component#11']
raise 'no Component#11' unless d
th = d.bounds.max.y.to_f
bt = b.transformation
rz = ->(deg) { Geom::Transformation.rotation(ORIGIN, Z_AXIS, deg.degrees) }
spots = [
  ['Audimute 2x4 - N wall (left gap)',  Geom::Transformation.translation([55.32, 249.37 - th, 22.51])],
  ['Audimute 2x4 - N wall (right gap)', Geom::Transformation.translation([103.32, 249.37 - th, 22.51])],
  ['Audimute 2x4 - E wall',             Geom::Transformation.translation([160.0 - th, 216.74, 22.56]) * rz.call(-90)],
  ['Audimute 2x4 - W wall',             Geom::Transformation.translation([22.69 + th, 192.74, 22.06]) * rz.call(90)]
]
m.start_operation('CMS: Audimute panels in the booth', true)
begin
  old = b.definition.entities.select { |e| e.respond_to?(:definition) && e.definition == d }
  b.definition.entities.erase_entities(old) unless old.empty?
  spots.each do |nm, wt|
    i = b.definition.entities.add_instance(d, bt.inverse * wt)
    i.name = nm
  end
  m.commit_operation
rescue Exception
  m.abort_operation
  raise
end
wb = lambda { |e| bb = Geom::BoundingBox.new; 8.times { |k| bb.add(e.bounds.corner(k).transform(bt)) }; [bb.min.to_a, bb.max.to_a].map { |p| p.map { |v| v.to_f.round(2) } } }
placed = b.definition.entities.select { |e| e.respond_to?(:definition) && e.definition == d }
# clash test against foam, duct covers and the IEP door / window panels (world boxes, 0.01 in tolerance)
others = b.definition.entities.select { |e| e.respond_to?(:definition) && e.definition.name =~ /\AFoam\z|Duct Cover|ENH .*(Door|WDO)/ }
clash = placed.flat_map do |p|
  pb = wb.call(p)
  others.map do |o|
    ob = wb.call(o)
    ov = (0..2).map { |k| [pb[1][k], ob[1][k]].min - [pb[0][k], ob[0][k]].max }
    ov.all? { |v| v > 0.01 } ? [p.name, o.definition.name, ov.map { |v| v.round(2) }] : nil
  end.compact
end
{ 'placed' => placed.map { |p| [p.name, wb.call(p)] }, 'overlaps' => clash,
  'original' => d.instances.reject { |i| i.parent == b.definition }.map { |i| [i.parent.respond_to?(:name) ? i.parent.name : 'MODEL', i.bounds.min.to_a.map { |v| v.to_f.round(1) }] } }
