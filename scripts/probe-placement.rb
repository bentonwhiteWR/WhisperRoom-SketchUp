# @title Probe placement of what's selected...
# @cat Build the booth
# @rank 9
#
# Assemble something correctly by hand, select it, run this. It writes down
# exactly where every component sits and how it is turned, so a build script can
# be made to reproduce it.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/probe-placement.rb"
#
# WHY THIS EXISTS
#
# A .skp cannot be read outside SketchUp. Handing one over is handing over a
# file nobody at the other end can open, and a screenshot only shows that
# something is wrong, never by how much. This turns a correct assembly into
# numbers: definition name, origin, the three axes, the yaw, whether the
# instance is mirrored, the bounding box, and - the part that actually settles
# arguments - the GAP between each part and the one before it along the run.
#
# "Flush" is a number. This is the number.
#
# It writes a TSV beside the component library and prints the same table to the
# console. Either can be read by someone who is not sitting at SketchUp.

require 'sketchup.rb'

load File.join(File.dirname(__FILE__), 'wr-folder.rb')

module WR_ProbePlacement
  OUT = '_placement-probe.tsv'.freeze

  # Every top-level component instance in the selection. A group that contains
  # instances is walked one level, because a booth build puts its parts inside a
  # group and selecting the group is the obvious thing to do.
  def self.instances(sel)
    out = []
    sel.each do |e|
      if e.is_a?(Sketchup::ComponentInstance)
        out << e
      elsif e.is_a?(Sketchup::Group)
        e.entities.each { |c| out << c if c.is_a?(Sketchup::ComponentInstance) }
      end
    end
    out
  end

  def self.f(v)
    format('%.4f', v.to_f)
  end

  # Yaw about the vertical, in degrees, from the instance's own X axis. 0 means
  # the definition's X still points along the model's X.
  def self.yaw(tr)
    x = tr.xaxis
    d = Math.atan2(x.y.to_f, x.x.to_f) * 180.0 / Math::PI
    d += 360.0 while d < -0.0001
    d -= 360.0 while d > 359.9999
    d
  end

  # A mirrored instance has a left-handed axis triple. Worth knowing: a mirror
  # and a half turn look identical on a symmetric part and are completely
  # different on a door.
  def self.mirrored?(tr)
    x = tr.xaxis
    y = tr.yaxis
    z = tr.zaxis
    det = x.x.to_f * (y.y.to_f * z.z.to_f - y.z.to_f * z.y.to_f) -
          x.y.to_f * (y.x.to_f * z.z.to_f - y.z.to_f * z.x.to_f) +
          x.z.to_f * (y.y.to_f * z.x.to_f - y.x.to_f * z.y.to_f)
    det < 0
  end

  def self.run
    model = Sketchup.active_model
    sel = model.selection
    list = instances(sel)
    if list.empty?
      UI.messagebox("Nothing to probe.\n\nSelect the assembled parts — or the " \
                    'group holding them — and run this again.')
      return
    end

    # A datum, so the numbers do not depend on where in the model it was built.
    all = Geom::BoundingBox.new
    list.each { |i| all.add(i.bounds) }
    ox = all.min.x.to_f
    oy = all.min.y.to_f
    oz = all.min.z.to_f

    rows = list.map do |i|
      tr = i.transformation
      b = i.bounds
      { :name => (i.name.to_s.empty? ? '(unnamed)' : i.name.to_s),
        :defn => i.definition.name.to_s,
        :tr => tr, :b => b,
        :x0 => b.min.x.to_f - ox, :y0 => b.min.y.to_f - oy, :z0 => b.min.z.to_f - oz,
        :x1 => b.max.x.to_f - ox, :y1 => b.max.y.to_f - oy, :z1 => b.max.z.to_f - oz }
    end

    span_x = all.max.x.to_f - ox
    span_y = all.max.y.to_f - oy
    run_x = span_x >= span_y
    rows.sort_by! { |r| run_x ? r[:x0] : r[:y0] }

    puts ''
    puts '=' * 100
    puts "PLACEMENT PROBE — #{rows.length} instance(s)"
    puts format('  selection spans %s x %s x %s in, measured from its own low corner',
                f(span_x), f(span_y), f(all.max.z.to_f - oz))
    puts format('  walking the %s axis, which is the longer one', run_x ? 'X' : 'Y')
    puts '=' * 100
    puts format('  %-22s %-26s %8s %8s %8s %8s %7s %5s',
                'NAME', 'DEFINITION', 'X0', 'Y0', 'Z0', 'RUN', 'YAW', 'MIRR')
    prev_end = nil
    rows.each do |r|
      run_len = run_x ? (r[:x1] - r[:x0]) : (r[:y1] - r[:y0])
      puts format('  %-22s %-26s %8s %8s %8s %8s %7.2f %5s',
                  r[:name][0, 22], r[:defn][0, 26],
                  f(r[:x0]), f(r[:y0]), f(r[:z0]), f(run_len),
                  yaw(r[:tr]), mirrored?(r[:tr]) ? 'YES' : '')
      here = run_x ? r[:x0] : r[:y0]
      unless prev_end.nil?
        gap = here - prev_end
        puts format('  %-22s   gap to the part before it: %s in%s', '', f(gap),
                    gap.abs < 0.0005 ? '   <- flush' : '')
      end
      prev_end = run_x ? r[:x1] : r[:y1]
    end

    tsv = ["name\tdefinition\tx0\ty0\tz0\tx1\ty1\tz1\tyaw\tmirrored\t" \
           "origin_x\torigin_y\torigin_z\t" \
           "xaxis\tyaxis\tzaxis\tgap_before"]
    prev_end = nil
    rows.each do |r|
      tr = r[:tr]
      here = run_x ? r[:x0] : r[:y0]
      gap = prev_end.nil? ? '' : f(here - prev_end)
      prev_end = run_x ? r[:x1] : r[:y1]
      v = lambda { |a| "#{f(a.x)},#{f(a.y)},#{f(a.z)}" }
      tsv << [r[:name], r[:defn],
              f(r[:x0]), f(r[:y0]), f(r[:z0]), f(r[:x1]), f(r[:y1]), f(r[:z1]),
              format('%.3f', yaw(tr)), mirrored?(tr) ? '1' : '0',
              f(tr.origin.x), f(tr.origin.y), f(tr.origin.z),
              v.call(tr.xaxis), v.call(tr.yaxis), v.call(tr.zaxis),
              gap].join("\t")
    end

    dir, = WR_Folder.field('parts', 'P:/Sketchup/NewMasterComponentList')
    path = File.join(dir.to_s, OUT)
    written = begin
      File.open(path, 'w') { |fh| fh.puts(tsv.join("\n")) }
      true
    rescue StandardError => e
      puts "  could not write #{path}: #{e.message}"
      false
    end

    puts ''
    if written
      puts "  wrote #{path}"
      puts '  That file is the answer — it can be read without SketchUp.'
    else
      puts '  Copy the table above instead; it carries the same numbers.'
    end
    puts '=' * 100
    puts ''
  end
end

begin
  WR_ProbePlacement.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Placement probe failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console.')
end
