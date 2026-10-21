# Walsh v3 step 1: retire the v2 layout. The old 96168 E PLATFORM booth, the v2 corner room (with its black
# NEW walls) and the v2 dims go onto a new HIDDEN tag 'Walsh Corner v2 21 Oct'. Hidden, not erased (undoable,
# recoverable). Nothing else is touched.
load File.join(File.dirname(__FILE__), 'geom.rb')
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
PIDS = { 3404973 => 'Booth - MDL 96168 E PLATFORM', 3426776 => 'Tech Lab 13 - Corner 21 Oct', 3427527 => 'Corner Dims 21 Oct' }
m.start_operation('Walsh v3: retire v2', true)
begin
  t = m.layers['Walsh Corner v2 21 Oct'] || m.layers.add('Walsh Corner v2 21 Oct')
  PIDS.each do |pid, nm|
    e = m.entities.find { |x| x.persistent_id == pid } or raise "#{nm} (#{pid}) not found"
    raise "pid #{pid} is #{e.name.inspect}, expected #{nm}" unless e.name == nm
    e.layer = t
    e.name = "#{nm} (v2 21 Oct)"
  end
  t.visible = false
  m.layers['WR-Room-New'].visible = false if m.layers['WR-Room-New']
  m.commit_operation
rescue Exception => e
  m.abort_operation
  raise
end
WalshRM.save(m)
m.entities.each { |e| puts "top #{e.typename} #{e.name} tag=#{e.layer.name}" if e.is_a?(Sketchup::Group) }
puts "saved #{m.path}"
