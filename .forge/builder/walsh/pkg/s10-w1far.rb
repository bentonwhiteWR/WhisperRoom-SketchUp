# Hide set WR-Dims-W1-Far on the 01-angled and 03-high IMAGE scenes too (its text is out of view there,
# leaving an orphan dimension line). Tag visibility only; no dim touched.
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/walsh/rm/geom.rb'
m = Sketchup.active_model
raise "wrong file" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
l = m.layers['WR-Dims-W1-Far'] or raise 'no set'
prevT = m.options['PageOptions']['ShowTransition']; m.options['PageOptions']['ShowTransition'] = false
st = m.pages.selected_page
begin
  m.pages.select { |p| p.name.end_with?('link) 01-angled', 'link) 03-high') }.each do |p|
    m.pages.selected_page = p
    l.visible = false; p.set_visibility(l, false)
    puts "#{p.name}: W1-Far off"
  end
ensure
  m.pages.selected_page = st if st; m.options['PageOptions']['ShowTransition'] = prevT
end
WalshRM.save(m)
true
