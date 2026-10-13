# Four wall shots from inside the booth with a TEMPORARY camera; the original camera is restored in `ensure`.
# Scenes are not touched. Run with --write-root <ap9/elev>.
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/walsh/ap9/b-lib.rb'
m = B8.model!
b = B8.booth(m)
v = m.active_view
c0 = v.camera
saved = Sketchup::Camera.new(c0.eye, c0.target, c0.up, c0.perspective?, c0.fov)
saved_aspect = c0.aspect_ratio
saved_height = c0.perspective? ? nil : c0.height
mod0 = m.modified?
bt = b.transformation
ar = v.vpwidth.to_f / v.vpheight
W_ = 2400; H_ = (W_ / ar).round
out = {}
begin
  { 'S' => [[85.0, 90.5, 41.5], [85.0, 4.25, 41.5], 161.5], 'N' => [[85.0, 7.5, 41.5], [85.0, 93.75, 41.5], 161.5],
    'E' => [[7.5, 49.0, 41.5], [165.75, 49.0, 41.5], 89.5], 'W' => [[162.5, 49.0, 41.5], [4.25, 49.0, 41.5], 89.5] }.each do |w, (e, t, run)|
    eye = Geom::Point3d.new(*e).transform(bt); tgt = Geom::Point3d.new(*t).transform(bt)
    d = eye.distance(tgt).to_f
    hh = Math.atan((run / 2 + 2) / d); vh = Math.atan(41.0 / d)
    fov = [2 * vh, 2 * Math.atan(Math.tan(hh) / ar)].max * 180 / Math::PI + 2.0
    cam = Sketchup::Camera.new(eye, tgt, Geom::Vector3d.new(0, 0, 1), true, fov)
    v.camera = cam
    fn = "#{B8::DIR}/elev/live-#{w}.png"
    v.write_image(filename: fn, width: W_, height: H_, antialias: true, transparent: false)
    out[w] = { 'file' => fn, 'fov' => fov.round(2), 'dist' => d.round(2), 'size' => [W_, H_] }
  end
ensure
  v.camera = saved
  v.camera.aspect_ratio = saved_aspect
  v.camera.height = saved_height if saved_height
end
c1 = v.camera
out['camera_restored'] = c1.eye.distance(saved.eye).to_f < 1e-6 && c1.target.distance(saved.target).to_f < 1e-6 && (c1.fov - saved.fov).abs < 1e-6 && c1.aspect_ratio == saved_aspect
out['modified'] = [mod0, m.modified?]
out['scene'] = m.pages.selected_page && m.pages.selected_page.name
$b8_result = JSON.generate(out)
