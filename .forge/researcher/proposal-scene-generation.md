# Research — Proposal scene generation: can a script place the cameras well?

2026-08-27, Researcher. Read-only; nothing was run in SketchUp (no live bridge). Every
behavioural claim about the SketchUp API is labelled; the geometry is arithmetic that a
Builder can verify with `rbtest.py` fixtures before it ever touches a model.

## Question

Benton: select a WhisperRoom inside a host room, press one button, and get a scene list
— proper front photo, proper angled photo, back photo, "done naturally" — good enough to
feed `scripts/proposal-package.rb` unedited. He frames it as "a script can't be as smart
as an AI." Is that true, or is camera placement here solvable geometry?

## Answer, short version

**The framing is wrong in his favour. Roughly 90% of "a good proposal photo" is
constrained geometry the model can already answer, and the current generator fails not
because scripts can't be smart but because it ignores every piece of information the
model carries.** The booth already declares its door wall (`WR-Booth-Door`) and vent
walls (`WR-Booth-Vent`) — observed, written by every booth builder in the repo. The host
room already declares its interior footprint (`WR-Floor`), its walls in two height bands
(`WR-Room` / `WR-Room-Upper`), and its doors (`WR-Doors`) — observed,
`scripts/build-room.rb:375-380`. The scene list itself is mandated (CLAUDE.md render
order; `reference/proposal-playbook.md` §4) and the current script already names and
orders it correctly. What is missing is the middle: a camera solver that (a) aims at the
booth instead of the whole model, (b) reads the door heading in the right coordinate
frame — the current code has a real bug there — and (c) knows the camera has to stand
inside the host room, or deliberately outside it over a lowered wall. All three are
arithmetic, written out below.

**Recommendation: fix `scripts/proposal-scenes.rb`, do not build a second generator.**
The scene names, ordering, tag discipline, panel ability wiring, and the
proposal-package handoff are already right in that file; only `subject_bounds`,
`heading_to`/`walk`, and `aim` — about 80 of its 277 lines — need replacing. A parallel
tool would fork the plate-name contract that `proposal-package.rb` and the playbook both
key on.

The honest residue that is NOT geometry: which of the two legal three-quarter sides
looks better when both fit, whether technical plates show the room at all, sun/style
taste, and everything V-Ray (still zero observed behaviour repo-wide). Each has a named
disposition below — choose-and-say, not silent fallback.

---

## 1. Diagnosis — why the current generator "kind of sucks"

`scripts/proposal-scenes.rb` (277 lines, read in full). The plate list, the per-scene
dimension-tag discipline (`DIM_TAGS` / `SHOWN_ON_DIMENSIONED`, lines 51-63), the
replace-don't-duplicate scene handling, and the ability on/off wiring are all sound and
worth keeping. The camera placement has four specific defects:

**D1 — It frames the whole model, not the booth (observed).** `subject_bounds`
(lines ~96-104): with nothing selected it takes `model.bounds` — room, dimensions,
notes, everything. `aim` (lines ~120-140) then stands the camera at
`dist = radius * 3.2 + 60` from that centre. For a 15' room the camera lands ~75 feet
out. The booth is small, off-centre, and the "centre" being framed is the room's centre,
not the booth's.

**D2 — It never consults the host room (observed by absence).** No line of the file
reads `WR-Floor`, `WR-Room`, or `WR-Room-Upper`. The eye position is never tested
against the room's interior; there is no sightline check; no wall is lowered or hidden.
So the "hero exterior in the finished room" is shot from far outside the room, looking
at the backs/outsides of the host walls — the exact situation the two-band wall
mechanism (`WR-Room-Upper`, `scripts/build-room.rb` header lines 44-77) was built to
solve, and which `.forge/scoper/scene-wall-lowering.md` documents Benton solving by
hand today. `page.use_section_planes = true` is set (line ~228) but no section plane is
ever created.

