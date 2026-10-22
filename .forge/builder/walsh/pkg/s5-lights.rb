# Walsh v3 package 2, step 5: V-Ray room lights for the closed-room renders.
# Showing the ceiling closes the room to the V-Ray sun/sky, so the room needs its own light.
# Same rig the 12 Oct Walsh pass used (walsh/lights.rb): 2x4 rect lights (half sizes 12 x 24),
# invisible, no reflections, 4,000 lm product figure x 320 (wr-drop-lights house calibration at
# the factory EV 14.23 camera), 5000 K, 1/2" under the 8'-0" assumed ceiling. CREATE ONLY.
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/walsh/rm/geom.rb'
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-drop-lights.rb' unless defined?(WR_DropLights)
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
raise "edit context open" if m.active_path && !m.active_path.empty?
DICT = 'wr_walsh_rm_lights'
have = m.entities.select { |e| e.respond_to?(:definition) && e.get_attribute(DICT, 'plugin') }
raise "#{have.size} RM room lights already placed - not placing twice" unless have.empty?
WalshRM.save(m)
# Interior polygon, read off the RM dims' endpoints (observed): SW, SE door corner, E, N, W.
poly = [[0, -21.88], [310, -21.88], [401.57, 90], [104.41, 332.71], [0, 205.12]].map { |x, y| Geom::Point3d.new(x, y, 0) }
segdist = lambda do |p, a, b|
  ab = b - a; t = ((p - a) % ab) / (ab % ab); t = [[t, 0].max, 1].min
  p.distance(a.offset(ab, ab.length * t))
end
booth = m.entities.find { |e| e.respond_to?(:name) && e.name.start_with?('Booth - MDL 96168 S RM') }
raise 'no booth' unless booth
bb = booth.bounds
puts "booth top z=#{bb.max.z.round(1)}"
pts = []
(0..6).each do |i|
  (0..6).each do |j|
    p = Geom::Point3d.new(40 + i * 84, 20 + j * 84, 0)
    next unless Geom.point_in_polygon_2D(p, poly, false)
    d = poly.each_index.map { |k| segdist.call(p, poly[k], poly[(k + 1) % poly.size]) }.min
    pts << p if d >= 30
  end
end
puts "grid points #{pts.size}: #{pts.map { |p| [p.x.round, p.y.round] }.inspect}"
ctx = VRay::Context.active or raise 'V-Ray context nil'
tag = m.layers['WR Lights'] || m.layers.add('WR Lights')
GAIN = 320.0; LM = 4000.0; K = 5000; Z = 95.5
rows = []
m.start_operation('Walsh RM: room ceiling lights', true)
pts.each_with_index do |p, n|
  d, plug = WR_DropLights.create_light(ctx, 12.0, 24.0)
  rgb = WR_DropLights.kelvin_rgb(K)
  wants = [[:invisible, true], [:affectReflections, false], [:units, WR_DropLights::UNITS_LUMENS],
           [:intensity, LM * GAIN], [:color, VRay::Color.new(*rgb)]]
  errs = WR_DropLights.write_params(ctx.scene, plug, wants)
  bad = wants.reject { |k, v| WR_DropLights.read_param(plug, k, v, errs[k])[0] }.map(&:first)
  i = m.entities.add_instance(d, Geom::Transformation.translation([p.x, p.y, Z]))
  i.layer = tag
  i.name = "Tech Lab RM ceiling light #{n + 1}"
  pn = WR_DropLights.plugin_name(plug)
  { 'plugin' => pn, 'lm_product' => LM.round, 'written' => (LM * GAIN).round, 'kelvin' => K }.each { |k, v| i.set_attribute(DICT, k, v) }
  rows << [i.name, p.x.round, p.y.round, pn, bad, i.bounds.min.z.round(1), i.bounds.max.z.round(1)]
end
m.commit_operation
rows.each { |r| puts r.inspect }
WalshRM.save(m)
rows.size
