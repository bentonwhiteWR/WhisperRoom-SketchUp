# Walsh v3 step 7: keep every retired layer out of the v3 AUTO-SET scenes. After AUTO-SET the model had
# Walsh Corner v2 / WR-Room-New / Walsh RM swapped visible (the old 'Ramp 06 TopDown' scene was left
# selected). Hide them in the model and in each stamped page's tag list; nothing else on a page changes.
load File.join(File.dirname(__FILE__), 'geom.rb')
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
RETIRED = ['Walsh Old Room 12 Oct', 'Walsh Old Dims 12 Oct', 'Walsh Ramp Option 12 Oct', 'WR-Room-New',
           'Walsh Corner v1 21 Oct', 'Walsh Corner v2 21 Oct', 'Walsh RM swapped N 21 Oct'].freeze
tags = RETIRED.map { |n| m.layers[n] or raise "no tag #{n}" }
pages = m.pages.select { |p| p.get_attribute('WR_AutoSet', 'token') }
raise 'Page#set_visibility missing' unless pages.first.respond_to?(:set_visibility)
m.start_operation('Walsh v3: retired tags out of the scenes', true)
begin
  tags.each { |t| t.visible = false }
  pages.each { |p| tags.each { |t| p.set_visibility(t, false) } }
  m.commit_operation
rescue Exception
  m.abort_operation
  raise
end
pages.each { |p| miss = RETIRED - p.layers.map(&:name); puts "#{p.name}: retired tags not hidden: #{miss.inspect}" }
WalshRM.save(m)
puts "saved #{m.path}"