**D3 — The door/vent heading is computed in the wrong coordinate frame once the booth
has been moved (derived; high confidence).** `walk` (lines 76-84) descends into groups
and component definitions and collects `e.bounds` **untransformed**. A drawing
element's bounds are expressed in its parent's coordinate system (reported — SketchUp
API semantics; the repo itself codes around this correctly elsewhere:
`scripts/booth-from-link.rb:1558` and `:1583` accumulate `tr * e.transformation` while
walking, which is the pattern `walk` lacks). The booth builds as a group at the model
root in booth-local coordinates near the origin (`scripts/build-booth-components.rb:2191`
`model.entities.add_group`; part transforms are in the 0..w booth frame per
`scripts/wr-booth-data.rb`), and Benton then moves that group into the host room by hand
(assumed — no placement code exists in the repo; this is the only way a booth gets into
a room today). After that move, the door instance's local bounds are subtracted from a
**model-space** centre (`heading_to`, lines 88-95), and `door_az`/`vent_az` come out
wrong — precisely in the real use case, a booth placed in a room away from the origin.
The script's own report then says "aimed at the real door" while aiming somewhere else.
This alone explains "I look at it and it grabs like five scenes and it kind of sucks."

**D4 — The angles are constants, not decisions (observed).** Three-quarter is always
`door_az + 35°` — same sign regardless of which side of the door wall has room to
stand or what the adjacent wall is. Vent view is always `vent_az + 25°`. Elevations are
fixed (12/20/14/89), FOV is fixed at 40, ortho height is `radius * 2.3` of the
whole-model diagonal (D1 again). The plan view pins `up = (0,1,0)` at 89° elevation
(line ~131), so the door wall does not necessarily read at the bottom of the sheet.

Summary: right scene list, right tag bookkeeping, cameras placed by a formula that
knows neither where the booth's door really is nor where a camera can physically stand.

---

## 2. Q1 — Can a script identify the door wall and vent walls? YES (observed)

- `WR-Booth-Door` and `WR-Booth-Vent` tags are written by every booth path:
  `scripts/build-booth-components.rb:2185-2187` creates them and lines ~2425-2431 assign
  them **by component name** (`/Door/i`, `/VNT/i`), deliberately not by the layout's
  static slot kind — the comment at lines ~2400-2410 records that a customer can move a
  door/vent into a slot the layout calls SOLID, so the name is the truth. Also
  `scripts/build-booth.rb:116-118` and the hand scripts (`booth-4260-s.rb:56-60`,
  `booth-96168-s.rb:62-66`). `scripts/booth-from-link.rb` builds through
  build-booth-components, so a customer-link booth carries the same tags.
- The remaining booth anatomy is tagged too: `WR-Booth-Walls`, `WR-Booth-Seals`,
  `WR-Booth-Corners`, `WR-Booth-Deck` (floor+ceiling, `build-booth-components.rb:2437`),
  and the overlay pass adds `WR-Booth-Foam` / `WR-Booth-Options`
  (`scripts/wr-overlays.rb:547-548` — file under active edit by a Builder; the tag names
  are stable enough to cite).
- The booth's door **swing arc** is loose edges inside the door component itself
  (reported — `scripts/angled-component-art.rb:496-510` discusses exactly those arcs),
  so the plan plate shows the swing with no extra drawing.
- **The cheap fix that makes the tags usable:** compute the door heading with
  accumulated transforms (the `collect_points` pattern above), i.e. door direction
  = unit(world-centre of `WR-Booth-Door` geometry − world-centre of the booth group),
  projected to XY. Snap it to the nearest booth-local wall normal (the booth is
  rectangular; four candidates) so a swung leaf cannot skew the heading. ~30 lines.

Nothing new needs authoring; the foundation Benton doubted already exists.

## 3. Q2 — Can a script find where a camera can stand? YES, with one escalation ladder

**The walkable region.** The host room's interior polygon is recoverable from the model:
`build-room.rb` builds the floor group from the interior polygon and tags it `WR-Floor`
(`scripts/build-room.rb:375, 391`). Take the WR-Floor group's top face outer loop →
polygon `P` (handles L-shapes, not just rectangles). The booth footprint `B` is the
booth group's world-space XY bounds. Cameras stand in `P` minus `B`.

**Standoff available.** For a plate with target `t` (booth centre, world) and view
azimuth `a`: cast the 2D ray from `t` along `−view_direction` and intersect it with each
edge of `P`; the nearest hit distance minus a 4" clearance is `s_avail`. This is a
dozen lines of segment intersection, unit-testable in `rbtest.py` fixtures with no
SketchUp at all.

