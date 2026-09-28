# Closes the leaf in every <door>_Open copy: each leaf gets back the exact
# transformation it has on the original door. The copies stay unique (so they can
# be opened by hand without touching the originals), stay where they are, and keep
# their scenes. Works inside the definitions, so any copy Benton made of an _Open
# door closes too. One undo step; verified by comparing bounds to the original.
load File.join(File.dirname(__FILE__), 'build.rb')
module DS
  def self.reset_open
    m = model!
    report = []
    m.start_operation('Close the Open doors', true)
    begin
      (STD + ENH).each do |n|
        enh = n.start_with?('ENH')
        copy = m.entities.select { |e| e.respond_to?(:definition) && e.name == "#{n}_Open" }
                 .min_by { |i| e = m.pages["#{n}_Open"].camera.eye; c = i.bounds.center; (c.x - e.x)**2 + (c.z - e.z)**2 }
        raise "#{n}_Open: copy not found" unless copy
        orig = top(m, n)
        cl = survey2(copy, enh)[:leaves]
        ol = survey2(orig, enh)[:leaves]
        raise "#{n}: #{cl.size} leaves in copy, #{ol.size} in original" unless cl.size == ol.size
        cl.zip(ol).each do |c, o|
          raise "#{n}: leaf mismatch #{c[-1].definition.name} / #{o[-1].definition.name}" unless c[-1].definition == o[-1].definition
          c[-1].transformation = o[-1].transformation
        end
        # verify each leaf against the original's (instance bounds only refresh on commit)
        err = cl.zip(ol).map do |c, o|
          x = wbox(c[-1], parent_world(copy, c)); y = wbox(o[-1], parent_world(orig, o))
          d = copy.transformation.origin - orig.transformation.origin
          [x.min.x - y.min.x - d.x, x.min.y - y.min.y - d.y, x.min.z - y.min.z - d.z,
           x.max.x - y.max.x - d.x, x.max.y - y.max.y - d.y].map { |v| v.to_f.abs }.max
        end.max
        raise "#{n}_Open: leaf still off by #{err.round(3)} in after closing" if err > 0.01
        report << "#{n}_Open: closed (#{cl.size} leaf part#{cl.size == 1 ? '' : 's'}), matches original"
      end
      m.commit_operation
    rescue Exception
      m.abort_operation
      raise
    end
    report
  end
end
puts DS.reset_open if $DS_RESET
$DS_RESET = false
