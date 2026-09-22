# Photo-match shots of the current model. Reads PREFIX from $cms_prefix.
$wr_no_autorun = true
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/cms/room.rb'
WR_CMS.reload!
out = 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/cms/compare/'
prefix = ($cms_prefix || 'shot')
v = Sketchup.active_model.active_view
ro = Sketchup.active_model.rendering_options
res = []
# hide the room-dimension tag for the photo comparisons only; restored below
dl = Sketchup.active_model.layers['CMS Room Dims (EST)']
was = dl ? dl.visible? : nil
dl.visible = false if dl
{ 'A' => [1512, 2016], 'B' => [2016, 1512] }.each do |k, (w, h)|
  WR_CMS.match!(k.to_sym)
  f = "#{out}#{prefix}-#{k}.png"
  ok = v.write_image(filename: f, width: w, height: h, antialias: true, transparent: false)
  c = v.camera
  res << [k, ok, c.fov.round(2), c.aspect_ratio.round(4), c.fov_is_height? ]
end
dl.visible = was if dl
res
