# Walsh corner: step 2. Identify the Platform copy, hide the Ramp copy by its tag, park the old Platform room
# and its old floor dims on hidden "old" tags (nothing deleted). Records what it found in model attributes
# (dict WalshCorner) for the later steps. DRY = true to only report.
DRY = defined?($walsh_dry) ? $walsh_dry : false
m = Sketchup.active_model
D = 'WalshCorner'
tops = m.entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
nm = ->(e) { e.is_a?(Sketchup::Group) ? e.name.to_s : "#{e.name} #{e.definition.name}" }
rooms = tops.select { |e| nm.(e) =~ /Tech Lab/i }
booths = tops.select { |e| nm.(e) =~ /Booth.*96168/i }
puts "rooms: #{rooms.map { |r| "#{nm.(r)}@#{r.layer.name}" }}"
puts "booths: #{booths.map { |b| "#{nm.(b)}@#{b.layer.name}" }}"
raise "expected 2 rooms, got #{rooms.size}" unless rooms.size == 2
hid = ->(pg) { pg ? pg.layers.map(&:name) : [] }
pp6 = m.pages['Platform 06 TopDown']
rp6 = m.pages['Ramp 06 TopDown']
raise 'no Platform 06 TopDown scene' unless pp6
plat_room = rooms.find { |r| !hid.(pp6).include?(r.layer.name) && (rp6.nil? || hid.(rp6).include?(r.layer.name)) }
if plat_room.nil?
  # fallback: Platform copy is the one with a platform-ish group inside its bounds
  plat_room = rooms.find do |r|
    tops.any? { |e| nm.(e) =~ /platform/i && r.bounds.contains?(e.bounds.center) }
  end
end
raise 'could not tell which room is the Platform copy; set it by hand' unless plat_room
ramp_room = (rooms - [plat_room]).first
puts "PLATFORM room tag=#{plat_room.layer.name} origin=#{plat_room.transformation.origin.to_a.map { |v| v.to_f.round(3) }}"
puts "RAMP room tag=#{ramp_room.layer.name}"
raise 'Platform room is rotated; the move maths assume axis-aligned' unless plat_room.transformation.xaxis.parallel?(X_AXIS)
bb = plat_room.bounds
inside = ->(e) { c = e.bounds.center; c.x.between?(bb.min.x - 24, bb.max.x + 24) && c.y.between?(bb.min.y - 24, bb.max.y + 24) }
movers = tops.select { |e| e != plat_room && !rooms.include?(e) && inside.(e) }
movers.each { |e| puts "  platform-copy member: #{nm.(e)} tag=#{e.layer.name} bb=#{e.bounds.min.to_a.map { |v| v.to_f.round(1) }}..#{e.bounds.max.to_a.map { |v| v.to_f.round(1) }}" }
old_dims = m.entities.select { |e| (e.is_a?(Sketchup::DimensionLinear) || e.is_a?(Sketchup::Text) || e.is_a?(Sketchup::ConstructionPoint)) && inside.(e) }
# dims nested in a dims group also count
dim_groups = tops.select { |e| inside.(e) && e.is_a?(Sketchup::Group) && e.entities.all? { |x| x.is_a?(Sketchup::Dimension) || x.is_a?(Sketchup::Text) || x.is_a?(Sketchup::ConstructionPoint) } && e.entities.size > 0 }
puts "old loose dims/text/cpoints in Platform area: #{old_dims.size}; dim-only groups: #{dim_groups.size}"
unless DRY
  m.start_operation('Walsh corner: retag', true)
  t_old = m.layers['Walsh Old Room 12 Oct'] || m.layers.add('Walsh Old Room 12 Oct')
  t_od  = m.layers['Walsh Old Dims 12 Oct'] || m.layers.add('Walsh Old Dims 12 Oct')
  plat_room.layer = t_old
  (old_dims + dim_groups).each { |e| e.layer = t_od }
  movers -= dim_groups
  ramp_tag = ramp_room.layer
  ramp_tag = nil if ramp_tag.name == 'Layer0' || ramp_tag.name == 'Untagged'
  [t_old, t_od].each { |t| t.visible = false }
  m.pages.each do |pg|
    next unless pg.respond_to?(:set_visibility)
    pg.set_visibility(t_old, false)
    pg.set_visibility(t_od, false)
  end
  if ramp_tag && ramp_tag != (movers.first && movers.first.layer)
    ramp_tag.visible = false
    puts "hid Ramp copy tag #{ramp_tag.name}"
  else
    puts 'WARNING: Ramp copy shares its tag with the Platform copy or is untagged; NOT hidden by tag'
  end
  o = plat_room.transformation.origin
  m.set_attribute(D, 'origin', o.to_a.map(&:to_f))
  m.set_attribute(D, 'movers', movers.map(&:persistent_id))
  m.set_attribute(D, 'ramp_tag', ramp_tag ? ramp_tag.name : '')
  m.set_attribute(D, 'plat_tag', movers.first ? movers.first.layer.name : '')
  m.commit_operation
  m.save
  puts "saved #{m.path}"
end
