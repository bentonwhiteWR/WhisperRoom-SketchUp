# Walsh v3 package 2, step 7: 02-front r camera pulled off the south wall; 1' door dim text outside.
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/walsh/rm/geom.rb'
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
raise "edit context open" if m.active_path && !m.active_path.empty?
pre = 'Booth - MDL 96168 S RM (21 Oct link) '
p = m.pages[pre + '02-front r'] or raise 'no 02-front r'
prev = m.options['PageOptions']['ShowTransition']
m.options['PageOptions']['ShowTransition'] = false
start = m.pages.selected_page
begin
  m.pages.selected_page = p
  m.active_view.camera = Sketchup::Camera.new([22, -2, 60], [218, 18, 44], Z_AXIS, true, 45)
  m.active_view.refresh
  p.update(PAGE_USE_CAMERA)
ensure
  m.pages.selected_page = start if start
  m.options['PageOptions']['ShowTransition'] = prev
end
g = m.entities.grep(Sketchup::Group).find { |x| x.persistent_id == 3442717 }
d = g.entities.find { |e| e.persistent_id == 3442731 }
was = d.text
m.start_operation('Walsh: 1\' door dim text outside', true)
d.text_position = Sketchup::DimensionLinear::TEXT_OUTSIDE_END
m.commit_operation
raise 'value moved' unless d.text == was
WalshRM.save(m)
puts "02-front r eye=#{p.camera.eye.to_a.map(&:round)} fov=#{p.camera.fov.round}; 1' dim text=#{d.text}"
true
