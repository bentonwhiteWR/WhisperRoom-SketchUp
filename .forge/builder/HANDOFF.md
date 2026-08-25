# Builder HANDOFF — Enhanced on the share-link path

2026-08-24, second pass (first pass: `1c84103`). Scope: `scripts/booth-from-link.rb`, plus an
investigation of Enhanced layout generation in `scripts/wr-booth-data.rb`.

**Everything here is UNRUN.** There is no Ruby outside SketchUp on this machine.
`python scripts/rbparse.py` reports `ok booth-from-link.rb` and all 49 `.rb` files in
`scripts/` parse. No behaviour was observed executing in SketchUp. The resolution behaviour
was verified by replaying the same logic against the real component folder in Python.

---

## 1. Done this pass — the ramp ruling

`component_for`'s WA-door branch now ignores `o[:ramp]` on the Enhanced path and emits the
plain `ENH LeftWADoor` / `ENH RightWADoor`, per Benton: *"Ramp only attached to standard."*
The ramp still reaches the model on the Standard path, unchanged.

**New coverage table** (observed — replay against the live folder, every portal-emittable pack
× both variants × 8 VSS/EFS/caster combinations × ramp × hx):

| | combinations | resolve | do not |
|---|---:|---:|---:|
| Standard | 960 | 928 | 32 |
| Enhanced | 960 | **928** | **32** |

Enhanced was 896/960 last pass. The 32 ramp-door misses are gone. **The two paths now have
identical coverage**, and the only remaining miss on either is `'STDWL7 / WL16'` — the
deliberate skip. That is 32 rows because it is one pack string counted across all 32 flag
combinations, not 32 distinct problems.

Per Benton's ruling the 7-inch is *"actually a modified mid wall seam seal but I don't have
that item created… it's kinda rare."* An Enhanced booth needing it aborts by name, which is
now the intended outcome. **I did not widen the `'STDWL7 / WL16'` regex on the Standard
path**, as instructed — it still falls through to the layout default there, exactly as before.

`ENH_MISSING_ABORTS = true` unchanged.

---

## 2. NOT done, deliberately — the Enhanced layouts

**I did not generate Enhanced layouts, and I did not touch `scripts/wr-booth-data.rb`.**

The instruction was to stop rather than invent panel runs if the geometry could not be derived
unambiguously from the −4.5 rule plus the fixed footprint. It cannot, and this is a
mathematical result rather than a judgement call.

### The proof

Evidence script: `.forge/builder/analyse-layouts.py` (re-runnable). It parses all 25 Standard
layouts out of `wr-booth-data.rb` and measures every panel from its `:poly`.

**Observed, from the 25 layouts:**

- Opposite walls always carry equal panel counts (N==S, E==W). So far so good.
- No panel in any layout lacks an Enhanced counterpart — **no 7-inch panel appears in the
  static layout data at all.** The 7-inch only ever arises from the portal's `shrinkPack` on a
  WA-door booth, which is not part of these layouts.
- **Panel counts per wall range from 1 to 5, and differ between the two axes of the same
  booth.** `MDL 102186` is 5 panels on N/S and 3 on E/W; `MDL 4230` is 1 and 1.

**Derived, and this is the blocker.** Under a literal one-for-one substitution — every panel
replaced by its counterpart 4.5 narrower — a wall of *n* panels shrinks by exactly 4.5*n*,
because the 2-inch joints are unchanged. With the outer footprint fixed, the air gap between
the shells is therefore forced to `2.25n` per side:

| implied gap per side | booths |
|---|---|
| 2.25 | 3 |
| 4.50 | 10 |
| 6.75 | 6 |
| 9.00 | 4 |
| 11.25 | 2 |

The gap is **not a constant**. It ranges from 2.25 to 11.25 inches, and it differs between the
two axes of the same booth — `MDL 96192` would get 9.00 one way and 4.50 the other; `MDL 102186`
11.25 and 6.75. What sets it is nothing physical: it is purely how many panels that particular
wall happens to be divided into.