**Standoff required (perspective plates).** Let the booth's visible extents from
azimuth `a` be `H` (ground to tray top — 81"/91" wall + deck; use the booth group's
world bounds z-extent rather than a catalogue figure) and
`W = |w·cos(a−a₀)| + |d·sin(a−a₀)|` (the XY bounds projected across the view). With
vertical field of view `f_v` and viewport aspect `r` (`tan(f_h/2) = r·tan(f_v/2)`),
margin `m` (suggest 0.10):

```
d_req = max( H(1+m)/2 / tan(f_v/2) ,  W(1+m)/2 / tan(f_h/2) )  +  (booth depth along view)/2
```

Caution for the Builder: whether `Sketchup::Camera#fov` is the vertical or horizontal
angle depends on `Camera#fov_is_height?` (reported — API docs; never exercised in this
repo). Verify live before trusting the fit; the symptom of getting it wrong is a hero
cropped top-and-bottom.

**Sightline check.** Before saving the scene, `model.raytest(eye→t)` (reported API,
unexercised here) and confirm the first hit is booth geometry (tag `WR-Booth-*`), not a
room wall — the same trick `scripts/wr-preflight.rb:132-159` already uses tags for.

**When the room is too small — the case that breaks naive tools.** Real host rooms
often cannot give `d_req` (a vent wall sits 6" off the host wall — clearance table in
CLAUDE.md). Escalation ladder, each step **printed by name** in the run report (repo
rule: no silent fallback):

1. **Widen FOV** up to a cap (suggest 60°) and recompute `d_req`.
2. **Swing the azimuth** ±15° in 5° steps toward whichever direction maximises
   `s_avail` (this is also how the tool picks the three-quarter's left/right sign —
   the side with more floor wins, and the report says which and why).
3. **Go through the wall, deliberately.** Place the eye outside `P` at `d_req` and make
   the crossed wall not block, exactly the way Benton does by hand today
   (`.forge/scoper/scene-wall-lowering.md`, observed): hide `WR-Room-Upper` on that
   scene (scenes persist tag visibility; `page.use_hidden_layers = true` is already
   set). The sightline must clear the 48" stub (`DEFAULT_SILL`,
   `scripts/build-room.rb`): with the wall plane at distance `d_w` from the target,
   stub top `z_s = 48`, target height `z_t` (≈ H/2), eye distance `d_e`:

   ```
   eye_z  ≥  z_t + (z_s + 2 − z_t) · d_e / (d_e − d_w)
   ```

   i.e. lift the camera until the eye→target line passes 2" above the stub where it
   crosses the wall. If the model has no `WR-Room-Upper` band (hand-built room), the
   alternative is per-scene hidden **objects** on the specific wall-band groups —
   `Page#use_hidden_objects` exists since SketchUp 2020 (reported, unexercised in this
   repo) — or `scripts/wr-split-walls.rb`, the existing supervised retrofit.
4. **Refuse that plate by name** and build the other four. Never a wrong camera saved
   silently.

## 4. Q3 — What each mandated plate reduces to, numerically

The list is fixed (CLAUDE.md; `reference/proposal-playbook.md` §4: hero exterior →
dimensioned → side elevation → rear/ventilation → plan). Provenance warning first:
**the repo contains no eye-height or FOV standard** — `reference/*.md` was searched and
has none (observed absence); the only precedent is the current script's own constants
(FOV 40, elevations 12/20/0/14/89, offsets +35/+25 — observed). Everything marked
*invented* below is a proposed default for Benton to nudge, not a sourced figure.

