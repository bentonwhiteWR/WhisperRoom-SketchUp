# Erase the two 2x2 squares cut from S1i, now that the full sheet 'Foam  S1i' (slot S13) is placed and verified.
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/walsh/ap9/b-lib.rb'
m = B8.model!
b = B8.booth(m)
pcs = B8.pieces(b)
full = pcs.select { |e| e.definition.name == 'Foam' && e.get_attribute('wr_walsh', 'v8_slot') == 'S13' }
raise "expected one full Foam on slot S13, found #{full.length}" unless full.length == 1 && full[0].name == 'Foam  S1i'
sq = pcs.select { |e| [3385434, 3390465].include?(e.persistent_id) }
raise "expected the two S1i squares, found #{sq.map(&:name)}" unless sq.length == 2 &&
  sq.all? { |e| e.definition.name =~ /\AFoam \(2x2\) back (left|right)\z/ && e.name =~ /S1i cut/ }
names = sq.map { |e| "#{e.name} [#{e.definition.name}]" }
m.start_operation('Walsh AP v8: erase the S1i squares (replaced by a full sheet)', true)
begin
  b.entities.erase_entities(sq)
  m.commit_operation
rescue Exception => e
  m.abort_operation
  raise e
end
$b8_result = JSON.generate({ 'erased' => names, 'foam_now' => B8.pieces(b).map { |e| e.definition.name }.tally })