Stated generally: for a constant gap `G`, the total shrink a wall needs is `2 + 2G`, spread
over its *n* panels — so each panel must narrow by `(2 + 2G)/n`. For that to be 4.5 for every
*n* from 1 to 5 simultaneously is impossible. **A constant gap and a one-for-one −4.5
substitution are mutually exclusive across this layout set.**

A second, independent check points the same way. If the inner shell is placed *concentrically*,
**10 of the 25 doors end up partly outside their outer door opening** — the inner leaf would
foul the outer frame. Examples (outer opening vs derived inner door, in booth coordinates):
`MDL 102102` 2.0–42.0 vs 8.75–44.25; `MDL 84102` 62.0–102.0 vs 59.75–95.25.

### What this means

The −4.5 rule is a **parts-naming** rule: it says which Enhanced part corresponds to which
Standard part. That is exactly how `component_for` uses it, and that use is sound and now
verified at 928/960. It is **not** a layout rule, and it does not locate the inner shell.

Deriving the layouts needs one number that does not exist anywhere yet: **the designed air gap
between the outer and inner shell.** `.forge/GOAL.md` already says that gap must be a measured
number and not inferred from the 4.5 name arithmetic — that instruction is correct and this is
the case it was written for.

### The footprint inference — I could not confirm it, and there is a competing explanation

The coordinator's reading is that identical Std/Enh exterior footprints imply an Enhanced booth
carries **both** the Standard outer walls and the Enhanced inner walls. I verified the premise
independently and it holds: **all 26 models have identical Std/Enh exterior footprints**
(observed, `models.json` `tupleFormat` `stdDims`/`enhDims`; only height differs). No figures
from that file appear in this document or in any code.

But the conclusion does not follow from it, because there is a simpler explanation:

**All 46 Standard deck codes have an identically-coded `ENH` twin** (observed —
`ENH 9648FL CTR` alongside `STD9648FL CTR`, and so on for all 46; the only `ENH`-only deck
codes are the two suspected-typo `423.54` files). The floor and ceiling *are* the same size in
both variants. So the exterior footprint is identical because **the deck is identical** — which
it would be whether the booth has one wall shell or two.

That is reinforced by `.forge/GOAL.md`'s own vertical datum ruling: *"The Enhanced walls sit on
the floor panel lip. They also squeeze under the ceiling lip."* A wall seated on a lip is
inboard of the deck edge. A single Enhanced shell standing on the lip of a full-size deck would
produce an identical exterior footprint and a smaller interior, with no second shell involved.

I am **not** asserting the single-shell reading is right — the DEVLOG's "booth inside a booth"
framing and the product's double-wall acoustics both argue for two shells. I am reporting that
**the footprint evidence does not distinguish between the two**, so it should not be treated as
settled. Nothing was built on either reading, so nothing has to be flipped; this is still open.

---

## 3. The one measurement that unblocks all of it

The gap is very likely already sitting in the components, unmeasured. **The floor lip on the
`ENH …FL` parts is what physically locates the inner shell.** Its inset from the deck edge *is*
the gap, and its height is the other half of the datum question `.forge/GOAL.md` already flags
as unmeasured.

Recommended next action, and it is cheap: extend `scripts/probe-enhanced.rb` (or write a small
sibling) to report, for the `ENH …FL` and `ENH …CL` parts, **the lip's inset from the part edge
and its height**, and the same for the `STD…FL`/`CL` twins. That yields:

- the shell gap, measured rather than inferred — which makes the layouts derivable;
- the floor-lip / ceiling-lip split of the 1.5-inch height difference, which `.forge/GOAL.md`
  says must be measured before the Enhanced z-datum constant is written;
- a direct test of the one-shell / two-shells question, since a deck built for two shells
  should show seating for both.

It needs Benton to run it, like the first probe. Until then, generating 25 Enhanced layouts
means choosing a gap by fiat and stamping it into geometry that looks authoritative — the exact
class of silent-wrong-answer this mission exists to remove.

**Alternatively, one sentence from Benton settles it:** what is the air gap between the outer
and inner shell, and does the inner wall run use the same number of panels as the outer wall it
sits inside?

---

## Produced

