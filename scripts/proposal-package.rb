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
  # The per-scene wall hiding lives here now, next to MODE, because that is
  # where the operator is when they decide a shot needs the back wall gone.
  # wr-scene-walls.rb stays a standalone tool as well; this reuses its
  # inventory/apply so there is ONE mechanism, not two that can disagree.
  load File.join(File.dirname(__FILE__), 'wr-scene-walls.rb')
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
    'never means nothing was hidden; [] means that.'
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
      row['annotation_tags_shown'] = p[:shown]
      row['annotation_note'] = p[:shown_note] if p[:shown_note]
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
    missing = []
    ANNOT_TAGS.each do |n|
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
  rescue StandardError => e
    # TELL THE TRUTH ABOUT WHICH WAY IT FAILED. The old message said only
    # 'annotation may be visible in this image' -- the opposite of the actual
    # damage, which was tags left hidden in the MODEL. Both halves are real
    # and both are now stated: the tags already hidden ARE recorded and WILL
    # be restored by finish, and the ones never reached are still showing, so
    # the image may carry construction annotation after all.
    done = (@annot_saved || {}).size
    left = ANNOT_TAGS.size - done
    log(dlg, "CLIENT-SAFE FAILED PARTWAY for #{file}: #{e.class}: #{e.message}", 'bad')
    log(dlg, "        #{done} tag(s) were hidden and ARE recorded - finish " \
             'will put them back. ' \
             "#{left} tag(s) were not reached and are still visible, so " \
             'construction annotation may be in this image. Check the image ' \
             'before sending, and check the tags in the model after the batch.', 'bad')
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

    ev = ev_of_camera(read[['/CameraPhysical', :f_number]],
                      read[['/CameraPhysical', :shutter_speed]])
    log(dlg, format('        the camera as configured is EV %.2f%s', ev || 0.0,
                    ev.nil? ? ' (could not be derived)' : ''), 'dim')

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

  def self.unit_image(model, dlg, p)
    plan = [{ :page => p[:page], :n => p[:n], :base => p[:base] }]
    # D4: an EXPLICIT height, so an image row and a render row of the same
    # scene come out the same shape. Before 1.9.3 only width was passed and
    # export-scenes.rb derived the height from the SketchUp window.
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
    hide.concat(ANNOT_TAGS) if @client_safe
    cfg  = { 'dir' => @cfg['dir'], 'width' => @cfg['width'],
             'height' => @cfg['height'], 'bg' => 'Opaque', 'over' => 'Yes',
             'hide_tags' => hide }
    # RECORD WHAT IS HIDDEN ON THIS SCENE BEFORE EXPORTING IT. Selecting the
    # page applies its saved per-entity hidden state — the per-scene wall
    # hiding (wr-scene-walls.rb, verified live 31 Aug 2026) — and
    # export_pages selects the same page again, so this early switch changes
    # nothing about the pixels. Transitions are off for the whole batch
    # (start_run), so it is instant.
    begin
      model.pages.selected_page = p[:page] if p[:page]
      p[:groups_hidden] = collect_hidden_groups(model)
    rescue StandardError
      p[:groups_hidden] = nil
    end
    begin
      annot_push(model, dlg, p[:file])
      present = hide.select { |n| model.layers[n] }
      log(dlg, "re-hiding after the scene switch: #{present.join(', ')}", 'dim') unless present.empty?
      x = WR_ExportScenes.export_pages(model, plan, cfg)
    ensure
      annot_pop(model, dlg)
    end
    if x[:written] > 0
      @results << { :file => p[:file], :lane => 'image', :status => 'ok',
                    # :width/:height feed manifest.json — the size the export
                    # ACTUALLY used, not the size that was asked for.
                    :groups_hidden => p[:groups_hidden],
                    :width => x[:width].to_i, :height => x[:height].to_i,
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
    # Same per-scene hidden record the image lane keeps — read here, right
    # after the scene switch applied its saved hidden state, so the manifest
    # says which walls this render is missing BY DESIGN.
    p[:groups_hidden] = collect_hidden_groups(model)
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
    ev_of_camera((pl[:f_number] rescue nil), (pl[:shutter_speed] rescue nil))
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
  # AND :apply_color_corrections IS NOT THE FIX. MEASURED 1 Sep 2026: with it
  # in SAVE_OPTS the retry file came out byte-different but luminance
  # IDENTICAL (mean 0.1585, max 0.691). It bakes only the VFB's correction
  # LAYERS (exposure / curve / LUT — all at default on this rig), not the
  # display sRGB transform the VFB window applies on top. It stays in
  # SAVE_OPTS so that any correction Benton DOES dial into the VFB reaches
  # the file; the display transform is baked deterministically by srgb_bake
  # below (wr-png-srgb.rb), which also stamps the sRGB + gAMA chunks so the
  # file finally declares its colour space.
  #
  # The other two options stay exactly as they were: :skip_alpha kills the
  # .Alpha.png sidecar, :no_alpha gives an opaque PNG.
  SAVE_OPTS = { :skip_alpha => true, :no_alpha => true,
                :apply_color_corrections => true }.freeze

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
    begin
      ok = @rend.save_vfb_image(p[:path], SAVE_OPTS)
    rescue Exception => e
      # An option key this build rejects raises. :apply_color_corrections is
      # the one that could be missing, and losing the whole batch over it
      # would be worse than a dark image, so drop it, SAY SO LOUDLY, and
      # save. The row still succeeds; it is just wrong in the way it used to
      # be wrong, and now it is named instead of silent.
      begin
        ok = @rend.save_vfb_image(p[:path], :skip_alpha => true, :no_alpha => true)
        @colour_baked = false
        log(dlg, "        #{p[:file]}  :apply_color_corrections was REJECTED by " \
                 "this V-Ray build (#{e.class}) - saved the RAW buffer instead. " \
                 'Any VFB correction layers are NOT in this file; the sRGB ' \
                 'post-encode below still runs and fixes the darkness.', 'bad')
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
      @results << { :file => p[:file], :lane => 'render', :status => 'ok',
                    # The size written into /SettingsOutput and read back by
                    # the size gate — det already names where it came from.
                    :groups_hidden => p[:groups_hidden],
                    :width => @cfg['width'].to_i, :height => @cfg['height'].to_i,
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
    present = ANNOT_TAGS.select { |n| (model.layers[n] rescue nil) }
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
      shown, note = shown_annot_tags(page_hidden_tags(page), use_h, present,
                                     @client_safe)
      { :file => p[:file], :n => p[:n], :lane => p[:lane], :scene => scene,
        :shown => shown, :shown_note => note }
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
             'annotations_hidden_in_images' => (@client_safe ? true : false),
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
        (mat[:applied] || mat[:reverted] || {}).each do |slot, n|
          log(d, "  #{slot}: #{n} surface(s)", 'dim')
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

    d.add_action_callback('activate') do |_c, n|
      next if busy?(d, 'activate')
      begin
        pg = model.pages.to_a[n.to_i - 1]
        model.pages.selected_page = pg if pg
      rescue StandardError => e
        puts "  could not activate scene #{n}: #{e.class}: #{e.message}"
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
        @walls_return ||= model.pages.selected_page
        model.pages.selected_page = pg
        units = WR_SceneWalls.inventory(model).map do |u|
          { 'key' => u[:key], 'room' => u[:room], 'wall' => u[:wall],
            'side' => u[:side].to_s, 'hidden' => u[:hidden] ? true : false,
            'mixed' => u[:mixed] ? true : false }
        end
        warn = WR_SceneWalls.pages_not_saving_hidden(model).include?(pg.name.to_s)
        d.execute_script('wallsShow(' + { 'n' => n.to_i, 'scene' => pg.name.to_s,
                                          'units' => units, 'warn' => warn }.to_json + ')')
      rescue StandardError => e
        d.execute_script('wallsFail(' + "#{e.class}: #{e.message}".to_json + ')')
      end
    end

    d.add_action_callback('wallsapply') do |_c, payload|
      next if busy?(d, 'wallsapply')
      begin
        req   = JSON.parse(payload.to_s)
        picks = {}
        (req['picks'] || {}).each { |k, v| picks[k] = v ? true : false }
        ok, msg = WR_SceneWalls.apply(model, picks)
        d.execute_script('wallsDone(' + { 'ok' => ok, 'msg' => msg }.to_json + ')')
        log(d, msg, ok ? 'dim' : 'bad')
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
      <th>#</th><th>SCENE</th><th>MODE</th><th>WALLS</th><th>FILE IT WILL WRITE</th><th></th>
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
      <button id="wpick" title="Select the wall in the model, then press this">USE MY SELECTION</button>
      <span class="wgap"></span>
      <button id="wapply" class="prim">APPLY TO THIS SCENE</button>
      <button id="wcancel">CANCEL</button>
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
      $wmsg=g("wmsg"), $wapply=g("wapply"), $wcancel=g("wcancel"),
      $wpick=g("wpick");

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
        "<td><button class='wbtn' data-walls='"+r.n+"' title='Choose which whole walls this scene hides'>Hide walls</button></td>"+
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
    Array.prototype.forEach.call($b.querySelectorAll("[data-walls]"), function(el){
      el.addEventListener("click", function(e){
        e.stopPropagation();
        if(running) return;
        wallsOpen(+el.getAttribute("data-walls"));
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
  var wallsN = 0, wallsUnits = [], wallsPicks = {};
  function wallsOpen(n){
    wallsN = n; wallsPicks = {};
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
    $wtitle.textContent = "Walls hidden in “" + d.scene + "”";
    if(!wallsUnits.length){
      $wbody.innerHTML = "<p class='wnone'>No named walls in this model. The picker "
        + "lists a wall by its name (“Wall 3”). A room drawn by hand or by an "
        + "older script has unnamed wall groups — run <b>Name walls for the scene "
        + "picker</b> once, then come back.</p>";
      return;
    }
    var byRoom = {}, order = [];
    wallsUnits.forEach(function(u){
      if(!byRoom[u.room]){ byRoom[u.room] = []; order.push(u.room); }
      byRoom[u.room].push(u);
    });
    $wbody.innerHTML = order.map(function(room){
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
    // Ticked = hidden in this scene. Every wall is sent on Apply, not just the
    // ones touched, so a box UNticked here reliably SHOWS that wall again.
    Array.prototype.forEach.call($wbody.querySelectorAll("input[data-key]"), function(el){
      el.addEventListener("change", function(){
        wallsPicks[el.getAttribute("data-key")] = el.checked;
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
      : "Ticked = hidden when this scene exports.";
  };
  window.wallsPicked = function (r) {
    var keys = r.keys || {}, n = 0;
    // ADDS to what is already ticked — picking a second wall must not
    // silently untick the first.
    Array.prototype.forEach.call($wbody.querySelectorAll("input[data-key]"), function(el){
      if(keys.indexOf(el.getAttribute("data-key")) >= 0){ el.checked = true; n++; }
    });
    $wmsg.className = "wmsg" + (n ? " ok" : " bad");
    $wmsg.textContent = n
      ? n + " wall(s) ticked from your selection. Apply to save them into this scene."
      : "Nothing in your selection matched a named wall. Click the wall itself in "
        + "the model — or the room, or its Walls group — then press this again.";
  };
  window.wallsNote = function (r) {
    $wmsg.className = "wmsg" + (r.ok ? "" : " bad");
    $wmsg.textContent = r.msg;
  };
  $wpick.addEventListener("click", function(){
    if(window.sketchup && sketchup.wallspick) sketchup.wallspick("");
  });
  window.wallsDone = function (r) {
    $wmsg.textContent = r.msg;
    $wmsg.className = "wmsg" + (r.ok ? " ok" : " bad");
    if(r.ok) setTimeout(wallsClose, 900);
  };
  $wapply.addEventListener("click", function(){
    var picks = {};
    Array.prototype.forEach.call($wbody.querySelectorAll("input[data-key]"), function(el){
      picks[el.getAttribute("data-key")] = el.checked;
    });
    if(window.sketchup && sketchup.wallsapply)
      sketchup.wallsapply(JSON.stringify({ n: wallsN, picks: picks }));
  });
  $wcancel.addEventListener("click", wallsClose);
  $wrap.addEventListener("click", function(e){ if(e.target === $wrap) wallsClose(); });

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
