# Per wall-facing side: the booth STRUCTURE face (wall panels + corner/mid seals, NOT vent hoods,
# duct covers, step or plates) and the hood face, each measured to its room wall. World inches.
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/cms/room.rb'
m = Sketchup.active_model
l, w, h, = WR_CMS.dims
b = m.entities.find { |e| e.respond_to?(:name) && e.name == 'MDL 96144 E (components)' }
t = b.transformation
struct = []
hoods = []
b.definition.entities.each do |e|
  next unless e.respond_to?(:definition)
  n = e.definition.name
  next if n =~ /\AENH /                     # inner (IEP) shell
  bb = Geom::BoundingBox.new
  e.bounds.corner(0) # noop
  8.times { |i| bb.add(e.bounds.corner(i).transform(t)) }
  if n =~ /Vnt/
    # a vent part: its PANEL is the slab within 2 in of the wall line; the box beyond is the hood
    hoods << [n, bb]
    ents = e.definition.entities
    fx = ents.grep(Sketchup::Face).select { |f| f.area > 500 } # big flat faces = the panel skin
    pb = Geom::BoundingBox.new
    fx.each { |f| f.vertices.each { |v| pb.add(v.position.transform(e.transformation).transform(t)) } }
    struct << ["#{n} panel faces", pb] if pb.valid?
  elsif n =~ /Panel|Door|Seal|WDO/
    struct << [n, bb]
  end
end
sx0 = struct.map { |_, bb| bb.min.x }.min; sx1 = struct.map { |_, bb| bb.max.x }.max
sy1 = struct.map { |_, bb| bb.max.y }.max; sy0 = struct.map { |_, bb| bb.min.y }.min
hx0 = hoods.map { |_, bb| bb.min.x }.min; hy1 = hoods.map { |_, bb| bb.max.y }.max
{ 'struct_x' => [sx0, sx1].map { |v| v.to_f.round(2) }, 'struct_y' => [sy0, sy1].map { |v| v.to_f.round(2) },
  'D_panel' => (l - sy1).to_f.round(2), 'D_hood' => (l - hy1).to_f.round(2),
  'C_panel' => sx0.to_f.round(2), 'C_hood' => hx0.to_f.round(2),
  'A_panel' => (w - sx1).to_f.round(2), 'A_radiator1_front' => (w - 5.0 - sx1).to_f.round(2),
  'who_sets' => { 'maxY' => struct.max_by { |_, bb| bb.max.y }[0], 'minX' => struct.min_by { |_, bb| bb.min.x }[0], 'maxX' => struct.max_by { |_, bb| bb.max.x }[0] } }
