# Remove the WR_DropLights rig through the tool's OWN remove path (never an abort/rollback: orphans V-Ray lights).
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/wr-drop-lights.rb'
r = WR_DropLights.remove_rig!(Sketchup.active_model)
(r['lines'] || []).each { |l| puts "  #{l}" }
r.reject { |k, _| k == 'lines' }
