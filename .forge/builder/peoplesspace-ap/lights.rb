m = Sketchup.active_model
sc = VRay::Context.active.scene
# world positions of every instance of each definition (walk the whole model)
pos = Hash.new { |h, k| h[k] = [] }
walk = lambda do |ents, t, path|
  ents.each do |e|
    next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
    tt = t * e.transformation
    pos[e.definition] << [tt.origin.to_a.map { |v| v.to_f.round(1) }, path, e.hidden? || !e.layer.visible?]
    walk.call(e.definition.entities, tt, path + [e.definition.name]) if path.length < 6
  end
end
walk.call(m.entities, Geom::Transformation.new, [])
m.definitions.each do |d|
  dict = d.attribute_dictionary('VRayPlugins') or next
  pl = (sc["/#{d.name}"] rescue nil)
  inten = (pl[:intensity] rescue 'n/a')
  typ = (pl.plugin_type rescue pl.class.name) rescue '?'
  ps = pos[d].first(4).map { |p, path, hid| "#{p.inspect}#{hid ? ' HIDDEN' : ''} in #{path.last(2).join('>')}" }
  puts "#{d.name.ljust(22)} int=#{inten} type=#{typ} n=#{pos[d].length} #{ps.join(' | ')}"
end
nil
