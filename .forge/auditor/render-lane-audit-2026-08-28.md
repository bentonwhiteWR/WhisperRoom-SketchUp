# Render-lane audit — 2026-08-28 (plugin 1.7.9, UNRUN)

Auditor pass over `scripts/proposal-package.rb` and its dependency chain
(`wr-mode.rb`, `wr-materials-swap.rb`, `wr-shading.rb`, `export-scenes.rb`,
`wr-preflight.rb`). The two defects fixed at 1.7.9 (empty frames / wrong view) are
taken as fixed and are NOT re-derived here. READ-ONLY: no code was changed.

Provenance tags: **observed** (read/ran it myself), **derived**, **reported**, **assumed**.
Nothing here was executed in SketchUp — no SketchUp, no ruby.exe on this machine.
`python scripts/rbparse.py`: 56 files parse (observed, baseline only).

## Headline

1. The cold-session mystery has a **documented** answer-candidate:
   `VRay::Command.render_production(context:)` — the on-disk YARD docs say the
   `VRay::Command` module "emulates the functionality exposed in the V-Ray for
   SketchUp toolbars and menus", i.e. the exact hand action that woke the session.
   Second candidate, same docs: `renderer.start(sync: true)` — `start` takes an
   options hash and `:sync` is documented as "Wait for renderer to start". The
   current code calls bare `rend.start`. (reported — documented, never called)
2. The documented state vocabulary is **ten states, not five** — and one of them,
   `:fatalError`, is classified as RUNNING by 1.7.9's classifier. A licence or
   engine failure would set the latch, log "render started", and burn the full
   30-minute RENDER_TIMEOUT_S per row: 2.5 hours on a 5-row batch. (derived from
   observed doc text + observed code)
3. `save_vfb_image` is now **documented**: `(path, options) => Boolean`, format
   from the extension, and options `:skip_alpha` (no `.Alpha.png` sidecar),
   `:no_alpha` (opaque RGB — kills the transparent-backdrop problem at the source),
   `:apply_color_corrections`. The tool ignores the Boolean and passes no options.

===DETAIL===

## Doc source (observed on disk, 28 Aug 2026)

`C:\Program Files\Chaos\V-Ray\V-Ray for SketchUp\extension\documentation\` —
YARD set generated 29 Apr 2026 (newer than the 1 Dec 2025 set
`reference/vray-ruby-api.md` describes; same structure). Pages read:
`VRay/Command.html`, `VRay/VRayRenderer.html`, `VRay/Context.html`,
`VRay/VRayInit.html`, `VRay/Scene.html`, and the overview
`file.V-Ray for SketchUp Ruby API.html`.

Key sentence from the overview (observed, verbatim): *"While working on a SketchUp
model, any changes made that involve V-Ray related functionality are kept in the
active Scene. **Only when a render/export is started this state is transferred to
the active VRayRenderer automatically.**"* — consistent with a renderer that has
never been fed a scene behaving differently from one that has.

---

## F1 — HIGH — `:fatalError` reads as RUNNING and burns 30 minutes per row

**Where:** `classify_render` + `IDLE_STATE = /\Aidle/i`, `proposal-package.rb`
lines 268–326; timeout branches lines 653–669.

**Evidence (observed doc text):** `VRayRenderer#state` documents TEN values:
`:fatalError, :idleInitialized, :idleStopped, :idleError, :idleFrameDone,
:idleDone, :preparing, :rendering, :renderingPaused, :renderingAwaitingChanges`.
The live watch on 28 Aug saw five of these; the classifier was built from the five.

**Derived consequence:** `:fatalError` does not match `/\Aidle/i`, so
`classify_render` returns `:running`. First poll: the latch sets and the log says
"render started" — false. The row then sits "running" until
`RENDER_TIMEOUT_S = 30*60`. Five rows hitting a licence error (this machine's
licence state is already suspect — the DR pair raises "Incorrect DR version")
= 2.5 hours of nothing, each row mislabeled "no :idleDone after 30 minutes".

Also in the unobserved set:
- `:idleError` → classified `:idle`; fails correctly but with the misleading
  message "stopped or cancelled" (or "never started").
- `:renderingPaused` / `:renderingAwaitingChanges` → `:running` — arguably right,
  but a paused render also burns the 30-minute timeout with no hint it is paused.

