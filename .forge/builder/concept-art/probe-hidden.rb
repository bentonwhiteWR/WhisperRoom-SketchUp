m = Sketchup.active_model
loft = m.entities.find { |e| e.is_a?(Sketchup::Group) && e.name == 'Loft' }
walls = loft.entities.find { |c| c.is_a?(Sketchup::Group) && c.name == 'Walls' }
puts "selected page: #{m.pages.selected_page ? m.pages.selected_page.name : nil}"
puts "loft hidden=#{loft.hidden?} walls-group hidden=#{walls.hidden?}"
walls.entities.grep(Sketchup::Group).each { |g| puts "  #{g.name}: hidden=#{g.hidden?}" if g.hidden? || g.name =~ /\AWall \d\z|Ceiling/ }
puts "layers hidden: #{m.layers.reject(&:visible?).map(&:name).inspect}"
m.pages.each { |pg| puts "  page #{pg.name}: shadow=#{pg.use_shadow_info?} hidden=#{pg.use_hidden_geometry? rescue '?'} layers=#{pg.use_hidden_layers?}" }
:ok
