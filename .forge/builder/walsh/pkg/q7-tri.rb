m = Sketchup.active_model
scr = 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-Documents-Claude-Sketchup/35e4c934-e1df-44e1-b92c-2f0ecd7fe560/scratchpad'
start = m.pages.selected_page
prev = m.options['PageOptions']['ShowTransition']
m.options['PageOptions']['ShowTransition'] = false
v = m.active_view
begin
  m.pages.selected_page = m.pages['Booth - MDL 96168 S RM (21 Oct link) 01-angled']
  v.camera = Sketchup::Camera.new([10, 60, 62], [262, 70, 44], Z_AXIS, true, 55)
  v.write_image(:filename => "#{scr}/tri-hero.png", :width => 1920, :height => 1080, :antialias => true)
  # what does a ray through the triangle's pixel hit?  old hero pixel ~ (1325, 705) of 1920x1080
  sx = 1325.0 / 1920 * v.vpwidth; sy = 705.0 / 1080 * v.vpheight
  ray = v.pickray(sx, sy)
  hit = m.raytest(ray, false)
  if hit
    puts "hit at #{hit[0].to_a.map { |c| c.round(1) }}"
    hit[1].each { |e| puts "  #{e.typename} #{(e.name rescue '')} tag=#{e.layer.name} pid=#{e.persistent_id} #{e.respond_to?(:definition) ? e.definition.name : ''} #{e.is_a?(Sketchup::Face) ? (e.material ? e.material.display_name : 'nomat') : ''}" }
  end
ensure
  m.pages.selected_page = start
  m.options['PageOptions']['ShowTransition'] = prev
end
true
