# INTERVENTION 2 (workaround). WR_NameWalls.run cannot be pressed headless
# (UI.inputbox + UI.messagebox on every exit, and it defaults to a dry run).
# Worse, its scan on THIS room also proposes renaming the two door leaves in
# "106 doors" to "Wall 1"/"Wall 2" -- NEVER_TAGS lists WR-Doors / WR-Doors-Leaf
# but this room's tags are WR-106-Doors, so the guard misses. So the plan is
# filtered to the walls container only.
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/wr-name-walls.rb'
$wr_no_autorun = nil
m = Sketchup.active_model
plans, = WR_NameWalls.scan(m)
keep = plans.select { |p| p.container_label =~ /106 walls\z/ }
drop = plans - keep
m.start_operation('t3 name walls (filtered)', true)
keep.each { |p| p.group.name = p.new_name if p.group.valid? }
m.commit_operation
{ 'named' => keep.map { |p| p.new_name }, 'refused' => drop.map { |p| [p.container_label, p.group.name] } }
