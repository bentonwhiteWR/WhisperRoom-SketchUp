# Click a WhisperRoom, get its dimensions — spec

2026-09-10, Scoper (Fable). **Approval gate: Benton has not approved anything yet.**
Mockup: `.forge/scoper/booth-dimensions-mockup.html` (variants A / A′ / B).

## The problem in one sentence

Benton wants to click a booth in SketchUp and have the three exterior dimension strings from
his reference image appear — attached to the booth's real corners, standing well clear, no
dialog, no label, nothing else — and today's tool gives him catalogue numbers floating in
space plus a text block, behind a four-field settings row.

Benton, verbatim: *"I still dont like the way our 'dimension tool' works at all for the
whisperroom. Lets essentially start from scratch. I want to be able to click a whisperroom, and
then all the dimensions show up. Similar to this image."*

Reference image (reported by the operator; I have not seen it): SketchUp 2026, three-quarter
view, exactly three strings — **8' 2"** along the left-front ground edge, **6' 7 1/2"** along
the right-front ground edge, **7' 5/16"** vertical at the right rear, full height — witness
lines from the booth corners, slash/arrow ticks, black, nothing else dimensioned.

---

## 1. What the reference image is (derived)

The three numbers decode exactly against `scripts/wr-booth-data.rb` and the current tool's
arithmetic:

| String | Inches | Decode |
|---|---|---|
| 8' 2" | 98.0 | `MDL 7296` `:w` = 98 (observed, `wr-booth-data.rb:939/958`) |
| 6' 7 1/2" | 79.5 | `:h` = 74 + one vented face × 5.5 (`VENT_PROUD`, `dimension-booth.rb:85`); the 7296 vents on N only |
| 7' 5/16" | 84.3125 | `HEIGHTS['Enhanced']` (`dimension-booth.rb:87`) |

So the image is a **7296 with Enhanced height** — an MDL 7296 E, or a 7296 S drawn with the
tool's remembered `height` preference stuck on Enhanced (a hazard in its own right, §3 D5).

**The height figure, settled.** `7' 5/16"` is SketchUp's Architectural formatting of
84.3125 in = **7'-0 5/16"** — it drops the zero inches. It is not "8 in short" of anything; it
is 11/16" under the catalogue 7'-1" (85.0). It is exactly the figure `CLAUDE.md` calls the
*drawn* Enhanced exterior ("a 96120 E measures 7'-0 5/16" as drawn") and the figure the
PeoplesSpace 96120 E renders carried (`reference/proposal-playbook.md:383-387`; DEVLOG:8566
"resolved as exact-vs-marketed").

Where the 84.3125 comes from, **derived** from the builder's own datums (none of this is
observed in SketchUp — it is arithmetic on constants):

```
IEP mat underside            -1.3125   (mat 0.3125 thick under the 1.0 standard floor;
                                        build-booth-components.rb ~1097, HANDOFF 1.33.0)
standard floor underside     -1.0
walls                         0 .. 81
standard ceiling top          82.0     (dimension-booth.rb:56-58 "free check")
IEP tray bottom               82.0 - IEP_TRAY_DROP 0.75 = 81.25   (bbc:621, :1097)
IEP tray top                  81.25 + 1.75 (ENH CL box height, TRAY-ORIENTATION table) = 83.0
overall                       83.0 - (-1.3125) = 84.3125  ✓
Standard: 82.0 - (-1.0) = 83.0 = 6' 11"  ✓
```

DEVLOG:6744 ("the 83.0000 / 84.3125 panel heights are wrong") is about **wall-panel** heights
(81 / 79.5), not the assembled exterior; it does not contradict the above.

