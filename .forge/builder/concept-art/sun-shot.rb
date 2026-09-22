load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/concept-art/render.rb'
c = WR_ConceptRender.room_pieces.find { |g| g.name == 'Ceiling' }
c.hidden = true
v = Sketchup.active_model.active_view
v.camera = Sketchup::Camera.new(Geom::Point3d.new(105, -63, 400), Geom::Point3d.new(105, -63, 0), Y_AXIS)
v.camera.perspective = false
v.camera.height = 420
load File.join(WhisperRoom::Tools::SCRIPTS_DIR, 'wr-bridge-lib.rb')
r = WRB.shot($shot_path, 1000)
c.hidden = false
r
