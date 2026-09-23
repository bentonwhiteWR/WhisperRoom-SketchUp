# Photo-match shots with the BOOTH and the V-Ray light gizmos hidden (photo A's camera now stands
# inside the booth). Both are restored in an ensure. Reads PREFIX from $cms_prefix.
m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:name) && e.name == 'MDL 96144 E (components)' }
lt = m.layers['WR Lights']
lights = m.entities.select { |e| e.get_attribute('wr_cms_lights', 'plugin') }
bh = b.hidden?
lv = lt.visible?
# Room pieces are hidden per SCENE (AUTO-SET / legacy plates store their hidden walls); whichever
# scene was selected last leaves its walls hidden globally, and the photo scenes store no hidden
# state. So every room piece is shown first -- the neutral state, which every scene re-applies over.
room = m.entities.find { |e| e.respond_to?(:name) && e.name == 'CMS Classroom' }
room.definition.entities.grep(Sketchup::Group).each do |g|
  g.hidden = false
  g.entities.grep(Sketchup::Group).each { |c| c.hidden = false } if g.name == 'Walls'
end
begin
  b.hidden = true
  lights.each { |e| e.hidden = true }   # their widgets; the tag itself is left alone
  load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/cms/jobs/shots.rb'
ensure
  b.hidden = bh
  lights.each { |e| e.hidden = false }
  lt.visible = lv
end
[b.hidden?, lt.visible?, lights.count(&:hidden?)]