**Recommended fix (not applied):** classify any state matching `/error/i`
(`:fatalError`, `:idleError`) as a new `:failed` verdict → fail the row by name
immediately, naming the raw state. Keep `:renderingPaused` as running but log the
raw state when it changes. Add the ten documented states to
`rbtest-proposal.py`'s classifier cases.

**5-minute check:** none can force `:fatalError` live cheaply. Instead:
open `VRay/VRayRenderer.html#state-instance_method` and read the list (1 min),
then in the Ruby console run
`WR_ProposalPackage.classify_render(:fatalError, false, false)` → returns
`:running` today. That is the bug demonstrated without a render.

---

## F2 — HIGH — the cold-session no-op `start`: two documented candidates

**The observation being explained (reported from the orchestrator/Benton):** on a
fresh session, before any interactive render, `renderer.start` returned without
raising and rendered nothing (five empty frames, 3.17 s spacing, under pre-1.7.9
code); after ONE hand render from the toolbar, the identical batch code engaged.
The hand render's console printed "Initializing Renderer" / "Exporting model" /
"Starting render" as distinct first-time steps.

**With 1.7.9 as designed (derived):** each cold row now fails by name at
`START_WINDOW_S = 30` s — loud, nothing saved — but a cold batch still produces
zero renders and Benton still has to hand-render first. ~30 s × N rows wasted,
plus the whole batch.

**Documented candidates (both from the on-disk YARD docs; NEITHER has ever been
called — reported, not verified):**

1. **`VRay::Command.render_production(context: VRay::Context.active)`** —
   `VRay/Command.html`: *"The Command module contains a series of methods that are
   meant to emulate the functionality exposed in the V-Ray for SketchUp toolbars
   and menus"*; `render_production` — *"Launches a production render"*. This is,
   by the docs' own framing, the same code path as the toolbar button that woke
   the session. The module also documents `stop_current_render(context:)`.
   Open unknowns: does it show the Asset Editor/VFB, does it drive the same
   `renderer.state` machine the poll loop reads (plausible — same context, same
   renderer), does it respect the active view the way `renderer.start` does.
2. **`renderer.start(sync: true)`** — `VRay/VRayRenderer.html#start`: *"# start
   (options) => nil — Starts a render"*, example `renderer.start(sync: true,
   sequence: false)`, `:sync` — *"Wait for renderer to start"*. If the cold no-op
   is an async hand-off that dies before the engine initialises, a synchronous
   start would either start it or fail in-band. Cheap to try: one keyword on the
   existing call.

There is no documented "initialise the renderer" call. `VRay::VRayInit` documents
only `#shutdown` (observed doc text) — evidence an init lifecycle object exists,
but no public init entry point. The overview's "state is transferred to the
renderer only when a render/export is started" sentence fits the hypothesis that
the toolbar path performs a first-time engine initialisation the bare Ruby
`start` skips — but WHY bare `start` no-ops cold remains **unexplained**; the two
candidates above are the documented things to try, in that order of promise.

**5-minute check (fresh SketchUp session, nothing rendered yet):** Ruby console:
`VRay::Context.active.renderer.start(sync: true)` then poll
`VRay::Context.active.renderer.state` a few times — does it reach `:preparing`?
If not, restart SketchUp and try `VRay::Command.render_production` and watch the
same. Whichever engages cold is the fix's foundation. (Each attempt consumes one
real render — use a small test model.)

---

## F3 — MED-HIGH — mode restore is silently skipped on a never-toggled model

**Where:** `finish`, `proposal-package.rb` line 948:
`if %w[draft render].include?(@saved_mode) && @mode_now != @saved_mode`.

**Observed in code:** `@saved_mode = WR_Mode.current(model)` (line 554), and
`WR_Mode.current` returns the string `'unknown (never toggled)'` when the model
has no WR_Mode dictionary (`wr-mode.rb` line 311). That string is not in
`%w[draft render]`, so `finish` **skips the mode restore with no message** — on
the first-ever proposal-package run on a fresh client model, the batch flips the
model into render mode (materials swapped, dim tags off) and leaves it there
silently. The file calls a leaked mutation its worst possible failure; this one
is by-construction on every first use.

Mitigation that exists: the Toggle button reads true state from the model and one
press puts it back — but nothing tells Benton to press it.

