require 'json'
m = Sketchup.active_model
booth = m.entities.find { |e| e.is_a?(Sketchup::ComponentInstance) && e.definition.name == 'Component' }
kids = booth.definition.entities.select { |x| x.is_a?(Sketchup::Group) || x.is_a?(Sketchup::ComponentInstance) }
rows = kids.map do |k|
  b = k.bounds; o = k.transformation.origin
  { 'name' => (k.name.to_s.empty? ? k.definition.name : k.name + '|' + k.definition.name),
    'min' => [b.min.x, b.min.y, b.min.z].map(&:to_f), 'max' => [b.max.x, b.max.y, b.max.z].map(&:to_f),
    'origin' => [o.x, o.y, o.z].map(&:to_f), 'home' => k.get_attribute('WR_Explode', 'home') }
end
File.write(File.join(WhisperRoom::Bridge.dir('art'), 'booth144144e.json'), JSON.pretty_generate(rows))
[rows.length, booth.definition.instances.length, rows.count { |r| r['home'] }]
