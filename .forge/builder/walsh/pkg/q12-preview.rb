m = Sketchup.active_model
dir = 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-Documents-Claude-Sketchup/35e4c934-e1df-44e1-b92c-2f0ecd7fe560/scratchpad/prev'
Dir.mkdir(dir) unless File.directory?(dir)
start = m.pages.selected_page
prev = m.options['PageOptions']['ShowTransition']
m.options['PageOptions']['ShowTransition'] = false
v = m.active_view
begin
  m.pages.each_with_index do |p, i|
    next if p.name.end_with?(' r')
    m.pages.selected_page = p
    f = "#{dir}/#{i}-#{p.name.split(' ').last}.png"
    v.write_image(:filename => f, :width => 1280, :height => 720, :antialias => true)
    puts f
  end
ensure
  m.pages.selected_page = start if start
  m.options['PageOptions']['ShowTransition'] = prev
end
true
