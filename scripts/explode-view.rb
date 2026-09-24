# @title Exploded view...
# @cat Component art (web catalog)
# @ability Exploded
# @ability-blurb Pull the selected assembly apart; switch off to put it back.
# @setting mode   choice  Axis|Radial|Vertical  Direction
# @setting spread number  60                   Spread (%)
# @setting fan    number  150                  Fan (%)
# @on  WR_ExplodeView.ability_on(opts)
# @off WR_ExplodeView.ability_off(opts)
#
# Pull an assembly apart for an assembly-manual illustration, and put it back.
#
# Every part remembers where it came from. The first explode stores each part's
# home position as an attribute on the part itself, so you can re-explode at a
# different spread, or Reset, as many times as you like — the offsets are always
# computed from home, never compounded onto the last run. Save the model and the
# homes travel with it.
#
# AXIS mode is the default and it is the one that reads properly in a manual.
# On a BOOTH it works by assembly, not by part (see booth_plan):
#   * the FLOOR stays where it is, its pieces opened out a little in-plane;
#   * each WALL moves straight out along its own outward normal as ONE unit —
#     door, frame, window, both skins of an Enhanced wall — and its panels open
#     out along the wall with the same gap at every joint;
#   * the CEILING lifts straight up, its panels opened out the same way;
#   * corner seals go out diagonally, clear of both walls they join;
#   * hardware and trim (seals, strips, locksets, duct covers, brackets) move
#     with the part they are fixed to, never on their own.
# Spread (%) sets how far walls and ceiling travel; Fan (%) sets how far apart
# the parts WITHIN a wall, floor or ceiling open (0 keeps each one a sheet).
#
# Anything that does not read as a booth — no floor/walls around a footprint —
# falls back to the older per-part rule: each part along its own flattest axis,
# with co-planar parts fanned apart (see fan_in_plane).
#
# Radial and Vertical are per-part and have no structure. They are kept for
# small assemblies; on a booth they scatter by design and are not what a manual
# or a proposal wants.
#
# Pair with Orbit Export for angles: explode, then orbit, and every frame is of
# the exploded assembly.
#
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/explode-view.rb"

require 'fileutils'

# The folder field is a dropdown of folders used before, plus a Browse entry.
load File.join(File.dirname(__FILE__), 'wr-folder.rb')

