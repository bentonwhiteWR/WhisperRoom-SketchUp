# Audit — LEAKED MUTATIONS (read-only)

**Scope:** every place a tool changes model state it intends to revert — tag visibility,
entity `hidden=`, page properties, materials, camera, shadow/render options, model options,
selection, attribute dictionaries — plus `start_operation` / `commit_operation` /
`abort_operation` discipline.
**Date:** 10 Sep 2026. Plugin 1.48.0. **Method:** static read only. Nothing here was executed;
there is no Ruby outside SketchUp on this machine. Every claim is tagged
observed / derived / reported / assumed.

**Headline:** the D10 discipline (capture before mutate) is genuinely held in the places the
repo has already been burned — `proposal-package.rb`'s `finish`, `export_pages`' `prev_vis`,
`@vray_saved`, the picker previews. The leaks that are left are in the places nobody has been
burned yet: **model options that were never treated as state at all** (units format),
**a window that mutates the model just by opening** (the deep row-state read), and
**a one-step undo that can consume itself while restoring nothing**.

---

## RANKED FINDINGS

### 1. Every builder silently rewrites the model's UNITS format, outside any operation, unrestorably — even on a dry run
**Risk: HIGH (silent, survives the save, not undoable, present in 14+ scripts).**

`scripts/build-booth-components.rb:2298-2302`

```ruby
model = Sketchup.active_model
begin
  model.options['UnitsOptions']['LengthFormat'] = Length::Architectural
rescue StandardError
end
```

- **observed** — this runs in `build_booth`, *before* `model.start_operation` (line 2504) and
  before the `unless cfg['dry']` guard. A DRY RUN — the mode whose entire contract is
  "nothing built" — changes the user's model anyway.
- **observed** — the value is never read first, never stored, never put back. There is no
  `LengthFormat` restore anywhere in `scripts/`.
- **derived** — `model.options` writes are not on the undo stack (the repo relies on this fact
  for `PageOptions`; `wr-scene-walls.rb:466-470` states the same about `page.update`), so
  Ctrl+Z cannot reverse it and saving the model makes it permanent.
- **Failure scenario:** Benton has a client's metric or decimal-inch drawing open, presses
  "Build from components" (or just dry-runs it to check part resolution), then discards the
  geometry — and the client's model is now Architectural. Every dimension string in that
  drawing re-renders in feet-and-inches. Nothing is said.

**Same defect, no restore, in:** `scripts/build-booth.rb:106`, `scripts/build-room.rb:379`,
`scripts/build-takeoff.rb:192`, `scripts/dimension-booth.rb:615`,
`scripts/dimension-whisperroom.rb:1003`, `scripts/booth-4260-s.rb:46`,
`scripts/booth-96168-s.rb:52`, `scripts/csusb-106.rb:372`, `scripts/csusb-rooms.rb:351`,
`scripts/dowaly-kuwait-tv.rb:159`, `scripts/fvrl-podcast-alcove.rb:155`,
`scripts/peoplesspace-alcove.rb:359`, `scripts/smith-studio.rb:431`,
`scripts/uthsc-audiology-rooms.rb:518`.
**Worse in two:** `scripts/pendant-jig.rb:382-384` and `scripts/tube-drying-stand.rb:308-310`
set `LengthFormat = Length::Decimal` **and** the unit/precision fields — a jig script flips an
architectural client model to decimal inches.

**Note:** `wr-callout-style.rb:32` already claims in prose that `UnitsOptions` is the one model
option this toolset touches — so the hazard is *known* and simply not handled.

---

### 2. Opening the Proposal Package window walks and ACTIVATES every scene in the model, and cannot put the model back if no scene was selected
**Risk: HIGH (fires on open, on a real client model, silent, not undoable).**

`scripts/proposal-package.rb:3899` → `state(model)` (`:1047`) → `row_states` (`:1002`) →
`WR_AutoSet.row_states` (`scripts/wr-autoset.rb:988-1035`).

```ruby
start = model.pages.selected_page
...
  pages.each_with_index do |pg, i|
    model.pages.selected_page = pg        # ACTIVATES every scene in the model
...
ensure
  restore_page(model, start)              # :861 — `if page && page.valid?`
```

