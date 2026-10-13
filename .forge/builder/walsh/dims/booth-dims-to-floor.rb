# Walsh: drop the 13 booth placement dimensions (WR-Dims-Booth, z 90) to the floor (z 0).
# Only free (unattached) linear dims on WR-Dims-Booth at model top level are touched.
m = Sketchup.active_model
raise "wrong model: #{m.path}" unless m.path.end_with?("Walsh Construction Tech Lab MDL 96168 E.skp")
dims = m.entities.grep(Sketchup::DimensionLinear).select { |d| d.layer.name == 'WR-Dims-Booth' }
raise "expected 13 booth dims, found #{dims.size}" unless dims.size == 13
raise "a booth dim is attached to geometry; not touching it" if dims.any? { |d| d.start[0] || d.end[0] }
before = dims.map { |d| [d.text, d.start[1].z.to_f, d.end[1].z.to_f, d.offset_vector.to_a] }
m.save(m.path)
opened = false
begin
  m.start_operation('Walsh: booth dimensions to the floor', true)
  opened = true
  dims.each do |d|
    s = d.start[1]; e = d.end[1]
    d.start = Geom::Point3d.new(s.x, s.y, 0)
    d.end   = Geom::Point3d.new(e.x, e.y, 0)
  end
  bad = dims.reject { |d| d.start[1].z.to_f.abs < 0.001 && d.end[1].z.to_f.abs < 0.001 }
  raise "#{bad.size} dims did not land at z 0" unless bad.empty?
  changed = dims.zip(before).reject { |d, b| d.text == b[0] && d.offset_vector.to_a == b[3] }
  raise "text or offset changed on #{changed.size} dims" unless changed.empty?
  m.commit_operation
  opened = false
rescue => ex
  m.abort_operation if opened
  raise
end
m.save(m.path)
[m.modified?, dims.map { |d| [d.text, d.start[1].z.to_f, d.end[1].z.to_f] }].inspect
