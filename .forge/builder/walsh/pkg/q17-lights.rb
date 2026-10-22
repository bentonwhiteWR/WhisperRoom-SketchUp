# Read-only: what is on the WR Lights tag, and V-Ray state.
m = Sketchup.active_model
l = m.layers['WR Lights']
puts "WR Lights tag: #{l ? "visible=#{l.visible?}" : 'none'}"
all = []
walk = lambda do |ents, tr, depth|
  ents.each do |e|
    next unless e.respond_to?(:definition)
    t = tr * e.transformation
    all << [e, t, depth] if e.layer == l
    walk.call(e.definition.entities, t, depth + 1) if depth < 3 && e.layer != l
  end
end
walk.call(m.entities, Geom::Transformation.new, 0)
all.each { |e, t, d| puts "  d#{d} #{e.name} def=#{e.definition.name} hid=#{e.hidden?} at=#{t.origin.to_a.map(&:round)} attrs=#{(e.attribute_dictionaries || []).map(&:name).inspect}" }
puts "count=#{all.size}"
ctx = (VRay::Context.active rescue nil)
puts "vray state=#{(ctx.state rescue 'n/a')}"
if ctx
  sc = ctx.scene
  %w[/SunLight /RTEngine /SettingsCamera /CameraPhysical /SettingsEnvironment].each do |p|
    pl = sc[p] rescue nil
    puts "#{p}: #{pl ? 'present' : 'none'}"
  end
  begin
    cp = sc['/CameraPhysical']; puts "  exposure=#{cp[:exposure] rescue '?'} iso=#{cp[:ISO] rescue '?'} f=#{cp[:f_number] rescue '?'} shutter=#{cp[:shutter_speed] rescue '?'}"
    su = sc['/SunLight']; puts "  sun enabled=#{su[:enabled] rescue '?'} intensity=#{su[:intensity_multiplier] rescue '?'}"
  rescue => e
    puts "  read err #{e.message}"
  end
end
true
