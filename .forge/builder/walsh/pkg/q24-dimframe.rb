# Read-only: for each image page, project every RM dim (16:9) and report which are fully in frame.
m = Sketchup.active_model
DIMG = m.find_entity_by_persistent_id(3442717)
def world_tr(e)
  t = Geom::Transformation.new; d = e
  while d.respond_to?(:parent) && d.parent.is_a?(Sketchup::ComponentDefinition)
    i = d.parent.instances.first; break unless i
    t = i.transformation * t; d = i
  end
  t
end
TR = world_tr(DIMG) * DIMG.transformation
def proj(cam, pt, asp)
  eye = cam.eye; z = cam.direction.normalize; up = cam.up.normalize; x = z.cross(up).normalize; y = x.cross(z)
  v = pt - eye; dz = v.dot(z); dx = v.dot(x); dy = v.dot(y)
  if cam.perspective?
    return nil if dz <= 1
    fy = Math.tan(cam.fov.degrees / 2)
    fy = fy / asp unless cam.fov_is_height?
    [dx / dz / (fy * asp), dy / dz / fy]
  else
    h = cam.height / 2.0
    [dx / (h * asp), dy / h]
  end
end
def dim_pts(d)
  s = d.start[1]; e = d.end[1]; o = d.offset_vector
  s2 = s.offset(o); e2 = e.offset(o)
  dirv = e2 - s2; len = dirv.length
  ex = len > 0 ? dirv.normalize : Geom::Vector3d.new(1,0,0)
  pts = [s, e, s2, e2]
  ext = [len * 0.35, 18].max
  case d.text_position
  when Sketchup::DimensionLinear::TEXT_OUTSIDE_START then pts << s2.offset(ex.reverse, ext)
  when Sketchup::DimensionLinear::TEXT_OUTSIDE_END then pts << e2.offset(ex, ext)
  end
  pts.map { |p| p.transform(TR) }
end
FRAME = (defined?(FRAME_M) ? FRAME_M : 0.94)
def in_frame(cam, d)
  dim_pts(d).all? { |p| q = proj(cam, p, 16.0 / 9); q && q[0].abs <= FRAME && q[1].abs <= FRAME }
end
start = m.pages.selected_page
prevT = m.options['PageOptions']['ShowTransition']; m.options['PageOptions']['ShowTransition'] = false
$dimframe = {}
begin
  m.pages.each do |p|
    m.pages.selected_page = p
    cam = m.active_view.camera
    vis = DIMG.entities.grep(Sketchup::DimensionLinear).select { |d| d.layer.visible? }
    out = vis.reject { |d| in_frame(cam, d) }
    $dimframe[p.name] = out.map(&:persistent_id)
    puts "  eye=#{cam.eye.to_a.map(&:round)} tgt=#{cam.target.to_a.map(&:round)} pcam=#{p.camera.eye.to_a.map(&:round)}"
    puts "#{p.name.split(' ').last(2).join(' ')} hg=#{p.use_hidden_geometry?} ho=#{p.use_hidden_objects?} persp=#{cam.perspective?} fovH=#{cam.fov_is_height? rescue '?'} visible=#{vis.size} OUT=#{out.map { |d| "#{d.persistent_id}:#{d.text}#{d.hidden? ? '(hid)' : ''}" }.join(', ')}"
  end
ensure
  m.pages.selected_page = start if start
  m.options['PageOptions']['ShowTransition'] = prevT
end
true
