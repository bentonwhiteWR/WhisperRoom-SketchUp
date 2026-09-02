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
# Parts move along ONE axis each — off the face they are flattest against — so a
# booth's panels come straight off their walls and the ceiling straight up.
# Radial drift looks fine in a viewport and awful on a page.
#
# On top of that outward move, parts that share a wall FAN apart from each other
# in the plane of that wall (see fan_in_plane). Without it a wall slides away as
# one sheet and its own panels never separate, which is the thing that made the
# first version of this look wrong.
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

    [plan, centre, size]
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
          kids = (e.respond_to?(:entities) ? e.entities : nil) rescue nil
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

    plan, centre, size = plan_for(ps, mode, spread, fan)

    if reset
      place(plan, 0.0)
      model.commit_operation
      puts ''
      puts "EXPLODED VIEW — reset #{plan.size} part(s) to home, #{cleared} leader group(s) removed"
      puts ''
      model.active_view.zoom_extents
      return true
    end

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
    report(plan, mode, spread, fan, size, cleared, swept, cfg['dir'])
    true
  rescue StandardError => e
    model.abort_operation if model
    UI.messagebox("Exploded view failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
    false
  end

  def self.report(plan, mode, spread, fan, size, cleared, swept, dir)
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
