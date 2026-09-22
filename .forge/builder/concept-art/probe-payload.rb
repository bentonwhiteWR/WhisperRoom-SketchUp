$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/booth-from-link.rb'
link = 'https://sales.whisperroom.com/booth-builder?live=0cebed4ed0ea6bc5e3b3d7acbf72242f#3=ARA118RgAAQCAAIGCgQIBwIA'
payload = WR_BoothLink.v3_payload(WR_BoothLink.v3_hash(link))
puts payload.inspect
WR_BoothLink.v3_report(payload)
:ok
