# Step 6a: WR_DropLights, office rig, ONLY the invisible fill-sphere scatter round the booth.
# Benton: no new visible fixtures (the room's own fluorescents are the visible ones), so the office
# panel grid (panel + plenum) is OFF; the face wash is OFF (real-interior lighting, not a product rig).
# WORKAROUND (scripts/ untouched): HEADROOM (18 in, written for 8 ft rooms) would put the booth-detect
# line at 107 in under this 125.4 in ceiling, above the 89 in booth top, and every booth role would be
# skipped. Raised for this press only and restored.
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/wr-drop-lights.rb'
m = Sketchup.active_model
room  = m.entities.find { |e| e.respond_to?(:name) && e.name == 'CMS Classroom' }
booth = m.entities.find { |e| e.respond_to?(:name) && e.name =~ /\AMDL 96144/ }
raise 'no room' unless room
raise 'no booth' unless booth
st = WR_DropLights.default_settings
st['rig'] = 'office'
st['ceiling'] = false
st['walls'] = 'none'
st['mult'] = ($wr_rig_mult || 1.0)
st['layers'].each_key { |k| st['layers'][k]['on'] = false }
st['layers']['fill']['on'] = true
orig = WR_DropLights::HEADROOM
begin
  WR_DropLights.send(:remove_const, :HEADROOM)
  WR_DropLights.const_set(:HEADROOM, 50.0)
  WR_DropLights.run(st, [room, booth])
ensure
  WR_DropLights.send(:remove_const, :HEADROOM)
  WR_DropLights.const_set(:HEADROOM, orig)
end
puts "HEADROOM restored to #{WR_DropLights::HEADROOM}"
:dropped
