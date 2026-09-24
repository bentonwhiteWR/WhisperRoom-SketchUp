r = VRay::Context.active.renderer
t = Hash.new(0)
names = []
r.each { |p| t[p.type.to_s] += 1 rescue nil; names << [p.name, p.type.to_s] if p.type.to_s =~ /RenderView|Clipper|Light|Camera|Fog|Volume|Env/ }
rv = r['/RenderView'] rescue nil
tf = rv ? rv[:transform].to_a.flatten.map { |v| v.is_a?(Numeric) ? v.round(2) : v.to_a.map { |x| x.round(2) } } : nil
nodes = []
r.each { |p| next unless p.type.to_s == 'Node'; nodes << p.name }
{ 'mode' => (r.render_mode rescue nil).to_s, 'keep_int' => (r.keep_interactive_running? rescue nil), 'types' => t.sort_by { |k, v| -v }.first(40).to_h,
  'rv_tf' => tf, 'rv_fov' => (rv[:fov] rescue nil), 'rv_ortho' => (rv[:orthographic] rescue nil), 'rv_clip' => [(rv[:clipping] rescue nil), (rv[:clipping_near] rescue nil)],
  'named' => names.first(80), 'n_nodes' => nodes.size, 'node_sample' => nodes.first(15) }