| Plate | Projection | Azimuth | Eye height / elevation | Fit rule | Visibility |
|---|---|---|---|---|---|
| 01-exterior (hero) | Perspective, FOV 50° *(invented; current 40 observed)* | door_normal ± 35° *(35 observed as current default; sign chosen by max `s_avail`)* | eye_z = 66" standing eye *(invented convention)*, aimed at booth mid-height ≈ H/2 | `d_req` formula §3; **eye must be inside `P`** — the brief says "in the finished room", so ladder step 3 is not allowed here, only 1, 2, 4 | Room fully visible; all dim tags off; optionally auto-run `wr-sun-aim.rb`'s aim after placing (reuse, §6) |
| 02-dimensioned | Parallel *(observed current)* | same family as 01, or straight-on door elevation — the shipped PeoplesSpace pack contains **both** a "Dimensioned Elevation" and a "Dimensioned Three-Quarter" (playbook §12, observed) | elevation 20° *(observed current)* | ortho `camera.height = 1.1 × max(H, W)` of the **booth+dims** extents, not the model diagonal | `WR-Dims` + `WR-Dims-Doors` on, others off (observed policy, keep verbatim) |
| 03-side | Parallel, true elevation | door_normal + 90°, side chosen = the non-vent side (vent gets its own plate) | elevation 0 | ortho height 1.1 × booth H | Evidence leans booth-only (PeoplesSpace `Side.png`/`Front.png` were booth-on-white plates — reported from playbook §12 + §5 trim rules); hide `WR-Room*`/`WR-Floor` on this scene, or lower walls — **open question for Benton** |
| 04-ventilation | Parallel *(observed current)* | vent_normal ± 25° *(observed current offset)*, sign by `s_avail` | elevation ~15°, or higher per the stub-clearing formula when shooting over a lowered wall | ortho height 1.1 × booth H | **This is the wall-lowering plate**: when the vent wall faces a host wall inside the 6"/10" clearance, hide `WR-Room-Upper` on this scene (the mechanism scoper already validated end-to-end through proposal-package — `.forge/scoper/scene-wall-lowering.md`) |
| 05-plan | Parallel, elevation 90 | n/a | camera above **room** centre | ortho height = 1.1 × max(room extents) — frame the room, not the booth: the plan is the placement story | `up` vector = −door_normal so the booth door reads at the bottom of the sheet *(replaces the 89°/up-Y dodge; at el 90 with an explicit non-parallel up there is no singularity)*; door swing arcs come free from the door components and `WR-Doors-Leaf` |

The scene properties block (use_camera, use_hidden_layers, transition_time 0, etc.,
lines ~222-229 of the current script) is correct as-is; so is restoring camera/page/tag
state afterwards.

`proposal-package.rb` needs nothing more than these scenes existing with stable names:
it enumerates `model.pages` in tab order and writes `<SceneName>.png` per its stored
per-page mark (`scripts/proposal-package.rb:146-150, 124-137`, observed). No new
interface between the two tools is required.

## 5. Q4 — What is genuinely not geometry, and the named disposition

1. **Left vs right three-quarter when both sides fit.** Taste. Tool picks by larger
   `s_avail`, ties broken toward showing the vent wall as the receding face, and
   **prints the choice**. Cheap for Benton to overrule: nudge and re-save the scene —
   the current file's stated philosophy (lines 26-29), worth keeping verbatim.