- `scripts/booth-from-link.rb` — Enhanced part mapping, on-disk pre-resolution with loud
  by-name reporting, `ENH_MISSING_ABORTS`, the ramp ruling, and the `46VntCP` Standard fix.
- `scripts/wr_tools/VERSION` — 1.5.3 → 1.5.4.
- `.forge/builder/replay-component-for.py` — coverage replay.
- `.forge/builder/analyse-layouts.py` — the layout geometry analysis behind section 2.

## Read-first

1. Section 2 above, before any further work on Enhanced layouts.
2. `scripts/booth-from-link.rb` header and `ENH_MISSING_ABORTS`.
3. The still-open downstream blocker, noted in `build_from_payload`: `wr-booth-data.rb` carries
   25 layouts and every key ends `' S'`, so `build_booth` still stops with its "panel lengths
   are unresolved" messagebox on any Enhanced key. **That is section 2's blocker, not a
   separate one.**

## Provenance

- **observed** — the `ENH` filename set; the `Panel`/`PanelSolid` split; window codes not
  taking the −4.5; `46VntCP` having no underscore; 353 files → 353 distinct normalised keys;
  `wr-booth-data.rb` having zero `' E'` keys; per-wall panel counts 1–5 and the resulting gap
  table; 10 of 25 doors failing the concentric check; all 26 models having identical Std/Enh
  exterior footprints; all 46 deck codes having an `ENH` twin; `guess_component` composing
  Standard names for unassigned slots.
- **derived** — that a constant gap and a one-for-one −4.5 substitution are mutually exclusive
  across this layout set; that realistic door/vent widths are only 40 and 46.
- **reported** — Benton's four rulings, via `.forge/GOAL.md`.
- **assumed** — per-session memoisation of the folder index is acceptable; returning an
  already-`_HX` name is safe (grounded in `build-booth-components.rb` line 846's
  `end_with?('_HX')` guard, and no file uses a lowercase `_hx`).

## Open questions

**Q1 — the shell gap.** The blocker. Measure the `ENH …FL` lip inset, or one sentence from
Benton. Everything in section 2 hangs on it.

**Q2 — one shell or two?** Not settled by the footprint evidence, for the reason in section 2.
The same lip measurement would answer it.

**Q3 — does the inner wall run use the same panel count as the outer wall?** If it does not,
the layout derivation is a packing problem rather than a substitution, and Benton's
"counterpart 4.5 smaller" describes the parts but not the runs.

**Closed this pass:** the previous O1–O4 (7-inch skip, 2.5" panel cancelled, ramp doors
cancelled, abort confirmed).

## Files

- `C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\scripts\booth-from-link.rb`
- `C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\scripts\wr_tools\VERSION`
- `C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\.forge\builder\replay-component-for.py`
- `C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\.forge\builder\analyse-layouts.py`

---
---

# Builder HANDOFF — scene→component resolution by raycast

**This is a SEPARATE, UNRELATED task from everything above.** Everything above concerns
Enhanced booth building (`scripts/booth-from-link.rb`, `.forge/GOAL.md`). Nothing above was
touched, re-opened, or superseded by this pass. Read the two independently.

2026-08-24. Scope: `scripts/save-scene-components.rb`, function `subject_for` and the
`HOW IT RESOLVED` reporting only.

**UNRUN.** There is no Ruby outside SketchUp on this machine. `python scripts/rbparse.py`
reports `ok save-scene-components.rb` and all 49 `.rb` files in `scripts/` parse. **No
behaviour was observed executing in SketchUp. Benton's next dry run is the test.**

## The problem, as handed over

`subject_for` picked the top-level instance whose bounds *centre* was nearest `cam.target`,
discarding `cam.direction` entirely. Over a 112-scene dry run (**observed**, Benton, this
evening): not one scene resolved with the camera inside a part; deck scenes resolved
137–236 in from the component they were assigned; 13 scenes collided onto a component another
scene had already claimed, overwhelmingly CL/FL twins stacked in Z and left/right hands.
Four shipped Enhanced floor files measure ~1.75 thick against 0.3125 for every other Enhanced
floor part — they contain ceiling geometry.

## What changed

