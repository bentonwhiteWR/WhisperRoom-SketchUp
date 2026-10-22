m = Sketchup.active_model
f = m.find_entity_by_persistent_id(3442505)
puts "thr #{f.class} parent=#{f.parent.respond_to?(:name) ? f.parent.name : f.parent}"
# world transform of the face's container
def wt(e)
  t = Geom::Transformation.new; d = e
  while d.respond_to?(:parent) && d.parent.is_a?(Sketchup::ComponentDefinition)
    i = d.parent.instances.first; break unless i
    t = i.transformation * t; d = i
  end; t
end
t = wt(f)
pts = f.vertices.map { |v| v.position.transform(t).to_a.map { |x| x.round(2) } }
p pts
# wall-3 pieces near door 2 for opening head height
r = m.find_entity_by_persistent_id(3442119)
puts "room tr origin=#{r.transformation.origin.to_a}"
r.definition.entities.grep(Sketchup::Group).each { |g| b = g.bounds; puts "  #{g.name} #{b.min.to_a.map{|x|x.round(1)}} #{b.max.to_a.map{|x|x.round(1)}}" }
true
