# Benton's toggle's OWN Render path, headless: WR_Mode.to_render (tags + every scene stamped, materials,
# style, shadows) -- explicit direction, never the flip. No messagebox (report is not called).
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/wr-mode.rb'
r = WR_Mode.to_render(Sketchup.active_model)
{ 'from' => r[:from], 'to' => r[:to], 'stuck' => r[:stuck] }
