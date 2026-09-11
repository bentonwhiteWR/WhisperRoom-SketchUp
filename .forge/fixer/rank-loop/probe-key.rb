$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/wr-drop-lights.rb'
$wr_no_autorun = nil
D = WR_DropLights
m = Sketchup.active_model
room  = m.entities.grep(Sketchup::Group).find { |g| g.name == 'Room' }
booth = m.entities.grep(Sketchup::Group).find { |g| g.name =~ /MDL/ }
info = D.room_info(room)
poly = info[:poly]
z_top = info[:z_top]
z_m = z_top
obst, skipped = D.obstructions(m, room, poly, z_m, [room, booth])
keepouts = obst.map { |o| o[:rect] }
o = obst.find { |x| x[:ent] == booth }
bb = o[:bb]
cx = (bb.min.x + bb.max.x) / 2.0; cy = (bb.min.y + bb.max.y) / 2.0
dc = D.booth_door_center(o)
dlen = Math.sqrt((dc[0]-cx)**2 + (dc[1]-cy)**2)
ux = (dc[0]-cx)/dlen; uy = (dc[1]-cy)/dlen
trace = []
d = D::ACCENT_OUT
while d >= D::ACCENT_MIN - 1e-9
  x = dc[0] + ux*d; y = dc[1] + uy*d
  trace << [d, x.round(1), y.round(1), D.point_in_poly?(x,y,poly), D.edge_dist(x,y,poly).round(1), D.in_keepout?(x,y,keepouts)]
  d -= D::ACCENT_STEP
end
kd = D.accent_standoff(dc, ux, uy, poly, keepouts, D::ACCENT_OUT, D::ACCENT_MIN, D::ACCENT_STEP, D::ACCENT_MARGIN)
doors = D.child_entities(booth).to_a.select { |e| D.layer_name(e) == 'WR-Booth-Door' }.map { |e| wb = D.world_bounds(e, o[:tr] * booth.transformation); [D.display_name(e), wb.min.to_a.map{|v| v.round(1)}, wb.max.to_a.map{|v| v.round(1)}] }
{ :poly => poly.map { |p| p.map { |v| v.round(1) } }, :z0 => info[:z0], :z_top => z_top,
  :booth_bb => [bb.min.to_a.map{|v| v.round(1)}, bb.max.to_a.map{|v| v.round(1)}],
  :booth_centre => [cx.round(1), cy.round(1)], :door_centre => dc.map { |v| v.round(1) },
  :normal => [ux.round(3), uy.round(3)], :keepouts => keepouts.map { |k| k.map { |v| v.round(1) } },
  :door_panels => doors, :trace => trace, :kd => kd, :room_doors => info[:doors] }
