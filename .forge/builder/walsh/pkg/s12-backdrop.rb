# Closes the Door 2 opening for the V-Ray renders: a small enclosed stub (floor, ceiling, back, two sides)
# just outside the south wall behind Door 2, on its own tag, visible ONLY on the two render scenes.
# Assumed geometry (not measured): 49" wide x 34" deep x 84" high. One new top-level group only.
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/walsh/rm/geom.rb'
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb'
m = Sketchup.active_model
raise "wrong file" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
TAG = 'Walsh Render Backdrop'
raise 'backdrop already built' if m.entities.grep(Sketchup::Group).any? { |g| g.name == 'Door 2 render backdrop' }
floor = m.find_entity_by_persistent_id(3442119).definition.entities.grep(Sketchup::Group).find { |g| g.name == 'Floor' }
walls = m.find_entity_by_persistent_id(3442119).definition.entities.grep(Sketchup::Group).find { |g| g.name == 'Walls' }
wmats = Hash.new(0)
scan = ->(ents) { ents.each { |x| if x.is_a?(Sketchup::Face) then (wmats[x.material] += 1 if x.material) elsif x.is_a?(Sketchup::Group) then (wmats[x.material] += 1 if x.material); scan.(x.entities) end } }
scan.(walls.entities)
wallm = wmats.max_by { |_, c| c }&.first or raise 'no wall material'
puts "wall material=#{wallm.display_name}"
floorm = floor.entities.grep(Sketchup::Face).map(&:material).compact.first
x0, x1, y0, y1, h = 256.0, 305.0, -25.88, -60.0, 84.0
m.start_operation('Walsh Door 2 render backdrop', true)
begin
  l = m.layers[TAG] || m.layers.add(TAG)
  g = m.entities.add_group
  g.name = 'Door 2 render backdrop'
  e = g.entities
  P = ->(x, y, z) { Geom::Point3d.new(x, y, z) }
  faces = {
    floor: [P[x0,y0,0], P[x1,y0,0], P[x1,y1,0], P[x0,y1,0]],
    ceil:  [P[x0,y0,h], P[x0,y1,h], P[x1,y1,h], P[x1,y0,h]],
    back:  [P[x0,y1,0], P[x1,y1,0], P[x1,y1,h], P[x0,y1,h]],
    west:  [P[x0,y0,0], P[x0,y1,0], P[x0,y1,h], P[x0,y0,h]],
    east:  [P[x1,y0,0], P[x1,y0,h], P[x1,y1,h], P[x1,y1,0]],
  }
  faces.each do |k, pts|
    f = e.add_face(pts)
    mat = k == :floor ? (floorm || wallm) : wallm
    f.material = mat; f.back_material = mat
  end
  g.layer = l
  g.set_attribute('walsh_pkg2', 'why', 'closes Door 2 opening for V-Ray; render scenes only; size assumed')
  m.commit_operation
rescue => ex
  m.commit_operation; raise ex
end
WalshRM.save(m)
st = m.pages.selected_page
prevT = m.options['PageOptions']['ShowTransition']; m.options['PageOptions']['ShowTransition'] = false
begin
  m.pages.each do |p|
    m.pages.selected_page = p
    vis = WR_ProposalPackage.mode_of(p) == 'render'
    l.visible = vis; p.set_visibility(l, vis)
    puts "#{p.name.split(' ').last(2).join(' ')} backdrop=#{vis}"
  end
ensure
  m.pages.selected_page = st if st; m.options['PageOptions']['ShowTransition'] = prevT
end
puts "floor material=#{floorm&.display_name.inspect}"
WalshRM.save(m)
true
