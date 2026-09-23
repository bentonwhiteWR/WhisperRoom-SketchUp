# Benton, 22 Sep: hide the corridor block (exterior-only geometry beyond Wall C) in "03-high r" and its
# image pair ONLY, stored in each scene's own hidden set. Light objects are not touched.
m = Sketchup.active_model
v = m.active_view
ps = m.pages
m.options['PageOptions']['TransitionTime'] = 0.0
room = m.entities.find { |e| e.respond_to?(:name) && e.name == 'CMS Classroom' }
w = room.definition.entities.find { |g| g.respond_to?(:name) && g.name == 'Walls' }
f4 = w.definition.entities.find { |g| g.respond_to?(:name) && g.name == 'Wall 4 fittings' }
corr = f4.definition.entities.find { |e| e.respond_to?(:definition) && e.name == 'corridor' }
sel = ps.selected_page
out = []
m.start_operation('CMS: hide corridor in 03-high', true)
begin
  ['MDL 96144 E (components) 03-high r', 'MDL 96144 E (components) 03-high'].each do |n|
    pg = ps[n]
    ps.selected_page = pg          # applies this page's own hidden set
    v.refresh
    corr.hidden = true
    pg.update(PAGE_USE_HIDDEN_OBJECTS)
    out << [n, (pg.hidden_entities || []).include?(corr), (pg.hidden_entities || []).size]
  end
  corr.hidden = false
  m.commit_operation
rescue Exception
  m.abort_operation
  raise
end
ps.selected_page = sel if sel
out << ['others hiding corridor', ps.reject { |p| p.name =~ /03-high/ }.select { |p| ((p.hidden_entities rescue nil) || []).include?(corr) }.map(&:name)]
out
