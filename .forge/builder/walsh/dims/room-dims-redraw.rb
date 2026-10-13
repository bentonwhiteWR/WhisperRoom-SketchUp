# Walsh: redraw the Tech Lab room dimensions (6 runs + 2 overalls on WR-Dims, door 24 corner + width on
# WR-Dims-Doors) with the house engine, anchored on construction points at the floor (z 0).
# The surviving 3' door dimension is erased first so the engine's redraw doesn't duplicate it.
m = Sketchup.active_model
raise "wrong model: #{m.path}" unless m.path.end_with?("Walsh Construction Tech Lab MDL 96168 E.skp")
$wr_suppress_autorun = true
load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/auto-dimension.rb"
$wr_suppress_autorun = false
AD = WR_AutoDimension

# The room floor: group 'Tech Lab 13' > group 'Floor' > its one face, with the world transform.
hit = nil
walk = lambda do |ents, tr, parent|
  ents.each do |e|
    next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    t = tr * e.transformation
    if e.name == 'Floor' && parent == 'Tech Lab 13'
      faces = e.definition.entities.grep(Sketchup::Face)
      raise "Floor group has #{faces.size} faces" unless faces.size == 1
      raise 'found two Tech Lab floors' if hit
      hit = [faces[0], t]
    end
    walk.call(e.definition.entities, t, e.name)
  end
end
walk.call(m.entities, Geom::Transformation.new, nil)
raise 'Tech Lab 13 floor not found' unless hit
floor, tr = hit
fz = floor.outer_loop.vertices[0].position.transform(tr).z.to_f
raise "floor is at z #{fz}, expected 0" unless fz.abs < 0.01

existing = m.entities.grep(Sketchup::DimensionLinear).select { |d| AD.own_tag?(d.layer.name) }
raise "expected only the 3' door dim on the engine's tags, found #{existing.size}" unless existing.size == 1 && existing[0].layer.name == 'WR-Dims-Doors'
anchors = [existing[0].start[0], existing[0].end[0]].select { |a| a.is_a?(Sketchup::ConstructionPoint) }

# Door 24 in world space, exactly as build-techlab.rb builds it: run 3 (SE -> SW), near jamb 203.52 from SE, 36 wide.
a = Geom::Point3d.new(243.520, 0, 0).transform(tr)
b = Geom::Point3d.new(0, 0, 0).transform(tr)
u = (b - a).normalize
box = Geom::BoundingBox.new
box.add(a.offset(u, 203.52)); box.add(a.offset(u, 239.52))

m.save(m.path)
opened = false
res = nil
begin
  m.start_operation('Walsh: redraw room dimensions on the floor', true)
  opened = true
  existing.each { |d| d.erase! if d.valid? }
  anchors.each { |c| c.erase! if c.valid? }
  res = AD.dimension_face(floor, transform: tr, doors: [box], anchor: :cpoint)
  dims = m.entities.grep(Sketchup::DimensionLinear).select { |d| AD.own_tag?(d.layer.name) }
  room = dims.select { |d| d.layer.name == 'WR-Dims' }
  door = dims.select { |d| d.layer.name == 'WR-Dims-Doors' }
  raise "room dims #{room.size}, expected 8" unless room.size == 8
  raise "door dims #{door.size}, expected 2" unless door.size == 2
  high = dims.reject { |d| d.start[1].z.to_f.abs < 0.01 && d.end[1].z.to_f.abs < 0.01 }
  raise "#{high.size} dims not at z 0" unless high.empty?
  m.commit_operation
  opened = false
rescue => ex
  m.abort_operation if opened
  raise
end
m.save(m.path)
dims = m.entities.grep(Sketchup::DimensionLinear).select { |d| AD.own_tag?(d.layer.name) }
[m.modified?, dims.map { |d| [d.layer.name, d.text, d.start[1].distance(d.end[1]).to_f.round(3)] }].inspect
