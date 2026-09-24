r = VRay::Context.active.renderer
c = ->(v) { v.respond_to?(:r) ? [v.r, v.g, v.b].map { |x| x.round(2) } : (v.is_a?(Numeric) ? v.round(3) : v.inspect[0, 40]) }
o = []
r.each do |p|
  next unless p.type.to_s == 'BRDFVRayMtl'
  o << [p.name[0, 60], c.(p[:diffuse]), c.(p[:reflect]), c.(p[:reflect_glossiness]), c.(p[:refract]), c.(p[:refract_glossiness]), c.(p[:opacity]), c.(p[:self_illumination]), (p[:opacity_source] rescue nil)]
end
o
