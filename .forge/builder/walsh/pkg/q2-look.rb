m = Sketchup.active_model
ro = m.rendering_options
%w[EdgeColorMode ForegroundColor EdgeDisplayMode DrawSilhouettes SilhouetteWidth DrawDepthQue DrawProfilesOnly ExtendLines DisplayColorByLayer RenderMode Texture BackgroundColor FaceFrontColor FaceBackColor ConstructionColor HighlightColor LockedColor SkyColor DrawHorizon DrawGround AmbientOcclusion ModelTransparency DrawLineEnds].each do |k|
  v = ro[k]; v = v.to_a if v.is_a?(Sketchup::Color)
  puts "  #{k} = #{v.inspect}"
end
booth = m.entities.find { |e| e.persistent_id == 3442662 }
cnt = Hash.new(0)
walk = lambda do |ents, depth, mat|
  ents.each do |e|
    if e.is_a?(Sketchup::Face)
      mm = e.material || mat
      cnt[mm ? mm.display_name : '(default)'] += e.area
    elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      next if e.hidden?
      walk.call(e.definition.entities, depth + 1, e.material || mat) if depth < 10
    end
  end
end
walk.call(booth.definition.entities, 0, booth.material)
puts '--- booth face area by material (top 15)'
cnt.sort_by { |_, a| -a }.first(15).each do |n, a|
  mt = m.materials[n] || m.materials.find { |x| x.display_name == n }
  c = mt ? mt.color.to_a : nil
  puts format('  %-40s %10.0f sq in  color=%s tex=%s', n, a, c.inspect, mt && mt.texture ? mt.texture.filename : '-')
end
d = m.entities.find { |e| e.persistent_id == 3442717 }
dl = d.definition.entities.grep(Sketchup::DimensionLinear).first
puts "dim in RM Dims: #{d.definition.entities.grep(Sketchup::DimensionLinear).size} dims"
puts "dims options: #{m.options['UnitsOptions'].to_a.inspect}"
puts "WR_Mode: #{defined?(WR_Mode) ? (WR_Mode.respond_to?(:current) ? WR_Mode.current(m) : 'loaded') : 'nil'}"
puts "mode attr: #{(m.attribute_dictionary('WR_Mode') || {}).to_a.inspect[0,600]}"
true
