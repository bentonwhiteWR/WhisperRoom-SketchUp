# Per-scene dim sets: on each perspective IMAGE page, hide (page-hidden flag only) every RM dim that is
# not fully inside the 16:9 frame; if any of the south-wall door chain is out, hide that whole chain.
# 06-plan and render pages are left with every dim unhidden. Values are not touched.
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/walsh/rm/geom.rb'
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/walsh/pkg/q24-dimframe.rb'  # defs only; its loop is read-only
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb'
m = Sketchup.active_model
raise "wrong file" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
CHAIN_S = [3442728, 3442729, 3442730, 3442731]
dims = DIMG.entities.grep(Sketchup::DimensionLinear)
before = dims.map { |d| [d.persistent_id, d.text] }.to_h
start = m.pages.selected_page
prevT = m.options['PageOptions']['ShowTransition']; m.options['PageOptions']['ShowTransition'] = false
m.start_operation('Walsh pkg2 per-scene dim sets', true)
begin
  m.pages.each do |p|
    m.pages.selected_page = p
    cam = m.active_view.camera
    target = WR_ProposalPackage.mode_of(p) == 'image' && cam.perspective?
    out = target ? dims.reject { |d| in_frame(cam, d) }.map(&:persistent_id) : []
    out |= CHAIN_S if (out & CHAIN_S).any?
    dims.each { |d| d.hidden = out.include?(d.persistent_id) }
    p.update(128 | 256)
    puts "#{p.name.split(' ').last(2).join(' ')} [#{WR_ProposalPackage.mode_of(p)}] hide=#{dims.select(&:hidden?).map(&:text).join(' | ')}"
  end
  m.commit_operation
rescue => e
  m.commit_operation; raise e
ensure
  m.pages.selected_page = start if start
  m.options['PageOptions']['ShowTransition'] = prevT
end
after = dims.map { |d| [d.persistent_id, d.text] }.to_h
raise "dim values changed!" unless before == after
puts "values unchanged: #{after.size} dims"
WalshRM.save(m)
true
