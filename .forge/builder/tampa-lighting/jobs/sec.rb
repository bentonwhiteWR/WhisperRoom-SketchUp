m = Sketchup.active_model
res = []
walk = lambda do |ents, path, tr|
  ents.each do |e|
    if e.is_a?(Sketchup::SectionPlane)
      pl = e.get_plane
      res << { 'path' => path, 'name' => e.name, 'active' => e.active?, 'hidden' => e.hidden?, 'layer' => e.layer.name,
               'plane' => pl.map { |v| v.to_f.round(2) }, 'world_origin' => tr.origin.to_a.map { |v| v.to_f.round(1) } }
    elsif e.respond_to?(:definition)
      walk.call(e.definition.entities, path + '/' + (e.name.to_s.empty? ? e.definition.name : e.name), tr * e.transformation) if path.count('/') < 6
    end
  end
end
walk.call(m.entities, '', Geom::Transformation.new)
ro = m.rendering_options
{ 'sections' => res.uniq { |r| [r['path'], r['name']] }, 'display_section_cuts' => ro['DisplaySectionCuts'], 'display_section_planes' => ro['DisplaySectionPlanes'],
  'pages_use_section' => m.pages.map { |p| [p.name, (p.use_section_planes? rescue nil)] } }