`subject_for` now casts a ray from `cam.eye` along the view direction and takes the first
top-level `ComponentInstance`/`Group` in the returned instance path. Two parts stacked in Z
cannot both be the first thing a ray strikes, which is the mechanism by which the CL/FL
collisions should break.

### The API, verified — not taken from memory

Checked against `ruby.sketchup.com/Sketchup/Model.html` this pass. The handover described the
shape from memory; **the memory was correct in every respect I checked**, with one detail
worth stating because the code depends on it:

| | documented |
|---|---|
| signature | `#raytest(ray, wysiwyg_flag = true) => Array(Geom::Point3d, Array<Sketchup::Drawingelement>) or nil` |
| ray argument | a two-element array `[Geom::Point3d, Geom::Vector3d]` |
| degenerate direction | *"If direction can not be normalized (e.g. direction = [0,0,0]), direction is taken as a point the ray intersects"* — a silent change of meaning, so the code normalises and guards |
| return | `nil`, or `[hit point, instance path]` |
| path order | **outermost first**: *"if the ray hits a face contained by a component instance the instance path would be `[Component1]`… `[Component1, Component2, Component3…]`"*. So `path.first` is the top-level subject. |
| path contents | documented as instances only — the Face is **not** in the array |
| `wysiwyg` default | `true`, and *"hidden geometry is not intersected against"*. **Left at the default**, deliberately: the ray should hit what a person looking at the scene would hit. |

Because the docs promise instances but I could not run it, the code uses
`path.find { instance or group }` rather than `path[0]` blind — that resolves correctly whether
or not a given SketchUp build also appends the Face.

`Sketchup::Camera#direction` is documented only as *"a Vector3d in the direction that the Camera
is pointing"* — **normalisation is not promised** (checked; the docs are silent). Hence
`view_direction`, which normalises and rebuilds from `target - eye` if the vector is degenerate.

### The fallback — replaced, not kept

Requirement 2 invited judgement. Nearest-to-target-point is the thing that failed, so it is no
longer the primary fallback. Three tiers, each labelling itself:

1. **`ray crosses bounds N in ahead`** — a slab test against each candidate's bounding box,
   nearest entry first. Catches a ray that sailed between real faces (a gap, hidden faces)
   while still being aimed at the part.
2. **`N in off ray axis, ahead` / `, BEHIND camera`** — smallest perpendicular distance from
   the ray line. Direction-aware "nearest". In-front candidates always outrank behind-camera
   ones regardless of perpendicular distance.
3. **`N in from target, no view direction`** — the old behaviour, reached only when there is no
   usable direction vector at all.

### The `HOW IT RESOLVED` column

Now distinguishes genuinely-aimed from guessed, at a glance:

- `ray hit at 212 in` — the camera really is pointing at that component.
- `fallback: …` — every fallback branch is prefixed `fallback:`, so a grep or sort on the
  column or the TSV separates them cleanly.

A new **AIM** summary block in `report` tallies `ray hit` vs `fallback` counts. The collision
report (`same component as scene #N`) is untouched and still appends to the same string.

Nothing else changed: naming, rename path, file writing, scene selection, manifest — all as
they were.

## Honest limits — please read before trusting the next run

- **UNRUN.** Everything below is reasoning about documented behaviour, not observation.
- **A camera positioned inside geometry is not verified.** The docs do not say what `raytest`
  does when the ray origin is inside a solid — whether it returns the face it exits through,
  the containing instance, or nothing. If a scene camera sits inside a part, its result is
  unpredictable to me. The dry run will show it: such a scene will either name a neighbouring
  part or show an implausibly small `ray hit at N in`.
- **Scene-specific visibility is not applied.** No scene is activated (deliberately — the script
  never moves the camera), so `raytest` sees the model's *current* layer and hidden state, not
  the state the scene stores. If a scene hides the part in front of its subject and that part is
  currently visible, the ray hits the wrong thing. Not previously a factor, because the old rule
  ignored geometry entirely. **Worth checking on the dry run: run it with all layers as they
  normally sit.**
- **`wysiwyg = true` skips hidden geometry.** Correct for intent, but a subject whose faces are
  all hidden will be missed by the ray and land in the bounds fallback — which is why tier 1
  exists.
