# @title Proposal package...
# @cat V-Ray renders
# @rank 0
#
# One button for a proposal's whole image set. Lists every scene in the model,
# lets each one be marked Skip / Image / Render AND choose which whole walls
# that scene hides (the WALLS column, since 1.15.0 — Benton: "It should be in
# the same UI, next to mode"), picks an output folder, and
# writes `<Scene Name>.png` (plain SketchUp export) or `<Scene Name> render.png`
# (V-Ray) into that folder — leaving the model exactly as it was. Since 1.10.7
# every batch also writes `manifest.json` beside the images: scene name, export
# order, lane, status, pixel size and every dimension/callout STRING the model
# holds — so the proposal-assembly step reads facts instead of re-deriving them
# from pixels at 300-700 dpi (see the manifest section below).
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
#     mode snapshot. It is RE-APPLIED after every scene switch inside the
#     export loop (1.19.3) -- a proposal scene stores its own shadow info and
#     rendering options and puts them back on selection, which silently undid
#     the contract on every row before that.
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
  # The per-scene wall hiding lives here now, next to MODE, because that is
  # where the operator is when they decide a shot needs the back wall gone.
  # wr-scene-walls.rb stays a standalone tool as well; this reuses its
  # inventory/apply so there is ONE mechanism, not two that can disagree.
  load File.join(File.dirname(__FILE__), 'wr-scene-walls.rb')
  # ...and its annotation twin (1.20.0). Same reasoning one column over: the
  # operator decides a shot needs the ceiling note gone while they are looking
  # at the scene list, not in another window. wr-scene-annotations.rb stays a
  # standalone tool too; this reuses its inventory/apply so there is ONE
  # mechanism, not two that can disagree.
  load File.join(File.dirname(__FILE__), 'wr-scene-annotations.rb')
  # SUN column (1.27.0): wr-sun-aim.rb is the aiming maths (it honours
  # $wr_no_autorun, so no dialog opens); wr-scene-sun.rb is the per-scene
  # save, a library in wr_tools' SKIP list.
  load File.join(File.dirname(__FILE__), 'wr-sun-aim.rb')
  load File.join(File.dirname(__FILE__), 'wr-scene-sun.rb')
  # The sRGB post-encode for the render lane (the dark-file fix — see the
  # THE DARK RENDERS section above save_frame). Pure Ruby, no tool of its own.
  load File.join(File.dirname(__FILE__), 'wr-png-srgb.rb')
ensure
  $wr_no_autorun = wr_pp_autorun_was
end

