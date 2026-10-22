# Read-only re-check after the SketchUp restart.
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb'
m = Sketchup.active_model
puts "path=#{m.path} modified=#{m.modified?} active_path=#{m.active_path.inspect}"
puts "running=#{WR_ProposalPackage.instance_variable_get(:@running).inspect}"
bd = m.entities.grep(Sketchup::Group).find { |g| g.name == 'Door 2 render backdrop' }
puts "backdrop=#{bd ? "pid #{bd.persistent_id} tag #{bd.layer.name}" : 'MISSING'}"
lights = m.entities.grep(Sketchup::Group).select { |g| g.name.to_s.start_with?('Tech Lab RM ceiling light') }
lc = 0; m.entities.each { |e| lc += 1 if e.respond_to?(:name) && e.name.to_s.start_with?('Tech Lab RM ceiling light') }
puts "room lights (top-level by name)=#{lc}"
dg = m.find_entity_by_persistent_id(3442717)
puts "dims: " + dg.entities.grep(Sketchup::DimensionLinear).map { |d| "#{d.persistent_id.to_s[-2..]}=#{d.text}@#{d.layer.name.sub('WR-Dims','D')}" }.join(' ')
tags = ['WR-Ceiling', 'WR Lights', 'Walsh Render Backdrop', 'WR-Dims-Long', 'WR-Dims-South', 'WR-Dims-W1-Corner', 'WR-Dims-W1-Far']
WR_SceneWalls.wall_units(m) rescue nil
st = m.pages.selected_page
prevT = m.options['PageOptions']['ShowTransition']; m.options['PageOptions']['ShowTransition'] = false
begin
  m.pages.each do |p|
    m.pages.selected_page = p
    c = p.camera
    vis = tags.map { |t| l = m.layers[t]; "#{t.sub('WR-Dims-', '').sub('Walsh Render ', '')}=#{l ? (l.visible? ? 1 : 0) : 'none'}" }.join(' ')
    hw = (WR_SceneWalls.wall_units(m).select { |u| u[:room].to_s.include?('RM 21 Oct') && u[:pieces].all?(&:hidden?) }.map { |u| u[:wall] } rescue '?')
    puts "#{p.name.split(' ').last(2).join(' ')} [#{WR_ProposalPackage.mode_of(p)}] eye=#{c.eye.to_a.map(&:round)} fov=#{c.fov.round} hidWalls=#{hw.inspect} #{vis}"
  end
ensure
  m.pages.selected_page = st if st; m.options['PageOptions']['ShowTransition'] = prevT
end
true
