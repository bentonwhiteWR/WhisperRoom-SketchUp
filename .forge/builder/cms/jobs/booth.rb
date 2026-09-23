# Step 4: the booth from link ?d=b31cfb67e46d (MDL 96144 E), headless. $cms_dry = true for a dry run.
# The payload is the portal's own answer to GET /api/booth-design/b31cfb67e46d (fetched 22 Sep 2026),
# pasted here because the tool's ?d= path fetches asynchronously (Sketchup::Http), which a bridge job
# cannot wait on.
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/booth-from-link.rb'
require 'json'
payload = JSON.parse('{"m":"MDL 96144","v":"E","h":"L","f":"Gray","wd":0,"rp":0,"hx":0,"cs":1,"vs":0,"ef":0,"rv":0,"sl":1,"jp":0,"bt":1,"dk":0,"sp":1,"nv":0,"ac":1,"dox":0,"fc":"S","a":{"N0":"STDWL46 VNT","N1":"STDWL46 VNT","N2":"STDWL46 VNT","S0":"STDWL46 DRFRM L","E0":"STDWL46","S1":"STDWL46 WDO3236","S2":"STDWL46","E1":"STDWL46","W0":"STDWL46","W1":"STDWL46 VNT"}}')
cfg = { 'dir' => 'Z:/Sketchup/NewMasterComponentList', 'dry' => ($cms_dry ? true : false) }
before = Sketchup.active_model.entities.to_a
begin
  WR_BoothLink.build_from_payload(payload, cfg)
rescue WhisperRoom::Bridge::ModalBlocked => e
  puts "MODAL: #{e.message[0, 600]}"
end
added = Sketchup.active_model.entities.to_a - before
added.map { |e| [e.class.to_s, (e.name rescue ''), e.layer.name, e.bounds.min.to_a.map { |v| v.to_f.round(2) }, e.bounds.max.to_a.map { |v| v.to_f.round(2) }] }