- **observed** — the deep pass is ON by default (`deep?`, `wr-autoset.rb:978-981`,
  `@deep = true if @deep.nil?`) and runs inside `state(model)`, which `run` calls to build the
  window's HTML (`proposal-package.rb:3899`). No operation is opened around any of it.
- **observed** — `restore_page` is a **no-op when `start` is nil**
  (`wr-autoset.rb:861: model.pages.selected_page = page if page && page.valid?`).
  `Sketchup::Pages#selected_page` returns nil whenever no scene tab is active, which is the
  normal state of a model someone has been drawing in.
- **derived** — activating a page re-applies that page's saved tag visibility, hidden-object
  state, style, shadow info and camera. So with no scene selected, merely opening the window
  leaves the model wearing the **last scene in the tab bar**: its hidden walls hidden, its tags
  off, its camera. None of that is on the undo stack (page activation is not an operation), so
  Ctrl+Z does nothing and a save makes it permanent.
- **derived, second-order, present even when `start` is NOT nil:** re-selecting `start` at the
  end restores that scene's *saved* snapshot, not the live state. Any hand-tweak made since
  clicking that tab — a group hidden by hand, shadows nudged, a tag switched off — is wiped
  back to the scene's stored values by the restore itself. It is a blanket re-assert, not a
  restore-to-what-was-there.
- **assumed** — that `restore_page` cannot do better: there is no SketchUp API for "no page
  selected", so the nil case is unfixable *by restore*. It is fixable by **refusing the deep
  pass when `selected_page` is nil**, which nothing currently does.

The same select-every-page loop with the same nil-`start` hole is in
`WR_SceneWalls.apply_all` (`scripts/wr-scene-walls.rb:427-446`),
`WR_SceneAnnotations.apply_all` (`scripts/wr-scene-annotations.rb:592-607`) and both
`undo_last` methods — but those are explicit operator actions inside an operation, so they rank
below this one, which fires on open.

---

### 3. UNDO LAST APPLY can restore nothing, report success, re-commit the wrong state, and consume the only record
**Risk: HIGH (this is the *recovery* path for a write Ctrl+Z cannot touch).**

`scripts/wr-scene-walls.rb:512-520` and `:522-546`

```ruby
def self.write_snapshot(page, before)
  preview_show(before, {})          # per piece, exactly as recorded
  ...
  page.update(update_mask)
end
...
  scan(model)                       # rebuild the key index; keys are entityIDs
  entries.each do |e|
    model.pages.selected_page = e[:page]
    write_snapshot(e[:page], e[:before])
    put << e[:name]                 # counted as "put back" unconditionally
  end
```

- **observed** — `preview_show` (`:604-617`) skips any key whose unit is missing from the
  rebuilt index: `u = @units && @units[key]; next unless u`. It returns nothing and counts
  nothing.
- **observed** — the keys are entityIDs (`scan` rebuilds `@units`; the comment at `:531` says
  so). A wall group erased, re-created, exploded/re-grouped or re-imported since the apply has
  a different entityID, so its recorded answer silently matches nothing.
- **observed** — `write_snapshot` then calls `page.update(update_mask)` regardless, which
  **writes the model's CURRENT (unrestored) hidden state back into the page**, and `undo_last`
  sets `@last_write = nil` (`:543`) and reports
  `"Put back the saved wall answer on N scene(s)"` — N counts *pages*, never *pieces*.
- **Failure scenario:** the operator runs APPLY TO ALL SCENES, dislikes it, edits a wall group,
  then presses UNDO LAST APPLY. The button says it put the answer back on 12 scenes. It put
  nothing back on the scenes whose units moved, re-stamped the unwanted state into those pages,
  and destroyed the only record that could have fixed it. The tool's own header calls this
  record "the one step there is".
- Identical shape in `scripts/wr-scene-annotations.rb` (`write_snapshot` / `undo_last`,
  `:682-730`), where `preview_show` (`:132-147`) has the same `next unless u`.
