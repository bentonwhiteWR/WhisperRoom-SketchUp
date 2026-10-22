$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb' unless defined?(WR_ProposalPackage)
m = Sketchup.active_model
bb = WR_Preflight.stray_bounds(m)
puts "room bb #{bb.min.to_a.map(&:to_i)} - #{bb.max.to_a.map(&:to_i)}"
puts 'WR-Room/WR-Floor tagged:'
(WR_ProposalScenes.tagged(m, 'WR-Room') + WR_ProposalScenes.tagged(m, 'WR-Floor')).each do |e|
  b = e.bounds
  puts "  #{e.typename} #{(e.name rescue '')} tag=#{e.layer.name} pid=#{e.persistent_id} [#{b.min.to_a.map(&:round)}]-[#{b.max.to_a.map(&:round)}]"
end
puts 'stray hits:'
WR_Preflight.stray_hits(m).each do |e|
  b = e.bounds
  puts "  #{e.typename} #{(e.name rescue '')} tag=#{e.layer.name} pid=#{e.persistent_id} vis=#{!e.hidden? && e.layer.visible?} [#{b.min.to_a.map(&:round)}]-[#{b.max.to_a.map(&:round)}]"
end
puts 'loose edges:'
m.entities.grep(Sketchup::Edge).each { |e| puts "  pid=#{e.persistent_id} tag=#{e.layer.name} #{e.start.position.to_a.map { |v| v.round(1) }} -> #{e.end.position.to_a.map { |v| v.round(1) }} hidden=#{e.hidden?}" }
true
