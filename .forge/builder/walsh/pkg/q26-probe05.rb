# Read-only: 05 preview with all WR-Dims* tags off, to tell dim lines from geometry. Reselect page restores.
m = Sketchup.active_model
dir = 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-Documents-Claude-Sketchup/35e4c934-e1df-44e1-b92c-2f0ecd7fe560/scratchpad/prev2'
prevT = m.options['PageOptions']['ShowTransition']; m.options['PageOptions']['ShowTransition'] = false
st = m.pages.selected_page
p = m.pages.find { |x| x.name.end_with?('05-ventilation') }
m.pages.selected_page = p
m.layers.each { |l| l.visible = false if l.name =~ /\AWR-Dims/ }
m.active_view.write_image(:filename => "#{dir}/probe05-nodims.png", :width => 1280, :height => 720, :antialias => true)
m.pages.selected_page = st
m.pages.selected_page = p
puts m.layers.select { |l| l.name =~ /\AWR-Dims/ }.map { |l| "#{l.name}=#{l.visible?}" }.join(' ')
m.pages.selected_page = st; m.options['PageOptions']['ShowTransition'] = prevT
true
