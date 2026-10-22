m = Sketchup.active_model
base = {}
m.rendering_options.each { |k, v| base[k] = (v.is_a?(Sketchup::Color) ? v.to_a : v) }
m.pages.each do |p|
  ro = p.rendering_options
  diffs = []
  if ro
    ro.each do |k, v|
      vv = v.is_a?(Sketchup::Color) ? v.to_a : v
      diffs << "#{k}=#{vv.inspect}" if base[k] != vv
    end
    fog = "fog=#{ro['DisplayFog']} ao=#{ro['AmbientOcclusion']} rm=#{ro['RenderMode']} tex=#{ro['Texture']} ecm=#{ro['EdgeColorMode']} trans=#{ro['ModelTransparency']}"
  else
    fog = 'no ro'
  end
  si = p.shadow_info
  sh = si ? "sh=#{si['DisplayShadows']} L=#{si['Light']} D=#{si['Dark']} sun=#{si['UseSunForAllShading']}" : 'no si'
  puts "#{p.name}\n   use_ro=#{p.use_rendering_options?} use_si=#{p.use_shadow_info?} style=#{p.style && p.style.name} #{fog} #{sh}\n   diff vs model: #{diffs.join('; ')[0,400]}"
end
true
