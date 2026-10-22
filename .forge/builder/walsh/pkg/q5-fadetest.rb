m = Sketchup.active_model
SCR = 'C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-Documents-Claude-Sketchup/35e4c934-e1df-44e1-b92c-2f0ecd7fe560/scratchpad'
room = m.entities.find { |e| e.persistent_id == 3442119 } or raise 'no room'
start = m.pages.selected_page
prev = m.options['PageOptions']['ShowTransition']
m.options['PageOptions']['ShowTransition'] = false
out = []
begin
  m.pages.selected_page = m.pages['Booth - MDL 96168 S RM (21 Oct link) 03-high']
  m.active_path = [room]
  out << m.active_path.map(&:persistent_id)
  out << m.active_view.write_image(:filename => "#{SCR}/r3-roomopen.png", :width => 1920, :height => 1080, :antialias => true, :transparent => false)
ensure
  m.active_path = nil
  m.pages.selected_page = start
  m.options['PageOptions']['ShowTransition'] = prev
end
out << (m.active_path || []).size
out
