# Read-only: v3 room walls/ceiling + each scene's hidden answer and camera.
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-scene-walls.rb' unless defined?(WR_SceneWalls)
m = Sketchup.active_model
room = m.entities.find { |e| e.persistent_id == 3442119 }
puts "room #{room.name} tag=#{room.layer.name} hid=#{room.hidden?} bb=#{room.bounds.min.to_a.map(&:round)}-#{room.bounds.max.to_a.map(&:round)}"
room.definition.entities.each do |e|
  next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
  e.definition.entities.grep(Sketchup::Face).first(1).each { |f| puts "     face z=#{f.bounds.min.z.round} mat=#{f.material&.name} back=#{f.back_material&.name}" } if e.name.start_with?("Ceiling")
  puts "  #{e.name} tag=#{e.layer.name} hid=#{e.hidden?}"
  e.definition.entities.grep(Sketchup::Group).each { |g| b = g.bounds; puts "     #{g.name} pid=#{g.persistent_id} bb=#{b.min.to_a.map(&:round)}-#{b.max.to_a.map(&:round)} mat=#{g.material&.name}" }
end
units = WR_SceneWalls.wall_units(m)
ceils = WR_SceneWalls.ceiling_units(m)
puts "ceilings: #{ceils.map { |c| "#{c[:key]} #{c[:label]} #{c[:box].inspect}" }.inspect}"
pre = 'Booth - MDL 96168 S RM (21 Oct link) '
start = m.pages.selected_page
m.options['PageOptions']['ShowTransition'] = false
m.pages.each do |p|
  m.pages.selected_page = p
  hid = units.select { |u| u[:room] == room.name && u[:pieces].first.hidden? }.map { |u| u[:wall] }
  ch = ceils.select { |c| c[:pieces].first.hidden? }.map { |c| c[:key] }
  c = p.camera
  puts "#{p.name.sub(pre,'')} | hidden walls #{hid.inspect} ceil #{ch.inspect} | eye #{c.eye.to_a.map(&:round)} tgt #{c.target.to_a.map(&:round)} #{c.perspective? ? "fov#{c.fov.round}" : 'ortho'} aspect=#{c.aspect_ratio}"
end
m.pages.selected_page = start
true
