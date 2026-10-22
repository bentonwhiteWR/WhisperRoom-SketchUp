# Read-only previews of every scene (SketchUp shaded, 1280x720) to scratch prev2/.
m = Sketchup.active_model
dir = 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-Documents-Claude-Sketchup/35e4c934-e1df-44e1-b92c-2f0ecd7fe560/scratchpad/prev2'
Dir.mkdir(dir) unless File.directory?(dir)
start = m.pages.selected_page
prev = m.options['PageOptions']['ShowTransition']
m.options['PageOptions']['ShowTransition'] = false
v = m.active_view
puts "view #{v.vpwidth}x#{v.vpheight}"
begin
  m.pages.each_with_index do |p, i|
    m.pages.selected_page = p
    f = "#{dir}/#{i}-#{p.name.split(' ').last(2).join('_')}.png"
    v.write_image(:filename => f, :width => 1280, :height => 720, :antialias => true)
    puts f
  end
ensure
  m.pages.selected_page = start if start
  m.options['PageOptions']['ShowTransition'] = prev
end
true
