# Walsh corner: step 0. Save the open model as the NEW Corner Platform file. Never overwrites the original.
m = Sketchup.active_model
ORIG = 'Walsh Construction Tech Lab MDL 96168 E.skp'
NEW  = 'Z:/Sketchup/ClientDrawings/Walsh Construction Tech Lab MDL 96168 E - Corner Platform.skp'
cur = m.path.to_s.gsub(92.chr, '/')
raise "open model is #{cur.inspect}, expected the Walsh 96168 E file" unless File.basename(cur) == ORIG || File.basename(cur) == File.basename(NEW)
if File.basename(cur) == File.basename(NEW)
  puts "already on the new file: #{cur}"
else
  raise "#{NEW} already exists; refusing to overwrite" if File.exist?(NEW)
  ok = m.save(NEW)
  raise 'save-as failed' unless ok
end
puts "path now #{m.path} exists=#{File.exist?(NEW)}"
