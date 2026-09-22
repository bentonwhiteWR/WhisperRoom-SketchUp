# Dry run of the link booth build under the bridge. Reports what resolves.
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/booth-from-link.rb'
link = 'https://sales.whisperroom.com/booth-builder?live=0cebed4ed0ea6bc5e3b3d7acbf72242f#3=ARA118RgAAQCAAIGCgQIBwIA'
h = WR_BoothLink.v3_hash(link)
payload = WR_BoothLink.v3_payload(h)
puts payload.inspect
WR_BoothLink.v3_report(payload)
cfg = { 'dir' => 'P:/Sketchup/NewMasterComponentList', 'dry' => true }
begin
  WR_BoothLink.build_from_payload(payload, cfg)
rescue WhisperRoom::Bridge::ModalBlocked => e
  puts "MODAL (expected on dry run): #{e.message[0, 300]}"
end
:dry_done