**Relation to the 1.33.0 ground lift (HANDOFF.md, builder).** Same root — the floor stack
hanging below z 0 — but not the same defect. The lift moves the whole group up 1.0 / 1.3125
so the mat lands on the host floor; the exterior height is untouched. What it exposes is a
**pre-existing** flaw in the current tool, named in `dimension-booth.rb:119-124` and DEVLOG:41:
`BASE_Z = -1.0` is added to the group *origin*, so on an Enhanced booth the height string
starts at the standard floor's underside, **5/16" above the mat**, and its 84.3125 run
therefore ends **5/16" above the tray top**. The witness points miss the geometry at both ends.
A dimension anchored to the geometry (this spec) has no `BASE_Z` and no `HEIGHTS` table at
all — it reads 84.3125 because that is what the built booth measures, and reads something
else only when the build is wrong, which is then said out loud.

**Conclusion:** the reference image's height is correct for an Enhanced booth. The new tool
**measures** it (mat underside → tray top); it never carries a height constant. The catalogue
7'-1" / 6'-11" are install clearances and stay out of the drawing (`CLAUDE.md` rule).

---

## 2. What exists today (observed)

Three scripts under `@cat Add dimensions`, all *abilities* (on/off switch rows in the panel):

| Script | Tag | What it draws | How it gets the numbers |
|---|---|---|---|
| `scripts/dimension-booth.rb` (750 lines) | `WR-Dims-Booth` | 3 dims + a 3-line screen-text label 36" above the roof | identifies the model from the group name / deck part names, then **catalogue** `:w :h` + 5.5"/vented face + `HEIGHTS` table; bare `Point3d`s at group-origin offsets |
| `scripts/dimension-selection.rb` (282) | `WR-Dims-Selection` | 3 dims | world **bounding box** of the selection (includes the open leaf, ramp, VSS, pan) |
| `scripts/auto-dimension.rb` (627) | `WR-Dims` / `WR-Dims-Doors` | room chains + doors | the room's floor face; not a booth tool |

Panel flow today (`scripts/wr_tools/main.rb` 1019-1175): select the booth → click the ability
row → `ability_on(opts)` runs with the four stored settings (`height` Auto|Standard|Enhanced,
`vents` text, `gap` 24, `rise` 36); no dialog from the panel, a 4-field `UI.inputbox` when run
from the list/console. Off = erase everything on the tag in the whole model.

### Placement today (`dimension-booth.rb:383-420`)
- X across the **south** (y0) ground edge, pushed −Y by `gap`.
- Y along the **east** (x1) ground edge, pushed +X.
- Height up the **south-west corner** (x0, y0), pushed −X — i.e. the left silhouette.
  Chosen 2026-08-15 over a mid-face anchor (commits 160eb26 → 8a1b56c).
- Reference image: height at the **right rear**. Different corner.

---

## 3. Defects — the specific reasons "start from scratch" is warranted

Both the output and the interaction are wrong, in this order of weight:

