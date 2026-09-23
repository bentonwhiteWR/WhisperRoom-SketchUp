# Step 7: the proposal package's scene setup (WR_ProposalScenes, the legacy five plates) AND
# AUTO-SET (WR_AutoSet.apply), both headless, booth = MDL 96144 E. The two photo-match scenes are
# never touched. Afterwards "CMS Room Dims (EST)" is hidden in every scene that stores tag state
# (it is not a WR-Dims* tag, so neither tool knows it; HANDOFF hazard).
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/proposal-package.rb'
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/proposal-scenes.rb'
m = Sketchup.active_model
photo = ['Photo A - long view', 'Photo B - corner view']
cams_before = photo.map { |n| p = m.pages[n]; p && p.camera.eye.to_a }
booth = m.entities.find { |e| e.respond_to?(:name) && e.name == 'MDL 96144 E (components)' }
out = {}
m.selection.clear
m.selection.add(booth)
WR_ProposalScenes.run(true)
m.selection.clear
b2, note = WR_AutoSet.resolve_booth(m, 'MDL 96144 E (components)')
raise(note || 'no booth') if b2.nil?
ok, msg, lines = WR_AutoSet.apply(m, b2, { 'mode' => ($wr_as_mode || 'create'), 'renders' => WR_AutoSet::MAX_RENDERS,
                                           'interior' => true, 'reaim' => true })
out['autoset'] = [ok, msg]
out['autoset_lines'] = lines
dl = m.layers['CMS Room Dims (EST)']
hid = []
m.pages.each do |pg|
  next if photo.include?(pg.name)
  next unless pg.use_hidden_layers?
  pg.set_visibility(dl, false)
  hid << pg.name
end
out['cms_dims_hidden_in'] = hid.size
out['pages'] = m.pages.map { |p| [p.name, p.use_hidden_layers?, (p.layers.include?(dl) rescue nil)] }
out['photo_cams_unchanged'] = photo.map { |n| p = m.pages[n]; p && p.camera.eye.to_a } == cams_before
out
