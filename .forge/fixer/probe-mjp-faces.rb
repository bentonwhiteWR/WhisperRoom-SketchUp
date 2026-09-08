# probe-mjp-faces.rb — which face of MJP.skp carries the jack field, and which
# way the placed boxes are pointing in the open model.
#
# NOT A TOOL. Run from Extensions > Developer > Ruby Console:
#   load "C:/Users/bento/Documents/Claude/Sketchup/.forge/fixer/probe-mjp-faces.rb"
# Read-only: it adds nothing, moves nothing. Paste the console output back.
#
# Part 1 reads MJP.skp straight off the P: library (definition space).
#   - z range, and the horizontal-face band = the jack box; anything below the
#     band is the two cable tails. Confirms +Z is up with the box on top.
#   - For the two Y-extreme planes (y = min and y = max, the two 8.75 x ~7 faces
#     of the box) it counts faces and lists materials. A jack FIELD is many small
#     faces (XLR rings, 1/4in holes, USB slots) on ONE plane; the closed back
#     is one or two big faces. Whichever Y sign is busy is the jack side.
# Part 2 finds every instance named 'MJP interior …' / 'MJP exterior …' in the
#   active model and prints where its definition +X / +Y / +Z point in world,
#   so the chain in .forge/fixer/mjp-transform-repro.py can be checked against
#   the live booth rather than believed.

module WR_ProbeMJP
  LIB = 'P:/Sketchup/NewMasterComponentList'

  def self.each_face(ents, tr, depth = 0, &blk)
    return if depth > 8
    ents.each do |e|
      case e
      when Sketchup::Face
        blk.call(e, tr)
      when Sketchup::ComponentInstance
        each_face(e.definition.entities, tr * e.transformation, depth + 1, &blk)
      when Sketchup::Group
        each_face(e.entities, tr * e.transformation, depth + 1, &blk)
      end
    end
  end

  def self.axis_name(v)
    x = v.x.to_f
    y = v.y.to_f
    z = v.z.to_f
    return format('%+.2f %+.2f %+.2f', x, y, z) unless [x, y, z].count { |c| c.abs > 0.99 } == 1
    return(x > 0 ? '+X' : '-X') if x.abs > 0.99
    return(y > 0 ? '+Y' : '-Y') if y.abs > 0.99
    z > 0 ? '+Z (UP)' : '-Z (DOWN)'
  end

  def self.part
    model = Sketchup.active_model
    path = File.join(LIB, 'MJP.skp')
    unless File.exist?(path)
      puts "  #{path} not reachable from this machine"
      return
    end
    defn = model.definitions.load(path)
    bb = defn.bounds
    puts format('  MJP.skp bounds  x %.4f..%.4f  y %.4f..%.4f  z %.4f..%.4f',
                bb.min.x.to_f, bb.max.x.to_f, bb.min.y.to_f, bb.max.y.to_f,
                bb.min.z.to_f, bb.max.z.to_f)

    up = Geom::Vector3d.new(0, 0, 1)
    levels = Hash.new(0.0)
    ymin = { :n => 0, :area => 0.0, :mats => Hash.new(0) }
    ymax = { :n => 0, :area => 0.0, :mats => Hash.new(0) }
    tol = 0.05
    each_face(defn.entities, Geom::Transformation.new) do |f, tr|
      n = f.normal.transform(tr)
      n.normalize!
      p0 = f.vertices.first.position.transform(tr)
      a = f.area.to_f
      levels[(p0.z.to_f * 8).round / 8.0] += a if n.dot(up).abs > 0.98
      next unless n.y.abs > 0.98
      side = (p0.y.to_f - bb.min.y.to_f).abs < tol ? ymin :
             ((p0.y.to_f - bb.max.y.to_f).abs < tol ? ymax : nil)
      next if side.nil?
      side[:n] += 1
      side[:area] += a
      m = f.material || f.back_material
      side[:mats][m ? m.display_name : '(none)'] += 1
    end

    puts '  horizontal-face levels (definition z, sq in) — the band is the BOX:'
    levels.sort.reverse.each { |z, a| puts format('     z %8.3f   %8.2f', z, a) if a > 0.2 }
    puts '  the two Y-extreme planes (the box faces). The busy one is the JACK FIELD:'
    [['y = MIN (def -Y side)', ymin], ['y = MAX (def +Y side)', ymax]].each do |lab, s|
      puts format('     %-24s %4d faces  %8.2f sq in  materials: %s', lab, s[:n], s[:area],
                  s[:mats].sort_by { |_k, v| -v }.map { |k, v| "#{k} x#{v}" }.join(', '))
    end
    puts '  FACE_ROOM[:mjp] = +1 points def +Y INTO the room. If the jack field is on'
    puts '  the y = MIN plane, +1 is backwards and the constant wants -1.'
  end

  def self.placed
    model = Sketchup.active_model
    found = 0
    model.definitions.each do |d|
      d.instances.each do |inst|
        nm = inst.name.to_s
        next unless nm =~ /\AMJP (interior|exterior)/
        found += 1
        t = inst.transformation
        wb = inst.bounds
        puts format('  %-24s def+X -> %-10s def+Y -> %-10s def+Z -> %-10s  world z %.2f..%.2f',
                    nm, axis_name(t.xaxis), axis_name(t.yaxis), axis_name(t.zaxis),
                    wb.min.z.to_f, wb.max.z.to_f)
      end
    end
    puts '  (no placed MJP instance in this model)' if found.zero?
    puts '  Expected when RIGHT: def+Z -> +Z (UP), box top near 29.07 (booth-local).'
    puts '  Shipped 1.19.2 gives def+Z -> -Z (DOWN) and the box at 10.69..18.06.'
  end

  def self.run
    puts ''
    puts '=' * 72
    puts 'PROBE MJP — part faces, then the placed boxes'
    puts '=' * 72
    puts '-- MJP.skp, definition space --'
    part
    puts '-- placed instances in the active model --'
    placed
    puts ''
  end
end

begin
  WR_ProbeMJP.run
rescue StandardError => e
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(6).map { |l| "  #{l}" }.join("\n")
end
