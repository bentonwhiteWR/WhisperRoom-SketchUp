# Walsh v3 package step 3: hand fixes on top of AUTO-SET (each one named in the handoff).
#  - 01-angled + 01-angled r: AUTO-SET's eye (-117,-26) is outside the room; the host door leaf fills the frame.
#    Eye inside the room, west of the booth (same camera the v3 pass used and Benton saw).
#  - 05-ventilation: roof-mount booth, the vent units are on the roof; raise the eye so the roof reads.
#  - 06-plan: ortho framed on the booth crops the room; frame the whole room + dims.
#  - Door-opening threshold faces (2) were unpainted and read as a white triangle; paint them the floor material.
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/walsh/rm/geom.rb'
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb' unless defined?(WR_ProposalPackage)
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
raise "edit context open" if m.active_path && !m.active_path.empty?
pre = 'Booth - MDL 96168 S RM (21 Oct link) '
pg = ->(n) { m.pages[pre + n] or raise "no page #{n}" }
prev = m.options['PageOptions']['ShowTransition']
m.options['PageOptions']['ShowTransition'] = false
v = m.active_view
m.start_operation('Walsh package hand fixes', true)
begin
  ['01-angled', '01-angled r'].each do |n|
    m.pages.selected_page = pg.(n)
    v.camera = Sketchup::Camera.new([10, 60, 62], [262, 70, 44], Z_AXIS, true, 55)
    pg.(n).update(1)
  end
  p = pg.('05-ventilation')
  m.pages.selected_page = p
  c0 = p.camera
  v.camera = Sketchup::Camera.new([c0.eye.x, c0.eye.y, 200], c0.target, Z_AXIS, true, c0.fov)
  p.update(1)
  p = pg.('06-plan')
  m.pages.selected_page = p
  c = Sketchup::Camera.new([206, 150, 1500], [206, 150, 0], Y_AXIS, false)
  c.height = 470
  v.camera = c
  p.update(1)
  mat = m.materials['[0128_White]'] or raise 'no floor material'
  room = m.entities.find { |e| e.persistent_id == 3442119 }
  doors = room.definition.entities.find { |e| e.respond_to?(:name) && e.name == 'Doors' }
  n = 0
  doors.definition.entities.grep(Sketchup::Group).each do |d|
    next unless d.name.include?('Opening')
    d.definition.entities.grep(Sketchup::Face).each do |f|
      next unless f.bounds.max.z < 0.5 && f.normal.z > 0.9 && f.material.nil?
      f.material = mat; n += 1
    end
  end
  puts "painted #{n} threshold face(s) #{mat.name}"
  m.commit_operation
ensure
  m.options['PageOptions']['ShowTransition'] = prev
end
m.pages.selected_page = pg.('01-angled')
WalshRM.save(m)
m.pages.each { |q| c = q.camera; puts "  #{q.name.sub(pre, '')} | #{WR_ProposalPackage.mode_of(q)} | eye=#{c.eye.to_a.map(&:round)} #{c.perspective? ? "fov #{c.fov.round}" : "ortho h #{c.height.round}"}" }
true
