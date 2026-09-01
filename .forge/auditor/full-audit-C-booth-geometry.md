# Full audit — lane C: booth geometry, the booth-builder link, and dimensioning

Auditor C, 2026-09-01, plugin 1.19.2 at commit `14197b9`. Read-only. Nothing under `scripts/`
was touched; the only files written are this one and `.forge/auditor/HANDOFF-C.md`.

**Environment limits, stated up front.** No SketchUp, no V-Ray, no `ruby.exe` on this machine.
Everything that touches the SketchUp API is traced, not run. Pure-Ruby claims were executed in
SketchUp's own CRuby 3.2 through `scripts/rbparse.py` (`rb_eval`) and are marked **observed**.
Builder and Fixer handoffs are treated as **reported**.

Provenance words, used exactly as the Operating Manual defines them: **observed** / **derived** /
**reported** / **assumed**.

---

## Ranked findings

Ranked by probability x cost; silent above loud; customer-facing above internal.

### C-1  HIGH — the two build paths draw the four split-run booths with MIRRORED side walls, and the standalone path undoes the 28 Aug fix

**Files.** `scripts/build-booth-components.rb:1312-1400` (`ASSIGN`), `:2151` (`run` passes
`ASSIGN[key]`), `scripts/booth-from-link.rb:1085-1089` (passes the link's own `assign`, never
`ASSIGN`), `scripts/gen-booth.py:90-97, 456-461` (`SWAP_TWO_PANEL_SIDE_WALL`),
`scripts/build-booth-components.rb:2020-2137` (`rebalance_walls` re-walks each wall from slot 0
at the low coordinate with the assigned part's real width).

**What the data says today (observed, rbparse over `wr-booth-data.rb`).** E/W slots are walked
south to north, slot 0 at the door end:

```
MDL 7272 S   E0 VNT   y  2..48 (46")    E1 SOLID y 50..72 (22")     W identical
MDL 7296 S   E0 SOLID y  2..48 (46")    E1 SOLID y 50..72 (22")
MDL 6060 S   E1 SOLID y  2..18 (16")    E0 VNT   y 20..60 (40")     <- ids reversed by the 1.7.10 swap
MDL 6084 S   E1 SOLID y  2..18 (16")    E0 SOLID y 20..60 (40")
```

**What `ASSIGN` then does on the standalone dialog path (derived from the observed data plus
`rebalance_walls`, and confirmed by a recorded live transcript).**
`ASSIGN['MDL 6060 S']` maps `E0 => '16PanelSolid'`, `E1 => '40VNT'`. `E0` is now the 40-wide
slot at y 20..60 and `E1` the 16-wide slot at y 2..18, so `rebalance_walls` walks `E1` (40VNT)
first from y 2 and the 40 lands back at the door end — exactly the arrangement Benton reported
wrong on 28 Aug, which `gen-booth.py`'s positional swap was written to remove. The generator
swapped positions; `ASSIGN` swaps slot ids; the two compose to the identity. The live build of
30 Aug (plugin 1.9.0, after 1.7.10) recorded it verbatim
(`.forge/builder/booth-matrix/build/MDL-6060-S.txt:356-361`, **reported**):

```
rebalanced E1  40VNT          2.000..42.000  (slot was 2.000..18.000)
rebalanced E0  16PanelSolid  44.000..60.000  (slot was 20.000..60.000)
```

`scripts/rbtest-live-booth.py:235` passes `WR_BuildBoothComponents::ASSIGN[key]`, so the whole
50-key golden baseline was captured on the ASSIGN path. `HANDOFF-booth-matrix.md` finding 5
("recorded, not adjudicated") is adjudicated here: that baseline holds the pre-fix arrangement.

For `MDL 7272 S/E` and `MDL 7296 S/E`, `ASSIGN` maps `E0 => '22PanelSolid'`, `E1 => '46...'`.
Since the 1.6.34 revert `E0` is the door-end slot, so the standalone path puts the **22 at the
door end and the 46 (window `W1`, vent `E1`) at the far end**, while the link path — no `ASSIGN`,
no `SWAP_TWO_PANEL_SIDE_WALL` entry for (46, 22) — builds the 46 at the door end. The `ASSIGN`
comment at `:1355-1357` still says "the 46 in part takes slot 1 (y 2..24), the 22 in panel slot
0 (y 26..72)" — that is the pre-27-Aug geometry (`aecf61a`, 14 Aug), and `ASSIGN` was never
revisited when the walk was reverted (`941fb3d`, 27 Aug; last `ASSIGN` edit `9b72bb6`).

**Trigger.** Panel button *Build from real components* (standalone) on any of 6060 / 6084 /
7272 / 7296, Standard or Enhanced, versus *Build the customer's booth (share link)* for the same
model. Eight catalogue keys.

**Failure.** Silent. Both builds close exactly (short+2+big equals big+2+short), the console
prints `exact` on every panel, and the window / vent / seam seal sit at opposite ends of the
side wall depending on which button was pressed. A customer render from one path contradicts a
render from the other, and one of the two contradicts the hinge slots on the physical part.

**On the 27 Aug `HANDOFF.md` question ("The 22" wall is where the window should be") — STILL
OPEN.** No pinned 7272 case exists: `rbtest-part-orientation.py` asserts (46, 22) is *not*
swapped, and nothing asserts what the standalone path produces. The question "does the 46 sit
at the door end or the far end on a real 7272" is still unanswered on disk, and the code now
gives both answers.

**Fix direction.** One owner for E/W order. Either delete every E/W entry from `ASSIGN` (the
N/S entries and the 7272's explicit vent/window choices can stay) so the generated data is the
only place order lives, or key `ASSIGN` on position rather than slot id. Then add a pinned test
that runs `ASSIGN` through the real data for all four booths and asserts the door-end panel
width on both paths. Regenerate the booth-matrix baseline afterwards — it is currently a golden
copy of the defect. The 7272/7296 direction itself is one tuple in `SWAP_TWO_PANEL_SIDE_WALL`
and needs Benton's eye on a built booth, as the generator's comment already says.

---

### C-2  HIGH — auto-dimension never dimensions a door on any room this workspace builds

**Files.** `scripts/auto-dimension.rb:322-329` (`doors_on` iterates `model.entities` only, no
descent), `scripts/build-room.rb:393, 413, 257-262` (`room` > `Doors` > `Opening n`, the
`WR-Doors` tag is on the opening group two levels down), `scripts/build-takeoff.rb:248, 275`
(same nesting).

**Trigger.** Any room from *Build the room* or the take-off pipeline, then *Dimensioned* on, or
the automatic `dimension_face(floor)` call at `build-room.rb:450` / `build-takeoff.rb:307`.

**Failure.** Silent. `doors_on` returns `[]`, `res[:doors]` is 0, the report prints
"0 door(s) dimensioned" among healthy-looking numbers, and the drawing goes out without the
corner-to-jamb and opening-width dimensions that `reference/sketchup-drawing.md` calls "not
optional — this is how a booth actually gets placed against a wall". **Derived**: the nesting is
observed in both builders and `doors_on` has no walk; it was identical before 1.17.0
(`git show be75055^:scripts/auto-dimension.rb`), so this is long-standing, not a regression, and
the 1.17.0 ConstructionPoint work for jambs (`:405-410`) is currently unreachable code.

**Fix direction.** Reuse the transform-carrying `collect` walk (`:113-125`) to find `WR-Doors`
entities at any depth and read their bounds in world space, or read the room group's `Doors`
child directly. Then the jamb ConstructionPoints (C-3) become live and need the same scrutiny.

---

### C-3  HIGH (unrun) — the 1.17.0 attached dimensions: a nested Vertex is attached with no InstancePath, the `:loose` count is never printed, and jamb ConstructionPoints are never cleared

**Files.** `scripts/auto-dimension.rb:249-262` (`attach_for` returns a bare `Vertex` when
`path` is nil), `:430-433` (`ability_on` and `build-room.rb:450` call `dimension_face` with no
`:path`, ever), `:405-410` (`cpoint_for` adds the ConstructionPoint to `model.entities`, then
wraps it in `[path, cp]` if a path was given — a path to a container the point is not in),
`:574-600` (`report` prints `made`, `doors`, closure — never `res[:loose]`), `:490-497`
(`clear_dims` greps `DimensionLinear` only).

**Trigger.** The normal path: a floor face inside a room group. `vertex_index` transforms the
positions to world (correct), `attach_for` finds the vertex and hands SketchUp the vertex
object bare, from a different entities context than the dimension is drawn in.

**Failure.** Cannot be run here, so two outcomes are possible and both are bad. (a) SketchUp
rejects the cross-context reference — `dim` rescues to nil, `made` is short, and the console
prints a lower count with no reason. (b) SketchUp accepts it and attaches in the group's local
frame — identical to world on a freshly built room, so it looks right, and drifts the moment the
room is moved, which is the 16 Aug defect class (`e90321d`) returning. Either way the guard the
DEVLOG promises ("COUNTED and returned as :loose, so a silent regression cannot look like
success") is half built: the count exists in the return hash and no caller prints it, so the
DEVLOG's Next-step 1 ("if the console reports dimensions as loose") can never fire.
Separately, once C-2 is fixed every *Dimensioned* toggle adds two ConstructionPoints per door on
`WR-Dims-Doors` and `clear_dims` never removes them — they accumulate on the tag the proposal
plates turn on. **Derived**; the API behaviour of a bare nested Vertex is **assumed** unknown.

**Fix direction.** Build an `InstancePath` to the floor face in `floor_face` (it already walks
the containers; keep the instance chain alongside `tr`) and pass it as `:path` from every
caller; add the ConstructionPoints to the face's own `parent.entities` so the `[path, cp]` form
is honest; print `loose` in `report` and make it a warning line; erase `ConstructionPoint` on
`OWN_TAGS` in `clear_dims`. Then run Next-step 1 for real.

---

### C-4  HIGH — no Ruby build script in this lane asserts an Untitled model before writing to `Sketchup.active_model`

**Files** (every `active_model` write site in the lane, none preceded by a `model.path` test —
**observed** by grep, `model.path` appears in the lane only for reporting in exporters):
`scripts/build-booth-components.rb:2167`, `scripts/booth-from-link.rb` (calls into it),
`scripts/build-booth.rb:104`, `scripts/auto-dimension.rb:514, 535, 543`,
`scripts/dimension-booth.rb:553, 713`, `scripts/dimension-selection.rb:235, 266`,
`scripts/explode-view.rb:448`, `scripts/reorient-model.rb:166`, `scripts/merge-materials.rb:294`,
`scripts/wr-split-walls.rb:265`, `scripts/wr-name-walls.rb:156`.

The guard exists only on the Python side of bridge jobs (`scripts/rbtest-live-booth.py:176-179`,
`eval-floorplan.py` per DEVLOG) and in `WRB.scratch!` (`scripts/wr-bridge-lib.rb`, wipe only).
The house rule, restated in `.forge/GOAL.md` and the DEVLOG for 1.12.9, is that the guard lives
INSIDE the Ruby job because the active model changes between a Python pre-flight and the job.

**Trigger.** Any agent-driven bridge job that `load`s one of these scripts directly (rather than
through a harness that wraps its own guard) while Benton has a client file in front.

**Failure.** Loud only after the fact: a booth or a dimension set lands in a saved client model.
Twice on 31 Aug the active model became `Master Component List.skp` between jobs (DEVLOG).

**Tension to resolve, not ignore.** These are also panel tools Benton runs deliberately into
client rooms, so an unconditional refusal would break the product. **Fix direction:** one
`WRB.assert_untitled!` (raise by name with title and path) in `wr-bridge-lib.rb`, called at the
top of every mutating entry point **when the script is running under the bridge** — a global the
bridge sets (`$wr_bridge_job`) or a `cfg['scratch_only']` key that every harness passes. The
guard is then in the Ruby, atomic with the build, and invisible to a human at the panel.

---

### C-5  MEDIUM-HIGH — the deck orientation is a measured rule with four exception layers, and 1.19.2 makes the 7296 contradict the reference's own invariant

**Files.** `scripts/wr-deck.rb:1012-1085` (measured quarter turn, `x_is_along`),
`:1097-1160` (measured half turn from `bracket_edge`, read off the FL twin), `:982-993`
(convention-A ceiling mirror keyed on the hand letter), `:789-790` (`YAW_180_FILES`:
STD4260, STD4872), `:836-839` (`MIRROR_DECK_KINDS`: 7272 FL+CL, 7296 FL only), `:1195`
(mirror applied last).

**Is there a general rule?** Two measured rules (quarter turn from the part's own box, half turn
from the floor twin's bracket line), and then three layers of exception that each patch a model
Benton looked at: the handed-class mirror (60/72 series ceilings), a per-file 180 (4260, 4872),
and a per-footprint mirror (7272, 7296). Each exception's own comment records that it was added
because the layer below it produced the wrong answer for that model. That is a growing list, not
a rule, and the code's own oldest comment names the risk ("a guess that fixes one and breaks
another is this file's oldest mistake").

**Coverage, from the DEVLOG and the handoffs (reported):** eyeballed correct or corrected —
4260, 4872, 4896, 6060, 6084, 7272, 7296, 84126, 96120, 96168, 102144. Recorded by the booth
matrix but never adjudicated for hinge side — 96192 E, 102186 E. **Never looked at by anyone:**
4230, 4242, 4284, 4848, 8484, 9696, 10284, 84102, 96144, 102102, 102126, 102168, 102186 S. The
code itself names 4230 / 4284 / 4848 floors as sharing the 4260's odd-origin trait and
"deliberately NOT listed" (`:783-788`) — three candidates for the next "rotated 90 / turned 180"
report.

**The 7296 contradiction (derived).** `MIRROR_DECK_KINDS[[98,74]] = %w[FL]` mirrors the floor
and not the ceiling, while the ceiling's half turn is read off that same floor twin
(`:982-993`). `reference/floor-ceiling-geometry.md` § "FLOOR AND CEILING HINGES ARE COPLANAR IN
PLAN" calls that an invariant and "a free correctness check". After 1.19.2 the 7296's floor and
ceiling hinges are on opposite sides of the tile **by construction**. Either the invariant is
false for the 7296 (then the reference must say so, and the "free check" is not free), or the
7296 floor is also wrong and has been since 1.10.5. The DEVLOG's own fallback ("put CL back and
add STD7248CL SIDE L/R to YAW_180_FILES") would be a fourth exception layer.

**Fix direction.** Do the per-part ceiling measurement the Fixer handoff already describes
(measure the hardware hanging below a convention-A ceiling's minor level the way `bracket_edge`
measures a floor's hardware above its rim) the next time a probe can run in SketchUp, and retire
the hand mirror and both per-model tables against it. Until then, print the floor/ceiling hinge
positions side by side on every deck build so the invariant is checked rather than asserted.

---

### C-6  MEDIUM — the MJP still hands `axes_for` a guessed 8.0 height; the same defect that stood the desk on edge

**Files.** `scripts/wr-overlays.rb:910` (`axes_for(gx[:e], MJP_W, 8.0, MJP_T)`), `:464-480`
(`axes_for` scores the guess exactly like the two measured numbers), `:858` (the desk fix:
`nil`), `:152` (`MJP_SPIN180`, a second orientation dial on the same part, added 1.19.2).

**Trigger.** Any link with `jp = 1`, on any host wall. Whether it goes wrong depends on
`MJP.skp`'s real extents, which are not recorded anywhere in the repo; the desk went wrong with a
guess 5.25 off the true axis.

**Failure.** Silent: the plate stands on edge or lies flat, on both faces, with a clean console
line. The DEVLOG says it "renders correctly today" — that is one part file at one revision, and
the 1.19.2 half-turn was tuned on top of the guessed axes. **Derived.**

**Fix direction.** Pass `nil` as the desk does; the width and thickness pick the axes and the
leftover is vertical. Re-check `MJP_SPIN180` afterwards — it may have been compensating.

---

### C-7  MEDIUM — the Enhanced height on the booth label is the drawn 7'-0 5/16", not the catalogue 7'-1"; HX and caster-plate booths get the Standard height silently

**Files.** `scripts/dimension-booth.rb:86` (`HEIGHTS = { 'Standard' => 83.0, 'Enhanced' =>
84.3125 }`), `:594-598` (`auto_h` from an ` E` key — reachable now: 25 Enhanced keys in
`wr-booth-data.rb`, **observed**), `:395-402` (the label string), `:697-701` (HX: console warning
only), no `_CP` handling anywhere in the file (**observed** by grep).

**Rule it breaks.** `CLAUDE.md:121-125`: Standard 6'-11", Enhanced 7'-1" are "the height a room
must give"; quote the catalogue figure when asking "will it fit", the drawn figure only when
transcribing a render's own callout. Standard follows it (83.0 is the catalogue number); Enhanced
does not, and the `Ext dims` label puts `7' 0 5/16"` on the customer plate as if it were the
catalogue. The 15 Aug audit recorded this as "unreachable — no Enhanced booth exists in the
data"; that note is stale since the Enhanced layouts landed.

**Also:** an HX booth (91-in panels) and a caster-plate booth (booth lifted 4.75 in,
`wr-overlays.rb` `booth_lift`) are dimensioned at 83 / 84.3 with, respectively, a console
warning and nothing at all. A drawn height 4.75 to 10 in short of the built geometry, beside a
label naming the model.

**Fix direction.** Height table keyed by variant from the catalogue (85.0 for Enhanced), detect
`_HX` and `_CP` and either refuse the height dimension by name or draw the measured extent with
the label saying so.

---

### C-8  MEDIUM — on the Standard link path an untranslatable pack, a missing variant, or an invalid option slot is quietly replaced with a tool-chosen default

**Files.** `scripts/booth-from-link.rb:850` (`variant = payload['v'] || 'S'` — a payload with
no variant builds Standard), `:868-871` and `:972-976` (untranslatable pack → `odd`, printed to
the console, slot left unassigned → `guess_component` fills it from the layout kind; only
Enhanced refuses), `:396` (`v3_sku` code 9 → `'STDWL7 / WL16'`, which `component_for` cannot
translate, so every 7-in companion slot on a `#3=` link takes the layout default),
`scripts/wr-overlays.rb:437-455` and `:394-435` (`mjp_host` / `desk_host` pick "the widest
window/cable wall" or "widest solid" when the customer's chosen slot is not eligible).

**Trigger.** A Standard `#3=` link with a 7-in companion; a portal pack string this plugin has
not seen; a desk or MJP slot the customer changed after choosing a different wall.

**Failure.** The booth builds, the messagebox says nothing, and one wall or one option part is
where the tool put it rather than where the customer did. Console-only. This is the class the
1.12.11 roof-vent fix was written against ("a wrong drawing wearing the costume of a known
limitation"); the Standard path was explicitly left with "today's behaviour EXACTLY".
**Derived.** Does it ever pick a booth model? No — `payload['m']` must be a string
(`:842-846`), `v3_payload` refuses unknown indices, `build_booth` messageboxes on an unknown key.
The model is never guessed; the variant, a slot's part, and an option's wall are.

**Fix direction.** Treat `odd` on Standard the way `ENH_MISSING_ABORTS` treats it on Enhanced
(refuse by name in the messagebox, with a build-anyway constant); require `v`; make the option
hosts refuse rather than relocate, or at minimum say so in the messagebox.

---

### C-9  MEDIUM-LOW — a malformed `#d=` link is reported as "no design id in that link"

**Files.** `scripts/booth-from-link.rb:196-204` (`hash_payload` rescues every error to nil),
`:1119-1125` (nil falls through to `short_id`, then "Could not find a design id"). The `#3=`
path was built the opposite way (`V3Refusal` by name) and its own comment records why
`unpack('m')` is dangerous — it silently skips characters outside the alphabet.

**Trigger.** A `#d=` link mangled in email (a stripped or substituted character).

**Failure.** Loud but misdiagnosed: the operator is told there is no link, not that the link is
damaged. A skipped character that leaves valid JSON behind would build the wrong booth
silently; that is improbable (`JSON.parse` almost always fails first) but not excluded.
**Derived.**

**Fix direction.** Distinguish "no `#d=`" from "`#d=` present but undecodable" and refuse the
second by name, as `#3=` does.

---

### C-10  LOW — `arch()` still prints `11'-12"` (prior Finding 5, STILL OPEN, now observed)

`scripts/auto-dimension.rb:459-466`. **Observed** in SketchUp's own CRuby via rbparse:
`arch(143.96) = 11'-12"`, `arch(95.98) = 7'-12"`, `arch(11.99) = 0'-12"`. Console run table
only; the drawn entities are formatted by SketchUp. Fix: carry the foot when the rounded inch
reaches 12.

### C-11  LOW — standoff fields parse with bare `to_f` (prior Finding 6, STILL OPEN)

`scripts/dimension-booth.rb:539-543`, `scripts/dimension-selection.rb` `settings`. Cosmetic
offsets only; `2'` reads as 2 in. Unchanged since 15 Aug.

### C-12  LOW — `angled-component-art.rb:336` still dedupes picked scenes by name (prior Finding 4 side-nit, STILL OPEN)

Two identically named scenes collapse to one in that exporter only.

### C-13  LOW — the block-out builder's IEP lift is a stale figure it documents as stale

`scripts/build-booth.rb:18-27` (`IEP_LIFT = 0.3125`, "NO LONGER IN STEP WITH ANYTHING") against
the component builder's measured 0.6875-0.75. Panel-exposed (`@rank 3`). An Enhanced block-out
sits its inner shell 0.4 in low. Internal, quick-look tool; recorded because it is one button
away from a customer plan view.

---

## Prior findings from `.forge/auditor/script-audit.md` (15 Aug) — status

| # | Finding | Status | Evidence |
|---|---|---|---|
| 1 | `start_with?('WR-Dims')` erased `WR-Dims-Booth` / `-Selection` | **FIXED** | `auto-dimension.rb:57-62` `OWN_TAGS` exact membership; `own_dims` `:476-479` uses `own_tag?`; `other_wr_dims` `:483-486` counts the others and never touches them (observed) |
| 2 | `proposal-scenes.rb` `DIM_TAGS` ignored the two new tags | **FIXED** | `proposal-scenes.rb:41` lists all four; `SHOWN_ON_DIMENSIONED` `:62` forces Booth/Selection off on every plate, deliberately, with the reason (observed) |
| 3 | re-exploding compounds distances | **FIXED** | `explode-view.rb:240-320` `home_bounds` — every measurement off home, comment records the defect (observed) |
| 4 | range `0-5` includes the last scene | **FIXED** | `lo = a < 1 ? 1 : a` in all five: `export-scenes.rb:124`, `save-scene-components.rb:182`, `angled-component-art.rb:319`, `elevation-export.rb:206`, `export-component-art.rb:187` (observed) |
| 4-nit | `angled-component-art` dedupes by name | STILL OPEN | `:336` (observed) — C-12 |
| 5 | `arch()` prints `x'-12"` | **STILL OPEN** | executed, C-10 (observed) |
| 6 | `to_f` standoffs | STILL OPEN | C-11 (observed) |
| 7 | list-scenes escaping | not this lane | — |
| note | dimension-booth Enhanced height "unreachable" | **now REACHABLE** — became a live inconsistency | C-7 (observed: 25 ` E` keys) |
| note | `booth-from-link` `ensure $wr_no_autorun = false` set-and-clear | unchanged | `:1081-1085` (observed); still harmless on every current path |

---

## Answers to the seven lane questions, in one line each

1. **Deck orientation.** Two measured rules plus three exception layers (C-5). Special-cased:
   4260, 4872 (file yaw), 7272 (mirror FL+CL), 7296 (mirror FL), 60/72-series ceilings (hand
   mirror). Never inspected: 4230, 4242, 4284, 4848, 8484, 9696, 10284, 84102, 96144, 102102,
   102126, 102168, 102186 S. The MJP 8.0 guess is real and unfixed (C-6).
2. **7272 side walls.** STILL OPEN, and the two build paths now disagree with each other; no
   pinned case exists (C-1).
3. **Link decoder.** `#3=` refuses everything malformed by name and never picks a model
   (146 offline checks pass, observed). `#d=` misreports malformed as "no link" (C-9). Neither
   path picks a model; the Standard path does default the variant, a slot's part, and an
   option's host wall (C-8).
4. **auto-dimension.** Findings 1 and 2 FIXED. Doors are never found on a built room (C-2);
   attachment is unrun and its `:loose` guard is not printed; ConstructionPoints leak (C-3).
   Standoffs 20/48/33 are consistent constants; dimension text is `''` on attached dims so
   SketchUp reports the geometry — no case found where the text could differ from the drawn
   geometry.
5. **dimension-booth.** Standard draws the catalogue 83.0; Enhanced draws 84.3125 (drawn) where
   CLAUDE.md says quote 7'-1" (C-7). Footprint is catalogue plus the 5.5-in vent rule, and the
   console reconciles the two on every run (solid).
6. Prior findings: table above.
7. **Untitled guard.** Absent from every Ruby build script in the lane (C-4).

---

## What is solid

- **All nine offline harnesses pass** on this checkout (observed, this session): `rbparse.py`
  (66 files parse), `rbtest.py`, `rbtest-overlays.py` (27 checks), `rbtest-boothlink-v3.py`
  (0 failures), `rbtest-boothlink-cbl.py` (0 failures), `rbtest-doorswing.py` (0 failures),
  `rbtest-roofvent.py` (0 failures), `rbtest-part-orientation.py` (45 checks),
  `rbtest-live-booth.py selftest` (20 checks). `rbtest-lights.py` is lane B's.
- **`scripts/wr-booth-data.rb` is byte-identical to a fresh `gen-booth.py --all`** run into a
  scratch folder against the live `WhisperRoomQuote/lib/pl-data` (observed: `diff` exit 0,
  1522 lines both). The generated data is in sync with its generator.
- **The `#3=` decoder** (`booth-from-link.rb:206-560`): complete-or-refuse, every table frozen and
  append-only, reserved bits refused rather than masked, length fully determined before any
  field is read, model index never clamped. This is the right shape and the test pins it.
- **The Enhanced and roof-mount refusals** (`ENH_MISSING_ABORTS`, `RM_HALF_APPLY_ABORTS`): a
  wrong booth that looks right is refused before geometry, by name, with a build-anyway
  constant. The Standard path should get the same (C-8).
- **`rebalance_walls`** closes each wall against its own run and leaves it as generated,
  loudly, when it cannot (`:2098-2103`); the slab-vs-bounding-box discipline is sound.
- **Undo safety** holds on every mutating script in the lane (one `start_operation` /
  `commit_operation` with abort on error), and `wr-split-walls`, `wr-name-walls`,
  `reorient-model`, `merge-materials` all default to a dry run.
- **Tag ownership** is exact-match everywhere now; the three dimension tools count each other's
  work and never erase it.
- **Naming contracts** between builder, deck and dimension-booth (`"MDL … S (components)"`,
  `"N0  46VNT…"`, `STD<cross><along>FL`) still hold; `by_deck` still reports the 10284 / 84102
  ambiguity rather than picking.
- **`wr-roof-vent.rb`** seats the roof unit from a measured table, names "+x is Right" with the
  portal's own vocabulary and a photographed proof, and refuses the models with no part.

## Not audited, stated plainly

`elevation-export.rb`, `angled-component-art.rb`, `export-component-art.rb` camera and scale
maths (skimmed for guards and range parsing only, as on 15 Aug); the Enhanced inner-deck
placement (`iep_deck`, `build-booth-components.rb:1029-1278`) beyond confirming its refusals;
the caster-plate and EFP overlay branches beyond their headers. Nothing in this document was
executed inside SketchUp.
