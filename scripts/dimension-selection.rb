# @title Measure whatever is selected...
# @cat Add dimensions
# @ability Dimensioned selection
# @ability-blurb Length, width and height of whatever is selected. Switch off to remove them.
# @setting where  choice  Outside|On the box  Where the dimensions sit
# @setting gap    number  12                  Standoff (in)
# @on  WR_DimensionSelection.ability_on(opts)
# @off WR_DimensionSelection.ability_off(opts)
#
# Select a WhisperRoom, switch this on, get its LENGTH, WIDTH and HEIGHT.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/dimension-selection.rb"
#
# NOT THE SAME JOB AS auto-dimension.rb, and that is why this exists. That one
# chain-dimensions a ROOM: it finds the largest horizontal face in the model,
# reads its outer loop, and dimensions every wall run and door off it. Point it
# at a booth sitting inside a room and it dimensions THE ROOM — which is how a
# selected booth came back reading 30 feet, drawn away from the thing that was
# selected. It was not wrong, it was answering a different question.
#
# This answers the question actually being asked: how big is this object.
#
# HOW THE SIZE IS TAKEN
#
# From the instance's WORLD bounding box, so what is measured is what is on
# screen, at the size and rotation it appears. A definition's own bounds would
# be the un-transformed part and would disagree with the picture the moment
# anything was scaled or rotated — the same class of error as dimensions landing
# fifty feet away, which is a local-coordinate reading drawn into world space.
#
# Dimensions are drawn in MODEL SPACE, not inside the selection. Putting them
# inside a component would repeat them on every instance of it and they would
# move when the part moved, which reads as correct until it very much is not.
#
# They go on their own tag, WR-Dims-Selection, so switching the ability off
# removes exactly what it drew and nothing else — never anything hand-drawn.

require 'sketchup.rb'

