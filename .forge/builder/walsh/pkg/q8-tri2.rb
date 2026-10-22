m = Sketchup.active_model
start = m.pages.selected_page
prev = m.options['PageOptions']['ShowTransition']
m.options['PageOptions']['ShowTransition'] = false
v = m.active_view
begin
  m.pages.selected_page = m.pages['Booth - MDL 96168 S RM (21 Oct link) 01-angled']
  v.camera = Sketchup::Camera.new([10, 60, 62], [262, 70, 44], Z_AXIS, true, 55)
  puts "vp #{v.vpwidth}x#{v.vpheight}"
  [[1325, 705], [1335, 712], [1340, 716], [1318, 700]].each do |px, py|
    # write_image 1920x1080 vs viewport aspect: map via vertical fov scale
    sx = v.vpwidth / 2.0 + (px - 960) * (v.vpheight / 1080.0)
    sy = v.vpheight / 2.0 + (py - 540) * (v.vpheight / 1080.0)
    hit = m.raytest(v.pickray(sx, sy), true)
    next puts("#{px},#{py}: miss") unless hit
    puts "#{px},#{py}: hit #{hit[0].to_a.map { |c| c.round(1) }}"
    hit[1].each { |e| puts "    #{e.typename} '#{(e.name rescue '')}' tag=#{e.layer.name} pid=#{e.persistent_id} #{e.respond_to?(:definition) ? e.definition.name : ''} #{e.is_a?(Sketchup::Face) ? (e.material ? e.material.display_name : 'nomat') + ' area=' + e.area.round(1).to_s : ''}" }
  end
ensure
  m.pages.selected_page = start
  m.options['PageOptions']['ShowTransition'] = prev
end
true
