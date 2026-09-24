m = Sketchup.active_model
def nm(e); e.respond_to?(:definition) ? "#{e.name}|#{e.definition.name}" : "#{e.name}|#{e.definition.name rescue ''}"; end
def ents(e); e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities; end
def walk(e, d, maxd, out, tf)
  kids = ents(e).select { |x| x.is_a?(Sketchup::Group) || x.is_a?(Sketchup::ComponentInstance) }
  b = e.bounds
  out << ("  " * d) + format("%s  [%d kids] min(%.1f,%.1f,%.1f) size(%.1f,%.1f,%.1f)", nm(e), kids.length, b.min.x, b.min.y, b.min.z, b.width, b.height, b.depth)
  return if d >= maxd
  kids.each { |k| walk(k, d + 1, maxd, out, tf) }
end
out = []
m.entities.each do |e|
  next unless e.is_a?(Sketchup::Group) && e.name == "MDL 7272 S (components)"
  next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
  next if e.respond_to?(:definition) && e.definition.name =~ /GoPro/
  walk(e, 0, 2, out, nil)
end
out.join("\n")
