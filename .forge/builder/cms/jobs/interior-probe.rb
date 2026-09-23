# Booth interior in WORLD inches: IEP room-face planes (from the foam backs), foam, duct covers, door,
# window, plus Benton's Audimute component (Component#11) and its children's layout.
m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:name) && e.name == 'MDL 96144 E (components)' }
t = b.transformation
wb = lambda { |e| bb = Geom::BoundingBox.new; 8.times { |i| bb.add(e.bounds.corner(i).transform(t)) }; [bb.min.to_a, bb.max.to_a].map { |p| p.map { |v| v.to_f.round(2) } } }
rows = b.definition.entities.select { |e| e.respond_to?(:definition) && e.definition.name =~ /Foam|Duct|ENH .*(Door|WDO|VNT|Panel)|Component#127/ }.map { |e| [e.definition.name, wb.call(e)] }
au = m.definitions['Component#11']
kids = au.entities.select { |e| e.respond_to?(:definition) }.map { |e| [e.definition.name, e.bounds.min.to_a.map { |v| v.to_f.round(2) }, e.bounds.max.to_a.map { |v| v.to_f.round(2) }] }
inst = au.instances.map { |i| [i.parent.respond_to?(:name) ? i.parent.name : 'MODEL', i.transformation.to_a.map { |v| v.round(3) }, i.layer.name, i.name] }
mats = au.entities.select { |e| e.respond_to?(:definition) }.map { |e| [e.definition.name, (e.material && e.material.name), e.definition.entities.grep(Sketchup::Face).map { |f| f.material && f.material.name }.compact.uniq.first(3)] }
{ 'booth_rows' => rows, 'audimute_kids' => kids, 'audimute_inst' => inst, 'audimute_mats' => mats, 'def_bounds' => [au.bounds.min.to_a, au.bounds.max.to_a].map { |p| p.map { |v| v.to_f.round(2) } } }
