# STEP 2 of the Cosmos import: keep only the Cosmos definitions the set uses,
# remove the two source files' wrappers and every other definition and
# material they brought in. Creates NO V-Ray lights (the deferred purge of a
# removed light's plugin name can take a light created in the same job).
m = Sketchup.active_model
b = $wr_ca_before
raise 'no import-1 snapshot in this session' if b.nil?
KEEP = ['Chair Lounge 009', 'Sofa Sectional 001', 'Table Coffee 001', 'Indoor Plant 004',
        'Indoor Plant 007', 'Zody Executive 4D Arms Metal Base'].freeze
KEEP.each { |n| raise "kept definition #{n} missing" if m.definitions[n].nil? }
removed = 0
m.start_operation('WR concept: drop imported wrappers', true)
begin
  $wr_ca_wrappers.each do |w|
    d = m.definitions[w]
    next if d.nil?
    m.definitions.remove(d)
    removed += 1
  end
  loop do
    doomed = m.definitions.select do |d|
      !b['defs'].include?(d.name) && !KEEP.include?(d.name) && d.instances.empty? && !d.image?
    end
    break if doomed.empty?
    doomed.each { |d| m.definitions.remove(d); removed += 1 }
  end
  m.commit_operation
rescue Exception
  m.abort_operation
  raise
end
left = m.definitions.reject { |d| b['defs'].include?(d.name) }.map(&:name)
# materials the import brought and nothing now uses
used = {}
walk = lambda do |ents|
  ents.each do |e|
    if e.is_a?(Sketchup::Face)
      used[e.material] = 1 if e.material
      used[e.back_material] = 1 if e.back_material
    elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      used[e.material] = 1 if e.material
    end
  end
end
walk.call(m.entities)
m.definitions.each { |d| walk.call(d.entities) }
mdoomed = m.materials.select { |x| !b['mats'].include?(x.name) && !used[x] }
mdoomed.each { |x| m.materials.remove(x) }
puts "definitions removed: #{removed}; imported definitions left: #{left.length}"
puts "imported materials removed: #{mdoomed.length}; imported materials kept: #{m.materials.count { |x| !b['mats'].include?(x.name) }}"
sl = VRay::Context.active.scene['/Standard Light']
puts "/Standard Light valid=#{sl && sl.valid?}"
left
