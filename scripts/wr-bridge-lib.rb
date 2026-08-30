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
  # in `... unless $wr_no_autorun`. build-room.rb, build-booth.rb and
  # csusb-rooms.rb do not: their last line runs unconditionally, so merely
  # LOADING them opens a dialog or builds geometry (observed 30 Aug 2026).
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
