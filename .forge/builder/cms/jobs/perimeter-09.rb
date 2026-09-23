# 18 in clearance perimeter around the booth, for "09-interior dims" only (Benton, 22 Sep).
# Offset 18 in outward from the booth STRUCTURE = the wall-panel exterior faces (seal envelope minus the
# measured 1.0 in seal proud, as jobs/place.rb); hoods / silencers do not count. Drawn inside the booth
# group (travels with it) on its own dashed tag; 18" dims on two sides (no EST.: a drawn offset); a floor
# label. Shown only in 09. Then a REPORT-ONLY check of the perimeter against the room.
m = Sketchup.active_model
v = m.active_view
ps = m.pages
pd = 'wr_cms_perim'
m.options['PageOptions']['TransitionTime'] = 0.0
b = m.entities.find { |e| e.respond_to?(:name) && e.name == 'MDL 96144 E (components)' }
bt = b.transformation
inv = bt.inverse
tag = m.layers['CMS Booth 18in Perimeter'] || m.layers.add('CMS Booth 18in Perimeter')
ls = (m.line_styles['Dash'] rescue nil) || (m.line_styles['Dash Dot'] rescue nil)
tag.line_style = ls if ls
tag.color = Sketchup::Color.new(238, 98, 22)   # brand orange; thin dashed line
seal = Geom::BoundingBox.new
hood = Geom::BoundingBox.new
b.definition.entities.each do |e|
  next unless e.respond_to?(:definition)
  n = e.definition.name
  next if n =~ /\AENH /
  8.times do |i|
    pt = e.bounds.corner(i).transform(bt)
    seal.add(pt) if n =~ /Seal|Panel/ && n !~ /Vnt/   # NOT the door part: its leaf/handle stand 1.27 in proud of the wall
    hood.add(pt) if n =~ /Vnt/
  end
end
px0, px1 = seal.min.x.to_f + 1.0, seal.max.x.to_f - 1.0     # panel faces
py0, py1 = seal.min.y.to_f + 1.0, seal.max.y.to_f - 1.0
r = [px0 - 18.0, py0 - 18.0, px1 + 18.0, py1 + 18.0]
z = 6.81 + 0.3
out = { 'panel_faces' => [px0, py0, px1, py1].map { |x| x.round(2) }, 'perimeter' => r.map { |x| x.round(2) } }
m.start_operation('CMS: 09 perimeter', true)
begin
  be = b.definition.entities
  be.erase_entities(be.select { |e| e.valid? && e.get_attribute(pd, 'own', false) })
  g = be.add_group
  g.name = '18 in clearance perimeter'
  pts = [[r[0], r[1], z], [r[2], r[1], z], [r[2], r[3], z], [r[0], r[3], z]].map { |p| Geom::Point3d.new(*p).transform(inv) }
  4.times { |i| g.entities.add_line(pts[i], pts[(i + 1) % 4]) }
  mk = lambda do |a, c, off, txt|
    d = be.add_dimension_linear(Geom::Point3d.new(*a).transform(inv), Geom::Point3d.new(*c).transform(inv), Geom::Vector3d.new(*off).transform(inv))
    d.text = txt
    d
  end
  d1 = mk.call([140.0, py0, z], [140.0, r[1], z], [0.5, 0, 0], '18"')        # front (door wall) side
  d2 = mk.call([px0, 178.0, z], [r[0], 178.0, z], [0, 0.5, 0], '18"')        # west side
  lg = be.add_group
  lg.entities.add_3d_text('18 in CLEARANCE PERIMETER', TextAlignLeft, 'Arial', true, false, 2.5, 0.0, 0.0, true, 0.0)
  lg.transform!(Geom::Transformation.translation(Geom::Point3d.new(84.0, r[1] + 5.0, z).transform(inv) - ORIGIN))
  [g, d1, d2, lg].each { |e| e.layer = tag; e.set_attribute(pd, 'own', true) }
  lg.material = m.materials['CMS Floor Text']
  # visible only in 09
  ps.each { |p| p.set_visibility(tag, p.name == '09-interior dims') if p.use_hidden_layers? }
  tag.visible = false
  # widen 09's frame to take the band + label (camera only)
  p9 = ps['09-interior dims']
  c9 = p9.camera
  cam = Sketchup::Camera.new(c9.eye, c9.target, c9.up)
  cam.perspective = false
  cam.height = (r[3] - r[1]) + 44.0
  ce = Geom::Point3d.new((r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, 1500)
  cam.set(ce, Geom::Point3d.new(ce.x, ce.y, 0), Y_AXIS)
  ps.selected_page = p9
  v.camera = cam
  p9.update(PAGE_USE_CAMERA)
  tag.visible = false
  m.layers['CMS Booth Interior Dims'].visible = false
  m.commit_operation
rescue Exception
  m.abort_operation
  raise
end
# REPORT-ONLY room check (world): Wall C X 0, Wall A X W, Wall D Y L; room fittings that project
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/cms/room.rb'
l, w, = WR_CMS.dims
out['to_walls'] = { 'C (X 0)' => r[0].round(2), 'A (X W)' => (w - r[2]).round(2), 'D (Y L)' => (l - r[3]).round(2) }
out['hoods_inside'] = { 'hood_bounds' => [hood.min.to_a, hood.max.to_a].map { |p| p.map { |x| x.to_f.round(2) } },
                        'inside' => hood.min.x >= r[0] && hood.max.y <= r[3] }
room = m.entities.find { |e| e.respond_to?(:name) && e.name == 'CMS Classroom' }
hits = []
wk = lambda do |ents, tr, path, depth|
  ents.each do |e|
    next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    bb = Geom::BoundingBox.new
    8.times { |k| bb.add(e.bounds.corner(k).transform(tr)) }
    nm = e.name.to_s.empty? ? (e.definition.name rescue '?') : e.name
    inside_band = bb.max.x > r[0] && bb.min.x < r[2] && bb.max.y > r[1] && bb.min.y < r[3] && bb.min.z < 40
    if inside_band && depth >= 1 && nm !~ /\AWall \d (lower|stripe|upper)\z|Walls|Floor/
      hits << ["#{path}/#{nm}", [bb.min.x, bb.min.y].map { |x| x.to_f.round(1) }, [bb.max.x, bb.max.y].map { |x| x.to_f.round(1) }] if depth <= 3
    end
    wk.call(e.definition.entities, tr * e.transformation, "#{path}/#{nm}", depth + 1) if depth < 3 && nm =~ /Walls|fittings|CMS Classroom/
  end
end
wk.call(room.definition.entities, room.transformation, 'room', 1)
out['room_items_crossing_band'] = hits
out
