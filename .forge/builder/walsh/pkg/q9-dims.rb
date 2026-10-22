m = Sketchup.active_model
g = m.entities.grep(Sketchup::Group).find { |x| x.persistent_id == 3442717 }
puts "dims group #{g.name.inspect} tag=#{g.layer.name} hidden=#{g.hidden?}"
h = Hash.new(0); g.entities.each { |e| h["#{e.typename}/#{e.layer.name}"] += 1 }
puts h.inspect
g.entities.grep(Sketchup::Text).each { |t| puts "  TEXT #{t.text.inspect}" }
g.entities.grep(Sketchup::DimensionLinear).first(3).each { |d| puts "  dim text=#{d.text.inspect} start=#{d.start[1].to_a.map{|c|c.round}} end=#{d.end[1].to_a.map{|c|c.round}}" }
puts "tags:"
m.layers.each { |l| puts "  #{l.name} visible=#{l.visible?}" }
puts "top-level texts:"
m.entities.grep(Sketchup::Text).each { |t| puts "  #{t.layer.name} #{t.text[0,60].inspect} hidden=#{t.hidden?}" }
true
