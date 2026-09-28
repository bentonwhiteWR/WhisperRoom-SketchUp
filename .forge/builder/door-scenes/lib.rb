# Shared helpers for the door _Open / _NoDoor scenes in "Master Component List AM".
module DS
  remove_const(:STD) if const_defined?(:STD, false)
  remove_const(:ENH) if const_defined?(:ENH, false)
  remove_const(:TITLE) if const_defined?(:TITLE, false)
  STD = %w[Left40Door Right40Door Left46Door Right46Door LeftWADoor RightWADoor
           Left40Door_HX Right40Door_HX Left46Door_HX Right46Door_HX LeftWADoor_HX RightWADoor_HX
           LeftWADoorWithRamp RightWADoorWithRamp LeftWADoorWithRamp_HX RightWADoorWithRamp_HX]
  ENH = ["ENH Left35.5Door","ENH Right35.5Door","ENH Left41.5Door","ENH Right41.5Door",
         "ENH LeftWADoor","ENH RightWADoor","ENH Left35.5Door_HX","ENH Right35.5Door_HX",
         "ENH Left41.5Door_HX","ENH Right41.5Door_HX","ENH LeftWADoor_HX","ENH RightWADoor_HX"]
  TITLE = 'Master Component List AM'
  def self.model!
    m = Sketchup.active_model
    raise "Wrong model in front: #{m.title.inspect} -- bring #{TITLE} to the front" unless m.title == TITLE
    m
  end
  def self.top(m, n)
    a = m.entities.select { |e| e.respond_to?(:definition) && e.definition.name == n }
    raise "#{n}: no top-level instance" if a.empty?
    # Several copies: take the one the scene's camera is aimed at (x,z nearest the eye line).
    e = m.pages[n].camera.eye
    a.min_by { |i| c = i.bounds.center; (c.x - e.x)**2 + (c.z - e.z)**2 }
  end
  def self.wbox(inst, tw)
    b = Geom::BoundingBox.new
    inst.definition.entities.each { |x| b.add(x.bounds) }
    t = tw * inst.transformation
    w = Geom::BoundingBox.new
    8.times { |i| w.add(b.corner(i).transform(t)) }
    w
  end
  # Every nested instance as [path(array of instances, root excluded), parent world transform]
  def self.each_nested(root, &blk)
    rec = lambda do |inst, tw, path|
      inst.definition.entities.each do |c|
        next unless c.respond_to?(:definition)
        blk.call(path + [c], tw)
        rec.call(c, tw * c.transformation, path + [c])
      end
    end
    rec.call(root, root.transformation, [])
  end
  # Returns {leaves: [paths], slab: path, hinges: [world boxes], locks: [world boxes]}
  def self.survey(root, enh)
    leaves = []; slab = nil; hinges = []; locks = []
    each_nested(root) do |path, tw|
      c = path[-1]; n = c.definition.name
      inside_leaf = leaves.any? { |l| path[0, l.size] == l && path.size > l.size }
      if enh
        if n =~ /^(WA )?IEP door/ && !inside_leaf
          leaves << path; slab ||= [path, tw]
          # the 35.5/41.5 IEP keeps its lockset in a sibling wrapper
          path[-2 .. -2] # noop
          sibs = (path.size > 1 ? path[-2].definition.entities : root.definition.entities)
          sibs.each { |s| leaves << (path[0..-2] + [s]) if s.respond_to?(:definition) && s.definition.name =~ /^DOOR AND DOOR FRAME ENHANCED/ && wbox(s, tw).width < 12 }
        end
      else
        if n =~ /with lockset/ && !inside_leaf && wbox(c, tw).width > 15
          leaves << path
        end
        slab ||= [path, tw] if n =~ /^(Std door \d+" for|WA door#)/
      end
      hinges << wbox(c, tw) if n =~ /^Hinge \(door frame\)/
      locks  << wbox(c, tw) if n =~ /^Lockset \((int|ext)\)/
    end
    { leaves: leaves, slab: slab, hinges: hinges, locks: locks }
  end
end
