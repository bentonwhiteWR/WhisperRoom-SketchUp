m = Sketchup.active_model
x = m.materials['CA Timber Beam']
meths = (x.public_methods - Object.public_methods).map(&:to_s).grep(/workflow|metal|rough|normal|ao_|pbr/).sort
puts "PBR methods: #{meths.join(' ')}"
['CA Timber Beam', 'CA Oak Slat', 'CA Plaster Warm White'].each do |n|
  t = m.materials[n]
  vals = []
  %w[workflow metalness_enabled? metallic_factor roughness_enabled? roughness_factor normal_enabled? normal_scale ao_enabled?].each do |k|
    vals << "#{k}=#{(t.send(k) rescue 'n/a').inspect}" if t.respond_to?(k)
  end
  vals << "rough_tex=#{(t.roughness_texture && File.basename(t.roughness_texture.filename)).inspect}" if t.respond_to?(:roughness_texture)
  vals << "normal_tex=#{(t.normal_texture && File.basename(t.normal_texture.filename)).inspect}" if t.respond_to?(:normal_texture)
  puts "#{n}: #{vals.join(' ')}"
end
puts "WORKFLOW consts: #{Sketchup::Material.constants.grep(/WORKFLOW|NORMAL_STYLE/).inspect}"
:ok
