# Where a placed wall part's FACES actually land, across the wall.
#
# The booth-matrix manifest records slot fit, facing and along-wall stations.
# It does NOT record the across-wall (thickness) position, so a room-proud
# change moves real geometry and leaves the manifest byte-identical - which is
# exactly what happened on the 2026-08-30 inner-window fix. This is the probe
# that saw it. Run it through the bridge on a model holding a built booth:
#
#   python scripts/sketchup-bridge.py --su 2026 run .forge/fixer/probe-wall-face-levels.rb
#
# It prints, for each named instance, the world-x level of every face parallel
# to the wall and that face's area - so a panel slab, its H strip and any trim
# ring standing proud of it are separate, readable numbers. Compare a window
# against the solid panel beside it and the two must agree face for face.
# Edit `want` for a different wall; x is hard-coded because the W wall runs y.

m = Sketchup.active_model
want = %w[W1 W1i W0 W0i]
found = {}
walk = lambda do |ents, tr|
  ents.each do |e|
    if e.is_a?(Sketchup::ComponentInstance)
      nm = e.name.to_s.split(/\s{2,}/).first.to_s.strip
      if want.include?(nm) && !found.key?(nm)
        found[nm] = [e, tr * e.transformation]
      end
      walk.call(e.definition.entities, tr * e.transformation) unless found.key?(nm)
    elsif e.is_a?(Sketchup::Group)
      walk.call(e.entities, tr * e.transformation)
    end
  end
end
walk.call(m.entities, Geom::Transformation.new)
want.each do |nm|
  unless found[nm]
    puts "#{nm}: NOT FOUND"; next
  end
  inst, tr = found[nm]
  levels = Hash.new(0.0)
  w2 = lambda do |ents, t|
    ents.each do |e|
      if e.is_a?(Sketchup::ComponentInstance) then w2.call(e.definition.entities, t * e.transformation)
      elsif e.is_a?(Sketchup::Group) then w2.call(e.entities, t * e.transformation)
      elsif e.is_a?(Sketchup::Face)
        xs = e.outer_loop.vertices.map { |v| v.position.transform(t).x.to_f }
        next if (xs.max - xs.min) > 0.001
        levels[(xs.min * 10000).round / 10000.0] += e.area
      end
    end
  end
  w2.call(inst.definition.entities, tr)
  puts format("\n%-6s %-26s  world-x levels of wall-parallel faces", nm, inst.definition.name)
  levels.sort.each { |lv, a| puts format('    x = %8.4f    %9.2f sq in', lv, a) }
end
nil
