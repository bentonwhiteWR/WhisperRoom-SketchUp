m = Sketchup.active_model
walk = lambda do |ents, path, depth|
  ents.each do |e|
    next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    d = e.respond_to?(:definition) ? e.definition : nil
    k = e.get_attribute('WR_DropLights', 'kind') || e.get_attribute('WR_DropLights', 'role')
    lt = d && d.get_attribute('VRayInfo', 'class')
    if k || lt
      puts "#{path}/#{e.name.empty? ? (d ? d.name : '?') : e.name} kind=#{k.inspect} vray=#{lt.inspect} layer=#{e.layer.name}"
    end
    walk.call(e.respond_to?(:definition) ? e.definition.entities : e.entities, "#{path}/#{e.name.empty? ? '#' : e.name}", depth + 1) if depth < 3 && !(e.name =~ /MDL 96120/)
  end
end
walk.call(m.entities, '', 0)
:ok