**D1 — Nothing is attached to the booth (observed, `dimension-booth.rb:410-420`).**
`add_dimension_linear` gets bare `Point3d`s computed from catalogue numbers and the group
origin. SketchUp stores coordinates and nothing else: witness lines land on the geometry only
when the catalogue, the 5.5" rule and `BASE_Z` all happen to match the build; move the booth
and the strings stay behind. Benton reported exactly this for the room tool ("it's all
disconnected … not actually connected to the walls", DEVLOG 1.17.0) and it was fixed there by
resolving every point to a vertex or a ConstructionPoint. That fix never reached the booth
tool.

**D2 — The numbers are the catalogue's, not the drawing's (observed).** The tool's own header
(lines 24-29) records a built 96120 measuring 10' 8 7/16" across X against the drawn
10' 7 1/2" — the E vent housing stands **6 7/16"** proud on that build, not 5 1/2". A 46VNT
part is 8.5468 thick against a 1.0 panel (observed, `P:\…\_component-probe.tsv`), so ~7.5"
of housing beyond the panel face is what the library ships; where the builder seats it decides
the drawn extent. A dimension that reads 6' 7 1/2" with its witness line floating 15/16" off
the housing is the "looks right, is wrong" failure. Also: `VENT_PROUD` is the no-EFS figure and
EFS is unmeasured; HX has no agreed height. Measured geometry has none of these gaps.

**D3 — Enhanced height string floats (derived, §1).** Starts 5/16" above the mat, ends 5/16"
above the tray. Post-1.33.0 this is visible on every Enhanced booth.

**D4 — Wrong corner for the height.** SW pushed −X today; the reference wants the right rear.

**D5 — A height *setting*.** `height` Auto|Standard|Enhanced is remembered per user
(`Sketchup.read_default`) and overrides Auto once set; a Standard booth can be drawn 1 5/16"
tall-er with nothing on screen saying so. A measured height has no setting to get wrong.

**D6 — An unasked-for label.** Three lines of 2D screen text (`add_text`) 36" over the roof.
Reference: none. The label's "Ext dims" also disagrees with the catalogue box by design
(lines 475-484), which needed a console paragraph to reconcile.

**D7 — Clear-all is model-wide (observed, `clear`, lines 429-444).** Dimensioning booth 2 in
a two-booth room erases booth 1's set first ("never stack two sets" — on the whole model).
Memory note *two-booths-one-room* says this layout is real.

**D8 — Two tools that disagree and warn about each other** (`OTHER_TAG`, lines 703-711).

**D9 — Not a defect, but the orange question:** both tools paint the *tag* brand orange
(`dimension-booth.rb:335`, `dimension-selection.rb:92`). A tag colour only shows under
Color-by-Tag; dimension entities draw in the model's dimension colour (Model Info ›
Dimensions, or `material=` via `wr-callout-style.rb`). So the reference's black is not a
departure — it is what the tool has always produced on screen. Recommendation: stop colouring
the tag orange (auto-dimension uses dark grey `[40,40,40]` for its primary tag and orange for
*secondary* doors); leave the dimension colour to the model / callout-style tool.

---

## 4. Decisions (made on Benton's behalf; each reversible)

| # | Decision | Why |
|---|---|---|
| S1 | **New script `scripts/dimension-whisperroom.rb`, module `WR_BoothDims`.** `dimension-booth.rb` is retired (see §9). `dimension-selection.rb` and `auto-dimension.rb` untouched. | "start from scratch"; the selection tool still answers "how big is this thing" for non-booths |
| S2 | **Three dimensions, exterior, and nothing else** (variant A). No label, no door, no vents, no interior. | the reference image |
| S3 | **Every string is measured off the built parts** and attached to them. Catalogue figures are printed beside them as a cross-check, never drawn. | D1, D2, D3, D5 |
| S4 | **A pick tool.** Panel button → cursor picks → click the booth → dims. Esc cancels. If a booth is already selected when the button is pressed, no pick. | Benton's sentence |
| S5 | **Not an ability.** A plain run script plus a companion `Clear WhisperRoom dimensions` script. Per-booth ownership via `persistent_id`. | D7; ability state is model-wide and cannot express "booth 1 on, booth 2 off" |
| S6 | **Tag `WR-Dims-Booth`, tag colour dark grey, no dimension colouring.** | keeps `proposal-scenes.rb` `DIM_TAGS`, `SHOWN_ON_DIMENSIONED`, `annot_tags` and client-safe working unchanged; D9 |
| S7 | **Standoff 24" on all three**, height standoff 36" when the side push is used (A′). Not a setting. Single-axis offsets so each drags cleanly. | prior 24; single-axis rule from 8ca3392 |
| S8 | **Front = the door wall.** Width runs along the door wall's ground edge; depth along the right-hand wall as you face the door; height up the rear corner on that same side. | proposal scenes already read the door side; matches the reference |
| S9 | **Height push: rear (+Y-ish) by default (A); side (A′) when anything sits within 24" behind the booth.** | booths are drawn 1" off a wall (house convention) |
| S10 | **Units forced Architectural**, auto-text only (`<>`), never a text override. | a dimension that lies about its own length is D2 again |
| S11 | Arrow style, font, colour: **model-wide, left alone** (`Model Info › Dimensions`; DEVLOG 1.26.3 — no Ruby API for the font). | one place to set it |

