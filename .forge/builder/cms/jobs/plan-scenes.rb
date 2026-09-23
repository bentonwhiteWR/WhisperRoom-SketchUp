# Benton, 22 Sep: the TOP-DOWN scenes show every host-room dimension plus the "not provided / estimated"
# note; every other scene keeps "CMS Room Dims (EST)" hidden. Redraws the room dims (new note text and
# label positions, dims.rb), stores the tag state IN each scene, and reframes the plan cameras so all
# dimension rows are in frame (the AUTO-SET plan camera framed the booth only; an AUTO-SET "update"
# with reaim would undo this framing -- rerun this job after one).
$wr_no_autorun = true
D = 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/cms/'
load D + 'room.rb'
load D + 'dims.rb'
m = Sketchup.active_model
out = {}
out['room_dims'] = WR_CMS.room_dims!
dl = m.layers[WR_CMS::DTAG]
plan = ->(pg) { pg.name == '05-plan' || pg.name =~ / 06-plan( r)?\z/ }
photo = WR_CMS::SCENES.values
bb = Geom::BoundingBox.new
m.entities.each { |e| bb.add(e.bounds) if e.valid? && e.get_attribute(WR_CMS::DDICT, 'own', false) && !e.is_a?(Sketchup::Text) }
m.entities.grep(Sketchup::Text).each { |t| bb.add(t.point) if t.get_attribute(WR_CMS::DDICT, 'own', false) }
# screen-text strings overhang the outermost dimension lines (~40 in at Benton's window): pad the frame
bb.add(bb.min.offset([-45, -24, 0])); bb.add(bb.max.offset([45, 24, 0]))
c = bb.center
aspect = 4.0 / 3.0
ht = [bb.height.to_f, bb.width.to_f / aspect].max * 1.06
out['frame'] = { 'min' => bb.min.to_a.map { |v| v.to_f.round }, 'max' => bb.max.to_a.map { |v| v.to_f.round }, 'height' => ht.round }
m.options['PageOptions']['TransitionTime'] = 0.0
before = m.pages.selected_page
done = []
m.pages.each do |pg|
  next if photo.include?(pg.name)
  next unless pg.use_hidden_layers?
  if plan.call(pg)
    m.pages.selected_page = pg
    cam = Sketchup::Camera.new([c.x, c.y, 1500], [c.x, c.y, 0], [0, 1, 0])
    cam.perspective = false
    cam.height = ht
    m.active_view.camera = cam
    dl.visible = true
    mine = m.entities.select { |e| e.valid? && e.get_attribute(WR_CMS::DDICT, 'own', false) }
    mine.each { |e| e.hidden = false if e.hidden? }
    pg.update(PAGE_USE_CAMERA | PAGE_USE_HIDDEN_OBJECTS | PAGE_USE_LAYER_VISIBILITY) rescue pg.update
    pg.set_visibility(dl, true)
    done << [pg.name, 'SHOWN', pg.layers.include?(dl) ? 'stored hidden?!' : 'stored visible', pg.camera.perspective?]
  else
    pg.set_visibility(dl, false)
    done << [pg.name, 'hidden', pg.layers.include?(dl)]
  end
end
dl.visible = false
m.pages.selected_page = before if before
out['pages'] = done
out['check'] = WR_CMS.check!
out