2. **Do technical plates (02/03) show the host room?** The shipped pack leans
   booth-only; the wall-lowering work leans room-visible for 04. Not derivable.
   Disposition: one dialog choice ("Technical plates: booth only / room lowered /
   room full"), default booth-only, recorded in the console report. Open question.
3. **Sun, style, materials.** `wr-sun-aim.rb` makes the sun placement geometric once
   the camera exists (observed — reads the camera, writes only shadow_info); style and
   the draft/render material story belong to `wr-mode.rb`/`proposal-package.rb`, not
   this tool. Whether the hero *composition* sings is Benton's eye; the tool's job is
   to make the default not embarrassing.
4. **Everything V-Ray.** Whether V-Ray honours hidden tags, hidden objects, or section
   planes is unobserved repo-wide (`probe-vray.rb` banner). The wall-lowering spec
   already flags the hidden-tag case for the first acceptance run; hidden **objects**
   should ride the same probe.
5. **Rooms not built by `build-room.rb`.** No `WR-Floor` / `WR-Room-Upper` (legacy and
   hand models use per-client tags — `.forge/scoper/scene-wall-lowering.md` findings
   item 1, observed). Disposition: ask the user to click the floor face (one pick), or
   refuse by name. Never guess a room from `model.bounds` — that is defect D1 reborn.
6. **Clutter between camera and booth** (desks, host furniture). The raytest sightline
   check detects it; the disposition is to report the blocking entity by name and let
   Benton move it or accept it, not to auto-hide customer geometry.

## 6. Reusable-code inventory

- `scripts/proposal-scenes.rb` — keep: PLATES list/names, DIM_TAGS discipline, scene
  replace/restore, ability on/off, report style. Replace: `subject_bounds`,
  `walk`/`heading_to`, `aim`, the azimuth `case` in `run`.
- `scripts/booth-from-link.rb:1558,1583` — `collect_points`/`collect_faces`: the
  correct transform-accumulating walk to copy for world-space tag centres. (File under
  active edit; copy the pattern, do not depend on the file.)
- `scripts/orbit-export.rb:156-175` — clean spherical `aim` with the parallel-projection
  scale discipline and the up-vector table; `scripts/elevation-export.rb:45-63,
  291-337` — axis-true elevations, `aspect_ratio`, view-height fit, and the
  camera-must-outrun-clipping note (`elevation-export.rb` ~323-325; same warning at
  `angled-component-art.rb:385-396`). These are the proven camera idioms to build on.
- `scripts/wr-sun-aim.rb` — sun-to-camera for the hero, already a one-call module.
- `scripts/build-room.rb` (two-band walls, `WR-Floor`), `scripts/wr-split-walls.rb`
  (retrofit), `.forge/scoper/scene-wall-lowering.md` (the analysis that the scene→
  package pipeline honours per-scene tag visibility with zero changes — observed
  citations inside it).
- `scripts/wr-preflight.rb:132-159` — tag-prefix-based "what did the ray hit" idiom.
- `scripts/prefix-scenes.rb` — collision-refusing scene renaming, the precedent for
  multi-booth prefixes.
- `scripts/check-iso-coverage.py` — **not camera math** (observed, read in full): it
  reconciles a scene list, an exporter's diagnostics, and the PNGs on disk. Reusable
  only as the pattern for a "did every plate export" audit; nothing in it reasons about
  views.

## 7. Q5 — Four WhisperRooms in four host rooms

He said assume one; the method must still repeat cleanly:

- **Scope by selection.** Select booth group → that booth's five scenes, named with a
  prefix (`R1 01-exterior`, …). Scene names are the filenames
  (`proposal-package.rb`, observed), so the prefix is what keeps 20 scenes from
  colliding; refuse on collision like `prefix-scenes.rb` does. The room that booth
  belongs to = the `WR-Floor` face whose polygon contains the booth's footprint centre
  — derivable, no user input.
- **What actually changes at four (found, not speculative):** the dimension tags are
  global. `build-room.rb` puts every room's dims on one `WR-Dims` tag, so plate 02 for
  room 1 would show all four rooms' dimension strings. Same for `WR-Room-Upper`:
  lowering walls for room 1's vent plate lowers every room's upper band (harmless if
  the other rooms are out of frame; visible if not). Disposition: per-scene hidden
  objects on the other rooms' groups (SU2020+ API, unexercised), or per-room tags —
  a small `build-room.rb` change (`WR-Dims-<room>`); name it in the run report until
  one ships. Hero framing may also catch a neighbouring room in the background —
  acceptable in an office floor plan, but the report should say the frame contains
  more than the subject room.
- Ability on/off must then remove *prefixed* scene sets, not just the five bare names
  (`scene_names`, current lines ~146-148, would miss them).

## Confidence & gaps

- Tags, plate policy, the D1/D2/D4 defects, and the package handoff: **observed** in
  the cited files.
- D3 (coordinate-frame bug): **derived** from API semantics that this repo itself codes
  around in `booth-from-link.rb`; not executed (no SketchUp here). If Benton in fact
  never moves the booth group after building — nothing in the repo says he doesn't —
  D3 is latent rather than active, and D1/D2/D4 still account for the bad output.
- All camera constants marked *invented* are exactly that; the fit formulas are plain
  trigonometry a Builder should fixture-test via `rbtest.py` before live use.
- `raytest`, `fov_is_height?`, `use_hidden_objects`: **reported** API, never run from
  this repo. Each is verify-first work for the Builder.
- V-Ray behaviour of any hidden state: **assumed** until `probe-vray.rb` and one manual
  render happen (GOAL.md item 3, still Benton's).
- I could not look at the actual PeoplesSpace PNGs (Desktop path, out of scope for a
  read-only researcher in this repo); claims about what those plates show are
  **reported** from `reference/proposal-playbook.md` §12.

===REPORT===
Produced: `.forge/researcher/proposal-scene-generation.md` (this file) and
`.forge/researcher/HANDOFF-scene-generation.md`. Verified by reading the cited files in
full or in the cited ranges; no code executed, no files outside `.forge/researcher/`
touched. Blockers: none.