module WR_DimensionSelection
  TAG  = 'WR-Dims-Selection'.freeze
  DICT = 'WR_DimSel'.freeze
  PREF = 'WR_DimensionSelection'.freeze

  DEFAULTS = { 'where' => 'Outside', 'gap' => '12' }.freeze

  def self.read_pref(k)
    v = Sketchup.read_default(PREF, k, DEFAULTS[k].to_s).to_s
    v.empty? ? DEFAULTS[k].to_s : v
  rescue Exception
    DEFAULTS[k].to_s
  end

  def self.write_pref(k, v)
    Sketchup.write_default(PREF, k, v.to_s.delete('"'))
  rescue Exception
    nil
  end

  # ------------------------------------------------------------------ subject --

  # What to measure. One selected object is the normal case; several are treated
  # as one assembly, which is what you want when a booth is a handful of loose
  # groups rather than one.
  def self.subject_bounds(model)
    sel = model.selection
    if sel.empty?
      UI.messagebox("Select the WhisperRoom first.\n\n" \
                    'Its overall length, width and height get dimensioned.')
      return nil
    end
    bb = Geom::BoundingBox.new
    n = 0
    sel.each do |e|
      next unless e.respond_to?(:bounds)
      b = e.bounds
      next unless b.valid?
      bb.add(b)
      n += 1
    end
    if n.zero? || !bb.valid?
      UI.messagebox("Nothing in the selection has a size to measure.")
      return nil
    end
    bb
  end

  # ---------------------------------------------------------------------- tag --

  def self.tag(model)
    t = model.layers[TAG] || model.layers.add(TAG)
    (t.color = Sketchup::Color.new(238, 98, 22)) rescue nil   # brand orange
    t
  end

  # ---------------------------------------------------------------- drawing --

  # A DimensionLinear wants two points and an offset VECTOR — the offset is what
  # pushes the dimension line clear of the object. Pass a zero vector and the
  # dimension lands on the edge it measures, which is unreadable on a dark booth.
  def self.dim(ents, a, b, offset, layer)
    d = ents.add_dimension_linear(a, b, offset)
    d.layer = layer if d
    d
  rescue StandardError => e
    puts "  dimension failed: #{e.class}: #{e.message}"
    nil
  end

  # Length along X, width along Y, height along Z, each drawn on the edge of the
  # box nearest the viewer's usual three-quarter view: X along the front-bottom,
  # Y along the right-bottom, Z up the front-LEFT corner. Consistent placement
  # matters more than clever placement — you learn where to look. That principle
  # has not changed; where the height sits has.
  #
  # EVERY OFFSET RUNS ALONG A SINGLE AXIS. NO DIAGONALS. The height used to be
  # drawn up the front-RIGHT corner with an offset of (0.7g, -0.7g, 0) — a 45
  # degree push, out in +X and toward the viewer in -Y at once. It cleared the
  # other two, but it read as a stray line shooting off the corner rather than
  # part of the drawing, and worse, a diagonally-offset dimension fights you when
  # you try to nudge it by hand. Drag a dimension whose offset lies on one axis
  # and it slides cleanly along that axis; drag a diagonal one and every pull
  # moves it in two directions at once. Benton could not move it, and that is the
  # half of the complaint that actually costs time.
  #
  # THE RULE, and it is a rule so that placement stops feeling arbitrary:
  # dimensions are pushed straight out of the face they belong to. Length belongs
  # to the front elevation and pushes -Y, out toward the viewer. Width belongs to
  # the right elevation and pushes +X. Height belongs to the front elevation too
  # — so it stands up the LEFT edge of that elevation and pushes -X, out the
  # side. Length across the bottom and height up the left is how an elevation is
  # dimensioned on paper, so the drawing now reads the way a drawing should.
  #
  # WHY THE LEFT AND NOT THE RIGHT, which is the collision the old diagonal was
  # dodging. With mn at the origin and a 122 x 98 x 83 box at the default 12 in
  # standoff, the three dimension LINES land at:
  #
  #   length  y = -12,  z = 0,     x from   0 to 122
  #   width   x = 134,  z = 0,     y from   0 to  98
  #   height  x = -12,  y = 0,     z from   0 to  83
  #
  # Height to width is 146 in apart in X — opposite ends of the box, the furthest
  # two of the three can be. Height to length is the close pair: nearest approach
  # is height's foot at (-12, 0, 0) to length's near end at (0, -12, 0), which is
  # sqrt(12^2 + 12^2) = 16.97 in of clear air, and it grows as the height line
  # rises. That separation is g * sqrt(2) — it scales with the standoff, so a
  # bigger gap never pushes them together. Offsetting the height +X or -Y from
  # the front-right corner instead lands its line on one of the other two: +X
  # puts it through the width line's own end point, -Y puts it through the
  # length line's. Neither is fixable by pushing further out, because the width
  # and length lines sit at exactly the same standoff. The left side is the only
  # single-axis placement that is clear at every gap.
  #
  # The two extension lines from the height's lower end and the length's left end
  # both leave the same box corner, in perpendicular directions. That is normal
  # drafting and is not a collision — the dimension lines themselves never meet.
  # Note that 16.97 in is also exactly how far apart the length and width lines
  # already were, so the height is no tighter to its neighbour than those two
  # have always been to each other.
  #
  # AND IT STAYS ON THE CORNER RATHER THAN SLIDING TO THE MIDDLE OF THAT FACE,
  # which is the other single-axis placement someone will reach for. On the
  # corner the line is on the booth's silhouette; at the face midpoint it is 49
  # in further back in Y and lands ON TOP OF the booth in the three-quarter view
  # this whole layout is aimed at. Projecting screen-across as 0.707 * (x + y)
  # for a front-right camera, the 122 x 98 box occupies 0 to 155.6; the corner
  # placement projects to -8.5, clear off the left of it, while the midpoint
  # projects to +26.2, a quarter of the way across the front face. Corner-placed
  # is not the same complaint as corner-DIRECTED — the diagonal was the problem.
  def self.draw(model, bb, gap, outside)
    lay = tag(model)
    ents = model.entities
    mn = bb.min
    mx = bb.max
    g = outside ? gap.to_f.abs : 0.0

    made = []
    # LENGTH — along X, on the near-bottom edge, pushed toward the viewer (-Y).
    made << dim(ents,
                Geom::Point3d.new(mn.x, mn.y, mn.z),
                Geom::Point3d.new(mx.x, mn.y, mn.z),
                Geom::Vector3d.new(0, -g, 0), lay)
    # WIDTH — along Y, on the right-bottom edge, pushed out in +X.
    made << dim(ents,
                Geom::Point3d.new(mx.x, mn.y, mn.z),
                Geom::Point3d.new(mx.x, mx.y, mn.z),
                Geom::Vector3d.new(g, 0, 0), lay)
    # HEIGHT — up Z at the front-LEFT corner, pushed out in -X only. Same two end
    # points' worth of height as ever; only the line's resting place moved. One
    # axis, so it drags cleanly in X. See the rule above for why this side.
    made << dim(ents,
                Geom::Point3d.new(mn.x, mn.y, mn.z),
                Geom::Point3d.new(mn.x, mn.y, mx.z),
                Geom::Vector3d.new(-g, 0, 0), lay)

    made.compact!
    made.each { |d| d.set_attribute(DICT, 'own', true) rescue nil }
    made
  end

  # Only ever erases what this script drew: tagged AND carrying the attribute.
  # Either test alone would eventually eat something hand-drawn on the same tag.
  def self.clear(model)
    doomed = model.entities.to_a.select do |e|
      next false unless e.valid?
      next false unless e.is_a?(Sketchup::Dimension)
      (e.layer && e.layer.name == TAG) || e.get_attribute(DICT, 'own', false)
    end
    n = doomed.length
    model.entities.erase_entities(doomed) unless doomed.empty?
    n
  rescue StandardError => e
    puts "  clear failed: #{e.class}: #{e.message}"
    0
  end

  def self.arch(inches)
    Sketchup.format_length(inches.to_f).to_s
  rescue StandardError
    format('%.2f in', inches.to_f)
  end

  # ------------------------------------------------------------------ ability --

  def self.settings(opts)
    where = (opts['where'] || opts[:where] || read_pref('where')).to_s
    gap   = (opts['gap']   || opts[:gap]   || read_pref('gap')).to_f
    gap = 12.0 if gap <= 0 || gap > 240
    write_pref('where', where)
    write_pref('gap', gap.round.to_s)
    [where, gap]
  end

  def self.ability_on(opts = {})
    model = Sketchup.active_model
    return false if model.nil?
    bb = subject_bounds(model)
    return false if bb.nil?
    where, gap = settings(opts)

    model.start_operation('Dimension selection', true)
    begin
      clear(model)                       # never stack two sets on one object
      made = draw(model, bb, gap, !where.to_s.downcase.include?('box'))
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      UI.messagebox("Dimension selection failed:\n\n#{e.class}: #{e.message}")
      return false
    end

    puts ''
    puts 'DIMENSION SELECTION'
    puts format('  length (X)  %s', arch(bb.max.x - bb.min.x))
    puts format('  width  (Y)  %s', arch(bb.max.y - bb.min.y))
    puts format('  height (Z)  %s', arch(bb.max.z - bb.min.z))
    puts "  #{made.length} dimension(s) on #{TAG}"
    puts '  Measured from the WORLD bounding box of the selection, so this is the'
    puts '  size as it sits in the model — not a catalogue figure. Anything'
    puts '  quoted from it is ESTIMATED until a tape says otherwise.'
    puts ''
    made.length == 3
  end

  def self.ability_off(_opts = {})
    model = Sketchup.active_model
    return false if model.nil?
    model.start_operation('Remove selection dimensions', true)
    n = clear(model)
    model.commit_operation
    puts "  removed #{n} dimension(s) from #{TAG}"
    true
  end

  # Running it from the list rather than the toggle just does the on-half, so the
  # button and the switch cannot mean different things.
  def self.run
    ability_on({})
  end
end

WR_DimensionSelection.run unless $wr_no_autorun
