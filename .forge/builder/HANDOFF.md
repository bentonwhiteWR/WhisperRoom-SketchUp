# HANDOFF — Builder → Benton: the ground lift, 1.33.0

2026-09-10. Benton: *"I think whenever we bring in a booth via the link, its
too low. It should be shifted up 1" for standard, or 1 5/16" for enhanced."*
**Cause identified; his numbers fall out of it. Unrun in SketchUp.**

## Cause (observed)
- `wr-deck.rb:76-87`: `DECK_TOP_Z = 0.0` — deck TOP on the wall plane, "the
  floor hangs below it, into the host floor", with the honest alternative
  named and deferred.
- Every FL part is a 1.000" slab z 0→1 (`reference/floor-ceiling-geometry.md`).
- `iep_deck` (build-booth-components ~1097): IEP mat, 0.3125 thick, placed at
  `host.min.z` — under the standard floor.
- So the floor stack bottomed at −1.000 (S) / −1.3125 (E). Not a coincidence.
- `WR_Overlays.booth_lift` already lifted the group for casters only; its
  no-caster 0.0 was a pinned contract (`rbtest-overlays.py`).

## Produced
- `scripts/wr-overlays.rb`: `booth_lift(casters, fl_bottom, stack_bottom =
  fl_bottom)` — casters unchanged, no casters `−stack_bottom`. `place_casters`
  no longer applies the transform (reports only). `place_all` returns
  `[placed, warns, casters_in]`.
- `scripts/build-booth-components.rb`: measures `fl_bottom` (standard floor
  bounds) and `stack_bottom` (min with the IEP deck's bounds); a **GROUND**
  pass after the overlays applies the lift once to the group; flags a
  no-caster lift ≠ 1.0/1.3125 by name; refuses to lift without a measured
  floor. `DECK_TOP_Z` untouched.
- `scripts/rbtest-overlays.py`: pins `1.0000 1.3125 -3.25 on 5.75 5.75`;
  leak scan inverted (one apply site in `build_booth`, none elsewhere).
- `scripts/rbtest-live-booth.py`: `ground_lift` / `stack_bottom` fields;
  `missing` regex fixed for the 1.25.0 wordings (regression from my earlier
  change today).
- Comments: `wr-deck.rb` (DECK_TOP_Z), `dimension-booth.rb` (BASE_Z).
- `VERSION` → **1.33.0** (minor). DEVLOG entry.

## Answers to the three questions
- **Already drawn?** Yes — every booth built before 1.33.0 sits 1" / 1 5/16"
  low. Re-import moves everything inside the group (walls, decks, seals,
  foam, options, ramp, plates, placeholders). Left behind: dimensions from
  `dimension-booth.rb` / `dimension-selection.rb` (model space — redraw),
  the room, screen notes, scene cameras.
- **Ramp / caster plate?** Ramp is geometry inside `…WADoorWithRamp.skp`,
  inside the group — moves. Plates are placed into the group and the caster
  lift is the same function's other branch — consistent by construction.
  Open (pre-existing): Enhanced + casters puts the mat 5/16 into the tray.
- **Exterior height?** Unchanged: a pure z translation of the group; every
  booth-local figure and print is identical to before.

## Assumptions (not observed)
- `Group#transformation=` composes as documented (the caster code used the
  same line since 1.9.x and Benton has built with casters).
- `union_bounds` of the IEP deck instances includes the mat's underside (it
  is the group-space bounds of the placed instances — same call `host`
  already relies on).

## To verify (Benton)
1. Link-import a **Standard** booth. Console: `GROUND  booth lifted 1.0000 -
   floor stack underside was -1.0000 … now 0.0000`. Tape from the room floor
   to the floor panel's underside: **0**; to the walls' underside: **1"**.
2. Link-import an **Enhanced** booth: `GROUND  booth lifted 1.3125`. Mat
   underside on the floor: **0**; standard floor underside: **5/16"**; walls'
   underside: **1 5/16"**.
