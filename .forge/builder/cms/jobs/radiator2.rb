# Re-seat radiator 2 IN PLACE (never WR_CMS.run!: a room rebuild makes new wall groups and every
# scene's stored hidden walls would point at erased groups). Replaces the one "radiator *" group whose
# Y range overlaps window 2, inside Walls > Wall 2 fittings, using features.rb's own radiator!.
$wr_no_autorun = true
D = 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/cms/'
load D + 'room.rb'
m = Sketchup.active_model
ya, yb = ($cms_rad || [55.5, 92.5])
room = m.entities.find { |e| e.respond_to?(:name) && e.name == 'CMS Classroom' }
walls = room.definition.entities.find { |g| g.is_a?(Sketchup::Group) && g.name == 'Walls' }
fit2 = walls.definition.entities.find { |g| g.is_a?(Sketchup::Group) && g.name == 'Wall 2 fittings' }
old = fit2.entities.select { |g| g.is_a?(Sketchup::Group) && g.name =~ /\Aradiator / && g.bounds.max.y < 150 }
raise "expected one radiator 2 group, found #{old.map(&:name)}" unless old.size == 1
WR_CMS.instance_variable_set(:@m, { rad: m.materials['CMS Radiator Cream'], pipe: m.materials['CMS Pipe Cream'] })
m.start_operation('CMS: re-seat radiator 2', true)
begin
  was = [old[0].name, old[0].bounds.min.y.to_f.round(2), old[0].bounds.max.y.to_f.round(2)]
  old[0].erase!
  WR_CMS.radiator!(fit2.entities, ya, yb, 25.0)
  m.commit_operation
rescue Exception
  m.abort_operation
  raise
end
now = fit2.entities.select { |g| g.is_a?(Sketchup::Group) && g.name =~ /\Aradiator / }.map { |g| [g.name, g.bounds.min.y.to_f.round(2), g.bounds.max.y.to_f.round(2), g.entities.grep(Sketchup::Group).size] }
{ 'was' => was, 'now' => now }
