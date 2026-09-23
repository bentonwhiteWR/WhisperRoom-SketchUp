# Viewport thumbnail of every scene (selecting each applies its stored tags / hidden walls). $cms_thumbs = out dir.
m = Sketchup.active_model
v = m.active_view
m.options['PageOptions']['TransitionTime'] = 0.0
dir = $cms_thumbs
res = []
m.pages.each_with_index do |pg, i|
  m.pages.selected_page = pg
  v.camera = pg.camera
  v.refresh
  f = File.join(dir, format('%02d-%s.png', i, pg.name.gsub(/[^A-Za-z0-9 ._-]/, '_')))
  ok = v.write_image(filename: f, width: 900, height: 600, antialias: true, transparent: false)
  dl = m.layers['CMS Room Dims (EST)']
  res << [pg.name, ok, dl.visible?]
end
res
