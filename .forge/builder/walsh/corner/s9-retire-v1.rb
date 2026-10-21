# Walsh corner: step 9 (21 Oct, section reorder). Retire the first corner build (room + dims) to a hidden tag,
# renamed "(v1 21 Oct)", so s3/s6 can rebuild for the moved door. Hidden, never deleted.
load File.join(File.dirname(__FILE__), 'geom.rb')
m = Sketchup.active_model
TAG = 'Walsh Corner v1 21 Oct'
names = ['Tech Lab 13 - Corner 21 Oct', 'Corner Dims 21 Oct']
gs = m.entities.grep(Sketchup::Group).select { |g| names.include?(g.name) }
raise "expected 2 groups, found #{gs.map(&:name).inspect}" unless gs.size == 2
m.start_operation('Walsh corner: retire v1', true)
l = m.layers[TAG] || m.layers.add(TAG)
gs.each { |g| g.name = "#{g.name} (v1 21 Oct)"; g.layer = l }
l.visible = false
m.pages.each { |pg| pg.set_visibility(l, false) if pg.respond_to?(:set_visibility) }
m.commit_operation
WalshCorner.save(m)
puts "retired #{gs.map(&:name).inspect} to hidden tag #{TAG}; saved #{m.path}"
