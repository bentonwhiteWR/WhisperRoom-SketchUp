# Walsh: re-frame Opt1/Opt2 06 TopDown so every floor dimension fits. Camera only (Page#update(1));
# direction, projection, tags and every other scene property stay as they were.
m = Sketchup.active_model
raise "wrong model: #{m.path}" unless m.path.end_with?("Walsh Construction Tech Lab MDL 96168 E.skp")
names = ['Opt2 06 TopDown', 'Opt1 06 TopDown']
pages = names.map { |n| m.pages[n] or raise "no scene #{n}" }
room = nil
m.entities.each { |e| room = e if e.is_a?(Sketchup::Group) && e.name == 'Tech Lab 13' }
dims = m.entities.grep(Sketchup::DimensionLinear).select { |d| d.layer.name.start_with?('WR-Dims') }
raise 'room group not at top level' unless room
raise "only #{dims.size} dims" unless dims.size == 23
fit = [room] + dims
v = m.active_view
po = m.options['PageOptions']; tr = po['ShowTransition']
start = m.pages.selected_page
before = pages.map { |p| c = p.camera; [p.name, c.perspective?, c.direction.to_a.map { |x| x.round(3) }, c.eye.to_a.map { |x| x.to_f.round(1) }] }
m.save(m.path)
opened = false
after = []
begin
  po['ShowTransition'] = false
  m.start_operation('Walsh: re-frame TopDown scenes', true)
  opened = true
  pages.each do |p|
    m.pages.selected_page = p
    dir = v.camera.direction.clone
    v.zoom(fit)
    v.zoom(0.88)
    raise 'view direction changed' unless v.camera.direction.parallel?(dir) && v.camera.direction.samedirection?(dir)
    p.update(1)
    f = "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/walsh/ap9/elev/topdown-reframed-#{p.name.gsub(/\W+/, '_')}.png"
    v.write_image(filename: f, width: 1920, height: 1080, antialias: true)
    c = p.camera
    after << [p.name, c.perspective?, c.eye.to_a.map { |x| x.to_f.round(1) }]
  end
  m.commit_operation
  opened = false
rescue => ex
  m.abort_operation if opened
  raise
ensure
  m.pages.selected_page = start if start
  po['ShowTransition'] = tr
end
m.save(m.path)
[before, after, m.modified?, v.vpwidth, v.vpheight].inspect
