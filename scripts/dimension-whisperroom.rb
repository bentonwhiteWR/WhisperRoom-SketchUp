# @title Dimension a WhisperRoom
# @cat Add dimensions
# @rank 1
# @icon dim-booth
#
# Click a WhisperRoom: its three exterior dimensions appear, measured off the
# built parts and attached to the booth's real corners. Nothing else — no
# label, no dialog, no settings. Esc cancels the pick.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/dimension-whisperroom.rb"
#
# Benton, 10 Sep 2026: "I still dont like the way our 'dimension tool' works at
# all for the whisperroom. Lets essentially start from scratch. I want to be
# able to click a whisperroom, and then all the dimensions show up."
#
# Spec: .forge/scoper/booth-dimensions-spec.md (rev 2). This file replaces
# dimension-booth.rb, which is shelved (# @shelf archive) for one release.
#
# ============================================================================
# THE THREE STRINGS, AND WHERE THE NUMBERS COME FROM
#
#   width    along the door wall's ground edge
#   depth    along one side wall's ground edge
#   height   up the far corner of that side wall, pushed out to the side
#
# EVERY ONE IS MEASURED OFF THE BUILT PARTS. The old tool drew catalogue
# numbers at bare points computed from the group origin, so its witness lines
# landed on the geometry only when the catalogue, the 5.5 in vent rule and a
# BASE_Z constant all happened to agree with the build — and on an Enhanced
# booth they did not (the height string floated 5/16 in at both ends). Here
# the footprint is the union of the outer-shell wall panels, the vent housings
# and the corner seals; the height runs from the floor stack's underside to
# the ceiling's top. Whatever that measures is what the dimension reads,
# because that is what SketchUp prints on it.
#
# THE CATALOGUE IS A CROSS-CHECK, NEVER DRAWN. wr-booth-data.rb's :w/:h plus
# 5.5 in per vented face, and 83.0 / 84.3125 in for Standard / Enhanced, are
# printed beside the measured figures on every run. Any axis more than 1/4 in
# apart gets a *** block naming the axis, both numbers and the part that set
# the measured one. The dimension still reads the measured value — a vent
# housing seated 6 7/16 in proud is a builder bug to fix in the builder, not a
# number for a dimension to paper over (coordinator, 10 Sep 2026: "the
# dimension reads what is DRAWN, always").
#
# ATTACHMENT. Each endpoint is a ConstructionPoint on WR-Dims-Booth at the
# corner, and the dimension is attached to it, so the witness line starts on
# a real entity that owns its position. That is the 1.17.0 door-jamb
# precedent from auto-dimension.rb. The nicer answer — attaching straight to
# a vertex inside the wall part through a Sketchup::InstancePath — is written
# (attach_vertex) but OFF: the 2019 overload of add_dimension_linear that
# takes nested paths has never been exercised in this repo, the bridge was
# not listening when this was built, and a misremembered overload would
# either raise (harmless) or land a witness line somewhere plausible and
# wrong (not harmless). ATTACH_NESTED_VERTICES flips it on once someone has
# watched it work; the code post-checks every endpoint against the intended
# corner either way. A point that cannot be attached at all falls back to a
# bare Point3d, is counted as `loose`, and the run reports it as a defect.
#
# THE CORNER. The set lives at one of the booth's four corners — FR, FL, RL,
# RR, named from outside facing the door wall — and everything else follows
# from that one choice: the two ground strings run along the two ground edges
# leaving the corner, the height stands at the far end of the side-wall edge,
# pushed out on that side. The corner is stored ON THE BOOTH GROUP
# (WR_BoothDims/corner), so a re-run redraws where the set was, and rotating
# booth 1 never touches booth 2. rotate-whisperroom-dimensions.rb advances it
# FR -> FL -> RL -> RR -> FR — the first press always goes to the other side,
# which is the case Benton named ("sometimes they will need to be on left
# side depending on where we need to get the image of"). ROTATE rebuilds; it
# never transforms an entity, so the set cannot drift off the geometry.
#
# OWNERSHIP. Every entity drawn carries WR_BoothDims/booth = the booth's
# persistent_id and WR_BoothDims/own = true, on tag WR-Dims-Booth. A re-run
# on a booth erases only that booth's set. clear-whisperroom-dimensions.rb
# removes one booth's set, or with Esc every set, and never anything else on
# the tag — a hand-drawn dimension someone put on WR-Dims-Booth survives.
#
# THE TAG NAME IS LOAD-BEARING. proposal-scenes.rb (DIM_TAGS,
# SHOWN_ON_DIMENSIONED), the per-scene ANNOTATIONS picker and the proposal
# package's client-safe pass all know WR-Dims-Booth. Keep it. The tag is
# coloured dark grey rather than the old brand orange: a tag colour only shows
# under Color-by-Tag, the dimensions themselves draw in the model's dimension
# colour (Model Info > Dimensions, or wr-callout-style.rb), and orange on the
# tag only ever confused the question of why the strings came out black.

require 'sketchup.rb'

