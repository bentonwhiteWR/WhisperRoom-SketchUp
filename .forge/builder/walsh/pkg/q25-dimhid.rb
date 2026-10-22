m = Sketchup.active_model
g = m.find_entity_by_persistent_id(3442717)
dims = g.entities.grep(Sketchup::DimensionLinear)
prevT = m.options['PageOptions']['ShowTransition']; m.options['PageOptions']['ShowTransition'] = false
st = m.pages.selected_page
m.pages.each { |p| m.pages.selected_page = p; puts "#{p.name.split(' ').last(2).join(' ')} hidden=#{dims.select(&:hidden?).map(&:text).join('|')}" }
m.pages.selected_page = st; m.options['PageOptions']['ShowTransition'] = prevT
true
