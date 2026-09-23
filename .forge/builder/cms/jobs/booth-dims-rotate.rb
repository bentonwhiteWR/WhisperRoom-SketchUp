# Step 8b: Rotate booth dimensions, headless (WR_BoothDims.rotate; the rotate button's own path).
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/dimension-whisperroom.rb'
m = Sketchup.active_model
b = m.entities.find { |e| e.respond_to?(:name) && e.name == 'MDL 96144 E (components)' }
WR_BoothDims.rotate(b)
b.get_attribute(WR_BoothDims::DICT, 'corner')
