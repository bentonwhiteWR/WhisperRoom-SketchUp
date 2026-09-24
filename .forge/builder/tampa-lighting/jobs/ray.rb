m = Sketchup.active_model
v = m.active_view
out = []
[[0.5, 0.5], [0.2, 0.2], [0.8, 0.8], [0.5, 0.1], [0.3, 0.7]].each do |fx, fy|
  x = v.vpwidth * fx; y = v.vpheight * fy
  ray = v.pickray(x, y)
  hit = m.raytest(ray, false)   # false = do not ignore hidden? (wysiwyg flag)
  hit2 = m.raytest(ray, true)
  f = ->(h) { h ? [h[0].to_a.map { |q| q.to_f.round(1) }, h[1].map { |e| e.respond_to?(:definition) ? (e.name.to_s.empty? ? e.definition.name : e.name) : e.class.name.split('::').last }] : nil }
  out << [[fx, fy], f.(hit), f.(hit2)]
end
out
