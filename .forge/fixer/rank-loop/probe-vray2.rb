ctx = VRay::Context.active
sc = ctx.scene
types = Hash.new(0)
lights = []
n = 0
sc.each do |pl|
  n += 1
  t = (pl.respond_to?(:type) ? pl.type : pl.class.name).to_s
  types[t] += 1
  if t =~ /Light/i
    lights << [pl.name.to_s, t, (pl[:intensity] rescue nil), (pl[:enabled] rescue nil), (pl[:units] rescue nil)]
  end
end
{ :total => n, :types => types, :lights => lights,
  :camera => { :f => (sc['/CameraPhysical'][:f_number] rescue nil), :sh => (sc['/CameraPhysical'][:shutter_speed] rescue nil), :iso => (sc['/CameraPhysical'][:ISO] rescue nil), :ev => (sc['/CameraPhysical'][:exposure_value] rescue nil), :exposure => (sc['/CameraPhysical'][:exposure] rescue nil), :type => (sc['/CameraPhysical'][:type] rescue nil) },
  :out => { :w => (sc['/SettingsOutput'][:img_width] rescue nil), :h => (sc['/SettingsOutput'][:img_height] rescue nil) },
  :cm => (sc['/SettingsColorMapping'] ? [:type, :dark_mult, :bright_mult, :gamma, :subpixel_mapping, :clamp_output, :adaptation_only, :linearWorkflow, :affect_background].map { |k| [k, (sc['/SettingsColorMapping'][k] rescue 'ERR')] } : 'no /SettingsColorMapping'),
  :rt => ( (sc['/SettingsRTEngine'] ? [:max_render_time, :max_sample_level, :noise_threshold, :progressive_samples_per_pixel].map { |k| [k, (sc['/SettingsRTEngine'][k] rescue 'ERR')] } : nil)),
  :vfb => ((sc['/SettingsVFB'] ? [:display_srgb, :bloom_on, :glare_on, :lut_on, :ocio_on, :icc_on, :exposure_on].map { |k| [k, (sc['/SettingsVFB'][k] rescue 'ERR')] } : 'no /SettingsVFB'))
}
