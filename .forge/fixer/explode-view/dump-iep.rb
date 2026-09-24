require 'json'
m = Sketchup.active_model
booth = m.entities.find { |e| e.is_a?(Sketchup::ComponentInstance) && e.definition.name == 'Component' }
c = booth.definition.entities.find { |e| e.is_a?(Sketchup::ComponentInstance) && e.definition.name =~ /Iep ceiling/ }
t = c.transformation
kids = c.definition.entities.select { |x| x.is_a?(Sketchup::Group) || x.is_a?(Sketchup::ComponentInstance) }
rows = kids.map do |k|
  bb = Geom::BoundingBox.new
  8.times { |i| bb.add(k.bounds.corner(i).transform(t)) }
  { 'name' => k.definition.name, 'min' => bb.min.to_a.map(&:to_f), 'max' => bb.max.to_a.map(&:to_f),
    'home' => k.get_attribute('WR_Explode', 'home') }
end
File.write(File.join(WhisperRoom::Bridge.dir('art'), 'iep-ceiling-kids.json'), JSON.pretty_generate(rows))
{ 'container_instances_in_model' => c.definition.instances.length,
  'container_axes' => [t.xaxis.to_a, t.yaxis.to_a, t.zaxis.to_a].map { |v| v.map { |x| x.round(3) } },
  'kid_defs' => kids.map { |k| [k.definition.name, k.definition.instances.length] }.uniq,
  'booth_instances' => booth.definition.instances.length,
  'rows' => rows.map { |r| [r['name'], r['min'].map { |x| x.round(1) }, r['max'].map { |x| x.round(1) }] } }
