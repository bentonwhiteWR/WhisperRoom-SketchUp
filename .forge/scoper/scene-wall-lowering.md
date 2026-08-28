# Scoping — "Lower the host-room walls for a backside scene"

2026-08-27, Scoper. No mockup accompanies this file — the recommendation needs no UI,
and making one would have implied a build this deliberately does not propose.

## The problem in one sentence

For scenes that look at the *back* of a booth pressed near a host-room wall, Benton
today hand-lowers the host walls and has to remember to put them back; he wants that
state to belong to the scene, and to survive the proposal-package batch without
weakening its revert guarantee.

## The decisive answer first: this is already solved in this repo, with no new code

The whole mechanism shipped in the two-band-walls work (see
`.forge/builder/HANDOFF-c.md`) and the proposal package rides it for free:

1. **`scripts/build-room.rb` builds every wall and door header as TWO stacked solids**
   split at a sill height (dialog field, default `DEFAULT_SILL = 48.0`, i.e. 4'-0").
   The lower band stays on `WR-Room`; the upper band goes on its own tag,
   **`WR-Room-Upper`** (observed — `band()` and the file header, which says in so many
   words: *"Hiding WR-Room-Upper on a scene 'lowers' the walls for a ventilation
   render without editing any geometry — nothing was ever moved, so there is nothing
   to put back."*).
2. **`scripts/wr-split-walls.rb` is the retrofit for models that already exist** with
   one-piece walls: it finds clean vertical-extrusion leaf wall groups, cuts each in
   two at a chosen sill, and tags the upper piece `WR-Room-Upper`. Dry-run by default,
   one-operation undo, skips-and-names anything it cannot confidently identify
   (observed — read in full). So "my current client model has full-height walls" is a
   one-time, supervised fix, not a blocker.
3. **Scenes persist tag visibility.** `Sketchup::Page` saves per-scene layer
   visibility when the page's "use hidden layers" property is on; this repo already
   relies on exactly that: `scripts/proposal-scenes.rb` sets
   `page.use_hidden_layers = true` on every plate it creates (observed, line ~221) and
   `scripts/merge-scenes.rb` round-trips the same flag (`use_hidden_layers?`,
   observed, lines 127/229). Hand-made scenes save visible tags by default in
   SketchUp's scene properties (reported — product behaviour, not read from this
   repo).
4. **The proposal package honors it with zero changes.** Both lanes activate the
   scene before capturing: the image lane via `WR_ExportScenes.export_pages`
   (`pages.selected_page = p[:page]`, `TransitionTime` zeroed — observed,
   `scripts/export-scenes.rb` ~170/191) and the render lane directly
   (`model.pages.selected_page = p[:page]; model.active_view.refresh` — observed,
   `scripts/proposal-package.rb` ~495). Activating a page applies its saved tag
   visibility, so a scene saved with `WR-Room-Upper` off exports/renders with lowered
   walls and the next scene with it on gets them back — the *scene switch itself* is
   the revert, inside the existing FINISH discipline, no new mutation added.
5. **Nothing else in the pipeline fights it.** `WR_Mode` flips only the four
   `DIM_TAGS` (`WR-Dims`, `WR-Dims-Doors`, `WR-Dims-Booth`, `WR-Dims-Selection` —
   observed, `scripts/proposal-scenes.rb` ~51); `WR-Room-Upper` is not in that list,
   so the draft/render toggle can never re-show walls a scene lowered.

The one genuinely unverified link: **whether V-Ray omits geometry on a hidden tag**
(assumed — V-Ray renders the visible viewport; every V-Ray behaviour in this repo is
reported-not-observed, per `probe-vray.rb`'s banner). One manual render of a
lowered-wall scene settles it, and it is worth folding into the first
proposal-package acceptance run.

## "Lower," not "hide" — the distinction he named is already the design

Benton said *lower*, and that matters: a lowered wall keeps the room reading as a
room — the floor line, the wall footprint, the bounce/shadow ground the render needs
so the booth doesn't float in white. Hiding `WR-Room-Upper` does exactly that: the
0-to-sill stub **stays visible**, so the wall is genuinely lowered to 4'-0" (or
whatever sill was chosen), not deleted. Hiding the whole `WR-Room` tag would be the
"hide" he was avoiding; nothing in this recommendation does that. Physically the
result matches what a real lowered wall does in a render: light floods over the stub,
the stub still catches contact shadow at the floor (derived — the lower band is
ordinary geometry with the wall material; the V-Ray light behaviour itself is
assumed until a render is seen).

## Findings, itemized (the questions the brief asked)

1. **Do the room scripts tag walls, and how granularly?** One walls tag per model,
   never per-wall (observed): `build-room.rb` → `WR-Room` + `WR-Room-Upper`;
   `csusb-rooms.rb` and `uthsc-audiology-rooms.rb` → `WR-Room`; `smith-studio.rb` →
   `WR-Studio-Walls`; `fvrl-podcast-alcove.rb` → `WR-FVRL-Walls`;
   `dowaly-kuwait-tv.rb` → `WR-KTV-Walls`. Only `build-room.rb` output (and anything
   `wr-split-walls.rb` has processed) has the upper band on its own tag. But
   granularity below the tag exists anyway: each band is its own named group
   (`Wall 3 (upper)`), which matters for the per-wall escape hatch below.
2. **`wr-split-walls.rb`** is, as suspected, "already most of this feature" — the
   retrofit half. Its recognizer is deliberately scoped to `build-room.rb`-shaped
   geometry; a `csusb-rooms.rb` model or hand-drawn walls will show as
   "skipped, by name" rather than be guessed at (observed — file header and
   `caps()`/`own_tag_ok?`). For such a model the honest path is: fix the grouping so
   walls are clean leaf extrusions, or accept full-height walls in that model.
3. **`wr-mode.rb` precedent** — yes: per-model snapshots of tag visibility, restored
   on toggle, tags-and-materials moving together (observed). Nothing to copy here
   though, because for wall lowering the *scene* is the right owner of the state, and
   scenes already own it natively.
4. **Does the repo rely on Page persisting tag visibility?** Yes — citations in
   point 3 of the decisive answer above.

## The options, weighed

| Option | Build cost | What Benton does | Fails at | Revert story |
|---|---|---|---|---|
| **A. Native per-scene tag visibility on the existing two-band walls (recommended)** | **Zero** | Untick `WR-Room-Upper` in the Tags tray, update the scene (details below). Once per backside scene. | Old models whose walls the splitter can't recognize; sill is one height for the whole model | **Nothing to revert** — no geometry ever moved; switching scenes restores the walls, and the proposal package switches scenes anyway |
| B. Horizontal section plane per scene | Small | Place plane, activate per scene | **Fatal at model root: the cut takes the booth's top off too** (derived — a root-level section cuts everything). A plane *inside* the room group cuts only the room, but activating a group-internal cut per scene is fiddly and easy to leave in the wrong state | Scene-saved, but the failure mode (booth beheaded, or cut left active) is silent in the viewport you're not looking at |
| C. Script-generated low twins (copy walls, scale, tag `WR Low Walls`, hide originals) | Medium | Run a generator, then manage twin+original tag pairs per scene | Twins drift when the room is edited; doubles the tag bookkeeping; solves a problem the two-band split already solved better (a band is a "twin" that can never drift) | Delete the copies — clean, but strictly more machinery than A for the same pixels |
| D. Render-time mutation inside proposal-package (push walls down per render row, restore after) | Large | Nothing extra per scene, but trusts the batch | **Weakens the tool's core guarantee**: the whole safety argument of `proposal-package.rb` is that model state changes only through `WR_Mode`, exactly twice, with one FINISH exit. Per-scene geometry edits happen N times, and a crash mid-row leaves edited geometry that an attribute dict can't describe how to un-edit | Worst of the four — this is the option the spec's own revert section exists to forbid |

Option A wins on every axis, and it is not a coincidence — the two-band work was
built *for* this exact render case (its own comments say "ventilation render" /
"see into the room"). Benton's backside-of-the-booth case is the same case from a
different azimuth.

## The recommendation: no new code — a three-step workflow

**For a new room** (drawn with `build-room.rb`): nothing to do at build time — the
two bands are automatic; set the "Wall split (sill)" field if 4'-0" isn't the height
he'd have lowered to by hand.

**For an existing model**: run *Split existing walls at sill (EDITS MODEL)* once,
read the dry run, then run it live. Anything it skips, it names.

**Per backside scene** (this replaces the manual lower-and-restore he does today):

1. Activate the scene (or frame the backside view and create it).
2. Window > Tags (or the Tags tray): untick **`WR-Room-Upper`**. The walls drop to
   the sill stub in the viewport — what you see is what exports.
3. Update the scene. **Use the Scenes tray's update button and, in the "Properties
   to update" dialog, tick only *Visible Tags* (plus *Hidden Geometry/Objects* if
   offered) when the camera has been orbited since the scene was saved** — a
   blanket right-click Update also re-saves the current camera and would silently
   re-frame the scene (reported — standard SketchUp scene-update behaviour, not
   verified in this repo). Then re-tick `WR-Room-Upper` so live modelling continues
   with full walls; the scene keeps its own saved state.

