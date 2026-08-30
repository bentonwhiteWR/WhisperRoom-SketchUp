# @title Proposal package...
# @cat V-Ray renders
# @rank 0
#
# One button for a proposal's whole image set. Lists every scene in the model,
# lets each one be marked Skip / Image / Render, picks an output folder, and
# writes `<Scene Name>.png` (plain SketchUp export) or `<Scene Name> render.png`
# (V-Ray) into that folder — leaving the model exactly as it was.
#
# Spec and clickable mockup: .forge/scoper/vray-proposal-package-spec.md and
# vray-proposal-mockup.html. The design decisions live there; the short form:
#
#   - Marks are stored ON EACH SCENE (attribute dict on the Sketchup::Page), so
#     they survive a save, a reopen, and a scene-tab reorder. Unmarked = Skip.
#   - The FILE column shows the EXACT name each row will write — sanitised,
#     " render" suffixed, collision-numbered — before anything is written. The
#     names are computed in Ruby, by the same method the export uses, and
#     pushed to the window; the column can never disagree with the disk.
#   - TWO PASSES, ONE MODE SWAP EACH WAY. Image rows export in DRAFT mode
#     (drafting materials — a plain export of render materials is neither one
#     thing nor the other), then render rows in RENDER mode. Model state is
#     changed only through WR_Mode, and the FINISH block — reached on success,
#     on failure and on cancel alike — restores mode, scene and camera. There
#     is no code path out of the batch that skips it.
#   - PLAIN IMAGES GET THE wr-shading.rb CONTRACT BY DEFAULT (DisplayShadows
#     off, Light 80 / Dark 45, ground/horizon/fog/watermark/AO off). V-Ray
#     lights cannot brighten a plain export; this contract is what makes one
#     read well. One checkbox turns it off; it is pushed after the draft swap
#     and popped before anything else changes mode, so it never leaks into a
#     mode snapshot.
#   - THE V-RAY LANE IS GATED, NOT ASSUMED. probe-vray.rb has now been run
#     live (27 Aug 2026, SketchUp 2026): VRay::Context.active is NON-NIL even
#     cold, `state` returned :idleInitialized, and the DR pair in_process? /
#     dr_enabled? RAISE on this machine — see the completion-classification
#     section below. When render rows are planned and VRay::Context.active is
#     nil, this tool still REFUSES BY NAME and offers to export the image
#     rows only — never a half-run. That refusal now proves only that V-Ray
#     is absent entirely; a non-nil context proves presence, not readiness.
#
# The batch is a state machine stepped by UI.start_timer, not a blocking loop:
# SketchUp runs Ruby on the UI thread, and a long `each` would freeze the
# window so progress never paints and Cancel can never be clicked.
#
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/proposal-package.rb"
#
# LIVE STATUS (2026-08-28): THE BATCH HAS RUN LIVE, on UTHealthSciences
# Audiology (12 scenes, 5 render / 7 image). The IMAGE lane is good. The
# RENDER lane failed two ways and both are fixed below — unrun since:
#
#   1. It wrote five EMPTY framebuffers (1,271 bytes, 640x480, every pixel
#      transparent), because IDLE_STATE = /idle/i called a renderer that had
#      never started "finished". Now: ONLY :idleDone finishes, and only after
#      the row has been SEEN RUNNING. See the completion section.
#   2. It rendered the WRONG SCENE — the one selected BEFORE the row. A
#      scene switch ANIMATES the camera over TransitionTime (1 s default) and
#      V-Ray snapshots the model ~0.22 s after start. Now: transitions are 0
#      for the batch, the camera is set from the page, and the two are
#      compared before start. See the camera-settling section.
#
# The 640x480 was V-Ray's own Asset Editor output size, which this tool does
# not set and has no known-safe way to set; it now WARNS about it in the log
# before the first render row.
#
# EARLIER STATUS (2026-08-27): the DIALOG has opened once in SketchUp 2026 —
# loaded from the Ruby Console with $wr_no_autorun cleared, WR_ProposalPackage
# .run showed the window (observed by Benton). The BATCH — the export/render
# machinery, wr-mode.rb, wr-materials-swap.rb under it — has still never run.
# Everything else is parsed with rbparse.py (real syntax check) and, for the
# filename/collision logic, the render-state classifier and the entry guards,
# executed against fixtures through SketchUp's own CRuby DLL
# (rbtest-proposal.py). probe-vray.rb HAS run live; its observations are
# folded in below.

require 'sketchup.rb'
require 'json'
require 'fileutils'

# The saved flag lives in a LOCAL, never in a shared global. This was the
# bug that made the panel button do nothing at all (2026-08-27, observed):
# the old `$wr_no_autorun_was = $wr_no_autorun` was the same global that
# wr-preflight.rb and wr-mode.rb use for their own save/restore dance, so the
# nested loads below CLOBBERED the saved nil with true, the ensure "restored"
# $wr_no_autorun to true, and the autorun line at the bottom of this file
# never fired — no dialog, no error, nothing. A local cannot be touched by a
# nested load. (wr-preflight.rb / wr-mode.rb / wr-pack-export.rb still carry
# the global-temp idiom; flagged for a separate pass, not fixed from here.)
wr_pp_autorun_was = $wr_no_autorun
$wr_no_autorun = true
begin
  load File.join(File.dirname(__FILE__), 'wr-preflight.rb')   # pulls in wr-mode.rb,
  load File.join(File.dirname(__FILE__), 'export-scenes.rb')  # wr-materials-swap.rb,
  load File.join(File.dirname(__FILE__), 'wr-folder.rb')      # wr-shading.rb
ensure
  $wr_no_autorun = wr_pp_autorun_was
end

