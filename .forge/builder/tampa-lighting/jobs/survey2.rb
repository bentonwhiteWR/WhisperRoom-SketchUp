m = Sketchup.active_model
nm = ->(e) { e.respond_to?(:definition) ? "#{e.name}|#{e.definition.name}" : e.class.name }
room = m.entities.find { |e| e.respond_to?(:definition) && e.name == 'Room' }
kids = room.definition.entities.map { |e| [nm.(e), e.layer.name, e.hidden?, (e.bounds.min.to_a + e.bounds.max.to_a).map { |v| v.to_f.round(0) }] }.reject { |k| k[0] =~ /Edge|Face/ }
wl = m.entities.select { |e| e.respond_to?(:definition) && e.name =~ /WR Lights (Ceiling|Wall)/ }.map do |g|
  [g.name, g.definition.entities.map { |c| c.class.name.split('::').last }.tally, g.definition.entities.grep(Sketchup::Face).map { |f| f.material && f.material.name }.uniq,
   g.attribute_dictionaries ? g.attribute_dictionaries.map { |d| [d.name, d.to_h.keys.first(6)] } : nil]
end
hero = m.pages['MDL 144144 E 01-angled r']
hid = (hero.hidden_entities || []).map { |e| nm.(e) }.tally
sph = m.definitions.select { |d| d.name =~ /sphere|dome/i }.map { |d| [d.name, d.instances.size] }
std = m.definitions['Standard Light']
booth = m.entities.find { |e| e.respond_to?(:definition) && e.name == 'MDL 144144 E' }
bk = booth.definition.entities.map { |e| nm.(e) }.tally
{ 'room_kids' => kids, 'wl' => wl, 'hero_hidden' => hid, 'sphere_defs' => sph, 'booth_kids' => bk,
  'mats' => m.materials.map(&:name).grep(/emiss|light|glow/i) }
