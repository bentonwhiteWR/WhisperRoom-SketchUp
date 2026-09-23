# Screenshot of a plan scene exactly as the scene stores it (selecting it applies its tags, hidden
# objects and camera); only the V-Ray light widgets are hidden, and restored. $cms_plan = [page, path, w, h]
m = Sketchup.active_model
v = m.active_view
name, path, w, h = $cms_plan
m.options['PageOptions']['TransitionTime'] = 0.0
pg = m.pages[name]
lights = m.entities.select { |e| e.get_attribute('wr_cms_lights', 'plugin') }
begin
  m.pages.selected_page = pg
  v.camera = pg.camera
  lights.each { |e| e.hidden = true }
  ok = v.write_image(filename: path, width: w, height: h, antialias: true, transparent: false)
ensure
  lights.each { |e| e.hidden = false }
end
[ok, m.layers['CMS Room Dims (EST)'].visible?, pg.camera.perspective?]
