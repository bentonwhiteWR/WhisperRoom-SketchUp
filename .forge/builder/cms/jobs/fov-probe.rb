# READ-ONLY probe on the VIEW camera (restored at the end): how does SketchUp store fov = 35?
m = Sketchup.active_model
v = m.active_view
keep = v.camera.clone rescue Sketchup::Camera.new(v.camera.eye, v.camera.target, v.camera.up)
out = {}
begin
  # (a) exactly what WR_ProposalScenes.aim does: mutate view.camera in place
  c = v.camera
  c.perspective = true
  c.fov = 35.0
  c.set(Geom::Point3d.new(-89.8, -52.6, 61.0), Geom::Point3d.new(91.3, 204.0, 44.0), Z_AXIS)
  out['a_inplace'] = [v.camera.fov.round(2), v.camera.fov_is_height?, v.camera.aspect_ratio]
  # (b) from a persp camera already at 14.24, set 35 again in place
  c = v.camera
  c.fov = 35.0
  out['b_again'] = [v.camera.fov.round(2)]
  # (c) a fresh camera assigned
  n = Sketchup::Camera.new(Geom::Point3d.new(-89.8, -52.6, 61.0), Geom::Point3d.new(91.3, 204.0, 44.0), Z_AXIS)
  n.fov = 35.0
  pre = n.fov
  v.camera = n
  out['c_fresh'] = [pre.round(2), v.camera.fov.round(2), v.camera.fov_is_height?]
  # (d) start from a PARALLEL camera, then flip to perspective and set 35 (legacy plates ran right after one)
  c = v.camera
  c.perspective = false
  c = v.camera
  c.perspective = true
  c.fov = 35.0
  out['d_from_parallel'] = [v.camera.fov.round(2), v.camera.fov_is_height?]
ensure
  v.camera = keep
end
out['restored_fov'] = v.camera.fov.round(2)
out['vp'] = [v.vpwidth, v.vpheight]
out
