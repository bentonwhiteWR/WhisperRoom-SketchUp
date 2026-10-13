# Save the Walsh model in place (run with --write-root Z:/Sketchup/ClientDrawings). Guarded by path.
m = Sketchup.active_model
raise "wrong model: #{m.path.inspect}" unless m.path.to_s =~ /Walsh Construction Tech Lab MDL 96168 E\.skp\z/
before = m.modified?
ok = m.save(m.path)
"saved=#{ok} was_modified=#{before} now_modified=#{m.modified?} path=#{m.path}"
