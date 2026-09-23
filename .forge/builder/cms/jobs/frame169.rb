# Every package-marked scene written at 16:9 (1600x900) exactly as a click shows it, light widgets hidden
# (restored in an ensure). $cms_dir = out dir. For the framing check only.
m = Sketchup.active_model
v = m.active_view
m.options['PageOptions']['TransitionTime'] = 0.0
lights = m.entities.select { |e| e.get_attribute('wr_cms_lights', 'plugin') }
sel = m.pages.selected_page
res = []
begin
  lights.each { |e| e.hidden = true }
  m.pages.each_with_index do |pg, i|
    mode = pg.get_attribute('WR_ProposalPackage', 'mode')
    next unless %w[render image].include?(mode)
    m.pages.selected_page = pg
    v.refresh
    f = File.join($cms_dir, format('%02d-%s.png', i, pg.name.gsub(/[^A-Za-z0-9 ._-]/, '_')))
    res << [pg.name, mode, v.write_image(filename: f, width: 1600, height: 900, antialias: true, transparent: true)]
  end
ensure
  lights.each { |e| e.hidden = false }
  m.pages.selected_page = sel if sel
end
res