3. Measure overall height, floor underside to ceiling top, on each — must
   equal the pre-1.33.0 figure (e.g. the 96120 E's drawn 7'-0 5/16").
4. A casters link: `caster datum: … will lift the booth 5.7500` then
   `GROUND … (caster datum)`; plate bottoms on the floor as before.
5. Run *Dimension this booth*: the height dimension should start at the floor,
   not an inch under it.

---

# HANDOFF — Fixer → Benton: SUN column, 1.27.0

2026-09-10. *"saving the sun from the light from here ... reset every time
we are playing with a scene"*. Built, **unrun in SketchUp**. Needs
`install-plugin.py` + restart (one `main.rb` SKIP entry).

## What was actually happening (read, not run)
- Light it from here writes the model's **live** sun only. Every scene
  **saves its own** sun (shadow settings ticked — the default) and puts it
  back the moment you click it. Nothing ever saved the aimed sun into a
  scene. Not "not saving" — saving too well.
- It is the **SketchUp** sun (direction). V-Ray's sun *intensity* is a
  different knob (`.forge/fixer/sun-blowout.md`) and is not touched here.
  If a V-Ray render does not follow the viewport sun, tell me — that is a
  different complaint.

## The column
- `☀ Sun` left of WALLS. The card shows the scene's **saved** sun and the
  sun that was in the **viewport when you opened it** (read before the
  scene is selected, because selecting is what resets it).
- **SAVE THAT INTO THIS SCENE** — the viewport sun, into this scene.
- **AIM FROM THIS SCENE'S CAMERA** — Light it from here from the scene's
  own camera (offset / match height / height), saved into this scene.
- **APPLY TO ALL SCENES** — this scene's saved sun into every scene shown.
  Asks by name. **UNDO LAST APPLY** puts it back; Ctrl+Z will not.
- FIX SCENES appears when any scene has shadow-settings saving off.

## Produced
- `scripts/wr-scene-sun.rb` (new library). `scripts/proposal-package.rb`:
  loads, `sun_payload`, six callbacks, column, card, JS, undo coverage.
  `scripts/wr_tools/main.rb`: SKIP. `VERSION` → **1.27.0**. DEVLOG.

## To verify (Benton) — "does it stick" is the check
1. Light it from here on any view. Open the package, `☀ Sun` on scene 3:
   "In the viewport when this opened" shows that sun; "Saved in this
   scene" shows the old one. SAVE THAT INTO THIS SCENE. Click scene 1,
   then scene 3: **the aimed sun is back on 3.** That is the fix.
2. AIM FROM THIS SCENE'S CAMERA on scene 5: log names the bearing; the
   viewport sun moves; click away and back — it stays.
3. APPLY TO ALL from scene 3: confirm; click three tabs — same sun. UNDO
   LAST APPLY beside Rescan → each has its old sun again.
4. Do a V-Ray render of a scene you saved: does the sun follow? Tell me
   either way — it decides whether this closes the complaint.

---

# HANDOFF — Builder → Benton: dimension font settled, 1.26.3

2026-09-10. Your question: *"so it matches all the text, but not the
dimensions. No way to achieve that then, huh?"* **Unrun in SketchUp.**

## The answer (reported, cited in the DEVLOG)
There is one dimension font per model — Model Info › Dimensions › Fonts —
and Ruby can neither read nor write it. Not per entity (`Sketchup::Dimension`
has no font method), and not through `model.options` either: the only
documented provider is `UnitsOptions`, and the request for a
`DimensionsOptions` provider (`api-issue-tracker #224`) has been open since
March 2019. So: the tool sets every NOTE's font, and for DIMENSIONS it now
tells you the exact value to set once in Model Info and opens that panel.
That is one setting for every dimension in the model — which is the
uniformity you asked for — it just cannot be limited to a selection.

## Changed — `scripts/wr-callout-style.rb`
- Status after Apply, when dimensions are ticked with a font: *To match,
  set Model Info > Dimensions > Fonts to Arial 12 regular — one setting for
  EVERY dimension in the model, not just this scope.*
- New button **Open Model Info › Dimensions** (`UI.show_model_info`).
- Header line *dimension font: Model Info only (N option providers probed,
  none carry it)* — a live probe, so if a future SketchUp adds the
  provider the header says so instead of this note going stale.
- `VERSION` → **1.26.3** (patch). `rbtest-callout-style.py` 41 checks.

## To verify (Benton)
1. Open the tool: second header line should read *dimension font: Model
   Info only (… probed, none carry it)*; the Ruby Console prints the
   provider names — I expect UnitsOptions, PageOptions, SlideshowOptions,
   NamedOptions, PrintOptions or similar; if anything with *dimension* in
   the name appears, tell Claude.
2. Apply with defaults: the status ends with the *set Model Info >
   Dimensions > Fonts to Arial 12 regular* line.
3. Press **Open Model Info › Dimensions**: Model Info should open on the
   Dimensions page. Set Fonts to Arial 12 there — every dimension follows.
   If the button opens Model Info on a different page, tell me which.

---

# HANDOFF — Fixer → Benton: scene number in front of the file, 1.26.2

2026-09-10. *"one underscore overview"*. Shipped, **unrun in SketchUp**;
the naming itself is proven offline (`rbtest-proposal.py` pn1-6).

## What you get
- `1_Overview.png`, `2_Plan render.png` — the table `#` in front, then
  the scene name. **Padded past nine scenes:** `01_Overview.png` …
  `13_….png` on PeoplesSpace, because `10_` would otherwise sort between
  `1_` and `2_` and the folder would not be in order — the thing you
  asked for. Nine scenes or fewer keep your literal form.
- FILE IT WILL WRITE shows the real name before you export.

## Know this
- **Reordering scenes renames the files.** Re-export into the same folder
  after a drag and the old-numbered files stay next to the new ones —
  EXISTS? only looks at names it is about to write. Export into a fresh
  folder after a reorder, or delete the old set by hand.
- Nothing downstream lists the folder: `build-v2.js` and every
  `proposal-v2.json` name files explicitly, so nothing breaks; new packs
  just reference the new names.

## To verify (Benton)
1. Open the proposal package on PeoplesSpace: the FILE column reads
   `01_…`, `02_…`. Export two Image rows; the folder shows those names
   and Explorer sorts them into scene order.
2. Drag a scene to a new position; the FILE column renumbers with it.

---

# HANDOFF — Fixer → Benton: UNDO LAST APPLY, 1.26.1

2026-09-10. Benton: *"add an undo button too"*. Built on a snapshot taken
before every apply, NOT on SketchUp's undo stack. **Unrun in SketchUp.**

## What it does
- Every apply (this scene / all scenes, walls / annotations, popover /
  standalone) records, per written scene, what the written rows were
  before — read with that scene selected. **UNDO LAST APPLY** selects each
  of those scenes and writes that back through the normal save path.
- **One step, this SketchUp session, this model.** Survives closing the
  picker and the package window. Refused on another model. Used up when
  pressed (press APPLY again for a redo). Not covered: the "Hide/Show
  selection" buttons.

## Where
- Package window: `UNDO LAST APPLY` beside Rescan (grey = nothing
  recorded; hover = what it would put back, on which scenes, when).
- Standalone walls / annotations dialogs: `Undo last apply` in the foot.
- Confirm boxes and Apply-to-all tooltips now point at it.

## Produced
- `scripts/wr-scene-walls.rb`, `scripts/wr-scene-annotations.rb`:
  `last_write`, `remember_write`, `snapshot_keys`, `undo_summary`,
  `write_snapshot`, `undo_last`; `apply` / `apply_all` record; `state`
  carries `undo`; button + `undolast` callback.
- `scripts/proposal-package.rb`: `undo_mod` / `undo_info` / `push_undo`,
  `undolast` callback, `state['undo']`, button, `drawUndo` / `setUndo`.
- `VERSION` → **1.26.0**. DEVLOG entry.

## To verify (Benton) — the put-back is the load-bearing check
1. Hide notes on scene A: tick a set and one loose callout → APPLY. Note
   the package log line. `UNDO LAST APPLY` lights up; hover: names A.
2. Press it. Log: `Put back the saved annotation answer on 1 scene(s): A`.
   Click A: the set and the callout are showing again. The button greys.
3. APPLY TO ALL with a wall ticked: confirm box now says UNDO LAST APPLY
   puts it back. Yes. Click two scenes: wall hidden. `UNDO LAST APPLY`
   hover: names every scene written. Press. Click the same two: wall
   back as it was on each (a scene that already hid it stays hidden).
4. Open a different model: the button is grey; hover says nothing
   recorded. Back on the first model it is grey too — it was used up.

---

# HANDOFF — Builder → Benton: uniform callout font & colour, 1.26.0

2026-09-10. New tool `scripts/wr-callout-style.rb` (TOOLS tab, *Tidy up the
model*): one dialog that puts one font and one colour on every note,
dimension and 3D label, or just some of them. **Unrun in SketchUp.**

## The truth per kind (reported — ruby.sketchup.com + forum, today)
- **Notes** (`Sketchup::Text`): font settable **only on SketchUp 2026.2+**
  (`Text#font=`; you are on 26.2.243, so yes); colour via `material=`.
- **Dimensions**: colour via `material=` — **font is NOT settable from
  Ruby**, no version, no options provider. The dialog says so, counts every
  dimension as a font skip, and names the manual route: *Model Info ›
  Dimensions › Fonts › Select all dimensions › Update*.
- **3D labels**: colour only (material on the group). The face is geometry.

## Produced
- `scripts/wr-callout-style.rb` — dialog: What (kinds, live counts) /
  Where (whole model default, my selection, one set) / Font / Colour;
  Apply = one undo; Match-majority links; House default button;
  last-used values persist per user. Reuses `WR_SceneAnnotations.kind_of`,
  `each_annotation`, `tag_of` — no second definition of "annotation".
- `scripts/rbtest-callout-style.py` — 37 checks on the two pure methods,
  mutation-checked.
- `VERSION` → **1.26.0** (minor: new tool). DEVLOG entry.

## Assumptions (not observed)
- `material=` on a `Sketchup::Text` colours the text the way Entity Info's
  swatch does. Confirmed on the forum for a dimension; text is the same
  Drawingelement contract. If it colours only the leader, say so.
- `Sketchup.write_default` round-trips `true`/`false` for bold/italic.
- Materials named `WR-Callout #hex` show in the materials list; harmless.

## To verify (Benton)
1. `git pull`, `install-plugin.py`, restart. Panel → TOOLS → *Tidy up the
   model* → **Uniform callout font & colour**. Header should read your
   SketchUp version and `text fonts: yes`; the three counts should match
   what *Hide notes & dimensions per scene* lists.
2. Leave everything default, press **Apply**. Every note should turn Arial
   12 orange; every dimension and 3D label should turn orange with the
   status reading `Skipped N: dimension font is not settable…`. Nothing
   else in the model should change. **One Ctrl+Z** puts it all back.
3. Set colour to black, untick Notes, Apply: only dims + labels change.
4. Select one note, choose *My selection*, size 18 bold, Apply: only that
   note changes.
5. Type `#zz` in the hex box and Apply: refused in red, nothing changed.

---

# HANDOFF — Fixer → Benton: Ctrl+Z never undid a scene write, 1.25.2

2026-09-10. Two reports, one cause. **Unrun in SketchUp.**

## The finding (observed by reading + your field test)
- **A scene snapshot is outside SketchUp's undo.** `Page#update`,
  `set_visibility`, `use_hidden_*=`: no undo note in the API; the only
  undo statement on `Page` (2026.0 release notes) names Axes, Camera,
  RenderingOptions, ShadowInfo. Your "ctrl+z didn't work" is the proof.
- **Ctrl+Z after an apply is worse than nothing:** it reverts the
  entities' hidden FLAGS (on the stack) and leaves every snapshot as
  written. The viewport shows the notes back; the next scene click hides
  them again. If a picker is opened in that state its ticks read cleared,
  and APPLY then snapshots the cleared state for real.
- **Drag-to-reorder writes no visibility** (`reorder` → `reorder_scene` →
  `pages.reorder` → `push_state`; reads only). The "reset" you saw is the
  Ctrl+Z the log line and my verify step told you to press. Walls,
  objects, notes, MODE, EV and camera all ride the page object, which
  `Pages#reorder` moves. Reasoned, not run — see the test below.

## Changed (text only, no behaviour)
- `scripts/wr-scene-walls.rb`, `scripts/wr-scene-annotations.rb`:
  `confirm_all?` box, `apply_all` message, Apply-to-every-scene title.
- `scripts/proposal-package.rb`: both popover Apply-to-all titles,
  `allScope()`, the reorder log line ("Drag it back to reverse it").
- `VERSION` → **1.25.2**. DEVLOG entry.

## PeoplesSpace — what is recoverable
- The apply-to-all you pressed: **gone from the session.** Re-author per
  scene, or reopen the last `.skp` / `.skb` saved before it.
- Scenes you only reordered: **nothing lost.** Click each tab; what it
  saved comes back. Do not press Ctrl+Z after a drag — drag it back.

## To verify (Benton) — the one check that matters
1. Any model: Hide notes on scene A → tick one note → APPLY. Click
   another scene, then drag A's row to a new position. **Do not press
   Ctrl+Z.** Click A: the note is still hidden → reorder is lossless.
   If it is showing → `Pages#reorder` is lossy: tell me, the drag
   feature comes out.
2. APPLY TO ALL: the confirm box now says Ctrl+Z will not put it back.

---

# HANDOFF — Builder → Benton: ANNOTATION defaults to Per scene, 1.25.1

2026-09-10. The PeoplesSpace Revision pack exported stripped because the
ANNOTATION dropdown defaulted to Client-safe. Benton: *set the default to
Per scene.* Shipped, **unrun in SketchUp**.

## What I found
- **Persisted per user, not per model**: `Sketchup.write_default(PREF,
  'annot', …)` in `start_run`, written on every export. A stored `client`
  is indistinguishable from the old default written through. Left alone.
- **Consequence you must know:** on this machine the registry already
  holds `client` (from this morning's export). **Set the dropdown to Per
  scene once by hand**; it sticks for every model on the machine. A machine
  that has never exported gets Per scene automatically.

## Changed — `scripts/proposal-package.rb`
- `run`: read-default / rescue / normalise → `draft`.
- `start_run`: `client_safe = cfg['annot'] == 'client'`; write-through maps
  anything else to `draft`; a one-line red log warning names exported
  scenes matching `dim|note|text|label|info|callout` when Client-safe is on.
- Dropdown: Per scene first and selected unless `client`; both labels and
  the helper paragraph rewritten; factual Client-safe detail kept.
- `VERSION` → **1.25.1** (patch). DEVLOG entry.

## To verify (Benton)
1. On this machine: open the tool, set ANNOTATION to **Per scene** once.
   Export `InteriorDims` as an image; open the PNG: dimensions present.
2. On a machine that has never exported (or after clearing the
   `WR_ProposalPackage` key): the dropdown should read Per scene on open.
3. Set Client-safe and export a `*Dims` scene: the log's first line should
   name it in red; the PNG is stripped, as chosen.

---

# HANDOFF — Builder → Benton: build around parts not authored yet, 1.25.0

2026-09-10. Benton: *"when trying to pull in a 102102 E with WA, it couldn't
find a couple of components. Those components are not in yet, id still like
for you to import even though it was missing a few pieces."* **Unrun in
SketchUp.**

## What his case actually is (observed)
- The portal writes `'STDWL7 / WL16'` for the 7" WA companion on a 40-series
  booth (`WhisperRoomQuote/booth-builder.html:3935` `shrinkPack`, `:3724`
  code C7; `lib/packing-list.js:1135` — Z02 is a 7 + 16 bundle, the 7 stands
  in the slot). `component_for` had no branch → `odd` for `S1` and `S1i` →
  `ENH_MISSING_ABORTS` refused. That is the "couple of components".
- Translated: outer `7Panel` (on P:), inner `ENH 2.5Panel` — the width the
  inner S wall closes on beside `ENH RightWADoor`, measured 44.5 wide in
  `P:/…/_enhanced-probe.tsv` (44.5 + 6.5 + 2.5 = 35.5 + 6.5 + 11.5).
  **`ENH 2.5Panel.skp` is not on P: as of today** (435 files listed; no
  `ENH 2.5…` at all). That is the not-authored part.

## Produced
- `scripts/build-booth-components.rb`: `missing` (structurally wrong — still
  a hard refusal) vs `absent` (file not on the share — consent box,
  `MB_YESNOCANCEL`, only `IDYES` builds; `cfg['missing'] == 'placeholder'`
  for bridge jobs; dry runs not asked). `absent_width`, `add_placeholder`,
  `missing_material`; constants `MISSING_DICT`, `MISSING_TAG`,
  `PLACEHOLDER_*`. Absent rows stay in `rows` for `rebalance_walls`; overlays
  get `rows.reject { absent }`. Booth group renamed `… INCOMPLETE - N part(s)
  missing`, attribute `wr_booth_components/missing`, loud console block,
  `warn` carries the list.
- `scripts/booth-from-link.rb`: `component_for` branch for
  `%r{\ASTDWL7\s*/\s*WL16\z}i`; inner gaps now `assign[sid] = base`;
  the ENH refusal only fires on `odd` (untranslatable). `ENH_MISSING_ABORTS`
  comment rewritten to say why.
- `scripts/wr-preflight.rb`: sixth row **Booth has every part**
  (`check_complete`), not fixable.
- `scripts/rbtest.py`: `fixture_absent` / `check_absent`, lifts
  `absent_width` verbatim. `scripts/rbtest-boothlink-cbl.py`: group 6.
- `VERSION` → **1.25.0** (minor). DEVLOG entry.

## Decisions (why)
- **Two kinds of miss.** A wrong part in a slot renders as a right one, so
  `missing` is never built around. An absent file has a known identity, so
  it can be — with consent and a visible stand-in.
- **The signal must survive client-safe.** `WR-Booth-Missing` is outside the
  `WR-Dims`/`WR-Notes` family on purpose (`proposal-scenes.rb annot_tags`
  matches only that family). Orange geometry + a 3D-text label are geometry,
  not notes; the group NAME reaches the manifest's `booth_groups` unchanged.
- **One dialog, complete list.** booth-from-link no longer refuses on gaps;
  the builder's gate sees every absent file (assigned or guessed) and asks
  once.
- **Inner gaps are assigned.** Unassigned, `guess_component` would stand an
  *existing* `ENH 11.5PanelSolid` in the 2.5 slot — the silent wrong part
  this repo exists to stop.

## Assumptions (not observed)
- `Entities#add_3d_text` signature `(string, align, font, bold, italic,
  letter_height, tolerance, z, filled, extrusion)` and that it authors along
  +X in XY at the group origin; `Group#transform!`; `Material#alpha=`.
  Wrapped in nothing — a wrong signature will raise inside the operation and
  abort the build loudly, which is the right failure.
- `MB_YESNOCANCEL` returns `IDYES` on Yes; Escape returns `IDCANCEL`.
- `booth.set_attribute` accepts an Array of Strings (documented).

## Downstream (checked)
- `proposal-package.rb`: `booth_groups` records the INCOMPLETE name;
  `booth_name?` still matches on `MDL`. The client-safe pass does **not**
  hide the tag. **Not wired, follow-up:** a manifest field naming the absent
  parts, and a refusal/warning in the package when a booth group carries
  `wr_booth_components/missing`. Small, but that file is the other agent's
  today.
- `wr-preflight.rb`: wired (row 6).
- Bridge (`rbtest-live-booth.py`): a booth with absent parts still raises
  `ModalBlocked` on a real build unless the job passes
  `'missing' => 'placeholder'`; dry runs now report ABSENT instead of
  raising.

## To verify (Benton) — the real 102102 E with WA link
1. Panel → **Build from booth-builder link** → paste the link. Console:
   `S1     7Panel  <- STDWL7 / WL16` and `S1i    ENH 2.5Panel  <- …`, then
   the `!!!` block "1 component file(s) DO NOT EXIST … S1i … ENH 2.5Panel.skp".
2. A **YES / NO / CANCEL** box listing `S1i  ENH 2.5Panel.skp`. Press **No**
   once: nothing is built. Run again, press **Yes**.
3. In the model you should SEE: a **bright orange slab** ~2.5" wide, full
   inner-wall height, standing proud of both faces, right beside the inner
   wide-access door on the S wall; a flat orange **"MISSING ENH 2.5Panel.skp"**
   label ~1 ft above the wall top over that slot (look from above); in
   **Outliner** the group named `MDL 102102 E (components) INCOMPLETE - 1
   part(s) missing`, containing `MISSING  S1i  ENH 2.5Panel.skp`; in
   **Tags** a `WR-Booth-Missing` tag.
4. The outer S wall should read `S0 RightWADoor` 49 wide + `S1 7Panel`, seal
   shifted 9 in (console `rebalanced` lines); the inner S wall
   `S0i ENH RightWADoor` 44.5 + seal + the 2.5 placeholder, closing on the
   original end (no "does not close" line for S inner).
5. **Pre-render checklist**: *Booth has every part* is red and names the
   file.
6. Proposal package, client-safe export: the orange slab and label are still
   in the image. If they are not, that is a defect — report it.

---

# HANDOFF — Builder → Benton: live preview in the pickers, 1.24.0

2026-09-10. Benton: *"Once we select a checkbox, go ahead and have it hidden
so that we can verify before we press Apply to the Scene."* Shipped in
**both** pickers (annotations = the ask; walls fell out of the shared
structure). **Unrun in SketchUp.**

## Produced
- `wr-scene-walls.rb`, `wr-scene-annotations.rb`: `preview_snapshot`,
  `preview_show(snap, picks)`, `preview_restore(snap)` — flags only, no
  `page.update`, no operation.
- `proposal-package.rb`: `@preview` state (`preview_begin` / `preview_show`
  / `preview_end` / `preview_op`), `wallspreview` + `annotspreview`
  callbacks, `preview_end` hooks in wallsclose, annotsclose, wallsopen,
  annotsopen, wallssel, wallsapply, wallsapplyall, annotsapply,
  annotsapplyall, annotsmove, and a new `d.set_on_closed`. JS:
  `wallsPreview()` / `annotsPreview()` called from every tick path (change,
  all/none links, USE MY SELECTION). Walls strip text now says the viewport
  is live.
- `VERSION` → **1.24.0** (minor). DEVLOG entry.

## Decisions (why)
- **Restore-then-apply**, not apply-from-preview: keeps `apply` computing
  from a clean baseline with its own operation, unchanged from before.
- **Baseline at open, full pick set per tick**: no per-click drift.
- **Transparent ops after the first**: one undo step per session. Holding
  an op open across callbacks would eat viewport edits on CANCEL.
- **Dirty flag after a tick is not avoidable**; no-tick sessions stay clean.

## Assumptions (not observed)
- `set_on_closed` fires on the X with a popover open (dialog-level event).
- `start_operation(name, true, false, true)` merges as the API documents.
- `active_view.refresh` repaints a flag change (existing precedent).

## To verify (Benton) — the restore is the load-bearing check
1. **Hide notes** on a scene → tick three rows → each vanishes in the
   viewport as you tick; untick one → it returns.
2. **CANCEL** → all three back. Reopen the picker: ticks match the scene's
   saved answer, unchanged. **Ctrl+Z once**: nothing visible should change
   (the session was one net no-op step).
3. Tick two → close the whole window with its **X** → both back in the
   viewport. Reopen the package: saved answer unchanged.
4. Tick two → **APPLY TO THIS SCENE** → brief flicker is fine; both hidden;
   switch scene and back: still hidden (saved). Ctrl+Z once → shown again.
5. Same four steps in **Hide walls**; also tick one, then **HIDE SELECTED**
   on something else: the previewed tick should NOT have been saved.
6. Start an export, open a picker (it should refuse) — no preview mid-run.

---

# HANDOFF — Builder → Benton: drag-to-reorder scenes, 1.23.0

2026-09-10. Benton: *"id like to be able to drag and drop scenes to reorder
them"* — the REAL SketchUp scenes, undoable, not a package-only order.
Shipped, **unrun in SketchUp**.

## Feasibility — the answer is yes, natively
`Sketchup::Pages#reorder(page, new_index)`, **SketchUp 2025.0+**, verified
verbatim on ruby.sketchup.com/Sketchup/Pages.html (reported, not run):
moves an existing page, 0-based, `IndexError` out of range. `Pages#add`'s
index only places a NEW page; `Page` has no writable index. Nothing in
`reference/` or the repo's probes had ever touched page order.

Three options, ranked:
1. **Native `reorder` — built.** Non-destructive by construction.
2. Package-only export order — certain, declined by Benton, not substituted.
3. Capture/rebuild/restore — **unsafe**: camera, style, shadow_info,
   rendering_options, hidden_entities, layers, section planes are readers
   whose only writer is `Page#update` from the live view; fog and per-page
   rendering deltas are not enumerable. Rejected.

## Produced — `scripts/proposal-package.rb`
- `reorder_scene(model, from, to)` beside `gather`: guard for the API,
  range checks that point at Rescan, one `start_operation('Reorder scene')`,
  result re-read from the model and reported (`Moved "X" from scene 3 to
  scene 1. Ctrl+Z reverses it.`).
- `reorder` callback (`busy?` guarded) → `reorder_scene` → log →
  `push_state` (always from the model).
- JS: rows `draggable` only when `!running && view.length === ST.rows.length`;
  `wireDrag()` with dragstart/over/leave/drop/end; drop computes the final
  1-based position and sends `{from, to}`; no optimistic reorder.
- CSS: `cursor:grab` on the `#` cell, `.dragging`, `.over-above`,
  `.over-below` in `var(--accent)`. No new colour.
- `VERSION` → **1.23.0** (minor). DEVLOG entry.

## Assumptions (not observed)
- `pages.reorder(pg, i)` leaves the page at index `i` (docs: "the new
  position of the page"). If it differs, the log says so and the table is
  right regardless.
- The reorder is recorded on the undo stack when wrapped in an operation.
- CEF in SketchUp 2026's HtmlDialog supports HTML5 drag events on `<tr>`
  (it is Chromium; the walls dialog already relies on modern DOM APIs).

## To verify (Benton) — the state-survival check is the one that matters
1. Proposal package: set scene 3 to RENDER, give it hidden walls and a
   hidden annotation set. Drag its row (grab the `#`) above scene 1.
   Expect: the table renumbers with it as scene 1, the FILE column
   renumbers, the log reads `Moved "…" from scene 3 to scene 1`, and the
   SketchUp scene tabs show the same order.
2. It still shows RENDER; **Hide walls** and **Hide notes** on its new row
   show the same ticks; clicking it shows the same camera.
3. **Ctrl+Z once** → tabs and table back to the old order.
4. Type a search: `#` cells lose the grab cursor, tooltip says to clear it.
5. Start an export: no drag while it runs.

---

# HANDOFF — Builder → Benton: singleton proposal package, 1.22.1

2026-09-10. Benton: *"If i re-click the proposal package right now, it opens
it again… Id like for that to just act as a refresh."* Shipped, **unrun**.

## The crux, answered (observed by reading)
`wr_tools/main.rb` `run(path)` → `load path`. A reload reopens the module;
module ivars survive (`@running` already depends on it). `@dlg` survived
too — `run()` never checked it. **"Never checked" fix, not "lost handle".
No `main.rb` change, so no `install-plugin.py` / restart needed** — a
`git pull` is enough on a machine that loads scripts live from the checkout.

## Produced — `scripts/proposal-package.rb` only
- `dialog_alive?(dlg)` — `visible?` under `rescue Exception`.
- `refocus_open_dialog` — `bring_to_front`, log `REFRESHED…`, then clicks
  the window's Rescan button via `execute_script` (reuses 1.21.1; skipped
  while the button is disabled). Running batch → forward only, logged.
- `run()`: singleton check after the no-scenes refusal, before the
  stale-batch block. `@model` stored beside `@dlg`; a live window on another
  model is closed and replaced (unless `@running`).
- `VERSION` → **1.22.1** (patch). DEVLOG entry.

## The five points
1. Stale/closed window: `visible?` false → opens clean; exceptions → false.
2. Bring to front: `HtmlDialog#bring_to_front`, same call the walls and
   annotations dialogs already use (repo precedent; SU 2017+ API).
3. Refresh reuses Rescan — no second mechanism; log says REFRESHED.
4. Mid-export: forward only, table untouched, one log line saying so.
5. Existing duplicates: cannot be closed by this — close them by hand once.

## To verify (Benton)
1. Open **Proposal package**. Press the tool button again → no second
   window; the open one comes forward; log shows `REFRESHED …` then a
   `RESCAN: N scene(s)…` line. Add a scene, press the button: new row.
2. Close the window. Press the button → opens clean, one window.
3. Start an export, press the button → comes forward, log says the table
   was left alone, export continues.

---

# HANDOFF — Builder → Benton: Apply to all scenes, 1.22.0

2026-09-10, after 1.21.1. Benton: *"would like for there to be an 'apply to
all scenes' button as well."* Shipped in **both** popovers and **both**
standalone dialogs, **unrun in SketchUp**.

## Produced
- `scripts/wr-scene-walls.rb`, `scripts/wr-scene-annotations.rb`:
  `apply` → wrapper over new `write_scene(page, picks)` (no transaction);
  `apply_all(model, picks, pages = nil)` → one operation, selects each
  page, writes, restores the start page, returns
  `[ok, msg, {:written, :unsaved}]`; `restore_page`; `confirm_all?(pages,
  what)` (UI.messagebox naming count + scenes + "REPLACED"). Standalone
  dialogs: **Apply to every scene** button, `collectPicks()` refactor,
  `applyall` callback.
- `scripts/proposal-package.rb`: **APPLY TO ALL N SCENES** in `#wfoot` and
  `#afoot` (non-prim, left of the orange APPLY TO THIS SCENE); `allScope()`
  sets the label from the table's `view` when a popover opens; `shownNs()`
  sends the shown indices; `wallsCollect` / `annotsCollect` refactors;
  Ruby `sweep_pages`, `log_sweep`, `wallsapplyall`, `annotsapplyall`
  callbacks with `busy?` guards.
- `scripts/wr_tools/VERSION` → **1.22.0** (minor: new module API + four
  dialogs). `DEVLOG.md` entry.

## Decisions to know about
- **Scope = scenes the table is showing** (bulk bar's SHOWN → rule), label
  says which; greyed when fewer than two are shown. Standalone = every scene.
- **Each page is selected before it is written** — not optional; see the
  `write_scene` comment. Writing an unselected page would stamp the current
  scene's non-row hidden state onto it.
- **Confirm lives in the callers**, `apply_all` is pure mechanism.

## Assumptions (not observed)
- `Page#update` is on the undo stack, so `abort_operation` and Ctrl+Z restore
  page snapshots. Reasoned from how per-scene apply is already undone.
- `selected_page=` inside an open operation is fine (selection is not an
  undoable model change). The per-scene path selects outside its operation.
- `UI.messagebox` from inside an HtmlDialog callback shows modally and
  returns; `browse` already calls `UI.select_directory` the same way.

## To verify (Benton)
1. Proposal package → **Hide walls** on scene 1, tick the booth, press
   **APPLY TO ALL 7 SCENES** (your count). Expect a Yes/No box listing the
   scenes and saying they will be REPLACED. **Yes** → popover goes green and
   closes, log shows `Saved to 7 scene(s)…` then one `written: "…"` line
   per scene. Click through the scenes: booth hidden on all.
2. **Ctrl+Z once** → booth back on every scene. This is the important one.
3. Same in **Annotations** with a set ticked.
4. Type a search that shows 3 scenes, open a popover: label should read
   `APPLY TO THE 3 SHOWN SCENES` and the box should list only those three.
5. Press **No** in the box: red "Not applied" message, nothing changed.
6. Standalone *Hide walls per scene*: **Apply to every scene** → same box,
   status line reads `Saved to N scene(s)…`, console lists each scene.
7. Regression: **APPLY TO THIS SCENE** and the standalone **Apply to this
   scene** behave as before.

---

# HANDOFF — Builder → Benton: Rescan button, 1.21.1

2026-09-10, later. Benton: *"lets add a 'refresh' button on the proposal
package UI at the top right or somewhere. So it loads in newly added scenes."*
Shipped, **unrun in SketchUp**.

## Produced — `scripts/proposal-package.rb`
- **Rescan** button in the `.top` header row, right of the scene count.
  Existing `.btn` class; no new CSS, no new colour.
- `rescan` action callback (above `activate`): `busy?` guard, then diffs the
  scene names the window sent up against `model.pages`, logs the result
  (`RESCAN: N scene(s) … new: … / no longer in the model: … / no change`),
  then `push_state`. Rebuild is the existing one — nothing new touches the
  model.
- `draw()` greys the button while `running`; the click handler also returns
  early on `running`.
- `scripts/wr_tools/VERSION` → **1.21.1** (patch: one control, one dialog).
- `DEVLOG.md` entry.

## The four risk questions, answered by reading (observed)
1. **MODE picks live on the page** — `set_mode` writes
   `page.set_attribute(DICT,'mode')`, `gather` reads `mode_of(page)`. A
   rescan cannot lose them; a renamed scene keeps its mode. EV likewise.
2. **Other state**: slot fills are on the model (`WR_MaterialsSwap`, redrawn
   by `drawMats`); folder / width / over / shade / annot inputs, the search
   box, the `.sect.open` classes and `$log` are DOM that `applyState`
   (`ST = st; drawMats(); draw();`) never touches. The search filter is
   simply re-applied to the new rows.
3. **Inert mid-batch**: `next if busy?(d, 'rescan')`, plus the greyed button.
4. **Deleted scene / open popover**: `#wwrap` and `#awrap` are
   `position:fixed; inset:0` overlays, so the header button cannot be pressed
   while a popover is open — blocked, not handled. A deleted scene drops
   off the table on rescan, which is exactly what the three "hit Rescan"
   raises were asking for. Those raises existed before the button did.

## Known edge (stated, not fixed)
- Scene-name diff uses `Array#-`, so deleting one of two scenes that share a
  name logs only a count change ("count went from X to Y (scenes sharing a
  name)"). The table itself is always right — it is rebuilt by index.

## To verify (Benton)
1. Open **Proposal package**. Set a few MODE picks, type something in the
   search box, minimise the MATERIALS section, browse to a folder.
2. In SketchUp add a scene (View › Animation › Add Scene) and rename another.
3. Press **Rescan** (header, right). Expect: the new scene appears as a row,
   the renamed one shows its new name **with its MODE intact**, the search
   text, folder and collapsed section are untouched, and the log reads
   `RESCAN: N scene(s) in the model -- new: … -- no longer in the model: …`.
4. Start an export and press Rescan mid-run: button is grey; if it somehow
   fires, the log says it was ignored because a batch is running.

---

# HANDOFF — Builder → Benton: create an annotation set from the dialog, 1.20.1

2026-09-10. Follow-up to 1.20.0. Benton: *"We added the dims annotations being
able to be hidden. I'd like for there to be a way to add an annotation set from
here."* Shipped, **unrun in SketchUp** — see Open questions.

## Produced

**Changed — `scripts/wr-scene-annotations.rb` only**
- `WR_SceneAnnotations.create_set(model, user_name)` — new class method,
  directly above the `apply` section and next to `move_selection_to_set`.
  Same `[ok, message]` convention, same `start_operation` /
  `commit_operation` / `abort_operation`-on-exception wrapper. Reads NO
  selection. Names via `WR_ProposalScenes.annot_set_name` (the one existing
  rule); empty/unnormalisable name refused by name; an existing tag is a
  `[true, …]` no-op saying so; otherwise `model.layers.add(name)` and the
  message names the REAL tag, which is usually `WR-Notes-<slug>` and not what
  was typed.
- `newset` action callback in `self.open`, wired exactly like `move`:
  `create_set` → `push_state` → `status`, unconditionally.
- `self.html` — a second full-width block inside the existing `#move` strip:
  label *"Create an empty set — no selection needed"*, the `WR-Notes-` prefix
  hint, `#cnew` (always visible, via the strip's existing `input.show` rule)
  and a `CREATE SET` button `#cgo`. Enter in the field clicks the button.
  One new CSS rule, `#move .lbl.two { margin-top: 10px; }` — spacing only, no
  new colour value.

**Changed — housekeeping**
- `scripts/wr_tools/VERSION` → **1.20.1**. Patch, not minor: this is one
  additive control inside an existing tool, no new tool, no change to the
  hide/show mechanism or to anything `proposal-package.rb` calls.
- `DEVLOG.md` — entry for 1.20.1 at the top.

## Read first
- `scripts/wr-scene-annotations.rb` header (lines 1–56) — why the tool is a
  hybrid, and why sets must stay inside the `WR-Dims*` / `WR-Notes*` family.
- `WR_ProposalScenes.annot_set_name` in `scripts/proposal-scenes.rb` (~line 92)
  — the single naming rule. Do not add a second one.

## Assumptions
- **assumed**: a freshly `model.layers.add`-ed tag is `visible?` → true, so
  `inventory` reports `hidden: false` and the row lands unticked. Derived from
  the code path, not observed in SketchUp.
- **derived**: the new set appears as a row on the next `push_state` because
  `inventory` builds a set row for every family tag present in
  `model.layers`, members or not (read at lines 219–251).
- **observed**: `python scripts/rbparse.py` → 68/68 files parse. That is a
  CRuby 3.2 syntax check and nothing more; it proves no behaviour.

## Open questions
- **Not run in SketchUp.** No `ruby.exe` here and no bridge to the SketchUp
  window. To verify, in Extensions → Developer → Ruby Console:
  `load "<repo>/scripts/wr-scene-annotations.rb"`, then
  1. type `Plan` in **Create an empty set** → **CREATE SET**. Expect status
     `Created WR-Notes-Plan — empty for now…`, a `WR-Notes-Plan` row under
     **Annotation sets** reading `empty`, unticked, and present in the move
     dropdown.
  2. **CREATE SET** on the same name again → "already exists … nothing was
     changed", list unchanged.
  3. Empty field → **CREATE SET** → "Type a name for the set first."
  4. Regression: the old **New set… + MOVE SELECTION INTO SET** path still
     moves a selection and still refuses an empty one.
- Should a just-created set be pre-selected in the move dropdown? Left alone
  deliberately — `push_state` rebuilds the strip, and guessing the next action
  was not part of the ask.

## Also in this session — clickable scene name, 1.20.2

`scripts/proposal-package.rb`. Benton: *"on the left side where it shows the
scene names, if I click the name, have it go to that scene in SketchUp."*
Wiring only — no new callback, no new mechanism.

- The scene-name cell is now
  `<td class='sc' data-go='<n>' title='Go to this scene in SketchUp'>` around
  the unchanged `hl(r.scene,hi)`, so the existing
  `querySelectorAll("[data-go]")` loop wires it alongside the row's `→`
  button. Ruby's `activate` callback is untouched.
- CSS: `td.sc { cursor:pointer }` + `td.sc:hover { color:var(--accent);
  text-decoration:underline }`. `--accent` is the variable `.go button:hover`
  already uses; no new colour.

**The two things I was told to check rather than assume — both checked
(observed, by reading the code):**
1. **Inert during an export.** `activate` begins `next if busy?(d, 'activate')`
   (~line 3136) and `busy?` (line 2931) returns true whenever `@running`,
   logging the reason into the window. The name cell calls the same callback,
   so it inherits that guard exactly. The JS-side `if(running) return;` used
   by the mode/walls/notes handlers is intentionally not copied: the Ruby
   guard explains itself in the log.
2. **The name cell had no other job.** It was a bare `<td>` holding only the
   highlighted name. There is no `<tr>`-level click handler anywhere in the
   dialog, and no drag, selection or inline editing on that column. Nothing
   was clobbered, and row behaviour is unchanged.

**No double fire**: the `→` button is inside the ROW but not inside the name
CELL, so one click hits one handler; its existing `stopPropagation()` is left
as it was.

`scripts/wr_tools/VERSION` → **1.20.2** (patch: markup + CSS wiring inside an
existing dialog).

**UNRUN IN SKETCHUP.** `python scripts/rbparse.py` → 68/68 parse, syntax only.
To verify: open **Proposal package**, hover a scene name (should turn orange
and underline), click it (SketchUp should jump to that scene, same as the row's
`→`). Then start an export and click a name mid-run: nothing should move and
the log should say the click was ignored because a batch is running.

## Also in this session — hide whole OBJECTS per scene, 1.21.0

The headline is a **bug**, not a feature request. Benton selected the booth,
pressed **USE MY SELECTION** in the proposal package's walls popover, and got
*"Nothing in your selection matched a named wall."*

### The shared-vs-duplicated question, answered

**Shared module, reduced surface.** `scripts/proposal-package.rb` (3154-3220)
calls `WR_SceneWalls.inventory`, `.apply`, `.keys_for_selection` and `.reveal`
directly — the Ruby engine is genuinely shared, not copied. What is duplicated
is only the **HTML/JS** (the popover has its own `wallsShow` markup, distinct
from the standalone dialog's two-column chips). And **`apply_selection` was
never wired into the popover at all**, which is the whole bug: the standalone
dialog's *Hide selection in this scene* buttons had no counterpart there.

### A scope correction, stated plainly

I was briefed that Benton had chosen **component instances only**. That was
wrong and I was told so before writing any code against it — **nothing had to
be undone**, I was still reading when the correction arrived. Entity Info shows
the booth as `Group (1 in model)` / Instance `MDL 96120 E (components)`, so an
instances-only filter would have listed nothing useful and missed the exact
object in question. Verified in the code myself: `inventory` walks
`model.entities.grep(Sketchup::Group)` as roots and `each_piece` matches
`PIECE_RE` group names — top-level ComponentInstances were never looked at at
all. The shipped filter is type-agnostic: **a top-level container, Group or
ComponentInstance, that is not already a wall row.**

## Produced

**`scripts/wr-scene-walls.rb`** (the shared engine + standalone dialog)
- `scan(model)` → `{ :walls, :objects }`, one `@units` index. `inventory`
  now just `scan(model)[:walls]` — contract unchanged for existing callers.
- `wall_units` (the old inventory body) now records `@wall_rooms`.
- `object_units`, `object_name`, `object_unit`, `unit_label`, `object_json`.
- `reveal` describes a row through `unit_label`, so walls and objects read the
  same in both windows.
- `state_json` gains `objects`.
- Dialog: an **Objects** tick-list under the two wall columns, with copy
  counts, a mixed-state note, SHOW ME, all/none links, and a new `reveal`
  action callback (the standalone dialog never had one).

**`scripts/proposal-package.rb`** (the popover)
- `self.walls_payload(model, n, pg)` — one shape, used by all three callbacks
  that redraw the popover, so they cannot drift.
- **`wallssel`** callback + **HIDE SELECTED** / **SHOW SELECTED** buttons,
  calling the module's existing `apply_selection`. Writes into the scene
  immediately, matching the standalone dialog.
- `wallsShow` renders an **Objects** section; the no-named-walls early return
  no longer swallows the body.
- USE MY SELECTION's failure message now points at HIDE SELECTED instead of
  only telling him to run *Name walls*.

**Housekeeping**: `scripts/wr_tools/VERSION` → **1.21.0** (a feature in two
dialogs plus a new module API), `DEVLOG.md` entry.

## Read first
- `scripts/wr-scene-walls.rb` — the `objects` comment block above
  `object_name`: why top-level-only is a correctness rule, and why the booth
  is a Group.
- `scripts/proposal-package.rb` — the comment above `wallssel`, which records
  the bug.

## Assumptions
- **observed** (by reading): the popover shares the module and lacked
  `apply_selection`; `inventory`'s roots are top-level Groups only.
- **derived**: `apply`, `keys_for_selection` and `reveal` absorb object units
  with no new code, because all three work through `unit[:pieces]` and
  `@units` — no second save mechanism was added.
- **assumed**: `Sketchup::Group#name` returns the Instance name Entity Info
  shows (so the booth row reads `MDL 96120 E (components)`). Not observed in
  SketchUp. If it comes back blank, the row falls back to the definition name
  and then to `unnamed group #<id>` — it degrades, it does not break.
- **assumed**: a top-level container nested-in-a-definition hazard is real
  (hiding a nested instance affects every placement). Reasoned from how
  definitions work, not probed.

## Open questions
- **UNRUN IN SKETCHUP.** `python scripts/rbparse.py` → 68/68 parse. Syntax
  only. To verify, in the proposal package: **Hide walls** on a scene → an
  **Objects** section should list the booth as `MDL 96120 E (components)`;
  tick it, **APPLY TO THIS SCENE**, confirm it vanishes on that scene and
  returns on the next. Select the booth in the viewport → **USE MY SELECTION**
  should tick its row rather than turn red. **HIDE SELECTED** should hide it
  immediately. **SHOW ME** should select it in the model. Repeat in the
  standalone *Hide walls per scene* dialog.
- Nested containers are deliberately unlisted. If Benton wants a booth that
  lives inside a room group to appear as a row, that is a follow-up and needs
  a decision about the shared-definition hazard first.
- **All three of this session's changes (1.20.1, 1.20.2, 1.21.0) are
  unverified by Benton.**

---

# HANDOFF — Builder → Benton: fixtures carry their lights, borrowed walls, 1.28.0

2026-09-10. Built, **unrun in SketchUp** — no `ruby.exe`, no V-Ray on this
machine. `python scripts/rbparse.py` clean (real CRuby 3.2 parse),
`python scripts/rbtest-lights.py` 45 + 10 PASS, five mutants on the new
wall-scan cores each KILLED and reverted. Full account: DEVLOG 1.28.0.

## Produced
- `scripts/wr-drop-lights.rb` — emitters placed INSIDE their F1/F2/F3
  fixture groups (`place` takes a container); `nested_lights` so the sweep
  reaps them; `sweep_point` locates owned containers by bounds centre (a
  latent re-press-doubles-the-rig hole on any room not at the origin);
  `existing_walls` / `add_walls` / `find_walls` / `erase_walls!`;
  `find_owned` / `erase_owned!` behind the ceiling wrappers; panel checkbox
  **Add walls on the open sides**, default OFF; `enclosure_trim` comment
  states what the caller has always passed and why the open-run count is
  not fed in.
- `scripts/rbtest-lights.py` — check 26 (`face_on_edge?` truth table +
  `open_edges` on the rectangle, the L, tolerance and overlap edges).
- `scripts/wr_tools/VERSION` 1.27.0 → **1.28.0** (minor: a new user-facing
  function and a structural change to what a press builds).

## Read first
- `wr-drop-lights.rb`, the comment block above `disc_solid` ("ONE THING
  TO MOVE") — group vs component, the nesting evidence, and the sweep.
- The comment above `enclosure_trim` — nothing moved, and the `poly.size`
  fact.

## Assumptions
- **reported**: a V-Ray light nested one level inside a group still
  exports and emits — from `BoothLighting.skp` inside link-built booths
  rendering hot (sun-blowout.md). Never rendered with THIS rig.
- **assumed**: `Entities#add_group` leaves the group at the identity
  transformation, so an instance added to `group.entities` with drawing-
  context coordinates lands where the same coordinates would in `ents`.
  Standard SketchUp behaviour; not probed here.
- **assumed**: `Group#bounds` is parent-space, so `world_bounds(e, tr)`
  with the parent's world transform is the world box (the same call the
  obstruction scan already relies on).
- **derived**: the origin hole — fixture and ceiling groups sit at (0,0,0)
  and the verification room happened to contain it.

## To verify (Benton) — the load-bearing checks
1. **Moved fixture takes its light, and still renders lit.** Press on a
   room. Outliner: `WR Fixture F1 flush drum` holds a `Rectangle Light`.
   Move the drum — the light widget moves with it. **Render**: the drum is
   lit. A dark drum = nested emitters do not export → tell me, the light
   goes back beside its fixture (one-line revert per call site).
2. **Second press reaps the nested plugins.** Press again: same instance
   count, console `swept the replaced rig: N V-Ray plugins deleted, 0 left
   behind`. Asset Editor Lights tab shows no orphan lights.
3. **Walls.** 3-sided room, tick *Add walls on the open sides*: exactly
   one `WR Lights Wall N` group, on the open run, floor to wall top;
   console names the run. Render from INSIDE: not over-bright (the trim
   line should still read `4 sides (1 borrowed wall) -> room trim x1.00`
   with a ceiling, `x0.35` without). Then
   `WR_DropLights.remove_rig!(Sketchup.active_model)` → `restore verified`,
   no `WR Lights Wall` left. Hide walls per scene should list the borrowed
   wall under Objects.
4. Pre-existing rig from before 1.28.0 in a model: one press must replace
   it cleanly (its lights are siblings and sweep as before).

## Open
- `assert_lights_visible!` (unused by `run`; the lookdev harness has its
  own) counts TOP-LEVEL light instances only, so with nested emitters its
  `expect` arm would undercount. Left as is; flagged.
- Ceiling and walls are borrowed before the grid/fallback refusal, so a
  refused room keeps them until the next press — pre-existing for the
  ceiling, kept consistent.


---

# HANDOFF — two-point perspective on export (Fixer, 10 Sep 2026, 1.29.0)

## What Benton said
"when we're exporting scenes, it's not saving the two-point perspective.
It's only going like the flat perspective."

## Finding
- **reported** (ruby.sketchup.com, api-issue-tracker #88 open): two-point
  is READ-ONLY from Ruby (`Camera#is_2d?`); no setter. Cannot be restored
  programmatically. The fix is avoidance + detection, never repair.
- **observed**: three camera-touching calls in the export path, all older
  than today (28 Aug / 27 Aug / 30 Aug): render-lane `view.camera =
  page_cam`, finish's `view.camera = @prev_cam`, image-lane `write_image`
  at 1600x900. Today's diff touches `selected_page=` only.
- **unverified**: which of the three drops the flag. `probe-two-point.rb`
  answers it live.
- **observed**: PeoplesSpace Revision image plates 02/03/04/06/11 have
  converging verticals (ordinary perspective). Not knowable from here
  whether those scenes were saved two-point.

## Changed
- `scripts/proposal-package.rb`: `two_point_of`, `page_two_point`,
  `two_point_check`; image lane reads the flag in `after_switch` and after
  the write; render lane skips the direct camera assignment on a two-point
  scene the switch honoured; finish skips `@prev_cam` when the scene
  restore already brought two-point back, and names a loss it causes;
  manifest fields `two_point_scene`, `two_point_view_at_export`,
  `two_point_view_after_write` + field note.
- `scripts/probe-two-point.rb` (new, dev shelf).
- VERSION 1.29.0 (minor: new script, new manifest fields).

## To verify (Benton) — load-bearing
1. On a two-point scene: `load ".../scripts/probe-two-point.rb"`. OPEN the
   two PNGs it writes to `%TEMP%`. Converging verticals in the 1600x900
   one = `write_image` at a foreign size is the culprit; next change is to
   export at the viewport aspect (drops D4's same-shape promise).
2. Package run with a two-point scene in each lane: log says `two-point
   perspective held`, manifest `two_point_view_at_export: true`.
3. Viewport still two-point after the run.

## Open
- If the probe shows step 1 (the scene switch itself) loses two-point,
  scenes do not round-trip it from Ruby and no exporter change helps —
  the honest answer becomes "export two-point plates by hand".


---

# HANDOFF — transparent backgrounds (Fixer, 10 Sep 2026, 1.30.0)

## What Benton said
"also curious if there can be a button for the renders to 'export with
transparent backgrounds'."

## Decision
Per-run BACKGROUND checkbox in FOLDER & DETAILS, default OFF, NOT
remembered (assumed use: compositing; not per scene). Both lanes wired;
neither verified live. The file on disk is checked after every write
(IHDR colour type) and a mismatch is logged `bad` and named in the row.

## Changed
- `scripts/proposal-package.rb`: `transp` in the export payload;
  `@transparent`; `image_cfg` bg `Transparent`; render lane omits
  `:no_alpha` (observed path to RGBA, F4 28 Aug); `png_alpha` /
  `alpha_note` / `alpha_mismatch?`; manifest `transparent_background`
  + per-row `alpha_channel` + field note; help text names the pack rule.
- VERSION 1.30.0 (minor: new option + manifest fields).

## Provenance
- **reported**: `write_image` `transparent` Boolean, default false,
  SketchUp 8+ (ruby.sketchup.com). No word on sky/ground.
- **observed** (F4): options-less `save_vfb_image` wrote transparent RGBA
  + `.Alpha.png` sidecar. `:skip_alpha` kept; `:no_alpha` dropped.
- **observed in code**: export-scenes.rb turns DrawGround/DrawHorizon/
  DisplayFog off after the switch and restores in `ensure`; the srgb
  bake accepts colour type 6.
- **unknown**: V-Ray environment alpha setting; whether the image-lane
  restore is clean over a batch (pre-existing path since 6 Aug).

## To verify (Benton) — load-bearing
1. Tick BACKGROUND; export one image + one render scene. Rows say
   `alpha channel: YES`. Open the PNGs in a viewer that shows alpha
   (checkerboard, not white).
2. Untick; export again; manifest `transparent_background: false`, rows
   silent about alpha.
3. Re-open the window: the box is unticked.

## Open
- The proposal generator / skill are untouched; they already flatten.
  A pack build could additionally read `alpha_channel` from the manifest
  and refuse — not done (proposals/ out of scope this pass).


---

# HANDOFF — preflight dims row demoted (Fixer, 10 Sep 2026, 1.30.1)

- Not inverted: `ROWS` labels are the required state, details the
  failure reason; the modal's `label: detail` produced the contradiction.
  All six rows share the shape; only the two modal composers changed
  (`label - FAILED: detail`).
- `proposal-package.rb` no longer blocks on `dims`; logs a dim line.
  `wr-preflight.rb` untouched (window + Fix intact); `wr-pack-export.rb`
  still blocks on it, wording fixed.
- Check: WR-Dims visible, Export, no modal.


---

# HANDOFF — screen notes move on export (Fixer, 10 Sep 2026, 1.31.0)

- **observed** cause: `image_cfg` forced the V-Ray height (D4, 1.9.3);
  `out_height` honours it over the window; nothing read the viewport
  aspect. V-Ray lane unaffected (no Sketchup::Text in renders).
- **reported/derived**: only no-leader (`ALeaderNone`) notes move; leader,
  pushpin, 3D text and dimensions are model-anchored.
- **observed**: Revision plate 05's no-leader note sits across the door
  frame; 02's "Outlet on ceiling" block and every bottom-left title block
  are no-leader too. Re-export before trusting any pre-1.31.0 plate with a
  no-leader note.
- Fix: plain lane written at the window's shape (`'height' => nil`);
  start_run logs plate size vs window vs V-Ray size; manifest `viewport`
  + `image_shape` + field note; WIDTH label corrected. D4 withdrawn: one
  shape for both lanes only by making the window the Asset Editor ratio.
- Two-point: one hedged sighting; manifest `two_point_view_at_export` is
  the record to read. Not marked fixed.
- Check: no-leader note against an edge, export, compare PNG to viewport.


---

# HANDOFF — drift confirmed; changed-window warning (Fixer, 10 Sep 2026, 1.31.1)

- **observed** (Benton): plate 05's clipped note IS the drift; he had
  blamed two-point. Two symptoms, reported separately.
- Rev2 no-leader notes are unreliable, not once-wrong; the 05 re-export
  relocated the note by luck. No note-nudging until the folder is
  re-exported from one window shape.
- `prior_viewport(dir)` reads the folder's last manifest; a different
  window logs `WINDOW CHANGED` (`bad`); size-mismatch line now `bad`.
- Check: export once, change the tray layout, export again — the log
  names both window sizes.

---

# HANDOFF — Builder → Benton: borrowed walls now get made, 1.31.2

2026-09-10, on the field report *"the walls arent being made"*. **Unrun in
SketchUp.** rbparse 71/71, rbtest-lights 47 + 10 PASS, hidden-flag mutant
reproduces the bug and is killed. DEVLOG 1.31.2 has the full account.

## Cause
A wall hidden with *Hide walls per scene* keeps its geometry (entity
`hidden` flag); 1.28.0's scan never checked `hidden?`, judged every run
walled, borrowed nothing, and said so only on the console. Derived from
the code path; the one question that would confirm it: **"On that room,
is the open side a wall you hid (Hide walls per scene / eye icon), or is
there no wall drawn there at all?"** — "hid" confirms; "no wall drawn"
means the tolerance line in the new console output is the next clue.

## Fix (`scripts/wr-drop-lights.rb`)
- `hidden_now?`, `existing_walls` flags hidden faces; `run_report` counts
  them separately; a hidden wall reads OPEN.
- `WALL_OUT` 1/16": borrowed walls stand just outside the polygon, so a
  doubled run buries the borrowed face inside the real wall — no fighting.
- Add walls select: **No / open runs (hidden counts as open) / every run**.
  `walls_mode` maps a 1.28.0 `true` to "open".
- Per-run console lines (`wall_scan_lines`) and an end-of-press window
  (`wall_notes`) whenever walls were asked for.
- `scripts/rbtest-lights.py` check 27; `VERSION` 1.31.1 → **1.31.2**
  (patch: a defect fix plus diagnostics, no new surface beyond the select).

## To verify (Benton)
1. Press with Add walls = "On the open runs" on the failing room. Console:
   one line per run; the hidden run reads `OPEN ... HIDDEN face on it`.
   Window: `<room>: N runs — k walled, m open (…) — m walls borrowed on
   runs …`. Outliner: `WR Lights Wall N`.
2. If the window still says all walled: read the console's `nearest
   parallel face is X" off the run` — that X is the tolerance to move.
   Pick "On every run" to enclose meanwhile.
3. Render from inside; then `WR_DropLights.remove_rig!(Sketchup.active_model)`
   → `restore verified`, no `WR Lights Wall` left.


---

# HANDOFF — V-Ray save arity regression (Fixer, 10 Sep 2026, 1.31.3)

- **observed**: `save_vfb_image(path, hash)` -> ArgumentError (given 2,
  expected 1). Docs: `save_vfb_image(path, options)` with an Options list
  = keywords. Both call sites now `**opts`.
- Pre-existing: the SAVE_OPTS Hash call raised since 1 Sep; the braceless
  fallback carried every render with a false "apply_color_corrections
  REJECTED" line. 1.30.0 made the fallback a Hash too -> total failure.
- No partial folder was written. V-Ray transparency stays possible
  (`:no_alpha` is documented). No other V-Ray call was touched.
- Harness cannot see plugin arity; a stub-renderer test would.
- Check: one render scene -> `1 exported, 0 FAILED`, PNG on disk.
---

# Fixer: the exposure clash — 1.32.0 (10 Sep 2026)

Benton: "the drop in lights function is also still breaking other lights
and the sun" / "this has to do with the exporting images in proposal
package being dark right?" Diagnosis in `.forge/fixer/sun-blowout.md`
(updated). **Nothing run in SketchUp.** rbparse 71/71, rbtest-lights 50,
rbtest-proposal +ev-iso.

## Answer to his question
Two problems on one camera. A PLAIN image never touches V-Ray (write_image
+ the wr-shading contract) — ISO cannot darken it. A V-Ray plate is dark
when the camera is at ISO 100 with a rig calibrated for 3200 (e.g. he
undid the stamp by hand to fix the sun); it is BLOWN when the camera is at
3200 and the sun / booth light are still at factory. Ask: **"were the dark
images plain image rows or ` render.png` rows?"**

## What changed (`scripts/wr-drop-lights.rb`, `scripts/proposal-package.rb`)
- `retune_window` after every press with a non-factory ISO: sun + every
  foreign V-Ray light, value now → proposed (÷32), all unticked, written
  only on WRITE THE TICKED ROWS, read back by name. Console gets the list.
- `booth_own_lights`: a booth that already carries a live V-Ray light
  (BoothLighting.skp, every link build) does NOT get the rig's role 6.
- proposal-package: `ev_of_camera` counts ISO; the "camera as configured"
  log line is honest on a stamped model and shouts when ISO ≠ 100.
- `exposure_ratio`, `stops_of`, `retune_rows` pure + harness check 28.

## To verify (Benton)
1. Fresh model, room + link booth, press *Drop the interior lights*. A
   second window "Exposure — what else needs retuning" should open after
   the walls window, listing `/SunLight` now 1.0 → 0.03125 and the booth's
   light(s) with their value ÷ 32. Nothing written yet.
2. Lights tab: ONE interior light in the booth (his), not two. Console:
   `booth "…" already carries N light(s) of its own … NOT added on top`.
3. Tick the sun row, press the button; the window should print
   `/SunLight[intensity_multiplier] = 0.03125 — written and read back`.
   Render: sunlit surfaces back where they were at factory. If it says DID
   NOT STICK, paste the line.
4. Proposal package on that model: the run log should say `EV 9.23 (f/8.0
   @ 1/300.0 @ ISO 3200.0, ISO counted)` plus a red ISO line.


---

# HANDOFF — double display correction (Fixer, 10 Sep 2026, 1.33.1)

- **observed**: field PNG RGB, sRGB-stamped, mean 0.671 vs 0.34 (Rev2) —
  display-corrected by V-Ray (option reached it after 1.31.3), then
  sRGB-encoded again by srgb_bake. Alpha ruled out (colour type 2).
- The 1 Sep "option changed nothing" test never exercised the option.
- Fix: `:apply_color_corrections` removed from SAVE_OPTS; rescue log no
  longer blames it; srgb_bake warns (log-only) when pre-encode mean > 0.45.
- Rev2 01/07/09 unaffected (mean 0.34). Renders from 1.31.3–1.33.0 are
  double-corrected: re-export.
- Not shipped: option ON + no bake (V-Ray's own corrected save, carries
  all VFB layers) — needs one measured comparison first.


---

# HANDOFF — per-model subfolder (Fixer, 10 Sep 2026, 1.34.0)

- `resolve_dir(root, per_model, title)` pure; dir1–dir6 in the harness.
- Unsaved model (`Model#title` == "") → ROOT, said in label, GOES TO
  line and a `bad` log line. Not refused, not prompted.
- FOLDER = root, remembered as root; `sub` pref default Yes reaches
  machines that exported before (never written until now).
- `DEFAULT_ROOT` Z:/Sketchup/Proposals offered only if unremembered AND
  present on the machine.
- prior_viewport / mkdir / collision / manifest all use the resolved dir.
  Manifest: `output_root`, `per_model_folder`.
- Check: saved model → GOES TO shows `<root>/<name>/`, export, PNG in it;
  untick → root.
