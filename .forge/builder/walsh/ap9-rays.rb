# ap9: ray survey of the four interior wall faces. Hides ONLY foam + Audimute (restored in ensure).
require 'json'
m = Sketchup.active_model
raise "wrong model #{m.path}" unless m.path =~ /Walsh Construction Tech Lab MDL 96168 E\.skp\z/
b = m.entities.grep(Sketchup::Group).find { |g| g.name == 'Booth - MDL 96168 E' }
t = b.transformation; ti = t.inverse
hid = b.entities.select { |e| e.respond_to?(:definition) && e.definition.name =~ /\AAudimute|\AFoam/ && !e.hidden? }
# wall: [run axis, run range, start normal coord, dir]
W = {
  'S' => { run: :x, r: [3.0, 167.0], c: 30.0, d: [0, -1, 0] },
  'N' => { run: :x, r: [3.0, 167.0], c: 70.0, d: [0, 1, 0] },
  'W' => { run: :y, r: [3.0, 95.0], c: 30.0, d: [-1, 0, 0] },
  'E' => { run: :y, r: [3.0, 95.0], c: 140.0, d: [1, 0, 0] }
}
out = { 'step_run' => 0.5, 'step_z' => 0.5, 'walls' => {} }
begin
  hid.each { |e| e.hidden = true }
  W.each do |w, s|
    rows = []
    z = 1.0
    while z <= 81.0
      row = []
      a = s[:r][0]
      while a <= s[:r][1]
        p = s[:run] == :x ? Geom::Point3d.new(a, s[:c], z) : Geom::Point3d.new(s[:c], a, z)
        h = m.raytest([p.transform(t), Geom::Vector3d.new(*s[:d]).transform(t)], true)
        if h
          lp = h[0].transform(ti)
          nc = s[:run] == :x ? lp.y : lp.x
          path = h[1].map { |e| e.respond_to?(:definition) ? e.definition.name : e.typename }
          nm = path[1] || path[0]
          row << [nc.to_f.round(3), nm]
        else
          row << [nil, 'NONE']
        end
        a += 0.5
      end
      rows << row
      z += 0.5
    end
    out['walls'][w] = { 'run' => s[:run].to_s, 'r0' => s[:r][0], 'z0' => 1.0, 'rows' => rows }
  end
ensure
  hid.each { |e| e.hidden = false if e.valid? }
end
File.write('C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-Documents-Claude-Sketchup/4197d3da-5c83-4677-a84d-a22ae4e12e24/scratchpad/ap9/rays.json', JSON.generate(out))
[hid.length, out['walls'].map { |k, v| [k, v['rows'].length, v['rows'][0].length] }]
