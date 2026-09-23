# Step 8: Dimension a WhisperRoom, headless (WR_BoothDims.dimension; the click tool's own path).
# $cms_corner: nil = the stored/default corner, or 'FR' / 'FL' / 'RL' / 'RR'.
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/dimension-whisperroom.rb'
m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:name) && e.name == 'MDL 96144 E (components)' }
made = WR_BoothDims.dimension(b, $cms_corner)
dims = []
walk = lambda { |ents, tr| ents.each { |e| if e.is_a?(Sketchup::DimensionLinear) && e.layer.name == 'WR-Dims-Booth'; dims << [e.text.to_s.empty? ? e.start[1].transform(tr).distance(e.end[1].transform(tr)).to_s : e.text, e.start[1].transform(tr).to_a.map { |v| v.to_f.round(1) }, e.end[1].transform(tr).to_a.map { |v| v.to_f.round(1) }]; elsif e.respond_to?(:definition) && e == b; walk.call(e.definition.entities, tr * e.transformation); end } }
walk.call(m.entities, Geom::Transformation.new)
{ 'corner' => b.get_attribute(WR_BoothDims::DICT, 'corner'), 'made' => (made.size rescue made.inspect), 'dims' => dims }
