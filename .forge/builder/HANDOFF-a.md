# HANDOFF — Builder A

## Produced

- `scripts/wr-materials-swap.rb` — draft/render material swap by NAME, three
  named slots (`WR-Floor-Render`, `WR-Wall-Render`, `WR-Door-Render`), fill
  stored per model in an attribute dictionary. `to_render(model)` /
  `to_draft(model)` are the library API; `run` is a thin panel command that
  also lets an operator set the three fills from a dropdown of the model's own
  materials. Every surface it could not map is named in the result, never
  silently left drafting.
- `scripts/wr-mode.rb` — Draft <-> Render toggle. Calls
  `WR_MaterialsSwap.to_render` / `.to_draft` for materials and touches nothing
  else material-related. Also flips every tag in `proposal-scenes.rb`'s
  `DIM_TAGS` (loaded, not re-listed), the active style, and `shadow_info`.
  Both mode snapshots are stored in an attribute dictionary and re-captured
  from the live model every time a mode is left, so flipping back restores
  whatever was actually there — not a hard-coded default — after the first
  toggle. `to_render(model)` / `to_draft(model)` are direction-explicit
  library entry points; `run` is the toggle a person presses.
- `scripts/wr-preflight.rb` — read-only checklist in an `UI::HtmlDialog`, five
  rows: dimension tags off, floor off drafting white, camera matches its
  saved scene, no geometry outside the walls, clear line of sight to the
  booth. The first three carry a Fix button (dims/floor call
  `WR_Mode.to_render`; scene re-snaps the camera to the selected page). Stray
  geometry gets a Select button instead of an auto-fix — nothing gets moved
  or deleted for you. The ceiling check is a documented heuristic (a
  `model.raytest` toward the booth's bounding-box centre) and degrades to a
  `skip` row, not a false pass/fail, when there's no booth tagged or the call
  errors. Deliberately has no "lighting rig present" row.
- `scripts/wr-pack-export.rb` — one-button export. Reads the five plate
  scenes from `proposal-scenes.rb`'s `PLATES` list. Scenes are marked for
  V-Ray with an attribute on the `Sketchup::Page` itself (unmarked = viewport
  lane, the safe default). Runs `WR_Preflight.check` first and asks
  Continue/Cancel if anything is failing. Per plate: switches the model to
  `WR_Mode.to_draft` for `02-dimensioned` or `WR_Mode.to_render` for the other
  four, exports through `WR_ExportScenes.export_pages` into a temp staging
  folder, then shells out to the new `scripts/wr-flatten-trim.py` to flatten
  onto white and trim dead margins (hero plate `01-exterior` is flattened but
  not trimmed, per `reference/proposal-playbook.md` §5) into
  `ProposalFiles\<Client>\0N-name.png`. Asks before overwriting anything
  already in that folder. V-Ray-marked scenes are reported and skipped;
  nothing under the `VRay::` namespace is called anywhere in this file.
  Restores the model's original mode and selected scene/camera in an `ensure`
  block regardless of outcome.
- `scripts/wr-flatten-trim.py` — small Python helper (Pillow), called via
  `system()` the same way `wr-shading.rb` shells out to
  `fix-angled-alpha.py`. Flattens a transparent PNG onto white and trims dead
  margins to the content bounding box; `--no-trim` skips the crop for the
  hero. It does **not** do the later resize-to-JPEG print-prep step —
  that stays part of the proposal build, not the pack export.

### A change outside the assigned four files

`scripts/export-scenes.rb` was refactored, minimally: the `write_image` loop
that used to live inline in `run()` is now `self.export_pages(model, plan,
cfg)`, a pure, non-interactive function; `run()` calls it and behaves exactly
as before. The file's last line changed from an unconditional
`WR_ExportScenes.run` to `WR_ExportScenes.run unless $wr_no_autorun` — every
other loadable script in this repo already carries that guard, and this one
was the one exception, which made it impossible to `load` the file for its
export logic without also popping its own interactive folder/width dialog.
This was necessary to satisfy "the exporter reuses this, it does not
reimplement it" — the alternative was a second `write_image` call somewhere,
which is exactly the kind of drift the file's own header warns about
elsewhere in this repo (see `wr-shading.rb`'s two-exporters story). I did not
touch anything else in the file.

## Read-first

- `scripts/wr-shading.rb` for the library-with-remove_const-guard pattern
  `wr-materials-swap.rb` and `wr-mode.rb` both follow, and for
  `WR_Shading.push`/`pop`/`SHADOW_KEYS`/`DEF_LIGHT`/`DEF_DARK`, which
  `wr-mode.rb` reuses directly rather than re-deriving shadow defaults.
- `scripts/proposal-scenes.rb` for `DIM_TAGS`, `PLATES`, and the
  tag-walking helper `tagged`/`walk` that `wr-preflight.rb` reuses.
- `scripts/booth-from-link.rb` (around line 205) for the
  `$wr_no_autorun = true / ensure $wr_no_autorun = false` cross-load pattern —
  my three files use a slightly stronger save/restore version
  (`$wr_no_autorun_was = $wr_no_autorun`) so that nested loads (pack-export
  loads preflight loads mode loads materials-swap) don't clear the guard
  early partway through the chain. This matters: the plain
  set-to-false-in-ensure version from `booth-from-link.rb` would have broken
  under this file's three-deep nesting.

## Assumptions

- **Ceiling-occlusion check is a heuristic, reported as one.** It casts a ray
  from the camera eye toward the centre of whatever is tagged `WR-Booth*` and
  fails only if the first thing hit is not booth-tagged. It cannot identify
  "ceiling" by name — only "something else is in the way" — and the row's
  detail text says so. `model.raytest(point, vector)` is the documented
  SketchUp Ruby API signature; it has never been exercised on this machine, so
  the call is wrapped and any error downgrades the row to `skip` rather than a
  false pass or a crash.
- **Camera-drift tolerance** for the "on a saved scene" check is 0.75 in on
  eye/target and 0.5 deg on the up vector — a judgement call, not a measured
  threshold, chosen to catch a real nudge without flagging floating-point
  noise from reselecting the same scene.
- **Stray-geometry margin** is 24 in past the WR-Room/WR-Floor bounding box —
  again a judgement call, generous enough not to flag a door swing arc or a
  dimension leader sitting just outside the wall face.
- **`wr-pack-export.rb` only ever touches the five named plate scenes**
  (`01-exterior` … `05-plan`), not every scene in the model. The goal text
  says "walks every scene in order"; I read that as every scene *in the
  proposal plate set*, because the destination filenames are fixed to those
  five names and a model can carry dozens of unrelated component-art scenes
  that have nothing to do with a client pack. Flagged here rather than
  silently picked either way.
- **Per-scene switching calls `WR_Mode`, not `WR_MaterialsSwap` directly**,
  and the page is selected *before* the mode call, not after — so `WR_Mode`'s
  style/shadow override is the one that sticks for that export, even though
  each of the five plates also carries its own baked-in
  tag-visibility/style/shadow snapshot from when `proposal-scenes.rb` created
  it. On the one axis that matters most (dimension-tag visibility) the two
  mechanisms already agree by construction — `proposal-scenes.rb`'s own
  `set_dims` bakes "02 shows dims, the other four hide them" into each scene
  independent of whatever mode the model was in when the scenes were made.
- **`wr-flatten-trim.py` needs Python + Pillow** on the machine that runs it.
  `fix-angled-alpha.py` already depends on the same stack for
  `wr-shading.rb`'s recovery step, so this is an existing dependency, not a
  new one — but it has not been exercised, same as everything else here.
- Output filenames are `<plate-name>.png` (flattened, opaque, trimmed) — not
  the resized JPEGs `reference/proposal-playbook.md` §5 describes for the
  final print pack. That resize/JPEG step stays part of building the actual
  proposal PDF (the `whisperroom-proposal` skill), which is a separate,
  later decision (crop framing, print DPI) that a one-button export
  shouldn't make silently.

## Open questions

- Whether `wr-pack-export.rb`'s "Continue export anyway?" gate on a failing
  preflight is the right amount of friction, or whether some failing checks
  (camera drift, stray geometry) should block export outright rather than
  just warn. Left as an operator decision on purpose.
- Whether the ceiling-occlusion heuristic is worth keeping at all given how
  little it can actually confirm — it degrades gracefully to `skip`, but a
  false PASS (something non-booth is hit but happens to be past the target
  distance) is possible and unverified.
- None of this has run. Every claim above about *behaviour* — as opposed to
  syntax — is `assumed` or `reported` from the SketchUp Ruby API as
  documented, not `observed`. `python scripts/rbparse.py` (a real CRuby 3.2
  parse) is clean on all five touched/created `.rb` files and on the full
  `scripts/` folder (47 files, all other builders' work included), but that
  proves syntax only.
