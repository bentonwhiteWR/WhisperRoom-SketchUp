# ap9: read-only dump of every booth child (booth-local bounds) + Audimute body boxes + foam geom extents.
require 'json'
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/build-booth-components.rb' unless defined?(WR_BuildBoothComponents)
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-overlays.rb' unless defined?(WR_Overlays)
m = Sketchup.active_model
raise "wrong model #{m.path}" unless m.path =~ /Walsh Construction Tech Lab MDL 96168 E\.skp\z/
b = m.entities.grep(Sketchup::Group).find { |g| g.name == 'Booth - MDL 96168 E' }
raise 'no booth' unless b
r = ->(bb) { [bb.min.x, bb.max.x, bb.min.y, bb.max.y, bb.min.z, bb.max.z].map { |v| v.to_f.round(3) } }
out = { 'booth_tr' => b.transformation.to_a.map { |v| v.round(4) }, 'items' => [] }
b.entities.each do |e|
  next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
  d = e.is_a?(Sketchup::Group) ? e.definition : e.definition
  h = { 'pid' => e.persistent_id, 'name' => e.name, 'def' => d.name, 'layer' => e.layer.name, 'hidden' => e.hidden?, 'box' => r.call(e.bounds) }
  if d.name =~ /\AAudimute/
    body = d.entities.grep(Sketchup::ComponentInstance).max_by { |c| c.bounds.width * c.bounds.height * c.bounds.depth }
    bb = Geom::BoundingBox.new
    8.times { |k| bb.add(body.bounds.corner(k).transform(e.transformation)) }
    h['body'] = r.call(bb)
    h['fabric'] = Geom::Vector3d.new(0, -1, 0).transform(e.transformation).normalize.to_a.map { |v| v.round(3) }
  end
  if d.name =~ /\AFoam/
    h['zaxis'] = e.transformation.zaxis.to_a.map { |v| v.round(3) }
    h['ge'] = WR_Overlays.geom_extents(d)[:e].to_a.map { |v| v.to_f.round(3) }
  end
  h['attrs'] = (e.attribute_dictionaries || []).map { |ad| [ad.name, ad.to_a.to_h] }.to_h rescue nil
  out['items'] << h
end
%w[Foam Audimute2x4 Audimute1x4 Audimute1x2].each do |n|
  d = m.definitions[n]
  next unless d
  ge = WR_Overlays.geom_extents(d)
  out["ge_#{n}"] = { 'lo' => ge[:lo].to_a.map { |v| v.to_f.round(3) }, 'hi' => ge[:hi].to_a.map { |v| v.to_f.round(3) }, 'mat' => d.entities.grep(Sketchup::Face).map { |f| f.material && f.material.name }.tally }
end
out['defs_foam'] = m.definitions.select { |d| d.name =~ /Foam/ }.map { |d| [d.name, d.instances.length] }
File.write('C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-Documents-Claude-Sketchup/4197d3da-5c83-4677-a84d-a22ae4e12e24/scratchpad/ap9/dump.json', JSON.pretty_generate(out))
[out['items'].length, out['defs_foam']]
