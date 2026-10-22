# Per-scene dim sets via TAGS (scenes here do not restore per-entity hidden state on dims - observed q25).
# Moves out-of-frame / occluded dims into four WR-Dims-* sets and hides each set only on the image
# scenes where it clips. 06-plan and render rows keep every set as visible as its original tag.
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/walsh/rm/geom.rb'
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb'
m = Sketchup.active_model
raise "wrong file" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
g = m.find_entity_by_persistent_id(3442717)
dims = g.entities.grep(Sketchup::DimensionLinear)
byid = dims.map { |d| [d.persistent_id, d] }.to_h
before = dims.map { |d| [d.persistent_id, d.text] }.to_h
SETS = {
  'WR-Dims-Long'      => { ids: [3442721, 3442722, 3442733, 3442734], hide: %w[01-angled 02-front 03-high 04-side 05-ventilation] },
  'WR-Dims-South'     => { ids: [3442728, 3442729, 3442730, 3442731, 3442732], hide: %w[01-angled 02-front 03-high 04-side] },
  'WR-Dims-W1-Corner' => { ids: [3442719], hide: %w[02-front 04-side] },
  'WR-Dims-W1-Far'    => { ids: [3442718, 3442720], hide: %w[02-front] },
}
orig = {}
SETS.each_value { |s| s[:ids].each { |i| raise "missing dim #{i}" unless byid[i]; orig[i] = byid[i].layer } }
start = m.pages.selected_page
prevT = m.options['PageOptions']['ShowTransition']; m.options['PageOptions']['ShowTransition'] = false
m.start_operation('Walsh pkg2 dim tag sets', true)
begin
  # record, per page, what each original tag shows (before moving anything)
  shows = {}
  m.pages.each do |p|
    m.pages.selected_page = p
    shows[p.name] = orig.values.uniq.map { |l| [l.name, l.visible?] }.to_h
  end
  layers = {}
  SETS.each do |name, s|
    l = m.layers[name] || m.layers.add(name)
    layers[name] = l
    s[:ids].each { |i| byid[i].layer = l }
  end
  m.pages.each do |p|
    m.pages.selected_page = p
    image = WR_ProposalPackage.mode_of(p) == 'image'
    SETS.each do |name, s|
      base = s[:ids].all? { |i| shows[p.name][orig[i].name] }
      vis = base && !(image && s[:hide].any? { |k| p.name.end_with?(" #{k}") })
      layers[name].visible = vis
      p.set_visibility(layers[name], vis)
    end
    puts "#{p.name.split(' ').last(2).join(' ')} [#{WR_ProposalPackage.mode_of(p)}] " + SETS.keys.map { |n| "#{n.sub('WR-Dims-', '')}=#{layers[n].visible? ? 'on' : 'OFF'}" }.join(' ')
  end
  m.commit_operation
rescue => e
  m.commit_operation; raise e
ensure
  m.pages.selected_page = start if start
  m.options['PageOptions']['ShowTransition'] = prevT
end
after = dims.map { |d| [d.persistent_id, d.text] }.to_h
raise 'dim values changed!' unless before == after
puts "values unchanged: #{after.size} dims"
WalshRM.save(m)
true