**Recommended fix:** when `@saved_mode` is not draft/render, restore to `'draft'`
(the shop's resting state) or at minimum add a loud log/summary line: "model was
never mode-toggled — leaving it in RENDER mode; press Toggle to go back".

**5-minute check:** open any scratch model that has never seen the toggle, mark
one scene Image, run the package, then look at the model: still in draft
materials/tags? Console: `WR_Mode.current(Sketchup.active_model)`.

---

## F4 — MED — `save_vfb_image`: Boolean return ignored; documented options answer
the sidecar and the alpha questions

**Docs (observed):** `save_vfb_image(path, options) => Boolean` — *"Save the
current image buffer as if you used the save button on the VFB. Format is deduced
from the filename extension."* Options include:
- `:skip_alpha` — *"Do not write the alpha channel into a separate file"* →
  this is the `.Alpha.png` sidecar switch. The observed sidecar is the DEFAULT.
- `:no_alpha` — *"Do not write the alpha channel together with the color data"* →
  an opaque PNG. Since the backdrop is already present in the RGB under the
  transparent alpha (observed by the caller), `no_alpha: true` yields the
  finished opaque render directly — no flatten step, no risk of a transparent
  PNG landing in a client pack.
- `:apply_color_corrections` — *"Bake the VFB corrections to the output file"*.
  Today's one-arg call presumably does NOT bake them (unverified which default
  applies) — if Benton tunes exposure in the VFB, the saved file may not match
  what he saw. Worth pinning explicitly once the live behaviour is confirmed.

**Defects in the current call (`save_frame`, lines 909–927):**
1. The Boolean return is discarded; success is judged by `File.exist?`. Under the
   'Overwrite' policy the target already exists — a failed save (locked file,
   OneDrive sync, wrong extension) returns false, `File.exist?` is still true,
   and the row is reported **ok with the stale previous image**. A caption then
   gets written against the wrong render. (derived)
2. Nothing plans, overwrites, skips, or cleans the `.Alpha.png` sidecar: the
   collision map and the Ask/Overwrite/Skip policy see only `<name>.png`, so
   stale sidecars accumulate in the client folder (already observed once).

**Recommended fix:** call
`@rend.save_vfb_image(p[:path], skip_alpha: true, no_alpha: true)` (options are
documented but UNRUN — a rejected option key would surface in the existing rescue
as a named row failure, which is the safe direction); check the Boolean; delete a
pre-existing target before saving so `File.exist?` means this run's file.

**5-minute check:** after any successful render sits in the VFB, console:
`VRay::Context.active.renderer.save_vfb_image("C:/temp/t.png", skip_alpha: true, no_alpha: true)`
→ expect `true`, one opaque PNG, no sidecar. Then the same to a locked/invalid
path → expect `false` (proves the Boolean is real).

---

## F5 — MED — dialog callbacks live during the batch: `setfill` can break the
revert; `activate` can move the scene mid-export

**Observed in code:** the JS guards `mark`/`bulk`/`export` with its `running`
flag, but the **`setfill` select handler (line 1566) and the `activate` go-arrow
(line 1532) have no `running` check, and none of the Ruby callbacks
(`mark`/`bulk`/`setfill`/`activate`, lines 1178–1222) check `@running`.**

**Derived consequence for `setfill`:** slot fills are read live from the model
dictionary. `WR_MaterialsSwap.to_draft` finds surfaces by the CURRENT fill names
(`fills(model)` → `find(model, render_names)`). Change a slot's fill during a
6-minute render and, at `finish`, surfaces painted with the OLD fill are simply
not found — **silently left on the render material**. That is a leaked mutation
with no report (`:left` only names surfaces found on a configured fill).

**Derived consequence for `activate`:** V-Ray snapshots the model ~0.22 s after
`start` (reported, V-Ray log). Clicking a row's arrow inside that window changes
the active view before the export completes — the 1.7.9 camera assert has already
passed, so this would resurrect the wrong-view bug for that row. Narrow window,
real hole.

**Recommended fix:** early-return from `mark`/`bulk`/`setfill`/`activate` when
`@running` (Ruby side — the JS flag is cosmetic), and disable the selects in
`runStarted()`.

**5-minute check:** start a 1-row render batch, change the Floor slot dropdown
while it renders, let it finish, then look at the floor: still on the (new? old?)
render material instead of drafting white → confirmed.

---

## F6 — MED — WR_Mode nests `start_operation` inside `start_operation`

**Observed in code:** `WR_Mode.to_mode` opens
`model.start_operation("WR Mode: …", true)` (line 261) and then calls
`WR_MaterialsSwap.to_render/to_draft`, which opens its **own**
`model.start_operation('WR Materials: …', true)` (lines 179/216) and commits it —
all while WR_Mode's operation is notionally open.

