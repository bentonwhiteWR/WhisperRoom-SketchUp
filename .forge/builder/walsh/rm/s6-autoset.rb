# Walsh v3 step 6: proposal scenes from AUTO-SET (headless body of proposal-package.rb 'autosetapply',
# popover defaults: create, DEFAULT_RENDERS, no interior). Tool code is only loaded, never changed.
# Fresh aspect-0 camera first (photo-job trap "Scenes opened super zoomed in").
load File.join(File.dirname(__FILE__), 'geom.rb')
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb'
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
want = 'Booth - MDL 96168 S RM (21 Oct link)'
booth, note = WR_AutoSet.resolve_booth(m, want)
raise(note || 'no booth') if booth.nil?
raise "resolved #{booth.persistent_id}, want #{m.get_attribute('WalshRM', 'booth_pid')}" unless booth.persistent_id == m.get_attribute('WalshRM', 'booth_pid')
stamped = m.pages.select { |p| p.get_attribute('WR_AutoSet', 'token') }.map(&:name)
raise "AUTO-SET pages already exist: #{stamped.inspect}" unless stamped.empty?
v = m.active_view
c = booth.bounds.center
clean = Sketchup::Camera.new(Geom::Point3d.new(c.x - 250, c.y - 250, 61), Geom::Point3d.new(c.x, c.y, 42), Z_AXIS)
clean.perspective = true
clean.fov = 35.0
v.camera = clean
raise 'aspect' unless v.camera.aspect_ratio.to_f == 0.0
ok, msg, lines = WR_AutoSet.apply(m, booth, { 'mode' => 'create', 'renders' => WR_AutoSet::DEFAULT_RENDERS, 'interior' => false, 'reaim' => false })
puts "APPLY ok=#{ok} msg=#{msg}"
(lines || []).each { |l| puts "  #{l}" }
m.pages.select { |p| p.get_attribute('WR_AutoSet', 'token') }.each do |p|
  cam = p.camera
  puts "  #{p.name} | #{WR_ProposalPackage.mode_of(p)} | #{p.get_attribute('WR_AutoSet', 'plate')} | " +
       (cam.perspective? ? "persp fov #{cam.fov.round(1)}" : "ortho") + " | hidden tags: #{p.layers.map(&:name).sort.join(', ')}"
end
WalshRM.save(m) if ok
puts "saved #{m.path}"