- **The slab test is my own arithmetic**, not a SketchUp call, and is unrun. It is a standard
  ray/AABB slab test in plain inch floats; a bug there would show as a wrong fallback, never as
  a wrong ray hit.
- **I did not verify the four bad floor files myself.** The ~1.75 vs 0.3125 measurements are
  **reported** by Benton. This change does not repair them — the affected scenes must be
  re-exported after the dry run confirms they now resolve correctly.

## Verification available on this machine, and what it proves

- `python scripts/rbparse.py` → `ok save-scene-components.rb`, 49/49 parse. **Proves the file
  is syntactically valid Ruby. Proves nothing about behaviour.**
- Re-read of the changed function against the live API docs, tabulated above. **Proves the call
  shapes match the documentation.**
- `scripts/rbcheck.py` was NOT used as evidence — per CLAUDE.md it is a bracket counter, not a
  parser.

**The test is Benton's next dry run.** What to look for, in order:

1. The **AIM** line. A high `ray hit` count is the headline; every `fallback` is a scene to eye.
2. The 13 previous collisions — do the `same component as scene #N` notes disappear? Named
   examples to check: 105/106 (`ENH 10218CL/FL CTR`), 91/92 (`IEP ceiling (7224)`),
   111/112 (`ENH 127LPCL/FL`).
3. Deck scenes that used to read 137–236 in — do they now read `ray hit` at a plausible range?
4. Any `BEHIND camera` label. That is a badly-aimed scene and wants fixing in the model, not
   in this script.

## Produced

- `scripts/save-scene-components.rb` — `subject_for` rewritten around `Model#raytest`; new
  `view_direction`, `fallback_for`, `ray_box_entry`, `ray_offsets`; `HOW IT RESOLVED` labels;
  AIM tally in `report`. Header comment corrected — it claimed the resolution was shared with
  `angled-component-art.rb` and behaved identically, which is now false.
- `scripts/wr_tools/VERSION` — 1.5.4 → 1.5.5.

## Read-first (for this task)

1. The comment block above `subject_for` — it carries the evidence and the verified API table.
2. The **Honest limits** section above, before reading any dry-run output as proof.
3. `angled-component-art.rb` still uses the OLD nearest-to-target rule and was **not** changed
   (out of scope). The two scripts can now disagree about the same scene. If its PNG art shows
   the same CL/FL problem, it needs the same fix.

## Provenance (this task)

- **observed** — the current contents of `save-scene-components.rb`; `rbparse.py` reporting
  49/49 ok; the documented `raytest` signature, ray argument shape, return shape, path order,
  path contents, degenerate-direction behaviour, and `wysiwyg` default and effect; the
  `Camera#direction` docs being silent on normalisation.
- **derived** — that two parts stacked in Z cannot both be the first face a ray strikes, so a
  raycast breaks the CL/FL ties a point-distance test cannot; that a `wysiwyg`-true ray will
  miss a subject whose faces are hidden, hence the bounds-entry fallback tier.
- **reported** — the 112-scene dry-run figures (no camera-inside hits, 43–46 in wall panels,
  137–236 in decks, 13 collisions, the named colliding scene pairs); the four bad floor files
  measuring ~1.75 against 0.3125. All from Benton; none re-measured here.
- **assumed** — that the parts of interest remain top-level in `model.entities`, matching the
  existing top-level-only rule which was left in place; that the model's current layer
  visibility approximates the scenes' stored visibility closely enough for the ray to be
  meaningful (flagged above as the main untested risk).

## Open questions (this task)

**R1 — cameras inside geometry.** Undocumented and unverified. The dry run reveals it.

**R2 — scene-stored visibility vs current visibility.** The ray uses current state. If the dry
run shows scenes resolving to a part that visually sits in front of the intended subject, this
is the cause, and the fix is to read `page.layers` / `page.use_hidden*` — a larger change than
was authorised here.

**R3 — `angled-component-art.rb`** carries the original rule and the original defect. Out of
scope this pass; flagged for a decision.

## Files (this task)

- `C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\scripts\save-scene-components.rb`
- `C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\scripts\wr_tools\VERSION`
