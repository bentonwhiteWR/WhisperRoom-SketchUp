# Walsh v3 package step 2: hide the leftover v2 tags globally, fresh aspect-0 camera, AUTO-SET create.
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/walsh/rm/geom.rb'
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb' unless defined?(WR_ProposalPackage)
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
raise "edit context open: #{m.active_path.inspect}" if m.active_path && !m.active_path.empty?
raise "scenes exist: #{m.pages.size}" unless m.pages.size == 0
m.start_operation('Walsh: hide v2 leftovers', true)
['Walsh Corner v2 21 Oct', 'WR-Room-New'].each { |n| l = m.layers[n]; l.visible = false if l; puts "hid tag #{n}" }
l = m.layers['Walsh RM Dims 21 Oct']; l.visible = true
m.commit_operation
booth, note = WR_AutoSet.resolve_booth(m, 'Booth - MDL 96168 S RM (21 Oct link)')
raise(note || 'no booth') if booth.nil? || booth.persistent_id != 3442662
v = m.active_view
c = booth.bounds.center
clean = Sketchup::Camera.new(Geom::Point3d.new(c.x - 250, c.y - 250, 61), Geom::Point3d.new(c.x, c.y, 42), Z_AXIS)
clean.perspective = true
clean.fov = 35.0
v.camera = clean
raise 'aspect' unless v.camera.aspect_ratio.to_f == 0.0
ok, msg, lines = WR_AutoSet.apply(m, booth, { 'mode' => 'create', 'renders' => 3, 'interior' => false, 'reaim' => false })
puts "APPLY ok=#{ok} msg=#{msg}"
(lines || []).each { |x| puts "  #{x}" }
m.pages.each do |p|
  cam = p.camera
  puts "  #{p.name} | #{WR_ProposalPackage.mode_of(p)} | #{p.get_attribute('WR_AutoSet', 'plate')} | " +
       (cam.perspective? ? "persp fov #{cam.fov.round(1)}" : "ortho h=#{cam.height.round}") +
       " eye=#{cam.eye.to_a.map(&:round)} tgt=#{cam.target.to_a.map(&:round)} | hidden: #{p.layers.map(&:name).sort.join(', ')}"
end
WalshRM.save(m) if ok
puts "saved=#{ok} active_path=#{m.active_path.inspect}"
true
