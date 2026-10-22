# Walsh v3 package 2, step 6: close the room on the render scenes, drop the dark render, fix dim text.
#  - 01-angled r / 02-front r: show the v3 room's walls (none hidden: both cameras are INSIDE the room),
#    show WR-Ceiling and WR Lights in the scene. 02-front r re-aimed from outside the south wall
#    (eye y -230 saw V-Ray ground between it and the room) to the SW corner inside the room.
#  - 03-high r -> Skip (dark).
#  - Dims (values untouched): 2" / 4" / 1" text moved outside their extension lines;
#    11' 11 15/16" dim line pushed further out so its text clears Wall 2.
load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/walsh/rm/geom.rb'
$wr_no_autorun = true
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/proposal-package.rb' unless defined?(WR_ProposalPackage)
load 'C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-scene-walls.rb' unless defined?(WR_SceneWalls)
m = Sketchup.active_model
raise "wrong file: #{m.path}" unless m.path.to_s.gsub(92.chr, '/').casecmp?(WalshRM::RM_SKP)
raise "edit context open" if m.active_path && !m.active_path.empty?
WalshRM.save(m)
pre = 'Booth - MDL 96168 S RM (21 Oct link) '
pg = ->(n) { m.pages[pre + n] or raise "no page #{n}" }
room = m.entities.find { |e| e.persistent_id == 3442119 } or raise 'no v3 room'
units = WR_SceneWalls.wall_units(m).select { |u| u[:room] == room.name }
raise "v3 room has #{units.size} wall units" unless units.size == 5
show_all = units.each_with_object({}) { |u, h| h[u[:key]] = false }
prev = m.options['PageOptions']['ShowTransition']
m.options['PageOptions']['ShowTransition'] = false
v = m.active_view
start = m.pages.selected_page
begin
  m.start_operation('Walsh package 2: closed-room renders', true)
  { '01-angled r' => nil,
    '02-front r'  => Sketchup::Camera.new([14, -12, 62], [218, 24, 44], Z_AXIS, true, 50) }.each do |n, cam|
    p = pg.(n)
    m.pages.selected_page = p
    if cam
      v.camera = cam
      v.refresh
      p.update(PAGE_USE_CAMERA)
    end
    r = WR_SceneWalls.write_scene(p, show_all)
    m.pages.selected_page = p
    %w[WR-Ceiling WR\ Lights].each { |t| m.layers[t].visible = true }
    p.update(PAGE_USE_LAYER_VISIBILITY)
    puts "#{n}: walls shown (#{r[:changed]} pieces), ceiling + lights tags shown#{cam ? ', re-aimed' : ''}"
  end
  WR_ProposalPackage.set_mode(pg.('03-high r'), 'skip')
  g = m.entities.grep(Sketchup::Group).find { |x| x.persistent_id == 3442717 } or raise 'no RM dims'
  dim = ->(pid) { g.entities.find { |e| e.persistent_id == pid } or raise "no dim #{pid}" }
  before = [3442718, 3442723, 3442727, 3442728].map { |pid| [pid, dim.(pid).text, Sketchup.format_length(dim.(pid).start[1].distance(dim.(pid).end[1]))] }
  dim.(3442727).text_position = Sketchup::DimensionLinear::TEXT_OUTSIDE_END    # 2"
  dim.(3442728).text_position = Sketchup::DimensionLinear::TEXT_OUTSIDE_START  # 4"
  dim.(3442723).text_position = Sketchup::DimensionLinear::TEXT_OUTSIDE_END    # 1"
  d = dim.(3442718); ov = d.offset_vector; ov.length = ov.length * 2.0; d.offset_vector = ov  # 11' 11 15/16"
  after = [3442718, 3442723, 3442727, 3442728].map { |pid| [pid, dim.(pid).text, Sketchup.format_length(dim.(pid).start[1].distance(dim.(pid).end[1]))] }
  raise "dim values moved: #{before.inspect} -> #{after.inspect}" unless before == after
  puts "dims (unchanged values): #{after.inspect}"
  m.commit_operation
rescue StandardError
  m.commit_operation  # never a blind abort: commit what landed, report, re-raise
  raise
ensure
  m.options['PageOptions']['ShowTransition'] = prev
  m.pages.selected_page = start if start
end
WalshRM.save(m)
m.pages.each { |q| c = q.camera; puts "  #{q.name.sub(pre, '')} | #{WR_ProposalPackage.mode_of(q)} | eye=#{c.eye.to_a.map(&:round)}" }
true
