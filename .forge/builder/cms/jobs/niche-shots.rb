# Close viewport shots of both radiator niches: a low 3/4 view into each, plus a top-down of the Wall A
# strip with the ceiling/fixtures/booth hidden for the shot only (restored in an ensure). $cms_dir = out dir.
m = Sketchup.active_model
v = m.active_view
dir = $cms_dir
room = m.entities.find { |e| e.respond_to?(:name) && e.name == 'CMS Classroom' }
walls = room.definition.entities.find { |g| g.respond_to?(:name) && g.name == 'Walls' }
hide = walls.definition.entities.select { |g| g.respond_to?(:name) && g.name =~ /\ACeiling\z|\AWall 2 fittings\z/ } +
       room.definition.entities.select { |g| g.respond_to?(:name) && g.name == 'Ceiling fixtures' }
lights = m.entities.select { |e| e.get_attribute('wr_cms_lights', 'plugin') }
b = m.entities.find { |e| e.respond_to?(:name) && e.name == 'MDL 96144 E (components)' }
res = []
keep = v.camera
begin
  lights.each { |e| e.hidden = true }
  [[62.0, 'w2'], [207.0, 'w1']].each do |yc, k|
    c = Sketchup::Camera.new([140.0, yc - 40.0, 30.0], [184.0, yc, 4.0], Z_AXIS); c.fov = 55
    v.camera = c
    f = File.join(dir, "niche-#{k}-low.png")
    res << v.write_image(filename: f, width: 1400, height: 1050, antialias: true, transparent: false)
  end
  hide.each { |g| g.hidden = true }
  b.hidden = true
  c = Sketchup::Camera.new([175.0, 135.0, 600], [175.0, 135.0, 0], Y_AXIS)
  c.perspective = false
  c.height = 290
  v.camera = c
  res << v.write_image(filename: File.join(dir, 'niches-top.png'), width: 700, height: 1400, antialias: true, transparent: false)
ensure
  hide.each { |g| g.hidden = false }
  b.hidden = false
  lights.each { |e| e.hidden = false }
  v.camera = keep
end
res
