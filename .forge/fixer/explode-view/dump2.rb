require 'json'
m = Sketchup.active_model
g = m.entities.find { |e| e.is_a?(Sketchup::Group) && e.name == 'MDL 7272 S (components)' }
kids = g.entities.select { |x| x.is_a?(Sketchup::Group) || x.is_a?(Sketchup::ComponentInstance) }
rows = kids.map do |k|
  b = k.bounds
  { 'name' => (k.name.to_s.empty? ? k.definition.name : k.name),
    'min' => [b.min.x, b.min.y, b.min.z].map(&:to_f), 'max' => [b.max.x, b.max.y, b.max.z].map(&:to_f) }
end
File.write(File.join(WhisperRoom::Bridge.dir('art'), 'booth7272s.json'), JSON.pretty_generate(rows))
rows.length
