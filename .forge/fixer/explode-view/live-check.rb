# Live repro/verify for explode-view.rb. Runs INSIDE an operation that is
# ABORTED at the end, so the model is left exactly as it was. Camera restored.
#   $EV = { 'mode' => 'Axis', 'spread' => 0.6, 'fan' => 1.5, 'shot' => 'name' }
load File.join(WhisperRoom::Tools::SCRIPTS_DIR, 'wr-bridge-lib.rb')
WRB.tool('explode-view.rb')
cfg = ($EV || {})
m = Sketchup.active_model
booth = cfg['target'] ? m.entities.find { |e| e.is_a?(Sketchup::Group) && e.name == cfg['target'] } : m.entities.find { |e| e.is_a?(Sketchup::ComponentInstance) && e.definition.name == 'Component' }
raise 'booth component not found' unless booth
v = m.active_view
cam = v.camera
saved_cam = Sketchup::Camera.new(cam.eye, cam.target, cam.up, cam.perspective?, cam.fov)
saved_sel = m.selection.to_a
out = {}
def ov(a, b, tol = 0.05)
  (0..2).all? { |i| [a[1][i], b[1][i]].min - [a[0][i], b[0][i]].max > tol }
end
def boxes(ps)
  ps.map { |e| b = e.bounds; [[b.min.x, b.min.y, b.min.z].map(&:to_f), [b.max.x, b.max.y, b.max.z].map(&:to_f)] }
end
m.start_operation('WR explode live check', true)
begin
  m.selection.clear
  m.selection.add(booth)
  ps = WR_ExplodeView.parts(m)
  home = boxes(ps)
  mode = cfg['mode'] == 'Radial' ? :radial : (cfg['mode'] == 'Vertical' ? :vertical : :axis)
  plan, _c, _s = WR_ExplodeView.plan_for(ps, mode, cfg['spread'] || 0.6, cfg['fan'] || 1.5)
  WR_ExplodeView.place(plan, 1.0)
  exp = boxes(ps)
  names = ps.map { |e| e.name.to_s.empty? ? e.definition.name : e.name }
  newov = []; keptov = 0; homeov = 0
  ps.length.times do |i|
    (i + 1...ps.length).each do |j|
      h = ov(home[i], home[j]); x = ov(exp[i], exp[j])
      homeov += 1 if h
      keptov += 1 if h && x
      if h && x && plan[i][:group]
        gi = [plan[i][:group], plan[i][:side]].inspect; gj = [plan[j][:group], plan[j][:side]].inspect
        (out['kept_cross'] ||= []) << "#{names[i][0,26]} #{gi} X #{names[j][0,26]} #{gj}" if gi != gj || gi !~ /floor/
        (out['kept_by'] ||= Hash.new(0))[[gi, gj].sort.join(' ~ ')] += 1
      end
      newov << "#{names[i]} X #{names[j]}" if x && !h
    end
  end
  out['parts'] = ps.length
  out['planned'] = plan.length
  out['home_overlaps'] = homeov
  out['home_overlaps_still'] = keptov
  out['new_overlaps'] = newov.length
  out['new_overlap_sample'] = newov.first(25)
  if cfg['watch']
    out['watch'] = plan.select { |p| n = (p[:ent].name.to_s.empty? ? p[:ent].definition.name : p[:ent].name); n =~ cfg['watch'] }.map { |p| n = (p[:ent].name.to_s.empty? ? p[:ent].definition.name : p[:ent].name); [n[0,28], p[:box].center.to_a.map { |v| v.to_f.round(1) }, p[:off].to_a.map { |v| v.to_f.round(1) }] }
  end
  out['groups'] = plan.map { |p| p[:group] }.compact.tally if plan.first && plan.first.key?(:group)
  if cfg['shot']
    wb = Geom::BoundingBox.new
    ps.each { |e| b = e.bounds; wb.add(b.min.transform(booth.transformation)); wb.add(b.max.transform(booth.transformation)) }
    c = wb.center; r = wb.diagonal
    dirs = cfg['dirs'] || { 'iso' => [1, -1.3, 0.9] }
    dirs.each do |tag, d|
      dv = Geom::Vector3d.new(*d); dv.length = r * 1.6
      up = tag == 'top' ? Geom::Vector3d.new(0, 1, 0) : Geom::Vector3d.new(0, 0, 1)
      v.camera = Sketchup::Camera.new(c.offset(dv), c, up, tag != 'top', 35)
      v.zoom(ps.map { |e| e }) rescue nil
      v.camera = Sketchup::Camera.new(c.offset(dv), c, up, tag != 'top', 35)
      hidden = m.entities.select { |e| e != booth && e.visible? }
      hidden.each { |e| e.visible = false }
      v.zoom_extents
      WRB.shot("#{cfg['shot']}-#{tag}.png", 1400, 1000)
      hidden.each { |e| e.visible = true }
    end
  end
  # reset path: every part exactly home?
  WR_ExplodeView.place(plan, 0.0)
  back = boxes(ps)
  out['max_home_err'] = ps.length.times.map { |i| (0..1).map { |k| (0..2).map { |a| (back[i][k][a] - home[i][k][a]).abs }.max }.max }.max
ensure
  m.abort_operation
  v.camera = saved_cam
  m.selection.clear
  saved_sel.each { |e| m.selection.add(e) if e.valid? }
end

$EV_OUT = out
