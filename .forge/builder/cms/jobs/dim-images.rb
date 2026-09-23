# Step 8c: the booth dimension images = the AUTO-SET IMAGE plates (booth dims shown, room EST dims
# hidden by each page's tag state), as SketchUp viewport exports -- NOT V-Ray. The WR Lights tag
# (V-Ray light gizmos) is hidden for the export and restored. Never overwrites: an existing file
# gets a -2, -3 ... suffix. $cms_dim_dir = output folder, $cms_dim_w = width.
m = Sketchup.active_model
v = m.active_view
dir = $cms_dim_dir
Dir.mkdir(dir) unless File.directory?(dir)
w = ($cms_dim_w || 2400).to_i
m.options['PageOptions']['TransitionTime'] = 0.0
lt = m.layers['WR Lights']
res = []
m.pages.each do |pg|
  next unless pg.name =~ /\AMDL 96144 E \(components\) (\d\d-[a-z]+)\z/
  short = Regexp.last_match(1)
  m.pages.selected_page = pg
  v.camera = pg.camera
  was = lt.visible?
  lt.visible = false
  base = File.join(dir, "CMS-MDL-96144-E-#{short}-dims")
  f = "#{base}.png"
  k = 2
  while File.exist?(f)
    f = "#{base}-#{k}.png"
    k += 1
  end
  h = (w / v.camera.aspect_ratio.to_f rescue nil)
  h = (w * v.vpheight.to_f / v.vpwidth).round if h.nil? || !h.finite? || h <= 0
  begin
    ok = v.write_image(filename: f, width: w, height: h.round, antialias: true, transparent: false)
  ensure
    lt.visible = was   # a hidden WR Lights tag renders UNLIT; restore even when the write raises
  end
  res << [short, ok, File.basename(f), m.layers['WR-Dims-Booth'].visible?, m.layers['CMS Room Dims (EST)'].visible?]
end
res
