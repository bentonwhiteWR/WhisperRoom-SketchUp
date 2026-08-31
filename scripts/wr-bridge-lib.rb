# Job-side helpers for the WhisperRoom bridge.
#
#   load File.join(WhisperRoom::Tools::SCRIPTS_DIR, 'wr-bridge-lib.rb')
#
# WHY THIS IS NOT IN wr_tools/wr_bridge.rb
#
# wr_tools/ is read from the INSTALLED plugin folder, so every edit there costs
# `python install-plugin.py` plus a SketchUp restart (CLAUDE.md). This file sits
# in scripts/, which main.rb resolves LIVE from the repo checkout, so editing it
# takes effect on the next job with no reinstall and no restart.
#
# So the split is by churn, not by topic: the protocol — claiming, capturing,
# fencing, the result file — is in wr_bridge.rb and is meant to stop changing.
# Test logic, assertion helpers and scratch-model builders are here and are
# meant to keep changing.
#
# Everything here is safe to load repeatedly. Jobs share top-level state across a
# SketchUp session (the bridge evals into TOPLEVEL_BINDING), so a job that is not
# idempotent will misbehave on its second run — this file is written to survive
# being loaded a hundred times in one session.

require 'sketchup.rb'

module WRB
  module_function

  # ------------------------------------------------------------------ paths --

  # The bridge's own art/ directory — the default sink for anything a job
  # writes. It is on the fence's allow-list, which is the point: a job that
  # writes here never has to think about write_roots.
  def art(name = nil)
    d = WhisperRoom::Bridge.dir('art')
    name ? File.join(d, name) : d
  end

  def scripts_dir
    WhisperRoom::Tools::SCRIPTS_DIR
  end

  # `load` a tool from the repo checkout with the autorun globals already set,
  # so loading it defines its methods without also running its normal entry
  # point. Same contract as main.rb's load_quietly, and for the same reason —
  # every tool script ends in a top-level autorun.
  #
  # The bridge already sets both globals for the job's whole extent, so this is
  # belt and braces for a job that asked for suppress_autorun:false and still
  # wants ONE quiet load.
  # NOT EVERY TOOL HONOURS THE GLOBALS, and that is a fact about the scripts
  # rather than a fault in the bridge. explode-view.rb and auto-dimension.rb end
  # in `... unless $wr_no_autorun`; build-room.rb and build-takeoff.rb guard on
  # both globals (since 1.11.0). build-booth.rb and csusb-rooms.rb do not:
  # their last line runs unconditionally, so merely LOADING them opens a
  # dialog or builds geometry (observed 30 Aug 2026).
  #
  # `deaf` is the answer for those. It makes UI::HtmlDialog#show and #show_modal
  # no-ops for the duration of the load, so a tool whose autorun opens a panel
  # can still be loaded for its methods. It is only a load-time muzzle: the
  # dialog object is still built, and anything the job calls afterwards behaves
  # normally.
  def tool(name, deaf = true)
    name = name + '.rb' unless name.end_with?('.rb')
    path = File.join(scripts_dir, name)
    raise ArgumentError, "no such tool script: #{path}" unless File.exist?(path)
    was_no, was_sup = $wr_no_autorun, $wr_suppress_autorun
    $wr_no_autorun = true
    $wr_suppress_autorun = true
    muzzle(deaf) do
      begin
        load path
      ensure
        $wr_no_autorun = was_no
        $wr_suppress_autorun = was_sup
      end
    end
    path
  end

  # Same alias-and-restore shape wr_bridge.rb uses for the modal patch, and the
  # same `unless already` guard for the same reason: if a restore were missed,
  # re-aliasing would capture the MUZZLED method as the original and HtmlDialog
  # would stay silently broken for the rest of the session.
  def muzzle(on)
    return yield unless on && defined?(UI::HtmlDialog)
    names = [:show, :show_modal].select { |m| UI::HtmlDialog.method_defined?(m) }
    names.each do |m|
      saved = :"wrb_orig_#{m}"
      unless UI::HtmlDialog.method_defined?(saved) ||
             UI::HtmlDialog.private_method_defined?(saved)
        UI::HtmlDialog.send(:alias_method, saved, m)
      end
      UI::HtmlDialog.send(:define_method, m) do |*_a|
        puts "  (WRB muzzled UI::HtmlDialog##{m} during a tool load)"
        nil
      end
    end
    begin
      yield
    ensure
      names.each { |m| UI::HtmlDialog.send(:alias_method, m, :"wrb_orig_#{m}") }
    end
  end

  # ------------------------------------------------------------- the model --

  def model
    Sketchup.active_model
  end

  # A census of the active model. The everyday assertion target: run a tool,
  # diff the census.
  def census(ents = nil)
    ents ||= model.entities
    out = Hash.new(0)
    ents.each { |e| out[e.class.name.split('::').last] += 1 }
    out['total'] = ents.length
    out
  end

  # Top-level group and component names, which is what most "did the tool build
  # the thing" checks actually want to see.
  def top_names
    model.entities.map do |e|
      if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        n = e.name.to_s
        n.empty? ? (e.respond_to?(:definition) ? e.definition.name.to_s : '<unnamed>') : n
      end
    end.compact
  end

  # WIPE THE ACTIVE MODEL'S GEOMETRY. Refuses on a saved model — a job may RUN
  # against a real drawing (Benton, 30 Aug 2026) but nothing here is going to
  # empty one. Scratch models only for anything destructive.
  def scratch!
    m = model
    unless m.path.to_s.empty?
      raise WhisperRoom::Bridge::Forbidden,
            "scratch! refuses to clear a saved model (#{m.path}). Open an " \
            'Untitled model, or use a job that only reads.'
    end
    m.start_operation('WRB scratch', true)
    m.entities.clear!
    m.commit_operation
    m.definitions.purge_unused
    m.materials.purge_unused
    census
  end

  # ------------------------------------------------------------- viewport --

  # A viewport PNG into the bridge's art/ folder. Returns the path, so a job can
  # end with `WRB.shot('after.png')` and the client prints where it landed.
  # write_image is fenced by the bridge; a path outside the allow-list raises
  # Forbidden before any file is created.
  def shot(name = 'view.png', width = 1600, height = nil)
    path = name.include?('/') || name.include?('\\') ? name : art(name)
    height ||= (width * 9 / 16)
    v = model.active_view
    v.write_image(:filename => path, :width => width, :height => height,
                  :antialias => true, :transparent => false)
    path
  end

  def zoom_extents
    model.active_view.zoom_extents
    model.active_view.refresh rescue nil
    true
  end

  # ------------------------------------------------------ take-off rooms --

  # Everything the floor-plan scorer needs to compare a built take-off room
  # against truth, per room group, IN THE ROOM'S OWN FRAME (the group stores
  # the origin build-takeoff.rb placed it at; every coordinate here has it
  # subtracted back out, so the numbers line up with the lock polygon and
  # eval/floorplans/<case>/truth.json with no best-fit step). Inches
  # throughout — Length#to_f is inches.
  def takeoff_readback(names = nil)
    out = []
    model.entities.grep(Sketchup::Group).each do |g|
      room_name = g.get_attribute('wr_takeoff', 'room')
      next unless room_name
      next if names && !names.include?(room_name)
      org = g.get_attribute('wr_takeoff', 'origin') || [0.0, 0.0]
      ox = org[0].to_f
      oy = org[1].to_f
      room = { 'name' => room_name, 'origin' => [ox, oy] }

      subs = g.entities.grep(Sketchup::Group)
      if (fg = subs.find { |x| x.name == 'Floor' })
        face = fg.entities.grep(Sketchup::Face).max_by(&:area)
        if face
          room['floor'] = face.outer_loop.vertices.map do |v|
            p = v.position
            [(p.x.to_f - ox).round(4), (p.y.to_f - oy).round(4)]
          end
        end
      end
      if (cg = subs.find { |x| x.name == 'Ceiling' })
        room['ceiling_z'] = cg.bounds.min.z.to_f.round(4)
      end
      if (dg = subs.find { |x| x.name == 'Doors' })
        door_groups = dg.entities.grep(Sketchup::Group)
        room['openings'] = door_groups.select { |x| x.name.start_with?('Opening') }
                                      .map do |og|
          b = og.bounds
          { 'name' => og.name,
            'min' => [(b.min.x.to_f - ox).round(4), (b.min.y.to_f - oy).round(4)],
            'max' => [(b.max.x.to_f - ox).round(4), (b.max.y.to_f - oy).round(4)] }
        end
        room['leaf_count'] = door_groups.count { |x| x.name.start_with?('Door leaf') }
        room['opening_count'] = room['openings'].length
      end
      room['features'] = subs.select { |x| x.layer && x.layer.name == 'WR-Obstruction' }
                             .map do |o|
        b = o.bounds
        { 'name' => o.name,
          'min' => [(b.min.x.to_f - ox).round(4), (b.min.y.to_f - oy).round(4),
                    b.min.z.to_f.round(4)],
          'max' => [(b.max.x.to_f - ox).round(4), (b.max.y.to_f - oy).round(4),
                    b.max.z.to_f.round(4)] }
      end
      room['notes'] = model.entities.grep(Sketchup::Text)
                           .select { |t| t.get_attribute('wr_takeoff', 'room') == room_name }
                           .map(&:text)
      out << room
    end
    out
  end

  # ---------------------------------------------------------- assertions --
  #
  # A failed assertion RAISES, which the bridge turns into status:"error" with a
  # backtrace naming the job line. That is the whole reason these exist rather
  # than returning false: a returned false is a value the client would report as
  # a pass with an odd-looking answer.

  class Failed < StandardError; end

  def assert(cond, msg = 'assertion failed')
    raise Failed, msg unless cond
    true
  end

  def assert_eq(want, got, msg = nil)
    return true if want == got
    raise Failed, (msg ? "#{msg}: " : '') + "expected #{want.inspect}, got #{got.inspect}"
  end

  def assert_gt(floor, got, msg = nil)
    return true if got > floor
    raise Failed, (msg ? "#{msg}: " : '') + "expected more than #{floor}, got #{got.inspect}"
  end

  # Run a named check, catching its failure so a job can report every check
  # rather than stopping at the first. Returns [name, ok, message].
  def check(name)
    yield
    [name, true, 'ok']
  rescue Exception => e
    [name, false, "#{e.class}: #{e.message}"]
  end

  # Roll a list of `check` results into one value, and RAISE if any failed — so
  # the client's exit code is the verdict, not something a human has to read.
  def verdict(results)
    bad = results.reject { |(_n, ok, _m)| ok }
    results.each { |(n, ok, m)| puts format('%-4s %-38s %s', ok ? 'PASS' : 'FAIL', n, m) }
    unless bad.empty?
      raise Failed, "#{bad.size} of #{results.size} checks failed: " +
                    bad.map { |(n, _o, m)| "#{n} (#{m})" }.join('; ')
    end
    { 'checks' => results.size, 'failed' => 0 }
  end
end
