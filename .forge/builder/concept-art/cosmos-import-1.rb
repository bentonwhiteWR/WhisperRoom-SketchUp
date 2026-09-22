# STEP 1 of the Cosmos import: load the two source files as definitions and
# REPORT what arrived. Removes nothing. See cosmos-import-2.rb.
m = Sketchup.active_model
sc = VRay::Context.active.scene
before_defs = m.definitions.map(&:name)
before_mats = m.materials.map(&:name)
before_plugs = []
sc.each { |p| before_plugs << p.name if p.category.to_s =~ /light|geometry/ }
$wr_ca_before = { 'defs' => before_defs, 'mats' => before_mats, 'plugs' => before_plugs }
srcs = ['C:/Users/bento/OneDrive/Desktop/Garden Dims.skp',
        'C:/Users/bento/Downloads/Spelman College MDL 96120 E ADA HX WDO 9696 E WDO HX.skp']
wrappers = []
srcs.each do |s|
  t0 = Time.now
  d = m.definitions.load(s)
  wrappers << d.name
  puts "loaded #{File.basename(s)} as #{d.name.inspect} in #{(Time.now - t0).round(1)} s"
end
$wr_ca_wrappers = wrappers
new_defs = m.definitions.reject { |d| before_defs.include?(d.name) }
puts "new definitions: #{new_defs.length}; new materials: #{m.materials.count { |x| !before_mats.include?(x.name) }}"
new_defs.each do |d|
  mp = d.get_attribute('VRayInfo', 'main_plugin')
  next if mp.nil?
  puts "  VRAY DEF #{d.name.inspect} class=#{d.get_attribute('VRayInfo', 'class')} plugin=#{mp} bbox=#{d.bounds.width.to_f.round(1)}x#{d.bounds.height.to_f.round(1)}x#{d.bounds.depth.to_f.round(1)}"
end
after_plugs = []
sc.each { |p| after_plugs << "#{p.name}(#{p.type})" if p.category.to_s =~ /light|geometry/ && !before_plugs.include?(p.name) }
puts "new light/geometry plugins: #{after_plugs.inspect}"
sl = sc['/Standard Light']
puts "/Standard Light valid=#{sl && sl.valid?} int=#{sl && sl[:intensity]}"
:step1_done