Then mark the scene Render or Image in the proposal package as normal. No change to
`scripts/proposal-package.rb`, no change to its spec, nothing new to revert.

**Per-wall escape hatch, still native**: if one flanking wall should stay full
height while only the back wall lowers, don't touch tags — instead open the walls
group, right-click just `Wall n (upper)` > Hide, and save the scene with hidden
objects. Pages save hidden-object state alongside tag visibility (reported —
SketchUp scene properties; this repo does not exercise it anywhere I found). Coarse
tag first, per-group hide only when a scene actually needs the asymmetry.

## The v2 helper, sketched but deliberately NOT recommended yet

If the scene-update dance in step 3 proves error-prone in practice (the camera-bake
footgun is real), the right-sized fix is a ~60-line toggle, not a wall UI:

- File: `scripts/scene-lower-walls.rb`, `# @title Lower walls on this scene`,
  `# @cat V-Ray renders`, module `WR_SceneLowerWalls`.
- What it does: on the selected page — flip `model.layers['WR-Room-Upper'].visible`,
  then write **only** the layer-visibility property back to the page
  (`page.update(PAGE_USE_HIDDEN_LAYERS)` — reported API, the flags-arity `update`
  exists precisely to avoid re-saving the camera; verify the constant name against
  the live API before building), then restore the live visibility to whatever it was
  so modelling state is untouched. Refuse by name if the tag doesn't exist ("run
  build-room.rb or the wall splitter first") or no scene is selected.
