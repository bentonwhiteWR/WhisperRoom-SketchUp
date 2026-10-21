m = Sketchup.active_model
puts "pages: " + m.pages.map { |p| "#{p.name}[#{p.get_attribute('WR_AutoSet', 'token')}|#{p.get_attribute('WR_AutoSet', 'plate')}]" }.join(' ; ')
puts "tags visible: " + m.layers.select(&:visible?).map(&:name).join(', ')
puts "tags hidden: " + m.layers.reject(&:visible?).map(&:name).join(', ')
cnt = Hash.new(0)
walk = lambda do |ents, path|
  ents.each do |e|
    if e.is_a?(Sketchup::DimensionLinear) then cnt["#{path} / #{e.layer.name}"] += 1
    elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      walk.(e.definition.entities, e.name.to_s[0, 40]) if path.empty?
    end
  end
end
walk.(m.entities, '')
cnt.each { |k, v| puts "  dims #{v}  #{k}" }
m.entities.each { |e| next unless e.respond_to?(:definition) || e.is_a?(Sketchup::Group); puts "  top #{e.typename} #{e.name} layer=#{e.layer.name} hidden=#{e.hidden?} pid=#{e.persistent_id}" }
