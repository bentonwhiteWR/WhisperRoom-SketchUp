# Give a converted SketchUp material a reflection layer by editing the V-Ray plugin JSON
# that V-Ray stores on the SketchUp material (dictionary VRayPlugins), then re-syncing.
# Usage: $hl_refl = { 'HL Paint Warm White' => [0.12, 0.45], ... }  (reflect grey, roughness)
require 'json'
m = Sketchup.active_model
out = {}
($hl_refl || {}).each do |name, (rv, rough)|
  mat = m.materials[name]
  next out[name] = 'no material' unless mat
  find = lambda { d = mat.attribute_dictionary('VRayPlugins'); d && d.keys.find { |k| k =~ %r{/(VRay Mtl|BRDFVRayMtl)\z} } }
  key = find.call
  if key.nil?
    VRay::MaterialSync.convert_to_vray(mat)
    key = find.call
  end
  next out[name] = 'no BRDF key' unless key
  j = JSON.parse(mat.get_attribute('VRayPlugins', key))
  j['params']['reflect'] = format('Color(%.3f,%.3f,%.3f)', rv, rv, rv)
  j['params']['reflect_glossiness'] = rough.to_s
  if j['userData'].is_a?(Hash)
    j['userData']['reflect_color'] = j['params']['reflect']
    j['userData']['reflect_glossiness_float'] = rough.to_s
  end
  mat.set_attribute('VRayPlugins', key, JSON.generate(j))
  r = (VRay::MaterialSync.to_vray(mat) rescue "to_vray: #{$!.message}")
  b = VRay::Context.active.scene[key]
  out[name] = [key, r.to_s[0, 40], b && b[:reflect].to_s, b && b[:reflect_glossiness]]
end
$hl_out = out
