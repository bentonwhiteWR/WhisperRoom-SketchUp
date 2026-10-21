# Walsh corner: step 7. Re-aim 'Platform 06 TopDown' and 'Platform 01 HeroRender' on the corner layout, keep
# the old/ramp tags hidden and the new tags shown in those two, export both as SketchUp PNGs to the NEW
# proposals folder. (V-Ray hero is a separate, optional step.) Lists the scenes now stale.
# Run with --write-root "Z:/Sketchup".
load File.join(File.dirname(__FILE__), 'geom.rb')
wc = WalshCorner
m = Sketchup.active_model
o = m.get_attribute('WalshCorner', 'origin') or raise 'run s2-retag.rb first'
OUT = 'Z:/Sketchup/Proposals/Walsh Construction Tech Lab MDL 96168 E - Corner Platform'
Dir.mkdir(OUT) unless File.directory?(OUT)
v = m.active_view
hide = ['Walsh Old Room 12 Oct', 'Walsh Old Dims 12 Oct', m.get_attribute('WalshCorner', 'ramp_tag').to_s].reject(&:empty?)
show = %w[WR-Room WR-Room-New WR-Floor WR-Doors WR-Doors-Leaf WR-Dims WR-Dims-Doors WR-Dims-Booth WR-Notes]
room = m.entities.grep(Sketchup::Group).find { |g| g.name == 'Tech Lab 13 - Corner 21 Oct' } or raise 'run s3-room.rb first'
dims = m.entities.grep(Sketchup::Group).find { |g| g.name == 'Corner Dims 21 Oct' }
W = ->(xy, zz = 0.0) { Geom::Point3d.new(o[0] + xy[0], o[1] + xy[1], o[2] + zz) }
setvis = lambda do |pg, top|
  hide.each { |n| (l = m.layers[n]) && (l.visible = false) }
  show.each { |n| (l = m.layers[n]) && (l.visible = true) }
  if (l = m.layers['WR-Ceiling'])
    l.visible = false                        # both views look in from above / past the missing ceiling
  end
  unless top
    %w[WR-Dims WR-Dims-Doors WR-Dims-Booth WR-Notes].each { |n| (l = m.layers[n]) && (l.visible = false) }
  end
  m.pages.selected_page = pg
end
shots = []
# ---- 06 TopDown
pg = m.pages['Platform 06 TopDown'] or raise 'no Platform 06 TopDown'
setvis.(pg, true)
bb = Geom::BoundingBox.new
bb.add(room.bounds)
bb.add(dims.bounds) if dims
ctr = bb.center
cam = Sketchup::Camera.new(Geom::Point3d.new(ctr.x, ctr.y, ctr.z + 3000), ctr, Y_AXIS)
cam.perspective = false
v.camera = cam
v.zoom(bb)
v.zoom(0.92)

pg.use_hidden_layers = true if pg.respond_to?(:use_hidden_layers=)
pg.update(1 | 32)
f1 = File.join(OUT, '6_Platform 06 TopDown.png')
v.write_image(filename: f1, width: 1920, height: 1080, antialias: true, transparent: false)
shots << f1
# ---- 01 HeroRender: eye in the Tech Lab near door 24 looking at the booth's open end
pg = m.pages['Platform 01 HeroRender'] or raise 'no Platform 01 HeroRender'
setvis.(pg, false)
tgt = wc.p(96.0, 70.0)
eye = [36.0, 40.0]
cam = Sketchup::Camera.new(W.(eye, 64.0), W.(tgt, 40.0), Z_AXIS)
cam.perspective = true
cam.fov = 60.0
v.camera = cam
pg.update(1 | 32)
f2 = File.join(OUT, '1_Platform 01 HeroRender (SketchUp, not V-Ray).png')
v.write_image(filename: f2, width: 1920, height: 1080, antialias: true, transparent: false)
shots << f2
m.save
shots.each { |f| puts "wrote #{f} #{File.exist?(f) ? File.size(f) : 'MISSING'}" }
stale = m.pages.map(&:name).reject { |n| ['Platform 06 TopDown', 'Platform 01 HeroRender'].include?(n) || n.start_with?('Ramp') }
puts "stale Platform scenes (still aimed at the 12 Oct layout): #{stale.join(', ')}"
puts "saved #{m.path}"
