# Cycle the 16 scenes (select only; no page is updated, added or deleted), shoot each to elev/scene-NN.png and
# test every camera against the new foam/Audimute pieces. Restores transition time, scene and live camera.
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/walsh/ap9/b-lib.rb'
m = B8.model!
b = B8.booth(m)
v = m.active_view
pages = m.pages
mod0 = m.modified?
prev_page = pages.selected_page
c0 = v.camera
saved = Sketchup::Camera.new(c0.eye, c0.target, c0.up, c0.perspective?, c0.fov)
saved_aspect = c0.aspect_ratio
popts = m.options['PageOptions']
prev_tt = popts['TransitionTime']
bi = b.transformation.inverse
pcs = B8.pieces(b)
boxes = pcs.map do |e|
  lo, hi = B8.body_local(e.definition)
  pts = [lo[0], hi[0]].product([lo[1], hi[1]], [lo[2], hi[2]]).map { |a, c, d| Geom::Point3d.new(a, c, d).transform(e.transformation) }
  [e, [0, 1, 2].map { |i| pts.map { |p| [p.x, p.y, p.z][i].to_f }.minmax }]
end
dist_to_box = lambda do |p, bx|
  d = [p.x.to_f, p.y.to_f, p.z.to_f].each_with_index.map { |c, i| lo, hi = bx[i]; c < lo ? lo - c : (c > hi ? c - hi : 0.0) }
  Math.sqrt(d.sum { |x| x * x })
end
ar = v.vpwidth.to_f / v.vpheight
W_ = 1600; H_ = (W_ / ar).round
out = { 'scenes' => [] }
begin
  popts['TransitionTime'] = 0.0
  pages.to_a.each_with_index do |pg, i|
    pages.selected_page = pg
    cam = v.camera
    eye_l = cam.eye.transform(bi)
    near = boxes.map { |e, bx| [dist_to_box.call(eye_l, bx), e] }.min_by(&:first)
    hit = m.raytest([cam.eye, cam.target - cam.eye], true)
    first = nil
    if hit
      piece = hit[1].find { |e| pcs.include?(e) }
      first = { 'dist' => cam.eye.distance(hit[0]).to_f.round(2), 'piece' => piece ? piece.name : nil,
                'what' => (hit[1].reverse.find { |e| e.respond_to?(:definition) } || hit[1].last).then { |e| e.respond_to?(:definition) ? e.definition.name : e.class.name } }
    end
    fn = format('%s/elev/scene-%02d.png', B8::DIR, i + 1)
    ok = v.write_image(filename: fn, width: W_, height: H_, antialias: true, transparent: false)
    out['scenes'] << { 'n' => i + 1, 'name' => pg.name, 'file' => fn, 'written' => ok,
                       'eye_booth_local' => [eye_l.x, eye_l.y, eye_l.z].map { |c| c.to_f.round(2) },
                       'nearest_piece' => near[1].name, 'eye_to_piece' => near[0].round(2), 'centre_ray_first_hit' => first }
  end
ensure
  popts['TransitionTime'] = prev_tt
  pages.selected_page = prev_page if prev_page
  v.camera = saved
  v.camera.aspect_ratio = saved_aspect
end
c1 = v.camera
out['restored'] = { 'scene' => pages.selected_page && pages.selected_page.name, 'transition' => popts['TransitionTime'],
                    'camera' => c1.eye.distance(saved.eye).to_f < 1e-6 && c1.target.distance(saved.target).to_f < 1e-6 && (c1.fov - saved.fov).abs < 1e-6 }
out['pages'] = pages.count
out['modified'] = [mod0, m.modified?]
$b8_result = JSON.generate(out)
