# Phase B probe (READ-ONLY): transforms, face extents and body boxes of every foam/Audimute instance.
require 'json'
m = Sketchup.active_model
raise "wrong model: #{m.path.inspect}" unless m.path.to_s =~ /Walsh Construction Tech Lab MDL 96168 E\.skp\z/
b = m.entities.grep(Sketchup::Group).find { |g| g.name == 'Booth - MDL 96168 E' }
raise 'no booth group' unless b
# face-vertex extents of a definition in its own coordinates (no plugin code needed)
gext = lambda do |ents, tr, acc|
  ents.each do |e|
    case e
    when Sketchup::Face then e.vertices.each { |v| acc << v.position.transform(tr) }
    when Sketchup::Group, Sketchup::ComponentInstance then gext.call(e.definition.entities, tr * e.transformation, acc)
    end
  end
  acc
end
r3 = ->(a) { a.to_a.map { |v| v.to_f.round(4) } }
box = lambda do |pts|
  xs = pts.map(&:x); ys = pts.map(&:y); zs = pts.map(&:z)
  [xs.min, xs.max, ys.min, ys.max, zs.min, zs.max].map { |v| v.to_f.round(4) }
end
defs = {}
out = { 'items' => [] }
b.entities.each do |e|
  next unless e.is_a?(Sketchup::ComponentInstance)
  dn = e.definition.name
  next unless dn =~ /\A(Foam|Audimute)/
  unless defs[dn]
    lp = gext.call(e.definition.entities, Geom::Transformation.new, [])
    kids = e.definition.entities.grep(Sketchup::ComponentInstance).map { |c| [c.definition.name, box.call(gext.call(c.definition.entities, c.transformation, []))] }
    defs[dn] = { 'local_face_box' => box.call(lp), 'def_bounds' => box.call((0..7).map { |k| e.definition.bounds.corner(k) }),
                 'kids' => kids, 'n_faces' => e.definition.entities.grep(Sketchup::Face).length, 'insert' => r3.call(e.definition.insertion_point) }
  end
  t = e.transformation
  wp = gext.call(e.definition.entities, t, [])
  out['items'] << { 'name' => e.name, 'def' => dn, 'layer' => e.layer.name, 'hidden' => e.hidden?, 'pid' => e.persistent_id,
                    'origin' => r3.call(t.origin), 'xaxis' => r3.call(t.xaxis), 'yaxis' => r3.call(t.yaxis), 'zaxis' => r3.call(t.zaxis),
                    'face_box' => box.call(wp), 'attrs' => (e.attribute_dictionaries || []).map { |ad| [ad.name, ad.to_a.to_h] }.to_h }
end
out['defs'] = defs
out['layers'] = %w[WR-Booth-Foam WR-Booth-Acoustic].map { |n| [n, !!m.layers[n], m.layers[n] && m.layers[n].visible?] }
out['active_page'] = m.pages.selected_page && m.pages.selected_page.name
out['modified'] = m.modified?
JSON.generate(out)
