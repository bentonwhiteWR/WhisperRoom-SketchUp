# Base lighting from the house tool: WR_DropLights, classic rig, headless.
#
# WORKAROUND, NOT A FIX (reported, scripts/ untouched): WR_DropLights counts an
# object as an obstruction -- and so as a BOOTH to aim the key / rim / foam
# graze at -- only if it rises above (ceiling - HEADROOM), HEADROOM = 18 in,
# written for 8 ft rooms. Under this 14 ft loft ceiling the booth (top 104.6
# in) falls below that line and every booth role is skipped ("no booth in
# this room"). The constant is raised for THIS press only and put back after.
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-drop-lights.rb'
m = Sketchup.active_model
room  = m.entities.find { |e| e.is_a?(Sketchup::Group) && e.name == 'Loft' }
booth = m.entities.find { |e| e.respond_to?(:name) && e.name =~ /\AMDL 96120/ }
raise 'no Loft room group' if room.nil?
raise 'no booth group' if booth.nil?
st = WR_DropLights.default_settings
st['rig'] = 'classic'
st['ceiling'] = false
st['walls'] = 'none'
st['mult'] = ($wr_rig_mult || 1.0)
orig = WR_DropLights::HEADROOM
begin
  WR_DropLights.send(:remove_const, :HEADROOM)
  WR_DropLights.const_set(:HEADROOM, 100.0)
  WR_DropLights.run(st, [room, booth])
ensure
  WR_DropLights.send(:remove_const, :HEADROOM)
  WR_DropLights.const_set(:HEADROOM, orig)
end
puts "HEADROOM restored to #{WR_DropLights::HEADROOM}"
sl = VRay::Context.active.scene['/Standard Light']
puts "AFTER: /Standard Light valid=#{sl && sl.valid?}"
:dropped
