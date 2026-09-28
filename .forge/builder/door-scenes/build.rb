# Adds <door>_Open and <door>_NoDoor scenes to "Master Component List AM".
#
# Each new scene frames its OWN copy of the door, placed straight above the
# original (Open band +OPEN_DZ, NoDoor band +NODOOR_DZ), and made unique down to
# the leaf, so the original doors and their 28 scenes are untouched.
#   Open   : leaf (+ its lockset) rotated OPEN_DEG outward (toward the camera,
#            which looks at every door's exterior face) about the hinge line.
#   NoDoor : leaf (+ its lockset) erased; frame, hinges and jamb stay.
# Hinge line = the slab's hinge-side vertical edge on its exterior face. The
# hinge side comes from the frame hinges when there are any, else the side
# opposite the lockset (Enhanced IEP doors have no visible hinges).
#
# $DS_DRY = true  -> report only, change nothing.
load File.join(File.dirname(__FILE__), 'lib.rb')

module DS
  OPEN_DEG  = 110.0
  OPEN_DZ   = 20_000.0
  NODOOR_DZ = 40_000.0
  SLAB_STD  = /^(Std door \d+"\s+for .*|WA door(#\d+)?)$/
  SLAB_ENH  = /^(WA )?IEP door( \d+")?(#\d+)?$/
  FIXED     = /frame|jamb|^Hinge \(door frame\)|H - strip|IEP wall|HX/i

  def self.subtree_names(inst, acc = [])
    inst.definition.entities.each do |c|
      next unless c.respond_to?(:definition)
      acc << c.definition.name
      subtree_names(c, acc)
    end
    acc
  end

  # {leaves: [paths], slabs: [[path, parent_tw]], hinges: [box], locks: [box]}
  def self.survey2(root, enh)
    slabs = []; hinges = []; locks = []; all = []
    each_nested(root) do |path, tw|
      c = path[-1]; n = c.definition.name
      all << [path, tw]
      slabs  << [path, tw] if n =~ (enh ? SLAB_ENH : SLAB_STD)
      hinges << wbox(c, tw) if n =~ /^Hinge \(door frame\)/
      locks  << wbox(c, tw) if n =~ /^Lockset \((int|ext)\)/
    end
    leaves = []
    slabs.each do |sp, _|
      # shallowest ancestor-or-self of the slab that carries no fixed part
      k = (0...sp.size).find do |i|
        a = sp[i]
        a.definition.name !~ /^(Std door frame|WA door frame)|jamb/i &&
          subtree_names(a).none? { |x| x =~ FIXED && x !~ SLAB_STD && x !~ SLAB_ENH }
      end
      leaf = sp[0..k]
      leaves << leaf unless leaves.include?(leaf)
      # lockset pieces hung beside the leaf rather than inside it
      parent = leaf.size > 1 ? leaf[-2] : root
      parent.definition.entities.each do |s|
        next unless s.respond_to?(:definition) && s != leaf[-1]
        names = [s.definition.name] + subtree_names(s)
        next unless names.any? { |x| x =~ /Lockset/ } && names.none? { |x| x =~ FIXED && x !~ /DOOR AND DOOR FRAME ENHANCED/ }
        next if names.any? { |x| x =~ (enh ? SLAB_ENH : SLAB_STD) }
        lp = leaf[0..-2] + [s]
        leaves << lp unless leaves.include?(lp)
      end
    end
    { leaves: leaves, slabs: slabs, hinges: hinges, locks: locks }
  end

  def self.slab_box(slabs)
    b = Geom::BoundingBox.new
    slabs.each { |p, tw| b.add(wbox(p[-1], tw)) }
    b
  end

  # [pivot point, axis, signed angle in radians]
  def self.hinge(s, cam_dir)
    sb = slab_box(s[:slabs])
    cx = sb.center.x
    side = if s[:hinges].any?
             s[:hinges].map { |h| h.center.x }.sum / s[:hinges].size < cx ? :min : :max
           elsif s[:locks].any?
             s[:locks].map { |h| h.center.x }.sum / s[:locks].size > cx ? :min : :max
           else
             raise 'no hinges and no lockset: hinge side unknown'
           end
    px = side == :min ? sb.min.x : sb.max.x
    # exterior face = the face toward the camera
    py = cam_dir.y > 0 ? sb.min.y : sb.max.y
    pivot = Geom::Point3d.new(px, py, sb.min.z)
    axis = Geom::Vector3d.new(0, 0, 1)
    ang = OPEN_DEG.degrees
    [ang, -ang].each do |a|
      c = sb.center.transform(Geom::Transformation.rotation(pivot, axis, a))
      toward_cam = (c.y - py) * cam_dir.y < 0
      return [pivot, axis, a, side] if toward_cam
    end
    raise 'could not pick a swing direction'
  end

  def self.make_unique_to_leaves(copy, enh)
    copy.make_unique
    40.times do
      s = survey2(copy, enh)
      shared = s[:leaves].flat_map { |p| p[0..-2] }.find { |i| i.definition.instances.length > 1 }
      return s unless shared
      shared.make_unique
    end
    raise 'make_unique did not converge'
  end

  def self.parent_world(copy, leafpath)
    t = copy.transformation
    leafpath[0..-2].each { |i| t = t * i.transformation }
    t
  end

  def self.run(dry)
    m = model!
    report = []
    work = (STD + ENH).flat_map { |n| [[n, :open], [n, :nodoor]] }
    order = work.sort_by { |n, v| [v == :open ? 0 : 1, (STD + ENH).index(n)] }
    m.start_operation('Door Open / NoDoor scenes', true) unless dry
    tt = m.options['PageOptions']['TransitionTime']
    orig_page = m.pages.selected_page
    begin
      m.options['PageOptions']['TransitionTime'] = 0 unless dry
      order.each do |n, v|
        enh = n.start_with?('ENH')
        pname = "#{n}_#{v == :open ? 'Open' : 'NoDoor'}"
        if m.pages[pname]
          report << "#{pname}: scene already exists, skipped"
          next
        end
        orig = top(m, n)
        page = m.pages[n]
        cam_dir = page.camera.direction
        if dry
          s = survey2(orig, enh)
          pv, _, a, side = hinge(s, cam_dir)
          ob = orig.bounds.min
          report << format('%-28s leaves=%s hinge=%s pivot x%.1f y%.1f swing %+.0f deg',
                           pname, s[:leaves].map { |p| p[-1].definition.name }.inspect, side,
                           pv.x - ob.x, pv.y - ob.y, a.radians)
          next
        end
        off = Geom::Vector3d.new(0, 0, v == :open ? OPEN_DZ : NODOOR_DZ)
        copy = m.entities.add_instance(orig.definition, Geom::Transformation.translation(off) * orig.transformation)
        copy.layer = orig.layer
        copy.name = pname
        copy.set_attribute('wr_door_scene', 'variant', v.to_s)
        s = make_unique_to_leaves(copy, enh)
        raise "#{pname}: no leaf found" if s[:leaves].empty?
        if v == :open
          pv, ax, a, = hinge(s, cam_dir)
          rw = Geom::Transformation.rotation(pv, ax, a)
          s[:leaves].each do |lp|
            tp = parent_world(copy, lp)
            lp[-1].transformation = tp.inverse * rw * tp * lp[-1].transformation
          end
        else
          s[:leaves].each { |lp| lp[-1].erase! if lp[-1].valid? }
        end
        # scene: the original scene's settings, camera lifted with the copy
        m.pages.selected_page = page
        c = page.camera
        cam = Sketchup::Camera.new(c.eye.offset(off), c.target.offset(off), c.up, c.perspective?)
        if c.perspective? then cam.fov = c.fov else cam.height = c.height end
        m.active_view.camera = cam
        np = m.pages.add(pname)
        report << "#{pname}: added (#{s[:leaves].size} leaf part#{s[:leaves].size == 1 ? '' : 's'} #{v == :open ? 'rotated' : 'erased'})"
      end
      m.commit_operation unless dry
    rescue Exception => e
      m.abort_operation unless dry
      raise
    ensure
      unless dry
        m.options['PageOptions']['TransitionTime'] = tt
        m.pages.selected_page = orig_page if orig_page && orig_page.valid?
      end
    end
    report
  end
end

puts DS.run($DS_DRY != false) if $DS_GO
$DS_GO = false
