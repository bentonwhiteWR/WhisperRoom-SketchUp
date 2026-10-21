m = Sketchup.active_model
%w[Walsh\ Corner\ v2\ 21\ Oct WR-Room-New Walsh\ RM\ swapped\ N\ 21\ Oct Walsh\ Corner\ v1\ 21\ Oct Walsh\ Assembly].each do |n|
  l = m.layers[n]; puts "#{n}: model visible=#{l && l.visible?}"
end
puts "selected page: #{m.pages.selected_page && m.pages.selected_page.name}"
m.pages.each { |p| next unless p.get_attribute('WR_AutoSet', 'token'); puts "#{p.name}: use_hidden_layers=#{p.use_hidden_layers?} " + %w[Walsh\ Corner\ v2\ 21\ Oct WR-Room-New Walsh\ RM\ swapped\ N\ 21\ Oct].map { |n| "#{n}=#{p.respond_to?(:get_visibility) ? p.get_visibility(m.layers[n]) : '?'}" }.join(' ') }
l = m.layers['Walsh Assembly']
cnt = 0
walk = lambda { |ents| ents.each { |e| cnt += 1 if e.layer == l; walk.(e.definition.entities) if e.respond_to?(:definition) && e.layer != l } }
walk.(m.entities)
puts "Walsh Assembly entities: #{cnt}"