module WR_BoothDims
  TAG  = 'WR-Dims-Booth'.freeze
  DICT = 'WR_BoothDims'.freeze
  # The retired tool's attribute dictionary. Its entities are swept by the
  # Clear tool so the archive can be deleted next release.
  OLD_DICT = 'WR_DimBooth'.freeze
  DATA = File.join(File.dirname(__FILE__), 'wr-booth-data.rb')

  # See the header: OFF until the InstancePath overload has been watched
  # working on the bridge. With it off every endpoint is a ConstructionPoint.
  ATTACH_NESTED_VERTICES = false

  # ==========================================================================
  # PURE SECTION — no SketchUp API from here to END PURE. rbtest-boothdims.py
  # lifts this block verbatim and runs it in the CRuby VM rbparse.py boots,
  # which has no Float#to_f: write `x * 1.0`, never `.to_f`, in here.
  # ==========================================================================

  # Standoffs, in inches. 24 on the two ground strings (coordinator, Q6);
  # the height shares a corner with the depth string and must clear its end,
  # so it goes out 36. Not settings — a standoff dial was asked about and
  # declined for this build.
  GAP      = 24.0
  GAP_RISE = 36.0

  # How far measured and catalogue may disagree before the run says so.
  CAT_TOL = 0.25

  # How far a vented face stands proud of the catalogue box, no EFS. Benton's
  # figure, confirmed against the 96120 render. Cross-check only, never drawn.
  VENT_PROUD = 5.5

  # Exterior heights by key suffix, for the cross-check only. Standard: floor
  # underside -1.0 to ceiling top 82.0. Enhanced: IEP mat underside -1.3125
  # to tray top 83.0. Derived from the builder's datums (spec §1).
  HEIGHT_STD = 83.0
  HEIGHT_ENH = 84.3125

  # The rotation order. First press from the default always lands on the
  # other side of the booth.
  CORNERS = %w[FR FL RL RR].freeze

  # Part naming, as build-booth-components.rb writes it: "N0  46VNT",
  # "S0  Right46Door", "SW corner seal", "STD9648FL SIDE", "FLi  ENH 9648FL".
  WALL_RE    = /\A([NSEW])\d+\s/.freeze
  DOOR_RE    = /Door/i.freeze
  CORNER_RE  = /corner seal/i.freeze
  FLOOR_RE   = /\A(?:(?:STD|ENH)\s*\d{2,3}\d{2}\s*FL|FLi\s)/i.freeze
  CEIL_RE    = /\A(?:(?:STD|ENH)\s*\d{2,3}\d{2}\s*CL|CLi\s)/i.freeze
  # Overlays and placeholders that sit in the booth group but are not the
  # booth: never vote. The inner IEP shell ("N0i  ENH 41.5VNT") fails WALL_RE
  # on its own — \d+ then \s, and the i is in the way — and mid-wall seals
  # ("N-seal0") never matched it. Both are excluded by construction.
  EXCLUDE_RE = /\AMISSING|roof unit|caster plate|elevated floor|\AEFP\d/i.freeze
  CASTER_RE  = /caster plate/i.freeze
  VENT_RE    = /v(?:e)?nt/i.freeze

  # Identification, kept from dimension-booth.rb so the cross-check finds
  # the catalogue entry the same way the proposal package finds a booth.
  NAME_RE = /\bMDL\b|\b\d{3,6}\s?[SE]\b/.freeze

  # What a child contributes, by name. :wall and :corner vote on the
  # footprint, :floor on the bottom, :ceiling on the top; nil votes nowhere.
  # A door is a wall part whose swung leaf and ramp live inside the same
  # component, so it is out — its frame face is coplanar with its neighbours
  # and nothing is lost.
  def self.classify(name)
    n = name.to_s
    return nil if n.empty? || n =~ EXCLUDE_RE
    return :floor   if n =~ FLOOR_RE
    return :ceiling if n =~ CEIL_RE
    return :corner  if n =~ CORNER_RE
    return nil      if n =~ DOOR_RE
    return :wall    if n =~ WALL_RE
    nil
  end

  # The wall letter carrying the door, or nil. First door wins.
  def self.door_wall(names)
    names.each do |n|
      m = WALL_RE.match(n.to_s)
      return m[1] if m && n.to_s =~ DOOR_RE
    end
    nil
  end

  # The vented faces read off the placed parts — the same rule the old tool
  # used, kept verbatim: "46NV" is a blank, VNT and Vent match, NV does not.
  def self.vents_from_names(names)
    faces = []
    efs = false
    names.each do |n|
      m = WALL_RE.match(n.to_s)
      next if m.nil? || n.to_s !~ VENT_RE
      efs = true if n.to_s =~ /EFS/i
      faces << m[1] unless faces.include?(m[1])
    end
    [faces.sort, efs]
  end

  def self.booth_name?(name)
    !(name.to_s =~ NAME_RE).nil?
  end

  # The extent, from a list of [name, [x0, y0, z0, x1, y1, z1]] in the
  # booth's own frame. Returns nil when nothing votes on the footprint (the
  # caller falls back to the group bounds and says so). Every side records
  # which part set it, because "E extent 128.44 set by E0 46VNT" is what
  # turns a mismatch into a fix.
  def self.extent_from_parts(parts)
    ext = nil
    parts.each do |name, b|
      kind = classify(name)
      next unless kind == :wall || kind == :corner
      if ext.nil?
        ext = { :x0 => b[0], :y0 => b[1], :x1 => b[3], :y1 => b[4],
                :x0_by => name, :y0_by => name, :x1_by => name, :y1_by => name,
                :z0 => nil, :z1 => nil, :z0_by => nil, :z1_by => nil,
                :walls => 0, :mode => :parts }
      else
        if b[0] < ext[:x0] then ext[:x0] = b[0]; ext[:x0_by] = name; end
        if b[1] < ext[:y0] then ext[:y0] = b[1]; ext[:y0_by] = name; end
        if b[3] > ext[:x1] then ext[:x1] = b[3]; ext[:x1_by] = name; end
        if b[4] > ext[:y1] then ext[:y1] = b[4]; ext[:y1_by] = name; end
      end
      ext[:walls] += 1
    end
    return nil if ext.nil?

    # Height: floor parts for the bottom, ceiling parts for the top. Walls
    # are out on purpose — a 46VNT box is 81.86 tall and a VSS 82.17, both
    # taller than a Standard ceiling top.
    parts.each do |name, b|
      kind = classify(name)
      if kind == :floor && (ext[:z0].nil? || b[2] < ext[:z0])
        ext[:z0] = b[2]
        ext[:z0_by] = name
      end
      if kind == :ceiling && (ext[:z1].nil? || b[5] > ext[:z1])
        ext[:z1] = b[5]
        ext[:z1_by] = name
      end
    end
    # No deck at all: the walls carry the height, and the report says so.
    if ext[:z0].nil? || ext[:z1].nil?
      parts.each do |name, b|
        kind = classify(name)
        next unless kind == :wall || kind == :corner
        if ext[:z0].nil? || b[2] < ext[:z0]
          ext[:z0] = b[2]
          ext[:z0_by] = "#{name} (NO FLOOR PART — wall used)"
        end
        if ext[:z1].nil? || b[5] > ext[:z1]
          ext[:z1] = b[5]
          ext[:z1_by] = "#{name} (NO CEILING PART — wall used)"
        end
      end
      ext[:height_from_walls] = true
    end
    ext
  end

  # The union of every non-excluded child, for a block-out with no named
  # parts (booth-4260-s.rb). Includes anything in the group; the console
  # says GROUP BOUNDS so nobody reads it as a measured shell.
  def self.extent_from_bounds(parts)
    ext = nil
    parts.each do |name, b|
      next if name.to_s =~ EXCLUDE_RE
      if ext.nil?
        ext = { :x0 => b[0], :y0 => b[1], :z0 => b[2], :x1 => b[3], :y1 => b[4], :z1 => b[5] }
      else
        ext[:x0] = b[0] if b[0] < ext[:x0]
        ext[:y0] = b[1] if b[1] < ext[:y0]
        ext[:z0] = b[2] if b[2] < ext[:z0]
        ext[:x1] = b[3] if b[3] > ext[:x1]
        ext[:y1] = b[4] if b[4] > ext[:y1]
        ext[:z1] = b[5] if b[5] > ext[:z1]
      end
    end
    return nil if ext.nil?
    %w[x0 y0 z0 x1 y1 z1].each { |k| ext[(k + '_by').to_sym] = 'GROUP BOUNDS' }
    ext[:walls] = 0
    ext[:mode] = :bounds
    ext
  end

  # The booth's frame from its door wall: f is the outward normal of the
  # front wall, r the right-hand direction when facing that wall from
  # outside (r = (-f) x z). Both in the booth's own XY.
  def self.frame_for(front)
    case front.to_s.upcase
    when 'N' then { :f => [0.0, 1.0],  :r => [-1.0, 0.0] }
    when 'E' then { :f => [1.0, 0.0],  :r => [0.0, 1.0] }
    when 'W' then { :f => [-1.0, 0.0], :r => [0.0, -1.0] }
    else          { :f => [0.0, -1.0], :r => [1.0, 0.0] }
    end
  end

  # [front sign, right sign] for a corner name. Unknown reads as FR.
  def self.corner_signs(corner)
    case corner.to_s.upcase
    when 'FL' then [1.0, -1.0]
    when 'RL' then [-1.0, -1.0]
    when 'RR' then [-1.0, 1.0]
    else           [1.0, 1.0]
    end
  end

  def self.next_corner(corner)
    i = CORNERS.index(corner.to_s.upcase) || 0
    CORNERS[(i + 1) % CORNERS.length]
  end

  # 0 for the default corner, 1..3 for the rotated ones.
  def self.press_of(corner)
    CORNERS.index(corner.to_s.upcase) || 0
  end

  # The box corner in direction d (each component non-zero).
  def self.box_corner(ext, d)
    [d[0] > 0 ? ext[:x1] : ext[:x0], d[1] > 0 ? ext[:y1] : ext[:y0]]
  end

  def self.combine(s1, v1, s2, v2)
    [s1 * v1[0] + s2 * v2[0], s1 * v1[1] + s2 * v2[1]]
  end

  # THE PLACEMENT TABLE, as one rule (spec §7): the two ground strings run
  # along the two ground edges that leave the corner; the height stands at
  # the far end of the side-wall edge, pushed outward on that side. Returns
  # the three strings as { :a, :b, :off } in the booth's frame, z included.
  #
  # With the door on S and the corner FR this is exactly the reference image:
  # width (x0,y0)->(x1,y0) pushed -Y 24, depth (x1,y0)->(x1,y1) pushed +X 24,
  # height up (x1,y1) pushed +X 36. rbtest-boothdims.py pins all four rows.
  def self.layout(ext, front, corner)
    fr = frame_for(front)
    f = fr[:f]
    r = fr[:r]
    sf, sr = corner_signs(corner)
    z0 = ext[:z0]
    z1 = ext[:z1]
    w0 = box_corner(ext, combine(sf, f, -1.0, r))
    w1 = box_corner(ext, combine(sf, f, 1.0, r))
    d0 = box_corner(ext, combine(1.0, f, sr, r))
    d1 = box_corner(ext, combine(-1.0, f, sr, r))
    h  = box_corner(ext, combine(-sf, f, sr, r))
    {
      :width  => { :a => [w0[0], w0[1], z0], :b => [w1[0], w1[1], z0],
                   :off => [sf * f[0] * GAP, sf * f[1] * GAP, 0.0] },
      :depth  => { :a => [d0[0], d0[1], z0], :b => [d1[0], d1[1], z0],
                   :off => [sr * r[0] * GAP, sr * r[1] * GAP, 0.0] },
      :height => { :a => [h[0], h[1], z0], :b => [h[0], h[1], z1],
                   :off => [sr * r[0] * GAP_RISE, sr * r[1] * GAP_RISE, 0.0] }
    }
  end

  # The slab the height and depth strings occupy on the chosen side: the
  # side face pushed out GAP_RISE (the 24 in depth slab sits inside it), the
  # booth's full run along f, full height. [x0, y0, z0, x1, y1, z1].
  def self.side_slab(ext, front, corner)
    r = frame_for(front)[:r]
    sr = corner_signs(corner)[1]
    d = [sr * r[0], sr * r[1]]
    xs = d[0] > 0 ? [ext[:x1], ext[:x1] + GAP_RISE] :
         d[0] < 0 ? [ext[:x0] - GAP_RISE, ext[:x0]] : [ext[:x0], ext[:x1]]
    ys = d[1] > 0 ? [ext[:y1], ext[:y1] + GAP_RISE] :
         d[1] < 0 ? [ext[:y0] - GAP_RISE, ext[:y0]] : [ext[:y0], ext[:y1]]
    [xs[0], ys[0], ext[:z0], xs[1], ys[1], ext[:z1]]
  end

  # Which side of the booth the set is on, in words, for the console.
  def self.side_word(corner)
    corner_signs(corner)[1] > 0 ? 'right' : 'left'
  end

  def self.aabb_overlap?(a, b)
    a[0] < b[3] && b[0] < a[3] &&
      a[1] < b[4] && b[1] < a[4] &&
      a[2] < b[5] && b[2] < a[5]
  end

  # The catalogue's expectation for the three axes: the box plus 5.5 per
  # vented face (E/W project in X, N/S in Y) and the height by key suffix.
  def self.catalogue_extent(w, h, faces, enhanced)
    x = w * 1.0
    y = h * 1.0
    x += VENT_PROUD if faces.include?('E')
    x += VENT_PROUD if faces.include?('W')
    y += VENT_PROUD if faces.include?('N')
    y += VENT_PROUD if faces.include?('S')
    [x, y, enhanced ? HEIGHT_ENH : HEIGHT_STD]
  end

  # measured / expected are [x, y, z]; by is [x_part, y_part, z_part]. Lines
  # for every axis that disagrees by more than tol; [] when all three agree.
  def self.reconcile(measured, expected, by, tol = CAT_TOL)
    out = []
    %w[X Y Z].each_with_index do |ax, i|
      d = measured[i] - expected[i]
      next if d.abs <= tol
      out << format('*** %s: drawn %.4f, catalogue %.4f (%+.4f) — set by %s',
                    ax == 'Z' ? 'HEIGHT' : "ACROSS #{ax}",
                    measured[i], expected[i], d, by[i].to_s)
    end
    out
  end

  # ---- END PURE ------------------------------------------------------------

  # ==========================================================================
  # SketchUp API from here down.
  # ==========================================================================

  def self.arch(inches)
    Sketchup.format_length(inches.to_f).to_s
  rescue StandardError
    format('%.4f in', inches.to_f)
  end

  def self.booths
    return {} unless File.exist?(DATA)
    load DATA
    WR_BOOTH_DATA::BOOTHS
  rescue Exception => e
    puts "  could not read #{DATA}: #{e.class}: #{e.message}"
    {}
  end

  # A Group carries its entities directly; a ComponentInstance keeps them on
  # its definition. Both turn up as a booth.
  def self.inner(inst)
    return inst.entities if inst.is_a?(Sketchup::Group)
    return inst.definition.entities if inst.respond_to?(:definition) && inst.definition
    nil
  rescue StandardError
    nil
  end

  # [name, entity] for every named child. Anything on WR-Booth-Missing is a
  # placeholder for a part that is not there, and does not vote. With
  # include_unnamed the nameless groups of a hand-built block-out come too —
  # only the GROUP BOUNDS fallback wants those; nothing named votes by name.
  def self.named_children(inst, include_unnamed = false)
    out = []
    ents = inner(inst)
    return out if ents.nil?
    ents.each do |e|
      next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      n = (e.name.to_s rescue '')
      next if n.empty? && !include_unnamed
      next if e.layer && e.layer.name == 'WR-Booth-Missing'
      out << [n, e]
    end
    out
  rescue StandardError
    out
  end

  # A child's bounds in the booth's own frame, as a flat six. Entity#bounds
  # on a child is already in the parent's coordinates — never
  # definition.bounds, which ignores the child's placement.
  def self.local_box(e)
    b = e.bounds
    return nil unless b.valid?
    [b.min.x.to_f, b.min.y.to_f, b.min.z.to_f, b.max.x.to_f, b.max.y.to_f, b.max.z.to_f]
  rescue StandardError
    nil
  end

  # A top-level thing that is a WhisperRoom, or nil with the reason. Route 1
  # is the name (what build-booth-components, booth-4260-s and build-booth
  # all write); route 2 is the parts inside it.
  def self.booth?(inst)
    return false unless inst.is_a?(Sketchup::Group) || inst.is_a?(Sketchup::ComponentInstance)
    return true if booth_name?(inst.name)
    # A component instance may be unnamed while its definition carries the
    # model — a saved booth re-imported as a component does that.
    return true if inst.respond_to?(:definition) && booth_name?(inst.definition.name)
    named_children(inst).any? { |n, _e| !classify(n).nil? }
  rescue StandardError
    false
  end

  # The catalogue key from the group name, then the deck parts — the old
  # tool's two routes, kept. nil when nothing answers; the cross-check is
  # then skipped and the report says so.
  DECK_RE = /\A(?:STD|ENH\s*)(\d{2,3})(\d{2})\s*FL/i.freeze

  def self.identify(inst, specs, kids)
    nm = (inst.name.to_s rescue '')
    hit = specs.keys.find { |k| nm.include?(k) }
    return [hit, format('the group name, "%s"', nm)] if hit

    fl = []
    kids.each do |n, e|
      m = DECK_RE.match(n.strip)
      next if m.nil?
      b = local_box(e)
      next if b.nil?
      fl << [m[1].to_f, m[2].to_f, (b[0] + b[3]) / 2.0, (b[1] + b[4]) / 2.0]
    end
    return [nil, 'nothing in it names a model'] if fl.empty?
    cross = fl.map { |f| f[0] }.max
    along = fl.map { |f| f[1] }.inject(0.0) { |a, v| a + v }
    xs = fl.map { |f| f[2] }
    ys = fl.map { |f| f[3] }
    spread_x = xs.max - xs.min
    spread_y = ys.max - ys.min
    orders = if (spread_x - spread_y).abs < 1.0
               [[along + 2.0, cross + 2.0], [cross + 2.0, along + 2.0]]
             elsif spread_x > spread_y
               [[along + 2.0, cross + 2.0]]
             else
               [[cross + 2.0, along + 2.0]]
             end
    enh = kids.any? { |n, _e| n =~ /\AENH\s/i || n =~ /\A(FL|CL)i\s/ }
    hits = []
    orders.each do |ex, ey|
      specs.each do |k, s|
        next unless (s[:w].to_f - ex).abs < 0.5 && (s[:h].to_f - ey).abs < 0.5
        next unless (k =~ /\sE\z/ ? true : false) == enh
        hits << k unless hits.include?(k)
      end
    end
    return [nil, 'the deck parts match no model'] if hits.empty?
    if hits.length > 1
      return [nil, format('the deck reads %g x %g, which fits %s equally', cross, along,
                          hits.join(' and '))]
    end
    [hits.first, format('the deck parts: %g across, %g along', cross, along)]
  rescue StandardError => e
    [nil, "identification failed: #{e.class}: #{e.message}"]
  end

  # ----------------------------------------------------------------- tag --

  def self.tag(model)
    t = model.layers[TAG] || model.layers.add(TAG)
    (t.color = Sketchup::Color.new(40, 40, 40)) rescue nil
    t
  end

  # ----------------------------------------------------------- ownership --

  def self.own(e, pid, corner)
    e.set_attribute(DICT, 'booth', pid)
    e.set_attribute(DICT, 'own', true)
    e.set_attribute(DICT, 'corner', corner)
  rescue StandardError
    nil
  end

  def self.owned_by?(e, pid)
    e.valid? && e.get_attribute(DICT, 'own', false) &&
      e.get_attribute(DICT, 'booth', nil) == pid
  rescue StandardError
    false
  end

  # Everything this tool ever drew, at the top level. Dimensions and the
  # ConstructionPoints they hang on.
  def self.owned(model)
    model.entities.to_a.select do |e|
      e.valid? && e.get_attribute(DICT, 'own', false)
    end
  rescue StandardError
    []
  end

  def self.old_tool_entities(model)
    model.entities.to_a.select do |e|
      e.valid? && (e.is_a?(Sketchup::Dimension) || e.is_a?(Sketchup::Text)) &&
        e.get_attribute(OLD_DICT, 'own', false)
    end
  rescue StandardError
    []
  end

  def self.booth_alive?(model, pid)
    return false if pid.nil?
    e = model.find_entity_by_persistent_id(pid)
    !e.nil? && e.valid?
  rescue StandardError
    # An API without the lookup cannot tell, and must not erase on a guess.
    true
  end

  # Erase one booth's set. Returns the count.
  def self.clear_for(model, pid)
    doomed = owned(model).select { |e| owned_by?(e, pid) }
    model.entities.erase_entities(doomed) unless doomed.empty?
    doomed.length
  end

  # Sets whose booth is gone. Returns the count erased.
  def self.clear_orphans(model)
    gone = owned(model).reject { |e| booth_alive?(model, e.get_attribute(DICT, 'booth', nil)) }
    model.entities.erase_entities(gone) unless gone.empty?
    gone.length
  end

  # ------------------------------------------------------------ anchors --

  ATTACH_TOL = 0.02
  CHECK_TOL  = 0.001

  # A vertex inside a voting part at this booth-frame point, as
  # [InstancePath, Vertex], or nil. Only consulted when
  # ATTACH_NESTED_VERTICES is on — see the header.
  def self.attach_vertex(inst, parts, local_pt)
    parts.each do |_name, part|
      next unless part.respond_to?(:definition) || part.is_a?(Sketchup::Group)
      ents = inner(part)
      next if ents.nil?
      pt = local_pt.transform(part.transformation.inverse)
      ents.grep(Sketchup::Edge).each do |edge|
        [edge.start, edge.end].each do |v|
          next unless v.position.distance(pt) <= ATTACH_TOL
          return [Sketchup::InstancePath.new([inst, part]), v]
        end
      end
    end
    nil
  rescue StandardError
    nil
  end

  # Resolve one endpoint. Returns [reference, kind] where kind is :vertex,
  # :synthetic or :loose. The ConstructionPoint is made in model.entities,
  # on the tag, owned by the booth, so it is erased with the set.
  def self.anchor_for(model, inst, parts, local_pt, world_pt, lay, pid, corner)
    if ATTACH_NESTED_VERTICES
      v = attach_vertex(inst, parts, local_pt)
      return [v, :vertex] if v
    end
    cp = model.entities.add_cpoint(world_pt)
    if cp
      cp.layer = lay
      own(cp, pid, corner)
      return [cp, :synthetic]
    end
    [world_pt, :loose]
  rescue StandardError
    [world_pt, :loose]
  end

  # Where a dimension endpoint actually landed, or nil. DimensionLinear#start
  # and #end return the point, or an [entity, point] pair when attached;
  # proposal-package.rb reads them the same way.
  def self.landed(v)
    return v if v.is_a?(Geom::Point3d)
    if v.is_a?(Array)
      p = v.find { |x| x.is_a?(Geom::Point3d) }
      return p if p
      e = v.find { |x| x.respond_to?(:position) }
      return e.position if e
    end
    return v.position if v.respond_to?(:position)
    nil
  rescue StandardError
    nil
  end

  # ---------------------------------------------------------------- draw --

  # The whole run for one booth. Returns the Dimension entities drawn (three
  # on success). The corner comes off the booth group unless ROTATE passes
  # the advanced one in; either way it is written INSIDE the operation, so
  # one Ctrl+Z reverses the strings and the corner together.
  def self.dimension(inst, force_corner = nil)
    model = inst.model
    kids = named_children(inst)
    parts = kids.map { |n, e| [n, local_box(e), e] }.reject { |_n, b, _e| b.nil? }
    pboxes = parts.map { |n, b, _e| [n, b] }
    names = kids.map { |n, _e| n }

    ext = extent_from_parts(pboxes)
    if ext.nil?
      every = named_children(inst, true).map { |n, e| [n, local_box(e)] }.reject { |_n, b| b.nil? }
      ext = extent_from_bounds(every)
    end
    if ext.nil?
      puts "DIMENSION WHISPERROOM — \"#{inst.name}\" has nothing inside it to measure. Nothing drawn."
      return []
    end

    front = door_wall(names) || 'S'
    stored = force_corner || (inst.get_attribute(DICT, 'corner', nil) rescue nil)
    corner = CORNERS.include?(stored.to_s.upcase) ? stored.to_s.upcase : 'FR'
    pid = inst.persistent_id
    lay_out = layout(ext, front, corner)

    tr = inst.transformation
    to_world = lambda { |p| Geom::Point3d.new(p[0], p[1], p[2]).transform(tr) }
    to_vec = lambda { |v| Geom::Vector3d.new(v[0], v[1], v[2]).transform(tr) }
    voters = parts.select { |n, _b, _e| [:wall, :corner, :floor, :ceiling].include?(classify(n)) }
                  .map { |n, _b, e| [n, e] }

    # Measured = what the dimension will read: world distance between the
    # two anchors. On an unscaled booth this equals the frame extent.
    meas = {}
    lay_out.each do |k, s|
      meas[k] = to_world.call(s[:a]).distance(to_world.call(s[:b])).to_f
    end
    # Axis figures for the cross-check, X / Y / Z in the booth frame.
    ax_meas = [(ext[:x1] - ext[:x0]) * 1.0, (ext[:y1] - ext[:y0]) * 1.0, (ext[:z1] - ext[:z0]) * 1.0]
    ax_by = ["#{ext[:x0_by]} / #{ext[:x1_by]}", "#{ext[:y0_by]} / #{ext[:y1_by]}",
             "#{ext[:z0_by]} / #{ext[:z1_by]}"]

    # Catalogue cross-check, printed, never drawn.
    specs = booths
    key, how_id = specs.empty? ? [nil, 'booth data not found'] : identify(inst, specs, kids)
    faces, efs = vents_from_names(names)
    mismatch = []
    expected = nil
    if key
      spec = specs[key]
      expected = catalogue_extent(spec[:w], spec[:h], faces, !(key =~ /\sE\z/).nil?)
      mismatch = reconcile(ax_meas, expected, ax_by)
    end

    # Obstruction: anything else at the top level standing in the slab the
    # side strings occupy. Comply and say — never skip a corner.
    slab = side_slab(ext, front, corner)
    slab_w = Geom::BoundingBox.new
    [[slab[0], slab[1], slab[2]], [slab[3], slab[1], slab[2]], [slab[0], slab[4], slab[2]],
     [slab[3], slab[4], slab[2]], [slab[0], slab[1], slab[5]], [slab[3], slab[1], slab[5]],
     [slab[0], slab[4], slab[5]], [slab[3], slab[4], slab[5]]].each { |c| slab_w.add(to_world.call(c)) }
    sw = [slab_w.min.x.to_f, slab_w.min.y.to_f, slab_w.min.z.to_f,
          slab_w.max.x.to_f, slab_w.max.y.to_f, slab_w.max.z.to_f]
    blockers = []
    model.entities.each do |e|
      next if e == inst
      next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      next unless e.valid?
      b = e.bounds
      next unless b.valid?
      eb = [b.min.x.to_f, b.min.y.to_f, b.min.z.to_f, b.max.x.to_f, b.max.y.to_f, b.max.z.to_f]
      next unless aabb_overlap?(sw, eb)
      nm = (e.name.to_s rescue '')
      nm = (e.definition.name.to_s rescue '') if nm.empty? && e.respond_to?(:definition)
      blockers << (nm.empty? ? 'an unnamed group' : nm)
    end

    begin
      model.options['UnitsOptions']['LengthFormat'] = Length::Architectural
    rescue StandardError
    end

    made = []
    kinds = []
    misses = []
    removed = 0
    model.start_operation('Dimension WhisperRoom', true)
    begin
      lay = tag(model)
      removed = clear_for(model, pid)
      orphans = clear_orphans(model)
      inst.set_attribute(DICT, 'corner', corner)
      [:width, :depth, :height].each do |k|
        s = lay_out[k]
        wa = to_world.call(s[:a])
        wb = to_world.call(s[:b])
        la = Geom::Point3d.new(s[:a][0], s[:a][1], s[:a][2])
        lb = Geom::Point3d.new(s[:b][0], s[:b][1], s[:b][2])
        ra, ka = anchor_for(model, inst, voters, la, wa, lay, pid, corner)
        rb, kb = anchor_for(model, inst, voters, lb, wb, lay, pid, corner)
        vec = to_vec.call(s[:off])
        d = nil
        begin
          d = model.entities.add_dimension_linear(ra, rb, vec)
        rescue StandardError => e
          puts "  attached dimension refused (#{e.class}: #{e.message}) — drawing loose"
          d = nil
        end
        if d.nil?
          d = model.entities.add_dimension_linear(wa, wb, vec)
          ka = kb = :loose
        end
        d.layer = lay
        own(d, pid, corner)
        # Auto text only (spec S10): the string reports what the geometry
        # measures, never a typed figure. Same guard as auto-dimension.rb.
        (d.text = '') rescue nil
        # Post-check: the witness points must be ON the corners. Anything
        # else is reported, whichever attachment route produced it.
        pa = landed(d.start)
        pb = landed(d.end)
        if pa.nil? || pa.distance(wa) > CHECK_TOL
          misses << format('%s start landed %s, wanted %s', k, pa ? pa.to_s : 'nowhere', wa.to_s)
        end
        if pb.nil? || pb.distance(wb) > CHECK_TOL
          misses << format('%s end landed %s, wanted %s', k, pb ? pb.to_s : 'nowhere', wb.to_s)
        end
        kinds << ka << kb
        made << d
      end
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      puts "DIMENSION WHISPERROOM FAILED: #{e.class}: #{e.message}"
      puts e.backtrace.first(6).map { |l| "  #{l}" }.join("\n") if e.backtrace
      UI.messagebox("Dimension WhisperRoom failed:\n\n#{e.class}: #{e.message}")
      return []
    end

    # ------------------------------------------------------------ report --
    press = press_of(corner)
    puts ''
    puts "DIMENSION WHISPERROOM — \"#{inst.name}\""
    puts format('  corner %s (%s)', corner,
                press.zero? ? 'default' : format('rotated, press %d of 4', press))
    puts format('  front  %s wall%s   set on the %s side', front,
                door_wall(names) ? ' (door)' : ' (no door part found — S assumed)', side_word(corner))
    if ext[:mode] == :bounds
      puts '  extent: GROUP BOUNDS — no named parts; includes anything in the group'
    else
      puts format('  extent: %d wall/corner part(s) voted', ext[:walls])
      puts format('    X %9.4f .. %9.4f   set by "%s" / "%s"', ext[:x0], ext[:x1], ext[:x0_by], ext[:x1_by])
      puts format('    Y %9.4f .. %9.4f   set by "%s" / "%s"', ext[:y0], ext[:y1], ext[:y0_by], ext[:y1_by])
      puts format('    Z %9.4f .. %9.4f   set by "%s" / "%s"', ext[:z0], ext[:z1], ext[:z0_by], ext[:z1_by])
      puts '    *** no floor/ceiling parts — the height is off the WALLS and is not the booth height' if ext[:height_from_walls]
    end
    puts format('  width   %-12s  depth   %-12s  height  %-12s   (MEASURED — what is drawn)',
                arch(meas[:width]), arch(meas[:depth]), arch(meas[:height]))
    if key
      puts format('  catalogue %s: %s x %s x %s  (%s, +%s per vented face: %s)', key,
                  arch(expected[0]), arch(expected[1]), arch(expected[2]), how_id,
                  arch(VENT_PROUD), faces.empty? ? 'none' : faces.join(' '))
      if mismatch.empty?
        puts format('  agrees with the catalogue within %s on all three axes', arch(CAT_TOL))
      else
        puts ''
        mismatch.each { |l| puts "  #{l}" }
        puts '      The dimension reads the DRAWN figure. If the part is seated wrong,'
        puts '      fix the build; a dimension does not paper over it.'
        puts ''
      end
    else
      puts "  catalogue cross-check skipped: #{how_id}"
    end
    puts '  *** EFS parts in this booth: the 5 1/2 in figure is the no-EFS rule, so the catalogue line understates' if efs
    casters = names.select { |n| n =~ CASTER_RE }
    unless casters.empty?
      cp = parts.select { |n, _b, _e| n =~ CASTER_RE }
      h = cp.map { |_n, b, _e| b[5] - b[2] }.max
      puts format('  caster plates: %d, %s tall — NOT in the height above (floor underside to ceiling top)',
                  casters.length, arch(h || 0))
    end
    kn = { :vertex => 0, :synthetic => 0, :loose => 0 }
    kinds.each { |k| kn[k] = (kn[k] || 0) + 1 }
    puts format('  anchors: %d on part vertices, %d synthetic (ConstructionPoints on %s), %d loose',
                kn[:vertex], kn[:synthetic], TAG, kn[:loose])
    puts '  *** LOOSE ENDPOINTS — those witness lines are attached to nothing. This is a defect, not a pass.' if kn[:loose] > 0
    misses.each { |m| puts "  *** #{m}" }
    puts format('  %d dimension(s) on %s for booth %s%s', made.length, TAG, pid,
                removed > 0 ? format(' (replaced %d)', removed) : '')
    puts format('  removed %d orphan(s) whose booth is gone', orphans) if orphans > 0
    unless blockers.empty?
      puts format('  *** %s side blocked by %s — the height and depth strings sit inside it; ' \
                  'rotate again or hide that for the shot', side_word(corner),
                  blockers.map { |b| "\"#{b}\"" }.join(', '))
    end
    old = old_tool_entities(model).length
    if old > 0
      puts format('  %d entity(ies) from the retired dimension-booth.rb are still in this model — ' \
                  'Clear WhisperRoom dimensions (Esc = all) removes them', old)
    end
    puts ''
    made
  end

  # Advance the stored corner, then the same path a fresh run uses.
  def self.rotate(inst)
    was = (inst.get_attribute(DICT, 'corner', nil) rescue nil)
    was = CORNERS.include?(was.to_s.upcase) ? was.to_s.upcase : 'FR'
    nxt = next_corner(was)
    puts "ROTATE — #{was} -> #{nxt}"
    dimension(inst, nxt)
  end

  # One booth's set, or (inst nil) every set this tool owns plus the retired
  # tool's leftovers. Never anything else on the tag.
  def self.clear(inst)
    model = Sketchup.active_model
    model.start_operation('Clear WhisperRoom dimensions', true)
    if inst
      n = clear_for(model, inst.persistent_id)
      model.commit_operation
      puts "CLEAR — removed #{n} entity(ies) of booth dimensions from \"#{inst.name}\""
    else
      mine = owned(model)
      old = old_tool_entities(model)
      model.entities.erase_entities(mine + old) unless (mine + old).empty?
      model.commit_operation
      puts format('CLEAR — removed %d entity(ies) from this tool and %d from the retired dimension-booth.rb',
                  mine.length, old.length)
    end
    true
  rescue StandardError => e
    model.abort_operation rescue nil
    puts "CLEAR FAILED: #{e.class}: #{e.message}"
    false
  end

  # ------------------------------------------------------------ the pick --

  def self.refuse(ent)
    nm = (ent.name.to_s rescue '')
    nm = (ent.definition.name.to_s rescue '') if nm.empty? && ent.respond_to?(:definition)
    msg = "Not a WhisperRoom I can recognise — the group is called \"#{nm}\".\n\n" \
          'Rename it to include the model ("MDL 96120 S") or use ' \
          "Measure whatever is selected.\n\nNothing was drawn."
    puts "DIMENSION WHISPERROOM — refused: #{msg.tr("\n", ' ')}"
    UI.messagebox(msg)
  end

  def self.perform(action, ent)
    unless booth?(ent)
      refuse(ent)
      return false
    end
    case action
    when :rotate then !rotate(ent).empty?
    when :clear  then clear(ent)
    else              !dimension(ent).empty?
    end
  end

  PROMPTS = {
    :dimension => 'Click a WhisperRoom to dimension it. Esc cancels.',
    :rotate    => 'Click a WhisperRoom to move its dimensions to the next corner. Esc cancels.',
    :clear     => 'Click a WhisperRoom to clear its dimensions. Esc with nothing picked clears every booth.'
  }.freeze

  # A one-shot pick: click a booth, the action runs, the tool exits. Clicking
  # empty space keeps the prompt up. Clicking something that is not a booth
  # refuses and exits — the operator meant that thing, and it was wrong.
  class PickTool
    def initialize(action)
      @action = action
      @done = false
    end

    def activate
      Sketchup.set_status_text(WR_BoothDims::PROMPTS[@action], SB_PROMPT)
    end

    def deactivate(view)
      Sketchup.set_status_text('', SB_PROMPT)
      view.invalidate
    end

    def onMouseMove(_flags, _x, _y, _view)
      Sketchup.set_status_text(WR_BoothDims::PROMPTS[@action], SB_PROMPT)
    end

    # reason 0 is Esc. 1 (tool re-selected) and 2 (undo while the tool was
    # live) are not a request to clear anything.
    def onCancel(reason, view)
      return if @done
      @done = true
      if @action == :clear && reason == 0
        if UI.messagebox("Clear WhisperRoom dimensions on EVERY booth in this model?", MB_YESNO) == IDYES
          WR_BoothDims.clear(nil)
        else
          puts 'CLEAR — cancelled, nothing removed'
        end
      else
        puts 'cancelled — nothing drawn'
      end
      view.model.select_tool(nil)
    end

    def onLButtonDown(_flags, x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)
      top = nil
      begin
        path = ph.path_at(0)
        top = path.first if path && !path.empty?
      rescue StandardError
        top = nil
      end
      top ||= ph.best_picked
      return if top.nil?   # empty space: the prompt stays up
      unless top.is_a?(Sketchup::Group) || top.is_a?(Sketchup::ComponentInstance)
        return
      end
      @done = true
      view.model.select_tool(nil)
      WR_BoothDims.perform(@action, top)
    rescue Exception => e
      puts "PICK FAILED: #{e.class}: #{e.message}"
      puts e.backtrace.first(6).map { |l| "  #{l}" }.join("\n") if e.backtrace
      view.model.select_tool(nil) rescue nil
    end
  end

  # The entry point all three scripts share. A booth already selected skips
  # the pick.
  def self.run(action = :dimension)
    model = Sketchup.active_model
    return false if model.nil?
    sel = model.selection.to_a.find do |e|
      e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    end
    if sel
      return perform(action, sel)
    end
    model.select_tool(PickTool.new(action))
    true
  end
end

begin
  WR_BoothDims.run(:dimension) unless $wr_no_autorun
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Dimension a WhisperRoom failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console.')
end