module WR_ProposalPackage
  %w[DICT PREF FORBIDDEN FOLDER_KEY SLOT_LABEL
     IDLE_STATE DONE_STATE ERROR_STATE RENDER_TIMEOUT_S UNREADABLE_LIMIT
     START_WINDOW_S STOP_CONFIRM_S CAM_FIELDS
     ASPECT_W ASPECT_H EV_F_NUMBER EV_ISO EV_INTERIOR EV_ROOM EV_MIN EV_MAX
     INTERIOR_RE MODE_FALLBACK QUALITY ANNOT_TAGS
     MANIFEST_FORMAT MANIFEST_NOTES].each do |c|
    remove_const(c) if const_defined?(c, false)
  end

  DICT       = 'WR_ProposalPackage'.freeze
  PREF       = 'WR_ProposalPackage'.freeze
  FOLDER_KEY = 'package'.freeze

  # Only what Windows genuinely refuses — export-scenes.rb's rule, verbatim.
  FORBIDDEN = /[<>:"\/\\|?*\x00-\x1f]/.freeze

  # Human label for each render slot. Keyed by the SLOT, not by the drafting
  # material: since 1.9.10 each slot's source material is per-model and
  # pickable, so the draft name is a value that moves, not a stable key.
  # WR_MaterialsSwap remains the one owner of the slot table itself.
  SLOT_LABEL = { 'WR-Floor-Render' => 'Floor',
                 'WR-Wall-Render'  => 'Walls',
                 'WR-Door-Render'  => 'Door' }.freeze

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

  # ...and since 1.20.0 the family is a PATTERN as well as those five names.
  # wr-scene-annotations.rb lets Benton create sets — WR-Notes-Plan,
  # WR-Dims-Booth-Alt — and a set this list had never heard of would sail
  # straight through the client-safe pass, which is defect D5 verbatim. So
  # every client-safe site asks the model, not the constant. The constant
  # remains the floor and the fallback: WR_ProposalScenes.annot_tags rescues
  # to it, so an unreadable layer collection still hides the five.
  def self.annot_tags(model)
    WR_ProposalScenes.annot_tags(model)
  rescue StandardError
    ANNOT_TAGS
  end

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
  #
  # ISO COUNTS (1.32.0). This used to derive EV from f-number and shutter
  # alone, which is right only at ISO 100 -- and wr-drop-lights.rb stamps
  # ISO 3200 into every model it touches. On such a model the log said
  # "EV 14.23" for a camera that is really at EV 9.23, five stops out
  # (.forge/fixer/sun-blowout.md, loose end 4). A wrong number in the log
  # is how "the exposure looks fine" gets said about a blown or a dark
  # render. `iso` is optional so the harness's ISO-100 cases still hold;
  # a missing or non-positive ISO is treated as 100 and said so by the
  # caller.
  def self.ev_of_camera(f_number, shutter, iso = nil)
    return nil unless f_number.is_a?(Numeric) && shutter.is_a?(Numeric)
    f = f_number * 1.0
    sp = shutter * 1.0
    return nil if f <= 0.0 || sp <= 0.0
    ev = Math.log((f * f) * sp) / Math.log(2.0)
    if iso.is_a?(Numeric) && iso > 0.0
      ev -= Math.log((iso * 1.0) / 100.0) / Math.log(2.0)
    end
    ev
  end

  # PURE. F3: where the model goes at the end of a batch. WR_Mode.current
  # returns 'unknown (never toggled)' on a model that has never been toggled,
  # and that value used to make finish SKIP the restore in silence -- OBSERVED
  # 30 Aug 2026, model left in RENDER mode. Anything that is not a real mode
  # now resolves to MODE_FALLBACK and the summary SAYS so.
  def self.mode_restore_target(saved_mode)
    %w[draft render].include?(saved_mode.to_s) ? saved_mode.to_s : MODE_FALLBACK
  end

  # PURE (D11, 1.9.6). The planned rows that produced no result of any kind --
  # not an ok, not a skip, not a failure. A LOST ROW: a client pack one render
  # short. D8 added the reconciliation and printed it at the bottom of the
  # summary, but the HEADLINE count and the dialog's closing verdict were both
  # computed from @results alone, so the window Benton actually watches said
  # '0 FAILED' and 'Done. Model restored.' on a batch that lost a row.
  #
  # One method, used by BOTH the headline and the verdict, so they can never
  # disagree again.
  def self.lost_rows(plan_files, result_files)
    return [] if plan_files.nil?
    plan_files.to_a - result_files.to_a
  end

  # The window the last run in this folder exported from, from its
  # manifest.json, or nil. Read-only, individually rescued: a folder with
  # no manifest, or a manifest from before 1.31.0 (no 'viewport'), is nil.
  def self.prior_viewport(dir)
    path = File.join(dir.to_s, 'manifest.json')
    return nil unless File.exist?(path)
    m = JSON.parse(File.read(path))
    v = m['viewport']
    return nil unless v.is_a?(Array) && v.size == 2 && v.all? { |x| x.is_a?(Integer) && x > 0 }
    v
  rescue Exception
    nil
  end

  # THE HONOURED SIZE (1.9.4). V-Ray's own /SettingsOutput if it can be read,
  # otherwise the Width field at ASPECT_W:ASPECT_H. Sets @size_source so every
  # later log line can say WHERE the number came from rather than just quoting
  # it -- a size that silently fell back to a default and a size the operator
  # chose look identical on disk.
  def self.honoured_size(width_field)
    sz = output_size(vray_context)
    if sz && sz[0] > 0 && sz[1] > 0
      @size_source = 'the V-Ray Asset Editor (/SettingsOutput)'
      return sz
    end
    @size_source = 'this tool\'s Width field - V-RAY\'S OWN SIZE COULD NOT BE READ'
    package_size(width_field)
  end

  # A RENDER BATCH REFUSES TO GUESS ITS OWN SIZE.
  #
  # For an image-only batch the Width fallback is fine -- view.write_image has
  # to be told a size and there is nothing else to ask. For a RENDER batch it
  # is not: falling back means quietly rendering at a shape the operator never
  # chose, which is exactly the 1200x900-instead-of-1600x900 defect this
  # release exists to fix. Named refusal, not a substitution.
  def self.require_render_size!
    return nil if @size_source.to_s.start_with?('the V-Ray')
    'V-Ray is being asked to render, but its output size could not be read ' \
      "from /SettingsOutput (#{@size_source}). Open the V-Ray Asset Editor, " \
      'confirm the render output size, and run this again. Nothing was ' \
      'rendered, because a render at a size nobody chose is worse than no ' \
      'render.'
  end

  # THE ORDER IS THE FIX (D9, 1.9.6). require_render_size! judges @size_source;
  # honoured_size is the only thing that ever SETS it. Until 1.9.6 start_run
  # asked the gate at :774 and read the size at :942 -- 168 lines later, past
  # the gate's own `return` -- so on a fresh load @size_source was nil, the
  # refusal fired, start_run returned BEFORE the read, and the next press was
  # identical. Every batch containing a render row was refused on every press,
  # permanently, with a message telling Benton to check a setting that nothing
  # had looked at. It survived because the one hand-written live test called
  # honoured_size and THEN require_render_size! -- the one order in which the
  # bug is invisible. The button used the other order.
  #
  # The two steps are now welded into ONE method, in the only order that can
  # be correct: READ, then JUDGE. Nothing else may call require_render_size!.
  #
  # Returns [[w, h], refusal_or_nil]. The refusal is still a REAL refusal and
  # is still the whole point of the gate: a render batch whose size genuinely
  # cannot be read is stopped, because rendering at a size nobody chose is the
  # defect this release exists to prevent.
  def self.render_size_gate(width_field, has_render_row)
    @size_source = nil
    size = honoured_size(width_field)                  # READ (sets @size_source)
    why  = has_render_row ? require_render_size! : nil # ...then JUDGE
    [size, why]
  end

  # PURE. One width in, the package's whole output size out -- the FALLBACK
  # shape only (D4). Kept because an image-only batch still needs a size when
  # there is no V-Ray to ask.
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

  # SCENE NUMBER PREFIX (1.26.2). Benton: "add the scene number right in
  # front of the file name ... one underscore overview ... that way we can
  # better send that to the proposal since the files will already be in
  # order." The number is the scene's TABLE number — its position in the
  # scene tabs, skipped scenes counted — zero-padded to the width the
  # scene count needs. His literal "1_" is kept for a model of nine scenes
  # or fewer; past nine, "10_" would sort between "1_" and "2_" and defeat
  # the ordering he asked for (PeoplesSpace has thirteen), so the intent
  # wins over the example: "01_Overview.png". Reordering scenes therefore
  # renames files; a re-export after a reorder leaves the old-numbered
  # files beside the new ones, because the EXISTS? policy only ever looks
  # at the names it is about to write.
  def self.scene_prefix(n, total)
    width = [total.to_s.length, 1].max
    format("%0#{width}d_", n.to_i)
  end

  # rows: [{'n'=>Integer, 'scene'=>String, 'mode'=>'skip'|'image'|'render'}]
  # in pages order. Returns { n => 'NN_file.png' } for every non-skip row.
  # ONE collision map across BOTH lanes, and the " render" suffix goes on
  # AFTER sanitising (the suffix contains no forbidden characters) — so
  # "05-plan" marked render and a scene named "05-plan render" marked image
  # feed the same map and the second one gets "(2)", visibly, in the FILE
  # column before anything is written. The prefix goes on BEFORE the map,
  # so a scene literally named "02_Plan" at position 1 reads "01_02_Plan"
  # rather than colliding with scene 2; two scenes sharing a name now
  # differ by prefix and the "(2)" suffix is only reached if the prefixed
  # names still collide, which they cannot.
  def self.plan_names(rows)
    used = {}
    out  = {}
    rows.each do |r|
      next if r['mode'] == 'skip'
      base = sanitize(r['scene'])
      base = 'scene' if base.empty?
      base = scene_prefix(r['n'], rows.size) + base
      base += ' render' if r['mode'] == 'render'
      out[r['n']] = "#{uniquify(base, used)}.png"
    end
    out
  end

  # -------------------------------------------------------------- manifest --
  #
  # WHY (1.10.7, the 45-minute finding). This tool used to write bare PNGs and
  # throw away everything else it knew: which scene a file came from, the
  # export order, and — the expensive part — the dimension callouts, which the
  # model holds as TEXT and the assembly agent then read back OFF THE PIXELS
  # at 300-700 dpi, one crop at a time (.forge/researcher/
  # proposal-image-step-timing.md §6 item 1). So every batch now writes
  # `manifest.json` beside the images. Same name, same serialisation and same
  # placement as the two existing manifest writers — export-component-art.rb
  # and orbit-export.rb — because a third incompatible shape would be a
  # defect, not a feature.
  #
  # THE HONESTY RULE, and it outranks completeness: nothing in this file may
  # invent a number. A dimension's `text` is the entity's own string,
  # verbatim ('<>' is SketchUp's placeholder for the computed value).
  # `measured` / `measured_in` are the straight-line distance between the
  # dimension's two anchor points — the model's own geometry, formatted by
  # the model's own unit settings — never a default and never a guess.
  # Anything unreadable is emitted as null with a note naming why; a missing
  # value FAILS BY NAME so a later reader cannot mistake absence for zero.
  #
  # The four methods below are PURE (data in, data out) so rbtest-proposal.py
  # proves them offline; the collectors and the writer further down touch the
  # SketchUp API and can only be proven live.

  MANIFEST_FORMAT = 1

  # What each field means, carried INSIDE the file because the reader of a
  # manifest.json in a client folder will not have this source open.
  MANIFEST_NOTES = [
    'measured / measured_in: straight-line distance between the dimension\'s ' \
    'two anchor points, in the model\'s units / in decimal inches. Model ' \
    'geometry, not the rendered string; for the axis-aligned dimensions the ' \
    'WR tools draw, it is the displayed value. null = unreadable, never zero.',
    'text: the entity\'s text property verbatim; \'<>\' is SketchUp\'s ' \
    'placeholder for the computed value. display: text with \'<>\' replaced ' \
    'by measured when both are known.',
    'annotation_tags_shown: the tags the scene\'s SAVED state shows - it says ' \
    'a callout\'s tag was visible, NOT that the callout lands inside the ' \
    'camera frame. Match annotations to a scene through their tag.',
    'annotations_hidden_in_images true means the batch ran client-safe: the ' \
    'exported files carry NO annotation text regardless of scene state.',
    'width/height null on an image row = not recorded (row failed, was ' \
    'skipped, or was lost) - never a default.',
    'groups_hidden: paths of model groups (e.g. \'3190J / Walls / Wall 2\') ' \
    'hidden in the model when this row exported - a wall missing from the ' \
    'image is missing BY DESIGN (per-scene wall hiding, wr-scene-walls.rb), ' \
    'not a modelling error. Read from the live model after the row\'s scene ' \
    'was selected. null = not recorded (row failed, skipped, or lost) - ' \
    'never means nothing was hidden; [] means that.',
    'annotation_tags_hidden: annotation sets (tags) the scene\'s SAVED state ' \
    'hides - a callout missing from the image is missing BY DESIGN ' \
    '(per-scene annotation hiding, wr-scene-annotations.rb). null = ' \
    'unreadable, never means nothing was hidden; [] means that.',
    'annotations_hidden: single callouts (kind, tag, text) hidden in the ' \
    'model when this row exported - the same BY DESIGN reading, for items ' \
    'hidden one by one. A 3D-text label also appears in groups_hidden as ' \
    '\'label: ...\'. A callout is absent from the image if it is in ' \
    'annotations_hidden OR its tag is in annotation_tags_hidden. null = not ' \
    'recorded; [] = nothing hidden singly.',
    'two_point_scene: true when the scene\'s SAVED camera is two-point ' \
    'perspective (Camera#is_2d?), false when ordinary/parallel, null when the ' \
    'scene saves no camera or it could not be read. two_point_view_at_export: ' \
    'the viewport\'s projection at the last moment before the file was ' \
    'written (image rows: after the scene switch; render rows: after the ' \
    'settle step). true/false/null as above. scene true + view false means ' \
    'the plate\'s verticals converge and the scene\'s two-point was lost on ' \
    'the way out - the Ruby API cannot set two-point (read-only, ' \
    'api-issue-tracker #88), so this is reported, not repaired. ' \
    'two_point_view_after_write (image rows only): the flag after ' \
    'view.write_image, read on the page the export went back to; a true -> ' \
    'false change across the write points at write_image. true after the ' \
    'write does NOT prove the file is two-point - look at its verticals.',
    'transparent_background true means the batch was asked for alpha ' \
    'backgrounds (plain images: write_image :transparent with sky/ground/fog ' \
    'off; renders: V-Ray\'s own alpha on save). alpha_channel per row is what ' \
    'the PNG on disk actually carries (IHDR colour type 6 = RGBA): true, ' \
    'false, or null if unread. A PROPOSAL PACK WANTS OPAQUE PLATES - flatten ' \
    'any alpha_channel: true file onto white (scripts/wr-flatten-trim.py) ' \
    'before building one. Only what the camera sees through is transparent; ' \
    'modelled room walls stay opaque.',
    "image rows are written at the SketchUp window's aspect (1.31.0): a "     'screen-anchored note (Text with no leader) is placed as a fraction of '     'the frame, so a frame of another shape moves it over other geometry. '     'Leader text, pushpin text, 3D text and dimensions are anchored in the '     'model and do not move. Plates from before 1.31.0 were forced to the '     'V-Ray shape and their screen notes may sit in the wrong place.'
  ].freeze

  # A top-level group/component whose NAME names a booth model. The builders
  # write "MDL 4260 S" (booth-*.rb) or the bare catalogue key (build-booth.rb),
  # and dimension-booth.rb's own fallback instruction is to rename the group
  # to include the model. Name-matching only — this reports what the model
  # SAYS, it never derives what the booth might be.
  def self.booth_name?(nm)
    s = nm.to_s
    return false if s.empty?
    !!(s =~ /\bMDL\b/ || s =~ /\b\d{3,6}\s?[SE]\b/)
  end

  # The string a plate shows for a dimension: the override text verbatim when
  # there is one, the measured value substituted into '<>' when SketchUp is
  # auto-texting. When measured is nil the raw text goes out untouched —
  # placeholder and all — so absence stays visible.
  def self.dim_display(raw, measured)
    r = raw.to_s
    return r.gsub('<>', measured.to_s) if r.include?('<>') && measured
    return measured.to_s if r.strip.empty? && measured
    r
  end

  # Which annotation tags a given exported plate could show, or nil-with-a-
  # note when that cannot be known. hidden: tag names the scene's saved state
  # hides (nil = unreadable); use_hidden: the scene stores tag visibility at
  # all; present: the annotation tags that exist in the model; client_safe:
  # the batch hid every annotation tag for the whole export (D5).
  def self.shown_annot_tags(hidden, use_hidden, present, client_safe)
    if client_safe
      return [[], 'batch ran client-safe: every annotation tag was hidden ' \
                  'in the exported file']
    end
    unless use_hidden
      return [nil, 'unreadable: the scene does not store tag visibility ' \
                   '(use_hidden_layers off) - the model\'s live state governed']
    end
    return [nil, 'unreadable: the scene\'s hidden-tag list could not be read'] if hidden.nil?
    [present - hidden, nil]
  end

  # Which annotation SETS a plate hid by design — the mirror of
  # shown_annot_tags, and the field a downstream reader needs to tell "that
  # callout is missing because the scene hides its set" from "the model is
  # wrong". Same inputs, same honesty rule: nil-with-a-note whenever the
  # answer cannot be known, never a guessed list.
  def self.hidden_annot_tags(hidden, use_hidden, present, client_safe)
    if client_safe
      return [present, 'batch ran client-safe: every annotation tag was ' \
                       'hidden in the exported file']
    end
    unless use_hidden
      return [nil, 'unreadable: the scene does not store tag visibility ' \
                   '(use_hidden_layers off) - the model\'s live state governed']
    end
    return [nil, 'unreadable: the scene\'s hidden-tag list could not be read'] if hidden.nil?
    [present & hidden, nil]
  end

  # Join the planned rows against what the batch actually reported, in export
  # order. A planned row with no result is a LOST row and says so — same
  # doctrine as lost_rows/summary_lines, never a silent omission.
  # plan_rows: [{ :file, :n, :lane, :scene, :shown, :shown_note }]
  # results:   the @results array (:file, :status, :detail, opt :width/:height)
  def self.manifest_rows(plan_rows, results)
    by_file = {}
    results.to_a.each { |r| by_file[r[:file]] ||= r }
    plan_rows.to_a.map do |p|
      r = by_file[p[:file]]
      row = { 'file'        => p[:file].to_s,
              'scene'       => p[:scene].to_s,
              'scene_index' => p[:n],
              'lane'        => p[:lane].to_s,
              'status'      => (r ? r[:status].to_s : 'lost'),
              'detail'      => (r ? r[:detail].to_s :
                                'the batch never reported on this row - a ' \
                                'lost row, not a skip') }
      row['width']  = (r && r[:width])  ? r[:width]  : nil
      row['height'] = (r && r[:height]) ? r[:height] : nil
      row['groups_hidden'] = (r && r[:groups_hidden]) ? r[:groups_hidden] : nil
      # 1.20.0 — the two annotation-hiding records, same doctrine as
      # groups_hidden: null means NOT RECORDED, [] means nothing was hidden.
      row['annotations_hidden'] = (r && r[:annotations_hidden]) ?
                                    r[:annotations_hidden] : nil
      # 1.29.0 — the projection record. null = not recorded / unreadable.
      row['two_point_scene'] = (r && !r[:two_point_scene].nil?) ? r[:two_point_scene] : nil
      row['two_point_view_at_export'] = (r && !r[:two_point_view].nil?) ? r[:two_point_view] : nil
      if r && r.key?(:two_point_after)
        row['two_point_view_after_write'] = r[:two_point_after].nil? ? nil : r[:two_point_after]
      end
      # 1.30.0 — what the PNG on disk carries. null = not read.
      row['alpha_channel'] = (r && !r[:alpha_channel].nil?) ? r[:alpha_channel] : nil
      row['annotation_tags_shown']  = p[:shown]
      row['annotation_tags_hidden'] = p[:hid]
      row['annotation_note'] = p[:shown_note] if p[:shown_note]
      row['annotation_hidden_note'] = p[:hid_note] if p[:hid_note]
      row
    end
  end

  # ----------------------------------------------------------------- state --

  # each_with_index over model.pages and nothing re-sorts it — the number IS
  # the position in the scene tabs, same as every exporter (list-scenes rule).
  def self.gather(model)
    model.pages.to_a.each_with_index.map do |page, i|
      { 'n' => i + 1, 'scene' => page.name.to_s, 'mode' => mode_of(page) }
    end
  end

  # DRAG-TO-REORDER (1.23.0). Benton: "id like to be able to drag and drop
  # scenes to reorder them in the proposal package" — and, asked what should
  # move, chose the REAL SketchUp scenes, not a package-only order.
  #
  # The mechanism is Sketchup::Pages#reorder(page, new_index), SketchUp
  # 2025.0+ (ruby.sketchup.com/Sketchup/Pages.html: "used to reorder an
  # existing Page object inside collection", 0-based, IndexError out of
  # range). It MOVES the page object, so nothing on it is touched: the
  # hidden-walls / hidden-annotations snapshots, camera, and the MODE and EV
  # attributes this tool stores on the page all travel with it. Erase-and-
  # re-add was never an option — it would have destroyed exactly that state.
  #
  # `from` and `to` are 1-based TABLE numbers. The result is re-read from
  # the model, never assumed from the drop: the log reports where the scene
  # actually landed. An older SketchUp without #reorder is refused by name.
  def self.reorder_scene(model, from, to)
    pages = model.pages
    unless pages.respond_to?(:reorder)
      return [false, 'This SketchUp cannot reorder scenes from Ruby — ' \
                     'Pages#reorder needs SketchUp 2025 or newer. Drag the ' \
                     'scene tabs in SketchUp instead.']
    end
    n = pages.count
    return [false, "scene #{from} is gone — hit Rescan"] if from < 1 || from > n
    return [false, "position #{to} is off the end — hit Rescan"] if to < 1 || to > n
    pg   = pages.to_a[from - 1]
    name = pg.name.to_s
    return [true, "\"#{name}\" is already scene #{to} — nothing moved."] if from == to
    model.start_operation('Reorder scene', true)
    begin
      pages.reorder(pg, to - 1)
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      return [false, "reorder failed and was rolled back: #{e.class}: #{e.message}"]
    end
    landed = pages.to_a.index { |p| p == pg }
    landed = landed.nil? ? nil : landed + 1
    if landed == to
      [true, "Moved \"#{name}\" from scene #{from} to scene #{to}. " \
             'Drag it back to reverse it — do not use Ctrl+Z here: scene state ' \
             'is outside SketchUp\'s undo, so Ctrl+Z reaches back to your last ' \
             'apply and unhides its walls/notes in the viewport instead.']
    else
      [false, "Asked to move \"#{name}\" to scene #{to}; the model reports it " \
              "at #{landed.inspect}. Table redrawn from the model."]
    end
  end

  def self.slot_rows(model)
    WR_MaterialsSwap::SLOT_FOR.map do |house, slot|
      src = WR_MaterialsSwap.source(model, slot)
      { 'slot'    => slot,
        'draft'   => src,
        'house'   => house,          # the shop default, so the row can say so
        'missing' => !(model.materials[src] rescue nil),
        'label'   => SLOT_LABEL[slot] || slot,
        'fill'    => WR_MaterialsSwap.fill(model, slot) }
    end
  end

  def self.state(model)
    rows  = gather(model)
    files = plan_names(rows)
    rows.each { |r| r['file'] = files[r['n']].to_s }
    { 'rows'      => rows,
      'slots'     => slot_rows(model),
      # Which way the model is showing RIGHT NOW, so the materials section can
      # offer the same flip the Toggle Draft/Render button does — you set the
      # slots here, you should be able to SEE them here.
      'mode'      => WR_Mode.current(model),
      # UNDO LAST APPLY (1.26.1): what the button would put back, or nil.
      'undo'      => undo_info(model),
      'materials' => (model.materials.map(&:name).sort rescue []) }
  end

  def self.push_state(model, dlg)
    dlg.execute_script("applyState(#{state(model).to_json})")
  rescue StandardError => e
    puts "  could not refresh the window: #{e.class}: #{e.message}"
  end

  # ---- UNDO LAST APPLY (1.26.1) -------------------------------------------
  # Ctrl+Z cannot reverse a scene write (1.25.2), so both scene modules
  # record what their last apply overwrote (WR_SceneWalls.undo_last and
  # its annotations twin) and this window offers to put it back. ONE step:
  # whichever module wrote most recently. The record lives on the module,
  # so it survives closing a popover and closing this window; it does not
  # survive SketchUp closing, and it is refused on another model.
  def self.undo_mod(model)
    [WR_SceneWalls, WR_SceneAnnotations, WR_SceneSun].select do |m|
      m.respond_to?(:undo_summary) && m.undo_summary(model)
    end.max_by { |m| m.last_write[:at] }
  rescue StandardError
    nil
  end

  def self.undo_info(model)
    m = undo_mod(model)
    m ? m.undo_summary(model) : nil
  end

  def self.push_undo(model, dlg)
    dlg.execute_script("setUndo(#{undo_info(model).to_json})")
  rescue StandardError
    nil
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

  # ------------------------------------------- two-point perspective --
  #
  # Benton, 10 Sep 2026: "when we're exporting scenes, it's not saving the
  # two-point perspective. It's only going like the flat perspective."
  #
  # REPORTED (ruby.sketchup.com Sketchup::Camera, read 10 Sep 2026; SketchUp
  # api-issue-tracker #88, still open): two-point perspective is READ-ONLY
  # from Ruby. Camera#is_2d? reports it (with center_2d / scale_2d); there
  # is NO setter. So this file can DETECT a lost two-point and can avoid the
  # calls suspected of flattening it, but it cannot put it back, and no line
  # below claims to.
  #
  # Three things in this file touch the camera. Two assign a Camera OBJECT
  # to the view -- the render lane's settling assignment and finish's
  # restore -- and both are now skipped when the projection they would
  # replace is already two-point (the scene switch brought it back; a
  # Camera object carries no way back in). The third is view.write_image
  # at 1600x900 (the image lane), which this file cannot avoid: it reads
  # the flag after the switch and again after the write, so the manifest
  # says per plate what the viewport was when the file was written.
  #
  # UNVERIFIED in SketchUp which of the three (if any) drops the flag --
  # no ruby.exe, no SketchUp here. scripts/probe-two-point.rb runs the same
  # calls one at a time on a live two-point scene and says which.
  def self.two_point_of(cam)
    return nil if cam.nil? || !cam.respond_to?(:is_2d?)
    cam.is_2d? ? true : false
  rescue Exception
    nil
  end

  # 'two-point' / 'ordinary' / 'unreadable' -- log lines and the manifest.
  def self.two_point_word(v)
    v.nil? ? 'unreadable' : (v ? 'two-point' : 'ordinary')
  end

  # The page's SAVED projection: nil when the page saves no camera.
  def self.page_two_point(page)
    return nil unless page && (page.use_camera? rescue false)
    two_point_of(page.camera)
  rescue Exception
    nil
  end

  # After a scene switch: does the viewport carry the projection the scene
  # saved? Records both readings on the plan row; a LOST two-point is logged
  # by name (the row still exports -- a flat plate the log names beats a
  # missing one nobody explains). Returns the viewport reading.
  def self.two_point_check(model, dlg, page, p, stage)
    p[:two_point_scene] = page_two_point(page)
    v = two_point_of(model.active_view.camera)
    p[:two_point_view] = v
    if p[:two_point_scene] == true && v == false
      log(dlg, "        #{p[:file]}  TWO-POINT PERSPECTIVE LOST #{stage}: " \
               'the scene is saved in two-point perspective but the ' \
               'viewport is in ordinary perspective, so the verticals in ' \
               'this plate will converge. Ruby cannot re-enter two-point ' \
               '(no API setter) - see scripts/probe-two-point.rb', 'bad')
    elsif p[:two_point_scene] == true
      log(dlg, "        #{p[:file]}  two-point perspective held #{stage}", 'dim')
    end
    v
  rescue Exception => e
    log(dlg, "        #{p[:file]}  could not read the projection " \
             "(#{e.class}: #{e.message})", 'bad')
    nil
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

    # SIZE GATE (1.9.4; ORDER FIXED 1.9.6). A render batch that could not read
    # V-Ray's own output size is refused here, before a single file is
    # written, rather than silently falling back to this tool's Width field --
    # which is exactly how a 1600x900 setting became a 1200x900 delivery.
    #
    # render_size_gate READS the size before it JUDGES it. This read used to
    # live 168 lines below, past this gate's own return, which made the
    # refusal unconditional and permanent (D9). out_w/out_h carry down to
    # @cfg; do not move the read back down.
    sz, why = render_size_gate(cfg['width'],
                               live.any? { |r| r['mode'] == 'render' })
    out_w, out_h = sz
    if why
      UI.messagebox(why)
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
    # THE DIMENSION-TAGS ROW DOES NOT BLOCK THIS EXPORT (1.30.1). Benton,
    # 10 Sep 2026: "ignore the dimensions flags off for preflight." Since
    # 1.20.0 each scene carries whatever its own ANNOTATIONS picker left
    # showing and Per scene is the default, so a visible WR-Dims tag at
    # export time is the normal, intended state - a modal on every press
    # for it contradicts the tool's own default. The row still exists in
    # the Pre-render checklist window and in wr-pack-export.rb, where a
    # dimension left on before a V-Ray render is worth a look; here it is
    # one dim line in the log, and the run does not stop.
    dims_row = failing.find { |r| r['id'] == 'dims' }
    failing  = failing.reject { |r| r['id'] == 'dims' }
    if dims_row
      log(dlg, "preflight: dimension tags visible (#{dims_row['detail']}) - "                'not blocking: each scene shows what its ANNOTATIONS picker '                'left on (Per scene), or nothing at all (Client-safe)', 'dim')
    end
    unless failing.empty?
      # Each row's label is the thing that MUST be true ("Floor off drafting
      # white") and its detail is why it is not - so "label: detail" read as
      # "Dimension tags off: Visible: WR-Dims", a contradiction on screen.
      # Say which is which.
      lines = failing.map { |r| "  - #{r['label']} - FAILED: #{r['detail']}" }.join("\n")
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
    # THE MANIFEST covers every LIVE row — including ones the collision policy
    # skipped, whose files are already on disk from an earlier batch and whose
    # scene mapping downstream still needs. finish writes it and clears this.
    @manifest_plan = live.map do |r|
      { :page => pages[r['n'] - 1], :n => r['n'], :lane => r['mode'],
        :file => files[r['n']] }
    end

    # Settings that should survive a restart — per machine, not per model
    # (a folder path is machine-specific). Quotes are stripped above; the
    # wr-folder storage rules apply.
    begin
      Sketchup.write_default(PREF, 'width', cfg['width'].to_s.delete('"'))
      Sketchup.write_default(PREF, 'over',  cfg['over'].to_s.delete('"'))
      Sketchup.write_default(PREF, 'shade', cfg['shade'] ? 'Yes' : 'No')
      Sketchup.write_default(PREF, 'annot', cfg['annot'].to_s == 'client' ? 'client' : 'draft')
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
    # PER SCENE IS THE DEFAULT (1.25.1). Benton exported the PeoplesSpace
    # Revision pack with this on Client-safe -- the old default, written
    # through to the registry by every export -- and got InteriorDims,
    # FrontDims, RampDimensions and OutletInfo with no dimensions and no
    # text. Client-safe is the deliberate strip-everything pass and has to
    # be chosen; anything else, including a missing value, is Per scene.
    client_safe = cfg['annot'].to_s == 'client'
    if client_safe
      # Named at the top of the log, before any image is written: the pack
      # that went out stripped had four scene names saying what they held.
      suspect = (image_rows + render_rows).map { |p| p[:page].name.to_s }
                                          .select { |nm| nm =~ /dim|note|text|label|info|callout/i }
      unless suspect.empty?
        log(dlg, "CLIENT-SAFE will strip every dimension and note from #{suspect.size} " \
                 "scene(s) whose names say they carry them: #{suspect.join(', ')}. " \
                 'If that is wrong, cancel and set ANNOTATION to Per scene.', 'bad')
      end
    end

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
    @annot_saved_entities = nil
    @client_safe   = client_safe
    # TRANSPARENT BACKGROUND (1.30.0). Per run, default OFF, deliberately
    # NOT written to the prefs: an opaque/transparent state that silently
    # carried over from last week is exactly how a client pack would end up
    # with alpha plates (CLAUDE.md: never drop a transparent PNG into the
    # pack). The manifest and every row detail say which way it went.
    @transparent   = (cfg['transp'] == true)
    @mode_note     = nil
    @quality_problems = []
    @srgb_problems = []
    @vray_saved    = nil
    @quality_note  = nil
    @ev_used       = {}
    # THE OUTPUT SIZE COMES FROM THE MODEL, NOT FROM THIS TOOL (1.9.4).
    #
    # Benton had the V-Ray Asset Editor set to 1600x900, 16:9. The package
    # exported 1200x900 at 4:3, because 1.9.3 derived both lanes from its own
    # Width field and wrote its answer into /SettingsOutput. That is backwards:
    # the render settings are HIS, the package's job is to use them and say
    # what it used.
    #
    # So the V-Ray scene is read first and both lanes are cut to what it says.
    # The Width field survives only as the fallback for an image-only batch on
    # a machine with no V-Ray at all, and when it is used the log says so by
    # name. A render batch that cannot read a size does not guess -- see
    # require_render_size!.
    # ...and out_w/out_h were read by render_size_gate at the SIZE GATE above,
    # BEFORE the gate judged them (D9). @size_source is already set.
    @cfg = { 'dir' => dir, 'width' => out_w.to_s, 'height' => out_h.to_s,
             'annot' => (client_safe ? 'client' : 'draft'),
             # OVERRIDES ARE OPT-IN AND NEVER DEFAULT (1.9.4). Absent or empty
             # means: touch nothing, render at the operator's own settings.
             'overrides' => (cfg['overrides'] || {}) }
    @saved_mode  = WR_Mode.current(model)
    @mode_now    = @saved_mode
    @prev_page   = model.pages.selected_page
    @prev_cam    = (model.active_view.camera.clone rescue nil)
    @prev_2d     = two_point_of(model.active_view.camera)

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
    # THE SHAPE OF THE PLAIN IMAGES, BY NAME (1.31.0). Read the window here
    # so the log says what the plates will be BEFORE the first one lands,
    # and how far from the V-Ray size they are.
    begin
      vw = model.active_view.vpwidth.to_i
      vh = model.active_view.vpheight.to_i
      @viewport = [vw, vh]
      if vw > 0 && vh > 0 && image_rows.any?
        ih = (out_w.to_i * vh / vw.to_f).round
        puts "  plain images: #{out_w}x#{ih} - the window's shape "              "(#{vw}x#{vh}), so screen notes land where they were placed"
        if (ih - out_h.to_i).abs > 2
          log(dlg, "plain images will be #{out_w}x#{ih} (the SketchUp window "                    "is #{vw}x#{vh}); V-Ray renders stay #{out_w}x#{out_h}. "                    "Written at the window's shape so screen-anchored notes "                    'land where you placed them. For image and render plates '                    'of ONE shape, make the window '                    "#{out_w}:#{out_h} first (undock trays / resize) and run again.", 'bad')
        end
        # THE WINDOW IS AN INPUT NOW, SO A CHANGED WINDOW IS SAID OUT LOUD
        # (1.31.1). Same scene, same model, different window shape =>
        # screen notes sit differently against the geometry. The last
        # run's manifest in this folder carries the window it used; if
        # this one differs, every earlier plate in the folder with a
        # no-leader note disagrees with the ones about to be written.
        prev = prior_viewport(dir)
        if prev && (prev[0] != vw || prev[1] != vh)
          log(dlg, "WINDOW CHANGED: this folder's earlier plates were written "                    "from a #{prev[0]}x#{prev[1]} window; this run is #{vw}x#{vh}. "                    'Screen notes (no leader) will sit differently from those '                    'plates - re-export the whole folder from one window shape '                    'before nudging any note to fit.', 'bad')
        end
        if (ih - out_h.to_i).abs <= 2
          log(dlg, "plain images: #{out_w}x#{ih}, the window's shape - same as "                    'the V-Ray size', 'dim')
        end
      end
    rescue Exception
      @viewport = nil
    end
    if @transparent
      puts '  background: TRANSPARENT (alpha) - not for a proposal pack ' \
           'without flattening first'
      log(dlg, 'BACKGROUND: TRANSPARENT (alpha channel) on every file this ' \
               'run writes. A proposal pack wants opaque plates - flatten ' \
               'onto white (scripts/wr-flatten-trim.py) before building one.', 'bad')
    end
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
    when :vray_setup then unit_vray_audit(model, dlg)
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
    counts = mat[:applied] || mat[:reverted] || {}
    counts.each { |slot, n| log(dlg, "  #{slot}: #{n} surface(s)", 'dim') }
    # A SWEEP THAT MOVED NOTHING MUST SAY WHY (1.19.12). Before this, an empty
    # counts hash printed no lines at all, so a batch mode step that swapped
    # nothing looked exactly like one that worked. WR_MaterialsSwap owns the
    # slot table, so it owns the explanation too.
    if counts.empty?
      log(dlg, '  nothing on a matching material was found:', 'bad')
      WR_MaterialsSwap.diagnose(model).each { |l| log(dlg, l, 'bad') }
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
    # CAPTURE BEFORE MUTATE (D10, 1.9.6). @annot_saved used to be assigned
    # AFTER the hide loop and nil'd by the rescue, so a raise partway through
    # left N tags already hidden in Benton's model with NO RECORD of what they
    # were -- annot_pop's `return if @annot_saved.nil?` no-opped, finish's
    # `if @annot_saved` no-opped, and the tags stayed off through the save and
    # into the next session. A leaked mutation, which this file's own header
    # calls the worst failure it can have.
    #
    # Now the hash is published to @annot_saved BEFORE the first flip and
    # filled IN PLACE, one tag at a time, each entry written before that tag
    # is touched. Whatever was hidden is always recorded, so annot_pop can put
    # it back on every exit path including a partial failure.
    saved = {}
    @annot_saved = saved
    # ...and the SAME discipline, published just as early, for the single
    # callouts the tag pass cannot reach. See THE UNTAGGED HOLE below.
    ents = {}
    @annot_saved_entities = ents
    missing = []
    family = annot_tags(model)
    family.each do |n|
      l = model.layers[n]
      if l.nil?
        missing << n
        next
      end
      saved[n] = l.visible?   # recorded first...
      l.visible = false       # ...then flipped
    end
    shown = saved.select { |_n, v| v }.keys
    log(dlg, "CLIENT-SAFE: hid #{saved.size} annotation tag(s) for #{file}" +
             (shown.empty? ? ' (none were showing)' : " - #{shown.join(', ')} " \
              'were visible and would have gone out on a client image'), 'dim')
    log(dlg, "        not in this model: #{missing.join(', ')}", 'dim') unless missing.empty?

    # THE UNTAGGED HOLE, CLOSED (1.20.0). Until now this method hid TAGS and
    # nothing else, and the probe of 9 Sep 2026 settled why that was not
    # enough: `tag.untagged_can_hide` FAILED -- SketchUp will not hide the
    # Untagged tag at all. Hand-placed text lands on Untagged, so a note
    # Benton typed into the model went out on a CLIENT-FACING image while
    # this log said "CLIENT-SAFE: hid 5 annotation tag(s)" and the manifest
    # said annotations_hidden_in_images: true. Silently wrong, in front of a
    # customer, which is the worst failure this file can have.
    #
    # So every loose callout -- a Text, a dimension or a `label:` 3D group on
    # any tag OUTSIDE the family -- is hidden per ENTITY as well, through the
    # same flag wr-scene-annotations.rb uses. Family tags are skipped: they
    # are already off above, and flipping their members individually would
    # only make more to put back.
    #
    # CAPTURE BEFORE MUTATE, one entity at a time, exactly as the tags are:
    # `ents` is published to @annot_saved_entities before the first flip and
    # filled in place, each entry written before that entity is touched. So a
    # raise partway through still leaves annot_pop able to put back every
    # entity it actually moved.
    #
    # NOTHING HERE IS EVER SAVED INTO A SCENE. These are live model flags;
    # only page.update writes them into a page, and this file never calls it.
    # The scenes' own saved annotation state is untouched by a client-safe run.
    loose = loose_annotations(model, family)
    if loose.nil?
      log(dlg, '        the loose-callout walk could not be read, so text on ' \
               'Untagged may still be in this image - check it before sending.', 'bad')
    else
      was_showing = 0
      loose.each do |e|
        ents[e.entityID] = [e, ((e.hidden? rescue false) ? true : false)]  # recorded first...
        was_showing += 1 unless ents[e.entityID][1]
        e.hidden = true                                                   # ...then flipped
      end
      if loose.empty?
        log(dlg, '        no loose callouts outside the sets - nothing on ' \
                 'Untagged to hide.', 'dim')
      else
        log(dlg, "        hid #{loose.size} loose callout(s) not on any " \
                 "annotation set (#{was_showing} were visible and would have " \
                 'gone out on a client image) - SketchUp cannot hide the ' \
                 'Untagged tag, so these go one by one. Scope: model space ' \
                 "and #{WR_SceneAnnotations::DEPTH} container(s) deep; a " \
                 'callout buried deeper than that is only reached by putting ' \
                 'it on an annotation set.', 'dim')
      end
    end
  rescue StandardError => e
    # TELL THE TRUTH ABOUT WHICH WAY IT FAILED. The old message said only
    # 'annotation may be visible in this image' -- the opposite of the actual
    # damage, which was tags left hidden in the MODEL. Both halves are real
    # and both are now stated: the tags already hidden ARE recorded and WILL
    # be restored by finish, and the ones never reached are still showing, so
    # the image may carry construction annotation after all.
    done = (@annot_saved || {}).size
    ents_done = (@annot_saved_entities || {}).size
    left = (annot_tags(model).size rescue ANNOT_TAGS.size) - done
    log(dlg, "CLIENT-SAFE FAILED PARTWAY for #{file}: #{e.class}: #{e.message}", 'bad')
    log(dlg, "        #{done} tag(s) and #{ents_done} loose callout(s) were " \
             'hidden and ARE recorded - finish will put them back. ' \
             "#{left} tag(s) were not reached and are still visible, so " \
             'construction annotation may be in this image. Check the image ' \
             'before sending, and check the tags in the model after the batch.', 'bad')
  end

  # Every loose callout in the model -- a Text, a dimension or a `label:` 3D
  # group whose tag is NOT in the annotation family, so the tag pass above
  # cannot reach it. One walk, no mutation. nil (never []) when the walk
  # itself fails, because "unreadable" and "there were none" are different
  # answers and the caller says which one it got.
  def self.loose_annotations(model, family)
    fam = Array(family)
    out = []
    WR_SceneAnnotations.each_annotation(model.entities) do |e, _kind|
      out << e unless fam.include?(WR_SceneAnnotations.tag_of(e))
    end
    out
  rescue StandardError
    nil
  end

  # WHATEVER WAS HIDDEN GOES BACK, on every exit path. Both halves are
  # restored, and each entry in its own rescue, so one locked tag or one
  # erased entity cannot strand the rest of the model hidden -- the failure
  # this method exists to prevent.
  def self.annot_pop(model, dlg)
    return if @annot_saved.nil? && @annot_saved_entities.nil?
    failed = []
    (@annot_saved || {}).each do |n, vis|
      begin
        l = model.layers[n]
        l.visible = vis if l
      rescue StandardError => e
        failed << "tag #{n} (#{e.class})"
      end
    end
    (@annot_saved_entities || {}).each do |id, pair|
      begin
        e   = pair[0]
        was = pair[1]
        next unless e && (e.valid? rescue false)
        e.hidden = was
      rescue StandardError => ex
        failed << "callout #{id} (#{ex.class})"
      end
    end
    unless failed.empty?
      log(dlg, 'these could NOT be put back and are still hidden in the ' \
               "model: #{failed.join(', ')}", 'bad')
    end
    @annot_saved = nil
    @annot_saved_entities = nil
  rescue StandardError => e
    log(dlg, "annotation state could not be put back: #{e.class}: #{e.message}", 'bad')
  end

  # THE IMAGE LANE UNDOES THE ENTITY HIDES AND MUST BE MADE TO REDO THEM.
  # Selecting a page re-applies that scene's saved per-entity hidden state --
  # that is the whole mechanism wr-scene-annotations.rb rides on -- so
  # export_pages' own `pages.selected_page =` puts every callout annot_push
  # just hid straight back, between the push and write_image. Exactly the
  # 1.9.12 tag defect and the 1.19.3 shading defect, one property over. So
  # this rides the same after_switch hook they do. Idempotent by design: it
  # re-asserts the flag from the record and touches nothing the record does
  # not name.
  def self.annot_reapply(model, dlg, page)
    return if @annot_saved_entities.nil? || @annot_saved_entities.empty?
    n = 0
    @annot_saved_entities.each_value do |pair|
      e = pair[0]
      next unless e && (e.valid? rescue false)
      next if (e.hidden? rescue true)
      e.hidden = true
      n += 1
    end
    # Tags too: export_pages re-hides the ones in cfg['hide_tags'], which is
    # the same family list, so they are covered there. Only the count is
    # logged here, and only when the switch actually undid something.
    log(dlg, "        re-hid #{n} loose callout(s) after the scene switch " \
             "(#{(page.name rescue '?')})", 'dim') if n > 0
  rescue StandardError => e
    log(dlg, 'loose callouts could NOT be re-hidden after the scene switch: ' \
             "#{e.class}: #{e.message} - text on Untagged may be in this " \
             'image. Check it before sending.', 'bad')
  end

  # AUDIT THE V-RAY SETTINGS. DO NOT OVERWRITE THEM. (1.9.4)
  #
  # This method used to be called unit_vray_setup and it wrote eight quality
  # parameters plus the output size into Benton's V-Ray scene on every batch.
  # That was wrong on principle, not just in its values. He had the Asset
  # Editor set to 1600x900 / 16:9 / Medium / Progressive / Denoiser off, and
  # the package silently rendered 1200x900 at 4:3 with a denoiser and a
  # sampler floor of its own invention. The renders that came out were not
  # the renders he configured, and nothing in the log said so.
  #
  # The rule now: THE RENDER SETTINGS BELONG TO THE OPERATOR. This reads them,
  # writes every one of them into the run log so a row is auditable after the
  # fact, and changes nothing unless an override was explicitly asked for.
  #
  # It is the same ethos as the rest of this repo -- never invent a number --
  # applied to the one place that was still inventing them.
  AUDIT = [
    ['/SettingsOutput',        :img_width],
    ['/SettingsOutput',        :img_height],
    ['/SettingsOutput',        :show_safe_frames],
    ['/SettingsImageSampler',  :type],
    ['/SettingsImageSampler',  :progressive_threshold],
    ['/SettingsImageSampler',  :progressive_maxSubdivs],
    ['/SettingsImageSampler',  :progressive_maxTime],
    ['/SettingsImageSampler',  :min_shade_rate],
    ['/SettingsOptions',       :progressive_noise_limit],
    ['/RenderChannelDenoiser', :enabled],
    ['/RenderChannelDenoiser', :mode],
    ['/SettingsRTEngine',      :noise_threshold],
    ['/SettingsRTEngine',      :max_sample_level],
    ['/CameraPhysical',        :f_number],
    ['/CameraPhysical',        :ISO],
    ['/CameraPhysical',        :shutter_speed],
    ['/SettingsGI',            :on],
    ['/SunLight',              :enabled]
  ].freeze

  def self.unit_vray_audit(model, dlg)
    ctx   = vray_context
    scene = vray_scene(ctx)
    if scene.nil?
      @quality_note = 'NOT READ - no V-Ray scene'
      log(dlg, 'V-RAY SETTINGS: no V-Ray scene to read. The render rows will '                'use whatever the Asset Editor is set to - which is the '                'intended behaviour, but it could not be logged.', 'bad')
      return
    end

    read = read_params(scene, AUDIT)
    pairs = AUDIT.map { |pl, k| ["#{pl}[#{k}]", read[[pl, k]]] }
    @quality_note = pairs.map { |k, v| "#{k}=#{v.inspect}" }.join(', ')

    # EVERY VALUE USED, IN THE LOG. Not a summary -- the actual numbers, so a
    # render that looks wrong can be traced to the settings that made it
    # without anyone having to reopen the Asset Editor and remember.
    log(dlg, "V-RAY SETTINGS READ FROM THE MODEL - these are HONOURED, not "              "changed. Output size comes from #{@size_source}.", 'dim')
    pairs.each_slice(3) do |row|
      log(dlg, '        ' + row.map { |k, v| "#{k}=#{v.inspect}" }.join('  '), 'dim')
    end

    iso_read = read[['/CameraPhysical', :ISO]]
    ev = ev_of_camera(read[['/CameraPhysical', :f_number]],
                      read[['/CameraPhysical', :shutter_speed]], iso_read)
    log(dlg, format('        the camera as configured is EV %.2f%s (f/%s @ 1/%s @ ISO %s%s)',
                    ev || 0.0, ev.nil? ? ' (could not be derived)' : '',
                    read[['/CameraPhysical', :f_number]].inspect,
                    read[['/CameraPhysical', :shutter_speed]].inspect,
                    iso_read.inspect,
                    iso_read.is_a?(Numeric) && iso_read > 0.0 ? ', ISO counted' : ' -- ISO unreadable, EV assumes 100'),
        iso_read.is_a?(Numeric) && (iso_read - 100.0).abs > 0.5 ? 'bad' : 'dim')
    if iso_read.is_a?(Numeric) && (iso_read - 100.0).abs > 0.5
      log(dlg, format('        ISO %s is NOT the factory 100: wr-drop-lights.rb stamps 3200 ' \
                      '(five stops). Its rig is calibrated for that; the sun and any ' \
                      'other light are ~%.0fx hot unless retuned. If ISO was put back ' \
                      'to 100 by hand, the rig renders ~5 stops DARK instead.',
                      iso_read.inspect, iso_read / 100.0), 'bad')
    end

    # OVERRIDES: opt-in, never default, and announced loudly when they are on.
    ov = overrides_triples
    if ov.empty?
      log(dlg, 'no overrides are configured - nothing was written to V-Ray', 'dim')
      @vray_saved = nil
      @quality_problems = []
      return
    end
    log(dlg, "OVERRIDES ARE ON. #{ov.length} V-Ray parameter(s) will be "              'CHANGED for this batch and restored afterwards:', 'bad')
    ov.each { |pl, k, v| log(dlg, "        #{pl}[#{k}] -> #{v.inspect}", 'bad') }
    @vray_saved = read_params(scene, ov.map { |pl, k, _v| [pl, k] })
    applied, problems = write_params(scene, ov)
    applied.each { |k, v| log(dlg, "        #{k} now reads #{v.inspect}", 'dim') }
    problems.each { |m| log(dlg, "OVERRIDE: #{m}", 'bad') }
    @quality_problems = problems
  rescue Exception => e
    @quality_note = "raised #{e.class}"
    log(dlg, "V-RAY SETTINGS: audit raised #{e.class}: #{e.message} - the " \
             'render rows still run on the settings the operator configured, ' \
             'but this batch could not log what they were', 'bad')
  end

  # The override table, built from cfg['overrides'] -- EMPTY unless a caller
  # deliberately supplied one. Keys are 'plugin|key' strings so an override
  # set can be written down in a config without any Ruby.
  def self.overrides_triples
    raw = (@cfg && @cfg['overrides']) || {}
    return [] if raw.nil? || raw.empty?
    raw.map do |k, v|
      pl, key = k.to_s.split('|', 2)
      next nil if pl.nil? || key.nil?
      [pl, key.to_sym, v]
    end.compact
  rescue StandardError
    []
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

  # RE-APPLIED AFTER EVERY SCENE SWITCH, NOT JUST PUSHED ONCE (1.19.3).
  #
  # unit_shade_push runs once, before the first image row. But every plate
  # proposal-scenes.rb makes stores its own rendering options and shadow info
  # (use_rendering_options / use_shadow_info both true -- SketchUp's default
  # for a hand-made scene too), and selecting such a page puts ITS shadows,
  # ambient occlusion, ground and horizon straight back over the contract --
  # the mechanism that put the light tags back in 1.9.12, one property over.
  # So the plain image went out with the scene's shadows while the log said
  # "shadows off". export_pages now calls this between each `selected_page =`
  # and write_image (cfg['after_switch']); it re-forces the contract and logs
  # what the row will ACTUALLY be written with.
  #
  # WR_Shading.apply, not push: apply only writes and reads back. push would
  # snapshot the already-contracted state, and pop would then "restore" the
  # contract instead of the model. @shade_saved is untouched here, so
  # unit_shade_pop still puts back exactly what was there before the batch.
  def self.shade_reapply(model, dlg, page)
    return unless @shade_saved
    stuck = WR_Shading.apply(model, @shade_saved[:dark])
    onoff = lambda { |v| v == true ? 'on' : (v == false ? 'off' : v.inspect) }
    sh = (model.shadow_info['DisplayShadows'] rescue :unreadable)
    ao = (model.rendering_options['AmbientOcclusion'] rescue :unreadable)
    name = (page.name rescue '?')
    log(dlg, "shading re-applied after switching to #{name}: " \
             "shadows #{onoff.call(sh)}, AO #{onoff.call(ao)}",
        stuck.empty? ? 'dim' : 'bad')
    stuck.each { |s| log(dlg, "  would not take: #{s}", 'bad') }
  rescue StandardError => e
    log(dlg, "shading re-apply failed after switching to #{(page.name rescue '?')}: " \
             "#{e.class}: #{e.message} -- this row exports as the scene sits", 'bad')
  end

  # The export_pages config for one image row. A method of its own so the
  # harness can prove the hook is WIRED, not only that export_pages honours
  # one. shade_reapply is a no-op when SHADING is unticked (@shade_saved nil).
  def self.image_cfg(hide, dlg, p = nil)
    { 'dir' => @cfg['dir'], 'width' => @cfg['width'],
      # PLAIN IMAGES ARE WRITTEN AT THE VIEWPORT'S OWN SHAPE (1.31.0).
      # Benton, 10 Sep 2026: "I know the text I had typed fit in the
      # drawing, but when it got exported, it was not in the same place."
      # A screen-anchored note (Sketchup::Text with no leader) is placed as
      # a fraction of the frame, not at a model point; write a frame of a
      # different shape and the note lands over different geometry. From
      # 1.9.3 (D4) to 1.30.1 this lane forced the V-Ray size (1600x900)
      # whatever the window was, so every screen note in every plain
      # plate moved. No height here => export-scenes.rb derives it from
      # view.vpwidth/vpheight ('viewport' in the detail). The V-Ray lane
      # keeps the Asset Editor size: V-Ray does not draw screen text at
      # all, so nothing moves there. The two lanes now differ in shape
      # unless the window is made to match - start_run says so by name.
      'height' => nil,
      # 'Transparent' makes export_pages pass :transparent => true to
      # write_image and switch DrawGround / DrawHorizon / DisplayFog off
      # after each scene switch, restoring them in its ensure (export-
      # scenes.rb, unchanged here). The REPORTED contract (ruby.sketchup.com
      # View#write_image): 'transparent' Boolean, default false, SketchUp 8+.
      # Nothing in the docs says what the sky and ground do under it, which
      # is why export_pages turns them off itself.
      'bg' => (@transparent ? 'Transparent' : 'Opaque'), 'over' => 'Yes',
      'hide_tags' => hide,
      # BOTH re-asserts ride this hook, because the page switch undoes both:
      # the shading contract (1.19.3) and, since 1.20.0, the client-safe
      # per-entity hides annot_push made (annot_reapply). The two-point
      # reading rides it too (1.29.0): this is the last moment before
      # write_image, so it is the projection the file is written from.
      'after_switch' => lambda { |m, pg|
        shade_reapply(m, dlg, pg)
        annot_reapply(m, dlg, pg)
        two_point_check(m, dlg, pg, p, 'after the scene switch') if p
      } }
  end

  def self.unit_image(model, dlg, p)
    plan = [{ :page => p[:page], :n => p[:n], :base => p[:base] }]
    # D4 (1.9.3) passed an EXPLICIT height so an image row and a render row
    # came out the same shape. WITHDRAWN in 1.31.0: that moved every
    # screen-anchored note (see image_cfg). The height is the window's now.
    # HIDE THESE AFTER EVERY PAGE SWITCH, NOT BEFORE THE EXPORT.
    #
    # The image lane runs in DRAFT mode, whose policy hides WR_Mode::LIGHT_TAGS
    # -- and that was not enough. wr-drop-lights.rb stamps "WR Lights" VISIBLE
    # into every saved scene on purpose (a light tag hidden during a V-Ray pass
    # renders silently unlit), and activating a page re-applies its saved tag
    # visibility, so the fixtures came back between the mode switch and
    # write_image and went out in the plain image. Observed in
    # ProposalFiles/test/Scene 1.png, 31 Aug 2026.
    #
    # annot_push below has the same exposure for the same reason, so the
    # client-safe tags ride along here too. It stays as well: it is what logs
    # WHICH annotation tags were showing, and it covers the render lane, which
    # does not go through export_pages at all.
    hide = WR_Mode::LIGHT_TAGS.dup
    # The LIVE family (1.20.0): a set Benton made this afternoon is hidden by
    # tonight's client-safe run. annot_tags rescues to the frozen five.
    hide.concat(annot_tags(model)) if @client_safe
    # ...and the shading contract rides the same hook (after_switch), for the
    # same reason: the scene puts its own shadow info back on selection.
    cfg  = image_cfg(hide, dlg, p)
    # RECORD WHAT IS HIDDEN ON THIS SCENE BEFORE EXPORTING IT. Selecting the
    # page applies its saved per-entity hidden state — the per-scene wall
    # hiding (wr-scene-walls.rb, verified live 31 Aug 2026) — and
    # export_pages selects the same page again, so this early switch changes
    # nothing about the pixels. Transitions are off for the whole batch
    # (start_run), so it is instant.
    begin
      model.pages.selected_page = p[:page] if p[:page]
      p[:groups_hidden] = collect_hidden_groups(model)
      p[:annotations_hidden] = collect_hidden_annotations(model)
    rescue StandardError
      p[:groups_hidden] = nil
      p[:annotations_hidden] = nil
    end
    begin
      annot_push(model, dlg, p[:file])
      present = hide.select { |n| model.layers[n] }
      log(dlg, "re-hiding after the scene switch: #{present.join(', ')}", 'dim') unless present.empty?
      x = WR_ExportScenes.export_pages(model, plan, cfg)
    ensure
      annot_pop(model, dlg)
    end
    # THE VIEWPORT AFTER THE WRITE. write_image at a size that is not the
    # viewport's (1600x900 here, D4) is the one camera-touching call this
    # lane cannot avoid. If the flag went from two-point to ordinary across
    # the write, the write did it. If it stayed two-point the file is
    # PROBABLY two-point -- probably: an offscreen re-derivation that puts
    # the camera back afterwards would leave the flag alone, and only the
    # file's own verticals settle that (probe-two-point.rb writes two).
    # export_pages has already re-selected the operator's previous page, so
    # this is not the exported scene's viewport any more -- it is the flag
    # of the page it went back to. Read it as "what write_image left
    # behind", nothing stronger.
    p[:two_point_after] = two_point_of(model.active_view.camera)
    if p[:two_point_view] == true && p[:two_point_after] == false
      log(dlg, "        #{p[:file]}  the viewport read ordinary perspective " \
               'after write_image, having read two-point before it - ' \
               'open this file and check whether its verticals converge', 'bad')
    end
    if x[:written] > 0
      alpha = png_alpha(p[:path])
      det = "image, #{x[:width]}x#{x[:height]} (height #{x[:height_source]})"
      det += alpha_note(alpha)
      @results << { :file => p[:file], :lane => 'image', :status => 'ok',
                    # :width/:height feed manifest.json — the size the export
                    # ACTUALLY used, not the size that was asked for.
                    :groups_hidden => p[:groups_hidden],
                    :annotations_hidden => p[:annotations_hidden],
                    :two_point_scene => p[:two_point_scene],
                    :two_point_view  => p[:two_point_view],
                    :two_point_after => p[:two_point_after],
                    :alpha_channel => alpha,
                    :width => x[:width].to_i, :height => x[:height].to_i,
                    :detail => det }
      log(dlg, "ok      #{p[:file]}  (#{det})", alpha_mismatch?(alpha) ? 'bad' : 'ok')
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

  # WHAT IS ACTUALLY ON DISK (1.30.0). A transparent request is only worth
  # anything if the PNG carries an alpha channel, and the two lanes reach
  # that through two different APIs (write_image :transparent; V-Ray's own
  # alpha on save_vfb_image), neither verified live for this option. So the
  # file's IHDR is read back: colour type 6 = RGBA, 2 = RGB (wr-png-srgb.rb
  # already parses it). true / false / nil (unreadable). A requested
  # transparency that came back RGB, or an unrequested alpha, is logged as
  # 'bad' and named in the row detail — never quietly 'ok'.
  def self.png_alpha(path)
    return nil unless path && File.exist?(path)
    head = File.binread(path, 33)
    return nil unless head && head.bytesize >= 33 && head[0, 8].bytes == [137, 80, 78, 71, 13, 10, 26, 10]
    ct = head[25].ord
    return true  if ct == 6 || ct == 4
    return false if ct == 2 || ct == 0 || ct == 3
    nil
  rescue Exception
    nil
  end

  def self.alpha_mismatch?(alpha)
    !alpha.nil? && (alpha != (@transparent ? true : false))
  end

  def self.alpha_note(alpha)
    want = @transparent ? 'transparent' : 'opaque'
    got  = alpha.nil? ? 'alpha channel unreadable' :
           (alpha ? 'alpha channel: YES' : 'alpha channel: no')
    if alpha_mismatch?(alpha)
      ", #{want} background was asked for but the file on disk is " \
        "#{alpha ? 'RGBA - it HAS alpha' : 'RGB - NO alpha'}"
    elsif @transparent
      ", transparent background (#{got})"
    else
      ''
    end
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
    # Same per-scene hidden record the image lane keeps — read here, right
    # after the scene switch applied its saved hidden state, so the manifest
    # says which walls this render is missing BY DESIGN.
    p[:groups_hidden] = collect_hidden_groups(model)
    p[:annotations_hidden] = collect_hidden_annotations(model)
    two_point_check(model, dlg, p[:page], p, 'after the scene switch')
    page_cam = (p[:page].camera rescue nil)
    if page_cam && p[:two_point_scene] == true && p[:two_point_view] == true
      # A TWO-POINT SCENE THAT THE SWITCH HONOURED IS LEFT ALONE (1.29.0).
      # The assignment below hands the view a Camera OBJECT, and Ruby has
      # no way to mark one two-point -- so if this assignment flattens the
      # projection (unverified; probe-two-point.rb step 3), the scene switch
      # was the only thing that could have set it and re-assigning would
      # throw it away. Transitions are off for the batch, so the switch has
      # already landed; the settle check below still judges eye/target/up.
      log(dlg, "        #{p[:file]}  two-point scene: keeping the camera the " \
               'scene switch set (a Camera object cannot be marked two-point)', 'dim')
    elsif page_cam
      begin
        model.active_view.camera = page_cam
      rescue Exception => e
        log(dlg, "        #{p[:file]}  could not set the camera " \
                 "directly (#{e.class}: #{e.message}) — relying on the " \
                 'scene switch', 'bad')
      end
      # The assignment happened: read the projection again so the manifest
      # carries what V-Ray will actually see, and name a loss it caused.
      two_point_check(model, dlg, p[:page], p, 'after the direct camera assignment')
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
    # EXPOSURE IS THE OPERATOR'S BY DEFAULT (1.9.4).
    #
    # 1.9.3 wrote /CameraPhysical on EVERY render row -- EV 9 for interiors,
    # EV 12 for room views -- because this rig needed two exposures and no
    # single value served both. That worked, and it was the wrong fix: it
    # hid a broken light rig behind a silent camera override, so the pictures
    # were right for a reason nobody could see in the model.
    #
    # The look-development matrix (scripts/lookdev-matrix.rb) found what was
    # actually wrong: the "WR Lights" TAG WAS HIDDEN, so not one of the eight
    # rectangle lights reached any render, and every frame was lit by the
    # V-Ray sun and sky alone. With the tag shown and the booth fixture raised,
    # a SINGLE exposure serves both an interior and a room view -- measured
    # 30 Aug 2026 across a five-step EV ladder on both cameras.
    #
    # So the default is now: write nothing, render at the camera the operator
    # configured, and LOG the EV that camera implies. A per-row EV is still
    # available, but only when the page carries an explicit stored value AND
    # the batch was started with exposure overrides enabled -- and when it
    # fires it is announced, never quiet.
    ev_landed = nil
    if exposure_override?
      ev = ev_of(p[:page])
      log(dlg, "        #{p[:file]}  EXPOSURE OVERRIDE IS ON - this row will "                "be rendered at EV #{format('%.2f', ev)}, not at the camera "                'as configured', 'bad')
      ev_landed = apply_exposure(ctx, dlg, ev, p[:file])
    end
    if ev_landed.nil?
      cam_ev = camera_ev(ctx)
      ev_landed = cam_ev
      log(dlg, format('        %s  EV %s, read from the camera as configured '                       '(nothing was written to /CameraPhysical)', p[:file],
                      cam_ev.nil? ? 'UNREADABLE' : format('%.2f', cam_ev)), 'dim')
    end
    @ev_used[p[:file]] = ev_landed

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

  # Is a per-row exposure override switched on for this batch? Opt-in, and
  # absent means NO -- the whole point of 1.9.4.
  def self.exposure_override?
    ov = (@cfg && @cfg['overrides']) || {}
    !!(ov['exposure'] || ov['ev'])
  rescue StandardError
    false
  end

  # The EV the camera is ALREADY set to, for the log. Read-only: this is what
  # the row will actually be exposed at when nothing overrides it.
  def self.camera_ev(ctx)
    scene = vray_scene(ctx)
    return nil if scene.nil?
    pl = (scene['/CameraPhysical'] rescue nil)
    return nil if pl.nil?
    ev_of_camera((pl[:f_number] rescue nil), (pl[:shutter_speed] rescue nil),
                 (pl[:ISO] rescue nil))
  rescue Exception
    nil
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
                          applied['/CameraPhysical[shutter_speed]'],
                          applied['/CameraPhysical[ISO]'])
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
  # THE DARK RENDERS. MEASURED 1 Sep 2026, and this is the whole of it.
  #
  # Benton: "The images don't look the same if you manually do it compared to
  # when you press the export package ... it's making them usually much
  # darker." Measured on his own pair, same model, same scene, same camera
  # (EV 14.229 in both -- so exposure is NOT the difference):
  #
  #     Scene 4 render.png (batch)   mean luminance 0.159, MAX 0.682
  #     the same frame by hand       mean luminance ~0.35+, max 1.000
  #
  # A render that never reaches white is the tell. Apply an sRGB transfer
  # curve to the batch file and it lands on 0.397 -- the hand render. The
  # saved file is the LINEAR buffer: what the VFB shows under "Raw".
  #
  # save_vfb_image saves the buffer without baking the VFB's colour
  # corrections unless it is asked to. The option has been documented in this
  # repo since the 28 Aug render-lane audit (F4) -- ":apply_color_corrections
  # -- Bake the VFB corrections to the output file" -- and was never adopted,
  # because at the time nobody had a measurement showing it mattered. Now
  # there is one.
  #
  # :apply_color_corrections IS NOT IN THE SAVE, AND THE 1 SEP "IT CHANGED
  # NOTHING" MEASUREMENT WAS NEVER A TEST OF IT (1.33.1). That day SAVE_OPTS
  # was passed as a positional Hash, which raised (1.31.3), and the retry
  # file came from the braceless fallback WITHOUT the option - so "byte-
  # different, luminance identical" measured render noise, not the option.
  # 1.31.3 fixed the arity and the option reached V-Ray for the first time.
  # OBSERVED 10 Sep 2026 (Benton's VFB-vs-file screenshot, and the file
  # itself): `2_Scene 4 render.png` came out RGB, sRGB-stamped, mean
  # luminance 0.671 against 0.34 for the Rev2 renders and the ~0.35-0.40
  # of a hand save. That is a display-corrected file encoded AGAIN by
  # srgb_bake: the option DOES bake the VFB's Display Correction layer,
  # and the pipeline below is calibrated (1 Sep, measured) for the LINEAR
  # buffer plus exactly one sRGB encode. Two roads to a correct file:
  #   (a) linear save + srgb_bake         - measured to land on the hand
  #                                         save; carries no VFB layers
  #                                         beyond the display transform;
  #   (b) :apply_color_corrections, no bake - V-Ray's own "as if you used
  #                                         the save button", carries every
  #                                         layer; NOT measured here.
  # (a) is what ships, because it is the one with a number behind it. (b)
  # is the road to take the day Benton dials a curve or LUT into the VFB,
  # and it needs one measured comparison first, not a comment.
  #
  # The two options that stay: :skip_alpha kills the .Alpha.png sidecar,
  # :no_alpha gives an opaque PNG (dropped for a transparent run, 1.30.0).
  SAVE_OPTS = { :skip_alpha => true, :no_alpha => true }.freeze

  # THE DARK-FILE FIX. Runs on every render-lane file the moment it lands on
  # disk: decode, sRGB-encode every colour byte, declare the colour space,
  # verify, replace (the whole contract lives in wr-png-srgb.rb — temp file,
  # pixel-perfect re-decode check, original never corrupted). Returns the
  # string to append to the row's detail; a failure is logged loudly, named
  # in the summary via @srgb_problems, and flagged in the detail itself so a
  # dark file can never be shipped quietly as 'ok'.
  #
  # If a future V-Ray build starts saving display-corrected pixels itself,
  # this would double-brighten — which is why the before/after means are in
  # the log and the detail on every row: a 'before' that already reads ~0.35+
  # on a normally-lit frame is the audit trail that says so. wr-png-srgb.rb
  # also refuses any file that already DECLARES a colour space.
  def self.srgb_bake(dlg, p)
    r = begin
      WR_PNGSRGB.encode_file(p[:path], "#{p[:path]}.srgb-tmp")
    rescue Exception => e
      { :ok => false, :why => "WR_PNGSRGB raised #{e.class}: #{e.message}" }
    end
    if r[:ok]
      # A LINEAR buffer of a normally lit frame reads ~0.15-0.20 before the
      # encode; a file that ALREADY carries the display transform reads
      # ~0.35+ and comes out ~0.6+ after - the 10 Sep 2026 double-bake
      # (mean 0.671). Heuristic, log-only: a genuinely bright linear frame
      # can trip it, so it names the suspicion and does not undo anything.
      if r[:before] * 1.0 > 0.45
        log(dlg, "        #{p[:file]}  pre-encode mean #{format('%.3f', r[:before] * 1.0)} " \
                 'already looks display-corrected - if V-Ray saved this file ' \
                 'with its corrections baked, the sRGB encode has now DOUBLED ' \
                 'them and the file will read washed out. Compare it to the ' \
                 'VFB before sending.', 'bad')
      end
      format(', sRGB-encoded (mean %.3f -> %.3f, max %.3f -> %.3f)',
             r[:before] * 1.0, r[:after] * 1.0,
             r[:max_before] * 1.0, r[:max_after] * 1.0)
    else
      (@srgb_problems ||= []) << "#{p[:file]}: #{r[:why]}"
      log(dlg, "        #{p[:file]}  *** sRGB ENCODE FAILED - the file on " \
               'disk is the LINEAR buffer and will read DARK in every ' \
               "viewer. Do not send it to a client. (#{r[:why]})", 'bad')
      ', *** LINEAR/DARK - sRGB encode failed, NOT CLIENT-READY (see log)'
    end
  end

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
    # TRANSPARENT RENDERS (1.30.0): drop :no_alpha rather than set it false.
    # OBSERVED (F4, 28 Aug 2026): with NO options save_vfb_image wrote a
    # transparent RGBA plus a .Alpha.png sidecar; :skip_alpha keeps killing
    # the sidecar and :no_alpha => true is what makes the file opaque.
    # Omitting the key is the observed path to alpha; passing false to it
    # is not something this repo has seen accepted. wr-png-srgb.rb's bake
    # handles RGBA (colour type 6, alpha bytes untouched). Whether V-Ray's
    # alpha is 0 where only the environment shows depends on the
    # environment's own alpha setting in the Asset Editor - not touched
    # here, so the on-disk check after the save is the only proof.
    save_opts = @transparent ? SAVE_OPTS.reject { |k, _| k == :no_alpha } : SAVE_OPTS
    # KEYWORDS, NOT A HASH (1.31.3). OBSERVED in the field, 10 Sep 2026:
    # `save_vfb_image(path, hash)` raises ArgumentError "wrong number of
    # arguments (given 2, expected 1)" - the frame was rendered, the save
    # failed, 0 exported. The documented signature (VRayRenderer.html:
    # "save_vfb_image(path, options)" with an Options: list) is Ruby-3
    # keywords, and Ruby 3 does not turn a positional Hash into keywords.
    # The braceless form the 30 Aug live check used (`:skip_alpha => true,
    # ...`) IS keywords, which is why it worked; the SAVE_OPTS constant
    # (1 Sep) never did - it raised here and the braceless fallback below
    # carried every render since, logging a false ":apply_color_corrections
    # was REJECTED". 1.30.0 turned the fallback into a Hash too, and the
    # last working call went with it. `**` sends keywords either way.
    begin
      ok = @rend.save_vfb_image(p[:path], **save_opts)
    rescue Exception => e
      # An option key this build rejects raises. Losing the whole batch
      # over one would be worse than a plain save, so retry with the two
      # options the 30 Aug live check accepted, SAY SO by name, and go on.
      # (Until 1.33.1 this branch blamed :apply_color_corrections; the real
      # raiser was the Hash arity, 1.31.3.)
      begin
        fallback = { :skip_alpha => true }
        fallback[:no_alpha] = true unless @transparent
        ok = @rend.save_vfb_image(p[:path], **fallback)
        @colour_baked = false
        log(dlg, "        #{p[:file]}  save_vfb_image rejected the save options " \
                 "(#{e.class}: #{e.message}) - saved with " \
                 "#{fallback.keys.join(', ')} instead; the sRGB encode below " \
                 'still runs.', 'bad')
      rescue Exception => e2
        @results << { :file => p[:file], :lane => 'render', :status => 'failed',
                      :detail => "save_vfb_image raised #{e2.class}: #{e2.message}" }
        log(dlg, "FAILED  #{p[:file]}  (save_vfb_image raised #{e2.class}: #{e2.message})", 'bad')
        return
      end
    end
    if ok == false
      @results << { :file => p[:file], :lane => 'render', :status => 'failed',
                    :detail => 'save_vfb_image returned false -- the frame was ' \
                               'NOT written' }
      log(dlg, "FAILED  #{p[:file]}  (save_vfb_image returned false)", 'bad')
      return
    end
    if File.exist?(p[:path])
      # THE DARK-FILE FIX runs the moment the file exists, before the row is
      # reported: save_vfb_image writes the LINEAR buffer (measured 1 Sep
      # 2026 — see THE DARK RENDERS above), so every render-lane file gets
      # the sRGB transfer curve baked in and the colour space declared. Its
      # note (success means, or a loud NOT-CLIENT-READY flag) is part of the
      # row's detail so the manifest and the summary carry it too.
      enc_note = srgb_bake(dlg, p)
      # The size and EV that were ACTUALLY used, and where the size came
      # from. 1.9.3 hard-coded ", denoiser on" here because it had just
      # switched the denoiser on itself; now that the denoiser is the
      # operator's setting, claiming anything about it would be a guess.
      evv = @ev_used[p[:file]]
      det = format('V-Ray %sx%s (size from %s), EV %s',
                   @cfg['width'], @cfg['height'], @size_source,
                   evv.nil? ? 'unreadable' : format('%.2f', evv.to_f))
      det += enc_note
      side = sidecars(p)
      det += format(', plus %d render-element sidecar(s): %s',
                    side.size, side.join(', ')) unless side.empty?
      alpha = png_alpha(p[:path])
      det += alpha_note(alpha)
      @results << { :file => p[:file], :lane => 'render', :status => 'ok',
                    # The size written into /SettingsOutput and read back by
                    # the size gate — det already names where it came from.
                    :groups_hidden => p[:groups_hidden],
                    :annotations_hidden => p[:annotations_hidden],
                    :two_point_scene => p[:two_point_scene],
                    :two_point_view  => p[:two_point_view],
                    :alpha_channel => alpha,
                    :width => @cfg['width'].to_i, :height => @cfg['height'].to_i,
                    :detail => det }
      log(dlg, "ok      #{p[:file]}  (#{det})", alpha_mismatch?(alpha) ? 'bad' : 'ok')
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

  # ------------------------------------------- manifest collectors/writer --
  #
  # The IMPURE half of the manifest section above: these read the SketchUp
  # API and can only be proven live. Every read is rescued to a null-with-a-
  # note, never to a substitute value.

  # A dimension attachment as a Point3d. OBSERVED (31 Aug 2026, SketchUp
  # 2026): start/end return [nil, Point3d] for point-attached dims. The shape
  # is still not trusted — anything that is a Point3d or answers .position is
  # accepted, anything else is nil and the row says 'unreadable' by name.
  # Also observed: Dimension#text returns the RENDERED string ("4'"), not a
  # '<>' placeholder, so `text` is directly usable and dim_display's '<>'
  # branch is a guard for overrides that embed it, not the common case. And
  # format_length can differ from the drawn text by a leading '~ ' on
  # non-exact lengths — `measured` on a diagonal read "~ 7' 2 9/16\"" while
  # the dim itself drew "7' 2 9/16\"".
  def self.dim_anchor(v)
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

  # Straight-line distance between a linear dimension's two anchors, in
  # inches (SketchUp's internal unit), or nil when either anchor is
  # unreadable.
  def self.dim_span(d)
    a = dim_anchor(d.start)
    b = dim_anchor(d.end)
    return nil unless a && b
    a.distance(b).to_f
  rescue StandardError
    nil
  end

  def self.ent_tag(e)
    e.layer ? e.layer.name.to_s : nil
  rescue StandardError
    nil
  end

  # Every dimension and text callout in MODEL SPACE (model.entities top
  # level — where auto-dimension.rb, dimension-booth.rb, dimension-selection.rb
  # and build-room.rb's notes all draw). Deliberately NOT a deep walk:
  # annotations nested inside groups are not where the house tools put them,
  # and the manifest says exactly what it covered via `annotation_scope`.
  def self.collect_annotations(model)
    out = []
    model.entities.each do |e|
      case e
      when Sketchup::DimensionLinear
        raw  = (e.text.to_s rescue '')
        span = dim_span(e)
        meas = span ? (Sketchup.format_length(span).to_s rescue nil) : nil
        row  = { 'kind' => 'linear_dimension', 'tag' => ent_tag(e),
                 'text' => raw }
        if meas
          row['measured']    = meas
          row['measured_in'] = (span * 1000).round / 1000.0
          row['display']     = dim_display(raw, meas)
        else
          row['measured']    = nil
          row['measured_in'] = nil
          row['display']     = raw
          row['note'] = 'anchor points unreadable - no measured value; the ' \
                        'rendered string must be read off the image'
        end
        out << row
      when Sketchup::DimensionRadial
        out << { 'kind' => 'radial_dimension', 'tag' => ent_tag(e),
                 'text' => (e.text.to_s rescue '') }
      when Sketchup::Text
        out << { 'kind' => 'text', 'tag' => ent_tag(e),
                 'text' => (e.text.to_s rescue '') }
      when Sketchup::Group
        # A 3D-text label is real geometry in a group named "label: ...", not
        # a Text entity (add_3d_text). The WR tools have written them since
        # 1.19.16 and the manifest could not see one; wr-scene-annotations.rb
        # hides them per scene, so the manifest has to be able to name them.
        nm = (e.name.to_s rescue '')
        if nm =~ WR_SceneAnnotations::LABEL_RE
          out << { 'kind' => '3d_text', 'tag' => ent_tag(e),
                   'text' => nm.sub(WR_SceneAnnotations::LABEL_RE, '') }
        end
      end
    end
    out
  rescue StandardError => e
    [{ 'kind' => 'error', 'tag' => nil, 'text' => nil,
       'note' => "annotation walk failed: #{e.class}: #{e.message} - the " \
                 'callouts must be read off the images for this batch' }]
  end

  # Group paths hidden in the model RIGHT NOW — the per-scene wall-hiding
  # record (wr-scene-walls.rb). Called after a row's scene is selected,
  # because selecting a scene applies its saved per-entity hidden state
  # (verified live 31 Aug 2026, SketchUp 2026) and the pixels honour exactly
  # that state. A hidden group's children are not walked — they vanish with
  # it, and listing every wall band of a hidden wall would bury the signal.
  # Component instances too, not just groups (code review, 1.12.4):
  # wr-scene-walls' selection buttons hide whatever is selected, and a booth
  # part placed as add_instance is a ComponentInstance — grepping only
  # groups made the manifest write [] for a scene that deliberately hid one,
  # which the field notes define as "nothing was hidden". An instance
  # descends through its definition's entities, so a hidden group nested
  # inside a component is seen as well.
  def self.hidden_group_walk(ents, path, depth)
    out = []
    ents.each do |g|
      is_grp = g.is_a?(Sketchup::Group)
      is_ci  = g.is_a?(Sketchup::ComponentInstance)
      next unless is_grp || is_ci
      nm = (g.name.to_s rescue '')
      nm = (g.definition.name.to_s rescue '') if nm.empty? && is_ci
      label = nm.empty? ? '(unnamed group)' : nm
      if (g.hidden? rescue false)
        out << (path + [label]).join(' / ')
      elsif depth < 3
        kids = begin
          is_grp ? g.entities : g.definition.entities
        rescue StandardError
          nil
        end
        out.concat(hidden_group_walk(kids, path + [label], depth + 1)) if kids
      end
    end
    out
  end

  def self.collect_hidden_groups(model)
    hidden_group_walk(model.entities, [], 0)
  rescue StandardError
    nil
  end

  # Single callouts hidden in the model RIGHT NOW — the per-scene ANNOTATION
  # record (wr-scene-annotations.rb), the twin of collect_hidden_groups and
  # read at the same moment, right after the row's scene was selected and
  # applied its saved state. Tag-hidden sets are NOT in here: they are
  # reported as annotation_tags_hidden, from the page's own hidden-tag list.
  # nil (never []) when the walk fails, because a reader must not mistake
  # "unreadable" for "nothing was hidden".
  def self.collect_hidden_annotations(model)
    out = []
    WR_SceneAnnotations.each_annotation(model.entities) do |e, kind|
      next unless (e.hidden? rescue false)
      out << { 'kind' => (kind == '3d' ? '3d_text' : kind),
               'tag'  => WR_SceneAnnotations.tag_of(e),
               'text' => WR_SceneAnnotations.text_of(e, kind) }
    end
    out
  rescue StandardError
    nil
  end

  # Tag names a scene's saved state HIDES, or nil when that cannot be read.
  # Sketchup::Page#layers returning the HIDDEN layers is OBSERVED (31 Aug
  # 2026, SketchUp 2026, scripted run): a scene saved with all four annot
  # tags hidden listed all four; one saved with two hidden listed those two,
  # and the manifest's shown-lists matched the exported pixels both ways.
  def self.page_hidden_tags(page)
    return nil unless page && page.respond_to?(:layers)
    page.layers.map { |l| l.name.to_s }
  rescue StandardError
    nil
  end

  # Names of top-level groups/components that name a booth model — what the
  # model SAYS it contains, for the product-identity line downstream.
  def self.booth_groups(model)
    model.entities.to_a
         .select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
         .map    { |e| (e.name.to_s rescue '') }
         .select { |n| booth_name?(n) }
  rescue StandardError
    []
  end

  # Write manifest.json beside the images. Called from finish on EVERY exit —
  # done, cancelled and failed alike — because partial results are real files
  # and the manifest must say which rows they are. A manifest failure is
  # named loudly but never blocks finish: the images are already on disk and
  # the model restore matters more.
  def self.write_manifest(model, dlg)
    plan = @manifest_plan
    return if plan.nil? || plan.empty?
    dir = @cfg && @cfg['dir'].to_s
    return if dir.nil? || dir.empty?
    # The LIVE family, so a set Benton made is reported as one (1.20.0).
    present = annot_tags(model).select { |n| (model.layers[n] rescue nil) }
    rows = plan.map do |p|
      page  = p[:page]
      scene = begin
        page ? page.name.to_s : ''
      rescue StandardError
        ''
      end
      use_h = begin
        page && page.use_hidden_layers?
      rescue StandardError
        nil
      end
      hid_tags    = page_hidden_tags(page)
      shown, note = shown_annot_tags(hid_tags, use_h, present, @client_safe)
      hid, hnote  = hidden_annot_tags(hid_tags, use_h, present, @client_safe)
      { :file => p[:file], :n => p[:n], :lane => p[:lane], :scene => scene,
        :shown => shown, :shown_note => note,
        :hid => hid, :hid_note => hnote }
    end
    annots = collect_annotations(model)
    data = { 'format'      => MANIFEST_FORMAT,
             'tool'        => 'proposal-package',
             'generated'   => Time.now.strftime('%Y-%m-%d %H:%M'),
             'model'       => model.title.to_s,
             'model_path'  => model.path.to_s,
             'booth_groups' => booth_groups(model),
             'width'       => @cfg['width'].to_i,
             'height'      => @cfg['height'].to_i,
             'size_source' => @size_source.to_s,
             # 1.31.0: width/height above are the V-RAY size. Image rows
             # carry their own width/height, written at the window's shape.
             'image_shape' => 'viewport - plain images are written at the SketchUp '                               "window's aspect so screen-anchored notes stay put; "                               "see each image row's width/height",
             'viewport'    => @viewport,
             'annotations_hidden_in_images' => (@client_safe ? true : false),
             'transparent_background' => (@transparent ? true : false),
             'annotation_scope' => 'model-space top level (model.entities) - ' \
                                   'where the WR dimension tools draw',
             'field_notes' => MANIFEST_NOTES,
             'images'      => manifest_rows(rows, @results || []),
             'annotations' => annots }
    File.open(File.join(dir, 'manifest.json'), 'w') do |f|
      f.write(JSON.pretty_generate(data))
    end
    puts "  manifest.json written - #{data['images'].size} image row(s), " \
         "#{annots.size} annotation(s)"
    log(dlg, "manifest.json written - #{data['images'].size} image row(s), " \
             "#{annots.size} annotation(s)", 'dim')
  rescue StandardError => e
    puts "  *** manifest.json NOT written: #{e.class}: #{e.message}"
    log(dlg, "MANIFEST NOT WRITTEN: #{e.class}: #{e.message} - the images " \
             'are unaffected; callouts must be read off the renders for ' \
             'this batch', 'bad')
  end

  # -------------------------------------------------------------- finish --

  # THE single exit. Runs on completion, on cancel and on any raise — restores
  # mode, scene and camera, and fails LOUDLY with a recovery instruction if
  # the restore itself fails. A leaked mutation is the worst failure this
  # tool can have, so nothing here is allowed to fail quietly.
  def self.finish(model, dlg, why)
    # RE-ENTRANCY GUARD (D13, 1.9.6). finish had none. When the bare
    # UI.messagebox below raised, the exception escaped into step_body's
    # rescue, which called finish AGAIN -- the mode restore ran twice and
    # @running was left latched. The box is now wrapped, and this guard means
    # nothing structural can do it either: a second entry is a no-op that says
    # so, and the first entry always reaches its own end.
    entered = false
    if @finishing
      puts "  (finish re-entered while already finishing - ignored: #{why})"
      return
    end
    @finishing = true
    entered    = true
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
    if @annot_saved || @annot_saved_entities
      begin
        annot_pop(model, dlg)
      rescue Exception => e
        restore_errs << "annotation restore: #{e.class}: #{e.message}"
      ensure
        @annot_saved = nil
        @annot_saved_entities = nil
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
      # THE OPERATOR'S TWO-POINT VIEW IS NOT FLATTENED BY ITS OWN RESTORE
      # (1.29.0). @prev_cam is a Camera OBJECT and Ruby cannot mark one
      # two-point, so if the view was two-point before the run and the
      # scene restore above already brought two-point back, assigning the
      # clone can only keep it or lose it -- never improve it. Left alone
      # in that case. (In two-point mode SketchUp drops the mode the moment
      # the view orbits, so a two-point view is the scene's own camera or a
      # pan/zoom of it; the page restore is the closer restore anyway.)
      # Otherwise the clone goes back as before, and if THAT loses a
      # two-point the operator had, it is said in the console and the log:
      # the fix is one click, Camera > Two-Point Perspective, and nothing
      # in this file can make it for him.
      if @prev_cam
        if @prev_2d == true && two_point_of(model.active_view.camera) == true
          puts '  view restore: the scene restore brought back two-point ' \
               'perspective; leaving it rather than re-assigning the camera'
        else
          model.active_view.camera = @prev_cam
          if @prev_2d == true && two_point_of(model.active_view.camera) == false
            msg = 'your view was in two-point perspective before the run ' \
                  'and the camera restore could not bring it back (no API ' \
                  'for it): Camera > Two-Point Perspective, or click the ' \
                  'scene tab'
            puts "  view restore: #{msg}"
            log(dlg, "RESTORE NOTE: #{msg}", 'bad')
          end
        end
      end
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
      # GUARDED (D13, 1.9.6). F10 named UI.messagebox as the residual raiser
      # inside finish and the CLOSING box was wrapped in 1.9.2 -- but this
      # one, the box that runs only when something has ALREADY gone wrong,
      # was left bare. Under a caller whose UI.messagebox raises (the bridge
      # muzzles modals; observed once) it threw out of finish into
      # step_body's rescue, which calls finish a SECOND time: the mode
      # restore ran twice and @running never came down.
      begin
      UI.messagebox("*** COULD NOT RESTORE THE MODEL'S ORIGINAL STATE ***\n\n" +
                    restore_errs.join("\n") +
                    "\n\nThe model is likely in #{@mode_now.to_s.upcase} mode " \
                    "(it started in #{@saved_mode.to_s.upcase}).\n" \
                    "Press 'Toggle Draft / Render mode' to put it back — WR_Mode " \
                    'stores the true state in the model, so the toggle reads it ' \
                    'even after a crash.')
      rescue Exception => e
        puts "  (the restore-failure box could not be shown: #{e.class}: " \
             "#{e.message} - the restore errors above are the whole of it)"
      end
    end

    # THE MANIFEST, after every restore and before the summary: the model is
    # back in its resting state, @results is complete, and a cancelled batch
    # still gets a manifest naming its partial files. Internally rescued —
    # a manifest failure is loud but never costs the restore or the summary.
    write_manifest(model, dlg)

    lines = summary_lines(why, restore_errs)
    puts ''
    lines.each { |l| puts l }
    puts ''
    restore_errs.each { |s| log(dlg, "RESTORE FAILED: #{s}", 'bad') }
    # D11 -- THE WHOLE SUMMARY REACHES THE WINDOW, not just lines.first. The
    # '*** N PLANNED ROW(S) PRODUCED NO RESULT AT ALL' block was written,
    # printed to the console and put in the messagebox, and was the one thing
    # the run window never showed.
    lines.each do |l|
      bad = !restore_errs.empty? || l.include?('***') || l.include?('FAILED')
      log(dlg, l.to_s, bad ? 'bad' : 'dim')
    end
    (@unmapped || []).each { |s| log(dlg, "unmapped  #{s}", 'bad') }

    # D11 -- the closing verdict counts lost rows too, so the window can no
    # longer say 'Done. Model restored.' on a short delivery.
    lost  = lost_rows(@plan_files, @results.map { |r| r[:file] })
    fails = @results.count { |r| r[:status] == 'failed' } + lost.size
    msg = if why == 'cancelled'
            'Cancelled — model restored. Partial results are real files.'
          elsif fails > 0
            "Done — #{fails} failure(s) named in the log" +
              (lost.empty? ? '' : ", #{lost.size} of them LOST ROW(S) that " \
                                  'produced no file at all') +
              '. Nothing silent. The pack is INCOMPLETE.'
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
    # D11 -- the plan is consumed above (headline, verdict and reconciliation
    # all read it) and must not survive into another call, or a later finish
    # would reconcile this batch's plan against that batch's results.
    @plan_files = nil
    # Same rule for the manifest plan: consumed by write_manifest above and
    # never allowed to leak into a later batch's finish.
    @manifest_plan = nil
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
  ensure
    @finishing = false if entered   # never clear the flag of an outer call
  end

  def self.summary_lines(why, restore_errs)
    ok    = @results.count { |r| r[:status] == 'ok' }
    skip  = @results.count { |r| %w[skipped cancelled].include?(r[:status]) }
    # D11 -- a LOST ROW IS A FAILURE IN THE HEADLINE. It used to be named only
    # at the bottom of the summary while the top line said 0 FAILED.
    missing = lost_rows(@plan_files, @results.map { |r| r[:file] })
    fails   = @results.count { |r| r[:status] == 'failed' } + missing.size
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
    # THE DARK-FILE doctrine: a file that could not be sRGB-encoded is on
    # disk as the linear buffer and reads dark — named here, never quietly
    # shipped inside an 'ok' count.
    (@srgb_problems || []).each do |s|
      lines << "  *** sRGB ENCODE FAILED (file is LINEAR/DARK, not client-ready): #{s}"
    end
    restore_errs.each { |s| lines << "  *** RESTORE FAILED: #{s}" }
    # D8 -- the reconciliation pass 1 did not have. 5 rows were planned, 4
    # files were written, and the summary still said '0 FAILED'. A row that
    # produced no result at all now shows up HERE, by name.
    unless missing.empty?
      lines << "  *** #{missing.size} PLANNED ROW(S) PRODUCED NO RESULT AT " \
               "ALL - this is a lost row, not a skip (counted in FAILED above):"
      missing.each { |f| lines << "        #{f}" }
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

  # F5, CLOSED AT LAST (D12, 1.9.6). The four dialog callbacks that MUTATE the
  # model -- mark, bulk, setfill, activate -- had no @running check on the
  # Ruby side. Two of them (the drawMats select and the go-arrow) had none on
  # the JS side either, and the JS `running` flag is set by runStarted(),
  # whose failure is rescued and ignored -- and which HAS been observed to
  # fail, leaving every control in the window live for the whole batch.
  #
  # This stopped being theoretical when VRay::Command.render_production was
  # OBSERVED to pump the Windows message loop (the mechanism behind the D1
  # nested-tick bug). A setfill dispatched mid-render changes the slot fill
  # the model is read from, so finish's WR_MaterialsSwap.to_draft looks for
  # surfaces by a fill name that was not used to paint them, finds none, and
  # leaves every floor face on the RENDER material -- silently, because the
  # :left report only names surfaces found on a configured fill. A model left
  # painted for render on a batch that reported clean.
  #
  # A refusal, never a silent ignore: the console and the run log both say it.
  def self.busy?(dlg, what)
    return false unless @running
    puts "WR_ProposalPackage: '#{what}' ignored - a batch is running."
    log(dlg, "'#{what}' was ignored: a batch is running and the model must " \
             'not change under it. Cancel the batch, or wait for it to ' \
             'finish, then try again.', 'bad')
    true
  end

  # ---- live preview in the pickers (1.24.0) -------------------------------
  #
  # Benton: "When we are clicking the checkboxes ... they don't actually
  # show that they're hidden until we press Apply to the Scene. Once we
  # select a checkbox, go ahead and have it hidden so that we can verify
  # before we press Apply."
  #
  # A preview mutates the model BEFORE the operator has agreed to anything,
  # so the whole design is about putting it back. @preview is the one
  # record of a live preview: which picker, which page, and the BASELINE —
  # snapshotted once when the picker opens, never per click, so toggling a
  # row twenty times cannot drift. Every tick sends the FULL pick set and
  # preview_show sets every unit from picks-or-baseline, so the preview is
  # a pure function of (baseline, picks) and there is nothing to accumulate.
  #
  # Exits, all through preview_end: CANCEL and the popover backdrop
  # (wallsclose / annotsclose), the window's X (set_on_closed), opening
  # another row's picker (preview_begin ends the last one first), and
  # APPLY. Apply is restore-THEN-apply: the real apply computes the saved
  # answer from the clean baseline with its own operation, exactly as it
  # did before this existed, and since every row is sent the result equals
  # what was on screen. The preview never calls page.update — a preview
  # that updates the page has committed.
  #
  # Undo: the first preview op is a normal operation, every later one —
  # including the restore — is TRANSPARENT and merges into it, so a picker
  # session is ONE undo step, a net no-op after CANCEL. Tradeoff, stated: a
  # transparent op merges into whatever the previous step is, so a viewport
  # edit made mid-preview would absorb the next toggle. The alternative —
  # one operation held open across HtmlDialog callbacks — would swallow any
  # viewport edit into the preview and undo it on CANCEL, which is worse.
  # The model IS left modified-flagged by a cancelled preview (any
  # operation does that); only "open, look, cancel" with no tick avoids it,
  # because nothing runs until the first tick.
  def self.preview_mod(kind)
    kind == :walls ? WR_SceneWalls : WR_SceneAnnotations
  end

  def self.preview_begin(model, kind, page)
    preview_end(model)
    @preview = { :kind => kind, :page => page,
                 :base => preview_mod(kind).preview_snapshot, :op => false }
  end

  # One operation, transparent after the first (see above).
  def self.preview_op(model, pv)
    model.start_operation('Preview hidden per scene', true, false, pv[:op])
    begin
      yield
      model.commit_operation
    rescue StandardError
      model.abort_operation
      raise
    end
    pv[:op] = true
  end

  def self.preview_show(model, picks)
    pv = @preview
    return unless pv
    preview_op(model, pv) { preview_mod(pv[:kind]).preview_show(pv[:base], picks) }
    model.active_view.refresh
  end

  # Put the model back and forget the preview. Idempotent: a second call is
  # a no-op, so the X and CANCEL can both fire. If the operator switched
  # scenes mid-preview, the preview's page is selected first — the baseline
  # belongs to THAT scene, and restoring it onto another would leave the
  # other scene looking different from what it saves.
  def self.preview_end(model)
    pv = @preview
    return unless pv
    @preview = nil
    return unless pv[:op]                 # never ticked: nothing was changed
    if pv[:page] && pv[:page].valid? && model.pages.selected_page != pv[:page]
      model.pages.selected_page = pv[:page]
    end
    preview_op(model, pv) { preview_mod(pv[:kind]).preview_restore(pv[:base]) }
    model.active_view.refresh
  rescue StandardError => e
    puts "  preview restore failed: #{e.class}: #{e.message}"
  end

  # Everything the walls popover needs for one scene, in one place, so the
  # three callbacks that have to redraw it (open, and either selection
  # button) cannot send three slightly different shapes. scan() is called
  # once per payload: it rebuilds WR_SceneWalls' @units key index, and both
  # apply and keys_for_selection read that index.
  # Everything the sun popover needs for one scene (1.27.0): the scene's
  # SAVED sun, the sun that was live when the picker opened, and whether
  # the scene saves shadow settings at all.
  def self.sun_payload(model, n, pg)
    off = WR_SceneSun.pages_not_saving(model)
    { 'n' => n.to_i, 'scene' => pg.name.to_s,
      'saved' => WR_SceneSun.sun_json(WR_SceneSun.page_sun(pg)),
      'live'  => WR_SceneSun.sun_json(@sun_live),
      'warn'  => off.include?(pg.name.to_s),
      'off'   => off.size,
      'offset' => WR_SceneSun::DEFAULT_OFFSET, 'elev' => WR_SceneSun::DEFAULT_ELEV }
  end

  def self.walls_payload(model, n, pg)
    st = WR_SceneWalls.scan(model)
    { 'n' => n.to_i, 'scene' => pg.name.to_s,
      'units' => st[:walls].map do |u|
        { 'key' => u[:key], 'room' => u[:room], 'wall' => u[:wall],
          'side' => u[:side].to_s, 'hidden' => u[:hidden] ? true : false,
          'mixed' => u[:mixed] ? true : false }
      end,
      'objects' => st[:objects].map { |u| WR_SceneWalls.object_json(u) },
      'warn' => WR_SceneWalls.pages_not_saving_hidden(model).include?(pg.name.to_s) }
  end

  # The pages an APPLY TO ALL request names, resolved by table index the way
  # every other callback here does it. A scene deleted since the table was
  # drawn is simply absent; none left is a refusal that points at Rescan.
  def self.sweep_pages(model, ns)
    all = model.pages.to_a
    pages = (ns || []).map { |n| all[n.to_i - 1] }.compact
    raise 'none of those scenes exist any more — hit Rescan' if pages.empty?
    pages
  end

  # One log line per scene the sweep wrote, so what was rewritten can be
  # read back afterwards — and a scene that will not re-assert what was
  # written is called out in red by name, not folded into a count.
  def self.log_sweep(dlg, ok, msg, det)
    log(dlg, msg, ok ? 'dim' : 'bad')
    return unless ok && det
    unsaved = det[:unsaved] || []
    (det[:written] || []).each do |nm|
      if unsaved.include?(nm)
        log(dlg, "  written, but \"#{nm}\" does not save hidden state — it will " \
                 'NOT come back on that scene', 'bad')
      else
        log(dlg, "  written: \"#{nm}\"", 'dim')
      end
    end
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

  # ------------------------------------------------------------ singleton --
  #
  # Benton, 10 Sep 2026: "If i re-click the proposal package right now, it
  # opens it again. Sometimes i have multiple copies. Id like for that to
  # just act as a refresh for the one already open instead."
  #
  # WHY there were duplicates — established before choosing a fix. The
  # panel's run(path) is a plain `load`, and re-loading this file REOPENS
  # module WR_ProposalPackage rather than replacing it, so module ivars
  # survive the reload: run() already relies on exactly that for @running
  # (the stale-batch prompt). @dlg survived the same way. The handle was
  # never lost; run() simply never looked at it. So this is the
  # "never checked" fix, and it needs no change in main.rb.

  # Liveness, guarded for exceptions and not just nil: a handle can outlive
  # its window (closed by the operator) and, in principle, a reloaded
  # module could hand back a dead object. HtmlDialog#visible? is the API's
  # own answer and what wr-scene-walls / -annotations already use.
  def self.dialog_alive?(dlg)
    return false unless dlg
    dlg.visible? ? true : false
  rescue Exception
    false
  end

  # The open window, brought forward and refreshed. The refresh IS the
  # Rescan button (1.21.1), clicked from Ruby: the JS sends up the scene
  # names it was showing, so the log says what changed, and the button's
  # own disabled state stands in for the batch guard. A running batch is
  # brought forward and left alone — the model must not be re-read under it.
  def self.refocus_open_dialog
    begin
      @dlg.bring_to_front
    rescue StandardError => e
      puts "  bring_to_front failed: #{e.class}: #{e.message}"
    end
    if @running
      puts 'WR_ProposalPackage: already open and a batch is running — brought ' \
           'forward, NOT refreshed.'
      log(@dlg, 'Tool button pressed again while a batch is running — window ' \
                'brought forward, table left alone.', 'dim')
      return
    end
    puts 'WR_ProposalPackage: already open — refreshed, not reopened.'
    log(@dlg, 'REFRESHED — the tool button was pressed while this window was ' \
              'open. Nothing was reopened: same window, same picks, same log.', 'dim')
    @dlg.execute_script("(function(){ var b = document.getElementById('rescan'); " \
                        'if (b && !b.disabled) b.click(); })()')
  rescue StandardError => e
    puts "  refresh failed: #{e.class}: #{e.message}"
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

    # SINGLETON (1.22.1) — see dialog_alive? above. A live window on THIS
    # model is refreshed, not reopened. A live window on another model
    # cannot be: its callbacks close over the model they were opened on. It
    # is closed here and a clean one opens below — unless a batch is running
    # in it, in which case the stale-batch prompt below owns the decision.
    if dialog_alive?(@dlg)
      if @model.equal?(model)
        refocus_open_dialog
        return
      end
      unless @running
        puts 'WR_ProposalPackage: the open window belongs to another model — ' \
             'closing it and opening a fresh one.'
        begin
          @dlg.close
        rescue StandardError
          nil
        end
      end
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
      Sketchup.read_default(PREF, 'annot', 'draft').to_s
    rescue Exception
      'draft'
    end
    width = '2400' if width.strip.empty?
    over  = 'Ask' unless ['Ask', 'Overwrite', 'Skip existing'].include?(over)
    annot = 'draft' unless %w[client draft].include?(annot)

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
    @dlg   = d   # so a stale-batch reset can reach the last window's log, if any
    @model = model   # the singleton check: this window belongs to THIS model

    d.add_action_callback('mark') do |_c, payload|
      next if busy?(d, 'mark')
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
      next if busy?(d, 'bulk')
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
      next if busy?(d, 'setfill')
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

    d.add_action_callback('setsrc') do |_c, payload|
      next if busy?(d, 'setsrc')
      begin
        data = JSON.parse(payload)
        WR_MaterialsSwap.set_source(model, data['slot'].to_s, data['name'].to_s)
      rescue StandardError => e
        puts "  slot source failed: #{e.class}: #{e.message}"
      end
      push_state(model, d)
    end

    # The same flip as the Toggle Draft/Render panel button, driven from inside
    # this window. NOT a shortcut around WR_Mode: it calls the same to_mode, so
    # the snapshot bookkeeping, the tag policy and the materials sweep are
    # identical whichever surface pressed it. Refused mid-batch — the batch owns
    # the model's mode while it runs.
    d.add_action_callback('togglemode') do |_c, _p|
      next if busy?(d, 'togglemode')
      begin
        cur    = WR_Mode.current(model)
        target = cur == 'render' ? 'draft' : 'render'
        res    = WR_Mode.to_mode(model, target)
        log(d, "MODE -> #{target.upcase}", 'dim')
        mat = res[:materials] || {}
        counts = mat[:applied] || mat[:reverted] || {}
        counts.each { |slot, n| log(d, "  #{slot}: #{n} surface(s)", 'dim') }
        # The button's whole job is showing what moved -- so it has to show
        # what did NOT, and why. See unit_mode above; same rule, same owner.
        if counts.empty?
          log(d, 'nothing on a matching material was found:', 'bad')
          WR_MaterialsSwap.diagnose(model).each { |l| log(d, l, 'bad') }
        end
        # Named here, in the window, at the moment you flip -- the whole point
        # of the button is seeing what did and did not swap.
        (mat[:unmapped] || mat[:left] || []).each { |x| log(d, "unmapped  #{x}", 'bad') }
        (res[:stuck] || []).each { |x| log(d, "stuck  #{x}", 'bad') }
        model.active_view.refresh
      rescue StandardError => e
        log(d, "mode toggle failed: #{e.class}: #{e.message}", 'bad')
        puts "  mode toggle failed: #{e.class}: #{e.message}"
      end
      push_state(model, d)
    end

    # RESCAN (1.21.1). Benton: "a 'refresh' button ... so it loads in newly
    # added scenes". Three error paths in this window had said "hit Rescan"
    # since 1.19 without any such button existing. The rebuild is the same
    # push_state every mark / bulk / fill change already does, and it loses
    # NOTHING the operator set in this window -- checked, not assumed: MODE
    # and EV live on the page (set_mode / set_ev), the slot fills live on the
    # model (WR_MaterialsSwap), and the folder, width, overwrite, shading,
    # annotation selectors, search text, section collapse states and the log
    # are DOM that applyState never touches. The payload is the scene list the
    # window was showing, so the log can say WHAT changed rather than only
    # that a refresh happened. Refused mid-batch like every sibling: the model
    # must not be re-read under a running export.
    d.add_action_callback('rescan') do |_c, payload|
      next if busy?(d, 'rescan')
      begin
        old = (JSON.parse(payload.to_s) rescue [])
        old = [] unless old.is_a?(Array)
        old = old.map(&:to_s)
        now = model.pages.to_a.map { |pg| pg.name.to_s }
        added = now - old
        gone  = old - now
        msg = "RESCAN: #{now.length} scene(s) in the model"
        msg += " -- new: #{added.join(', ')}" unless added.empty?
        msg += " -- no longer in the model: #{gone.join(', ')}" unless gone.empty?
        if added.empty? && gone.empty?
          msg += if now.length == old.length
                   ' -- no change to the scene list'
                 else
                   # Array#- is by name, so a deleted DUPLICATE of a surviving
                   # name shows up only as a count change. Say so.
                   " -- count went from #{old.length} to #{now.length} "                    '(scenes sharing a name)'
                 end
        end
        log(d, msg, 'dim')
        if !added.empty? && !gone.empty?
          log(d, '  a renamed scene reads as one gone and one new; its MODE '                  'is stored on the scene itself and survives the rename.', 'dim')
        end
      rescue StandardError => e
        puts "  rescan failed: #{e.class}: #{e.message}"
      end
      push_state(model, d)
    end

    # One drag = one operation; its reverse is dragging back, NOT Ctrl+Z
    # (see reorder_scene). The table is ALWAYS redrawn
    # from the model afterwards (push_state → gather), so row numbers and the
    # FILE column come from where the scene really is, not from the drop.
    d.add_action_callback('reorder') do |_c, payload|
      next if busy?(d, 'reorder')
      begin
        req = JSON.parse(payload.to_s)
        ok, msg = reorder_scene(model, req['from'].to_i, req['to'].to_i)
        log(d, msg, ok ? 'dim' : 'bad')
      rescue StandardError => e
        log(d, "reorder failed: #{e.class}: #{e.message}", 'bad')
        puts "  reorder failed: #{e.class}: #{e.message}"
      end
      push_state(model, d)
    end

    # UNDO LAST APPLY (1.26.1). A live preview is ended first: its restore
    # would otherwise land on top of what was just put back.
    d.add_action_callback('undolast') do |_c, _p|
      next if busy?(d, 'undolast')
      begin
        preview_end(model)
        m = undo_mod(model)
        if m
          ok, msg = m.undo_last(model)
          log(d, msg, ok ? 'dim' : 'bad')
        else
          log(d, 'Nothing to put back — no apply has been recorded in this SketchUp session.', 'bad')
        end
      rescue StandardError => e
        log(d, "put back failed: #{e.class}: #{e.message}", 'bad')
        puts "  put back failed: #{e.class}: #{e.message}"
      end
      push_undo(model, d)
    end

    d.add_action_callback('activate') do |_c, n|
      next if busy?(d, 'activate')
      begin
        pg = model.pages.to_a[n.to_i - 1]
        model.pages.selected_page = pg if pg
      rescue StandardError => e
        puts "  could not activate scene #{n}: #{e.class}: #{e.message}"
      end
    end

    # ---- SUN column (1.27.0) -------------------------------------------------
    #
    # Benton: "saving the sun from the light from here ... being reset every
    # time we are playing with a scene". The sun HE aims lives in the model's
    # live shadow_info; every scene saves its OWN copy and puts it back when
    # clicked. wr-scene-sun.rb has the whole reading. The live sun is read
    # BEFORE the picker selects the scene, because the select is exactly
    # what overwrites it — that is the value SAVE THE VIEWPORT SUN writes.
    d.add_action_callback('sunopen') do |_c, n|
      next if busy?(d, 'sunopen')
      begin
        pg = model.pages.to_a[n.to_i - 1]
        raise "scene #{n} is gone — hit Rescan" if pg.nil?
        preview_end(model)
        @sun_live = WR_SceneSun.read_sun(model.shadow_info)
        @walls_return ||= model.pages.selected_page
        model.pages.selected_page = pg
        d.execute_script('sunShow(' + sun_payload(model, n, pg).to_json + ')')
      rescue StandardError => e
        d.execute_script('sunFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    # The sun that was in the viewport when the picker opened, into this scene.
    d.add_action_callback('sunsave') do |_c, n|
      next if busy?(d, 'sunsave')
      begin
        pg = model.pages.to_a[n.to_i - 1]
        raise "scene #{n} is gone — hit Rescan" if pg.nil?
        raise 'no viewport sun was read when this opened' if @sun_live.nil?
        ok, msg = WR_SceneSun.apply(model, pg, @sun_live)
        log(d, msg, ok ? 'dim' : 'bad')
        push_undo(model, d)
        d.execute_script('sunDone(' + { 'ok' => ok, 'msg' => msg,
                                        'saved' => WR_SceneSun.sun_json(WR_SceneSun.page_sun(pg)),
                                        'warn' => WR_SceneSun.pages_not_saving(model).include?(pg.name.to_s) }.to_json + ')')
      rescue StandardError => e
        d.execute_script('sunFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    # Light it from here, from this scene's own camera, saved into this scene.
    d.add_action_callback('sunaim') do |_c, payload|
      next if busy?(d, 'sunaim')
      begin
        req = JSON.parse(payload.to_s)
        pg  = model.pages.to_a[req['n'].to_i - 1]
        raise "scene #{req['n']} is gone — hit Rescan" if pg.nil?
        ok, msg = WR_SceneSun.aim(model, pg, req['offset'], req['matchcam'] ? true : false,
                                  req['elev'])
        log(d, msg, ok ? 'dim' : 'bad')
        push_undo(model, d)
        d.execute_script('sunDone(' + { 'ok' => ok, 'msg' => msg,
                                        'saved' => WR_SceneSun.sun_json(WR_SceneSun.page_sun(pg)),
                                        'warn' => WR_SceneSun.pages_not_saving(model).include?(pg.name.to_s) }.to_json + ')')
      rescue StandardError => e
        d.execute_script('sunFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    # This scene's SAVED sun into every scene the table is showing — the
    # walls sweep's shape: sweep_pages, confirm by name, one operation,
    # one log line per scene, UNDO LAST APPLY as the way back.
    d.add_action_callback('sunapplyall') do |_c, payload|
      next if busy?(d, 'sunapplyall')
      begin
        req = JSON.parse(payload.to_s)
        pg  = model.pages.to_a[req['n'].to_i - 1]
        raise "scene #{req['n']} is gone — hit Rescan" if pg.nil?
        sun = WR_SceneSun.page_sun(pg)
        raise "scene \"#{pg.name}\" has no saved sun yet — aim or save one first" if sun.nil?
        pages = sweep_pages(model, req['ns'])
        if WR_SceneSun.confirm_all?(pages, sun)
          ok, msg, det = WR_SceneSun.apply_all(model, sun, pages)
          log_sweep(d, ok, msg, det)
        else
          ok, msg = false, 'Not applied — nothing was changed.'
        end
        push_undo(model, d)
        d.execute_script('sunDone(' + { 'ok' => ok, 'msg' => msg,
                                        'saved' => WR_SceneSun.sun_json(WR_SceneSun.page_sun(pg)),
                                        'warn' => WR_SceneSun.pages_not_saving(model).include?(pg.name.to_s) }.to_json + ')')
      rescue StandardError => e
        d.execute_script('sunFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    d.add_action_callback('sunfix') do |_c, n|
      next if busy?(d, 'sunfix')
      begin
        ok, msg = WR_SceneSun.fix_pages(model)
        log(d, msg, ok ? 'dim' : 'bad')
        pg = model.pages.to_a[n.to_i - 1]
        d.execute_script('sunNote(' + { 'ok' => ok, 'msg' => msg,
                                        'warn' => pg ? WR_SceneSun.pages_not_saving(model).include?(pg.name.to_s) : false,
                                        'off' => WR_SceneSun.pages_not_saving(model).size }.to_json + ')')
      rescue StandardError => e
        d.execute_script('sunFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    d.add_action_callback('sunclose') do |_c, _p|
      @sun_live = nil
      begin
        if @walls_return && @walls_return.valid?
          model.pages.selected_page = @walls_return
        end
      rescue StandardError => e
        puts "  could not restore the scene you were on: #{e.class}: #{e.message}"
      ensure
        @walls_return = nil
      end
    end

    # ---- per-scene wall hiding, in this window ------------------------------
    #
    # A scene's hidden walls can only be read or written while THAT scene is
    # selected — the state lives on the page, and selecting a page is what
    # asserts it. So opening the picker selects the scene, and closing it puts
    # the operator back where they were. Anything else would either read the
    # wrong scene's walls or silently move them off the row they were working
    # on.
    d.add_action_callback('wallsopen') do |_c, n|
      next if busy?(d, 'wallsopen')
      begin
        pg = model.pages.to_a[n.to_i - 1]
        raise "scene #{n} is gone — hit Rescan" if pg.nil?
        preview_end(model)                # another row's preview, if any
        @walls_return ||= model.pages.selected_page
        model.pages.selected_page = pg
        payload = walls_payload(model, n, pg)   # scan() fills @units first
        preview_begin(model, :walls, pg)
        d.execute_script('wallsShow(' + payload.to_json + ')')
      rescue StandardError => e
        d.execute_script('wallsFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    # HIDE / SHOW WHAT IS SELECTED, from this window. THE BUG THIS FIXES
    # (Benton, 10 Sep 2026): he selected the booth in the viewport, pressed
    # USE MY SELECTION in this popover and got "Nothing in your selection
    # matched a named wall" — because the popover shared WR_SceneWalls'
    # inventory, apply, keys_for_selection and reveal but NOT
    # apply_selection, so from the proposal package there was no way to hide
    # anything that was not a named wall. The standalone dialog has had these
    # two buttons all along; this is the same module method, wired through.
    #
    # It writes to the scene IMMEDIATELY rather than waiting for APPLY, which
    # is what the standalone dialog does too — the selection is transient and
    # holding it until Apply would mean holding a reference to something the
    # operator has already clicked away from.
    d.add_action_callback('wallssel') do |_c, payload|
      next if busy?(d, 'wallssel')
      begin
        req  = JSON.parse(payload.to_s)
        pg   = model.pages.to_a[req['n'].to_i - 1]
        raise "scene #{req['n']} is gone — hit Rescan" if pg.nil?
        # HIDE/SHOW SELECTED writes the scene NOW, so the preview must come
        # off first or its ticks would be snapshotted into the page.
        preview_end(model)
        ok, msg = WR_SceneWalls.apply_selection(model, req['hide'] ? true : false)
        # Redraw first, so a row the operator just hid comes back ticked,
        # then put the outcome in the message strip the redraw cleared.
        payload = walls_payload(model, req['n'], pg)
        preview_begin(model, :walls, pg)   # new baseline: the scene changed
        d.execute_script('wallsShow(' + payload.to_json + ')')
        d.execute_script('wallsNote(' + { 'ok' => ok, 'msg' => msg }.to_json + ')')
        log(d, msg, ok ? 'dim' : 'bad')
      rescue StandardError => e
        d.execute_script('wallsFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    # Every tick sends the full pick set; nothing is written to the scene.
    d.add_action_callback('wallspreview') do |_c, payload|
      next if busy?(d, 'wallspreview')
      begin
        req   = JSON.parse(payload.to_s)
        picks = {}
        (req['picks'] || {}).each { |k, v| picks[k] = v ? true : false }
        preview_show(model, picks)
      rescue StandardError => e
        d.execute_script('wallsNote(' + { 'ok' => false,
          'msg' => "preview failed: #{e.class}: #{e.message}" }.to_json + ')')
      end
    end

    d.add_action_callback('wallsapply') do |_c, payload|
      next if busy?(d, 'wallsapply')
      begin
        req   = JSON.parse(payload.to_s)
        picks = {}
        (req['picks'] || {}).each { |k, v| picks[k] = v ? true : false }
        preview_end(model)                # restore-THEN-apply, see preview_*
        ok, msg = WR_SceneWalls.apply(model, picks)
        d.execute_script('wallsDone(' + { 'ok' => ok, 'msg' => msg }.to_json + ')')
        push_undo(model, d)
        log(d, msg, ok ? 'dim' : 'bad')
      rescue StandardError => e
        d.execute_script('wallsFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    # APPLY TO ALL SCENES (1.22.0). Benton: "would like for there to be an
    # 'apply to all scenes' button as well." The same picks into every scene
    # the table is showing, ONE operation (NOT undoable — page.update is
    # outside SketchUp's undo; see WR_SceneWalls.apply_all), confirmed by
    # name first because it replaces the saved answer of scenes the operator
    # is not looking at. The mechanism is the module's
    # apply_all — select each page, write_scene, restore — not a second
    # save path. On "No", nothing is touched and the popover says so.
    d.add_action_callback('wallsapplyall') do |_c, payload|
      next if busy?(d, 'wallsapplyall')
      begin
        req   = JSON.parse(payload.to_s)
        picks = {}
        (req['picks'] || {}).each { |k, v| picks[k] = v ? true : false }
        pages = sweep_pages(model, req['ns'])
        preview_end(model)                # the sweep selects pages; clean first
        if WR_SceneWalls.confirm_all?(pages, 'wall')
          ok, msg, det = WR_SceneWalls.apply_all(model, picks, pages)
          log_sweep(d, ok, msg, det)
        else
          ok, msg = false, 'Not applied — nothing was changed.'
        end
        d.execute_script('wallsDone(' + { 'ok' => ok, 'msg' => msg }.to_json + ')')
        push_undo(model, d)
      rescue StandardError => e
        d.execute_script('wallsFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    # Click the wall in the viewport, then this — because "Wall 4" means
    # nothing until you have gone digging for it.
    d.add_action_callback('wallspick') do |_c, _p|
      next if busy?(d, 'wallspick')
      begin
        keys = WR_SceneWalls.keys_for_selection(model)
        d.execute_script('wallsPicked(' + { 'keys' => keys }.to_json + ')')
      rescue StandardError => e
        d.execute_script('wallsFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    # And the other way: show me which one this row is.
    d.add_action_callback('wallsreveal') do |_c, key|
      next if busy?(d, 'wallsreveal')
      begin
        ok, msg = WR_SceneWalls.reveal(model, key.to_s)
        d.execute_script('wallsNote(' + { 'ok' => ok, 'msg' => msg }.to_json + ')')
      rescue StandardError => e
        d.execute_script('wallsFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    d.add_action_callback('wallsclose') do |_c, _p|
      preview_end(model)                  # CANCEL / backdrop: put it all back
      begin
        if @walls_return && @walls_return.valid?
          model.pages.selected_page = @walls_return
        end
      rescue StandardError => e
        puts "  could not restore the scene you were on: #{e.class}: #{e.message}"
      ensure
        @walls_return = nil
      end
    end

    # ---- per-scene ANNOTATION hiding, in this window (1.20.0) --------------
    #
    # The same contract as the walls picker one column over, and for the same
    # reason: a scene's hidden callouts can only be read or written while THAT
    # scene is selected, so opening the picker selects the scene and closing it
    # puts the operator back. @walls_return is deliberately shared — only one
    # modal can be open at a time, and two return slots could disagree about
    # where "back" is.
    d.add_action_callback('annotsopen') do |_c, n|
      next if busy?(d, 'annotsopen')
      begin
        pg = model.pages.to_a[n.to_i - 1]
        raise "scene #{n} is gone — hit Rescan" if pg.nil?
        preview_end(model)                # another row's preview, if any
        @walls_return ||= model.pages.selected_page
        model.pages.selected_page = pg
        st = WR_SceneAnnotations.state_hash(model)   # inventory fills @units
        preview_begin(model, :annots, pg)
        warn = WR_SceneAnnotations.pages_not_saving(model).include?(pg.name.to_s)
        d.execute_script('annotsShow(' + { 'n' => n.to_i, 'scene' => pg.name.to_s,
                                           'sets' => st['sets'], 'loose' => st['loose'],
                                           'warn' => warn }.to_json + ')')
      rescue StandardError => e
        d.execute_script('annotsFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    # Every tick sends the full pick set; nothing is written to the scene.
    d.add_action_callback('annotspreview') do |_c, payload|
      next if busy?(d, 'annotspreview')
      begin
        req   = JSON.parse(payload.to_s)
        picks = {}
        (req['picks'] || {}).each { |k, v| picks[k] = v ? true : false }
        preview_show(model, picks)
      rescue StandardError => e
        d.execute_script('annotsNote(' + { 'ok' => false,
          'msg' => "preview failed: #{e.class}: #{e.message}" }.to_json + ')')
      end
    end

    d.add_action_callback('annotsapply') do |_c, payload|
      next if busy?(d, 'annotsapply')
      begin
        req   = JSON.parse(payload.to_s)
        picks = {}
        (req['picks'] || {}).each { |k, v| picks[k] = v ? true : false }
        preview_end(model)                # restore-THEN-apply, see preview_*
        ok, msg = WR_SceneAnnotations.apply(model, picks)
        d.execute_script('annotsDone(' + { 'ok' => ok, 'msg' => msg }.to_json + ')')
        push_undo(model, d)
        log(d, msg, ok ? 'dim' : 'bad')
      rescue StandardError => e
        d.execute_script('annotsFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    # The walls sweep's twin, one column over — same scope, same confirm,
    # same single undo. See wallsapplyall.
    d.add_action_callback('annotsapplyall') do |_c, payload|
      next if busy?(d, 'annotsapplyall')
      begin
        req   = JSON.parse(payload.to_s)
        picks = {}
        (req['picks'] || {}).each { |k, v| picks[k] = v ? true : false }
        pages = sweep_pages(model, req['ns'])
        preview_end(model)                # the sweep selects pages; clean first
        if WR_SceneAnnotations.confirm_all?(pages, 'annotation')
          ok, msg, det = WR_SceneAnnotations.apply_all(model, picks, pages)
          log_sweep(d, ok, msg, det)
        else
          ok, msg = false, 'Not applied — nothing was changed.'
        end
        d.execute_script('annotsDone(' + { 'ok' => ok, 'msg' => msg }.to_json + ')')
        push_undo(model, d)
      rescue StandardError => e
        d.execute_script('annotsFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    # Click the callout in the viewport, then this.
    d.add_action_callback('annotspick') do |_c, _p|
      next if busy?(d, 'annotspick')
      begin
        keys, hint, _others = WR_SceneAnnotations.keys_for_selection(model)
        d.execute_script('annotsPicked(' +
                         { 'keys' => keys, 'hint' => hint }.to_json + ')')
      rescue StandardError => e
        d.execute_script('annotsFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    # And the other way: show me which one this row is.
    d.add_action_callback('annotsreveal') do |_c, key|
      next if busy?(d, 'annotsreveal')
      begin
        ok, msg = WR_SceneAnnotations.reveal(model, key.to_s)
        d.execute_script('annotsNote(' + { 'ok' => ok, 'msg' => msg }.to_json + ')')
      rescue StandardError => e
        d.execute_script('annotsFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    # MODEL state, not scene state — the dialog says so, and the message says
    # by name what it refused to move.
    d.add_action_callback('annotsmove') do |_c, payload|
      next if busy?(d, 'annotsmove')
      begin
        req = JSON.parse(payload.to_s)
        pv_page = @preview && @preview[:page]
        preview_end(model)                # the move re-tags; clean first
        ok, msg = WR_SceneAnnotations.move_selection_to_set(model, req['name'])
        st = WR_SceneAnnotations.state_hash(model)
        preview_begin(model, :annots, pv_page || model.pages.selected_page)
        d.execute_script('annotsMoved(' + { 'ok' => ok, 'msg' => msg,
                                            'sets' => st['sets'],
                                            'loose' => st['loose'] }.to_json + ')')
        log(d, msg, ok ? 'dim' : 'bad')
      rescue StandardError => e
        d.execute_script('annotsFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    d.add_action_callback('annotsclose') do |_c, _p|
      preview_end(model)                  # CANCEL / backdrop: put it all back
      begin
        if @walls_return && @walls_return.valid?
          model.pages.selected_page = @walls_return
        end
      rescue StandardError => e
        puts "  could not restore the scene you were on: #{e.class}: #{e.message}"
      ensure
        @walls_return = nil
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

    # The window's X while a picker is previewing: the forgotten exit.
    d.set_on_closed { preview_end(model) }

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
  body { font:12.5px/1.4 "Segoe UI",system-ui,sans-serif; background:var(--bg);
         color:var(--ink); display:flex; flex-direction:column; overflow:hidden; }
  ::-webkit-scrollbar { width:9px; height:9px; }
  ::-webkit-scrollbar-thumb { background:#c9d0d5; border-radius:5px; }

  .top { flex:0 0 auto; padding:7px 11px 4px; display:flex; gap:10px; align-items:baseline; }
  .top .t { font-weight:650; }
  .top .c { color:var(--muted); font-size:12px; margin-left:auto; }
  .cmd { flex:0 0 auto; margin:0 11px 6px; }
  .cmd input { width:100%; padding:6px 9px; font:inherit; color:var(--ink);
    background:var(--surface); border:1px solid var(--line); border-radius:8px; outline:none; }
  .cmd input:focus { border-color:var(--accent); }

  .bulk { flex:0 0 auto; margin:0 11px 6px; padding:5px 9px; background:var(--surface);
          border:1px solid var(--line); border-radius:8px; display:flex; gap:8px; align-items:center; }
  .bulk .lbl { font-size:10.5px; font-weight:650; letter-spacing:.1em; color:var(--faint); }
  .btn { font:inherit; font-size:11.5px; padding:4px 10px; border:1px solid var(--line);
         border-radius:6px; background:var(--surface); color:var(--ink); cursor:pointer;
         white-space:nowrap; }
  .btn:hover { border-color:var(--accent); }
  .btn.p { background:var(--accent); border-color:var(--accent); color:#fff; font-weight:650; }
  .btn.p:disabled { background:#f0b48e; border-color:#f0b48e; cursor:default; }
  .btn:disabled { color:var(--faint); cursor:default; border-color:var(--line); }

  .wrap { flex:1 1 auto; overflow:auto; margin:0; background:var(--surface);
          border:0; border-radius:0 0 8px 8px; min-height:0; }
  table { width:100%; border-collapse:collapse; }
  th { position:sticky; top:0; background:var(--surface); text-align:left;
       font-size:10px; font-weight:650; letter-spacing:.09em; color:var(--faint);
       padding:5px 8px; border-bottom:1px solid var(--line); white-space:nowrap; z-index:2; }
  td { padding:3px 8px; border-top:1px solid var(--line); vertical-align:middle; }
  tr:hover td { background:#f8f4f1; }
  td.n { font-variant-numeric:tabular-nums; color:var(--muted); width:1%; white-space:nowrap; }
  /* drag-to-reorder (1.23.0): the # cell is the grip; the drop edge is drawn
     in the accent already used for hover states — no new colour. */
  tr[draggable="true"] td.n { cursor:grab; }
  tr.dragging { opacity:.4; }
  tr.over-above td { border-top:2px solid var(--accent); }
  tr.over-below td { border-bottom:2px solid var(--accent); }
  /* The scene name is the SECOND way to jump to a scene -- it carries the
     same data-go hook as the arrow at the end of the row, so the one
     [data-go] wiring below drives both. A cell that moves the SketchUp
     camera when it is clicked has to look clickable, hence the pointer and
     the hover; the underline is hover-only so the column stays a quiet list
     to read. No new colour -- var(--accent), the same one .go button:hover
     already uses. */
  td.sc { cursor:pointer; }
  td.sc:hover { color:var(--accent); text-decoration:underline; }
  td.file { color:var(--muted); font-size:11.5px; white-space:nowrap; overflow:hidden;
            text-overflow:ellipsis; max-width:210px; }
  td.file b { color:var(--accent); font-weight:600; }
  td.go { width:1%; }
  .go button { border:0; background:transparent; color:var(--faint); cursor:pointer;
               font-size:13px; padding:0 4px; }
  .go button:hover { color:var(--accent); }
  mark { background:#ffe3a8; color:inherit; border-radius:2px; }

  .seg { display:inline-flex; border:1px solid var(--line); border-radius:6px; overflow:hidden; }
  /* per-scene wall hiding */
  .wbtn { font:inherit; font-size:11px; padding:3px 9px; border:1px solid var(--line);
    border-radius:3px; background:var(--surface); color:var(--muted); cursor:pointer;
    white-space:nowrap; }
  .wbtn:hover { border-color:var(--accent); color:var(--accent); }
  #wwrap { display:none; position:fixed; inset:0; background:rgba(20,24,28,.44);
    align-items:center; justify-content:center; z-index:50; }
  #wcard { background:var(--surface); border:1px solid var(--line); border-radius:6px;
    width:min(520px,92vw); max-height:82vh; display:flex; flex-direction:column;
    box-shadow:0 10px 34px rgba(0,0,0,.28); }
  #wtitle { font-weight:650; padding:12px 14px 8px; font-size:13px; }
  #wbody { overflow:auto; padding:0 14px; flex:1 1 auto; }
  .wroom { margin-bottom:10px; }
  .wrh { font-size:10px; letter-spacing:.1em; text-transform:uppercase;
    color:var(--muted); margin:6px 0 3px; }
  .wrow { display:flex; align-items:center; gap:8px; padding:3px 2px; font-size:12px; }
  .wrow label { display:flex; align-items:center; gap:8px; cursor:pointer; flex:1 1 auto; }
  .wfind { font:inherit; font-size:10px; letter-spacing:.06em; padding:2px 7px;
    border:1px solid var(--line); border-radius:3px; background:var(--surface);
    color:var(--muted); cursor:pointer; }
  .wfind:hover { border-color:var(--accent); color:var(--accent); }
  .wgap { flex:1 1 auto; }
  .wrow:hover { background:var(--soft); }
  .wside { color:var(--muted); font-size:11px; }
  .wmix { color:var(--accent); font-size:10.5px; margin-left:auto; }
  .wnone { font-size:12px; color:var(--muted); line-height:1.5; }
  .wmsg { padding:8px 14px; font-size:11.5px; color:var(--muted); }
  .wmsg.ok  { color:#2c6e49; }
  .wmsg.bad { color:#b03027; }
  #wfoot { display:flex; gap:8px; padding:10px 14px 12px; border-top:1px solid var(--line); }
  #wfoot button { font:inherit; font-size:12px; padding:5px 13px; border:1px solid var(--line);
    border-radius:3px; background:var(--surface); cursor:pointer; }
  #wfoot button.prim { background:var(--accent); border-color:var(--accent); color:#fff; }
  /* The objects block in the walls popover. Reuses .wrow and .wrh from the
     rows above it — same list, one more section — so there is nothing new
     to style beyond the divider. */
  .wobj { margin-top:10px; border-top:1px solid var(--line); padding-top:8px; }
  .wobjnote { font-size:11px; color:var(--muted); line-height:1.45; margin:4px 2px 0; }
  /* per-scene annotation hiding — the ANNOTATIONS column's modal. It reuses
     the walls modal's w* classes wherever the shape is the same; these are
     only the parts a unified set/callout list needs and walls does not. */
  #awrap { display:none; position:fixed; inset:0; background:rgba(20,24,28,.44);
    align-items:center; justify-content:center; z-index:50; }
  #acard { background:var(--surface); border:1px solid var(--line); border-radius:6px;
    width:min(560px,94vw); max-height:86vh; display:flex; flex-direction:column;
    box-shadow:0 10px 34px rgba(0,0,0,.28); }
  #atitle { font-weight:650; padding:12px 14px 8px; font-size:13px; }
  #abody { overflow:auto; padding:0 14px; flex:1 1 auto; }
  #afoot { display:flex; gap:8px; padding:10px 14px 12px; border-top:1px solid var(--line); }
  #afoot button { font:inherit; font-size:12px; padding:5px 13px; border:1px solid var(--line);
    border-radius:3px; background:var(--surface); cursor:pointer; }
  #afoot button.prim { background:var(--accent); border-color:var(--accent); color:#fff; }
  /* SUN popover (1.27.0): the annotations card's shape, one id over. */
  #swrap { display:none; position:fixed; inset:0; background:rgba(20,24,28,.44);
    align-items:center; justify-content:center; z-index:50; }
  #scard { background:var(--surface); border:1px solid var(--line); border-radius:6px;
    width:min(560px,94vw); max-height:86vh; display:flex; flex-direction:column;
    box-shadow:0 10px 34px rgba(0,0,0,.28); }
  #stitle { font-weight:650; padding:12px 14px 8px; font-size:13px; }
  #sbody { overflow:auto; padding:0 14px 6px; flex:1 1 auto; font-size:12px; }
  #sbody .srow { display:flex; gap:8px; align-items:baseline; padding:5px 0; border-top:1px solid var(--line); }
  #sbody .srow:first-child { border-top:0; }
  #sbody .slab { color:var(--muted); font-size:11px; text-transform:uppercase; letter-spacing:.04em; flex:0 0 150px; }
  #sbody .sval b { font-weight:650; }
  #sbody .sctl { display:flex; gap:10px; align-items:center; flex-wrap:wrap; padding:8px 0 2px; }
  #sbody .sctl input[type=number] { width:56px; font:inherit; padding:2px 4px; border:1px solid var(--line); border-radius:3px; }
  #sbody button.wbtn { margin-left:auto; }
  #sfoot { display:flex; gap:8px; padding:10px 14px 12px; border-top:1px solid var(--line); }
  #sfoot button { font:inherit; font-size:12px; padding:5px 13px; border:1px solid var(--line);
    border-radius:3px; background:var(--surface); cursor:pointer; }
  #sfoot button.prim { background:var(--accent); border-color:var(--accent); color:#fff; }
  .wrh .links { margin-left:auto; text-transform:none; letter-spacing:0; font-size:11px; }
  .wrh .links a { color:var(--muted); cursor:pointer; text-decoration:underline dotted; }
  .wrh .links a:hover { color:var(--accent); }
  /* the callout's own text can be long; it truncates with an ellipsis and the
     full string rides in the title attribute. min-width:0 is what lets a flex
     child actually shrink — without it the row just overflows the card. */
  .wrow label { min-width:0; }
  .wrow .txt { white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .wrow .cnt, .wrow .kind { color:var(--muted); font-size:11px; white-space:nowrap; }
  .wrow .kind { font:10px Consolas,monospace; border:1px solid var(--line);
    border-radius:3px; padding:0 4px; }
  .wrow.member { padding-left:22px; }
  .wrow.member.dis { opacity:.5; }
  .wrow.member.dis label { cursor:default; }
  .wrow.member.dis .with { color:var(--accent); font-size:10.5px; margin-left:auto;
    white-space:nowrap; }
  .aexp { border:0; background:transparent; color:var(--faint); cursor:pointer;
    font-size:10px; padding:0 2px; width:16px; }
  .aexp:hover { color:var(--accent); }
  .ahint { font-size:11px; color:var(--muted); margin:4px 0 6px 2px; line-height:1.45; }
  .amove { border-top:1px solid var(--line); margin-top:6px; padding:8px 0 6px;
    display:flex; gap:6px; align-items:center; flex-wrap:wrap; }
  .amove .wrh { flex:1 1 100%; margin:0 0 2px; }
  .amove select, .amove input { font:inherit; font-size:12px; padding:4px 7px;
    border:1px solid var(--line); border-radius:4px; background:#fff; color:var(--ink); }
  .amove input { width:120px; display:none; }
  .amove input.show { display:inline-block; }
  .amove .prefix { color:var(--faint); font:11.5px Consolas,monospace; display:none; }
  .amove .prefix.show { display:inline; }
  .amove button { font:inherit; font-size:11px; padding:4px 10px; border:1px solid var(--line);
    border-radius:3px; background:var(--surface); cursor:pointer; }
  .amove .note { flex:1 1 100%; font-size:11px; color:var(--muted); }
  .seg button { font:inherit; font-size:11px; padding:3px 9px; border:0; background:var(--surface);
                color:var(--muted); cursor:pointer; border-left:1px solid var(--line); }
  .seg button:first-child { border-left:0; }
  .seg button.on-skip   { background:#eef1f2; color:var(--muted); font-weight:650; }
  .seg button.on-image  { background:#e8f0fa; color:#2b5e8f; font-weight:650; }
  .seg button.on-render { background:var(--soft); color:var(--accent); font-weight:650; }

  .sect { flex:0 0 auto; margin:0 11px 6px; background:var(--surface);
          border:1px solid var(--line); border-radius:8px; }
  .sect > .hd { padding:5px 9px; display:flex; gap:8px; align-items:center; cursor:pointer;
                user-select:none; }
  .sect .hd .lbl { font-size:10.5px; font-weight:650; letter-spacing:.1em; color:var(--faint); }
  .sect .hd .sum { color:var(--muted); font-size:11.5px; margin-left:auto; }
  .sect .hd .tri { color:var(--faint); font-size:10px; }
  .sect .bodyy { padding:2px 9px 8px; display:none; }
  .sect.open .bodyy { display:block; }
  /* A section that should EAT the leftover height when it is open (the scene
     list, the log) and give all of it back when it is collapsed. Without this
     every section is fixed-height, the column overflows a short window, and
     the bar carrying Export package is pushed off the bottom -- which is the
     bug this markup exists to fix. */
  .sect.grow { display:flex; flex-direction:column; min-height:0; }
  .sect.grow.open { flex:1 1 auto; }
  .sect.grow.open > .bodyy { flex:1 1 auto; min-height:0; display:flex;
                             flex-direction:column; padding:0; }
  .sect .hd .mini { color:var(--faint); font-size:14px; line-height:1; padding:0 2px; }
  .sect .hd:hover .mini { color:var(--accent); }
  .matrow { display:flex; gap:8px; align-items:center; padding:4px 0; }
  .matrow .from { width:64px; flex:0 0 auto; color:var(--muted); font-size:12px; }
  .matrow .from b { color:var(--ink); font-weight:600; }
  .matrow .arrow { flex:0 0 auto; color:var(--muted); font-size:12px; }
  .matrow .to { width:132px; flex:0 0 auto; color:var(--muted); font-size:12px; }
  .matrow select.src { flex:1 1 0; min-width:0; }
  .matrow select.src.gone { color:#b00; }
  .matmode { display:flex; gap:8px; align-items:center; padding:2px 0 8px; }
  .matmode .now { color:var(--muted); font-size:12px; }
  .matmode .now b { color:var(--ink); font-weight:600; }
  .matrow select { flex:1 1 auto; font:inherit; font-size:12px; padding:4px 6px;
                   border:1px solid var(--line); border-radius:6px; background:#fff;
                   color:var(--ink); min-width:0; }
  .matnote { color:var(--muted); font-size:11px; padding-top:6px;
             border-top:1px dashed var(--line); margin-top:6px; }

  .out { flex:0 0 auto; margin:0; padding:0; background:transparent;
         border:0; border-radius:0; display:grid;
         grid-template-columns:auto 1fr auto; gap:5px 8px; align-items:center; }
  .out .lbl { font-size:10.5px; font-weight:650; letter-spacing:.08em; color:var(--faint); }
  .out input, .out select { font:inherit; font-size:12px; padding:5px 8px;
               border:1px solid var(--line); border-radius:6px; background:#fff;
               color:var(--ink); min-width:0; }
  .out input:focus { border-color:var(--accent); outline:none; }
  .out .half { display:flex; gap:8px; align-items:center; flex-wrap:wrap; }
  .out .half .lbl { width:auto; }
  .out .half input[type=text] { width:72px; }
  .out .shadelbl { font-size:11.5px; color:var(--muted); }

  .runlog { flex:1 1 auto; margin:0; background:#20262a; color:#cdd6da;
            border-radius:0 0 8px 8px; font:11px/1.5 Consolas,monospace; padding:7px 10px;
            max-height:150px; min-height:0; overflow:auto; }
  .runlog .ok { color:#8fd0a0; } .runlog .bad { color:#f0a08c; } .runlog .dim { color:#8b979e; }
  .bar { flex:0 0 auto; padding:2px 11px 9px; display:flex; gap:8px; align-items:center; }
  .prog { flex:1 1 auto; color:var(--muted); font-size:11.5px; }
  .prog .pbar { height:4px; background:#e6e9eb; border-radius:2px; margin-top:4px; overflow:hidden; }
  .prog .pbar i { display:block; height:100%; width:0%; background:var(--accent); transition:width .2s; }
  .foot { flex:0 0 auto; padding:0 11px 8px; color:var(--muted); font-size:10.5px; display:none; }
  body.showhelp .foot { display:block; }
</style></head><body>

<div class="top">
  <span class="t">#{escHtml(title)}</span>
  <span class="c" id="count"></span>
  <button class="btn" id="rescan"
          title="Re-read the model's scene list — picks up scenes added, renamed or deleted since this window opened. Your MODE picks, folder, search and log all stay.">Rescan</button>
  <button class="btn" id="undolast" disabled
          title="Nothing to put back yet">UNDO LAST APPLY</button>
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

<div class="sect grow open" id="scenesect">
  <div class="hd">
    <span class="tri">&#9660;</span>
    <span class="lbl">SCENES</span>
    <span class="sum" id="scenesum"></span>
    <span class="mini" title="Minimise">&minus;</span>
  </div>
  <div class="bodyy"><div class="wrap"><table>
    <thead><tr>
      <th>#</th><th>SCENE</th><th>MODE</th><th>SUN</th><th>WALLS</th><th>ANNOTATIONS</th><th>FILE IT WILL WRITE</th><th></th>
    </tr></thead>
    <tbody id="body"></tbody>
  </table></div></div>
</div>

<div class="sect" id="mats">
  <div class="hd" id="matshd">
    <span class="tri">&#9654;</span>
    <span class="lbl">MATERIALS FOR THE V-RAY PASS</span>
    <span class="sum" id="matsum"></span>
  </div>
  <div class="bodyy" id="matbody"></div>
</div>

<div class="sect open" id="outsect">
  <div class="hd">
    <span class="tri">&#9660;</span>
    <span class="lbl">FOLDER &amp; DETAILS</span>
    <span class="sum" id="outsum"></span>
    <span class="mini" title="Minimise">&minus;</span>
  </div>
  <div class="bodyy"><div class="out">
  <span class="lbl">FOLDER</span>
  <input type="text" id="dir" value="#{escAttr(dir)}" style="width:100%">
  <button class="btn" id="browse">Browse&hellip;</button>

  <span class="lbl">IMAGES</span>
  <div class="half">
    <span class="lbl">WIDTH</span><input type="text" id="width" value="#{escAttr(width)}">
    <span class="lbl">PX — plain images: width from the V-Ray Asset Editor when it can be read (this field is the fallback), height follows the SketchUp window's shape so screen notes land where you placed them. V-Ray renders use the Asset Editor size exactly; make the window that shape for plates of one size.</span>
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
    <option value="draft"#{annot == 'client' ? '' : ' selected'}>Per scene — each scene shows what its ANNOTATIONS picker left showing (normal)</option>
    <option value="client"#{annot == 'client' ? ' selected' : ''}>Client-safe — strip every dimension and note from every image</option>
  </select>
  <span></span>
  <span class="lbl"></span>
  <label class="shadelbl"><b>Per scene</b> is the normal pack: a scene named for its dimensions carries them, and each image shows exactly what its own ANNOTATIONS picker left showing. <b>Client-safe</b> is the deliberate strip-everything pass for a pack that must carry no callouts at all: it hides #{WR_Mode::ANNOT_TAGS.join(', ')}, every WR-Dims-… / WR-Notes-… set in this model, <b>and every loose callout on Untagged</b> — SketchUp will not hide the Untagged tag, so those go one by one (1.20.0) — on every scene, whatever its picker says. Everything is put back at the end. The choice is remembered per user, not per model.</label>
  <span></span>

  <span class="lbl">BACKGROUND</span>
  <label class="shadelbl"><input type="checkbox" id="transp">
    Transparent background (alpha channel) — for compositing a booth onto a photo or a slide. <b>Off every time this window opens</b>; it is never remembered.</label>
  <span></span>
  <span class="lbl"></span>
  <label class="shadelbl"><b>Plain images:</b> the sky, ground and fog are switched off for each write and the file carries alpha where the view shows background. <b>V-Ray renders:</b> saved with V-Ray's own alpha instead of the usual opaque save. In both, only what the camera sees THROUGH is transparent — a booth inside a modelled room is opaque wall to wall, so hide the room per scene (WALLS column) if the booth is to float. <b>Not for a proposal pack:</b> the generator wants opaque plates — flatten onto white first (<code>scripts/wr-flatten-trim.py</code>). The manifest records <code>transparent_background</code> and, per file, whether the PNG on disk actually has an alpha channel.</label>
  <span></span>
</div></div>
</div>

<div class="sect grow open" id="logsect" style="display:none">
  <div class="hd">
    <span class="tri">&#9660;</span>
    <span class="lbl">LOG</span>
    <span class="sum" id="logsum"></span>
    <span class="mini" title="Minimise">&minus;</span>
  </div>
  <div class="bodyy"><div class="runlog" id="log"></div></div>
</div>

<div class="bar">
  <div class="prog"><span id="pmsg">Ready.</span><div class="pbar"><i id="pfill"></i></div></div>
  <button class="btn" id="cancel" style="display:none">Cancel</button>
  <button class="btn" id="helpb" title="Show the notes under this window">?</button>
  <button class="btn" id="closeb">Close</button>
  <button class="btn p" id="export">Export package</button>
</div>

<div class="foot"># is the scene's position in the tabs — same number the exporters use.
  The arrow jumps to that scene. Filenames are the scene names verbatim; only characters
  Windows forbids become &ldquo;-&rdquo;, and a V-Ray scene gets &ldquo; render&rdquo; added.
  Size the SketchUp window to the aspect you want before exporting.</div>

<div id="wwrap">
  <div id="wcard">
    <div id="wtitle"></div>
    <div id="wbody"></div>
    <div id="wmsg" class="wmsg"></div>
    <div id="wfoot">
      <button id="wpick" title="Tick the rows that match what is selected in the model">USE MY SELECTION</button>
      <button id="wselhide" title="Hide whatever is selected in the model on this scene, right now">HIDE SELECTED</button>
      <button id="wselshow" title="Show whatever is selected in the model on this scene, right now">SHOW SELECTED</button>
      <span class="wgap"></span>
      <button id="wapplyall" title="The same ticks into every scene the table is showing — asks first. Ctrl+Z will NOT undo it; UNDO LAST APPLY will.">APPLY TO ALL SCENES</button>
      <button id="wapply" class="prim">APPLY TO THIS SCENE</button>
      <button id="wcancel">CANCEL</button>
    </div>
  </div>
</div>
<div id="awrap">
  <div id="acard">
    <div id="atitle"></div>
    <div id="abody"></div>
    <div id="amsg" class="wmsg"></div>
    <div id="afoot">
      <button id="apick" title="Select the callouts in the model, then press this">USE MY SELECTION</button>
      <span class="wgap"></span>
      <button id="aapplyall" title="The same ticks into every scene the table is showing — asks first. Ctrl+Z will NOT undo it; UNDO LAST APPLY will.">APPLY TO ALL SCENES</button>
      <button id="aapply" class="prim">APPLY TO THIS SCENE</button>
      <button id="acancel">CANCEL</button>
    </div>
  </div>
</div>
<div id="swrap">
  <div id="scard">
    <div id="stitle"></div>
    <div id="sbody"></div>
    <div id="smsg" class="wmsg"></div>
    <div id="sfoot">
      <button id="sfix" title="Turn on shadow-settings saving for every scene that has it off">FIX SCENES</button>
      <span class="wgap"></span>
      <button id="sapplyall" title="This scene's saved sun into every scene the table is showing — asks first. Ctrl+Z will NOT undo it; UNDO LAST APPLY will.">APPLY TO ALL SCENES</button>
      <button id="saim" class="prim" title="Light it from here, from this scene's own camera, saved into this scene">AIM FROM THIS SCENE'S CAMERA</button>
      <button id="scancel">CLOSE</button>
    </div>
  </div>
</div>
<script>
(function () {
  "use strict";
  var ST = #{st.to_json};
  var running = false;

  function g(id){ return document.getElementById(id); }
  var $q=g("q"), $b=g("body"), $count=g("count"), $pick=g("picksum"),
      $log=g("log"), $pmsg=g("pmsg"), $pfill=g("pfill"),
      $wrap=g("wwrap"), $wtitle=g("wtitle"), $wbody=g("wbody"),
      $wmsg=g("wmsg"), $wapply=g("wapply"), $wapplyall=g("wapplyall"), $wcancel=g("wcancel"),
      $wpick=g("wpick"), $wselhide=g("wselhide"), $wselshow=g("wselshow"),
      $awrap=g("awrap"), $atitle=g("atitle"), $abody=g("abody"),
      $amsg=g("amsg"), $aapply=g("aapply"), $aapplyall=g("aapplyall"), $acancel=g("acancel"),
      $apick=g("apick"),
      $swrap=g("swrap"), $stitle=g("stitle"), $sbody=g("sbody"), $smsg=g("smsg"),
      $saim=g("saim"), $sapplyall=g("sapplyall"), $scancel=g("scancel"), $sfix=g("sfix");

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
    // Rows drag only when the table shows EVERY scene and no batch is
    // running: in a filtered view "drop above scene 5" has no single meaning
    // in the full list, so rather than guess, the grip is off and the # cell
    // says why.
    var canDrag = !running && view.length === ST.rows.length;
    var grip = canDrag ? "Drag to reorder the SketchUp scenes"
                       : (running ? "Reordering is off while a batch runs"
                                  : "Clear the search to drag scenes into a new order");
    $b.innerHTML = view.map(function(r){
      var fh = r.file ? esc(r.file).replace(/ render(?=( \\(\\d+\\))?\\.png$)/," <b>render</b>") : "&mdash;";
      return "<tr data-n='"+r.n+"'"+(canDrag ? " draggable='true'" : "")+">"+
        "<td class='n' title='"+grip+"'>"+r.n+"</td>"+
        "<td class='sc' data-go='"+r.n+"' title='Go to this scene in SketchUp'>"+
          hl(r.scene,hi)+"</td>"+
        "<td><span class='seg'>"+
          segBtn(r,"skip","Skip")+segBtn(r,"image","Image")+segBtn(r,"render","Render")+
        "</span></td>"+
        "<td><button class='wbtn' data-sun='"+r.n+"' title='Where the sun is for this scene — aim it, save it, or put it on every scene'>&#9728; Sun</button></td>"+
        "<td><button class='wbtn' data-walls='"+r.n+"' title='Choose which whole walls this scene hides'>Hide walls</button></td>"+
        "<td><button class='wbtn' data-annots='"+r.n+"' title='Choose which notes and dimensions this scene hides'>Hide notes</button></td>"+
        "<td class='file' title='"+esc(r.file)+"'>"+fh+"</td>"+
        "<td class='go'><button data-go='"+r.n+"' title='Go to this scene'>&#8594;</button></td></tr>";
    }).join("");
    if(canDrag) wireDrag();
    Array.prototype.forEach.call($b.querySelectorAll("[data-mode]"), function(el){
      el.addEventListener("click", function(){
        if(running) return;
        if(window.sketchup && sketchup.mark)
          sketchup.mark(JSON.stringify({ n:+el.getAttribute("data-n"),
                                         mode:el.getAttribute("data-mode") }));
      });
    });
    Array.prototype.forEach.call($b.querySelectorAll("[data-sun]"), function(el){
      el.addEventListener("click", function(e){
        e.stopPropagation();
        if(running) return;
        sunOpen(+el.getAttribute("data-sun"));
      });
    });
    Array.prototype.forEach.call($b.querySelectorAll("[data-walls]"), function(el){
      el.addEventListener("click", function(e){
        e.stopPropagation();
        if(running) return;
        wallsOpen(+el.getAttribute("data-walls"));
      });
    });
    Array.prototype.forEach.call($b.querySelectorAll("[data-annots]"), function(el){
      el.addEventListener("click", function(e){
        e.stopPropagation();
        if(running) return;
        annotsOpen(+el.getAttribute("data-annots"));
      });
    });
    // Both the name cell and the arrow button carry data-go, so this one
    // loop wires both and they cannot drift apart. The arrow sits inside
    // the ROW but not inside the name CELL, so nothing fires twice; the
    // existing stopPropagation stays, because it is what keeps a click on
    // the arrow from also reaching an ancestor handler. The 'running'
    // check is deliberately NOT duplicated here -- Ruby's
    // busy?(d, 'activate') guard already refuses the jump mid-batch AND
    // writes the reason into the log, which is better feedback than a
    // silent no-op in JS. A click must never move the camera out from
    // under a running exporter.
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
    // The scene section's own header carries the count, so a minimised list
    // still says what is in it.
    g("scenesum").textContent = $count.textContent;
    var filled = ST.slots.filter(function(s){ return s.fill; }).length;
    g("matsum").textContent = nr ? (filled+" of "+ST.slots.length+" slots filled — applies to "
                                    +nr+" render scene(s)")
                                 : "no render scenes marked";
    g("export").disabled = running || (nr+ni)===0;
    // drawMats() is not re-run when a batch starts or stops, so the mode
    // button's disabled state is refreshed here instead — the batch owns the
    // model's mode while it runs.
    var mb = g("modebtn"); if(mb) mb.disabled = running;
    // Rescan too: Ruby's busy? guard would refuse it anyway, but a greyed
    // button says so before the click rather than after.
    var rb = g("rescan"); if(rb) rb.disabled = running;
    drawUndo();
  }

  // UNDO LAST APPLY (1.26.1): enabled only when Ruby says there is a
  // record for THIS model; the tooltip names what it would put back.
  function drawUndo(){
    var ub = g("undolast"); if(!ub) return;
    var u = ST.undo;
    ub.disabled = running || !u;
    ub.title = u
      ? "Put back the saved "+u.what+" answer on "+u.scenes.length+" scene(s): "+u.scenes.join(", ")
        +" (applied "+u.at+"). One step, this SketchUp session only. Ctrl+Z cannot do this."
      : "Nothing to put back yet — an apply in this SketchUp session records what it overwrote.";
  }
  window.setUndo = function (u) { ST.undo = u; drawUndo(); };

  // HTML5 drag-and-drop over the rows. The drop sends {from, to} as TABLE
  // numbers and nothing else: the table is not touched here, because Ruby
  // pushes a fresh state from the model and that is the only version of
  // the order that counts. Dropping on the upper half of a row means
  // "before it", the lower half "after it".
  var dragN = 0;
  function clearOver(){
    Array.prototype.forEach.call($b.querySelectorAll("tr.over-above, tr.over-below"), function(tr){
      tr.classList.remove("over-above"); tr.classList.remove("over-below");
    });
  }
  function wireDrag(){
    Array.prototype.forEach.call($b.querySelectorAll("tr[draggable]"), function(tr){
      tr.addEventListener("dragstart", function(e){
        dragN = +tr.getAttribute("data-n");
        tr.classList.add("dragging");
        try { e.dataTransfer.setData("text/plain", String(dragN)); e.dataTransfer.effectAllowed = "move"; } catch(_){}
      });
      tr.addEventListener("dragend", function(){
        tr.classList.remove("dragging"); clearOver(); dragN = 0;
      });
      tr.addEventListener("dragover", function(e){
        if(!dragN) return;
        e.preventDefault();
        var r = tr.getBoundingClientRect(), above = (e.clientY - r.top) < r.height/2;
        clearOver();
        tr.classList.add(above ? "over-above" : "over-below");
      });
      tr.addEventListener("dragleave", function(){ tr.classList.remove("over-above"); tr.classList.remove("over-below"); });
      tr.addEventListener("drop", function(e){
        e.preventDefault();
        if(!dragN || running) return;
        var target = +tr.getAttribute("data-n"),
            r = tr.getBoundingClientRect(), above = (e.clientY - r.top) < r.height/2,
            from = dragN, to;
        // Final 1-based position once `from` is lifted out of the list.
        if(above) to = (from < target) ? target - 1 : target;
        else      to = (from < target) ? target     : target + 1;
        clearOver();
        if(to === from) return;
        if(window.sketchup && sketchup.reorder)
          sketchup.reorder(JSON.stringify({ from: from, to: to }));
      });
    });
  }

  function drawMats(){
    // The same flip as the Toggle Draft/Render panel button, put where the
    // slots are set — you pick the materials here, so you should be able to
    // SEE them here rather than closing the window to look.
    // Three states, not two: WR_Mode reports "unknown (never toggled)" on a
    // model it has never switched, and claiming that one is showing drafting
    // colours would be a guess. Say what is known and no more.
    var mode = ST.mode || "", isRender = mode === "render", isDraft = mode === "draft",
        word = isRender ? "RENDER" : isDraft ? "DRAFT" : "NOT YET TOGGLED",
        tail = isRender ? " — the V-Ray fills below are on the model right now."
             : isDraft  ? " — drafting colours. Press to put the fills below on the model."
             : " — this model has not been switched, so what it shows now is whatever it was saved with.",
        modeHtml = "<div class='matmode'>" +
          "<button class='btn' id='modebtn'" + (running ? " disabled" : "") + ">" +
          (isRender ? "Show draft materials" : "Show render materials") + "</button>" +
          "<span class='now'>Model is showing <b>" + word + "</b>" + tail + "</span></div>";
    g("matbody").innerHTML = modeHtml + ST.slots.map(function(s){
      // LEFT select — which material in THIS model the slot swaps FROM. The
      // shop default (0128_White and friends) is only a default; a model that
      // did not come out of build-room.rb needs to point the slot at its own
      // floor. A source that is no longer in the model is still listed, and
      // marked, rather than silently falling back to the first material.
      var srcs = ST.materials.slice();
      if(s.missing && s.draft && srcs.indexOf(s.draft) < 0) srcs.unshift(s.draft);
      var sopts = srcs.map(function(m){
        return "<option"+(m===s.draft?" selected":"")+">"+esc(m)+"</option>";
      }).join("");
      // RIGHT select — the V-Ray material it swaps TO.
      var opts = ["(unset)"].concat(ST.materials).map(function(m){
        var cur = s.fill ? s.fill : "(unset)";
        return "<option"+(m===cur?" selected":"")+">"+esc(m)+"</option>";
      }).join("");
      var title = s.missing ? " title='Not a material in this model right now'"
                : (s.draft===s.house ? " title='The shop default for this slot'"
                                     : " title='Custom for this model — the shop default is "+esc(s.house)+"'");
      return "<div class='matrow'><span class='from'>"+esc(s.label)+"</span>"+
             "<select class='src"+(s.missing?" gone":"")+"' data-slot='"+esc(s.slot)+"'"+title+">"+sopts+"</select>"+
             "<span class='arrow'>&rarr;</span>"+
             "<span class='to'>"+esc(s.slot)+"</span>"+
             "<select data-slot='"+esc(s.slot)+"'>"+opts+"</select></div>";
    }).join("") +
    "<div class='matnote'>Applied only while the V-Ray scenes render, and reverted before this " +
    "window says done — the model goes back to drafting materials. A slot left (unset) leaves " +
    "those surfaces drafting and is <b>reported by name</b>, never silently wrong. The left box " +
    "is the material the slot swaps <b>from</b> — it starts on the shop drafting material, and " +
    "you point it at this model's own floor, walls or door when the model didn't come from " +
    "Build room. Same slots as the Draft / Render toggle — set them in either place. If " +
    "SketchUp ever dies mid-render, the Toggle Draft/Render button puts the model back.</div>";
    var mb = g("modebtn");
    if(mb) mb.addEventListener("click", function(){
      if(running) return;
      if(window.sketchup && sketchup.togglemode) sketchup.togglemode("");
    });
    Array.prototype.forEach.call(g("matbody").querySelectorAll("select"), function(sel){
      var isSrc = sel.classList.contains("src");
      sel.addEventListener("change", function(){
        var msg = JSON.stringify({ slot:sel.getAttribute("data-slot"), name:sel.value });
        if(!window.sketchup) return;
        if(isSrc){ if(sketchup.setsrc) sketchup.setsrc(msg); }
        else     { if(sketchup.setfill) sketchup.setfill(msg); }
      });
    });
  }

  // Ruby pushes fresh rows + filenames after every mark / bulk / fill change,
  // so the FILE column always shows what the export will actually write.
  // ---- per-scene wall hiding, inline under the row ------------------------
  // The picker is a MODAL over this window rather than a row expansion: the
  // scene list is filterable and scrollable, and a panel anchored to a row
  // that can scroll out from under it is how you end up applying walls to a
  // scene you are not looking at.
  // APPLY TO ALL SCENES means the scenes the TABLE is showing — every scene
  // unless the search box is filtering. That is the bulk bar's SHOWN → rule
  // one section up, and the narrower of the two readings: a deliberate
  // filter narrows this too, and the label says how many so nobody has to
  // remember whether one is on. Ruby confirms by name before writing.
  function allScope(btn){
    var all = view.length === ST.rows.length;
    btn.textContent = all ? "APPLY TO ALL "+ST.rows.length+" SCENES"
                          : "APPLY TO THE "+view.length+" SHOWN SCENES";
    btn.disabled = view.length < 2;
    btn.title = view.length < 2
      ? "Only this scene is shown — use APPLY TO THIS SCENE"
      : "The same ticks into "+(all ? "every scene" : "the "+view.length+" scenes the table is showing")
        +" — asks first. Ctrl+Z will NOT undo it; UNDO LAST APPLY will.";
  }
  function shownNs(){ return view.map(function(r){ return r.n; }); }

  var wallsN = 0, wallsUnits = [], wallsPicks = {};
  function wallsOpen(n){
    wallsN = n; wallsPicks = {};
    allScope($wapplyall);
    $wtitle.textContent = "Loading scene " + n + "…";
    $wbody.innerHTML = "";
    $wmsg.textContent = ""; $wmsg.className = "wmsg";
    $wrap.style.display = "flex";
    if(window.sketchup && sketchup.wallsopen) sketchup.wallsopen(String(n));
  }
  function wallsClose(){
    $wrap.style.display = "none";
    wallsN = 0; wallsUnits = []; wallsPicks = {};
    if(window.sketchup && sketchup.wallsclose) sketchup.wallsclose("");
  }
  window.wallsFail = function (msg) {
    $wtitle.textContent = "Could not read the walls";
    $wmsg.textContent = msg; $wmsg.className = "wmsg bad";
  };
  window.wallsShow = function (d) {
    wallsUnits = d.units || [];
    var wallsObjs = d.objects || [];
    $wtitle.textContent = "Hidden in “" + d.scene + "”";
    // The objects section renders whether or not there are named walls, so
    // the no-walls case can no longer swallow the whole body and leave the
    // booth unreachable — which is how this window ended up with no way to
    // hide anything but a wall.
    var wallsHtml;
    if(!wallsUnits.length){
      wallsHtml = "<p class='wnone'>No named walls in this model. The picker "
        + "lists a wall by its name (“Wall 3”). A room drawn by hand or by an "
        + "older script has unnamed wall groups — run <b>Name walls for the scene "
        + "picker</b> once, then come back. Whole objects are listed below "
        + "either way.</p>";
    } else {
      var byRoom = {}, order = [];
      wallsUnits.forEach(function(u){
        if(!byRoom[u.room]){ byRoom[u.room] = []; order.push(u.room); }
        byRoom[u.room].push(u);
      });
      wallsHtml = order.map(function(room){
        return "<div class='wroom'><div class='wrh'>" + esc(room) + "</div>"
          + byRoom[room].map(function(u){
              var side = u.side ? " <span class='wside'>" + esc(u.side) + "</span>" : "";
              return "<div class='wrow'><label><input type='checkbox' data-key='"
                + esc(u.key) + "'" + (u.hidden ? " checked" : "") + ">"
                + "<span>Wall " + u.wall + side + "</span></label>"
                + (u.mixed ? "<span class='wmix'>pieces disagree — ticking sets them all</span>" : "")
                + "<button class='wfind' data-find='" + esc(u.key)
                + "' title='Select this wall in the model so you can see it'>SHOW ME</button>"
                + "</div>";
            }).join("") + "</div>";
      }).join("");
    }
    // Objects: the booth, furniture, anything at the top level that is not
    // already a wall row above. Same checkbox, same data-key, so Apply and
    // USE MY SELECTION pick them up with no extra wiring.
    var objHtml = "<div class='wobj'><div class='wrh'>Objects — booth, furniture, "
      + "anything that is not a named wall</div>";
    objHtml += wallsObjs.length
      ? wallsObjs.map(function(u){
          return "<div class='wrow'><label><input type='checkbox' data-key='"
            + esc(u.key) + "'" + (u.hidden ? " checked" : "") + ">"
            + "<span class='txt' title='" + esc(u.label) + "'>" + esc(u.label) + "</span>"
            + (u.count > 1 ? "<span class='cnt'>" + u.count + " copies</span>" : "")
            + "</label>"
            + (u.mixed ? "<span class='wmix'>copies disagree — ticking sets them all</span>" : "")
            + "<button class='wfind' data-find='" + esc(u.key)
            + "' title='Select this object in the model so you can see it'>SHOW ME</button>"
            + "</div>";
        }).join("")
      : "<div class='wrow'><span class='cnt'>nothing at the top level that is not "
        + "already a wall above</span></div>";
    objHtml += "<div class='wobjnote'>Top-level objects only. Something nested "
      + "inside a component is not listed here — hiding it would hide it in every "
      + "copy of the parent, not just on this scene — so select it in the model and "
      + "use HIDE SELECTED.</div></div>";
    $wbody.innerHTML = wallsHtml + objHtml;
    // Ticked = hidden in this scene. Every wall is sent on Apply, not just the
    // ones touched, so a box UNticked here reliably SHOWS that wall again.
    Array.prototype.forEach.call($wbody.querySelectorAll("input[data-key]"), function(el){
      el.addEventListener("change", function(){
        wallsPicks[el.getAttribute("data-key")] = el.checked;
        wallsPreview();
      });
    });
    Array.prototype.forEach.call($wbody.querySelectorAll("[data-find]"), function(el){
      el.addEventListener("click", function(){
        if(window.sketchup && sketchup.wallsreveal)
          sketchup.wallsreveal(el.getAttribute("data-find"));
      });
    });
    $wmsg.className = "wmsg" + (d.warn ? " bad" : "");
    $wmsg.textContent = d.warn
      ? "This scene does not save hidden objects, so walls will NOT come back on it. "
        + "Apply turns that on for you."
      : "Ticked = hidden when this scene exports — and hidden in the viewport now, "
        + "so you can check before Apply. Cancel puts everything back.";
  };
  window.wallsPicked = function (r) {
    var keys = r.keys || {}, n = 0;
    // ADDS to what is already ticked — picking a second wall must not
    // silently untick the first.
    Array.prototype.forEach.call($wbody.querySelectorAll("input[data-key]"), function(el){
      if(keys.indexOf(el.getAttribute("data-key")) >= 0){ el.checked = true; n++; }
    });
    if(n) wallsPreview();
    $wmsg.className = "wmsg" + (n ? " ok" : " bad");
    $wmsg.textContent = n
      ? n + " wall(s) ticked from your selection. Apply to save them into this scene."
      : "Nothing in your selection matched a row in this list. If it is nested "
        + "inside a component or a room, there is no row for it — press HIDE "
        + "SELECTED instead and it goes straight into this scene.";
  };
  window.wallsNote = function (r) {
    $wmsg.className = "wmsg" + (r.ok ? "" : " bad");
    $wmsg.textContent = r.msg;
  };
  $wpick.addEventListener("click", function(){
    if(window.sketchup && sketchup.wallspick) sketchup.wallspick("");
  });
  // These two write into the scene immediately — no APPLY needed — which is
  // the standalone dialog's behaviour and the only thing that can reach a
  // container the list does not have a row for.
  function wallsSel(hide){
    if(window.sketchup && sketchup.wallssel)
      sketchup.wallssel(JSON.stringify({ n: wallsN, hide: hide }));
  }
  $wselhide.addEventListener("click", function(){ wallsSel(true); });
  $wselshow.addEventListener("click", function(){ wallsSel(false); });
  window.wallsDone = function (r) {
    $wmsg.textContent = r.msg;
    $wmsg.className = "wmsg" + (r.ok ? " ok" : " bad");
    if(r.ok) setTimeout(wallsClose, 900);
  };
  // LIVE PREVIEW (1.24.0): every tick sends the whole pick set, so Ruby
  // sets every row from picks-or-baseline and nothing accumulates. Nothing
  // is saved until APPLY; CANCEL, the backdrop and the window's X all put
  // the viewport back.
  function wallsPreview(){
    if(running || !wallsN) return;
    if(window.sketchup && sketchup.wallspreview)
      sketchup.wallspreview(JSON.stringify({ n: wallsN, picks: wallsCollect() }));
  }
  function wallsCollect(){
    var picks = {};
    Array.prototype.forEach.call($wbody.querySelectorAll("input[data-key]"), function(el){
      picks[el.getAttribute("data-key")] = el.checked;
    });
    return picks;
  }
  $wapply.addEventListener("click", function(){
    if(window.sketchup && sketchup.wallsapply)
      sketchup.wallsapply(JSON.stringify({ n: wallsN, picks: wallsCollect() }));
  });
  $wapplyall.addEventListener("click", function(){
    if(window.sketchup && sketchup.wallsapplyall)
      sketchup.wallsapplyall(JSON.stringify({ n: wallsN, ns: shownNs(), picks: wallsCollect() }));
  });
  $wcancel.addEventListener("click", wallsClose);
  $wrap.addEventListener("click", function(e){ if(e.target === $wrap) wallsClose(); });

  // ---- per-scene ANNOTATION hiding (1.20.0) -------------------------------
  // ONE LIST, ONE RULE: ticked = hidden when this scene exports — the walls
  // polarity, deliberately, because the two buttons sit on the same row.
  //
  // Two mechanisms under it and the operator never picks between them: a SET
  // row is a tag (one flag hides every callout on it, at any depth, and the
  // client-safe pass can find it by name); a CALLOUT row is one entity's own
  // hidden flag. SketchUp will NOT hide the Untagged tag — proved live, 9 Sep
  // 2026 — so loose callouts are listed one by one under NOT IN A SET with
  // all/none links, and there is deliberately no "Untagged" set row: a tick
  // that silently does nothing is the one outcome this picker forbids.
  var annotsN = 0, annotsSets = [], annotsLoose = [], aPicks = {}, aExp = {};
  var AKIND = { text:"text", dim:"dim", "3d":"3D" };

  function annotsOpen(n){
    annotsN = n; aPicks = {}; aExp = {};
    allScope($aapplyall);
    $atitle.textContent = "Loading scene " + n + "…";
    $abody.innerHTML = "";
    $amsg.textContent = ""; $amsg.className = "wmsg";
    $awrap.style.display = "flex";
    if(window.sketchup && sketchup.annotsopen) sketchup.annotsopen(String(n));
  }
  function annotsClose(){
    $awrap.style.display = "none";
    annotsN = 0; annotsSets = []; annotsLoose = []; aPicks = {}; aExp = {};
    if(window.sketchup && sketchup.annotsclose) sketchup.annotsclose("");
  }
  window.annotsFail = function (msg) {
    $atitle.textContent = "Could not read the annotations";
    $amsg.textContent = msg; $amsg.className = "wmsg bad";
  };
  function aItemRow(it, member, setHidden){
    // A member of a TICKED set is greyed and disabled, but its own tick is
    // KEPT and still sent — so unticking the set brings back exactly the
    // members that were showing before it was ticked.
    var dis = member && setHidden;
    return "<div class='wrow"+(member?" member":"")+(dis?" dis":"")+"'>"+
      "<label><input type='checkbox' data-akey='"+esc(it.key)+"'"+
      (aPicks[it.key]?" checked":"")+(dis?" disabled":"")+">"+
      "<span class='kind'>"+AKIND[it.kind]+"</span>"+
      "<span class='txt' title='"+esc(it.full)+"'>"+esc(it.text)+"</span>"+
      (it.tag && it.tag!=="Untagged" ? "<span class='cnt'>"+esc(it.tag)+"</span>" : "")+
      "</label>"+
      (dis ? "<span class='with'>hidden with the set</span>" : "")+
      "<button class='wfind' data-afind='"+esc(it.key)+
      "' title='Select this callout in the model so you can see it'>SHOW ME</button></div>";
  }
  function annotsDraw(){
    var h = "<div class='wroom'><div class='wrh'>Annotation sets"+
      "<span class='links'><a data-aall='sets'>all</a> &middot; "+
      "<a data-anone='sets'>none</a></span></div>";
    h += annotsSets.length ? annotsSets.map(function(u){
      var on = !!aPicks[u.key], ex = !!aExp[u.key];
      var r = "<div class='wrow'><button class='aexp' data-aexp='"+esc(u.key)+
        "' title='Show the callouts in this set'>"+(ex?"&#9660;":"&#9654;")+"</button>"+
        "<label><input type='checkbox' data-akey='"+esc(u.key)+"'"+(on?" checked":"")+">"+
        "<span class='txt'>"+esc(u.name)+"</span>"+
        "<span class='cnt'>"+esc(u.cnt)+"</span></label>"+
        "<button class='wfind' data-afind='"+esc(u.key)+
        "' title='Select everything on this set so you can see it'>SHOW ME</button></div>";
      if(ex) r += u.members.length
        ? u.members.map(function(m){ return aItemRow(m, true, on); }).join("")
        : "<div class='wrow member'><span class='cnt'>nothing on this tag</span></div>";
      return r;
    }).join("") : "<div class='ahint'>No WR-Dims / WR-Notes sets in this model yet. "+
        "Everything is listed below, one callout at a time.</div>";
    h += "</div><div class='wroom'><div class='wrh'>Not in a set — tick one by one"+
      "<span class='links'><a data-aall='loose'>all</a> &middot; "+
      "<a data-anone='loose'>none</a></span></div>";
    h += annotsLoose.length
      ? annotsLoose.map(function(it){ return aItemRow(it, false, false); }).join("")
      : "<div class='ahint'>Nothing loose — every callout in this model is in a set.</div>";
    h += "<div class='ahint'>SketchUp will not hide Untagged as a group, so these are "+
      "hidden one at a time (or all at once with the link above). Want them as a "+
      "reusable set? Select them in the model and move them into one below. "+
      "Callouts nested deeper than two containers are not listed — a set hides "+
      "those too, because tag visibility has no depth limit.</div></div>";
    h += "<div class='amove'><div class='wrh'>Move selection into a set — optional, for every scene</div>"+
      "<select id='aset'>"+annotsSets.map(function(u){
        return "<option value='"+esc(u.name)+"'>"+esc(u.name)+"</option>"; }).join("")+
      "<option value='__new'>New set&hellip;</option></select>"+
      "<span class='prefix' id='aprefix'>WR-Notes-</span>"+
      "<input id='anew' placeholder='Plan'>"+
      "<button id='amovego'>MOVE SELECTION INTO SET</button>"+
      "<span class='note'>Re-tags the selected text, dimensions and 3D labels. "+
      "Membership is for every scene; anything that is not an annotation is "+
      "refused by name.</span></div>";
    $abody.innerHTML = h;
    annotsWire();
  }
  function annotsWire(){
    Array.prototype.forEach.call($abody.querySelectorAll("input[data-akey]"), function(el){
      el.addEventListener("change", function(){
        aPicks[el.getAttribute("data-akey")] = el.checked;
        if(el.getAttribute("data-akey").charAt(0)==="t") annotsDraw();
        annotsPreview();
      });
    });
    Array.prototype.forEach.call($abody.querySelectorAll("[data-aexp]"), function(el){
      el.addEventListener("click", function(){
        var k = el.getAttribute("data-aexp"); aExp[k] = !aExp[k]; annotsDraw();
      });
    });
    Array.prototype.forEach.call($abody.querySelectorAll("[data-afind]"), function(el){
      el.addEventListener("click", function(){
        if(window.sketchup && sketchup.annotsreveal)
          sketchup.annotsreveal(el.getAttribute("data-afind"));
      });
    });
    Array.prototype.forEach.call($abody.querySelectorAll("[data-aall],[data-anone]"), function(el){
      el.addEventListener("click", function(){
        var grp = el.getAttribute("data-aall") || el.getAttribute("data-anone"),
            on = el.hasAttribute("data-aall");
        (grp==="sets" ? annotsSets : annotsLoose).forEach(function(u){ aPicks[u.key] = on; });
        annotsDraw();
        annotsPreview();
        $amsg.className = "wmsg";
        $amsg.textContent = (on ? "Every " : "No ") + (grp==="sets" ? "set" : "loose callout") +
          " ticked. Apply to save that into this scene.";
      });
    });
    var sel = g("aset");
    if(sel) sel.addEventListener("change", function(){
      var isNew = sel.value === "__new";
      g("anew").className = isNew ? "show" : "";
      g("aprefix").className = "prefix" + (isNew ? " show" : "");
      if(isNew) g("anew").focus();
    });
    var mv = g("amovego");
    if(mv) mv.addEventListener("click", function(){
      var v = g("aset").value;
      var name = v === "__new" ? g("anew").value : v;
      if(window.sketchup && sketchup.annotsmove)
        sketchup.annotsmove(JSON.stringify({ name: name }));
    });
  }
  window.annotsShow = function (d) {
    annotsSets = d.sets || []; annotsLoose = d.loose || [];
    aPicks = {};
    annotsSets.forEach(function(u){
      if(u.hidden) aPicks[u.key] = true;
      (u.members||[]).forEach(function(m){ if(m.hidden) aPicks[m.key] = true; });
    });
    annotsLoose.forEach(function(it){ if(it.hidden) aPicks[it.key] = true; });
    $atitle.textContent = "Notes & dimensions hidden in “" + d.scene + "”";
    annotsDraw();
    $amsg.className = "wmsg" + (d.warn ? " bad" : "");
    $amsg.textContent = d.warn
      ? "This scene does not save hidden tags or objects, so callouts will NOT come "
        + "back on it. Apply turns that on for you."
      : "Ticked = hidden when this scene exports. Sets hide as one; loose callouts "
        + "hide one by one — both are saved into this scene only.";
  };
  window.annotsPicked = function (r) {
    var keys = r.keys || [], n = 0;
    // ADDS to what is already ticked — picking a second callout must not
    // silently untick the first.
    keys.forEach(function(k){ aPicks[k] = true; n++; });
    annotsDraw();
    if(n) annotsPreview();
    $amsg.className = "wmsg" + (n ? " ok" : " bad");
    $amsg.textContent = n
      ? n + " callout(s) ticked from your selection." +
        (r.hint ? " All of them are on " + r.hint + " — tick the set to hide all of them." : "")
      : "Nothing in your selection is a note, a dimension or a 3D label. Click the "
        + "callout itself in the model, then press this again.";
  };
  window.annotsNote = function (r) {
    $amsg.className = "wmsg" + (r.ok ? "" : " bad");
    $amsg.textContent = r.msg;
  };
  window.annotsMoved = function (r) {
    if(r.sets) annotsSets = r.sets;
    if(r.loose) annotsLoose = r.loose;
    annotsDraw();
    $amsg.className = "wmsg" + (r.ok ? " ok" : " bad");
    $amsg.textContent = r.msg;
  };
  window.annotsDone = function (r) {
    $amsg.textContent = r.msg;
    $amsg.className = "wmsg" + (r.ok ? " ok" : " bad");
    if(r.ok) setTimeout(annotsClose, 900);
  };
  $apick.addEventListener("click", function(){
    if(window.sketchup && sketchup.annotspick) sketchup.annotspick("");
  });
  function annotsPreview(){
    if(running || !annotsN) return;
    if(window.sketchup && sketchup.annotspreview)
      sketchup.annotspreview(JSON.stringify({ n: annotsN, picks: annotsCollect() }));
  }
  function annotsCollect(){
    // EVERY row is sent, not only the ticked ones, so unticking reliably shows
    // again — the walls rule. A member row behind a collapsed set is not in the
    // DOM, so its remembered pick is sent from the state instead of being lost.
    var picks = {};
    annotsSets.forEach(function(u){
      picks[u.key] = !!aPicks[u.key];
      (u.members||[]).forEach(function(m){ picks[m.key] = !!aPicks[m.key]; });
    });
    annotsLoose.forEach(function(it){ picks[it.key] = !!aPicks[it.key]; });
    return picks;
  }
  $aapply.addEventListener("click", function(){
    if(window.sketchup && sketchup.annotsapply)
      sketchup.annotsapply(JSON.stringify({ n: annotsN, picks: annotsCollect() }));
  });
  $aapplyall.addEventListener("click", function(){
    if(window.sketchup && sketchup.annotsapplyall)
      sketchup.annotsapplyall(JSON.stringify({ n: annotsN, ns: shownNs(), picks: annotsCollect() }));
  });
  $acancel.addEventListener("click", annotsClose);
  $awrap.addEventListener("click", function(e){ if(e.target === $awrap) annotsClose(); });

  // ---- per-scene SUN (1.27.0) ---------------------------------------------
  // The third sibling of the walls and annotations pickers. The sun he aims
  // with Light it from here lives in the model's LIVE shadow settings; every
  // scene saves its own and puts it back when clicked, so nothing he aimed
  // ever stuck. Ruby reads the live sun BEFORE selecting the scene (the
  // select is what overwrites it); this card shows both and saves either.
  var sunN = 0;
  function sunFmt(s){
    if(!s) return "<i>not saved</i>";
    return "bearing <b>"+(s.az==null?"?":s.az)+"&deg;</b>, height <b>"+(s.el==null?"?":s.el)+"&deg;</b>"
      + " <span class='cnt'>(north "+(s.north==null?"?":s.north)+"&deg;, "+esc(s.time)+")</span>";
  }
  function sunOpen(n){
    sunN = n;
    allScope($sapplyall);
    $sapplyall.title = $sapplyall.title.replace("The same ticks into", "This scene's saved sun into");
    $stitle.textContent = "Loading scene " + n + "…";
    $sbody.innerHTML = "";
    $smsg.textContent = ""; $smsg.className = "wmsg";
    $swrap.style.display = "flex";
    if(window.sketchup && sketchup.sunopen) sketchup.sunopen(String(n));
  }
  function sunClose(){
    $swrap.style.display = "none";
    sunN = 0;
    if(window.sketchup && sketchup.sunclose) sketchup.sunclose("");
  }
  function sunWarn(warn, off){
    $sfix.style.display = off ? "" : "none";
    $sfix.textContent = "FIX " + off + " SCENE" + (off===1?"":"S");
    $smsg.className = "wmsg" + (warn ? " bad" : "");
    $smsg.textContent = warn
      ? "This scene does not save shadow settings, so no sun comes back when it is clicked. "
        + "Saving turns that on for this scene; FIX SCENES turns it on for every scene."
      : "Aim writes the sun the way Light it from here does — from this scene's camera — "
        + "and saves it into this scene only. Nothing here touches V-Ray's sun intensity.";
  }
  window.sunFail = function (msg) {
    $stitle.textContent = "Could not read the sun";
    $smsg.textContent = msg; $smsg.className = "wmsg bad";
  };
  window.sunShow = function (d) {
    $stitle.textContent = "Sun for “" + d.scene + "”";
    $sbody.innerHTML =
      "<div class='srow'><span class='slab'>Saved in this scene</span><span class='sval' id='ssaved'>"+sunFmt(d.saved)+"</span></div>"
      + "<div class='srow'><span class='slab'>In the viewport when this opened</span><span class='sval'>"+sunFmt(d.live)+"</span>"
      + (d.live ? "<button class='wbtn' id='ssave' title='The sun you set with Light it from here, saved into this scene'>SAVE THAT INTO THIS SCENE</button>" : "")
      + "</div>"
      + "<div class='sctl'><span class='slab'>Aim from the camera</span>"
      + "<label>offset <input type='number' id='soff' step='5' value='"+esc(d.offset)+"'>&deg; to one side</label>"
      + "<label><input type='checkbox' id='smatch' checked> match the camera's height</label>"
      + "<label>or height <input type='number' id='selev' step='5' min='5' max='85' value='"+esc(d.elev)+"'>&deg;</label>"
      + "</div>";
    var sv = g("ssave");
    if(sv) sv.addEventListener("click", function(){
      if(window.sketchup && sketchup.sunsave) sketchup.sunsave(String(sunN));
    });
    var sm = g("smatch"), se = g("selev");
    if(sm && se){ se.disabled = sm.checked; sm.addEventListener("change", function(){ se.disabled = sm.checked; }); }
    sunWarn(d.warn, d.off);
  };
  window.sunDone = function (r) {
    $smsg.textContent = r.msg;
    $smsg.className = "wmsg" + (r.ok ? " ok" : " bad");
    var ss = g("ssaved"); if(ss && r.saved !== undefined) ss.innerHTML = sunFmt(r.saved);
    if(r.warn === false) { $smsg.className = "wmsg" + (r.ok ? " ok" : " bad"); }
  };
  window.sunNote = function (r) {
    $smsg.textContent = r.msg;
    $smsg.className = "wmsg" + (r.ok ? " ok" : " bad");
    $sfix.style.display = r.off ? "" : "none";
    $sfix.textContent = "FIX " + r.off + " SCENE" + (r.off===1?"":"S");
  };
  $saim.addEventListener("click", function(){
    var sm = g("smatch"), so = g("soff"), se = g("selev");
    if(window.sketchup && sketchup.sunaim)
      sketchup.sunaim(JSON.stringify({ n: sunN, offset: so ? +so.value : 30,
                                       matchcam: sm ? sm.checked : true, elev: se ? +se.value : 35 }));
  });
  $sapplyall.addEventListener("click", function(){
    if(window.sketchup && sketchup.sunapplyall)
      sketchup.sunapplyall(JSON.stringify({ n: sunN, ns: shownNs() }));
  });
  $sfix.addEventListener("click", function(){
    if(window.sketchup && sketchup.sunfix) sketchup.sunfix(String(sunN));
  });
  $scancel.addEventListener("click", sunClose);
  $swrap.addEventListener("click", function(e){ if(e.target === $swrap) sunClose(); });

  window.applyState = function (st) { ST = st; drawMats(); draw(); };
  window.setDir = function (d) { g("dir").value = d; };

  // ---- run feedback, driven from Ruby ----
  window.logLine = function (text, cls) {
    g("logsect").style.display="";
    $log.innerHTML += "<span class='"+(cls||"dim")+"'>"+esc(text)+"</span><br>";
    $log.scrollTop = 1e6;
  };
  window.setProgress = function (pct, msg) {
    $pfill.style.width = pct+"%"; $pmsg.textContent = msg;
  };
  window.runStarted = function () {
    running = true; $log.innerHTML="";
    // Reveal the log AND open it -- a run someone minimised the log for still
    // needs to show its first line, or a failure scrolls past unseen.
    var ls = g("logsect"); ls.style.display=""; ls.classList.add("open");
    var lt = ls.querySelector(".tri"); if(lt) lt.innerHTML="&#9660;";
    var lm = ls.querySelector(".mini"); if(lm){ lm.innerHTML="&minus;"; lm.title="Minimise"; }
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
  // EVERY section collapses, not just the materials one. A short SketchUp
  // window could not reach Export package because every block was fixed-height
  // and the bar was pushed off the bottom; now the scene list, the details and
  // the log all give their height back when minimised, and the two that should
  // absorb the leftover (.grow) do.
  Array.prototype.forEach.call(document.querySelectorAll(".sect > .hd"), function(hd){
    hd.addEventListener("click", function(){
      var s = hd.parentNode, open = s.classList.toggle("open");
      var t = s.querySelector(".tri"); if(t) t.innerHTML = open?"&#9660;":"&#9654;";
      var m = s.querySelector(".mini");
      if(m){ m.innerHTML = open?"&minus;":"&plus;"; m.title = open?"Minimise":"Expand"; }
    });
  });
  g("rescan").addEventListener("click", function(){
    if(running) return;
    // The scene names this window is showing go up with the request, so the
    // log can name what the rescan found rather than just "refreshed".
    if(window.sketchup && sketchup.rescan)
      sketchup.rescan(JSON.stringify(ST.rows.map(function(r){ return r.scene; })));
  });
  g("undolast").addEventListener("click", function(){
    if(running) return;
    if(window.sketchup && sketchup.undolast) sketchup.undolast("");
  });
  g("helpb").addEventListener("click", function(){
    document.body.classList.toggle("showhelp");
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
        annot: g("annot").value,
        transp: g("transp").checked
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