module WR_ExplodeView
  DICT     = 'WR_Explode'.freeze
  TAG_LEAD = 'WR-Explode-Leaders'.freeze
  PREF     = 'WR_ExplodeView'.freeze

  DEFAULTS = {
    'action' => 'Explode',
    'mode'   => 'Axis (one axis per part)',
    'spread' => '60',
    'fan'    => '150',
    'frames' => '0',
    'dir'    => 'C:/Users/bento/Desktop/ProposalFiles/PartArt'
  }.freeze

  # ------------------------------------------------------------------- input --

  def self.ask
    keys  = %w[action mode spread fan frames dir]
    prompts = ['Action', 'Direction', 'Spread (%)', 'Fan (%)',
               'Sweep frames (0 = none)', 'Output folder']
    defaults = keys.map { |k| v = Sketchup.read_default(PREF, k, DEFAULTS[k]).to_s
                              v.empty? ? DEFAULTS[k] : v }
    lists = ['Explode|Reset',
             'Axis (one axis per part)|Radial|Vertical only',
             '', '', '', '']
    di = keys.index('dir')
    defaults[di], lists[di] = WR_Folder.field('explode', defaults[di])

    res = UI.inputbox(prompts, defaults, lists, 'Exploded View')
    return nil unless res
    out = {}
    keys.each_with_index { |k, i| out[k] = res[i].to_s.strip }
    # Only when frames are actually being swept; asking for a folder on a plain
    # explode would be a dialog for nothing.
    if out['frames'].to_i > 0
      out['dir'] = WR_Folder.resolve(out['dir'], 'explode', 'Where should the sweep frames go?')
      return nil if out['dir'].nil?
    end
    keys.each { |k| Sketchup.write_default(PREF, k, out[k]) }
    out
  end

  # ------------------------------------------------------------------- parts --

  # The parts inside a container, whatever KIND of container it is.
  #
  # This is where "select the WhisperRoom and nothing useful happens" came from.
  # A Group answers #entities; a ComponentInstance DOES NOT — its geometry lives
  # on its definition. The old code tested `respond_to?(:entities)`, so selecting
  # a booth that happened to be a component fell through to "treat the selection
  # as the parts", found exactly one part, and moved the whole booth as a lump.
  # Booths built here are groups, which is why it worked most of the time and
  # failed on the ones that came in as components.
  def self.entities_of(e)
    return e.entities if e.is_a?(Sketchup::Group)
    return e.definition.entities if e.is_a?(Sketchup::ComponentInstance)
    nil
  rescue StandardError
    nil
  end

  def self.children_of(e)
    ents = entities_of(e)
    return [] if ents.nil?
    ents.select { |x| x.is_a?(Sketchup::Group) || x.is_a?(Sketchup::ComponentInstance) }
  rescue StandardError
    []
  end

  def self.container?(e)
    e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
  end

  # EDITING A COMPONENT'S INSIDES MOVES EVERY INSTANCE OF IT. A booth built here
  # is a group, so this is normally moot — but a booth brought in as a component
  # and placed twice would explode both copies at once, which is a surprise
  # worth refusing to spring on someone.
  def self.multi_instance?(e)
    e.is_a?(Sketchup::ComponentInstance) && e.definition.instances.length > 1
  rescue StandardError
    false
  end

  def self.parts(model, allow_homed = false)
    sel = model.selection
    if sel.empty?
      if allow_homed
        homed = homed_parts(model)
        return homed unless homed.empty?
      end
      UI.messagebox("Select the assembly first.\n\n" \
                    'Select the WhisperRoom itself — the whole booth — and its parts ' \
                    'are what get pushed out.')
      return nil
    end

    if sel.count == 1 && container?(sel.first)
      subject = sel.first
      if multi_instance?(subject)
        n = subject.definition.instances.length
        go = UI.messagebox("This is a component with #{n} copies in the model.\n\n" \
                           "Exploding it moves the parts INSIDE the definition, so all " \
                           "#{n} copies come apart together.\n\nCarry on?", MB_OKCANCEL)
        return nil if go != IDOK
      end
      # Unwrap redundant nesting. A booth is often a group holding one group
      # holding the parts; stopping at the first level would find a single child
      # and explode nothing. Descend while there is exactly one child and it is
      # itself a container.
      kids = children_of(subject)
      while kids.length == 1 && container?(kids.first)
        inner = children_of(kids.first)
        break if inner.empty?
        subject = kids.first
        kids = inner
      end
      return kids unless kids.empty?

      UI.messagebox("Nothing to explode inside that.\n\n" \
                    'It holds loose geometry rather than separate parts, so there is ' \
                    'nothing to pull apart.')
      return nil
    end

    sel.to_a.select { |e| container?(e) }
  end

  # Where a part started. Recorded the first time it moves, so Reset always has
  # something true to go back to even weeks later.
  def self.home_of(e)
    a = e.get_attribute(DICT, 'home')
    return Geom::Point3d.new(a[0], a[1], a[2]) if a.is_a?(Array) && a.size == 3
    o = e.transformation.origin
    e.set_attribute(DICT, 'home', [o.x.to_f, o.y.to_f, o.z.to_f])
    o
  end

  # Translate only — never touch a part's rotation or scale.
  def self.move_to(e, origin)
    d = origin - e.transformation.origin
    e.transform!(Geom::Transformation.translation(d)) if d.length > 0.0001
  end

  # ------------------------------------------------------------------ vectors --

  # The axis a FLAT part should come off along: its own thinnest one. A wall
  # panel is 1" thick and 81" tall, so it lifts off its wall face; a floor tile
  # is thin in Z, so it drops. Nil when the part is not obviously flat — a corner
  # seal is 4.875" square in plan and has no face to come off — and nil when the
  # part sits on that axis' centre line, because then the thin axis cannot say
  # which WAY to go.
  #
  # This replaced "whichever axis the part is furthest along". That rule read a
  # floor tile at the far end of a long booth as an X part and slid it sideways
  # out of its own deck instead of dropping it.
  def self.flat_axis(box, v, size)
    d = [box.width.to_f, box.height.to_f, box.depth.to_f]
    ord  = (0..2).sort_by { |i| d[i] }
    thin = ord[0]
    return nil unless d[thin] < 0.5 * d[ord[1]]
    return nil unless v.to_a[thin].to_f.abs > 0.01 * size
    thin
  end

  def self.direction(v, box, size, mode)
    return nil if v.length < 0.01
    case mode
    when :radial
      v.normalize
    when :vertical
      Geom::Vector3d.new(0, 0, v.z < 0 ? -1 : 1)
    else
      # One axis, not three: the part's flat axis, or failing that whichever axis
      # it is already furthest along.
      i = flat_axis(box, v, size)
      i ||= (0..2).max_by { |k| v.to_a[k].to_f.abs }
      a = [0.0, 0.0, 0.0]
      a[i] = v.to_a[i].to_f < 0 ? -1.0 : 1.0
      Geom::Vector3d.new(a[0], a[1], a[2])
    end
  end

  # ---------------------------------------------------------------- the work --

  # Place every part at home + offset*factor. factor 0 is fully assembled, 1 is
  # fully exploded, so a sweep is just this called in a loop.
  #
  # The offset is a whole vector rather than direction-and-distance because a
  # part's travel is now two components added together (outward, plus the
  # in-plane fan). Written out component-wise so that factor 0.0 lands on home
  # EXACTLY — x + 0.0 * anything is x — which is what makes Reset exact.
  def self.place(plan, factor)
    plan.each do |p|
      o = p[:off]
      target = Geom::Point3d.new(p[:home].x.to_f + o.x.to_f * factor,
                                 p[:home].y.to_f + o.y.to_f * factor,
                                 p[:home].z.to_f + o.z.to_f * factor)
      move_to(p[:ent], target)
    end
  end

  # Where a part's bounding box SITS AT HOME. Parts are only ever translated by
  # this script, never rotated or scaled, so the home box is simply the current
  # box shifted by (home - where it is now).
  def self.home_bounds(e, home)
    b = e.bounds
    d = home - e.transformation.origin
    return b if d.length < 0.0001
    hb = Geom::BoundingBox.new
    hb.add(b.min.offset(d))
    hb.add(b.max.offset(d))
    hb
  end

  # A wall is not one part. It is three or four panels with a seal between each
  # pair, and every one of them is the same distance along the same axis from the
  # booth centre — so the outward vector alone moves the whole wall away as a
  # single sheet and never separates the panels IN it. That is exactly what "the
  # exploded view doesn't separate parallel walls" meant: opposite walls did come
  # apart (their vectors point opposite ways), co-planar neighbours did not.
  #
  # So after the outward vector is worked out, parts are grouped by (direction,
  # which plane they sit in) and each group is spread about its own centre in the
  # two axes it is NOT travelling along. The panel at the left end of the north
  # wall drifts further left as the wall moves north; the seal near the middle
  # barely drifts; the wall opens out like a fan. A floor deck is the same thing
  # lying down — three tiles that would otherwise drop as one slab.
  #
  # This is NOT redundant with the outward vector and collapsing the two would
  # bring the sheet back. Scaling about the group centre also means the parts keep
  # their order and the gaps only ever grow, so it cannot introduce a new overlap
  # inside a group.
  #
  # `amount` is a fraction of each part's own offset from its group centre, so the
  # spread is proportional: big panels move far, small seals stay near the middle
  # where a reader expects to find them.
  def self.fan_in_plane(plan, size, amount)
    return if amount <= 0.0
    # Same plane means "same coordinate along the travel axis, near enough".
    # 2% of the assembly diagonal keeps a corner seal, which stands about an inch
    # proud of the panels it joins, in with the wall it belongs to.
    tol = 0.02 * size

    plan.group_by { |p| [p[:dir].x.to_f, p[:dir].y.to_f, p[:dir].z.to_f] }.each do |key, mem|
      ax = (0..2).find { |i| key[i] != 0.0 }
      next if ax.nil?                       # radial parts have no single axis
      mem = mem.sort_by { |p| p[:box].center.to_a[ax].to_f }
      runs = [[mem.first]]
      mem.each_cons(2) do |a, b|
        if b[:box].center.to_a[ax].to_f - a[:box].center.to_a[ax].to_f <= tol
          runs.last << b
        else
          runs << [b]
        end
      end

      runs.each do |run|
        next if run.length < 2
        cs = run.map { |p| p[:box].center }
        mid = (0..2).map { |i| cs.map { |c| c.to_a[i].to_f }.inject(:+) / run.length }
        run.each_with_index do |p, i|
          d = (0..2).map do |j|
            j == ax ? 0.0 : (cs[i].to_a[j].to_f - mid[j]) * amount
          end
          p[:off] = Geom::Vector3d.new(p[:off].x.to_f + d[0],
                                       p[:off].y.to_f + d[1],
                                       p[:off].z.to_f + d[2])
        end
      end
    end
  end

  # ------------------------------------------------------- booth structure --
  #
  # WHY THIS EXISTS. The per-part rule below (direction + fan_in_plane) gave
  # every part its OWN travel: distance grew with how far the part sat from the
  # centre, direction came from its own flattest axis, and the fan scaled it
  # about whatever run it fell into. On a real booth (144144 E, Sep 2026) that
  # meant the three panels of one wall went out 127, 144 and 134 in and slid
  # +20, +64 and -23 in along it; the open door leaf — thinnest in X — was sent
  # east as if it were an E-wall panel while its frame went south; the six
  # ceiling panels lifted anywhere from 103 to 133 in; the floor dropped over
  # 100 in and fanned 30-40 in sideways. No wall read as a wall.
  #
  # So a booth is planned as assemblies. Everything here is PURE — arrays of
  # [min, max] home boxes in, offsets out, no SketchUp API — so it runs outside
  # SketchUp (scripts/rbtest-explode.py lifts these methods verbatim).
  #
  # All of it is in the parent's frame, which for a booth is the booth's own
  # axes: walls run along X and Y there whatever way the booth is turned in the
  # model.

  BP_SMALL     = 12.0  # no bigger than this in any direction: hardware, follows its owner
  BP_PANEL_MIN = 15.0  # a wall part at least this wide along the wall is a panel; seals are 2-12.3
  BP_TALL      = 0.4   # of the assembly height: a part this tall is wall
  BP_WIDE      = 0.35  # of the smaller plan side: a flat part this wide is floor or ceiling
  BP_REACH     = 0.5   # wall/ceiling travel = spread x this x the booth's biggest dimension
  BP_GAP       = 0.15  # in-plane gap = travel x fan x this
  BP_FLOOR_GAP = 0.35  # the floor opens out this fraction of the wall gap — "slightly"
  BP_CLEAR     = 6.0   # a wall's end panels never slide further than travel - this

  OUTWARD = { :w => [-1.0, 0.0], :e => [1.0, 0.0], :s => [0.0, -1.0], :n => [0.0, 1.0] }.freeze

  # Offsets for a booth, or nil when the parts do not read as one. `boxes` is
  # [[min xyz], [max xyz]] per part AT HOME. Returns a hash of parallel arrays:
  #   :off   [dx, dy, dz] per part
  #   :kind  :floor / :wall / :corner / :ceiling / :attached
  #   :side  :w/:e/:s/:n for a wall part, [sx, sy] for a corner
  #   :owner the part an :attached part follows (nil for the rest)
  # plus :d (wall/ceiling travel) and :g (in-plane gap between wall panels).
  def self.booth_plan(boxes, spread, fan)
    n = boxes.length
    return nil if n < 4
    mn  = boxes.map { |b| b[0].map(&:to_f) }
    mx  = boxes.map { |b| b[1].map(&:to_f) }
    ext = (0...n).map { |i| (0..2).map { |a| mx[i][a] - mn[i][a] } }
    ctr = (0...n).map { |i| (0..2).map { |a| (mx[i][a] + mn[i][a]) * 0.5 } }
    lo  = (0..2).map { |a| mn.map { |p| p[a] }.min }
    hi  = (0..2).map { |a| mx.map { |p| p[a] }.max }
    h   = hi[2] - lo[2]
    return nil if h < 1.0
    plan_min = [hi[0] - lo[0], hi[1] - lo[1]].min

    # 1. What each part IS, from its shape and height. Floor and ceiling parts
    # must be flat (Z their thinnest axis) as well as wide: a door threshold is
    # low and long but thinnest across the wall, and belongs to the door.
    kind = Array.new(n, :attached)
    (0...n).each do |i|
      e = ext[i]
      next if e.max <= BP_SMALL
      if e[2] >= BP_TALL * h
        kind[i] = :wall
      elsif e[2] <= [e[0], e[1]].min && [e[0], e[1]].max >= BP_WIDE * plan_min
        rel = (ctr[i][2] - lo[2]) / h
        kind[i] = :floor   if rel < 0.25
        kind[i] = :ceiling if rel > 0.75
      end
    end

    # 2. The footprint the walls stand round: the floor's, else the ceiling's,
    # else the walls' own. NOT the whole assembly's — an open door leaf or a
    # duct stack standing proud would pull the centre off.
    src = (0...n).select { |i| kind[i] == :floor }
    src = (0...n).select { |i| kind[i] == :ceiling } if src.empty?
    src = (0...n).select { |i| kind[i] == :wall } if src.empty?
    return nil if src.empty?
    f0 = [0, 1].map { |a| src.map { |i| mn[i][a] }.min }
    f1 = [0, 1].map { |a| src.map { |i| mx[i][a] }.max }
    fc = [0, 1].map { |a| (f0[a] + f1[a]) * 0.5 }
    fh = [0, 1].map { |a| [(f1[a] - f0[a]) * 0.5, 1.0].max }

    # 3. Which wall each tall part belongs to — by WHERE it stands relative to
    # the footprint, not by which way it is thin. A door leaf standing open is
    # thin across the wall it hangs in; its position still says which wall.
    side = Array.new(n)
    (0...n).each do |i|
      next unless kind[i] == :wall
      u = (ctr[i][0] - fc[0]) / fh[0]
      v = (ctr[i][1] - fc[1]) / fh[1]
      if u.abs < 0.5 && v.abs < 0.5
        kind[i] = :attached            # free-standing inside the room
        next
      end
      pmax = [ext[i][0], ext[i][1]].max
      pmin = [[ext[i][0], ext[i][1]].min, 0.01].max
      if pmax < 2.0 * pmin && u.abs > 0.75 && v.abs > 0.75
        kind[i] = :corner
        side[i] = [u < 0 ? -1.0 : 1.0, v < 0 ? -1.0 : 1.0]
      elsif u.abs >= v.abs
        side[i] = u < 0 ? :w : :e
      else
        side[i] = v < 0 ? :s : :n
      end
    end
    walls = [:w, :e, :s, :n].select { |sd| side.include?(sd) }
    return nil if walls.length < 2

    # 4. Travel and gap.
    base = [2.0 * fh[0], 2.0 * fh[1], h].max
    d = spread.to_f * BP_REACH * base
    g = d * fan.to_f * BP_GAP

    # 5. Each wall's panel columns along it. Outer panel, inner skin panel and
    # anything else as wide that stands over the same stretch are ONE column,
    # so the two skins of an Enhanced wall open out together and stay aligned.
    cols = {}
    walls.each do |sd|
      ax  = OUTWARD[sd][0] == 0.0 ? 0 : 1
      mem = (0...n).select { |i| kind[i] == :wall && side[i] == sd }
      pan = mem.select { |i| ext[i][ax] >= BP_PANEL_MIN }.sort_by { |i| ctr[i][ax] }
      cl = []
      pan.each do |i|
        a0 = mn[i][ax]
        a1 = mx[i][ax]
        hit = cl.find do |c|
          ov = [a1, c[3]].min - [a0, c[2]].max
          ov >= 0.5 * [a1 - a0, c[3] - c[2]].min
        end
        if hit
          hit[0] = [hit[0], a0].min
          hit[1] = [hit[1], a1].max
        else
          cl << [a0, a1, a0, a1]
        end
      end
      cols[sd] = [ax, cl.sort_by { |c| c[0] + c[1] }]
    end
    # A wall's end panels must stay inside its neighbours' travel, or they
    # would slide into the next wall. Cap the gap rather than the travel —
    # Spread is the number the user asked for.
    most = cols.values.map { |c| c[1].length }.max.to_i
    g = [g, (d - BP_CLEAR) / ((most - 1) * 0.5)].min if most > 1
    g = 0.0 if g < 0.0

    off = Array.new(n) { [0.0, 0.0, 0.0] }
    (0...n).each do |i|
      if kind[i] == :wall
        sd = side[i]
        ax, cl = cols[sd]
        off[i] = [OUTWARD[sd][0] * d, OUTWARD[sd][1] * d, 0.0]
        off[i][ax] += bp_shift(cl, ctr[i][ax], g)
      elsif kind[i] == :corner
        sx, sy = side[i]
        xw = sx < 0 ? :w : :e          # the wall this corner closes in X...
        yw = sy < 0 ? :s : :n          # ...and in Y
        # Out with BOTH walls, and along each as far as that wall's end panel,
        # so it sits off the corner clear of the two it joins.
        ex = cols[yw] ? bp_shift(cols[yw][1], ctr[i][0], g) : 0.0
        ey = cols[xw] ? bp_shift(cols[xw][1], ctr[i][1], g) : 0.0
        off[i] = [sx * d + ex, sy * d + ey, 0.0]
      end
    end

    # 6. Floor and ceiling open out about the footprint centre. Scaling keeps
    # every piece in order and only ever widens a gap, so it cannot make a new
    # overlap; dividing by the typical panel size makes the gap about the same
    # between rows as between columns.
    [[:floor, g * BP_FLOOR_GAP, 0.0], [:ceiling, g, d]].each do |k, gap, lift|
      mem = (0...n).select { |i| kind[i] == k }
      next if mem.empty?
      kk = [0, 1].map do |a|
        w = mem.map { |i| ext[i][a] }.select { |x| x >= BP_PANEL_MIN }.sort
        w.empty? ? 0.0 : gap / w[w.length / 2]
      end
      mem.each do |i|
        off[i] = [kk[0] * (ctr[i][0] - fc[0]), kk[1] * (ctr[i][1] - fc[1]), lift]
      end
    end

    # 7. Everything else follows the part it is fixed to: the one its box
    # overlaps most (touching counts), else the nearest. Owners are never
    # themselves followers, so nothing chains and nothing is left behind.
    anchors = (0...n).reject { |i| kind[i] == :attached }
    owner = Array.new(n)
    (0...n).each do |i|
      next unless kind[i] == :attached
      best = nil
      bv = 0.0
      bd = nil
      anchors.each do |j|
        vol = 1.0
        gap2 = 0.0
        (0..2).each do |a|
          o = [mx[i][a], mx[j][a]].min - [mn[i][a], mn[j][a]].max
          vol *= [o + 0.25, 0.0].max
          gap2 += o * o if o < 0
        end
        if vol > bv
          best = j
          bv = vol
        elsif bv == 0.0 && (bd.nil? || gap2 < bd)
          best = j
          bd = gap2
        end
      end
      next if best.nil?
      owner[i] = best
      off[i] = off[best].dup
    end

    { :off => off, :kind => kind, :side => side, :owner => owner, :d => d, :g => g }
  end

  # How far a wall part slides ALONG its wall. Column k of n moves (k - mid) x g,
  # so every joint opens by the same g. A part standing over a column (panel,
  # window, door leaf) moves with it exactly; one standing in a joint (a seal)
  # moves in proportion across the gap, which keeps it centred in the widened
  # joint; anything beyond the ends moves with the end column.
  def self.bp_shift(cl, c, g)
    k = cl.length
    return 0.0 if k.zero?
    mid = (k - 1) * 0.5
    cl.each_with_index { |col, j| return (j - mid) * g if c >= col[0] && c <= col[1] }
    return -mid * g if c < cl[0][0]
    return mid * g if c > cl[k - 1][1]
    (0...(k - 1)).each do |j|
      a = cl[j][1]
      b = cl[j + 1][0]
      next unless c > a && c < b
      return (j - mid + (c - a) / (b - a)) * g
    end
    0.0
  end

  def self.plan_for(parts, mode, spread, fan = 0.0)
    homes = parts.map { |e| [e, home_of(e)] }

    # EVERY measurement below is taken from HOME, never from where a part happens
    # to be sitting. The header promises you can re-run at a different spread
    # without resetting first; that promise used to be half true. `centre` and
    # `size` came off `e.bounds` — the CURRENT bounds — so a second explode
    # measured itself against the already-exploded model, `size` grew by better
    # than a factor of two, and everything flew twice as far again. Only the home
    # POSITION was being handled properly. Hence home_bounds.
    boxes = homes.map { |e, h| home_bounds(e, h) }

    bb = Geom::BoundingBox.new
    boxes.each { |b| bb.add(b) }
    centre = bb.center
    size   = bb.diagonal.to_f

    # A booth is planned by assembly (booth_plan). Every part gets a plan entry,
    # including the ones that stay put — a part left out of the plan would keep
    # whatever offset the LAST explode gave it.
    if mode == :axis
      bp = booth_plan(boxes.map { |b| [b.min.to_a, b.max.to_a] }, spread, fan)
      if bp
        up = Geom::Vector3d.new(0, 0, 1)
        plan = homes.each_with_index.map do |(e, h), i|
          o = bp[:off][i]
          k = bp[:kind][i]
          k = bp[:kind][bp[:owner][i]] if k == :attached && bp[:owner][i]
          dir = case k
                when :wall
                  s = bp[:side][bp[:owner][i] || i]
                  Geom::Vector3d.new(OUTWARD[s][0], OUTWARD[s][1], 0)
                when :ceiling then up
                end
          { :ent => e, :home => h, :dir => dir, :dist => (dir ? bp[:d] : 0.0),
            :off => Geom::Vector3d.new(o[0], o[1], o[2]), :box => boxes[i],
            :group => k, :side => bp[:side][bp[:owner][i] || i] }
        end
        return [plan, centre, size, bp]
      end
    end

    vecs = boxes.map { |b| b.center - centre }
    far  = vecs.map { |v| v.length.to_f }.max
    far  = 1.0 if far < 0.01

    plan = []
    homes.each_with_index do |(e, h), i|
      dir = direction(vecs[i], boxes[i], size, mode)
      next if dir.nil?
      # Parts already further out travel further, which keeps the layers from
      # bunching. The 0.35 floor stops near-centre parts sitting on top of
      # everything else.
      reach = 0.35 + 0.65 * (vecs[i].length.to_f / far)
      dist  = size * spread * reach
      off   = Geom::Vector3d.new(dir.x.to_f * dist, dir.y.to_f * dist, dir.z.to_f * dist)
      plan << { :ent => e, :home => h, :dir => dir, :dist => dist,
                :off => off, :box => boxes[i], :vec => vecs[i] }
    end

    # Axis mode only. Radial already separates co-planar neighbours, because no
    # two of them share a direction, and Vertical only means vertical only —
    # sliding panels sideways there would be answering a question nobody asked.
    fan_in_plane(plan, size, spread * fan) if mode == :axis

    [plan, centre, size, nil]
  end

  # Leader lines are gone as a feature, but models drawn before they were
  # removed still carry the group. This sweeps it up so switching Exploded on
  # once cleans the old ones out for good.
  def self.clear_leaders(model)
    n = 0
    model.entities.to_a.each do |e|
      next unless e.is_a?(Sketchup::Group) && e.valid?
      next unless e.layer && e.layer.name == TAG_LEAD
      e.erase!
      n += 1
    end
    n
  end

  # A sweep from assembled to exploded, one PNG per step. The current camera is
  # used as-is — frame the shot before running.
  def self.sweep(model, plan, frames, dir)
    view = model.active_view
    FileUtils.mkdir_p(dir)
    w = 1200
    h = (w * view.vpheight.to_f / view.vpwidth.to_f).round
    written = 0
    frames.times do |k|
      f = frames == 1 ? 1.0 : k.to_f / (frames - 1)
      place(plan, f)
      view.refresh
      path = File.join(dir, format('explode_%02d.png', k))
      Sketchup.status_text = "Explode sweep #{k + 1} of #{frames}"
      written += 1 if view.write_image(:filename => path, :width => w, :height => h,
                                       :antialias => true, :transparent => true)
    end
    Sketchup.status_text = ''
    [written, w, h]
  end

  # ------------------------------------------------------------------- entry --

  # ------------------------------------------------------------- entry points --
  #
  # Three ways in, one body:
  #   run          — asks, then performs. The Ruby Console / menu path.
  #   ability_on   — explode with stored settings, no dialog. The panel's toggle.
  #   ability_off  — put everything back. Also no dialog.
  #
  # The panel toggles this dozens of times in a session, so the ability path must
  # never put a modal in the way. That is the whole reason it exists.

  def self.run
    cfg = ask
    return unless cfg
    perform(cfg)
  end

  def self.ability_on(opts = {})
    perform(stored_cfg(opts).merge('action' => 'Explode', 'frames' => '0'))
  end

  def self.ability_off(opts = {})
    perform(stored_cfg(opts).merge('action' => 'Reset', 'frames' => '0'))
  end

  # Whatever was last saved, with the panel's settings laid over the top.
  def self.stored_cfg(opts)
    base = {}
    DEFAULTS.each_key do |k|
      v = Sketchup.read_default(PREF, k, DEFAULTS[k]).to_s
      base[k] = v.empty? ? DEFAULTS[k] : v
    end
    opts.each { |k, v| base[k.to_s] = v.to_s unless v.nil? || v.to_s.empty? }
    base
  end

  # Every part that has ever been moved carries its home as an attribute, so a
  # reset can find its own work with nothing selected. That matters for a toggle:
  # by the time you switch it off, the selection is usually long gone.
  def self.homed_parts(model)
    found = []
    scan = lambda do |ents, depth|
      return if depth > 3
      ents.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        if e.get_attribute(DICT, 'home').is_a?(Array)
          found << e
        else
          # entities_of, not respond_to?(:entities): a ComponentInstance keeps
          # its parts on its definition, so a booth that is a component was
          # never searched and switching Exploded off put nothing back.
          kids = entities_of(e)
          scan.call(kids, depth + 1) if kids
        end
      end
    end
    scan.call(model.entities, 0)
    found
  end

  def self.perform(cfg)
    model = Sketchup.active_model
    reset = cfg['action'] == 'Reset'

    ps = parts(model, reset)
    return false if ps.nil?
    if ps.size < 2
      UI.messagebox("Only #{ps.size} part found.\n\nSelect a group that CONTAINS the parts, " \
                    "or select several parts.")
      return false
    end

    mode   = if cfg['mode'].start_with?('Radial') then :radial
             elsif cfg['mode'].start_with?('Vertical') then :vertical
             else :axis
             end
    spread = cfg['spread'].to_f / 100.0
    spread = 0.6 if spread <= 0 || spread > 5
    # 0 is a legitimate fan — it is the old sheet-of-panels behaviour — so only
    # a negative or a silly number falls back to the default.
    fan    = cfg['fan'].to_f / 100.0
    fan    = 1.5 if fan < 0 || fan > 10
    frames = cfg['frames'].to_i
    frames = 0 if frames < 0 || frames > 60

    model.start_operation(reset ? 'Reset assembly' : 'Exploded view', true)
    cleared = clear_leaders(model)

    if reset
      # Straight home, with no planning at all: a reset must never depend on
      # classifying the parts the same way the explode did.
      plan = ps.map { |e| { :ent => e, :home => home_of(e) } }
      plan.each { |p| move_to(p[:ent], p[:home]) }
      model.commit_operation
      puts ''
      puts "EXPLODED VIEW — reset #{plan.size} part(s) to home, #{cleared} leader group(s) removed"
      puts ''
      model.active_view.zoom_extents
      return true
    end

    plan, _centre, size, bp = plan_for(ps, mode, spread, fan)
    place(plan, 1.0)
    model.commit_operation

    swept = nil
    if frames > 1
      model.start_operation('Explode sweep', true)
      swept = sweep(model, plan, frames, cfg['dir'].tr('\\', '/'))
      place(plan, 1.0)
      model.commit_operation
    end

    model.active_view.zoom_extents
    report(plan, mode, spread, fan, size, cleared, swept, cfg['dir'], bp)
    true
  rescue StandardError => e
    model.abort_operation if model
    UI.messagebox("Exploded view failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
    false
  end

  def self.report(plan, mode, spread, fan, size, cleared, swept, dir, bp = nil)
    if bp
      groups = Hash.new(0)
      plan.each do |p|
        k = p[:group]
        s = p[:side]
        label = case k
                when :wall then "wall #{s.to_s.upcase}"
                when :corner then 'corner seals'
                when nil, :attached then 'unplaced (stays)'
                else k.to_s
                end
        groups[label] += 1
      end
      puts ''
      puts 'EXPLODED VIEW — booth'
      puts ''
      puts "  #{plan.size} parts, spread #{(spread * 100).round}%, fan #{(fan * 100).round}%"
      puts format('  walls out %.1f", ceiling up %.1f", floor stays; %.1f" gap at every wall joint',
                  bp[:d], bp[:d], bp[:g])
      puts ''
      groups.sort.each { |k, v| puts format('    %-18s %d part(s)', k, v) }
      puts '  (seals, strips and hardware are counted with the part they move with)'
      puts ''
      puts '  Reset puts every part back exactly; re-exploding measures from home.'
      puts ''
      return
    end

    axes = Hash.new(0)
    plan.each do |p|
      d = p[:dir]
      k = if d.x.abs > 0.9 then (d.x > 0 ? '+X' : '-X')
          elsif d.y.abs > 0.9 then (d.y > 0 ? '+Y' : '-Y')
          elsif d.z.abs > 0.9 then (d.z > 0 ? '+Z' : '-Z')
          else 'radial'
          end
      axes[k] += 1
    end

    puts ''
    puts 'EXPLODED VIEW'
    puts ''
    puts "  #{plan.size} parts moved, #{mode} direction, spread #{(spread * 100).round}%"
    puts format('  assembly is %.1f" across; parts travel %.1f" to %.1f"',
                size, size * spread * 0.35, size * spread)
    if mode == :axis
      # The outward component is exactly p[:dist] along an axis, so whatever is
      # left of the offset once that is taken out is the in-plane fan.
      biggest = plan.map do |p|
        sq = (p[:off].length.to_f**2) - (p[:dist]**2)
        sq > 0 ? Math.sqrt(sq) : 0.0
      end.max.to_f
      puts format('  fan %d%%: parts sharing a wall also spread within it, up to %.1f"',
                  (fan * 100).round, biggest)
    end
    puts "  #{cleared} leftover leader group(s) from an older version cleared" if cleared > 0
    puts ''
    puts '  DIRECTIONS'
    axes.sort.each { |k, v| puts format('    %-7s %d part(s)', k, v) }
    puts ''
    if swept
      puts format('  SWEEP: %d frames at %dx%d -> %s', swept[0], swept[1], swept[2], dir)
      puts '  Assembled to exploded, one PNG per step. Current camera, as framed.'
      puts ''
    end
    puts '  Every part stored its home position, so Reset puts it back exactly and'
    puts '  re-running at a different spread measures from home rather than'
    puts '  compounding onto this run. The homes are saved with the model.'
    puts ''
    puts '  Next: Orbit Export for angles — every frame will be of the exploded'
    puts '  assembly. Reset first if you want the assembled version too.'
    puts ''
  end
end

WR_ExplodeView.run unless $wr_no_autorun
