# Step 4-5: foam to neutral gray, then place the booth.
# Placement (Benton, corrected 22 Sep): 18 in is measured from the booth's STRUCTURE = its wall-panel
# exterior faces; vent hoods / silencers / seam seals do not count. Measured on this booth (booth-local):
# N (vent) wall panel skin Y 97.0; exterior seam seals 1 in proud of the panel skins (to Y 98 / X 0 / X 146);
# vent box 5.5 in beyond the seals; hood assembly 6.42 in beyond.
# So: N panel face 18.0 in off Wall D; centred on X = W/2 (the side panel faces then sit 19.3 in off
# Walls A and C -- a 144 in panel span cannot be 18 in from both walls of a 182.6 in room).
# THE MOVE IS MEASURED OFF THE PARTS, NEVER OFF THE GROUP ORIGIN: the booth group's origin was found reset
# to (0,0,6.06) after the dimension tools wrote into the group, and an origin-based move threw the booth
# 155.74 in north (observed 22 Sep, corrected by this version).
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/cms/room.rb'
m = Sketchup.active_model
l, w, h, = WR_CMS.dims
b = m.entities.find { |e| e.respond_to?(:name) && e.name == 'MDL 96144 E (components)' }
raise 'no booth' unless b
SEAL_PROUD = 1.0
env = lambda do
  t = b.transformation
  seal = Geom::BoundingBox.new
  hood = Geom::BoundingBox.new
  plate = Geom::BoundingBox.new
  b.definition.entities.each do |e|
    next unless e.respond_to?(:definition)
    n = e.definition.name
    next if n =~ /\AENH /
    8.times do |i|
      pt = e.bounds.corner(i).transform(t)
      seal.add(pt) if n =~ /Seal|Panel|Door/ && n !~ /Vnt/
      hood.add(pt) if n =~ /Vnt/
      plate.add(pt) if n =~ /\ACP\d/
    end
  end
  { 'x0' => seal.min.x.to_f, 'x1' => seal.max.x.to_f, 'y0' => seal.min.y.to_f, 'y1' => seal.max.y.to_f,
    'hx0' => hood.min.x.to_f, 'hy1' => hood.max.y.to_f, 'z0' => plate.min.z.to_f }
end
out = {}
fm = m.materials['[Color_I06]']
users = Hash.new(0)
m.definitions.each { |d| d.entities.each { |e| users[d.name] += 1 if (e.respond_to?(:material) && e.material == fm) || (e.is_a?(Sketchup::Face) && e.back_material == fm) } }
out['Color_I06_users'] = users
fm.color = Sketchup::Color.new(96, 96, 98) if fm && users.keys == ['Foam']
out['foam'] = fm && fm.color.to_a
a = env.call
rep = lambda do |e|
  { 'D_panel' => (l - (e['y1'] - SEAL_PROUD)).round(2), 'D_seal' => (l - e['y1']).round(2), 'D_hood' => (l - e['hy1']).round(2),
    'C_panel' => (e['x0'] + SEAL_PROUD).round(2), 'C_seal' => e['x0'].round(2), 'C_hood' => e['hx0'].round(2),
    'A_panel' => (w - (e['x1'] - SEAL_PROUD)).round(2), 'A_seal' => (w - e['x1']).round(2),
    'A_seal_to_rad1_front' => (w - 5.0 - e['x1']).round(2), 'door_face_Y' => e['y0'].round(2), 'plate_bottom_z' => e['z0'].round(3) }
end
out['before'] = rep.call(a)
dx = w / 2.0 - (a['x0'] + a['x1']) / 2.0
dy = (l - 18.0) - (a['y1'] - SEAL_PROUD)
dz = -a['z0']
m.start_operation('CMS: place booth', true)
begin
  b.transform!(Geom::Transformation.translation([dx, dy, dz]))
  m.commit_operation
rescue Exception
  m.abort_operation
  raise
end
out['moved'] = [dx, dy, dz].map { |v| v.round(3) }
out['after'] = rep.call(env.call)
bb = b.bounds
out['booth_bounds_incl_dims_step'] = [bb.min.to_a, bb.max.to_a].map { |p| p.map { |v| v.to_f.round(1) } }
out
