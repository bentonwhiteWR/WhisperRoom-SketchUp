# read-only preview: select the 01-angled page (its tags), then set a candidate camera on the view only
m = Sketchup.active_model
pg = m.pages.find { |p| p.name.end_with?('01-angled') }
m.pages.selected_page = pg
eye = $try_eye; tgt = $try_tgt
m.active_view.camera = Sketchup::Camera.new(eye, tgt, Z_AXIS, true, $try_fov)
"ok"
