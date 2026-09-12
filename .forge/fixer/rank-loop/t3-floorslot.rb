# INTERVENTION 4. Fill the WR-Floor-Render slot with the i02 material, and
# REPOINT the slot's SOURCE, because V-Ray's materials_helper renamed every
# house drafting material out from under WR_MaterialsSwap when convert_to_vray
# ran ("0128_White" -> "0128_White2").
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/wr-materials-swap.rb'
$wr_no_autorun = nil
m = Sketchup.active_model
before = { 'fills' => WR_MaterialsSwap.fills(m), 'sources' => WR_MaterialsSwap.sources(m) }
WR_MaterialsSwap.set_source(m, 'WR-Floor-Render', '0128_White2')
WR_MaterialsSwap.set_source(m, 'WR-Wall-Render',  '0099_LightSteelBlue2')
WR_MaterialsSwap.set_source(m, 'WR-Door-Render',  '0043_SaddleBrown2')
WR_MaterialsSwap.set_fill(m, 'WR-Floor-Render', 'WR Plank Grey Wide 48')
{ 'before' => before,
  'fills' => WR_MaterialsSwap.fills(m), 'sources' => WR_MaterialsSwap.sources(m),
  'diag' => WR_MaterialsSwap.diagnose_lines(WR_MaterialsSwap.diagnosis(m)) }