---

## 5. Identification — what counts as "a WhisperRoom"

Pick resolves to the **top-level** `Group`/`ComponentInstance` in `model.entities` containing
the picked entity (`PickHelper#best_picked` + walk `#path` to depth 0). Then, in order:

1. **Name** matches `proposal-package.rb:613 booth_name?` — `/\bMDL\b/` or
   `/\b\d{3,6}\s?[SE]\b/`. Covers `"MDL 96120 E (components)"` (build-booth-components,
   line 2451), `"MDL 4260 S"` (booth-4260-s.rb:63), `build-booth.rb:125` (`key`).
2. **Children** — any child named like a wall part `/\A[NSEW]\d+\s/` (bbc:2675
   `"#{p[:id]}  #{r[:name]}"`) or a deck part `WR_Deck::NAME` / `ENH_NAME`
   (`/\ASTD(\d{2,3})(\d{2})\s*(FL|CL)/i`, `/\AENH\s+…/`).
3. Neither → **refuse**: "Not a WhisperRoom I can recognise — the group is called X. Rename it
   to include the model (`MDL 96120 S`) or use *Measure whatever is selected*." Nothing drawn.

Route 1 with no route-2 parts (a hand-built block-out) → measure the **group bounds** and say
so in the console (`extent: GROUP BOUNDS — no named parts; includes anything in the group`).

---

## 6. The extent — which parts define each string

Measured in **world space**: `child.bounds` is in the booth group's space, so transform its 8
corners by `booth.transformation` (or use `Geom::BoundingBox` of transformed corners). Never
`definition.bounds`.

| String | Parts that vote | Excluded, and why |
|---|---|---|
| Width, Depth (footprint) | outer-shell wall panels `/\A[NSEW]\d+\s/` **except** doors; corner seals `/corner seal/i`; vent housings (they are wall parts, so they are in) | `…Door…` / `…WADoor…` (the swung leaf and ramp live inside that component; the frame face is coplanar with its neighbours — nothing is lost); mid-wall seals `/-seal\d/` (`SEAL_PROUD` is a dial); `MISSING` placeholders; overlays: roof unit (`WR_RoofVent.part_name`), `caster plate`, EFP; anything on `WR-Booth-Missing` |
| Height | floor parts `STD…FL` / `ENH …FL` / `FLi …` (min z) and ceiling parts `STD…CL` / `ENH …CL` / `CLi …` (max z) | walls (a 46VNT box is 81.86 tall, a VSS 82.17 — taller than the ceiling top on Standard), roof units, casters, silencer stacks |

Per side, the console names the part that set it: `E extent 128.44 set by "E0  46VNT"`.

**Cross-check, printed, never drawn:** catalogue `:w :h` + 5.5 per vented face
(vent faces read off the parts as `vents_from_model` does today — keep that regex), height
83.0 / 84.3125 by key. Any axis differing by more than **0.25 in** prints a `***` block
naming the axis, both figures and the part responsible. The dimension still reads the
measured value.

**Casters:** if `caster plate` children exist the height measures mat/floor underside → tray
top as usual and the console adds the plate height separately (`CP_BOOTH_LIFT` territory, not
part of the booth height).

---

## 7. Anchors and placement

Let the extent be `x0..x1`, `y0..y1`, `z0..z1` in world space **after** re-expressing it in the
booth's own frame: use the booth group's X/Y axes (a rotated booth gets dimensions along its
own walls, not the world's). Front `F` = the wall carrying the door part (`DRFRM` slot /
`Door` in the name); default S if none. Right-hand side `R` = the wall to the right when facing
`F` from outside. Rear = opposite `F`. Corner names below assume F = S, R = E; rotate
accordingly.

