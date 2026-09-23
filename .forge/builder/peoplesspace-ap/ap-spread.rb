m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:definition) && e.definition.name == 'Group#28' && !e.hidden? }
bt = b.transformation; bi = bt.inverse
GAP = 1.0
wb = lambda { |e| bb = Geom::BoundingBox.new; (0..7).each { |k| bb.add(e.definition.bounds.corner(k).transform(bt * e.transformation)) }; bb }
sel = b.definition.entities.grep(Sketchup::ComponentInstance).select { |e| e.name =~ /^Audimute/ || e.definition.name == 'Foam' }
raise "found #{sel.length}" unless sel.length == 25
wall = lambda { |bb| bb.max.x < 12 ? :back : (bb.min.y < 12 ? :left : (bb.max.y > 118 ? :right : :other)) }
rows = sel.group_by { |e| bb = wb.call(e); [wall.call(bb), bb.max.z.round(1)] }
raise "piece on no wall" if rows.keys.any? { |w, _| w == :other }
usable = { back: [11.9, 119.6], left: [9.1, 92.9], right: [9.1, 92.9] }
m.start_operation('Spread acoustic panels 1 in apart', true)
rows.sort_by { |k, _| [k[0].to_s, -k[1]] }.each do |(w, top), es|
  runx = w != :back
  span = lambda { |e| bb = wb.call(e); runx ? [bb.min.x, bb.max.x] : [bb.min.y, bb.max.y] }
  es = es.sort_by { |e| span.call(e)[0] }
  widths = es.map { |e| s = span.call(e); s[1] - s[0] }
  lo = es.map { |e| span.call(e)[0] }.min; hi = es.map { |e| span.call(e)[1] }.max
  total = widths.sum + GAP * (es.length - 1)
  start = (lo + hi) / 2.0 - total / 2.0
  raise "#{w} row @#{top} would be #{total.round(2)} wide, outside usable" if start < usable[w][0] || start + total > usable[w][1]
  es.each_with_index do |e, i|
    d = start - span.call(e)[0]
    e.transform!(bi * Geom::Transformation.translation(runx ? [d, 0, 0] : [0, d, 0]) * bt)
    start += widths[i] + GAP
  end
  s = es.map { |e| span.call(e) }
  puts format('%-5s top %.2f  %d pieces  %.2f..%.2f  gaps %s', w, top, es.length, s.first[0], s.last[1], s.each_cons(2).map { |a, c| (c[0] - a[1]).round(2) }.inspect)
end
m.commit_operation
nil
