sc = VRay::Context.active.scene
dump = lambda do |p|
  h = {}
  p.each { |k, v, *_| h[k] = (v.is_a?(Numeric) || v == true || v == false) ? v : (v.is_a?(VRay::Scene::Plugin) ? "plugin:#{v.name}" : v.inspect[0, 80]) }
  h
end
out = {}
sc.each { |p| out[p.name] = dump.(p) if p.type.to_s =~ /EnvironmentFog|VRayClipper|VolumeAerial|VolumeVRayToon|SettingsVFB|CosmosAsset/ }
out