| Dim | From | To | Offset (booth frame) | Text |
|---|---|---|---|---|
| Width | front-left ground corner `(x0,y0,z0)` | front-right `(x1,y0,z0)` | `(0, −24, 0)` | auto |
| Depth | front-right `(x1,y0,z0)` | rear-right `(x1,y1,z0)` | `(+24, 0, 0)` | auto |
| Height (A) | rear-right ground `(x1,y1,z0)` | rear-right top `(x1,y1,z1)` | `(0, +24, 0)` | auto |
| Height (A′) | same | same | `(+36, 0, 0)` | auto |

A′ is chosen automatically when any other top-level entity's world bounds intersect the slab
`y1 .. y1+24` across `x0-24 .. x1+24` (a wall behind the booth). Console says which and why.

**Attachment (D1).** For each endpoint, in order:
1. A real **vertex** at that corner inside a voting part, addressed with an
   `Sketchup::InstancePath` (`[booth, part, vertex]`) — the 2019+ overload of
   `add_dimension_linear(instance_path_a, point_a, instance_path_b, point_b, offset)`
   (**reported**, from API memory — the Builder verifies this on the bridge before relying on
   it; if the overload does not take nested paths, fall through).
2. A **ConstructionPoint** on `WR-Dims-Booth` at the corner (the 1.17.0 door-jamb precedent).
   Always the case for the vent-projected corner `(x1, y1, z0)` when the housing does not
   reach the corner (a 7296's housings span x 2..48 and 50..96, so `(98, 79.5, 0)` is a
   virtual point). Counted and printed as `synthetic` per endpoint.
3. Bare point — **only** if 2 fails, counted as `:loose`, and the run reports it as a defect,
   never as success.

---

## 8. Ownership, re-run, removal

- Every entity drawn (3 dimensions, any ConstructionPoints) gets
  `set_attribute('WR_BoothDims', 'booth', booth.persistent_id)` and
  `('WR_BoothDims','own',true)`, and sits on `WR-Dims-Booth`.
- **Re-run on a booth** erases only entities whose `booth` attribute matches, then redraws.
  Booth 2 is never touched.
- **Clear WhisperRoom dimensions** (`scripts/clear-whisperroom-dimensions.rb`, same module):
  pick a booth → remove that booth's set; Esc with nothing picked → confirm → remove every
  entity carrying `WR_BoothDims/own`. Never anything else on the tag (a hand-drawn dimension
  someone put on `WR-Dims-Booth` survives — same rule as today's `clear`).
- Also erase any orphan set whose `booth` id no longer resolves (booth deleted) — say so.
- One `start_operation('Dimension WhisperRoom', true)` per run; Ctrl+Z reverses the lot.
- Callable: `WR_BoothDims.dimension(inst)` returns the three `Dimension` entities, so
  `booth-from-link.rb` can add a "dimension it" tick later (not in this build — Q9).

---

## 9. Panel and repo wiring

- New: `scripts/dimension-whisperroom.rb` (`@title Dimension a WhisperRoom…`,
  `@cat Add dimensions`, `@rank 1`, `@icon` as the old one), and
  `scripts/clear-whisperroom-dimensions.rb` (`@cat Add dimensions`). Both read
  `$wr_no_autorun` like their peers.
- Retire `scripts/dimension-booth.rb`: `# @shelf archive`, header note pointing at the new
  file, ability directives removed so the panel stops offering the switch. Do not delete this
  session — a model with its old dims still needs `ability_off` once. (The new Clear tool
  should also sweep `WR_DimBooth/own` entities so the archive can be deleted next release.)
- `scripts/proposal-scenes.rb:50` `DIM_TAGS` and `:114` `SHOWN_ON_DIMENSIONED`: unchanged
  (tag name kept). Update the comment at 45-47 only.
- `scripts/wr_tools/VERSION`: minor bump (new script + retirement).
- DEVLOG entry; `python scripts/rbparse.py` clean on every `.rb`.
- **No settings row** — no `@setting` directives. If a standoff dial is ever wanted it is one
  `@setting gap number 24`, but not in this build (Q6).

---

## 10. Acceptance — must be seen on the bridge, not reasoned

Run through `scripts/sketchup-bridge.py` (`run`/`eval`/`shot`) on a live SketchUp 2026:

1. **7296 E, link-built, no room.** Pick the booth → exactly 3 `Sketchup::Dimension` on
   `WR-Dims-Booth`, no `Text`. Strings read `8' 2"`, `6' 7 1/2"`, `7' 5/16"` **or** the
   console prints a `***` mismatch block naming the axis and the part (this is the Q4
   outcome and is a pass either way — a silent wrong number is the only fail).
2. **Witness lines land.** For each of the 6 endpoints, `dimension.start/end` position equals
   a transformed vertex or a ConstructionPoint within 0.001 in; `:loose` count is 0.
3. **Heights.** Standard 96120 S reads `6' 11"`; Enhanced 96120 E reads `7' 5/16"`; the height's
   lower point z equals the floor stack's world min z (0.0 after 1.33.0), the upper equals the
   ceiling/tray max z. Screenshot the three-quarter view; the vertical string spans the booth
   exactly, no overhang either end.
4. **Placement.** Screenshot from Benton's usual front-right three-quarter camera: width on
   the left-front ground edge, depth on the right-front, height at the right rear, none of the
   three lines crossing the booth silhouette; matches mockup A.
5. **Against a wall.** Booth 1" off a north wall: height goes to A′ (side, 36"), console says
   `rear blocked by "<wall name>"`; nothing drawn inside the wall.
