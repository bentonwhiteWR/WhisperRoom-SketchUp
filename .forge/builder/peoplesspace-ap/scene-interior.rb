m = Sketchup.active_model
po = m.options['PageOptions']; tr = po['ShowTransition']; po['ShowTransition'] = false
src = m.pages['OverviewRender']
m.pages.selected_page = src
name = 'InteriorAcousticRender'
raise "#{name} already exists" if m.pages[name]
# eye: just inside the window corner (front IEP face x 95.75, far wall face y 122.4), ~60 in above the raised floor (4.06)
cam = Sketchup::Camera.new([91.5, 118.0, 64.0], [6.3, 9.0, 46.0], [0, 0, 1])
cam.perspective = true; cam.fov = 70
m.active_view.camera = cam
idx = m.pages.to_a.index(m.pages['InteriorDims'])
pg = m.pages.add(name, PAGE_USE_ALL, idx)
pg.use_camera = true
m.pages.selected_page = pg
po['ShowTransition'] = tr
c = pg.camera
puts "added '#{pg.name}' at position #{m.pages.to_a.index(pg) + 1}/#{m.pages.size}; style #{pg.style&.name}; hidden tags #{pg.layers.map(&:name)}; eye #{c.eye.to_a.map { |v| v.to_f.round(1) }} fov #{c.fov}"
nil