module WR_ProposalPackage
  %w[DICT PREF FORBIDDEN FOLDER_KEY SLOT_LABEL
     IDLE_STATE DONE_STATE ERROR_STATE RENDER_TIMEOUT_S UNREADABLE_LIMIT
     START_WINDOW_S STOP_CONFIRM_S CAM_FIELDS
     ASPECT_W ASPECT_H EV_F_NUMBER EV_ISO EV_INTERIOR EV_ROOM EV_MIN EV_MAX
     INTERIOR_RE MODE_FALLBACK QUALITY ANNOT_TAGS].each do |c|
    remove_const(c) if const_defined?(c, false)
  end

  DICT       = 'WR_ProposalPackage'.freeze
  PREF       = 'WR_ProposalPackage'.freeze
  FOLDER_KEY = 'package'.freeze

  # Only what Windows genuinely refuses — export-scenes.rb's rule, verbatim.
  FORBIDDEN = /[<>:"\/\\|?*\x00-\x1f]/.freeze

  # Human label for each drafting material, for the slot rows. The slots and
  # their draft names come from WR_MaterialsSwap — the one owner of that table.
  SLOT_LABEL = { WR_MaterialsSwap::DRAFT_FLOOR => 'Floor',
                 WR_MaterialsSwap::DRAFT_WALL  => 'Walls',
                 WR_MaterialsSwap::DRAFT_DOOR  => 'Door' }.freeze

  # ------------------------------------------------- output shape (D4) --
  #
  # ONE aspect for the whole package. Before 1.9.3 the two lanes disagreed:
  # the image lane took its height from the SketchUp window (1200 -> 1200x475
  # on 30 Aug 2026) and the render lane took whatever the V-Ray Asset Editor
  # was set to. Now both are derived from the Width field and this ratio --
  # export-scenes.rb gets an explicit cfg['height'], and the V-Ray SCENE's
  # /SettingsOutput is written to the same numbers (see apply_output_size).
  ASPECT_W = 4
  ASPECT_H = 3

  # --------------------------------------------------- exposure (D2) --
  #
  # OBSERVED 30 Aug 2026, seven bracket renders: V-Ray's physical camera is
  # the only exposure control that does anything here. /CameraPhysical's
  # :exposure_value reads 0.0 and is NOT used by this build; the effective
  # exposure comes from f_number, shutter_speed and ISO:
  #
  #     EV100 = log2(f_number**2 * shutter_speed)   at ISO 100
  #
  # V-Ray's defaults f/8 @ 1/300 give EV 14.23, which renders this rig's
  # booth interior nearly black. (ISO was READ BACK LIVE on 30 Aug 2026 as
  # 100.0 -- the parameter key is :ISO, not :iso, which is why the first pass
  # read nil and had to assume it. The EV numbers below are therefore
  # measured, not assumed.)
  #
  # AND NO SINGLE VALUE SERVES BOTH KINDS OF VIEW. The ambient downlights
  # carry ~8x the booth interior light, so:
  #
  #     booth interior   EV  9   (EV 12 leaves it dark)
  #     room / exterior  EV 12   (EV  9 clips the room to white -- that is
  #                               exactly the unusable image of pass 1)
  #
  # So exposure is PER ROW, not per batch. Each page carries an optional 'ev'
  # attribute; a page without one gets EV_INTERIOR if its name reads like an
  # interior view, else EV_ROOM. The value used is logged for every render
  # row so it is auditable after the fact.
  EV_F_NUMBER = 8.0
  EV_ISO      = 100.0
  EV_INTERIOR = 9.0
  EV_ROOM     = 12.0
  EV_MIN      = 2.0     # refuse absurd stored values rather than render them
  EV_MAX      = 20.0
  INTERIOR_RE = /interior|inside|in-booth|booth\s+in/i

  # ---------------------------------------------- render quality (D3) --
  #
  # Pass 1 rendered on STOCK V-Ray sampler settings and no denoiser, and
  # every surface came out crawling with orange speckle and fireflies. These
  # are now OWNED: written into the V-Ray scene before the render rows, read
  # back, and restored in finish. Values read back live 30 Aug 2026 before
  # any change (the "was" column) --
  #
  #   /RenderChannelDenoiser  enabled            false -> true
  #                           mode 2 / engine 0 / strength 1.0 left as found;
  #                           the plugin already EXISTS in every V-Ray scene,
  #                           it was simply switched off.
  #   /SettingsImageSampler   type 3 = progressive, so the PROGRESSIVE keys
  #                           are the ones that govern:
  #                           progressive_threshold   0.04 -> 0.01
  #                           progressive_maxSubdivs    20 -> 100
  #                           progressive_maxTime      0.0 -> 6.0 (minutes;
  #                             0 means "no limit" -- a budget, so a hard
  #                             scene ends noisy instead of never)
  #                           min_shade_rate             6 -> 8
  #   /SettingsOptions        progressive_noise_limit 0.04 -> 0.01
  #   /SettingsRTEngine       noise_threshold         0.04 -> 0.01
  #                           max_sample_level         400 -> 800
  #
  # RTEngine governs the interactive/GPU engine rather than this production
  # path; it is set anyway so the floor holds whichever engine runs.
  # [plugin, key, value] -- every one read back after the write, and a write
  # that does not stick is named, not swallowed.
  QUALITY = [
    ['/RenderChannelDenoiser', :enabled,                 true],
    ['/SettingsImageSampler',  :progressive_threshold,   0.01],
    ['/SettingsImageSampler',  :progressive_maxSubdivs,  100],
    ['/SettingsImageSampler',  :progressive_maxTime,     6.0],
    ['/SettingsImageSampler',  :min_shade_rate,          8],
    ['/SettingsOptions',       :progressive_noise_limit, 0.01],
    ['/SettingsRTEngine',      :noise_threshold,         0.01],
    ['/SettingsRTEngine',      :max_sample_level,        800]
  ].freeze

  # -------------------------------------------- client-safe output (D5) --
  #
  # Every tag that carries construction annotation. WR_Mode owns the list
  # (DIM_TAGS + WR-Notes since 1.9.3); named here only so the client-safe
  # image pass and the mode machinery cannot drift apart.
  ANNOT_TAGS = WR_Mode::ANNOT_TAGS

  # F3 (render-lane audit) -- where a model goes when it started in no mode
  # at all. WR_Mode.current returns 'unknown (never toggled)' on a model with
  # no WR_Mode dictionary, and until 1.9.3 finish simply SKIPPED the restore
  # on that value: OBSERVED 30 Aug 2026, the model was left sitting in RENDER
  # mode after the batch, silently. Draft is the shop's resting state.
  MODE_FALLBACK = 'draft'.freeze

  # -------------------------------------------------------------- marking --

  # 'render' / 'image' / 'skip'. Stored on the page itself so a mark survives
  # save, reopen and tab reorder (precedent: wr-pack-export.rb's vray flag).
  # Key absent means skip — the default and the safe one.
  def self.mode_of(page)
    m = page.get_attribute(DICT, 'mode', nil).to_s
    %w[render image].include?(m) ? m : 'skip'
  rescue StandardError
    'skip'
  end

  def self.set_mode(page, mode)
    if %w[render image].include?(mode)
      page.set_attribute(DICT, 'mode', mode)
    else
      d = page.attribute_dictionary(DICT, false)
      d.delete_key('mode') if d
    end
  end

  # ------------------------------------------------------ per-row exposure --

  # The EV a render row is exposed at, stored on the page beside its mode so
  # it survives save, reopen and tab reorder. A page with no stored value
  # falls back to the documented defaults -- interior views EV_INTERIOR,
  # everything else EV_ROOM -- chosen from the SCENE NAME, which is the only
  # thing this tool knows about the view without rendering it. That fallback
  # is a default, not a guess dressed up as a measurement: the value actually
  # used is written into the run log for every render row.
  def self.ev_of(page)
    raw = page.get_attribute(DICT, 'ev', nil)
    ev_for(page.name.to_s, raw)
  rescue StandardError
    EV_ROOM
  end

  def self.set_ev(page, ev)
    if ev.nil?
      d = page.attribute_dictionary(DICT, false)
      d.delete_key('ev') if d
    else
      page.set_attribute(DICT, 'ev', ev.to_f)
    end
  end

  # PURE -- proven offline by rbtest-proposal.py.
  #
  # `x * 1.0` and not `x.to_f`, here and in the two methods below, and that is
  # deliberate: rbtest-proposal.py runs these in the barebones Ruby VM
  # rbparse.py boots out of SketchUp's own DLL, and in that VM Float#to_f is
  # NOT DEFINED (Integer#to_f is). Observed 30 Aug 2026: `(10.5).to_f` raises
  # NoMethodError there while `3.to_f` returns 3.0. A `.to_f` in a pure method
  # is therefore a method that cannot be tested offline, which is worse than
  # the small ugliness of multiplying by one.
  def self.ev_for(scene_name, stored)
    if stored.is_a?(Numeric)
      v = stored * 1.0
      return v if v >= EV_MIN && v <= EV_MAX
    end
    return EV_INTERIOR if scene_name.to_s =~ INTERIOR_RE
    EV_ROOM
  end

  # PURE. EV100 = log2(f_number**2 * shutter_speed) at ISO 100, so the
  # shutter that lands a wanted EV is 2**(EV - log2(f**2)). At f/8 that is
  # 2**(EV - 6): EV 9 -> 8, EV 12 -> 64, EV 14.23 -> 300 (V-Ray's default,
  # which is how this formula was checked against the shipped numbers).
  def self.shutter_for_ev(ev, f_number = EV_F_NUMBER)
    f = f_number * 1.0
    2.0**((ev * 1.0) - (Math.log(f * f) / Math.log(2.0)))
  end

  # PURE. The inverse, used to report the EV that ACTUALLY landed after the
  # write is read back -- never the EV that was asked for.
  def self.ev_of_camera(f_number, shutter)
    return nil unless f_number.is_a?(Numeric) && shutter.is_a?(Numeric)
    f = f_number * 1.0
    sp = shutter * 1.0
    return nil if f <= 0.0 || sp <= 0.0
    Math.log((f * f) * sp) / Math.log(2.0)
  end

  # PURE. F3: where the model goes at the end of a batch. WR_Mode.current
  # returns 'unknown (never toggled)' on a model that has never been toggled,
  # and that value used to make finish SKIP the restore in silence -- OBSERVED
  # 30 Aug 2026, model left in RENDER mode. Anything that is not a real mode
  # now resolves to MODE_FALLBACK and the summary SAYS so.
  def self.mode_restore_target(saved_mode)
    %w[draft render].include?(saved_mode.to_s) ? saved_mode.to_s : MODE_FALLBACK
  end

  # PURE. One width in, the package's whole output size out -- used for BOTH
  # lanes (D4).
  def self.package_size(width)
    w = width.to_s.to_i
    w = 1200 if w < 200 || w > 6000
    [w, (w * ASPECT_H / ASPECT_W.to_f).round]
  end

  # ---------------------------------------------------------------- naming --

  def self.sanitize(s)
    out = s.to_s.strip.gsub(FORBIDDEN, '-')
    out.sub(/[. ]+\z/, '')      # Windows silently drops a trailing dot or space
  end

  # First caller gets the base name; later callers get "base (2)", "base (3)".
  # The FINAL name is what goes into `used`, so a scene literally named
  # "X (2)" cannot silently collide with a numbered one either.
  def self.uniquify(base, used)
    final = base
    k = 1
    while used.key?(final)
      k += 1
      final = "#{base} (#{k})"
    end
    used[final] = true
    final
  end

  # rows: [{'n'=>Integer, 'scene'=>String, 'mode'=>'skip'|'image'|'render'}]
  # in pages order. Returns { n => 'file.png' } for every non-skip row.
  # ONE collision map across BOTH lanes, and the " render" suffix goes on
  # AFTER sanitising (the suffix contains no forbidden characters) — so
  # "05-plan" marked render and a scene named "05-plan render" marked image
  # feed the same map and the second one gets "(2)", visibly, in the FILE
  # column before anything is written.
  def self.plan_names(rows)
    used = {}
    out  = {}
    rows.each do |r|
      next if r['mode'] == 'skip'
      base = sanitize(r['scene'])
      base = "scene-#{r['n']}" if base.empty?
      base += ' render' if r['mode'] == 'render'
      out[r['n']] = "#{uniquify(base, used)}.png"
    end
    out
  end

  # ----------------------------------------------------------------- state --

  # each_with_index over model.pages and nothing re-sorts it — the number IS
  # the position in the scene tabs, same as every exporter (list-scenes rule).
  def self.gather(model)
    model.pages.to_a.each_with_index.map do |page, i|
      { 'n' => i + 1, 'scene' => page.name.to_s, 'mode' => mode_of(page) }
    end
  end

  def self.slot_rows(model)
    WR_MaterialsSwap::SLOT_FOR.map do |draft, slot|
      { 'slot' => slot, 'draft' => draft,
        'label' => SLOT_LABEL[draft] || draft,
        'fill'  => WR_MaterialsSwap.fill(model, slot) }
    end
  end

  def self.state(model)
    rows  = gather(model)
    files = plan_names(rows)
    rows.each { |r| r['file'] = files[r['n']].to_s }
    { 'rows'      => rows,
      'slots'     => slot_rows(model),
      'materials' => (model.materials.map(&:name).sort rescue []) }
  end

  def self.push_state(model, dlg)
    dlg.execute_script("applyState(#{state(model).to_json})")
  rescue StandardError => e
    puts "  could not refresh the window: #{e.class}: #{e.message}"
  end

  # ------------------------------------------------------------ v-ray gate --

  # OBSERVED (probe-vray.rb, 27 Aug 2026, SketchUp 2026): VRay::Context.active
  # is NON-NIL in a cold session, before any render. So a nil here means V-Ray
  # is genuinely absent (not installed / not enabled) and the refusal by name
  # is right — but a non-nil context is a WEAK guarantee: it proves V-Ray is
  # loaded, not that a render will succeed (the same probe showed this very
  # context's renderer raising from its DR methods). Every VRay:: call in this
  # file still sits behind this gate and inside its own rescue.
  def self.vray_context
    return nil unless defined?(VRay)
    VRay::Context.active
  rescue Exception
    nil
  end

  # --------------------------------------------------- v-ray parameters --
  #
  # Everything this tool writes into V-Ray goes through these three methods,
  # for one reason: a V-Ray parameter write DOES NOT NECESSARILY STICK. The
  # lighting lane learned that the hard way (wr-drop-lights.rb, 1.9.1) --
  # a bare plugin[key] = value outside VRay::Scene#change is re-synced away
  # and reads back as the factory default minutes later. So every write here
  # happens inside ONE `scene.change`, and every write is READ BACK. A value
  # that did not land is named, never assumed.

  def self.vray_scene(ctx)
    return nil if ctx.nil? || !ctx.respond_to?(:scene)
    ctx.scene
  rescue Exception
    nil
  end

  # Snapshot [plugin, key] pairs so finish can put them back. :absent means
  # the plugin is not in this scene; :unreadable means the read raised.
  def self.read_params(scene, pairs)
    out = {}
    pairs.each do |plname, key|
      pl = (scene[plname] rescue nil)
      out[[plname, key]] = pl.nil? ? :absent : (pl[key] rescue :unreadable)
    end
    out
  end

  # Write [plugin, key, value] triples and read every one back.
  # Returns [applied_hash, problems_array]; problems is empty on success.
  def self.write_params(scene, triples)
    begin
      scene.change do
        triples.each do |plname, key, val|
          pl = (scene[plname] rescue nil)
          next if pl.nil?
          pl[key] = val
        end
      end
    rescue Exception => e
      return [{}, ["VRay::Scene#change raised #{e.class}: #{e.message}"]]
    end
    applied  = {}
    problems = []
    triples.each do |plname, key, val|
      pl = (scene[plname] rescue nil)
      if pl.nil?
        problems << "#{plname} is not in this V-Ray scene - #{key} was NOT set"
        next
      end
      got = (pl[key] rescue :unreadable)
      applied["#{plname}[#{key}]"] = got
      ok = if val.is_a?(Numeric) && got.is_a?(Numeric)
             (got.to_f - val.to_f).abs <= (val.to_f.abs * 0.001 + 0.000001)
           else
             got == val
           end
      unless ok
        problems << "#{plname}[#{key}] DID NOT STICK - wrote #{val.inspect}, " \
                    "read back #{got.inspect}"
      end
    end
    [applied, problems]
  end

  # Put a read_params snapshot back. Best effort by design (it runs in
  # finish, where a raise must not strand the model), but every failure is
  # returned so finish can report it.
  def self.restore_params(scene, saved)
    return [] if scene.nil? || saved.nil? || saved.empty?
    triples = saved.reject { |_k, v| v == :absent || v == :unreadable }
                   .map { |(plname, key), v| [plname, key, v] }
    return [] if triples.empty?
    _applied, problems = write_params(scene, triples)
    problems
  rescue Exception => e
    ["V-Ray restore raised #{e.class}: #{e.message}"]
  end

  # ------------------------------------------- render completion signals --
  #
  # OBSERVED (probe-vray.rb, 27 Aug 2026, cold idle renderer, no render yet):
  #
  #   renderer.state           -> :idleInitialized
  #   renderer.sequence_ended? -> true
  #   renderer.in_process?     -> RAISES StandardError "Incorrect DR version"
  #   renderer.dr_enabled?     -> RAISES the same
  #
  # in_process? and dr_enabled? are the distributed-rendering pair, and on
  # this machine they raise even on an idle renderer with DR never used.
  # NOTHING in this file may call them, and nothing may gate the batch on
  # them — `state` is the completion signal, `sequence_ended?` the backup.
  #
  # The state vocabulary is now OBSERVED IN FULL (Benton, live SketchUp
  # 2026, 28 Aug 2026, a 0.25 s state watcher across a hand render):
  #
  #   :idleStopped      sequence_ended? true    stopped
  #   :idleInitialized  sequence_ended? true    cold, never started
  #   :preparing        sequence_ended? false   starting up
  #   :rendering        sequence_ended? false   actively rendering
  #   :idleDone         sequence_ended? true    FINISHED - a frame exists
  #
  # Timing from that watch: :idleInitialized 11:56:10.735 -> :preparing
  # 11:56:11.176 (440 ms lead-in) -> :rendering 11:56:11.432 -> :idleDone
  # 12:01:37.674 (5m26s total).
  #
  # THREE of the five match /idle/i, which is what the old IDLE_STATE test
  # matched, so a renderer that had never started read as FINISHED on the
  # first tick past START_GRACE_S. That is the 28 Aug bug: five 1,271-byte
  # 640x480 fully transparent PNGs, mtimes 3.17 s apart - the grace window
  # plus one tick, not a render. The rules now:
  #
  #   - ONLY :idleDone means finished.
  #   - :idleStopped / :idleInitialized are idle-but-not-done.
  #   - anything else (:preparing, :rendering, any state never seen) is
  #     RUNNING - unknown still means running, as before.
  #   - and a finished verdict is only ever accepted once the row has been
  #     seen RUNNING at least once (the latch). sequence_ended? is true on
  #     a cold renderer too, so the backup path needs the same latch.
  IDLE_STATE = /\Aidle/i          # the idle family: stopped/initialized/done
  DONE_STATE = /\AidleDone\z/i    # the ONLY value that means a frame exists

  # F1 (render-lane audit, 2026-08-28) -- FIXED 1.9.2, 30 Aug 2026.
  #
  # The five states above are the five a hand render happened to pass
  # through. The V-Ray 7 YARD docs on this machine
  # (C:\Program Files\Chaos\V-Ray\V-Ray for SketchUp\extension\
  # documentation\VRay/VRayRenderer.html#state-instance_method, generated
  # 29 Apr 2026 -- OBSERVED) document TEN:
  #
  #   :fatalError :idleInitialized :idleStopped :idleError :idleFrameDone
  #   :idleDone :preparing :rendering :renderingPaused :renderingAwaitingChanges
  #
  # :fatalError does NOT match /\Aidle/i, so under the pre-1.9.2 classifier
  # it returned :running: a licence or engine failure would SET THE LATCH,
  # log "render started", and then sit until RENDER_TIMEOUT_S -- thirty
  # minutes per row, mislabelled as a timeout. :idleError was only slightly
  # better: classified :idle, failing after STOP_CONFIRM_S with the wrong
  # reason ("stopped or cancelled").
  #
  # Both now match ERROR_STATE and return :failed, which the poll loop fails
  # BY NAME on the first poll, quoting the raw state. Checked before the
  # idle family so the /\Aidle/i prefix of :idleError cannot win.
  ERROR_STATE = /error/i          # :fatalError, :idleError -- fail immediately

  RENDER_TIMEOUT_S = 30 * 60 # a row still not done after this fails by name
  UNREADABLE_LIMIT = 5       # consecutive polls with BOTH signals raising
  START_WINDOW_S   = 30      # a row that has never been seen in a running
                             # state this long after `start` FAILS BY NAME:
                             # the render never started. Observed lead-in is
                             # 440 ms, so 30 s is ~68x margin and still far
                             # under RENDER_TIMEOUT_S - long enough that a
                             # slow scene export cannot trip it, short enough
                             # that a dead batch is not a 30-minute wait.
  STOP_CONFIRM_S   = 10      # once RUNNING has been seen, a return to an
                             # idle-but-not-done state (i.e. :idleStopped)
                             # held this long fails the row by name: someone
                             # or something stopped the render. No such
                             # transient was seen in the watch; 10 s is
                             # margin against one.

  # One guarded read of a renderer poll signal. :raised means the call
  # raised or the method is absent — a V-Ray raise must never escape into
  # the timer loop.
  def self.read_signal(rend, meth)
    return :raised unless rend.respond_to?(meth)
    rend.public_send(meth)
  rescue Exception
    :raised
  end

  # PURE — exercised offline by rbtest-proposal.py, including the :raised
  # paths. state_val / seq_ended are raw poll results (with :raised from
  # read_signal); seen_running is THE LATCH, threaded in as an argument so
  # this method stays pure and testable. Returns :running, :finished, :idle
  # or :unreadable. (1.9.2 adds :failed.)
  #
  #   - a readable state decides alone:
  #       matches ERROR_STATE         -> :failed   (checked FIRST -- F1)
  #       not in the idle family      -> :running  (also sets the latch)
  #       :idleDone and latched       -> :finished
  #       :idleDone and NOT latched   -> :idle     (never started; the poll
  #                                     loop fails the row on START_WINDOW_S
  #                                     rather than saving an empty frame)
  #       any other idle value        -> :idle
  #   - state unreadable: sequence_ended? false is :running; true is
  #     :finished ONLY if latched, else :idle — it reads true cold.
  #   - both unreadable: :unreadable — the poll loop fails the row by name
  #     after UNREADABLE_LIMIT consecutive ticks.
  def self.classify_render(state_val, seq_ended, seen_running = false)
    unless state_val == :raised || state_val.nil?
      s = state_val.to_s
      return :failed  if     s =~ ERROR_STATE
      return :running unless s =~ IDLE_STATE
      return :idle    unless s =~ DONE_STATE
      return seen_running ? :finished : :idle
    end
    unless seq_ended == :raised || seq_ended.nil?
      return :running unless seq_ended
      return seen_running ? :finished : :idle
    end
    :unreadable
  end

  # ------------------------------------------------ camera settling --
  #
  # OBSERVED (Benton, 28 Aug 2026): a render row rendered the PREVIOUS
  # scene's view. The mechanism: `model.pages.selected_page =` starts a
  # camera ANIMATION over PageOptions/TransitionTime (1 s by default), and
  # V-Ray's own log says it snapshots the model ~0.22 s after `start`. So
  # the export caught the camera barely off the scene it came from.
  # `active_view.refresh` draws a frame; it does NOT wait for a transition.
  #
  # The image lane never showed this because export-scenes.rb's
  # export_pages sets TransitionTime = 0 around its loop (its comment:
  # "else write_image can catch a tween"). The render lane now does the
  # same for the whole batch — pushed in start_run, popped in finish, which
  # also covers finish's own selected_page / camera restore — AND sets the
  # camera from the page directly, AND asserts the two agree before start.
  CAM_FIELDS = %w[eye.x eye.y eye.z target.x target.y target.z
                  up.x up.y up.z lens].freeze

  # Flatten a Sketchup::Camera to comparable numbers, or nil if it cannot be
  # read (a scene with "save camera" off has no camera at all).
  def self.cam_tuple(cam)
    return nil if cam.nil?
    e = cam.eye
    t = cam.target
    u = cam.up
    [e.x.to_f, e.y.to_f, e.z.to_f,
     t.x.to_f, t.y.to_f, t.z.to_f,
     u.x.to_f, u.y.to_f, u.z.to_f,
     (cam.perspective? ? cam.fov.to_f : cam.height.to_f)]
  rescue Exception
    nil
  end

  # PURE — exercised offline by rbtest-proposal.py. Two cam_tuple readings;
  # nil when they agree within tol, else a string naming the worst field.
  # A nil tuple is a mismatch: an unreadable camera is not a match.
  def self.cam_mismatch(a, b, tol = 0.01, fields = CAM_FIELDS)
    return 'camera unreadable' if a.nil? || b.nil?
    return 'camera readings differ in shape' if a.size != b.size
    worst_i = 0
    worst_d = 0.0
    a.each_index do |i|
      d = (a[i] - b[i]).abs      # cam_tuple has already made these Floats
      next unless d > worst_d
      worst_d = d
      worst_i = i
    end
    return nil if worst_d <= tol
    format('%s off by %.3f', fields[worst_i] || "field #{worst_i}", worst_d)
  rescue Exception => e
    "camera comparison failed (#{e.class})"
  end

  # Best-effort READ of V-Ray's configured output size, for the warning in
  # start_run. REPORTED, never observed: /SettingsOutput with img_width /
  # img_height are the V-Ray core names. Every hop is respond_to?-gated and
  # rescued; nil means "could not read", which is a louder warning, not an
  # error. This NEVER writes to V-Ray, and never touches in_process? /
  # dr_enabled? (they raise on this machine).
  # F9 -- OBSERVED 30 Aug 2026, three live renders. There are TWO
  # /SettingsOutput plugins, and WHICH ONE GOVERNS DEPENDS ON HOW THE RENDER
  # IS STARTED:
  #
  #   renderer.start            renders the renderer's already-loaded scene at
  #                             the RENDERER's SettingsOutput. Nothing exported
  #                             the model, so this is an empty scene at V-Ray's
  #                             640x480 default -- a black frame, and the
  #                             scene-side 400x300 written just before it was
  #                             ignored entirely.
  #   VRay::Command             exports the V-Ray SCENE into the renderer
  #     .render_production      first, SettingsOutput included, so the SCENE's
  #                             img_width / img_height are what come out.
  #                             Observed: renderer set to 400x300, scene set to
  #                             1200x900, render_production -> a 1200x900 PNG.
  #                             The export overwrote the renderer's copy.
  #
  # This lane renders through render_production, so the SCENE is read first
  # here and the renderer is only the fallback. Whoever needs to CHANGE the
  # size should write the scene copy inside `scene.change`.
  #
  # What is still NOT explained: Benton's Asset Editor showing 1600 while the
  # output measured 2400x1350. Nothing here proves the Asset Editor field and
  # scene['/SettingsOutput'] are the same number.
  def self.output_size(ctx)
    return nil if ctx.nil? || !ctx.respond_to?(:scene)
    scene = ctx.scene
    pl = nil
    pl = (scene['/SettingsOutput'] rescue nil) if scene.respond_to?(:[])
    pl = (scene.fetch('/SettingsOutput') rescue nil) if pl.nil? && scene.respond_to?(:fetch)
    if pl.nil? && ctx.respond_to?(:renderer)
      rend = (ctx.renderer rescue nil)
      pl = (rend.fetch(:SettingsOutput) rescue nil) if rend.respond_to?(:fetch)
    end
    return nil if pl.nil? || !pl.respond_to?(:[])
    w = (pl[:img_width]  rescue nil)
    h = (pl[:img_height] rescue nil)
    return nil unless w.to_i > 0 && h.to_i > 0
    [w.to_i, h.to_i]
  rescue Exception
    nil
  end

  # -------------------------------------------------------------- the run --

  # cfg: {'dir', 'width', 'over' ('Ask'|'Overwrite'|'Skip existing'), 'shade'}
  def self.start_run(model, dlg, cfg)
    if @running                    # double-press race; never a silent ignore
      puts 'WR_ProposalPackage: Export pressed while a batch is running — ignored.'
      log(dlg, 'a batch is already running — this press was ignored', 'bad')
      return
    end

    dir = cfg['dir'].to_s.strip.delete('"').tr('\\', '/').sub(%r{/+\z}, '')
    if dir.empty?
      UI.messagebox('Choose an output folder first.')
      return
    end

    rows  = gather(model)
    files = plan_names(rows)
    live  = rows.reject { |r| r['mode'] == 'skip' }
    if live.empty?
      UI.messagebox('No scenes are marked Image or Render — nothing to export.')
      return
    end

    # V-Ray gate BEFORE anything runs: never a half-run that dies mid-pass.
    if live.any? { |r| r['mode'] == 'render' } && vray_context.nil?
      images = live.select { |r| r['mode'] == 'image' }
      # Observed: the context exists even cold, so a nil here means the
      # extension itself is missing or disabled — not merely "not warmed up".
      msg = "V-Ray is not available in this session (no active context).\n\n" \
            "V-Ray normally provides a context as soon as SketchUp starts, so " \
            "check that the V-Ray extension is installed and enabled, then run " \
            'this again'
      if images.empty?
        UI.messagebox("#{msg}.\n\nNo scenes are marked Image, so there is nothing " \
                      'else to export.')
        return
      end
      ans = UI.messagebox("#{msg} — or export the image rows only.\n\n" \
                          "Yes = export the #{images.size} image row(s) only.\n" \
                          'No = cancel.', MB_YESNO)
      return unless ans == IDYES
      live = images
    end

    # Preflight — failing rows shown, Continue/Cancel is the operator's call.
    pf = begin
      WR_Preflight.check(model)
    rescue StandardError => e
      puts "  preflight itself failed: #{e.class}: #{e.message}"
      nil
    end
    failing = (pf || []).select { |r| r['status'] == 'fail' }
    unless failing.empty?
      lines = failing.map { |r| "  - #{r['label']}: #{r['detail']}" }.join("\n")
      go = UI.messagebox("Preflight found #{failing.size} issue(s):\n\n#{lines}\n\n" \
                         'Continue the export anyway?', MB_YESNO)
      return unless go == IDYES
    end

    begin
      FileUtils.mkdir_p(dir)
    rescue StandardError => e
      UI.messagebox("Cannot create the output folder:\n#{dir}\n\n#{e.class}: #{e.message}")
      return
    end

    # Resolve the on-disk collision policy UP FRONT, so the batch itself never
    # has to ask anything (a messagebox inside a timer tick re-enters timers).
    @results = []
    pages = model.pages.to_a
    plan = live.map do |r|
      { :page => pages[r['n'] - 1], :n => r['n'], :lane => r['mode'],
        :file => files[r['n']], :base => File.basename(files[r['n']], '.png'),
        :path => File.join(dir, files[r['n']]) }
    end
    existing = plan.select { |p| File.exist?(p[:path]) }
    unless existing.empty?
      case cfg['over']
      when 'Overwrite'
        # keep them all
      when 'Skip existing'
        existing.each do |p|
          @results << { :file => p[:file], :lane => p[:lane],
                        :status => 'skipped', :detail => 'already existed (policy: skip existing)' }
        end
        plan -= existing
      else # Ask
        names = existing.map { |p| p[:file] }.join("\n  ")
        ans = UI.messagebox("These files already exist in\n#{dir}:\n\n  #{names}\n\n" \
                            'Overwrite them? Yes overwrites, No skips just those and ' \
                            'keeps going.', MB_YESNOCANCEL)
        return if ans == IDCANCEL
        if ans != IDYES
          existing.each do |p|
            @results << { :file => p[:file], :lane => p[:lane],
                          :status => 'skipped', :detail => 'already existed, overwrite declined' }
          end
          plan -= existing
        end
      end
    end
    if plan.empty?
      UI.messagebox('Every planned file already exists and was skipped — nothing to do.')
      @results = []
      return
    end
    # D8: what was PLANNED, so summary_lines can reconcile it against what
    # was reported and name any row that vanished.
    @plan_files = plan.map { |x| x[:file] }

    # Settings that should survive a restart — per machine, not per model
    # (a folder path is machine-specific). Quotes are stripped above; the
    # wr-folder storage rules apply.
    begin
      Sketchup.write_default(PREF, 'width', cfg['width'].to_s.delete('"'))
      Sketchup.write_default(PREF, 'over',  cfg['over'].to_s.delete('"'))
      Sketchup.write_default(PREF, 'shade', cfg['shade'] ? 'Yes' : 'No')
      Sketchup.write_default(PREF, 'annot', cfg['annot'].to_s == 'draft' ? 'draft' : 'client')
    rescue Exception
      nil
    end
    WR_Folder.remember(FOLDER_KEY, dir)

    image_rows  = plan.select { |p| p[:lane] == 'image' }
    render_rows = plan.select { |p| p[:lane] == 'render' }

    # CLIENT-SAFE OUTPUT (D5). 'client' is the default and hides every
    # ANNOT_TAGS tag for the whole batch; 'draft' is the deliberate opt-out
    # that keeps the annotated look, for the internal/check-print pass. The
    # image lane runs in DRAFT mode (that is what makes it flat and
    # measurable) and draft mode SHOWS dimensions on purpose, so hiding has
    # to be an explicit pass over the tags, not a mode change -- and it is
    # undone in finish, on every exit path.
    client_safe = cfg['annot'].to_s != 'draft'

    # ---- build the unit list. One timer tick does at most one unit.
    units = []
    unless image_rows.empty?
      units << [:mode, 'draft']
      units << [:shade_push] if cfg['shade']
      image_rows.each { |p| units << [:image, p] }
      units << [:shade_pop] if cfg['shade']
    end
    unless render_rows.empty?
      units << [:mode, 'render']
      units << [:vray_setup]
      render_rows.each { |p| units << [:render, p] }
    end

    @running     = true
    @cancel      = false
    @close_after = false
    @units       = units
    @ui          = 0
    @done        = 0
    @total       = units.size
    @awaiting    = nil
    @rend        = nil
    @render_began     = nil
    @unreadable_polls = 0
    @seen_running     = false
    @idle_since       = nil
    @shade_saved   = nil
    @annot_saved   = nil
    @client_safe   = client_safe
    @mode_note     = nil
    @quality_problems = []
    @vray_saved    = nil
    @quality_note  = nil
    @ev_used       = {}
    out_w, out_h = package_size(cfg['width'])
    @cfg = { 'dir' => dir, 'width' => out_w.to_s, 'height' => out_h.to_s,
             'annot' => (client_safe ? 'client' : 'draft') }
    @saved_mode  = WR_Mode.current(model)
    @mode_now    = @saved_mode
    @prev_page   = model.pages.selected_page
    @prev_cam    = (model.active_view.camera.clone rescue nil)

    # Scene transitions OFF for the whole batch, popped in finish. A 1 s
    # camera animation is why a render row captured the previous scene
    # (see the camera-settling section). finish's own selected_page /
    # camera restore runs BEFORE the pop, so the restore is instant too.
    @page_opts = (model.options['PageOptions'] rescue nil)
    @prev_tt   = nil
    begin
      if @page_opts
        @prev_tt = @page_opts['TransitionTime']
        @page_opts['TransitionTime'] = 0
      end
    rescue Exception => e
      @prev_tt = nil
      log(dlg, "could not disable scene transitions " \
               "(#{e.class}: #{e.message}) - each render row still sets its " \
               'camera from the page and checks it before starting', 'bad')
    end

    puts ''
    puts "PROPOSAL PACKAGE — #{image_rows.size} image, #{render_rows.size} render -> #{dir}"
    puts "  output size #{out_w}x#{out_h} (both lanes), annotation: " \
         "#{client_safe ? 'HIDDEN (client-safe)' : 'SHOWN (draft)'}"
    # GUARDED, 1.9.2. This was the ONE unguarded dialog call in the launch
    # path, and it sits between `@running = true` and the timer start -- F10's
    # named hazard, OBSERVED on 30 Aug 2026 when a scripted caller passed a
    # dlg that could not take execute_script: it raised here, so @running
    # latched true with NO timer, and the batch sat at 0 of 7 units forever
    # with nothing said. Every other dialog call in this file is already
    # rescued; this one now matches.
    begin
      dlg.execute_script('runStarted()')
    rescue StandardError => e
      puts "  (dialog runStarted() failed: #{e.class}: #{e.message} - the "            'batch continues; only the dialog is out of step)'
    end
    log(dlg, "#{image_rows.size} image + #{render_rows.size} render row(s) -> #{dir}", 'dim')
    warn_output_size(dlg) unless render_rows.empty?

    stop_stale_timer
    @timer = UI.start_timer(0.1, true) { step(model, dlg) }
  end

  def self.stop_stale_timer
    UI.stop_timer(@timer) if @timer
  rescue StandardError
    nil
  ensure
    @timer = nil
  end

  # ------------------------------------------------------------- the step --

  # THE RE-ENTRANCY GUARD, and why it is now two methods.
  #
  # FIXED 1.9.2, 30 Aug 2026 -- OBSERVED, and it cost a whole render row.
  #
  # It used to read:
  #
  #     def self.step(model, dlg)
  #       return if @in_step
  #       @in_step = true
  #       ... body ...
  #     ensure
  #       @in_step = false
  #     end
  #
  # A method-level `ensure` runs on EVERY exit from the method, and that
  # includes the guard's own `return if @in_step`. So the guard UNLOCKED
  # ITSELF: a nested tick returned and cleared the flag on its way out, and
  # the tick after that walked straight in while the outer call was still
  # running.
  #
  # That is not theoretical. VRay::Command.render_production pumps the
  # Windows message loop while it exports the model, so SketchUp's timers
  # DO fire inside it. Live 30 Aug 2026, a 5-scene batch with two render
  # rows produced this dialog log:
  #
  #     "Rendering 01 Booth Exterior Three-Quarter render.png..."   <- outer
  #     "Rendering 04 Booth Interior render.png..."                 <- NESTED
  #     "04 Booth Interior render.png  render started"
  #     "01 Booth Exterior Three-Quarter render.png  render started"
  #     ... 1356 polls of 01 ...
  #     "ok  01 Booth Exterior Three-Quarter render.png"
  #     "PROPOSAL PACKAGE - 4 exported, 0 skipped, 0 FAILED"
  #
  # The nested tick dispatched row 04 and set @awaiting to it; the outer
  # call then overwrote @awaiting with row 01. Row 04 was rendered and
  # thrown away, produced NO result row, and the batch called itself a
  # clean run: 5 rows planned, 4 files written, 0 failures reported. A
  # silently vanishing row is the exact failure mode this file exists to
  # make impossible.
  #
  # The guard now lives in a wrapper with no ensure of its own, so the only
  # thing that can clear @in_step is a call that actually SET it.
  def self.step(model, dlg)
    return if @in_step
    @in_step = true
    step_body(model, dlg)
  end

  def self.step_body(model, dlg)
    if @cancel
      if @awaiting
        begin
          @rend.stop if @rend            # reported API — best effort
        rescue Exception
          nil
        end
        @results << { :file => @awaiting[:file], :lane => 'render',
                      :status => 'cancelled', :detail => 'render stopped mid-flight' }
        @awaiting = nil
      end
      finish(model, dlg, 'cancelled')
      return
    end

    # A render in flight: poll it, at most one poll per tick. Completion is
    # read from `state` (observed working), with `sequence_ended?` deciding
    # only if `state` itself is unreadable — NEVER from in_process?, which
    # raises "Incorrect DR version" on this machine (see the completion
    # section above). Every branch here either stays in the timer loop or
    # fails the row by name and moves on; none of them skips FINISH.
    #
    # THE LATCH (@seen_running): a finished verdict is only accepted after
    # this row has been seen in a RUNNING state at least once. Both finish
    # signals — :idleDone and sequence_ended? — also read as finished on a
    # renderer that never started, and that is exactly how five empty frame
    # buffers got saved on 28 Aug 2026. A row that never latches fails BY
    # NAME at START_WINDOW_S; nothing is ever saved for it.
    if @awaiting
      elapsed = Time.now - (@render_began || Time.now)
      # F7: keep the raw state for the failure messages. When a render row
      # fails, the state symbol is the one datum that says WHICH failure it
      # was; every fail_render_row message below now quotes it.
      state_now = read_signal(@rend, :state)
      @last_state = state_now
      verdict = classify_render(state_now,
                                read_signal(@rend, :sequence_ended?),
                                @seen_running)
      if verdict == :running
        unless @seen_running
          @seen_running = true
          log(dlg, "        #{@awaiting[:file]}  render started", 'dim')
        end
        @idle_since = nil
      elsif verdict == :idle
        @idle_since ||= Time.now
      else
        @idle_since = nil
      end
      @unreadable_polls = verdict == :unreadable ? @unreadable_polls + 1 : 0
      idle_held = @idle_since ? Time.now - @idle_since : 0

      if verdict == :failed
        # F1: an error state is terminal. Fail NOW, by name, with the raw
        # state -- never burn RENDER_TIMEOUT_S on a renderer that has
        # already given up.
        fail_render_row(dlg, 'the renderer reported an ERROR state -- ' \
                             'render abandoned, nothing saved')
      elsif verdict == :finished
        save_frame(dlg, @awaiting)
        @awaiting = nil
        @done += 1
        progress(dlg, nil)
      elsif @unreadable_polls >= UNREADABLE_LIMIT
        fail_render_row(dlg, 'renderer state and sequence_ended? both ' \
                             'unreadable — render stopped, nothing saved')
      elsif !@seen_running && elapsed > START_WINDOW_S
        fail_render_row(dlg, 'the render never started — the renderer was ' \
                             "still idle #{START_WINDOW_S}s after " \
                             'renderer.start (never reached :preparing or ' \
                             ':rendering). Nothing saved — an empty frame ' \
                             'buffer is NOT a render')
      elsif @seen_running && idle_held > STOP_CONFIRM_S
        fail_render_row(dlg, 'the renderer went idle without finishing — ' \
                             "not :idleDone for #{STOP_CONFIRM_S}s after it " \
                             'was running (stopped or cancelled). Nothing saved')
      elsif elapsed > RENDER_TIMEOUT_S
        fail_render_row(dlg, "no :idleDone state after " \
                             "#{RENDER_TIMEOUT_S / 60} minutes — render " \
                             'stopped, nothing saved')
      else
        progress(dlg, "Rendering #{@awaiting[:file]}…")
      end
      return
    end

    unit = @units[@ui]
    if unit.nil?
      finish(model, dlg, 'done')
      return
    end
    @ui += 1

    case unit[0]
    when :mode       then unit_mode(model, dlg, unit[1])
    when :shade_push then unit_shade_push(model, dlg)
    when :shade_pop  then unit_shade_pop(model, dlg)
    when :vray_setup then unit_vray_setup(model, dlg)
    when :image      then unit_image(model, dlg, unit[1])
    when :render     then unit_render(model, dlg, unit[1])
    end
    @done += 1 unless @awaiting          # a started render counts when it lands
    progress(dlg, nil)
  rescue Exception => e
    # No path out of the batch skips FINISH — an unexpected raise lands here.
    puts "  *** batch step raised: #{e.class}: #{e.message}"
    puts e.backtrace.first(5).map { |l| "      #{l}" }.join("\n") if e.backtrace
    log(dlg, "batch step raised: #{e.class}: #{e.message}", 'bad')
    finish(model, dlg, "stopped by an error (#{e.class})")
  ensure
    @in_step = false
  end

  # --------------------------------------------------------------- units --

  # The ONLY way this tool changes model state. A raise here stops the batch
  # (the model is safe: each WR_MaterialsSwap sweep is one atomic operation,
  # aborted on a raise) — routed to FINISH by step's rescue.
  def self.unit_mode(model, dlg, target)
    res = WR_Mode.to_mode(model, target)
    @mode_now = target
    log(dlg, "MODE -> #{target.upcase}", 'dim')
    mat = res[:materials] || {}
    (mat[:applied] || mat[:reverted] || {}).each do |slot, n|
      log(dlg, "  #{slot}: #{n} surface(s)", 'dim')
    end
    # Unmapped surfaces named BEFORE the first render — "floor still white"
    # is said here, not discovered in the image.
    problems = mat[:unmapped] || mat[:left] || []
    problems.each { |s| log(dlg, "unmapped  #{s}", 'bad') }
    @unmapped = problems if target == 'render'
    model.active_view.refresh
  end

  # CLIENT-SAFE OUTPUT (D5) -- OBSERVED 30 Aug 2026: pass 1's image rows went
  # out carrying the room's "20'" and "16'" dimension strings and the ceiling
  # banner "Ceiling 8'-0" - HOUSE DEFAULT, not measured. Confirm before
  # quoting." That banner lives on WR-Notes, which until 1.9.3 was in no tag
  # list at all, so not even RENDER mode hid it.
  #
  # WHY THIS IS PER ROW AND NOT ONCE PER BATCH. The obvious design -- hide the
  # tags at the top of the unit list, restore them in finish -- was WRITTEN,
  # RUN, AND OBSERVED TO FAIL on 30 Aug 2026: the very next unit is
  # [:mode, 'draft'], and DRAFT MODE'S WHOLE JOB IS TO SHOW DIMENSIONS, so
  # WR_Mode turned every one of them straight back on and the plan export came
  # out fully annotated. Moving the hide after the mode unit fixes the picture
  # and breaks something worse: WR_Mode snapshots the LIVE tag visibilities
  # when it leaves a mode, so a batch that was sitting in draft with the dims
  # hidden would memorise "draft means no dimensions" into the model and keep
  # it forever.
  #
  # So the hide brackets the EXPORT, not the batch. No mode transition ever
  # happens between a push and its pop, so no snapshot can record the
  # temporary state. Image rows push and pop around each write_image; render
  # rows push before render_production (which is what exports the model into
  # V-Ray) and are popped by finish, because nothing between the first render
  # row and finish changes mode.
  #
  # And it is not redundant with render mode: on a model whose first-ever
  # toggle happens inside this batch, WR_Mode's render snapshot is seeded from
  # "whatever was showing", which is everything. Render mode alone does NOT
  # guarantee a clean frame on a fresh model. This does.
  def self.annot_push(model, dlg, file)
    return unless @client_safe
    return if @annot_saved            # already hidden by an earlier row
    saved = {}
    missing = []
    ANNOT_TAGS.each do |n|
      l = model.layers[n]
      if l.nil?
        missing << n
        next
      end
      saved[n] = l.visible?
      l.visible = false
    end
    @annot_saved = saved
    shown = saved.select { |_n, v| v }.keys
    log(dlg, "CLIENT-SAFE: hid #{saved.size} annotation tag(s) for #{file}" +
             (shown.empty? ? ' (none were showing)' : " - #{shown.join(', ')} " \
              'were visible and would have gone out on a client image'), 'dim')
    log(dlg, "        not in this model: #{missing.join(', ')}", 'dim') unless missing.empty?
  rescue StandardError => e
    @annot_saved = nil
    log(dlg, "CLIENT-SAFE FAILED for #{file}: #{e.class}: #{e.message} - " \
             'construction annotation may be visible in this image. Check ' \
             'before sending.', 'bad')
  end

  def self.annot_pop(model, dlg)
    return if @annot_saved.nil?
    @annot_saved.each do |n, vis|
      l = model.layers[n]
      l.visible = vis if l
    end
    @annot_saved = nil
  rescue StandardError => e
    log(dlg, "annotation tags could not be put back: #{e.class}: #{e.message}", 'bad')
  end

  # RENDER QUALITY AND SIZE, once per batch, before the first render row.
  #
  # D3 (speckle) and D4 (size). Both are written into the V-Ray SCENE, not
  # the renderer: VRay::Command.render_production exports the scene into the
  # renderer on every call, so the scene copy is the one that wins (observed
  # 30 Aug 2026 -- renderer 400x300 + scene 1200x900 produced a 1200x900 PNG).
  # Everything written here is read back, and everything is restored in
  # finish: this tool owns these settings for the length of a batch and hands
  # them back exactly as it found them.
  def self.unit_vray_setup(model, dlg)
    ctx   = vray_context
    scene = vray_scene(ctx)
    if scene.nil?
      @quality_note = 'NOT SET - no V-Ray scene'
      log(dlg, 'RENDER QUALITY: no V-Ray scene to write to. The render rows ' \
               'will use whatever the Asset Editor is set to, denoiser ' \
               'included - expect the stock speckle.', 'bad')
      return
    end

    w, h = package_size(@cfg['width'])
    size_triples = [['/SettingsOutput', :img_width, w],
                    ['/SettingsOutput', :img_height, h]]
    triples = size_triples + QUALITY.map { |pl, k, v| [pl, k, v] }
    @vray_saved = read_params(scene, triples.map { |pl, k, _v| [pl, k] })
    applied, problems = write_params(scene, triples)

    log(dlg, "RENDER SIZE: V-Ray scene /SettingsOutput set to " \
             "#{applied['/SettingsOutput[img_width]'].inspect}x" \
             "#{applied['/SettingsOutput[img_height]'].inspect} - " \
             'the same shape as the image rows', 'dim')
    log(dlg, "RENDER QUALITY: denoiser " \
             "#{applied['/RenderChannelDenoiser[enabled]'].inspect}, " \
             "progressive noise threshold " \
             "#{applied['/SettingsImageSampler[progressive_threshold]'].inspect}, " \
             "max subdivs #{applied['/SettingsImageSampler[progressive_maxSubdivs]'].inspect}, " \
             "min shade rate #{applied['/SettingsImageSampler[min_shade_rate]'].inspect}, " \
             "time budget #{applied['/SettingsImageSampler[progressive_maxTime]'].inspect} min", 'dim')
    @quality_note = applied.map { |k, v| "#{k}=#{v.inspect}" }.join(', ')
    problems.each { |m| log(dlg, "RENDER QUALITY: #{m}", 'bad') }
    @quality_problems = problems
  rescue Exception => e
    @quality_note = "raised #{e.class}"
    log(dlg, "RENDER QUALITY: setup raised #{e.class}: #{e.message} - render " \
             'rows run on stock settings', 'bad')
  end

  # The wr-shading contract, image lane only, one checkbox. Pushed AFTER the
  # draft swap and popped before anything else changes mode, so the contract
  # never gets recorded into a WR_Mode snapshot.
  def self.unit_shade_push(model, dlg)
    @shade_saved = WR_Shading.push(model, WR_Shading::KEEP, WR_Shading::DEF_DARK)
    log(dlg, "shading contract on (Light #{WR_Shading::DEF_LIGHT} / Dark #{WR_Shading::DEF_DARK}, shadows off)", 'dim')
  rescue StandardError => e
    @shade_saved = nil
    log(dlg, "shading contract could not be applied: #{e.class}: #{e.message} — images export as the model sits", 'bad')
  end

  def self.unit_shade_pop(model, dlg)
    WR_Shading.pop(model, @shade_saved) if @shade_saved
    @shade_saved = nil
    log(dlg, 'shading contract restored', 'dim')
  end

  def self.unit_image(model, dlg, p)
    plan = [{ :page => p[:page], :n => p[:n], :base => p[:base] }]
    # D4: an EXPLICIT height, so an image row and a render row of the same
    # scene come out the same shape. Before 1.9.3 only width was passed and
    # export-scenes.rb derived the height from the SketchUp window.
    cfg  = { 'dir' => @cfg['dir'], 'width' => @cfg['width'],
             'height' => @cfg['height'], 'bg' => 'Opaque', 'over' => 'Yes' }
    begin
      annot_push(model, dlg, p[:file])
      x = WR_ExportScenes.export_pages(model, plan, cfg)
    ensure
      annot_pop(model, dlg)
    end
    if x[:written] > 0
      @results << { :file => p[:file], :lane => 'image', :status => 'ok',
                    :detail => "image, #{x[:width]}x#{x[:height]} " \
                               "(height #{x[:height_source]})" }
      log(dlg, "ok      #{p[:file]}  (image, #{x[:width]}x#{x[:height]}, " \
               "height #{x[:height_source]})", 'ok')
    else
      @results << { :file => p[:file], :lane => 'image', :status => 'failed',
                    :detail => 'view.write_image returned false' }
      log(dlg, "FAILED  #{p[:file]}  (view.write_image returned false)", 'bad')
    end
  rescue StandardError => e
    @results << { :file => p[:file], :lane => 'image', :status => 'failed',
                  :detail => "#{e.class}: #{e.message}" }
    log(dlg, "FAILED  #{p[:file]}  (#{e.class}: #{e.message})", 'bad')
  end

  # THE RENDER LANE'S SIZE IS OURS NOW (D4, 1.9.3).
  #
  # Until 1.9.3 this method could only WARN: render rows came out at whatever
  # the V-Ray Asset Editor happened to be set to (640x480 on 28 Aug 2026,
  # discovered only once the files were on disk), while image rows came out
  # at the Width field crossed with the SketchUp window's aspect. Two lanes,
  # two shapes, neither requested.
  #
  # unit_vray_setup now WRITES /SettingsOutput from the same Width field the
  # image lane uses, at ASPECT_W:ASPECT_H. This method reports what V-Ray is
  # sitting at BEFORE that write, and what it is about to become -- so the
  # log shows the change rather than implying the old value governed.
  def self.warn_output_size(dlg)
    want_w, want_h = package_size(@cfg['width'])
    sz = output_size(vray_context)
    if sz
      same = sz[0] == want_w && sz[1] == want_h
      log(dlg, "RENDER SIZE: V-Ray is at #{sz[0]}x#{sz[1]}" \
               "#{same ? ' already' : "; this batch will set it to #{want_w}x#{want_h}"}" \
               ' - the same size the image rows use, and it is put back at ' \
               'the end of the batch.', 'dim')
    else
      log(dlg, 'RENDER SIZE: could not read the V-Ray output size before the ' \
               "run. The batch still writes #{want_w}x#{want_h} into the " \
               'V-Ray scene and reads it back; if that write does not land ' \
               'it is named in the log.', 'bad')
    end
  rescue Exception => e
    log(dlg, "RENDER SIZE: pre-run size check failed " \
             "(#{e.class}: #{e.message}) - the batch still sets the size " \
             'itself and reads it back.', 'bad')
  end

  # Everything V-Ray in here is REPORTED API, individually rescued: a wrong
  # assumption about a signature becomes a named per-row failure, never a
  # crash out of the batch.
  def self.unit_render(model, dlg, p)
    ctx = vray_context
    if ctx.nil?
      @results << { :file => p[:file], :lane => 'render', :status => 'failed',
                    :detail => 'V-Ray context went away mid-run' }
      log(dlg, "FAILED  #{p[:file]}  (V-Ray context went away mid-run)", 'bad')
      return
    end
    rend = begin
      ctx.renderer
    rescue Exception => e
      nil
    end
    if rend.nil?
      @results << { :file => p[:file], :lane => 'render', :status => 'failed',
                    :detail => 'the active V-Ray context has no renderer' }
      log(dlg, "FAILED  #{p[:file]}  (the active V-Ray context has no renderer)", 'bad')
      return
    end

    # SETTLE THE CAMERA BEFORE start — see the camera-settling section.
    # Transitions are already off for the batch (start_run); set the camera
    # from the page anyway, then ASSERT the viewport agrees with the page.
    # A disagreement fails the row BY NAME rather than rendering a view the
    # caption will contradict.
    model.pages.selected_page = p[:page]
    page_cam = (p[:page].camera rescue nil)
    if page_cam
      begin
        model.active_view.camera = page_cam
      rescue Exception => e
        log(dlg, "        #{p[:file]}  could not set the camera " \
                 "directly (#{e.class}: #{e.message}) — relying on the " \
                 'scene switch', 'bad')
      end
    end
    model.active_view.refresh

    if page_cam
      va = cam_tuple(model.active_view.camera)
      pa = cam_tuple(page_cam)
      # POSITION (eye/target/up, fields 0-8) and LENS (field 9) are judged
      # separately, because the worst single field across all ten could be
      # the lens while the eye is also off.
      #
      # A lens difference is a WARNING, not a failure: eye/target/up decide
      # which way the camera points, SketchUp can re-derive fov from the
      # viewport aspect on assignment, and V-Ray's /CameraPhysical may carry
      # its own value (open question 7 in reference/vray-ruby-api.md).
      # Refusing to render over that would block every row for something
      # that is not the wrong-view bug.
      mm   = cam_mismatch(va && va[0, 9], pa && pa[0, 9])
      lens = cam_mismatch(va && va[9, 1], pa && pa[9, 1], 0.01, ['lens'])
      if lens && mm.nil?
        log(dlg, "        #{p[:file]}  lens differs from the scene " \
                 "(#{lens}) - position matches, rendering anyway", 'bad')
      end
      if mm
        @results << { :file => p[:file], :lane => 'render', :status => 'failed',
                      :detail => "the viewport camera never settled on " \
                                 "this scene (#{mm}) — nothing rendered, " \
                                 'because a render of the wrong view is ' \
                                 'worse than a missing one' }
        log(dlg, "FAILED  #{p[:file]}  (camera never settled on this scene: #{mm})", 'bad')
        return
      end
    else
      log(dlg, "        #{p[:file]}  this scene saves no camera — " \
               'rendering the current view', 'bad')
    end
    # PER-ROW EXPOSURE (D2). Pass 1 set one EV for the whole batch and the
    # room-level row came out clipped to white. EV is a property of the VIEW,
    # not of the batch: this rig's booth interior wants EV 9 and its room
    # views want EV 12, and there is no value that serves both. The number
    # used goes in the log and into the row's detail, so a wrong-looking
    # image can always be traced back to the exposure that made it.
    ev = ev_of(p[:page])
    ev_landed = apply_exposure(ctx, dlg, ev, p[:file])
    @ev_used[p[:file]] = ev_landed || ev

    progress(dlg, "Rendering #{p[:file]}…")

    @rend = rend
    @last_state = nil
    begin
      # F2 (render-lane audit) -- ROOT CAUSE FOUND AND FIXED 1.9.2,
      # 30 Aug 2026, all OBSERVED live in SketchUp 2026 / V-Ray 7.
      #
      # `renderer.start` does NOT export the model. It starts the renderer on
      # whatever scene is already loaded INTO THE RENDERER, and on a session
      # where nothing has exported the model that is nothing at all. Measured
      # on this room-plus-booth model:
      #
      #   renderer.start(sync: true)      state -> :rendering, :idleDone in
      #                                   0.6 s, saved frame 429 bytes of
      #                                   SOLID BLACK, 3 runs, every time
      #   VRay::Command.render_production console prints "Exporting model:
      #                                   Done (0.43 s)" / "Starting render",
      #                                   :idleDone in 8.5 s, saved frame
      #                                   111,595 bytes -- the real image
      #
      # `sync: true` is real (it makes `start` engage the state machine cold,
      # which a bare `start` does not) but it is NOT the fix: it engages the
      # renderer on an empty scene. That is the whole "five empty frames"
      # story of 28 Aug 2026 -- the renders DID run, on nothing.
      #
      # VRay::Command's own doc line is "meant to emulate the functionality
      # exposed in the V-Ray for SketchUp toolbars and menus" -- i.e. the
      # toolbar button, export step included. It drives the SAME renderer the
      # poll loop reads (state went :idleDone -> :rendering -> :idleDone on
      # `VRay::Context.active.renderer` throughout).
      # Hidden BEFORE render_production, because that call is what exports the
      # SketchUp model into V-Ray. finish pops it: nothing between here and
      # there changes mode, so no WR_Mode snapshot can record the hiding.
      annot_push(model, dlg, p[:file])
      if defined?(VRay::Command) && VRay::Command.respond_to?(:render_production)
        VRay::Command.render_production(:context => ctx)
      else
        # NO SILENT FALLBACK: say plainly that this path renders whatever is
        # already in the renderer, which is usually an empty scene.
        log(dlg, "        #{p[:file]}  VRay::Command.render_production is " \
                 'ABSENT in this build -- falling back to renderer.start, ' \
                 'which does NOT export the model and is the known ' \
                 'black-frame path', 'bad')
        rend.start(:sync => true)
      end
    rescue Exception => e
      @results << { :file => p[:file], :lane => 'render', :status => 'failed',
                    :detail => "renderer.start raised #{e.class}: #{e.message}" }
      log(dlg, "FAILED  #{p[:file]}  (renderer.start raised #{e.class}: #{e.message})", 'bad')
      return
    end

    # Poll `state` / `sequence_ended?` from the next tick on. in_process? is
    # NEVER consulted — it raises on this machine (completion section above).
    if rend.respond_to?(:state) || rend.respond_to?(:sequence_ended?)
      @awaiting         = p
      @render_began     = Time.now
      @unreadable_polls = 0
      @seen_running     = false   # the latch, per row
      @idle_since       = nil
    else
      # No poll surface at all — fall back to the documented blocking wait.
      # Progress is per-scene here and mid-render cancel cannot land until
      # it returns.
      begin
        rend.wait if rend.respond_to?(:wait)
      rescue Exception
        nil
      end
      save_frame(dlg, p)
    end
  end

  # Write this row's exposure into the V-Ray physical camera and read it
  # back. Returns the EV that ACTUALLY landed (derived from the read-back
  # f_number and shutter_speed), or nil if it could not be set -- in which
  # case the row still renders, at whatever exposure the camera carries, and
  # the log says so by name rather than implying the value took.
  def self.apply_exposure(ctx, dlg, ev, file)
    scene = vray_scene(ctx)
    if scene.nil?
      log(dlg, "        #{file}  EXPOSURE NOT SET (no V-Ray scene) - this " \
               'row renders at whatever the camera already carries', 'bad')
      return nil
    end
    triples = [['/CameraPhysical', :f_number,      EV_F_NUMBER],
               ['/CameraPhysical', :ISO,           EV_ISO],
               ['/CameraPhysical', :shutter_speed, shutter_for_ev(ev)]]
    # Snapshot ONCE per batch, before the first row changes anything, so the
    # restore puts back the operator's camera and not row N-1's exposure.
    @vray_saved ||= {}
    read_params(scene, triples.map { |pl, k, _v| [pl, k] }).each do |k, v|
      @vray_saved[k] = v unless @vray_saved.key?(k)
    end
    applied, problems = write_params(scene, triples)
    problems.each { |m| log(dlg, "        #{file}  EXPOSURE: #{m}", 'bad') }
    landed = ev_of_camera(applied['/CameraPhysical[f_number]'],
                          applied['/CameraPhysical[shutter_speed]'])
    log(dlg, format('        %s  EV %.2f (f/%s @ 1/%s, ISO %s)%s',
                    file, landed || ev,
                    applied['/CameraPhysical[f_number]'].inspect,
                    applied['/CameraPhysical[shutter_speed]'].inspect,
                    applied['/CameraPhysical[ISO]'].inspect,
                    problems.empty? ? '' : ' - SEE THE WARNINGS ABOVE'), 'dim')
    landed
  rescue Exception => e
    log(dlg, "        #{file}  EXPOSURE NOT SET (#{e.class}: #{e.message})", 'bad')
    nil
  end

  # A render row that will never report finished (poll surface dead, or the
  # timeout): stop the renderer best-effort, fail the row BY NAME, and let
  # the batch move to its next unit. This stays inside the timer loop, so
  # the batch still ends at FINISH with mode, scene and camera restored.
  def self.fail_render_row(dlg, detail)
    begin
      @rend.stop if @rend                # reported API — best effort
    rescue Exception
      nil
    end
    detail = "#{detail} (last renderer state: #{@last_state.inspect})"
    @results << { :file => @awaiting[:file], :lane => 'render',
                  :status => 'failed', :detail => detail }
    log(dlg, "FAILED  #{@awaiting[:file]}  (#{detail})", 'bad')
    @awaiting = nil
    @done += 1
    progress(dlg, nil)
  end

  # F4 (render-lane audit) -- FIXED 1.9.2, 30 Aug 2026, OBSERVED live.
  #
  # save_vfb_image(path, options) => Boolean. Three things were wrong:
  #
  #  1. The Boolean was discarded and success judged by File.exist?. Under
  #     the Overwrite policy the target ALREADY EXISTS, so a failed save
  #     (locked file, OneDrive sync, bad extension) reported ok against the
  #     PREVIOUS run's image -- and a caption then gets written about the
  #     wrong render. Fixed by deleting the target first (so File.exist?
  #     means THIS run) and by checking the Boolean.
  #  2. No options: the default writes a separate <name>.Alpha.png sidecar
  #     that nothing in the collision map plans for, and a TRANSPARENT RGB
  #     that has to be flattened before it can go in a client pack.
  #     :skip_alpha kills the sidecar, :no_alpha gives an opaque PNG.
  #  3. An option key this build rejects would raise, and the rescue below
  #     fails the row by name rather than silently skipping -- the safe
  #     direction. Verified live 30 Aug 2026: returns true, one opaque PNG,
  #     no sidecar.
  # RENDER-ELEMENT SIDECARS -- OBSERVED 30 Aug 2026, and they are new since
  # the denoiser was switched on. save_vfb_image(:skip_alpha, :no_alpha)
  # writes ONE opaque RGB file and no .Alpha.png, which is what F4 fixed. But
  # with /RenderChannelDenoiser enabled, V-Ray also wrote
  #
  #     <base>.denoiser.png        the DENOISED image
  #     <base>.effectsResult.png   the same pixels
  #
  # next to it. Two consequences worth stating plainly:
  #
  #  1. Nothing in the collision map, the Ask/Overwrite/Skip policy or the
  #     summary knows these exist, so they accumulate in the output folder and
  #     could reach a client pack. They are NAMED in the row detail and in the
  #     log instead of being silently left -- deleting another program's
  #     output is not this tool's call.
  #  2. The file this tool saves is the VFB's RGB channel, and the denoiser
  #     result is the SIDECAR. Measured on 01 Booth Exterior Three-Quarter,
  #     1200x900: mean neighbour-pixel difference 0.0444 in the saved .png
  #     against 0.0416 in .denoiser.png -- the saved frame is about 7%
  #     noisier than the denoised one. So the denoiser IS running and the
  #     saved image is NOT the fully denoised frame. Whether save_vfb_image
  #     can be pointed at the denoised channel is UNANSWERED; it was not
  #     tried.
  def self.sidecars(p)
    dir  = File.dirname(p[:path])
    base = File.basename(p[:path], '.png')
    Dir.glob(File.join(dir, "#{base}.*.png")).map { |f| File.basename(f) }.sort
  rescue Exception
    []
  end

  def self.save_frame(dlg, p)
    begin
      File.delete(p[:path]) if File.exist?(p[:path])
    rescue Exception
      nil
    end
    ok = nil
    begin
      ok = @rend.save_vfb_image(p[:path], :skip_alpha => true, :no_alpha => true)
    rescue Exception => e
      @results << { :file => p[:file], :lane => 'render', :status => 'failed',
                    :detail => "save_vfb_image raised #{e.class}: #{e.message}" }
      log(dlg, "FAILED  #{p[:file]}  (save_vfb_image raised #{e.class}: #{e.message})", 'bad')
      return
    end
    if ok == false
      @results << { :file => p[:file], :lane => 'render', :status => 'failed',
                    :detail => 'save_vfb_image returned false -- the frame was ' \
                               'NOT written' }
      log(dlg, "FAILED  #{p[:file]}  (save_vfb_image returned false)", 'bad')
      return
    end
    if File.exist?(p[:path])
      det = format('V-Ray %sx%s, EV %.2f, denoiser on',
                   @cfg['width'], @cfg['height'], (@ev_used[p[:file]] || 0.0).to_f)
      side = sidecars(p)
      det += format(', plus %d render-element sidecar(s): %s',
                    side.size, side.join(', ')) unless side.empty?
      @results << { :file => p[:file], :lane => 'render', :status => 'ok',
                    :detail => det }
      log(dlg, "ok      #{p[:file]}  (#{det})", 'ok')
      unless side.empty?
        log(dlg, "        #{p[:file]}  these sidecars are NOT in the " \
                 'collision plan and must not go to a client: ' \
                 "#{side.join(', ')}", 'bad')
      end
    else
      @results << { :file => p[:file], :lane => 'render', :status => 'failed',
                    :detail => 'save_vfb_image returned but wrote no file' }
      log(dlg, "FAILED  #{p[:file]}  (save_vfb_image returned but wrote no file)", 'bad')
    end
  end

  # -------------------------------------------------------------- finish --

  # THE single exit. Runs on completion, on cancel and on any raise — restores
  # mode, scene and camera, and fails LOUDLY with a recovery instruction if
  # the restore itself fails. A leaked mutation is the worst failure this
  # tool can have, so nothing here is allowed to fail quietly.
  def self.finish(model, dlg, why)
    stop_stale_timer
    restore_errs = []

    begin
      if @shade_saved
        WR_Shading.pop(model, @shade_saved)
        @shade_saved = nil
      end
    rescue Exception => e
      restore_errs << "shading pop: #{e.class}: #{e.message}"
    end

    # V-RAY, back exactly as it was found: output size, denoiser, sampler and
    # the physical camera's exposure. This tool OWNS those for the length of
    # a batch and no longer.
    begin
      vs = vray_scene(vray_context)
      restore_params(vs, @vray_saved).each do |m|
        restore_errs << "V-Ray restore: #{m}"
      end
    rescue Exception => e
      restore_errs << "V-Ray restore: #{e.class}: #{e.message}"
    ensure
      @vray_saved = nil
    end

    # ANNOTATION TAGS back BEFORE the mode restore, so the visibilities
    # WR_Mode records into its snapshot are the model's real ones and not the
    # client-safe pass's temporary hiding.
    if @annot_saved
      begin
        annot_pop(model, dlg)
      rescue Exception => e
        restore_errs << "annotation tag restore: #{e.class}: #{e.message}"
      ensure
        @annot_saved = nil
      end
    end

    # F3 -- FIXED 1.9.3. This used to read
    #
    #     if %w[draft render].include?(@saved_mode) && @mode_now != @saved_mode
    #
    # so a model that had never been toggled (WR_Mode.current returns the
    # string 'unknown (never toggled)') fell straight through the condition
    # and the batch left it in RENDER mode WITH NOTHING SAID. Observed live
    # 30 Aug 2026: after pass 1's batch the scratch model was still in render
    # mode, materials swapped, and the run reported a clean finish.
    #
    # Now: an unresolvable saved mode resolves to MODE_FALLBACK ('draft', the
    # shop's resting state) and the fact is stated in the log AND in the
    # summary. It fails by name; it never skips in silence.
    @mode_target = mode_restore_target(@saved_mode)
    if @mode_target != @saved_mode.to_s
      @mode_note = "the model had never been mode-toggled (WR_Mode.current " \
                   "read #{@saved_mode.inspect}), so it was restored to " \
                   "#{@mode_target.upcase} rather than left in " \
                   "#{@mode_now.to_s.upcase}"
      puts "  #{@mode_note}"
    end
    if @mode_now != @mode_target
      begin
        WR_Mode.to_mode(model, @mode_target)
        @mode_now = @mode_target
      rescue Exception => e
        restore_errs << "mode restore to #{@mode_target}: #{e.class}: #{e.message}"
      end
    end

    begin
      model.pages.selected_page = @prev_page if @prev_page
    rescue Exception => e
      restore_errs << "scene restore: #{e.class}: #{e.message}"
    end
    begin
      model.active_view.camera = @prev_cam if @prev_cam
    rescue Exception => e
      restore_errs << "camera restore: #{e.class}: #{e.message}"
    end
    # Scene transitions back on LAST, so the two restores above were instant.
    begin
      if @page_opts && !@prev_tt.nil?
        @page_opts['TransitionTime'] = @prev_tt
      end
    rescue Exception => e
      restore_errs << "scene transition time restore: #{e.class}: #{e.message}"
    ensure
      @page_opts = nil
      @prev_tt   = nil
    end

    unless restore_errs.empty?
      puts "  *** could not restore the model's original state:"
      restore_errs.each { |s| puts "        #{s}" }
      UI.messagebox("*** COULD NOT RESTORE THE MODEL'S ORIGINAL STATE ***\n\n" +
                    restore_errs.join("\n") +
                    "\n\nThe model is likely in #{@mode_now.to_s.upcase} mode " \
                    "(it started in #{@saved_mode.to_s.upcase}).\n" \
                    "Press 'Toggle Draft / Render mode' to put it back — WR_Mode " \
                    'stores the true state in the model, so the toggle reads it ' \
                    'even after a crash.')
    end

    lines = summary_lines(why, restore_errs)
    puts ''
    lines.each { |l| puts l }
    puts ''
    restore_errs.each { |s| log(dlg, "RESTORE FAILED: #{s}", 'bad') }
    log(dlg, lines.first.to_s, restore_errs.empty? ? 'dim' : 'bad')
    (@unmapped || []).each { |s| log(dlg, "unmapped  #{s}", 'bad') }

    fails = @results.count { |r| r[:status] == 'failed' }
    msg = if why == 'cancelled'
            'Cancelled — model restored. Partial results are real files.'
          elsif fails > 0
            "Done — #{fails} failure(s) named in the log. Nothing silent."
          else
            'Done. Model restored.'
          end
    msg = 'FINISHED WITH RESTORE ERRORS — see the message and console.' unless restore_errs.empty?
    begin
      dlg.execute_script("runFinished(#{msg.to_json})")
    rescue StandardError
      nil
    end

    # THE LATCH COMES DOWN BEFORE THE LAST MESSAGE BOX, and the box is
    # guarded. F10 in the render-lane audit named UI.messagebox as the one
    # residual raiser inside finish; OBSERVED live on 30 Aug 2026, a scripted
    # caller whose UI.messagebox raises (the bridge muzzles modals) made this
    # line throw AFTER every file was written and every restore had run. The
    # raise escaped finish into step's rescue, which called finish a SECOND
    # time -- so the mode restore ran twice -- and @running was still latched
    # true at the end, leaving a completed batch claiming to be running and
    # the button needing the stale-reset path. Every file was on disk and the
    # summary was correct; only the bookkeeping lied.
    #
    # Order matters: @running goes down first so no raise can leave it up,
    # and the box is rescued like every other UI call in this file.
    @running  = false
    @unmapped = nil
    @results  = @results || []
    begin
      UI.messagebox(lines.join("\n"))
    rescue Exception => e
      puts "  (the summary box could not be shown: #{e.class}: #{e.message} " \
           '- the summary above is the whole of it, and the batch is finished)'
    end
    if @close_after
      @close_after = false
      begin
        dlg.close
      rescue StandardError
        nil
      end
    end
  end

  def self.summary_lines(why, restore_errs)
    ok    = @results.count { |r| r[:status] == 'ok' }
    skip  = @results.count { |r| %w[skipped cancelled].include?(r[:status]) }
    fails = @results.count { |r| r[:status] == 'failed' }
    lines = ["PROPOSAL PACKAGE — #{ok} exported, #{skip} skipped, #{fails} FAILED" \
             "#{why == 'done' ? '' : "  (#{why})"}"]
    lines << "  #{@cfg['dir']}"
    @results.each do |r|
      tag = { 'ok' => 'ok', 'failed' => 'FAILED', 'skipped' => 'skip',
              'cancelled' => 'cancel' }[r[:status]] || r[:status]
      lines << format('  %-7s %-40s (%s)', tag, r[:file], r[:detail])
    end
    (@unmapped || []).each { |s| lines << "  unmapped: #{s}" }
    lines << "  note: #{@mode_note}" if @mode_note
    (@quality_problems || []).each { |s| lines << "  render quality: #{s}" }
    restore_errs.each { |s| lines << "  *** RESTORE FAILED: #{s}" }
    # D8 -- the reconciliation pass 1 did not have. 5 rows were planned, 4
    # files were written, and the summary still said '0 FAILED'. A row that
    # produced no result at all now shows up HERE, by name.
    if @plan_files
      missing = @plan_files - @results.map { |r| r[:file] }
      unless missing.empty?
        lines << "  *** #{missing.size} PLANNED ROW(S) PRODUCED NO RESULT AT " \
                 "ALL - this is a lost row, not a skip:"
        missing.each { |f| lines << "        #{f}" }
      end
    end
    lines
  end

  # ------------------------------------------------------------ dialog io --

  def self.log(dlg, text, cls)
    dlg.execute_script("logLine(#{text.to_json}, #{cls.to_json})")
  rescue StandardError
    nil
  end

  def self.progress(dlg, msg)
    pct = @total.zero? ? 0 : (100.0 * @done / @total).round
    m = msg || "#{@done} of #{@total} step(s) done…"
    dlg.execute_script("setProgress(#{pct}, #{m.to_json})")
  rescue StandardError
    nil
  end

  # ---------------------------------------------------------- entry guards --
  #
  # Both entry decisions are PURE — flag in, verdict out — so rbtest-proposal.py
  # proves them offline. Every :decline / false verdict is announced by the
  # caller: this button must never again do nothing and say nothing.

  # The trailing autorun line's decision. True unless a loader suppressed it.
  def self.autorun?(no_autorun_flag)
    no_autorun_flag ? false : true
  end

  # What run() does about the live-batch flag:
  #   :launch  — nothing running, open the dialog
  #   :reset   — flag set, user confirmed it is stale: clear through FINISH,
  #              then open the dialog
  #   :decline — flag set, user did not confirm: leave the batch alone
  def self.launch_decision(running, reset_confirmed)
    return :launch unless running
    reset_confirmed ? :reset : :decline
  end

  # The way out of a stuck @running flag that does not need a restart.
  # Routed THROUGH finish(), not around it — the single-exit contract holds
  # even for the reset: mode, scene and camera are restored (best-effort,
  # loudly on failure) exactly as any other end of a batch.
  def self.reset_stale_batch(model)
    puts 'WR_ProposalPackage: clearing a stale batch flag through FINISH…'
    @results     ||= []
    @cfg         ||= {}
    @cancel        = false
    @close_after   = false
    begin
      @rend.stop if @rend                # reported API — best effort
    rescue Exception
      nil
    end
    @rend     = nil
    @awaiting = nil
    finish(model, @dlg, 'reset — stale batch state cleared from a new launch')
    @running = false                     # finish sets this; belt and braces
  end

  # ------------------------------------------------------------------ run --

  def self.run
    puts 'WR_ProposalPackage.run — opening the dialog…'   # "did the click reach Ruby?"
    model = Sketchup.active_model
    if model.nil? || model.pages.count.zero?
      puts 'WR_ProposalPackage: not opened — the model has no scenes.'
      UI.messagebox("This model has no scenes.\n\nAdd scenes first " \
                    '(View > Animation > Add Scene), or run ' \
                    "'Set up the five proposal plates'.")
      return
    end

    # Never stomp a live batch — killing its timer would skip FINISH and leave
    # the model mutated. The live run's own window has the Cancel button. But
    # a STALE flag (window gone, module reloaded mid-batch) must not brick the
    # button until a SketchUp restart, so a dead flag can be cleared here.
    if @running
      confirmed = UI.messagebox(
        "A proposal-package export is already running.\n\n" \
        "If its window is open, cancel it there — do NOT reset a live run.\n\n" \
        "If there is no window (the run is stuck or its window is gone),\n" \
        'press Yes to clear the stale state and open the dialog.',
        MB_YESNO
      ) == IDYES
      case launch_decision(true, confirmed)
      when :reset
        reset_stale_batch(model)
      else # :decline
        puts 'WR_ProposalPackage: not opened — a batch is (or claims to be) ' \
             'running and the reset was declined. Cancel it from its window, ' \
             'or press the button again and choose Yes to clear stale state.'
        return
      end
    end
    stop_stale_timer
    @results = []

    title = model.title.to_s.empty? ? '(unsaved model)' : model.title
    dir   = WR_Folder.read_list(FOLDER_KEY).first.to_s
    # read_default EVALS the stored string; a bad one raises SyntaxError, which
    # descends from ScriptError, not StandardError (wr-folder.rb's storage
    # rules) — so these rescue Exception, not a plain rescue.
    width = begin
      Sketchup.read_default(PREF, 'width', '2400').to_s
    rescue Exception
      '2400'
    end
    over = begin
      Sketchup.read_default(PREF, 'over', 'Ask').to_s
    rescue Exception
      'Ask'
    end
    shade = begin
      Sketchup.read_default(PREF, 'shade', 'Yes').to_s
    rescue Exception
      'Yes'
    end != 'No'
    annot = begin
      Sketchup.read_default(PREF, 'annot', 'client').to_s
    rescue Exception
      'client'
    end
    width = '2400' if width.strip.empty?
    over  = 'Ask' unless ['Ask', 'Overwrite', 'Skip existing'].include?(over)
    annot = 'client' unless %w[client draft].include?(annot)

    d = UI::HtmlDialog.new(
      :dialog_title    => "Proposal package — #{title}",
      :preferences_key => 'com.whisperroom.proposalpackage',
      :scrollable      => true,
      :resizable       => true,
      :width           => 700,
      :height          => 760,
      :min_width       => 520,
      :min_height      => 480,
      :style           => UI::HtmlDialog::STYLE_DIALOG
    )
    d.set_html(html(title, state(model), dir, width, over, shade, annot))
    @dlg = d   # so a stale-batch reset can reach the last window's log, if any

    d.add_action_callback('mark') do |_c, payload|
      begin
        data = JSON.parse(payload)
        page = model.pages.to_a[data['n'].to_i - 1]
        set_mode(page, data['mode'].to_s) if page
      rescue StandardError => e
        puts "  mark failed: #{e.class}: #{e.message}"
      end
      push_state(model, d)
    end

    d.add_action_callback('bulk') do |_c, payload|
      begin
        data  = JSON.parse(payload)
        pages = model.pages.to_a
        (data['ns'] || []).each do |n|
          page = pages[n.to_i - 1]
          set_mode(page, data['mode'].to_s) if page
        end
      rescue StandardError => e
        puts "  bulk mark failed: #{e.class}: #{e.message}"
      end
      push_state(model, d)
    end

    d.add_action_callback('setfill') do |_c, payload|
      begin
        data = JSON.parse(payload)
        name = data['name'].to_s
        name = '' if name == '(unset)'
        WR_MaterialsSwap.set_fill(model, data['slot'].to_s, name)
      rescue StandardError => e
        puts "  slot fill failed: #{e.class}: #{e.message}"
      end
      push_state(model, d)
    end

    d.add_action_callback('activate') do |_c, n|
      begin
        pg = model.pages.to_a[n.to_i - 1]
        model.pages.selected_page = pg if pg
      rescue StandardError => e
        puts "  could not activate scene #{n}: #{e.class}: #{e.message}"
      end
    end

    d.add_action_callback('browse') do |_c, cur|
      begin
        start = cur.to_s.strip.delete('"')
        start = WR_Folder.read_list(FOLDER_KEY).first.to_s unless File.directory?(start)
        opts = { :title => 'Where should the package go?' }
        opts[:directory] = start if !start.empty? && File.directory?(start)
        chosen = UI.select_directory(opts)
        unless chosen.nil? || chosen.to_s.empty?
          p = chosen.to_s.tr('\\', '/')
          WR_Folder.remember(FOLDER_KEY, p)
          d.execute_script("setDir(#{p.to_json})")
        end
      rescue StandardError => e
        puts "  browse failed: #{e.class}: #{e.message}"
      end
    end

    d.add_action_callback('export') do |_c, payload|
      begin
        cfg = JSON.parse(payload)
        start_run(model, d, cfg)
      rescue StandardError => e
        UI.messagebox("Export failed to start:\n\n#{e.class}: #{e.message}")
        puts "FAILED: #{e.class}: #{e.message}"
        puts e.backtrace.first(5)
      end
    end

    d.add_action_callback('cancelrun') { |_c| @cancel = true if @running }

    d.add_action_callback('close') do |_c|
      if @running
        @cancel = true        # Close during a run behaves as Cancel first;
        @close_after = true   # FINISH closes the window after the restore.
      else
        d.close
      end
    end

    d.show
    puts 'WR_ProposalPackage: dialog shown.'
    nil
  rescue Exception => e
    # Exception, not StandardError — the repo rule (main.rb, "running"): a
    # ScriptError must become a message box here, never a silent dead button.
    UI.messagebox("Proposal package failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
    raise if e.is_a?(SystemExit) || e.is_a?(NoMemoryError)
  end

  # ----------------------------------------------------------------- html --

  def self.html(title, st, dir, width, over, shade, annot)
    <<-HTML
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Proposal package</title>
<style>
  :root { --bg:#f4f5f6; --surface:#fff; --ink:#1c2327; --muted:#66727a;
          --faint:#9aa4ab; --line:#e2e6e9; --accent:#ee6216; --soft:#fdeee4;
          --ok:#2e7d46; --bad:#b0402c; }
  * { box-sizing:border-box; margin:0; }
  html,body { height:100%; }
  body { font:13px/1.45 "Segoe UI",system-ui,sans-serif; background:var(--bg);
         color:var(--ink); display:flex; flex-direction:column; overflow:hidden; }
  ::-webkit-scrollbar { width:9px; height:9px; }
  ::-webkit-scrollbar-thumb { background:#c9d0d5; border-radius:5px; }

  .top { flex:0 0 auto; padding:10px 12px 6px; display:flex; gap:10px; align-items:baseline; }
  .top .t { font-weight:650; }
  .top .c { color:var(--muted); font-size:12px; margin-left:auto; }
  .cmd { flex:0 0 auto; margin:0 12px 8px; }
  .cmd input { width:100%; padding:8px 10px; font:inherit; color:var(--ink);
    background:var(--surface); border:1px solid var(--line); border-radius:8px; outline:none; }
  .cmd input:focus { border-color:var(--accent); }

  .bulk { flex:0 0 auto; margin:0 12px 8px; padding:8px 11px; background:var(--surface);
          border:1px solid var(--line); border-radius:8px; display:flex; gap:8px; align-items:center; }
  .bulk .lbl { font-size:10.5px; font-weight:650; letter-spacing:.1em; color:var(--faint); }
  .btn { font:inherit; font-size:12px; padding:5px 11px; border:1px solid var(--line);
         border-radius:6px; background:var(--surface); color:var(--ink); cursor:pointer;
         white-space:nowrap; }
  .btn:hover { border-color:var(--accent); }
  .btn.p { background:var(--accent); border-color:var(--accent); color:#fff; font-weight:650; }
  .btn.p:disabled { background:#f0b48e; border-color:#f0b48e; cursor:default; }
  .btn:disabled { color:var(--faint); cursor:default; border-color:var(--line); }

  .wrap { flex:1 1 auto; overflow:auto; margin:0 12px 10px; background:var(--surface);
          border:1px solid var(--line); border-radius:9px; min-height:140px; }
  table { width:100%; border-collapse:collapse; }
  th { position:sticky; top:0; background:var(--surface); text-align:left;
       font-size:10.5px; font-weight:650; letter-spacing:.09em; color:var(--faint);
       padding:8px 9px; border-bottom:1px solid var(--line); white-space:nowrap; z-index:2; }
  td { padding:5px 9px; border-top:1px solid var(--line); vertical-align:middle; }
  tr:hover td { background:#f8f4f1; }
  td.n { font-variant-numeric:tabular-nums; color:var(--muted); width:1%; white-space:nowrap; }
  td.file { color:var(--muted); font-size:11.5px; white-space:nowrap; overflow:hidden;
            text-overflow:ellipsis; max-width:210px; }
  td.file b { color:var(--accent); font-weight:600; }
  td.go { width:1%; }
  .go button { border:0; background:transparent; color:var(--faint); cursor:pointer;
               font-size:13px; padding:0 4px; }
  .go button:hover { color:var(--accent); }
  mark { background:#ffe3a8; color:inherit; border-radius:2px; }

  .seg { display:inline-flex; border:1px solid var(--line); border-radius:6px; overflow:hidden; }
  .seg button { font:inherit; font-size:11px; padding:3px 9px; border:0; background:var(--surface);
                color:var(--muted); cursor:pointer; border-left:1px solid var(--line); }
  .seg button:first-child { border-left:0; }
  .seg button.on-skip   { background:#eef1f2; color:var(--muted); font-weight:650; }
  .seg button.on-image  { background:#e8f0fa; color:#2b5e8f; font-weight:650; }
  .seg button.on-render { background:var(--soft); color:var(--accent); font-weight:650; }

  .sect { flex:0 0 auto; margin:0 12px 8px; background:var(--surface);
          border:1px solid var(--line); border-radius:8px; }
  .sect > .hd { padding:8px 11px; display:flex; gap:8px; align-items:center; cursor:pointer;
                user-select:none; }
  .sect .hd .lbl { font-size:10.5px; font-weight:650; letter-spacing:.1em; color:var(--faint); }
  .sect .hd .sum { color:var(--muted); font-size:11.5px; margin-left:auto; }
  .sect .hd .tri { color:var(--faint); font-size:10px; }
  .sect .bodyy { padding:2px 11px 10px; display:none; }
  .sect.open .bodyy { display:block; }
  .matrow { display:flex; gap:8px; align-items:center; padding:4px 0; }
  .matrow .from { width:230px; flex:0 0 auto; color:var(--muted); font-size:12px; }
  .matrow .from b { color:var(--ink); font-weight:600; }
  .matrow select { flex:1 1 auto; font:inherit; font-size:12px; padding:4px 6px;
                   border:1px solid var(--line); border-radius:6px; background:#fff;
                   color:var(--ink); min-width:0; }
  .matnote { color:var(--muted); font-size:11px; padding-top:6px;
             border-top:1px dashed var(--line); margin-top:6px; }

  .out { flex:0 0 auto; margin:0 12px 8px; padding:9px 11px; background:var(--surface);
         border:1px solid var(--line); border-radius:8px; display:grid;
         grid-template-columns:auto 1fr auto; gap:7px 8px; align-items:center; }
  .out .lbl { font-size:10.5px; font-weight:650; letter-spacing:.08em; color:var(--faint); }
  .out input, .out select { font:inherit; font-size:12px; padding:5px 8px;
               border:1px solid var(--line); border-radius:6px; background:#fff;
               color:var(--ink); min-width:0; }
  .out input:focus { border-color:var(--accent); outline:none; }
  .out .half { display:flex; gap:8px; align-items:center; flex-wrap:wrap; }
  .out .half .lbl { width:auto; }
  .out .half input[type=text] { width:72px; }
  .out .shadelbl { font-size:11.5px; color:var(--muted); }

  .runlog { flex:0 0 auto; margin:0 12px 8px; background:#20262a; color:#cdd6da;
            border-radius:8px; font:11px/1.6 Consolas,monospace; padding:8px 11px;
            max-height:130px; overflow:auto; display:none; }
  .runlog .ok { color:#8fd0a0; } .runlog .bad { color:#f0a08c; } .runlog .dim { color:#8b979e; }
  .bar { flex:0 0 auto; padding:0 12px 12px; display:flex; gap:8px; align-items:center; }
  .prog { flex:1 1 auto; color:var(--muted); font-size:11.5px; }
  .prog .pbar { height:4px; background:#e6e9eb; border-radius:2px; margin-top:4px; overflow:hidden; }
  .prog .pbar i { display:block; height:100%; width:0%; background:var(--accent); transition:width .2s; }
  .foot { flex:0 0 auto; padding:0 12px 10px; color:var(--muted); font-size:11px; }
</style></head><body>

<div class="top">
  <span class="t">#{escHtml(title)}</span>
  <span class="c" id="count"></span>
</div>

<div class="cmd">
  <input id="q" placeholder="Search scenes — several words, any order — or a range like 1-5"
         autocomplete="off" spellcheck="false">
</div>

<div class="bulk">
  <span class="lbl">SHOWN &rarr;</span>
  <button class="btn" data-bulk="render">Render</button>
  <button class="btn" data-bulk="image">Image</button>
  <button class="btn" data-bulk="skip">Skip</button>
  <span class="lbl" style="margin-left:auto" id="picksum"></span>
</div>

<div class="wrap"><table>
  <thead><tr>
    <th>#</th><th>SCENE</th><th>MODE</th><th>FILE IT WILL WRITE</th><th></th>
  </tr></thead>
  <tbody id="body"></tbody>
</table></div>

<div class="sect" id="mats">
  <div class="hd" id="matshd">
    <span class="tri">&#9654;</span>
    <span class="lbl">MATERIALS FOR THE V-RAY PASS</span>
    <span class="sum" id="matsum"></span>
  </div>
  <div class="bodyy" id="matbody"></div>
</div>

<div class="out">
  <span class="lbl">FOLDER</span>
  <input type="text" id="dir" value="#{escAttr(dir)}" style="width:100%">
  <button class="btn" id="browse">Browse&hellip;</button>

  <span class="lbl">IMAGES</span>
  <div class="half">
    <span class="lbl">WIDTH</span><input type="text" id="width" value="#{escAttr(width)}">
    <span class="lbl">PX — height follows the viewport aspect. V-Ray renders use the size in the V-Ray Asset Editor.</span>
  </div>
  <span></span>

  <span class="lbl">EXISTS?</span>
  <select id="over" style="max-width:200px">
    <option#{over == 'Ask' ? ' selected' : ''}>Ask</option>
    <option#{over == 'Overwrite' ? ' selected' : ''}>Overwrite</option>
    <option#{over == 'Skip existing' ? ' selected' : ''}>Skip existing</option>
  </select>
  <span></span>

  <span class="lbl">SHADING</span>
  <label class="shadelbl"><input type="checkbox" id="shade"#{shade ? ' checked' : ''}>
    Even shading for plain images (shadows off, Light #{WR_Shading::DEF_LIGHT} / Dark #{WR_Shading::DEF_DARK} — the component-art contract). V-Ray scenes are never touched by this.</label>
  <span></span>

  <span class="lbl">ANNOTATION</span>
  <select id="annot">
    <option value="client"#{annot == 'draft' ? '' : ' selected'}>Client-safe — hide dimensions and notes</option>
    <option value="draft"#{annot == 'draft' ? ' selected' : ''}>Draft — keep dimensions and notes visible</option>
  </select>
  <span></span>
  <span class="lbl"></span>
  <label class="shadelbl">Client-safe hides #{WR_Mode::ANNOT_TAGS.join(', ')} for the whole run and puts every one back at the end. Choose Draft only for an internal check print — those images carry construction dimensions and the ceiling-height note.</label>
  <span></span>
</div>

<div class="runlog" id="log"></div>

<div class="bar">
  <div class="prog"><span id="pmsg">Ready.</span><div class="pbar"><i id="pfill"></i></div></div>
  <button class="btn" id="cancel" style="display:none">Cancel</button>
  <button class="btn" id="closeb">Close</button>
  <button class="btn p" id="export">Export package</button>
</div>

<div class="foot"># is the scene's position in the tabs — same number the exporters use.
  The arrow jumps to that scene. Filenames are the scene names verbatim; only characters
  Windows forbids become &ldquo;-&rdquo;, and a V-Ray scene gets &ldquo; render&rdquo; added.
  Size the SketchUp window to the aspect you want before exporting.</div>

<script>
(function () {
  "use strict";
  var ST = #{st.to_json};
  var running = false;

  function g(id){ return document.getElementById(id); }
  var $q=g("q"), $b=g("body"), $count=g("count"), $pick=g("picksum"),
      $log=g("log"), $pmsg=g("pmsg"), $pfill=g("pfill");

  function esc(s){ return String(s==null?"":s).replace(/&/g,"&amp;")
    .replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;")
    .replace(/'/g,"&#39;"); }   // scene names go into title='...' attributes

  // ---- search: list-scenes semantics, over scene names only ----
  function terms(q){ return q.toLowerCase().split(/\\s+/).filter(function(t){return t.length>0;}); }
  function parseNums(q){
    if (!/^[\\d\\s,\\-]+$/.test(q)) return null;
    var want={}, only=/[,\\-]/.test(q);
    q.split(",").forEach(function(tok){
      tok=tok.trim(); if(!tok) return;
      var m=tok.match(/^(\\d+)\\s*-\\s*(\\d+)$/);
      if (m){ var a=+m[1],b=+m[2]; if(a>b){var t=a;a=b;b=t;} for(var k=a;k<=b;k++) want[k]=1; }
      else if (/^\\d+$/.test(tok)) want[+tok]=1;
    });
    return Object.keys(want).length ? {want:want, only:only} : null;
  }
  function hl(t, ts){
    var s=String(t==null?"":t);
    if(!ts || !ts.length) return esc(s);
    var lo=s.toLowerCase(), spans=[];
    ts.forEach(function(term){
      if(!term) return; var i=lo.indexOf(term);
      while(i>=0){ spans.push([i,i+term.length]); i=lo.indexOf(term,i+term.length); }
    });
    if(!spans.length) return esc(s);
    spans.sort(function(a,b){return a[0]-b[0]||a[1]-b[1];});
    var out="", at=0;
    spans.forEach(function(sp){
      if(sp[1]<=at) return; var a=sp[0]>at?sp[0]:at;
      out+=esc(s.slice(at,a))+"<mark>"+esc(s.slice(a,sp[1]))+"</mark>"; at=sp[1];
    });
    return out+esc(s.slice(at));
  }

  // ---- table ----
  var view = ST.rows.slice();
  function segBtn(r,m,label){
    return "<button data-n='"+r.n+"' data-mode='"+m+"' class='"+(r.mode===m?("on-"+m):"")+"'>"+label+"</button>";
  }
  function draw(){
    var q=$q.value.trim(), nums=parseNums(q), ts=terms(q);
    view = ST.rows.filter(function(r){
      if(!q) return true;
      if(nums && nums.only) return !!nums.want[r.n];
      if(nums && nums.want[r.n]) return true;
      var s=r.scene.toLowerCase();
      return ts.length>0 && ts.every(function(t){ return s.indexOf(t)>=0; });
    });
    var hi=(nums&&nums.only)?[]:ts;
    $b.innerHTML = view.map(function(r){
      var fh = r.file ? esc(r.file).replace(/ render(?=( \\(\\d+\\))?\\.png$)/," <b>render</b>") : "&mdash;";
      return "<tr data-n='"+r.n+"'>"+
        "<td class='n'>"+r.n+"</td>"+
        "<td>"+hl(r.scene,hi)+"</td>"+
        "<td><span class='seg'>"+
          segBtn(r,"skip","Skip")+segBtn(r,"image","Image")+segBtn(r,"render","Render")+
        "</span></td>"+
        "<td class='file' title='"+esc(r.file)+"'>"+fh+"</td>"+
        "<td class='go'><button data-go='"+r.n+"' title='Go to this scene'>&#8594;</button></td></tr>";
    }).join("");
    Array.prototype.forEach.call($b.querySelectorAll("[data-mode]"), function(el){
      el.addEventListener("click", function(){
        if(running) return;
        if(window.sketchup && sketchup.mark)
          sketchup.mark(JSON.stringify({ n:+el.getAttribute("data-n"),
                                         mode:el.getAttribute("data-mode") }));
      });
    });
    Array.prototype.forEach.call($b.querySelectorAll("[data-go]"), function(el){
      el.addEventListener("click", function(e){
        e.stopPropagation();
        if(window.sketchup && sketchup.activate) sketchup.activate(el.getAttribute("data-go"));
      });
    });
    var nr=ST.rows.filter(function(r){return r.mode==="render";}).length,
        ni=ST.rows.filter(function(r){return r.mode==="image";}).length;
    $count.textContent = (view.length===ST.rows.length ? ST.rows.length+" scenes"
                          : view.length+" of "+ST.rows.length)
                         + " · "+nr+" render · "+ni+" image";
    $pick.textContent = nr+" RENDER · "+ni+" IMAGE · "+(ST.rows.length-nr-ni)+" SKIP";
    var filled = ST.slots.filter(function(s){ return s.fill; }).length;
    g("matsum").textContent = nr ? (filled+" of "+ST.slots.length+" slots filled — applies to "
                                    +nr+" render scene(s)")
                                 : "no render scenes marked";
    g("export").disabled = running || (nr+ni)===0;
  }

  function drawMats(){
    g("matbody").innerHTML = ST.slots.map(function(s){
      var opts = ["(unset)"].concat(ST.materials).map(function(m){
        var cur = s.fill ? s.fill : "(unset)";
        return "<option"+(m===cur?" selected":"")+">"+esc(m)+"</option>";
      }).join("");
      return "<div class='matrow'><span class='from'>"+esc(s.label)+" <b>"+esc(s.draft)+
             "</b> &rarr; "+esc(s.slot)+"</span>"+
             "<select data-slot='"+esc(s.slot)+"'>"+opts+"</select></div>";
    }).join("") +
    "<div class='matnote'>Applied only while the V-Ray scenes render, and reverted before this " +
    "window says done — the model goes back to drafting materials. A slot left (unset) leaves " +
    "those surfaces drafting and is <b>reported by name</b>, never silently wrong. Same slots as " +
    "the Draft / Render toggle — set them in either place. If SketchUp ever dies mid-render, " +
    "the Toggle Draft/Render button puts the model back.</div>";
    Array.prototype.forEach.call(g("matbody").querySelectorAll("select"), function(sel){
      sel.addEventListener("change", function(){
        if(window.sketchup && sketchup.setfill)
          sketchup.setfill(JSON.stringify({ slot:sel.getAttribute("data-slot"), name:sel.value }));
      });
    });
  }

  // Ruby pushes fresh rows + filenames after every mark / bulk / fill change,
  // so the FILE column always shows what the export will actually write.
  window.applyState = function (st) { ST = st; drawMats(); draw(); };
  window.setDir = function (d) { g("dir").value = d; };

  // ---- run feedback, driven from Ruby ----
  window.logLine = function (text, cls) {
    $log.style.display="block";
    $log.innerHTML += "<span class='"+(cls||"dim")+"'>"+esc(text)+"</span><br>";
    $log.scrollTop = 1e6;
  };
  window.setProgress = function (pct, msg) {
    $pfill.style.width = pct+"%"; $pmsg.textContent = msg;
  };
  window.runStarted = function () {
    running = true; $log.innerHTML=""; $log.style.display="block";
    g("cancel").style.display=""; $pfill.style.width="0%"; draw();
  };
  window.runFinished = function (msg) {
    running = false; g("cancel").style.display="none"; $pmsg.textContent = msg; draw();
  };

  // ---- wiring ----
  Array.prototype.forEach.call(document.querySelectorAll("[data-bulk]"), function(el){
    el.addEventListener("click", function(){
      if(running) return;
      var ns = view.map(function(r){ return r.n; });
      if(window.sketchup && sketchup.bulk)
        sketchup.bulk(JSON.stringify({ ns:ns, mode:el.getAttribute("data-bulk") }));
    });
  });
  $q.addEventListener("input", draw);
  g("matshd").addEventListener("click", function(){
    var s=g("mats"); s.classList.toggle("open");
    s.querySelector(".tri").innerHTML = s.classList.contains("open")?"&#9660;":"&#9654;";
  });
  g("browse").addEventListener("click", function(){
    if(window.sketchup && sketchup.browse) sketchup.browse(g("dir").value);
  });
  g("cancel").addEventListener("click", function(){
    if(window.sketchup && sketchup.cancelrun) sketchup.cancelrun();
    $pmsg.textContent = "Cancelling — finishing the current step, then restoring the model…";
  });
  g("closeb").addEventListener("click", function(){
    if(window.sketchup && sketchup.close) sketchup.close();
  });
  g("export").addEventListener("click", function(){
    if(running) return;
    if(window.sketchup && sketchup.export)
      sketchup.export(JSON.stringify({
        dir:   g("dir").value,
        width: g("width").value,
        over:  g("over").value,
        shade: g("shade").checked,
        annot: g("annot").value
      }));
  });

  drawMats();
  draw();
}());
</script></body></html>
    HTML
  end

  def self.escAttr(s)
    s.to_s.gsub('&', '&amp;').gsub('"', '&quot;').gsub('<', '&lt;')
  end

  def self.escHtml(s)
    s.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
  end
end

# The autorun line — the panel button IS this line. It can be suppressed by a
# loader that sets $wr_no_autorun on purpose (main.rb's load_quietly, another
# script pulling this file in as a library), but NEVER silently: a skip is
# announced on the console with the way to launch by hand, because a truthy
# flag here can also be STALE — left behind by a loader that crashed between
# set and restore — and a stale flag suppressing this line is exactly how the
# button once did nothing at all (2026-08-27).
begin
  if WR_ProposalPackage.autorun?($wr_no_autorun)
    WR_ProposalPackage.run
  else
    puts 'WR_ProposalPackage: loaded but NOT launched — $wr_no_autorun is ' \
         "#{$wr_no_autorun.inspect}. A loader that set it gets this on " \
         'purpose; anywhere else the flag is stale. To open the dialog run:' \
         "\n  WR_ProposalPackage.run" \
         "\nand to clear a stale flag for good:  $wr_no_autorun = nil"
  end
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).map { |l| "  #{l}" }.join("\n") if e.backtrace
  UI.messagebox("Proposal package failed:\n\n#{e.class}: #{e.message}\n\nSee the Ruby Console.")
end
