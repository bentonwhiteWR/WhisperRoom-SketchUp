# The legacy five plates (WR_ProposalScenes) frame the booth from OUTSIDE the room and do not hide
# walls, so as made they show wall exteriors only. Per plate: hide every room wall whose plane the
# camera stands behind (with its fittings; Wall 2's pilaster goes with Wall 2), and the ceiling +
# ceiling fixtures when the camera is above it. Stored in the page's hidden objects, as AUTO-SET does.
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/cms/room.rb'
m = Sketchup.active_model
l, w, h, = WR_CMS.dims
room = m.entities.find { |e| e.respond_to?(:name) && e.name == 'CMS Classroom' }
walls = room.definition.entities.find { |g| g.is_a?(Sketchup::Group) && g.name == 'Walls' }
fix = room.definition.entities.find { |g| g.is_a?(Sketchup::Group) && g.name == 'Ceiling fixtures' }
pieces = walls.definition.entities.grep(Sketchup::Group)
m.options['PageOptions']['TransitionTime'] = 0.0
out = []
before = m.pages.selected_page
%w[01-exterior 02-dimensioned 03-side 04-ventilation 05-plan].each do |nm|
  pg = m.pages[nm]
  next unless pg
  m.pages.selected_page = pg
  e = pg.camera.eye
  hide = []
  hide << 1 if e.y > l
  hide << 2 if e.x > w
  hide << 3 if e.y < 0
  hide << 4 if e.x < 0
  up = e.z > h
  pieces.each do |g|
    n = g.name[/\AWall (\d)/, 1].to_i
    want = (n > 0 && hide.include?(n)) || (g.name == 'Ceiling' && up)
    g.hidden = want
  end
  fix.hidden = up
  pg.use_hidden_objects = true if pg.respond_to?(:use_hidden_objects=)
  pg.update(PAGE_USE_HIDDEN_OBJECTS) rescue pg.update(16)
  out << [nm, hide, up, pg.hidden_entities.map { |x| x.respond_to?(:name) ? x.name : x.class.to_s }.uniq]
end
m.pages.selected_page = before if before
out
