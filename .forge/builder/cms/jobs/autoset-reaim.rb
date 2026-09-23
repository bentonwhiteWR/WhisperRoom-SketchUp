# Re-aim every AUTO-SET plate with AUTO-SET's OWN apply (mode update, reaim), from a CLEAN view camera.
# WR_ProposalScenes.aim mutates whatever camera the view already has; if that camera carries an
# aspect_ratio (a photo-match scene leaves 0.75 / 1.333), fov = 35 is stored as a HORIZONTAL fov. So the
# view gets a fresh perspective camera with aspect 0 first. Scene count is unchanged (update mode).
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/proposal-package.rb'
m = Sketchup.active_model
v = m.active_view
before = m.pages.map(&:name)
clean = Sketchup::Camera.new(Geom::Point3d.new(-100, -100, 60), Geom::Point3d.new(90, 200, 40), Z_AXIS)
clean.perspective = true
clean.fov = 35.0
v.camera = clean
pre = [v.camera.fov, v.camera.aspect_ratio, v.camera.fov_is_height?]
booth, note = WR_AutoSet.resolve_booth(m, 'MDL 96144 E (components)')
raise(note || 'no booth') if booth.nil?
ok, msg, lines = WR_AutoSet.apply(m, booth, { 'mode' => 'update', 'renders' => WR_AutoSet::MAX_RENDERS, 'interior' => true, 'reaim' => true })
after = m.pages.map(&:name)
cams = m.pages.select { |p| p.get_attribute('WR_AutoSet', 'plate') }.map { |p| c = p.camera; [p.name.sub('MDL 96144 E (components) ', ''), c.perspective? ? c.fov.round(2) : "ortho h#{c.height.to_f.round}", c.aspect_ratio, c.fov_is_height?] }
{ 'view_before' => pre, 'ok' => ok, 'msg' => msg.to_s[0, 300], 'pages_same' => before == after, 'count' => after.size, 'cams' => cams }