**Reported (SketchUp API):** operations do not nest — starting a new operation
while one is open implicitly closes the open one. Confidence medium (this is
long-standing documented/community-established SketchUp behaviour; not verified
here).

**Derived consequences if that holds:**
- WR_Mode's operation ends at the materials call, so everything after the swap
  (tag flips, style, shadow_info, snapshot save) runs either outside any
  operation or as a fragment — the advertised "one Ctrl+Z undoes the whole flip"
  is false (two-plus undo steps, or worse).
- On a raise after the swap, `WR_Mode`'s `abort_operation` has nothing (or the
  wrong thing) open — the swap stays committed while the tag/shadow half is
  rolled back or half-applied: exactly the "materials swapped, dims still on"
  state the file exists to prevent. In the batch this is masked by `finish`'s
  mode restore, but standalone toggles hit it bare.

**Recommended fix:** have `to_mode` pass a flag so WR_MaterialsSwap skips its own
operation when called from inside one (or use `start_operation(name, true, false,
true)` transparent-chaining on the inner one).

**5-minute check:** in a scratch model, press Toggle Draft/Render once, then
press Ctrl+Z ONCE. If materials revert but tags/shadows don't (or vice versa),
the nesting is broken as described.

---

## F7 — LOW-MED — failure messages omit the raw state; `:idleFrameDone` risk

**Observed in code:** the three `fail_render_row` messages (never started /
stopped without finishing / timeout) never include the actual `state` symbol the
poll saw. When a live failure happens, the one datum that distinguishes F1/F2/F8
theories is thrown away.

**`:idleFrameDone` (documented, never observed):** if a batch single-frame
production render can terminate at `:idleFrameDone` instead of `:idleDone`, the
classifier calls it `:idle` and `STOP_CONFIRM_S = 10` s later a COMPLETED
6-minute render is discarded as "stopped or cancelled". Benton's hand render
ended at `:idleDone` (observed), so this is unlikely — but the hand render is the
only sample, and a batch-triggered render has never completed under 1.7.9.

**Recommended fix:** append `(last state: #{state_val.inspect})` to every render
failure detail; decide `:idleFrameDone` policy only after it is ever seen.

**5-minute check:** none needed in advance — this is cheap logging that pays off
on the first live failure. Watch the first live batch log for the raw state.

---

## F8 — LOW — `@prev_cam = view.camera.clone` may alias the live camera

**Observed in code:** line 557. Sketchup API objects are thin wrappers over C++
objects; `Object#clone` on `view.camera` may copy the wrapper, not the camera, in
which case `@prev_cam` tracks the view and `finish`'s camera restore is a no-op.
(assumed — never verified either way.)

Blast radius is small: `finish` restores `selected_page` first (TT = 0, instant),
which re-applies the scene camera; `@prev_cam` only matters when Benton's
viewport had drifted off the saved scene before the batch — that drift would be
lost. `wr-preflight`'s scene-drift check would then read PASS, masking that the
view moved.

**5-minute check:** console:
`c = Sketchup.active_model.active_view.camera.clone; e = c.eye.to_a` → orbit the
view by hand → `c.eye.to_a == e` ? If false, the clone is live-aliased and the
restore is a no-op.

---

## F9 — LOW — output size: a documented WRITE path exists; the 1600 mystery stays open

- Reading: `scene['/SettingsOutput']` is a documented accessor (`Scene#[]` —
  "Accessor to get a VRay::Scene::Plugin by its name", observed doc text), and
  plugin parameter access via `plugin[:param]` is the documented pattern. The
  parameter NAMES `img_width`/`img_height` are still reported (V-Ray core
  convention), not confirmed in this binding. `warn_output_size`'s guarded read
  is sound.
- Writing: the docs give a full mechanism — `scene.change { pl = scene['/SettingsOutput']; pl[:img_width] = 2400 }` — and
  `VRayRenderer#fetch(:SettingsOutput)` is documented as "retrieves a plugin or
  creates it if not found". So "no documented way to set the size" is no longer
  true as a doc claim; what is missing is live verification that the write takes
  AND survives the Asset Editor.
- Why Benton's 1600 in the Asset Editor produced 2400×1350 output (observed by
  the caller) cannot be resolved offline. Plausibles (all assumed): the AE field
  edited was a different quality preset's size; "aspect from viewport" /
  safe-frame coupling; the AE not committing until a render from ITS button.

