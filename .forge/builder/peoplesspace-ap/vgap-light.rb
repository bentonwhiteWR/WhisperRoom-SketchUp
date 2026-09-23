m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
bt = b.transformation; bi = bt.inverse
wb = lambda { |e| bb = Geom::BoundingBox.new; (0..7).each { |k| bb.add(e.definition.bounds.corner(k).transform(bt * e.transformation)) }; bb }
sel = b.definition.entities.grep(Sketchup::ComponentInstance).select { |e| e.name =~ /^Audimute/ || e.definition.name == 'Foam' }
raise "found #{sel.length}" unless sel.length == 25
drop = { 80.6 => 0.0, 68.6 => 1.0, 20.6 => 2.0 }
m.start_operation('Acoustic rows: 1 in vertical gaps', true)
sel.each do |e|
  d = drop[wb.call(e).max.z.round(1)] or raise "unexpected row top #{wb.call(e).max.z}"
  e.transform!(bi * Geom::Transformation.translation([0, 0, -d]) * bt) if d > 0
end
m.commit_operation
rows = sel.group_by { |e| wb.call(e).max.z.round(2) }.map { |z, es| [z, es.map { |e| wb.call(e).min.z.round(2) }.max, es.length] }.sort.reverse
puts 'rows (top, bottom, pieces): ' + rows.inspect
# light: +40 % inside a V-Ray transaction, then read back after it closes
sc = VRay::Context.active.scene
pl = sc['/Standard Light']
before = pl[:intensity].to_f
sc.change('Brighten booth Standard Light 40%') { pl[:intensity] = before * 1.4 }
after = sc['/Standard Light'][:intensity].to_f
json = m.definitions['Standard Light'].attribute_dictionary('VRayPlugins').to_a.map { |k, v| v.to_s[/"intensity":"?[\d.]+/] }.compact.first
puts format('Standard Light intensity %.1f -> %.1f (definition JSON: %s)', before, after, json.inspect)
nil
