# Walsh v3 step 0: Save As the RM file before any change. Source must be the Corner Platform file.
m = Sketchup.active_model
SRC = 'Walsh Construction Tech Lab MDL 96168 E - Corner Platform.skp'
NEW = 'Z:/Sketchup/ClientDrawings/Walsh Construction Tech Lab MDL 96168 S - Corner RM.skp'
cur = m.path.to_s.gsub(92.chr, '/')
if File.basename(cur) == File.basename(NEW)
  puts "already on the RM file: #{cur}"
else
  raise "open model is #{cur.inspect}, expected #{SRC}" unless File.basename(cur) == SRC
  raise "#{NEW} already exists; refusing to overwrite" if File.exist?(NEW)
  puts "note: modified=#{m.modified?} before save-as; any unsaved changes go to the RM file only"
  m.save(NEW) or raise 'save-as failed'
end
puts "path now #{m.path} exists=#{File.exist?(NEW)} size=#{File.size(NEW)}"
