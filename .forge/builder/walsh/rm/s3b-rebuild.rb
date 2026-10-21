# Walsh v3 step 3b (21 Oct, Benton): the s3 build swapped N2/N3, which made the 22 the END section on N.
# The booth builder (headless, same link) reads N0 46 WDO | N1 46 WDO | N2 22 | N3 46 CBL, S0 46 CBL |
# S1 46 CBL | S2 22 | S3 46 CBL, E0 46 | E1 46, W0 43 | W1 WA door R. Rebuild EXACTLY from the link, no edits.
# The wrong booth is hidden on its own tag (never deleted).
load File.join(File.dirname(__FILE__), 'geom.rb')
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
bad_pid = m.get_attribute('WalshRM', 'booth_pid')
raise 'already rebuilt' if m.get_attribute('WalshRM', 'bad_booth_pid')
bad = m.entities.find { |e| e.persistent_id == bad_pid } or raise "wrong booth #{bad_pid} not found"
m.start_operation('Walsh v3: retire swapped booth', true)
begin
  tg = m.layers['Walsh RM swapped N 21 Oct'] || m.layers.add('Walsh RM swapped N 21 Oct')
  tg.visible = false
  bad.layer = tg
  bad.name = bad.name + ' (WRONG N order, swapped)'
  m.set_attribute('WalshRM', 'bad_booth_pid', bad_pid)
  m.delete_attribute('WalshRM', 'booth_pid')
  m.commit_operation
rescue Exception
  m.abort_operation
  raise
end
WalshRM.save(m)
puts "retired #{bad.name} pid #{bad_pid} on hidden tag; saved"
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/booth-from-link.rb'
LINK = 'https://test-sales-portal-production.up.railway.app/booth-builder#3=ARIEQaAgAAgIAAICAgACAAAMBA'
pl = WR_BoothLink.v3_payload(WR_BoothLink.v3_hash(LINK))
want = { 'N0' => 'STDWL46 WDO3248', 'N1' => 'STDWL46 WDO3248', 'N2' => 'STDWL22', 'N3' => 'STDWL46 CBL',
         'S0' => 'STDWL46 CBL', 'S1' => 'STDWL46 CBL', 'S2' => 'STDWL22', 'S3' => 'STDWL46 CBL',
         'E0' => 'STDWL46', 'E1' => 'STDWL46', 'W0' => 'STDWL43', 'W1' => 'WA STDDRFRM R' }
diff = want.reject { |k, v| pl['a'][k] == v }
raise "link decode differs from the builder: #{diff.keys.map { |k| "#{k}=#{pl['a'][k]}" }}" unless diff.empty?
before = m.entities.to_a
WR_BoothLink.build_from_payload(pl, 'dir' => 'P:/Sketchup/NewMasterComponentList', 'dry' => false)
made = m.entities.to_a - before
b = made.find { |e| e.is_a?(Sketchup::Group) && e.name =~ /96168/ } or raise 'no booth group made'
m.set_attribute('WalshRM', 'booth_pid', b.persistent_id)
m.set_attribute('WalshRM', 'link', LINK)
WalshRM.save(m)
puts "booth #{b.name} pid #{b.persistent_id}"
# panel order per wall, booth-local
b.entities.each do |c|
  next unless c.respond_to?(:definition)
  tok = c.name.split(' ').first.to_s
  next unless tok =~ /\A[NSEW]\d\z/
  bb = c.bounds
  puts format('  %-4s %-28s x %7.2f..%7.2f  y %6.2f..%6.2f', tok, c.definition.name[0, 28], bb.min.x, bb.max.x, bb.min.y, bb.max.y)
end
puts "saved #{m.path}"
