# Walsh v3 step 3: build MDL 96168 S from the 21 Oct link, with ONE change: the N2/N3 packs swapped so the
# CBL 46 stands beside the N1 window (Sarah: "place one of the cable walls to the left, beside the wall
# window"). rebalance_walls re-walks N to 46 CBL at 98-144, 22 solid at 146-168. CBL count stays 4.
load File.join(File.dirname(__FILE__), 'geom.rb')
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
raise 'booth already built (WalshRM/booth_pid); Ctrl+Z first' if m.get_attribute('WalshRM', 'booth_pid')
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/booth-from-link.rb'
LINK = 'https://test-sales-portal-production.up.railway.app/booth-builder#3=ARIEQaAgAAgIAAICAgACAAAMBA'
pl = WR_BoothLink.v3_payload(WR_BoothLink.v3_hash(LINK))
raise "link changed: #{pl['a'].inspect}" unless pl['a']['N2'] == 'STDWL22' && pl['a']['N3'] == 'STDWL46 CBL'
pl['a']['N2'], pl['a']['N3'] = pl['a']['N3'], pl['a']['N2']
before = m.entities.to_a
WR_BoothLink.build_from_payload(pl, 'dir' => 'P:/Sketchup/NewMasterComponentList', 'dry' => false)
made = m.entities.to_a - before
puts "new top-level: #{made.map { |e| "#{e.typename} #{e.respond_to?(:name) ? e.name : ''} pid=#{e.persistent_id}" }.inspect}"
b = made.find { |e| e.is_a?(Sketchup::Group) && e.name =~ /96168/ } or raise 'no booth group made'
m.set_attribute('WalshRM', 'booth_pid', b.persistent_id)
m.set_attribute('WalshRM', 'link', LINK)
WalshRM.save(m)
puts "booth #{b.name} pid #{b.persistent_id} tr #{b.transformation.origin.to_a.map { |v| v.to_f.round(3) }}"
puts "bounds #{b.bounds.min.to_a.map { |v| v.to_f.round(2) }} .. #{b.bounds.max.to_a.map { |v| v.to_f.round(2) }}"
puts "saved #{m.path}"
