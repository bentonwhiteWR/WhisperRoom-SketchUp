# Walsh v3 package step 1: back up, delete every old scene, erase the hidden wrong booth + its tag, save.
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/walsh/rm/geom.rb'
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb' unless defined?(WR_ProposalPackage)
require 'json'
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
raise "edit context open: #{m.active_path.inspect}" if m.active_path && !m.active_path.empty?
WalshRM.save(m)
bdir = 'Z:/Sketchup/ClientDrawings/Backups'
Dir.mkdir(bdir) unless File.directory?(bdir)
stamp = Time.now.strftime('%Y%m%d-%H%M')
copy = "#{bdir}/Walsh Construction Tech Lab MDL 96168 S - Corner RM - pre-package #{stamp}.skp"
m.save_copy(copy)
puts "backup copy #{copy} (#{File.size(copy)} bytes)"
rec = m.pages.map do |p|
  c = p.camera
  { 'name' => p.name, 'mode' => WR_ProposalPackage.mode_of(p), 'token' => p.get_attribute('WR_AutoSet', 'token'),
    'plate' => p.get_attribute('WR_AutoSet', 'plate'),
    'eye' => c.eye.to_a, 'target' => c.target.to_a, 'up' => c.up.to_a, 'persp' => c.perspective?,
    'fov' => (c.perspective? ? c.fov : nil), 'height' => (c.perspective? ? nil : c.height),
    'hidden_tags' => p.layers.map(&:name) }
end
jf = "#{bdir}/Walsh RM scenes pre-package #{stamp}.json"
File.write(jf, JSON.pretty_generate(rec))
puts "scene record #{jf} (#{rec.size} scenes)"

booth = m.entities.grep(Sketchup::Group).find { |g| g.persistent_id == 3442662 }
raise 'v3 booth missing' unless booth
ok, msg, lines = WR_AutoSet.remove(m, booth, {})
puts "REMOVE ok=#{ok} #{msg}"; (lines || []).each { |l| puts "  #{l}" }
old = m.pages.to_a.dup
m.start_operation('Walsh: delete old-model scenes', true)
old.each { |p| puts "  erased   #{p.name}"; m.pages.erase(p) }
m.commit_operation
puts "scenes left: #{m.pages.size}"

wrong = m.entities.grep(Sketchup::Group).find { |g| g.persistent_id == 3442605 }
tag = m.layers['Walsh RM swapped N 21 Oct']
if wrong
  raise "pid 3442605 is not the swapped booth: #{wrong.name}" unless wrong.name.include?('WRONG N order')
  m.start_operation('Walsh: erase swapped booth', true)
  wrong.erase!
  m.commit_operation
  puts 'erased wrong booth pid 3442605'
end
if tag
  users = 0
  m.definitions.each { |d| d.entities.each { |e| users += 1 if e.respond_to?(:layer) && e.layer == tag } }
  m.entities.each { |e| users += 1 if e.respond_to?(:layer) && e.layer == tag }
  puts "tag users left: #{users}"
  m.layers.remove(tag, false)
  puts "tag removed: #{m.layers['Walsh RM swapped N 21 Oct'].nil?}"
end
WalshRM.save(m)
puts "saved #{m.path}"
true
