# Walsh corner: step 2 (as found 21 Oct). The live file holds ONE room ("Tech Lab 13") and TWO booths at the
# same spot: "Booth - MDL 96168 E" (door ramp option) and "Booth - MDL 96168 E PLATFORM" (entity-hidden,
# platform + ramp in Component#17). All three on tag "Walsh Assembly". This step, nothing deleted:
#   old room + its ceiling lights -> tag 'Walsh Old Room 12 Oct' (hidden)
#   loose old dims/text/cpoints/edges and the dims inside the PLATFORM booth -> 'Walsh Old Dims 12 Oct' (hidden)
#   Ramp booth -> tag 'Walsh Ramp Option 12 Oct' (hidden)
#   PLATFORM booth unhidden (it is the one that moves in s4b)
load File.join(File.dirname(__FILE__), "geom.rb")
DRY = defined?($walsh_dry) ? $walsh_dry : false
m = Sketchup.active_model
D = 'WalshCorner'
gi = ->(e) { e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
tops = m.entities.select(&gi)
room = tops.select { |e| e.name == 'Tech Lab 13' }
pb = tops.select { |e| e.name == 'Booth - MDL 96168 E PLATFORM' }
rb = tops.select { |e| e.name == 'Booth - MDL 96168 E' }
raise "expected 1 room/1 platform booth/1 ramp booth, got #{room.size}/#{pb.size}/#{rb.size}" unless [room, pb, rb].all? { |a| a.size == 1 }
room = room[0]; pb = pb[0]; rb = rb[0]
lights = tops.select { |e| e.name =~ /Tech Lab ceiling light/ }
loose = m.entities.select { |e| e.is_a?(Sketchup::Dimension) || e.is_a?(Sketchup::Text) || e.is_a?(Sketchup::ConstructionPoint) || e.is_a?(Sketchup::ConstructionLine) || e.is_a?(Sketchup::Edge) }
pdims = pb.entities.select { |e| e.is_a?(Sketchup::Dimension) || e.is_a?(Sketchup::Text) }
puts "room #{room.persistent_id} origin #{room.transformation.origin.to_a.map(&:to_f)}; lights #{lights.size}; loose annot #{loose.size}; dims inside PLATFORM booth #{pdims.size}"
puts "PLATFORM booth pid #{pb.persistent_id} hidden=#{pb.hidden?}; Ramp booth pid #{rb.persistent_id}"
unless DRY
  m.start_operation('Walsh corner: retag', true)
  begin
    t_old = m.layers['Walsh Old Room 12 Oct'] || m.layers.add('Walsh Old Room 12 Oct')
    t_od  = m.layers['Walsh Old Dims 12 Oct'] || m.layers.add('Walsh Old Dims 12 Oct')
    t_rb  = m.layers['Walsh Ramp Option 12 Oct'] || m.layers.add('Walsh Ramp Option 12 Oct')
    room.layer = t_old
    lights.each { |e| e.layer = t_old }
    (loose + pdims).each { |e| e.layer = t_od }
    rb.layer = t_rb
    pb.hidden = false
    [t_old, t_od, t_rb].each { |t| t.visible = false }
    m.pages.each do |pg|
      next unless pg.respond_to?(:set_visibility)
      [t_old, t_od, t_rb].each { |t| pg.set_visibility(t, false) }
    end
    m.set_attribute(D, 'origin', room.transformation.origin.to_a.map(&:to_f))
    m.set_attribute(D, 'movers', [pb.persistent_id])
    m.set_attribute(D, 'ramp_tag', t_rb.name)
    m.set_attribute(D, 'plat_tag', pb.layer.name)
    m.commit_operation
  rescue Exception => e
    m.abort_operation
    raise
  end
  WalshCorner.save(m)
  puts "saved #{m.path}"
end
