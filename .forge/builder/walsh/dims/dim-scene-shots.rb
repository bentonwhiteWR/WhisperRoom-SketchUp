m = Sketchup.active_model
raise "wrong model: #{m.path}" unless m.path.end_with?("Walsh Construction Tech Lab MDL 96168 E.skp")
po = m.options['PageOptions']; tr = po['ShowTransition']
start = m.pages.selected_page; cam = m.active_view.camera
eye, tgt, up, persp, fov = cam.eye, cam.target, cam.up, cam.perspective?, (cam.perspective? ? cam.fov : nil)
res = []
begin
  po['ShowTransition'] = false
  ['Opt2 03 BoothDims', 'Opt2 06 TopDown', 'Opt1 03 BoothDims'].each do |n|
    pg = m.pages[n] or next
    m.pages.selected_page = pg
    f = "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/walsh/ap9/elev/dims-all-#{n.gsub(/\W+/, '_')}.png"
    res << [n, m.active_view.write_image(filename: f, width: 1800, height: 1100, antialias: true)]
  end
ensure
  m.pages.selected_page = start if start
  c = m.active_view.camera
  c.set(eye, tgt, up); c.perspective = persp; c.fov = fov if persp && fov
  po['ShowTransition'] = tr
end
[res, m.modified?].inspect
