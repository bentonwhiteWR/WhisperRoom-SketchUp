# Walsh: scene prefixes Opt2 -> Ramp, Opt1 -> Platform (Benton, 12 Oct). Names only.
m = Sketchup.active_model
raise "wrong model: #{m.path}" unless m.path.end_with?("Walsh Construction Tech Lab MDL 96168 E.skp")
map = { 'Opt2 ' => 'Ramp ', 'Opt1 ' => 'Platform ' }
plan = m.pages.map { |p| k = map.keys.find { |x| p.name.start_with?(x) }; [p, k ? map[k] + p.name[k.size..-1] : nil] }
todo = plan.select { |_, n| n }
raise "expected 9 Opt scenes, found #{todo.size}" unless todo.size == 9
names = m.pages.map(&:name) - todo.map { |p, _| p.name } + todo.map { |_, n| n }
raise 'rename would create a duplicate scene name' unless names.uniq.size == names.size
m.save(m.path)
opened = false
begin
  m.start_operation('Walsh: rename scenes Ramp / Platform', true)
  opened = true
  todo.each { |p, n| p.name = n }
  m.commit_operation
  opened = false
rescue => ex
  m.abort_operation if opened
  raise
end
m.save(m.path)
[m.modified?, m.pages.map(&:name)].inspect
