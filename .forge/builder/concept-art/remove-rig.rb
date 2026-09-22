# Remove the Drop-in-the-Lights rig through the tool's OWN remove path
# (remove_rig! - the backend of its "Remove all lights" button, minus the
# confirmation dialog). Never an abort/rollback: that orphans V-Ray lights.
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-drop-lights.rb'
r = WR_DropLights.remove_rig!(Sketchup.active_model)
(r['lines'] || []).each { |l| puts "  #{l}" }
sl = VRay::Context.active.scene['/Standard Light']
puts "/Standard Light valid=#{sl && sl.valid?}"
r.reject { |k, _| k == 'lines' }