6. **Rotated booth** (group rotated 30°): strings run along the booth's own walls, same
   three values.
7. **Two booths.** Dimension both; re-run on booth 1; booth 2's three remain (count 6).
   Clear on booth 2 → 3 remain, all with booth 1's id. Clear-all → 0.
8. **Pick refusals.** Click empty space → status-bar prompt stays, nothing drawn; click a
   wall group named `N wall` → refusal message, nothing drawn; Esc → tool exits.
9. **Undo.** One Ctrl+Z after a run removes all three.
10. **Proposal package.** `annot_tags` lists `WR-Dims-Booth`; client-safe hides it; a scene
    with it ticked exports with the strings.
11. **Hand-built block-out** (`booth-4260-s.rb`): dims drawn from group bounds, console says
    `GROUP BOUNDS`.
12. `rbparse.py` 0 errors; VERSION bumped; pushed.

---

## 11. Open questions (for Benton — also in the mockup's list)

| # | Question | Default if unanswered |
|---|---|---|
| Q1 | A (height off the rear) or A′ (off the side), or auto by what is behind the booth? | auto (S9) |
| Q2 | Three only (A), or also the plan set with interior clear (B)? | A only |
| Q3 | Was the reference image hand-drawn with SketchUp's Dimension tool, or the old tool's output moved by hand? (Tells us if its witness lines sit on geometry.) | assume hand-drawn; attach to geometry regardless |
| Q4 | When the built vent housing measures other than 5 1/2" proud (a 96120 build read 6 7/16"), which wins: what is drawn, or the rule? | the dimension reads what is drawn; the builder's vent seating is a separate fix, flagged |
| Q5 | Enhanced interior clear height (only for B). | not drawn |
| Q6 | 24" standoff — fine, or further? | 24 |
| Q7 | Pick tool, or select-then-button only? | both (S4) |
| Q8 | Clear per booth (pick) with Esc = all — OK? | yes |
| Q9 | Should *Booth from link* dimension the booth automatically after a build? | no, not this build |
| Q10 | Plain black (model dimension colour) confirmed over orange? | black |

## 12. Not in scope
Room chains (`auto-dimension.rb`), generic object measuring (`dimension-selection.rb`), the
label / interior figures as text, fixing the vent-housing seat in `build-booth-components.rb`
(Q4 follow-up), V-Ray visibility of dimensions (V-Ray ignores `Dimension` entities — reported,
scene-annotations spec).