- **Minimum fix (not applied):** have `preview_show`/`write_snapshot` return the count of keys
  it could not resolve, refuse the page write when any are missing, and keep `@last_write`.

---

### 4. `use_hidden_objects` / `use_hidden_layers` are blanket-set to true on the user's scenes and never recorded or restored
**Risk: MEDIUM-HIGH (silent, survives the save, and the tool's own undo does not cover it).**

`scripts/wr-scene-walls.rb:390-394`, `:512-518` (`write_snapshot`), `:584-588`
(`apply_selection`); `scripts/wr-scene-annotations.rb:560-568` (both properties).

```ruby
if page.respond_to?(:use_hidden_objects=) &&
   page.respond_to?(:use_hidden_objects?) && !page.use_hidden_objects?
  page.use_hidden_objects = true rescue nil
end
```

- **observed** — the `before` record these methods carry (`snapshot_keys`, `:491-496`) holds
  *piece hidden flags only*. The page property is not in it.
- **observed** — `undo_last` → `write_snapshot` sets it to `true` **again** on the way back, so
  UNDO LAST APPLY cannot restore it either. Neither can Ctrl+Z: `page.update` and page property
  writes are outside the undo stack, as `wr-scene-walls.rb:466-470` itself documents.
- **Failure scenario:** a scene deliberately set to *not* save hidden objects (a common way to
  keep one overview scene showing everything) is silently converted into one that does, by a
  single wall pick, for ever. The tool warns loudly about the *opposite* case ("scene(s) not
  saving hidden objects") and treats making the change as free.
- `fix_pages` (`wr-scene-walls.rb:620-638`, `wr-scene-annotations.rb:571-...`) does the same to
  **every** page, but that one is an explicitly-named button — correct behaviour, listed only
  for completeness.

---

### 5. `abort_operation` is reachable AFTER `commit_operation` in the two biggest builders
**Risk: MEDIUM-HIGH (the failure message lies about committed geometry; possible rollback of an unrelated operation).**

`scripts/wr-drop-lights.rb:4174` commits, then ~70 lines of reporting
(`print_light_report`, `format`, `UI.messagebox` at `:4223`) run **still inside** the `begin`
whose handler is `:4242-4254`:

```ruby
      model.commit_operation
      probe_after = model_probe(model)
      print_light_report(...)
      ...
      UI.messagebox("Add walls (...)")      # :4223
    rescue StandardError => e
      model.abort_operation                  # :4243 — nothing is open
      ...
      raise e
```

Same shape at `scripts/build-booth-components.rb:2978` (commit) → `:3025`
(`model.abort_operation unless cfg['dry']`), with a `UI.messagebox` at `:2990` inside the
protected tail and `rescue Exception` — so even a `NoMemoryError` routes through the abort.

- **observed** — the commit/abort line numbers and the code between them.
- **reported (this repo, twice)** — `UI.messagebox` raising is not hypothetical:
  `proposal-package.rb:3318-3324` and `:3378-3392` document it observed live on 30 Aug 2026
  ("a scripted caller whose UI.messagebox raises — the bridge muzzles modals").
- **assumed** — what SketchUp does with `abort_operation` when no operation is open is not
  documented. Best case a no-op; worst case it rolls back the previously committed operation.
  Either way the *reported* outcome is wrong.
- **Failure scenario (best case, still bad):** the light rig is fully placed and committed; a
  raise in the reporting tail re-raises to `:4258`, which shows "Drop Interior Lights failed".
  Benton believes nothing was placed and presses again. Drop Lights sweeps its own stale rig so
  it survives that; **`build-booth-components.rb` does not** — a second press stacks a second
  booth on the first.
- **Fix shape (not applied):** move the reporting tail outside the `begin`, or set a
  `committed = true` flag and guard the abort on it.

---

### 6. `wr-materials-swap` detects duplicate SOURCE materials and not duplicate FILLS — so Render→Draft can repaint with the wrong drafting material
**Risk: MEDIUM (silent, wrong-looking model, reversible only by hand).**

`scripts/wr-materials-swap.rb:185-206` (`slot_for`) explicitly refuses a source material claimed
by two slots: *"a surface on it has two possible destinations and no way to choose … left OUT of
the map and returned separately"*. The reverse direction has no such check:

`scripts/wr-materials-swap.rb:138-140` + `:295-297`

```ruby
def self.fills(model)
  SLOT_FOR.values.each_with_object({}) { |s, h| h[s] = fill(model, s) }
end
...
  slot = fillmap.key(cur)          # first slot whose fill == cur; no dupe check
  draft_name = slot ? source(model, slot) : nil
  e.material = drafting_material(model, draft_name)
```

- **observed** — `Hash#key` returns the *first* matching key. No `dupes` equivalent exists for
  fills, and nothing warns.
- **Failure scenario:** floor and ceiling slots are both filled with the same V-Ray white (a
  natural configuration). `to_render` paints both with it. `to_draft` then maps every surface on
  that white back to the **floor's** drafting material — the ceiling comes back the floor's
  colour. The result reports `reverted` counts and no problem. This runs inside every Proposal
  Package mode swap (`WR_Mode.to_mode` → `to_draft`), so it lands in the model the batch claims
  to have restored exactly.

---

### 7. A V-Ray override that could be WRITTEN but not READ is never restored, and is not reported as a restore failure
**Risk: MEDIUM (silent, outside the undo stack entirely, changes the operator's own camera).**

`scripts/proposal-package.rb:1185-1196`

```ruby
def self.restore_params(scene, saved)
  triples = saved.reject { |_k, v| v == :absent || v == :unreadable }
```

and `read_params` (`:1136-1143`) records `:unreadable` when `pl[key]` raises.

- **observed** — `:unreadable` keys are dropped from the restore silently; `restore_params`
  returns only the problems `write_params` reports for the triples it *did* send, so `finish`'s
  `restore_errs` (`:3195-3200`) stays empty and the summary says "Done. Model restored."
- **observed** — `apply_exposure` (`:2634-2639`) writes `/CameraPhysical` `f_number`, `ISO` and
  `shutter_speed` on **every render row** while only merging readable values into `@vray_saved`.
  A key whose read raised but whose write succeeded is left at the batch's value.
- **derived** — V-Ray scene parameters are not on SketchUp's undo stack (stated repeatedly in
  this repo, e.g. `wr-drop-lights.rb:3598-3602`), so nothing recovers this but retyping.
- **reported (this file's own header, lines 40-49)** — the V-Ray Ruby surface on this machine is
  flaky enough that `in_process?`/`dr_enabled?` *raise*; an unreadable-but-writable parameter is
  that failure mode one key over.
- **Failure scenario:** a render batch leaves the client's physical camera at f/8 ISO 100 and a
  batch-chosen shutter, and the log says the model was restored. The next hand render is exposed
  wrong and nobody knows why.
- **Fix shape:** treat `:unreadable` as a restore failure *to report*, not a key to skip.

---

### 8. `export_pages`' `ensure` is a chain of unguarded statements — the first failure abandons the tag restore, which is last
**Risk: MEDIUM (this is the block that puts the user's tags back).**

`scripts/export-scenes.rb:311-319`

```ruby
ensure
  prev_ro.each { |k, v| ro[k] = v }
  page_opts['TransitionTime'] = prev_tt
  pages.selected_page = prev_page if prev_page
  prev_vis.each do |n, v|
    l = model.layers[n]
    (l.visible = v) if l && !v.nil?
  end
```

- **observed** — none of the four restores is individually rescued. `pages.selected_page =` on a
  page deleted during the run, or an `ro[k] = nil` write for a key whose read returned nil,
  raises out of the `ensure` and the remaining statements never run.
- **observed** — the tag restore is deliberately placed LAST (its comment: *"AFTER the page is
  restored, so the restore's own tag re-apply cannot undo this"*), which makes it the statement
  most likely to be skipped. The tags it puts back are `WR_Mode::LIGHT_TAGS` — hidden by the
  exporter — so the leak is "the user's light tag stays hidden", which `wr-mode.rb`'s own header
  calls a silently-unlit V-Ray pass.
- **observed, same file, second hole:** `page_opts['TransitionTime'] = 0` at `:219` happens
  **before** the `begin` at `:255`. Anything raising in the 35 lines between (the `prev_ro`
  reads, the `prev_page` read, the `model.layers[n]` loop at `:245-248`) leaks
  `TransitionTime = 0` into the model permanently — a model option, not undoable, saved with the
  file. `proposal-package.rb` handles its own copy of exactly this correctly (`:1759-1775`:
  rescued, with `@prev_tt` published first).
- Compare: `finish` (`proposal-package.rb:3182-3410`) wraps *every* restore in its own
  `begin/rescue` and accumulates `restore_errs`. That is the pattern this `ensure` should copy.

---

### 9. D10 residue: `WR_Shading.push` mutates before the caller can record what it mutated — and `pop` refuses to restore keys it could not read
**Risk: MEDIUM-LOW probability, HIGH cost (a silently restyled model, saved).**

`scripts/proposal-package.rb:2158-2164`

```ruby
@shade_saved = WR_Shading.push(model, WR_Shading::KEEP, WR_Shading::DEF_DARK)
```

`scripts/wr-shading.rb:167-204` — `push` builds `saved` as a **local**, changes the style and
calls `apply` (which writes 5 rendering options and 4 shadow keys), and returns `saved` only at
the end. The caller's record therefore exists only *after* the mutation. This is D10's exact
shape — the one `finish`, `export_pages` and `@vray_saved` were all fixed into
capture-before-mutate.

- **observed** — the assignment order and `apply`'s position inside `push`.
- **derived** — the window is narrow: `apply` has a blanket `rescue StandardError`
  (`wr-shading.rb:157`) and the style write is rescued, so only a non-`StandardError`
  (`NoMemoryError`, `Interrupt`, a `ScriptError` from a reloaded constant — plausible in a repo
  that hot-`load`s and uses `remove_const`) escapes mid-apply. If one does, `@shade_saved` stays
  nil, `unit_shade_pop` (`:2166`) and `finish` (`:3199`) both test `if @shade_saved` and do
  nothing, and the model keeps DisplayShadows off, ground/horizon/fog/watermark/AO off and
  Light/Dark forced — permanently, under a clean "Done. Model restored." summary.
- **observed, independent** — `WR_Shading.pop` (`:206-217`):
  `(ro[k] = v) rescue nil unless v.nil?`. A key whose *read* failed during push is recorded nil
  and is then deliberately **not** restored — left at the contract's value rather than the
  user's. Restore-to-what-was-there fails open, silently.
- Same push-then-assign at `scripts/export-component-art.rb:371`, where the exposure is wider:
  `push` at `:371`, then `apply`, `describe` and the `prev_page` read all sit **before** the
  `begin` at `:383` whose `ensure` holds the `pop` — plus `page_opts['TransitionTime'] = 0` at
  `:365`, the same pre-`begin` leak as finding 8.
- **Fix shape:** let the caller pass in (and own) the `saved` hash, or have `push` publish it to
  a module ivar before its first write.

---

### 10. Every mode toggle blanket-stamps "WR Lights" into EVERY saved scene, and no restore puts the per-scene answers back
**Risk: MEDIUM (blanket-reset rather than restore; hits the operator's real scene set).**

`scripts/wr-mode.rb:229-249` (`stamp_light_pages`), called from `to_mode` (`:320`):
`pg.set_visibility(l, want)` on **every page in the model**, at the target mode's polarity.

- **observed** — nothing anywhere records the pages' prior per-scene visibility of `WR Lights`;
  `to_mode`'s snapshot (`snapshot`, `:175-185`) stores the *model-wide* layer state only.
  `wr-drop-lights.rb:2360-2372` (`stamp_tag_into_pages`) does the same thing with `true`.
- **observed** — `proposal-package.rb`'s batch calls `WR_Mode.to_mode` up to three times per run
  (draft → render → restore), so one export re-stamps every scene up to three times.
- **observed, the sharp edge** — `finish` (`:3227-3240`) resolves a never-toggled model
  (`WR_Mode.current` → `'unknown (never toggled)'`) to `MODE_FALLBACK` `'draft'` and calls
  `to_mode`. On a client model that has never seen this plugin, an export therefore stamps
  `WR Lights` **hidden** into every one of the operator's scenes, and reports it as a restore.
- **derived** — the stamps are inside `to_mode`'s operation, so a single Ctrl+Z *immediately*
  would reverse them; after three operations and a summary box, nobody will.
- The polarity pin is deliberate policy and well argued in the header. The defect is that the
  *pages* are treated as blanket policy targets with no record, while the file's own contract
  says "BOTH STATES ARE REMEMBERED, NOT ASSUMED".

---

### 11. Operations that can be left OPEN: `rescue StandardError` around a whole transaction, and unguarded work between `start_operation` and `commit_operation`
**Risk: MEDIUM-LOW probability, HIGH cost (an open operation swallows the user's next edits).**

- `scripts/wr-mode.rb:288-337` — `to_mode` wraps its whole transaction in
  `rescue StandardError => e; model.abort_operation; raise e`. A `NoMemoryError`, `Interrupt` or
  `ScriptError` escapes with the operation still open; every subsequent viewport edit joins it.
  `proposal-package.rb:4643` explicitly uses `rescue Exception`, calling it "the repo rule
  (main.rb)" — `to_mode` does not follow it. Same narrow rescue in
  `wr-materials-swap.rb:274`/`:307`, `wr-scene-walls.rb:351`/`:438`/`:539`/`:590`,
  `wr-scene-annotations.rb` (six sites), `wr-scene-sun.rb:193`/`:223`/`:335`,
  `wr-autoset.rb:761`/`:825`/`:853`/`:942`.
- `scripts/wr-drop-lights.rb:2044-2065` — `remove_rig!` opens an operation and then runs
  `e.get_attribute(...)`, `e.respond_to?(:definition)` and `nested_lights(e)` with **no rescue
  at all** between `start_operation` and `commit_operation`. A stale entity reference raising
  there leaves the operation open with lights half-erased.
- `scripts/wr-drop-lights.rb:1963-1978` — `erase_owned!` has the same unprotected shape (smaller
  surface: only `g.valid?` is unguarded).
- **observed** for all line numbers; **derived** for the consequence (SketchUp's behaviour for an
  operation never committed or aborted).

---

### 12. Smaller leaks, listed because they are real and cheap to close

| Where | What leaks | Tag |
|---|---|---|
| `scripts/wr-drop-lights.rb:2780` | `(t.color = Sketchup::Color.new(255,199,44))` is applied to an **existing** `WR Lights` tag, not only one this tool created. The operator's tag colour is overwritten, unrecorded. | observed |
| `scripts/wr-drop-lights.rb:2782-2787` | `t.visible = true` on a tag the operator had deliberately hidden — deliberate policy, but unrecorded and never reverted by `remove_rig!`. | observed |
| `scripts/wr-scene-walls.rb:321-333` (`reveal`) | `model.selection.clear` then `add` — the operator's selection is destroyed by a "show me which one" button and never restored. Low cost (selection is not saved with the file). | observed |
| `scripts/wr-sun-aim.rb:347-357` (`calibrate`) | `orig = si['NorthAngle'].to_f`; if the read yields nil, `orig` is `0.0` and the `ensure` writes **0.0** — silently rotating the model's north instead of restoring it. The `ensure` itself is unguarded. | observed / derived |
| `scripts/proposal-package.rb:2166-2172` (`unit_shade_pop`) | not rescued; a raise in `WR_Shading.pop` leaves `@shade_saved` set and propagates into `step_body` → `finish`, which retries the pop. Benign today, but it depends on `finish` being reached. | observed |
| `scripts/proposal-package.rb:4617-4626` (`export` callback) | the only mutating callback that does **not** call `preview_end(model)` first. Currently unreachable with a live preview because the pickers are `position:fixed; inset:0` modals (`:4743`, `:4773`, `:4809`, `:4821`), so this is defence-in-depth, not a live defect. | observed |

---

## WHAT IS ACTUALLY GOOD (so a fix does not break it)

- **observed** — `proposal-package.rb:3182-3410` (`finish`): re-entrancy guarded, every restore
  in its own `begin/rescue`, errors accumulated and shown, `@running` lowered before the last
  message box, plan/manifest state cleared. This is the reference implementation in the repo.
- **observed** — `export-scenes.rb:240-248`: `prev_vis` is populated **before** the loop that
  hides, and restored after the page restore. Capture-before-mutate, correct.
- **observed** — `proposal-package.rb:2131` (`@vray_saved = read_params(...)` before
  `write_params`) and `:2634-2639` (`@vray_saved ||= {}`, first-write-wins per key) — correct
  D10 shape; the only hole is finding 7's `:unreadable` drop.
- **observed** — the picker previews (`proposal-package.rb:3538-3585`): baseline snapshotted once
  at `preview_begin` before any mutation, the preview is a pure function of (baseline, picks),
  and **all** exits route through `preview_end` — CANCEL, backdrop, APPLY, opening another
  picker, and `set_on_closed` (`:4640`).
- **observed** — `wr-drop-lights.rb:1984-2028` (`verify_restore!`): an independent re-read that
  refuses by name rather than trusting its own capture. That check is why finding 5's best case
  is survivable.

---

## NOT COVERED

- **Nothing was run.** No SketchUp, no Ruby. Every behavioural claim is static reading; anything
  I could not settle from source is tagged `derived` or `assumed`. In particular I could not
  determine empirically what `abort_operation` does with no operation open (finding 5), nor
  confirm that `model.options` writes are outside the undo stack (finding 1) — both are
  `derived` from the repo's own prose.
- `scripts/proposal-package.rb` is being edited concurrently (the zero-scene open change, 1.48.1,
  visible at `:3676-3697`). Findings 2, 7, 8 and 9 touch that file but none touch
  `open_decision`, `run`'s gate or the dialog HTML, so they should not collide. Line numbers here
  may drift.
- The V-Ray render lane's *runtime* behaviour (`unit_render`, the completion classifier, the
  framebuffer save) — audited only for parameter save/restore, not correctness.
- All HTML/JavaScript except the modal-overlay CSS checked for finding 12's last row.
- `wr-overlays.rb` was read for mutation shape only: it is a placement library with no
  save/restore contract of its own (its caller `build-booth-components.rb` owns the operation),
  so it is covered by finding 5 rather than separately. Its `model.layers.add` /
  `model.definitions.add` / materials writes rely on the caller's abort to clean up — a reliance
  `wr-drop-lights.rb:2001-2011` says out loud does **not** hold for materials and definitions
  ("this is the check that catches the 37th material"). I did not chase that to a concrete leak.
- The **"refuse unless Untitled"** rule: the only enforcement in `scripts/` is
  `wr-bridge-lib.rb:131-140` (`scratch!`, which refuses a saved model). **No builder checks
  `model.path`** — `build-booth-components.rb`, `build-room.rb`, `build-booth.rb`,
  `build-takeoff.rb`, `pendant-jig.rb`, `tube-drying-stand.rb` and the per-client room scripts
  all build into whatever model is open. I did not audit whether that is intended per script
  (several are clearly meant to run on client models); flagged because finding 1 rides on it.

---

## SUGGESTED ORDER OF REPAIR

1. **Finding 1** — delete or capture/restore the `LengthFormat` write; at minimum move it behind
   `unless cfg['dry']`. One line per file, 14 files, no design needed.
2. **Finding 2** — refuse the deep pass (or skip the page walk) when
   `model.pages.selected_page` is nil, and say so in the window.
3. **Finding 3** — make `preview_show`/`write_snapshot` report unresolved keys; refuse the page
   write and keep `@last_write` when any are missing.
4. **Finding 5** — move the post-commit reporting tails out of the protected block.
5. **Finding 8** — wrap each statement in `export_pages`' `ensure`, and move
   `TransitionTime = 0` inside the `begin`.
6. **Findings 4, 6, 7, 9, 10, 11** in that order.
