# Drives the REAL entry points (ability_on / ability_off) on the booth component.
# Each is its own committed operation, exactly as the panel does it. The job
# ends with every part back home (that is the thing under test); if it raises
# midway the finally-block resets anyway. Camera and selection restored.
load File.join(WhisperRoom::Tools::SCRIPTS_DIR, 'wr-bridge-lib.rb')
WRB.tool('explode-view.rb')
m = Sketchup.active_model
booth = m.entities.find { |e| e.is_a?(Sketchup::ComponentInstance) && e.definition.name == 'Component' }
v = m.active_view
cam = v.camera
saved_cam = Sketchup::Camera.new(cam.eye, cam.target, cam.up, cam.perspective?, cam.fov)
saved_sel = m.selection.to_a
kids = booth.definition.entities.select { |x| x.is_a?(Sketchup::Group) || x.is_a?(Sketchup::ComponentInstance) }
iep = kids.find { |k| k.definition.name =~ /Iep ceiling/ }
pieces = iep.definition.entities.select { |x| x.is_a?(Sketchup::ComponentInstance) || x.is_a?(Sketchup::Group) }
had_home = pieces.map { |k| !k.get_attribute('WR_Explode', 'home').nil? }
all = kids + pieces
pos = lambda { all.map { |k| o = k.transformation.origin; [o.x.to_f, o.y.to_f, o.z.to_f] } }
dmax = lambda { |a, b| a.each_index.map { |i| (0..2).map { |j| (a[i][j] - b[i][j]).abs }.max }.max }
out = {}
home = pos.call
begin
  m.selection.clear; m.selection.add(booth)
  WR_ExplodeView.ability_on('mode' => 'Axis', 'spread' => '60', 'fan' => '200')
  a = pos.call
  out['moved_at_60'] = a.each_index.count { |i| dmax.call([a[i]], [home[i]]) > 0.001 }
  out['iep_pieces_moved_at_60'] = (kids.length...all.length).count { |i| dmax.call([a[i]], [home[i]]) > 0.001 }
  WR_ExplodeView.ability_on('mode' => 'Axis', 'spread' => '90', 'fan' => '200')
  b = pos.call
  out['max_change_60_to_90'] = dmax.call(a, b).round(2)
  WR_ExplodeView.ability_on('mode' => 'Axis', 'spread' => '60', 'fan' => '200')
  out['back_to_60_err'] = dmax.call(a, pos.call)
  m.selection.clear
  WR_ExplodeView.ability_off({})
  out['reset_no_selection_err'] = dmax.call(home, pos.call)
  %w[Radial Vertical].each do |md|
    m.selection.clear; m.selection.add(booth)
    ok = WR_ExplodeView.ability_on('mode' => md, 'spread' => '60', 'fan' => '200')
    out["#{md}_ran"] = ok
    m.selection.clear
    WR_ExplodeView.ability_off({})
    out["#{md}_reset_err"] = dmax.call(home, pos.call)
  end
ensure
  err = dmax.call(home, pos.call)
  if err > 1e-6
    m.start_operation('WR explode test cleanup', true)
    all.each_with_index { |k, i| d = Geom::Point3d.new(*home[i]) - k.transformation.origin; k.transform!(Geom::Transformation.translation(d)) }
    m.commit_operation
    out['cleanup_needed'] = err
  end
  # Leave the IEP pieces' attributes exactly as found.
  made = pieces.each_index.select { |i| !had_home[i] && pieces[i].get_attribute('WR_Explode', 'home') }
  unless made.empty?
    m.start_operation('WR explode test cleanup (attributes)', true)
    made.each { |i| pieces[i].delete_attribute('WR_Explode') }
    m.commit_operation
  end
  out['home_attrs_created_then_removed'] = made.length
  out['final_err'] = dmax.call(home, pos.call)
  v.camera = saved_cam
  m.selection.clear
  saved_sel.each { |e| m.selection.add(e) if e.valid? }
end
$EV_OUT = out