- Defaults: acts on the selected scene only; no inputs; pressing it again un-lowers.
- Revert story: same as option A — it only ever writes a page property, never
  geometry; Ctrl+Z inside one `start_operation` undoes the page write.

Build it only after Benton has used the manual workflow on a real proposal and asked
for the shortcut. Building it now would be scope creep past a native feature he
hasn't tried yet.

## If the simulation image he mentioned arrives, check

- Whether his hand-lowered walls stop at roughly waist/sill height (validates the
  48" default) or at booth-top height minus a bit (would argue for a taller
  per-model sill — it's a dialog field either way).
- Whether *all* host walls are lowered or only the one behind the booth (decides how
  soon the per-wall hidden-object hatch matters).
- Whether the lowered wall still shows a top cap / thickness in the render — the
  band split leaves a capped stub (derived from `quad`'s pushpull), which should
  match; if his manual version bevels or opens the top, that's a look difference to
  ask about.
- Whether the floor outside the room appears — if his manual workflow also hides the
  host floor beyond the stub, that's a separate tag decision, not covered here.

## Open questions / risks (also in HANDOFF-wall-lowering.md)

1. **V-Ray honoring hidden tags per activated scene** — assumed; fold into the first
   proposal-package live run: one backside scene with `WR-Room-Upper` off, marked
   Render, and eyeball the frame.
2. **48" sill as the lowered height** — inherited guess from the two-band work;
   Benton's image or first use settles it. Changing it per model is a dialog field;
   changing it on an already-built room means re-running the splitter is NOT enough
   (bands are already cut) — rebuild the room or move the cut by hand. Worth saying
   to him once.
3. **Two-band walls have never been seen on screen** — the entire mechanism this
   leans on is parsed-not-run (reported, `.forge/builder/HANDOFF-c.md`). The
   recommendation stands on code that must still pass its own first live build.
4. **Old client models** (`csusb-rooms.rb`-style walls, hand-drawn walls) are
   outside the splitter's recognizer by design; those either get regrouped by hand
   first or keep full-height walls.
