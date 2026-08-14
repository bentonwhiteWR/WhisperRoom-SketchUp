# @title Exploded View...
# @cat Room tools
# @ability Exploded
# @ability-blurb Pull the selected assembly apart; switch off to put it back.
# @setting mode   choice  Axis|Radial|Vertical  Direction
# @setting spread number  60                   Spread (%)
# @setting leads  choice  Yes|No               Leader lines
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
# Parts move along ONE axis each — whichever they are already furthest along —
# so a booth's panels come straight off their walls and the ceiling straight up.
# Radial drift looks fine in a viewport and awful on a page.
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
    'leads'  => 'Yes',
    'frames' => '0',
    'dir'    => 'C:/Users/bento/Desktop/ProposalFiles/PartArt'
  }.freeze

  # ------------------------------------------------------------------- input --

  def self.ask
    keys  = %w[action mode spread leads frames dir]
    prompts = ['Action', 'Direction', 'Spread (%)', 'Leader lines',
               'Sweep frames (0 = none)', 'Output folder']
    defaults = keys.map { |k| v = Sketchup.read_default(PREF, k, DEFAULTS[k]).to_s
                              v.empty? ? DEFAULTS[k] : v }
    lists = ['Explode|Reset',
             'Axis (one axis per part)|Radial|Vertical only',
             '', 'Yes|No', '', '']
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

  # The direct children of whatever is selected. Top-level parts are what a
  # manual shows; nesting deeper just produces confetti.
  # allow_homed: on a reset, fall back to every part that already carries a home
  # attribute rather than demanding a selection that no longer exists.
  def self.parts(model, allow_homed = false)
    sel = model.selection
    if sel.empty?
      if allow_homed
        homed = homed_parts(model)
        return homed unless homed.empty?
      end
      UI.messagebox("Select the assembly first.\n\n(Or select several parts.)")
      return nil
    end
    if sel.count == 1 && sel.first.respond_to?(:entities)
      kids = sel.first.entities.select { |e|
        e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      }
      return kids unless kids.empty?
    end
    sel.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
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

  def self.direction(v, mode)
    return nil if v.length < 0.01
    case mode
    when :radial
      v.normalize
    when :vertical
      Geom::Vector3d.new(0, 0, v.z < 0 ? -1 : 1)
    else
      # Whichever axis the part is already furthest along. One axis, not three.
      cand = [[v.x.abs, Geom::Vector3d.new(v.x < 0 ? -1 : 1, 0, 0)],
              [v.y.abs, Geom::Vector3d.new(0, v.y < 0 ? -1 : 1, 0)],
              [v.z.abs, Geom::Vector3d.new(0, 0, v.z < 0 ? -1 : 1)]]
      cand.max_by { |m, _| m }[1]
    end
  end

  # ---------------------------------------------------------------- the work --

  # Place every part at home + offset*factor. factor 0 is fully assembled, 1 is
  # fully exploded, so a sweep is just this called in a loop.
  def self.place(plan, factor)
    plan.each do |p|
      target = p[:home].offset(p[:dir], p[:dist] * factor)
      move_to(p[:ent], target)
    end
  end

  def self.plan_for(parts, mode, spread)
    homes = parts.map { |e| [e, home_of(e)] }

    # Centre and size from HOME positions, so a re-explode is not measured off
    # an already-exploded model.
    bb = Geom::BoundingBox.new
    parts.each { |e| bb.add(e.bounds) }
    centre = bb.center
    size   = bb.diagonal.to_f

    vecs = homes.map { |e, h| e.bounds.center - centre }
    far  = vecs.map { |v| v.length.to_f }.max
    far  = 1.0 if far < 0.01

    plan = []
    homes.each_with_index do |(e, h), i|
      dir = direction(vecs[i], mode)
      next if dir.nil?
      # Parts already further out travel further, which keeps the layers from
      # bunching. The 0.35 floor stops near-centre parts sitting on top of
      # everything else.
      reach = 0.35 + 0.65 * (vecs[i].length.to_f / far)
      plan << { :ent => e, :home => h, :dir => dir,
                :dist => size * spread * reach, :vec => vecs[i] }
    end
    [plan, centre, size]
  end

  def self.leaders(model, plan)
    t = model.layers[TAG_LEAD] || model.layers.add(TAG_LEAD)
    (t.color = Sketchup::Color.new(150, 150, 158)) rescue nil
    g = model.entities.add_group
    g.name = 'Explode leaders'
    g.layer = t
    n = 0
    plan.each do |p|
      a = p[:ent].bounds.center
      b = a.offset(p[:dir], -p[:dist])
      next if a.distance(b) < 0.5
      begin
        edge = g.entities.add_line(b, a)
        edge.soft = false if edge
        n += 1
      rescue StandardError
      end
    end
    g.erase! if n.zero? && g.valid?
    n
  end

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
    frames = cfg['frames'].to_i
    frames = 0 if frames < 0 || frames > 60

    model.start_operation(reset ? 'Reset assembly' : 'Exploded view', true)
    cleared = clear_leaders(model)

    plan, centre, size = plan_for(ps, mode, spread)

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
    leads = (cfg['leads'] == 'Yes') ? leaders(model, plan) : 0
    model.commit_operation

    swept = nil
    if frames > 1
      model.start_operation('Explode sweep', true)
      swept = sweep(model, plan, frames, cfg['dir'].tr('\\', '/'))
      place(plan, 1.0)
      model.commit_operation
    end

    model.active_view.zoom_extents
    report(plan, mode, spread, size, leads, cleared, swept, cfg['dir'])
    true
  rescue StandardError => e
    model.abort_operation if model
    UI.messagebox("Exploded view failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
    false
  end

  def self.report(plan, mode, spread, size, leads, cleared, swept, dir)
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
    puts "  #{leads} leader line(s) on #{TAG_LEAD}" if leads > 0
    puts "  #{cleared} old leader group(s) cleared" if cleared > 0
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

WR_ExplodeView.run