**5-minute check:** set 1600 in the Asset Editor, then console:
`VRay::Context.active.scene['/SettingsOutput'][:img_width]` — if it reads 1600,
the AE and the core agree and the 2400 came from somewhere else (say, V-Ray
resizing to viewport aspect at export); if it reads 2400 or raises, the AE field
edited is not `/SettingsOutput` and the warning's read is aimed at the wrong
plugin.

---

## F10 — INFO — timer loop, single-exit, and small residuals (traced, mostly sound)

Traced paths (all observed in code):
- **Re-entrancy:** `@in_step` guard is set/ensure-cleared correctly; `finish`
  stops the timer BEFORE its message boxes, so the "messagebox inside a tick
  re-enters timers" hazard does not apply to `finish`'s own boxes.
- **Completion / cancel / raise-in-step:** all route to `finish`; verified no
  path skips it inside the timer loop.
- **Raise inside `finish` itself:** every restore is individually rescued
  (`Exception`), so the restore block cannot raise; the residual raisers are
  `UI.messagebox` / `summary_lines` — a raise there escapes with the timer
  already stopped and `@running` still true. Recoverable: the next button press
  offers the stale reset, which routes through `finish` again and (because
  `@page_opts`/`@prev_tt` are nilled in an `ensure`) will NOT double-restore
  TransitionTime but WILL redo mode/scene/camera. Acceptable.
- **Raise in `start_run` between `@running = true` (line 539) and the timer
  start (line 584):** `@running` latches true with no timer; TransitionTime may
  already be 0. Recoverable through the same stale-reset path, which restores
  TT. Loud (the export callback's messagebox fires). Acceptable, worth knowing.
- **Multi-row reasoning:** per-row latch reset (`@seen_running = false` at
  line 876) is correct; row N+1 starting from `:idleDone` classifies as `:idle`
  until `:preparing` is seen — correct. `export_pages`' inner
  TransitionTime save/restore during image rows writes 0 back (the batch's own
  value) — no conflict with `start_run`'s push/pop.
- **`to_draft`'s `fillmap.key(cur)`:** if two slots are configured with the SAME
  fill material, `Hash#key` returns the first slot — the other family of
  surfaces reverts to the wrong drafting material. Only one slot is filled today
  (Benton: by design), so dormant; becomes live the day walls get a fill equal
  to the floor's. One-line note for whoever fills a second slot.
- **wr-mode swap-and-revert symmetry** (asked in the assignment): `to_render`
  maps surfaces by draft-material name; `to_draft` maps back by fill name.
  Atomic per-sweep (each is one operation — see F6 for the nesting caveat).
  Correctly reverted PROVIDED the fills don't change mid-batch (F5) and no two
  slots share a fill (above). The walls/doors-stay-draft state is by design and
  is reported via `:unmapped` — behaves as intended.

## Gaps — stated as prominently as the findings

- Nothing in this audit was executed. Every "derived" above rests on reading
  1.7.9 code (observed) plus doc text (observed on disk) plus Benton's live
  observations (reported). Confidence is capped at the weakest link in each.
- `:fatalError` cannot be forced cheaply, so F1's fix can only be proven by unit
  test (offline) plus the classifier check given.
- Whether `VRay::Command.render_production` drives the same
  `renderer.state` machine the poll loop reads is NOT known. If it renders
  through a different renderer instance, the poll loop would need re-aiming.
  The one-line console check in F2 answers this before any code changes.
- The licence-seat question (does a scripted render consume a seat) remains open;
  the "Incorrect DR version" raise still suggests the licence state is unhappy,
  which is also what makes F1's `:fatalError` scenario plausible here.
- The doc set on disk is dated 29 Apr 2026 — newer than the one
  `reference/vray-ruby-api.md` catalogued (1 Dec 2025). The state list and
  `Command` module may be new since; treat doc claims as "this build's docs",
  still not this build's behaviour.

===REPORT===
Findings F1–F10 above, ranked. Top three actions for the next session, in order:
(1) run F2's two cold-console checks — they decide the whole cold-start design;
(2) fix F1's classifier (`/error/i` → fail by name) with offline tests before the
next batch; (3) adopt F4's documented `save_vfb_image` options and Boolean check.
F3 and F5 are the two silent leaked-mutation paths that survive 1.7.9.
