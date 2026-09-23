# Where every CMS light points (world normal of its emitting side, -Z of its own frame) and sits.
$wr_no_autorun = true
D = 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/'
load D + 'scripts/wr-drop-lights.rb' unless defined?(WR_DropLights)
load D + '.forge/builder/cms/lights.rb'
_, ls = WR_CMS_Lights.mine
ls.map { |i| n = Geom::Vector3d.new(0, 0, -1).transform(i.transformation); [i.get_attribute('wr_cms_lights', 'name'), i.transformation.origin.to_a.map { |v| v.to_f.round(1) }, n.to_a.map { |v| v.round(2) }] }
