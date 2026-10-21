# Walsh v3 step 9: fix two plates after looking at the first export.
#  - 01-angled (and its 'r' twin): AUTO-SET's eye sat outside the room and a host door leaf filled the frame.
#    New eye inside the room, west of the booth, three-quarter on the window face + door end (matches the builder iso).
#  - 06-plan: ortho framed on the booth cropped the room; reframe on the whole room + dims.
#  - RM Dims group moves off Layer0 onto its own tag so the hero can hide it; every other page keeps it on.
#  - The old v1/v2 pages that were still marked Image go to Skip so a package run never exports them again.
load File.join(File.dirname(__FILE__), 'geom.rb')
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb' unless defined?(WR_ProposalPackage)
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
WalshRM.save(m)
pre = 'Booth - MDL 96168 S RM (21 Oct link) '
pg = ->(n) { m.pages[pre + n] or raise "no page #{n}" }
dims = m.entities.grep(Sketchup::Group).find { |g| g.name == 'RM Dims 21 Oct' } or raise 'no RM Dims group'
m.start_operation('Walsh RM s9 cams', true)
tag = m.layers['Walsh RM Dims 21 Oct'] || m.layers.add('Walsh RM Dims 21 Oct')
tag.visible = true
dims.layer = tag
m.pages.each { |p| p.set_visibility(tag, !p.name.start_with?(pre + '01-angled')) }
v = m.active_view
['01-angled', '01-angled r'].each do |n|
  p = pg.(n)
  m.pages.selected_page = p
  v.camera = Sketchup::Camera.new([10, 60, 62], [262, 70, 44], Z_AXIS, true, 55)
  p.update(1)
end
p = pg.('06-plan')
m.pages.selected_page = p
c = Sketchup::Camera.new([206, 150, 1500], [206, 150, 0], Y_AXIS, false)
c.height = 470
v.camera = c
p.update(1)
skipped = []
m.pages.each do |q|
  next if q.name.start_with?(pre)
  next unless WR_ProposalPackage.mode_of(q) == 'image'
  WR_ProposalPackage.set_mode(q, 'skip'); skipped << q.name
end
m.set_attribute('WalshRM', 'old_pages_skipped', skipped)
m.pages.selected_page = pg.('01-angled')
m.commit_operation
WalshRM.save(m)
puts "old pages now skip: #{skipped.inspect}"
m.pages.each { |q| puts "  #{q.name}: #{WR_ProposalPackage.mode_of(q)} dims=#{q.get_attribute('x','y').inspect if false}" }
true
