d = 'P:/Sketchup/NewMasterComponentList'
m = Sketchup.active_model
%w[SL29 SL52 HEPA Audimute2x4 Audimute1x4 Audimute1x2].push('Bass Trap').each do |n|
  df = m.definitions.load(File.join(d, n + '.skp'))
  b = df.bounds
  kids = df.entities.grep(Sketchup::ComponentInstance).map { |i| i.definition.name }.tally
  puts format('%-12s  W %.3f  D %.3f  H %.3f   min(%.2f,%.2f,%.2f)  axes-in-%s  kids=%s', n,
              b.width.to_f, b.height.to_f, b.depth.to_f, b.min.x.to_f, b.min.y.to_f, b.min.z.to_f,
              df.behavior.is2d? ? 'glue' : '3d', kids.inspect)
end
nil
