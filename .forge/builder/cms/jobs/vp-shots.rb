# Every scene exactly as a click shows it, at the viewport's own size (selecting the page applies its
# camera, tags and hidden objects). Only the V-Ray light widgets are hidden, restored in an ensure.
m = Sketchup.active_model
v = m.active_view
m.options['PageOptions']['TransitionTime'] = 0.0
dir = $cms_vp
lights = m.entities.select { |e| e.get_attribute('wr_cms_lights', 'plugin') }
sel = m.pages.selected_page
res = []
begin
  lights.each { |e| e.hidden = true }
  m.pages.each_with_index do |pg, i|
    m.pages.selected_page = pg
    v.refresh
    f = File.join(dir, format('%02d-%s.png', i, pg.name.gsub(/[^A-Za-z0-9 ._-]/, '_')))
    ok = v.write_image(filename: f, width: v.vpwidth.to_i, height: v.vpheight.to_i, antialias: true, transparent: false)
    res << [pg.name, ok, v.camera.perspective? ? v.camera.fov.round(2) : 'ortho']
  end
ensure
  lights.each { |e| e.hidden = false }
  m.pages.selected_page = sel if sel
end
res
