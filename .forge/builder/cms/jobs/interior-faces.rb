# READ-ONLY: the booth's interior face planes (world inches). Per wall, the area-weighted planes of the
# inner-shell (ENH / IEP) parts' faces that point INTO the booth, and the foam front faces.
m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:name) && e.name == 'MDL 96144 E (components)' }
bt = b.transformation
ctr = b.bounds.center
acc = Hash.new { |h, k| h[k] = Hash.new(0.0) }
walk = lambda do |ents, tr, tag|
  ents.each do |e|
    if e.is_a?(Sketchup::Face)
      n = e.normal.transform(tr)
      p = e.vertices[0].position.transform(tr)
      area = e.area * 1.0
      if n.x.abs > 0.99
        side = p.x < ctr.x ? 'W' : 'E'
        into = (side == 'W' && n.x > 0) || (side == 'E' && n.x < 0)
        acc["#{tag} #{side}"][p.x.to_f.round(2)] += area if into
      elsif n.y.abs > 0.99
        side = p.y < ctr.y ? 'S' : 'N'
        into = (side == 'S' && n.y > 0) || (side == 'N' && n.y < 0)
        acc["#{tag} #{side}"][p.y.to_f.round(2)] += area if into
      end
    elsif e.respond_to?(:definition)
      walk.call(e.definition.entities, tr * e.transformation, tag)
    end
  end
end
b.definition.entities.each do |e|
  next unless e.respond_to?(:definition)
  n = e.definition.name
  tag = n =~ /\AENH .*(Panel|VNT|Door|WDO)/ ? 'IEP' : (n == 'Foam' ? 'FOAM' : nil)
  next unless tag
  walk.call(e.definition.entities, bt * e.transformation, tag)
end
acc.map { |k, h| [k, h.sort_by { |_, a| -a }.first(3).map { |v, a| [v, a.round] }] }.sort
