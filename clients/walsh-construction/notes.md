# Walsh Construction: PHAME Tech Lab (room 13), 12 Oct 2026

The request came from Sarah (sales), relayed by Benton. The client wants the Recording Studio package in an 8' x 14' Enhanced, rendered in two ramp configurations with the ADA door in the same place.

Model: `Z:\Sketchup\ClientDrawings\Walsh Construction Tech Lab MDL 96168 E.skp` (new file, saved after every step).

Provenance labels used below: **observed** (I read or measured it myself), **derived** (computed from observed values), **reported** (someone told me), **assumed** (needed to proceed, not checked).

## Open items, in order

1. **Ceiling height is ASSUMED at 8'-0".** It is not on the plan. Benton (reported): "assume 8' ceiling but we don't know". A note on `WR-Notes` in the model says the same. The Enhanced install clearance is 7'-1" (85 in, from the catalog), so the booth fits under 96 in with 11 in to spare (derived). A ceiling under 85 in disqualifies it.
2. **Door 1 is not in the Tech Lab.** Its swing arc is centred 14.4 in east of the Tech Lab's east wall (observed, vector), so it opens into STORAGE 17. The Tech Lab's only door is **door 24** at the SW corner. The plan's dashed booth and Sarah's ramp/PL sketch both sit at the east end, against the east wall. Nothing else depends on door 1.
3. **Booth position differs from the dashed rectangle.** The plan draws the booth 2.9 in off the south wall and 3.0 in off the east wall (observed). The link puts EFS vents on the booth's south wall and on W0. The quote tool's rule (`layout-render.js`) is that EFS reaches out 10 in. The S3 EFS box also overhangs the booth's SE corner by 10.6 in, and the W0 EFS overhangs the SW corner by 10.6 in (observed, model geometry). I placed the booth so its outermost hardware sits 1 in off the south and east walls. That puts the shell **11 5/8 in** off both walls (derived). If the room must match the dashed rectangle, the EFS boxes go through the walls.
4. **Resolved 12 Oct (layout v8):** all 9 foam sheets are now inside the booth, uncut, with the full AP. E1i and W1i were placed; the two S1i squares were replaced by a full sheet and erased. See the acoustic section.
5. **Three duct covers moved off their ports, at Benton's request, for the renders only.** This is NOT a real duct layout. Each one is tagged `wr_walsh/moved_off_port`:
   - Duct Cover hi W0i: y 12.21-24.09 -> 16.88-28.76 (+4.67 along the wall)
   - Duct Cover hi S3i: x 145.91-157.79 -> 141.31-153.19 (-4.60)
   - Duct Cover lo S0i: x 12.16-24.04 -> 16.88-28.76 (+4.72)

   All 4 high covers were then raised flush to the tile underside: top 78.86 -> 80.25. All 4 low covers were dropped onto the elevated floor: z 2.04-16.86 -> 2.75-17.57. All values booth-local, observed by ray.
6. **Bass trap count comes from the package name, not the link.** The link carries `bt` as on/off with no package (`pk`). I used Sarah's "Recording Studio" (reported), which the quote presets give as 3 packs = **6 traps**. If the quote line says otherwise, the count changes.
7. **The take-off is not on the review-sheet pipeline.** `takeoff-check.py` and `build-takeoff.rb` handle only rectilinear E/S/W/N runs, and this room has three angled walls. The take-off lives in `takeoff-vector.json` and was built by `build-techlab.rb`, which uses WR_BuildRoom's own polygon, mitre, wall and door code plus the shared dimension engine. No review sheet exists for this job, and the auto-dimension "chain closure" check can't prove angled runs. Closure was checked separately (below).

8. **Foam count: the importer placed 7 sheets where the BOM gives 9** (MDL 96168 E: 3 x FOAM3 = 9 sheets; reported by the coordinator, not re-checked here). This model is fixed by hand (layout v8, 9 sheets). The importer bug itself is still open.

## Measured constraints (booth-local inches, observed by ray or bounds)

| Constraint | Value |
|---|---|
| Floor (EFP top) | 2.75 |
| Ceiling tile underside | 80.25 |
| IEP beams | x 48.25-49.75, 96.25-97.75, 120.25-121.75; z 76.25-79.25; y 5-93. Anything crossing one tops out at **75.75** (0.5 gap) |
| Ceiling seals | x 45.75-52.25, 93.75-100.25, 117.75-124.25 at z >= 79.25 |
| High duct covers | z 65.43-80.25 |
| Low duct covers | z 2.75-17.57 |
| Clear height between a low and a high cover | **47.86**: a 48 in sheet can't sit over a vent panel |
| Back-wall cover x ranges | low S0 16.88-28.76, S1 60.16-72.04, S3 132.16-144.04; high S0 25.91-37.79, S1 73.91-85.79, S3 141.31-153.19 |
| Right-wall cover y ranges | high W0 16.88-28.76, low W0 25.96-37.84 |
| Trap legs | SW x,y <= 16.38; SE x >= 153.69, y <= 16.37 |
| Wall faces | S 4.38 (H-strip 4.31), N 93.75 (window trim 93.0), W 4.38/4.31, E 165.69 |
| Window trims (N) | x 7.5-42.5 and 55.5-90.5, z 37.2-76.1; 13.0 in clear between them |
| Inner door N3i | x 121.25-165.75 |
| Studio lights | x 19.6-30.4, 67.6-78.4, 139.6-150.4; z 79.03-80.25 |

## Decoded link (observed, importer's own decoder)

`#3=ARIHs-IgAAYGCgQBAQABAAABAA` decodes to **MDL 96168 E**, left-hand door, gray foam:
- **Door:** `WA STDDRFRM L` at N3, the north wall at its east end. The importer builds `LeftWADoorWithRamp` on the outer shell (the ramp only exists on the Standard part) and `ENH LeftWADoor` on the IEP shell.
- **Windows:** WDO3236 at N0 and N1.
- **Vents:** S0, S1, S3 and W0, with VSS and EFS.
- **Flags:** rp 1, ad 1 (ADA), ep 1 (elevated floor), sl 1, bt 1, ac 1, rv 0, hp 0.
- The first link Benton sent decoded to MDL 96168 **S**. He replaced it. Nothing from the S link survives.
- The link matches "8' x 14' Enhanced".
- Exterior 170 x 98 in (14'-2" x 8'-2"), catalog height 7'-1" (models.json).

## Scale anchor and wall table

- **Anchor:** the stated scale `1/8" = 1'-0"` at native 34 x 22 in, which gives 9.000 pt per ft (observed text). Two checks agree:
  - the dashed 8' x 14' rectangle measures 13'-11.8" x 7'-11.8";
  - the red 15'-2 1/2" callout measures 15'-2.3".
- **Room faces:** new walls are black filled polygons (4.8 in thick), and the room face is the fill edge. The exterior wall is a stroked double line, and the room face is the inner line's centre.
- **Tolerance:** +/-0.6 in from line weight, plus the architect's own drafting accuracy (unknown).
- **Walk:** clockwise from the apex (the NW-most corner). Origin is the interior SW corner. +y is plan-up, not true north.

| Run | Wall | Length (derived, plan-vector) |
|---|---|---|
| 0 | exterior diagonal (existing) | 243.65 in = 20'-3.6" |
| 1 | east angled (new) | 77.99 in = 6'-6.0" |
| 2 | east (new) | 118.08 in = 9'-10.1" |
| 3 | south (new) | 243.52 in = 20'-3.5" |
| 4 | west (new) | 205.12 in = 17'-1.1" |
| 5 | NW angled (new) | 164.87 in = 13'-8.9" |

- **Closure:** the polygon is built from intersected face lines, so it closes by construction. The run vectors read back from the model also sum to (0.000, 0.000) (observed).
- **Area:** 478.7 SF, against the plan's stated 479 SF (derived).
- **Angles:** both angled new walls are square (90.0 deg) to the exterior wall.
- **In the model:** the 6 runs, the 2 overalls (24'-4 15/16" x 27'-8 11/16") and both door-24 dimensions (4" and 3') were REDRAWN on 12 Oct evening at the floor (z 0) by `.forge/builder/walsh/dims/room-dims-redraw.rb` after they were found missing; all read back equal to the take-off.
- **Not modelled:** a 1-1.3 in, 23.6 in long projection on the exterior wall's inner face. It is far from the booth.
- **Defaults:** wall thickness 4 in (cosmetic), ceiling 96 in (assumed, see item 1).

## Doors

- **Door 24** (observed, swing arc): south wall, near jamb **4.0 in from the SW corner**, 3'-0" wide, hinge on the west jamb, swinging into the Tech Lab. Height 6'-8" (reported, plan note "(3) new doors at 3-0 x 6-8").
- Both door dimensions (4" and 3') are in the model on `WR-Dims-Doors`.

## Booth position and clearances

All values are in room coordinates and derived from model geometry.
- **Shell:** x 61.89-231.89, y 11.63-109.63 (14'-2" x 8'-2").
- **Shell to walls:** 11 5/8 in to the south wall, 11 5/8 in to the east wall, 5'-1 7/8" to the west wall.
- **EFS to walls:** S3 EFS 1 in to the east wall, south EFS row 1 in to the south wall, W0 EFS 4'-3 7/8" to the west wall.
- **Door 24:** its far jamb to the W0 EFS is 11 7/8 in. The 36 in swing stays clear of the booth.
- **Height:** booth top 84.31 in (IEP tray top). Under the assumed 96 in ceiling that leaves 11.7 in.
- **Placement dimensions:** 13 of them, on `WR-Dims-Booth`, moved from z 90 to the floor (z 0) on 12 Oct evening at Benton's request (`.forge/builder/walsh/dims/booth-dims-to-floor.rb`).

## Option 2: the link's ADA ramp, straight out from the door

- **Ramp:** x 180.89-229.89 (49 in wide, the WA frame), projecting **3'-9 5/8" (45.6 in)** north from the shell. The catalog figure is 45.625.
- **East wall:** the ramp's east edge is 1'-1 5/8" from the east wall at the shell. The angled wall opens out to 44.1 in at the ramp foot.
- **Exterior wall:** from the ramp foot, 6'-2 3/4" at the ramp's east edge and 9'-6 7/8" at its west edge.
- **Landing:** a 60 x 60 in clear area centred on the ramp fits in front of the foot. 60 x 60 is the usual ADA landing figure; I assumed it, it is not a WhisperRoom number.
- **Doors:** the ramp and its landing clear door 24 and its swing by about 12 ft. Door 1 is in another room.

## Option 1: side ramp and platform

- The model has ONE room and booth, with the link ramp in place.
- Benton will duplicate the room and booth, add the side ramp and platform himself, and set the Opt1 scenes' visibility.
- **Organisation:** the room group `Tech Lab 13` and the booth group `Booth - MDL 96168 E` share the tag **`Walsh Assembly`**.
  - Select the two groups, copy, and put the copy on its own tag.
  - The dimensions, notes and the 8 room lights stay top-level on their own tags.
  - I tried a whole-model group earlier and it hung SketchUp, so don't retry it.

## Bass traps (6), both back corners, each 3 high

Measured by ray: the tile underside is 80.25 and the EFP floor top is 2.75 (booth-local).
- Top 56.25-80.25 (flush to the tile).
- Middle 29.50-53.50 (gaps 2.75 below and above).
- Bottom 2.75-26.75 (on the floor).
- Right angle in the corner, legs on the walls.
- They no longer stand in front of the N0 window or the door. That was the original importer placement.

## Acoustic package + 9 foam sheets, layout v8: applied and verified (12 Oct 2026, desktop)

AP 96168 = 5 x 2x4, 2 x 1x4, 14 x 1x2 (`ap-packages.js`, observed earlier). Foam = 9 full sheets, none cut (BOM 3 x FOAM3, reported). The layout is `.forge/builder/walsh/ap9/layout-v8.json`, options S1 + E1. Benton approved it as drawn, including the 7 standing 1x2s and the sheets lying flat (reported, 12 Oct).

Verified live after the final save (observed, `b-verify.rb` + `b-verify.py`; result in `.forge/builder/walsh/ap9/b-verify-final.json`):
- All 30 pieces sit within 0.0000 in of their slots.
- Every gap is at least 0.50 in: to other pieces, to the survey keep-outs, and in 3D to the live traps, duct covers, IEP beams and ceiling seals. Across the NW corner it is 0.625.
- **The tightest spots are exactly 0.50:** sheet tops under the IEP beams (S and N, top 75.75), the 1x2 stacks, and the row/band seams.
- Every piece is seated by multi-ray on the most proud face under it: air 0.0000, none buried. Pieces crossing an H-strip (z ~40-41.5) rest on it: S/W 4.3125, E 165.6875, N 93.6875. The Audimute hang clips sit about 0.12 into the wall, as on v7.
- Audimute fabric (local -y) and foam profile (local +z) face the room. Audimute is on `WR-Booth-Acoustic`, foam on `WR-Booth-Foam`.
- Counts: Foam 9 (no squares), Audimute 5/2/14, traps 6. Nothing hidden. All 16 scenes are unchanged; no camera sits within 12 in of a piece.

Booth-local inches below. Along the wall, S and N run in booth x and E and W in booth y. The z values run up from the booth origin. Positions are derived (layout v8) and verified live.

**Back (S), seen from inside, left to right (booth x falling):**
- standing 1x2 under the S3 high cover: x 140.93-152.93, z 40.75-64.75;
- foam `S3i`: x 116.17-140.17, z 27.75-75.75;
- AP 2x4: x 91.41-115.41, z 27.75-75.75;
- three flat 1x2s under the S1 high cover: x 66.65-90.65, z 27.75-39.75 / 40.25-52.25 / 52.75-64.75;
- foam `S0i`: x 41.89-65.89, z 27.75-75.75;
- three flat 1x2s under the S0 high cover: x 17.13-41.13, same z values;
- bottom row, z 3.25-27.25:
  - foam `S1i` lying flat, x 78.10-126.10, between the S1 and S3 low covers;
  - two standing 1x2s, x 31.96-43.96 and 44.96-56.96, between the S0 and S1 low covers.
- Totals: 3 foam, 1 x 2x4, 9 x 1x2.
- The wall is not mirror-symmetric, because the vent columns aren't. Every band gap is 0.76, including the gaps to the trap stacks.

**Left (E), symmetric about y 54.69, seen from inside, front (left) to back (right):**
- band z 30.625-78.625: AP 2x4 y 67.69-91.69 | foam `E0i` y 42.69-66.69 | AP 2x4 y 17.69-41.69;
- row z 3.25-27.25: standing 1x2 y 79.69-91.69 | foam `E1i` lying flat y 30.69-78.69 | standing 1x2 y 17.69-29.69.
- Totals: 2 foam, 2 x 2x4, 2 x 1x2.

**Right (W), seen from inside, back (left) to front (right):**
- back cluster:
  - flat 1x2, y 17.44-41.44, z 18.125-30.125 (0.55 above the W0 low cover);
  - standing 1x2, y 17.19-29.19, z 30.625-54.625;
  - 1x4, y 29.69-41.69, z 30.625-78.625.
- foam `W0i` y 42.69-66.69 and AP 2x4 y 67.69-91.69, both z 30.625-78.625;
- foam `W1i` lying flat, y 43.19-91.19, z 3.25-27.25.
- Totals: 2 foam, 1 x 2x4, 1 x 1x4, 2 x 1x2.

**Front (N, door wall), seen from inside, left to right:**
- row z 3.25-27.25: foam `N0i` lying flat x 7.00-55.00 | standing 1x2 x 57.875-69.875 | foam `N1i` lying flat x 72.75-120.75 (0.50 off the door frame);
- 1x4 between the windows: x 43.00-55.00, z 27.75-75.75;
- AP 2x4 beside the door: x 96.75-120.75, z 27.75-75.75.
- Totals: 2 foam, 1 x 2x4, 1 x 1x4, 1 x 1x2.

**Moves from v7:**
- Foam:
  - S0i, S3i, E0i and W0i were moved.
  - E1i and W1i were placed from staging and renamed `Foam  E1i` / `Foam  W1i`.
  - Three copies of the `Foam` definition were added: `Foam  S1i` (restores the cut S1i), `Foam  N0i` and `Foam  N1i`.
  - The two S1i 2x2 squares were erased after the full sheet was placed and verified.
- Audimute pieces that changed wall were renamed `<part> <wall>` and their `wr_walsh/wall` updated:
  - 1x2s to the back: 2 from the left wall, 2 from the right wall, 2 from the front wall;
  - one 2x4 from the front wall to the left wall;
  - one 1x4 from the left wall to the front wall.
- Every placed piece carries `wr_walsh/v8_slot`, its id in `layout-v8.json`.
- Each wall was one undo step, and the model was saved before the first edit and after each wall.

## Studio lights, IEP beams, lighting

- **Studio lights:** 3 x SL52 from the importer, flush to the tile (+0.0000 at 9/9 points, from the importer log).
- **IEP beams:** 3 x IEP BEAM 8, one under each ceiling seal, top 79.25.
- **Room lights:** 8 V-Ray 2x4 rectangle lights on `WR Lights` at z 95.5, 4000 lm product, 5000 K, invisible to camera. That is about 67 lm/SF, the CCU density.
- The file was upgraded to the current V-Ray, so older V-Ray versions can't open it.

## Scenes

**Current (12 Oct evening, observed):** Benton cut the set to 9 scenes and renamed the series: `Opt2` is now `Ramp` (the link's ADA ramp, Option 2) and `Opt1` is now `Platform` (side ramp + platform, Option 1). In the model now: Ramp 01 HeroRender, Ramp 03 BoothDims, Ramp 06 TopDown, Platform 01 HeroRender, Platform 03 BoothDims, Platform 06 TopDown, Ramp 05 VentView, Ramp 07 InteriorAcousticRender, Ramp 08 InteriorBackRender. Both TopDowns were re-framed to fit every floor dimension.

Originally there were two identical series, `Opt2 ..` and `Opt1 ..`, with lanes marked for the proposal package (`WR_ProposalPackage/mode`).

| # | Scene | Lane |
|---|---|---|
| 01 | HeroRender | render |
| 02 | RampRender | render |
| 03 | BoothDims | image |
| 04 | SideElevation (hides walls 5 and 4) | image |
| 05 | VentView (hides wall 4) | image |
| 06 | TopDown | image |
| 07 | InteriorAcousticRender | render |
| 08 | InteriorBackRender | render |

## Files

- `takeoff-vector.json`: the take-off, every value with its source.
- `build-techlab.rb`: builds the room. Call `WR_WalshTechLab.build`.
- Job scripts and screenshots: `.forge/builder/walsh/`. These are untracked and stay out of git (client imagery).
- The client plan and sketch: `clients/walsh-construction/plans/` (gitignored).

## 21 Oct revision: corner platform layout

**Request (Sarah, via Benton, 21 Oct):** "They want it to fit in the below corner with the platform and ramp. The black walls are not constructed yet so if you can just show the exact dimensions of what they would need to build." Benton, on the brief: "Idk just draw the room as close to their drawing as possible. The black walls can move." Only the platform + ramp option is drawn.

**Status (11:30, 21 Oct):** built in SketchUp over the bridge and saved as a new file. The 12 Oct original is untouched: still 12 Oct 22:13, 9,291,234 bytes. The top-down and a plain SketchUp hero are exported, and I looked at both.

**Superseded in part (afternoon, 21 Oct):** the booth sections were reordered and the door moved one section in. See "v2: section reorder" at the end of this section. The v2 wall table replaces the one below, and Option T is no longer needed.

### What the live file actually held (survey, 21 Oct)
The 12 Oct file was not two copies side by side, which is what the first s2 script assumed.
- **Room:** ONE room, `Tech Lab 13`, at the origin. The take-off frame is the world frame, so O = (0, 0, 0).
- **Booths:** TWO at the same spot, both with origin (72.52, 11.63, 1.313):
  - `Booth - MDL 96168 E`, the door-ramp option (`LeftWADoorWithRamp` at N3);
  - `Booth - MDL 96168 E PLATFORM`, entity-hidden, with the platform and ramp in `Component#17`.
- **Tags:** all three sit on tag `Walsh Assembly`. The scenes switched between the two booths with entity hidden flags, not tags.
- **Frame:** the booth group's local frame is the shell frame: x 0-170 runs W to E and y 0-98 runs S to N. The 12 Oct note's shell origin at (61.89, 11.63) does not match this file; the live origin is 72.52.

`s2-retag.rb` and `s4-booth.rb` were written for the wrong structure and were NOT run. `s2b-retag.rb` and `s4b-booth.rb` replace them.

### What was done (nothing deleted)
- `Tech Lab 13` and its 8 ceiling lights went to the hidden tag `Walsh Old Room 12 Oct`.
- 26 loose old dims, text, cpoints and edges, plus 2 dims inside the PLATFORM booth, went to the hidden tag `Walsh Old Dims 12 Oct`.
- The door-ramp booth went to the hidden tag `Walsh Ramp Option 12 Oct`.
- The PLATFORM booth was unhidden and placed in the corner with one rigid transform.
  - `Component#17` (platform + ramp) was mirrored about the platform centre, booth x 143.37.
  - The ramp now runs toward the open end.
- The new room is `Tech Lab 13 - Corner 21 Oct`. Its black walls are on the tag `WR-Room-New` and named `NEW ...`.
- One dims group, `Corner Dims 21 Oct`, holds 27 dims and one note.
- `Platform 06 TopDown` and `Platform 01 HeroRender` were re-aimed and exported.

### Layout
- **Booth:** MDL 96168 E, with the shell 11 5/8" off both walls.
  - The back (S face, EFS) is on the exterior wall.
  - The W0 end (also EFS) faces the new corner wall.
  - Door N3 is at the open end.
- **New walls:** all square to the exterior wall.
- **Ramp:** runs toward the open end (`RAMP_DIR 'open'`). The coordinator confirmed this on 21 Oct.

### Measured from the live model (observed)
- **Platform:** 3'-10" wide (booth-local x 120.37-166.37) and 46" deep in front of the N face. Its top is 3.73" above the floor. In the corner frame it covers s 132.0-178.0 and d 109.63-155.63.
- **Ramp:** 45.61" (3'-9 5/8") long and 46" deep. Corner frame: s 178.0-223.6.
- **Booth door N3 opening:** booth-local x 121.25-165.75. The opening is 3'-8 1/2" wide and sits 4 1/4" off the booth's open-end corner.
- **Front hardware:** the N0/N1 panels end at y 97.75, inside the 98" shell, so FP = 0 along the front wall.
- **EFS:** the silencers stand 10" proud on the S face and on the W0 end. That leaves 1 5/8" to each wall.

None of these values moved a black wall. The zone wall sits at d 156.63, so it clears the platform edge (155.63) by 1". The wall table is the same as on the offline plan.

### Wall table (interior faces, as built)

| Run | Ours | Architect | Provenance |
|---|---|---|---|
| Exterior wall, apex to corner wall | 32'-0" | 32'-0" | reported (architect) |
| NEW corner wall, exterior to front wall | 9'-2 5/8" | 9'-1" MIN CLR | derived (11 5/8 + 98 + 1) |
| NEW corner wall, front wall to south wall | 2'-9 5/16" | not dimensioned | derived |
| Corner wall overall | 11'-11 15/16" | not dimensioned | derived |
| NEW front wall, corner to step | 7'-0" | ~7'-0" | derived (scaled) |
| NEW step wall | 3'-10" | ~3'-3" | derived (platform 46 deep + 1) |
| NEW zone wall, step to angled wall | 4'-7 5/8" | ~4'-8" | assumed (scaled from markup) |
| NEW angled wall, zone wall to south wall | 8'-5 9/16" | not dimensioned | derived |
| South wall, SW corner to angled wall | 10'-10" | not dimensioned | derived |
| South wall, angled wall to corner wall (pocket) | 15'-0 3/8" | not dimensioned | derived |
| South wall overall | 25'-10 7/16" | not dimensioned | derived |
| West wall | 18'-11" | 18'-11" | reported (architect) |
| NW angled wall | 13'-8 7/8" | not dimensioned | observed (take-off) |

### Moves away from the architect's drawing
- **Front wall:** moves from 9'-1" to 9'-2 5/8", +1 5/8". The shell face sits at 9'-1 5/8", so a wall at 9'-1" would cut it.
- **Zone wall:** moves from about 12'-4" to 13'-0 5/8" off the exterior wall, +8 5/8". That makes the step wall 3'-10" instead of about 3'-3", and clears the 46"-deep platform by 1".
- **Step and angled walls:** their positions along the exterior wall are as the architect drew them (scaled).
- **Door 24:** the angled wall's foot lands 10'-10" from the SW corner, so door 24 (4" to 3'-4") stays clear.

### Assumed or estimated values
- **Architect's stated figures (assumed):** the 32'-0" is taken as apex to the corner wall's interior face, and the 18'-11" as interior face to interior face.
- **Scaled positions:** the step wall at 7'-0" and the angled wall at 11'-7 5/8" along the exterior wall come from a 239 px capture (~6 px/ft), so ±6".
- **Pocket door (estimated):** 3'-0", 1'-0" off the corner wall, hinged at the east jamb and swinging into the pocket.
- **Door 24 (assumed):** kept at 4" to 3'-4" from the SW corner on the moved south wall.
- **Ceiling (assumed):** 8'-0", the house default.

### Open questions
- **Platform exposure (seen in the build).** Door N3 is at the booth's open end, so the platform runs from s 11'-0" to 14'-10" and the ramp runs out to s 18'-7 5/8".
  - The architect's alcove, between the step and the angled wall (s 7'-0" to 11'-7 5/8"), holds only the first 7 5/8" of the platform.
  - The rest of the platform, and all of the ramp, sit in the open Tech Lab.
  - **Option T** moves the whole zigzag with our door: step at about 11'-0 5/8", angled wall at about 15'-6 5/8", foot about 5'-9" from the SW corner. Door 24 is still clear. Benton to choose.
- **Client figures needed:** the real ceiling height and the pocket door.

### Scenes
- `Platform 06 TopDown` and `Platform 01 HeroRender` are re-aimed on the corner layout.
- `Platform 03 BoothDims` is stale: it is still aimed at the 12 Oct layout.
- Every `Ramp ...` scene is stale, because its room and booth are now on hidden tags.

### Run order (bridge, as actually run on 21 Oct)
1. `survey.rb`
2. `s0-saveas.rb`
3. `s2b-retag.rb`
4. `s4b-booth.rb`
5. `s3-room.rb`
6. `s6-dims.rb`
7. `s7-scenes.rb`, with `$walsh_hero_eye = [40, 165]` and `$walsh_hero_tgt = [165, 120]` set to aim the hero.
8. `flatten.py`

**How to run them:**
- **Write roots:** steps 2-7 need `--write-root`: `Z:/Sketchup/ClientDrawings` for the saves and `Z:/Sketchup` for s7.
- **Saving:** the bridge refuses a bare `m.save`. Every step therefore saves through `WalshCorner.save`, which writes only to the Corner Platform path.
- **Loading:** the bridge's `run` copies the script elsewhere, so `File.dirname(__FILE__)` breaks. Load each step through a one-line wrapper: `load "<abs path>"`.

### Paths
- **Model:** `Z:\Sketchup\ClientDrawings\Walsh Construction Tech Lab MDL 96168 E - Corner Platform.skp`
- **Images:** `Z:\Sketchup\Proposals\Walsh Construction Tech Lab MDL 96168 E - Corner Platform\`
  - `6_Platform 06 TopDown.png`: the dimensioned SketchUp top-down.
  - `1_Platform 01 HeroRender (SketchUp, not V-Ray).png`
  - `Corner Platform plan (offline, not SketchUp).png`: SUPERSEDED. Its walls are identical, but it draws a 48" ramp (measured 45 5/8") and a 44" platform (measured 46").
- **Scripts:** `.forge/builder/walsh/corner/`

### v2: section reorder (afternoon, 21 Oct)
**Request (Benton):** "the 2' section needs to be closer on the other side. The door needs to be shifted one section in." Then: "the 2' section doesnt go direclty up against the corner, its still a center section, but it would be the closest section other than the 'side' section."

**Section survey (observed, booth-local x from the corner-wall end, 0-170):**

| Wall | Before | After |
|---|---|---|
| Order | SIDE 48 / CTR 48 / CTR 24 / SIDE 48 | SIDE 48 / CTR 24 / CTR 48 / SIDE 48 |
| Front (N) | N0 46 window / N1 46 window / N2 19 / N3 49 WA door | N0 46 window / N2 19 / N3 49 WA door / N1 46 window |
| Back (S) | S0 vent / S1 vent + EFS / S2 22 solid / S3 vent | S0 vent / S2 22 solid / S1 vent + EFS / S3 vent |

- **Door N3:** the opening moved from x 121.25-165.75 to 73.25-117.75. It is now in the third module, one section in from the open end.
- **Vent walls are unchanged:** back wall S0/S1/S3, plus W0 on the corner end, all with EFS. S1 (vent + EFS) moved one section, +24". The W0 EFS did not move.
- **EFS proximity (FLAG):** with S1 now beside S3, the two silencer boxes sit about 1/2" apart vertically with about 2" of x overlap. I could see no intersection in a close-up, but I could not measure the nested sub-bounds. Check this in SketchUp.
- **BOM:** no part was added or removed. The 49" WA frame keeps its 19" companion directly beside it (46+22 becomes 49+19, the layout-render.js rule).
- **Wide-panel rule (FLAG, not blocking):** the memory rule puts the wide floor section, the door frame and the wide side-wall panel at the door end. The door is now in a centre module, not at an end. The rule is written for split-run 6060/6084/7272/7296 side walls, so whether it applies to a 96168 front wall needs Benton or the quote tool to confirm.

**What s8 moved (inside the PLATFORM booth only):**
- Wall sections and seals, per the table above.
- Deck: the CTR48 and CTR24 tiles and the STDSS strip, 10 pieces in all.
- Platform and ramp (`Component#17`): -48", following the door. The ramp still runs toward the open end.
- Fittings: Studio Light SL52 (2 of 3), Duct Covers lo/hi on S1i, IEP BEAM 8 seam 2, and Foam N1i (now x 117.75-165.75).
- **Hidden, not deleted:** Audimute2x4 front, Audimute2x4 back and Foam S1i. They had no free spot after the reorder and carry the attribute `WalshCorner/hidden_by`. **The interior needs an AP/foam re-layout pass (whisperroom-acoustic-package).**

**Re-fit of the black walls:**
- The platform now sits inside the architect's alcove: s 7'-0" to 10'-10" (84-130), with the alcove running to s 11'-7 5/8".
- The ramp runs s 10'-10" to 14'-7 5/8" (130-175.6) toward the open end. It clears the start of the angled wall (s 139.6, d 156.63) by 1".
- The only wall that moved is the step wall, from s 84 to s 83. That leaves 1" clear of the platform, and it falls out of `geom.solve` automatically.
- Door 24 is unchanged and clear. Option T is no longer needed.
- The v1 room and dims were renamed `(v1 21 Oct)` and moved to the hidden tag `Walsh Corner v1 21 Oct`.
- The NEW walls now carry the material `WR New Wall (to build)`, near-black (38,38,38), on the tag `WR-Room-New`, so they read dark in the top-down.

### Wall table v2 (interior faces, as built)

| Run | Ours | Architect | Provenance |
|---|---|---|---|
| Exterior wall, apex to corner wall | 32'-0" | 32'-0" | reported (architect) |
| NEW corner wall | 9'-2 5/8" + 2'-9 5/16" = 11'-11 15/16" | 9'-1" MIN CLR (first run) | derived |
| NEW front wall, corner to step | 6'-11" | ~7'-0" | derived (platform west edge - 1") |
| NEW step wall | 3'-10" | ~3'-3" | derived (platform 46 deep + 1") |
| NEW zone wall, step to angled wall | 4'-8 5/8" | ~4'-8" | derived (angled-wall start, scaled, less step) |
| NEW angled wall | 8'-5 9/16" | not dimensioned | derived |
| South wall | 10'-10" + 15'-0 3/8" = 25'-10 7/16" | not dimensioned | derived |
| West wall | 18'-11" | 18'-11" | reported (architect) |
| NW angled wall | 13'-8 7/8" | not dimensioned | observed (take-off) |

**Moves away from the architect (v2):**
- Front wall depth +1 5/8" (9'-1" to 9'-2 5/8").
- Step wall position -1" (about 7'-0" to 6'-11").
- Zone wall +8 5/8" in depth, so the step wall is 3'-10", not about 3'-3".

**Door dims on the top-down:** booth corner to jamb 6'-1 1/4", opening 3'-8 1/2", jamb to open end 4'-4 1/4". Total 14'-2", which closes.

### v2 run order (after the v1 order above)
1. `s8-sections.rb`. `$walsh_dry = true` gives a plan-only run.
2. `s9-retire-v1.rb`
3. `s3-room.rb` (now applies the dark wall material)
4. `s6-dims.rb`: 28 dims. The front-wall dim is on the booth roof, and the step dim is on the pocket side.
5. `s7-scenes.rb`, with `$walsh_hero_eye = [40, 165]` and `$walsh_hero_tgt = [125, 120]`.
6. `flatten.py`

**Top-down legibility:** acceptable. The top "11 5/8"" label crosses the exterior wall line.


## v3 (21 Oct, evening): Sarah's final plan, MDL 96168 S roof mount, corner RM

**Request (Sarah, verbatim):** "Ok. Here's the final plan. Remove platform and ramp (leave ADA Door and Elevated Floor). Add Roof Mount ventilation. Gray studio foam, onyx Audimute panels. Will you also place one of the cable walls to the left, beside the wall window?" Benton: drop the old booth and all black walls, back to the full Tech Lab outline; RM not wall vents; bottom-right corner, back on the diagonal exterior wall, angled toward the host doors; 1" nominal, door swing respected, no EFS clearance. Later: "dont worry about the acoustic package right now."

**Link (staging builder):** `#3=ARIEQaAgAAgIAAICAgACAAAMBA` -> MDL 96168 S, Wide Access door hinge R, foam Gray, flags wideDoor / efp / roofVent / ap; ramp, ada, efs all false. Builder: interior 94 x 166, exterior 98 x 170, "vent on the roof - nothing sticks out".

**Panels, matched to the builder (verified headless, iso captures in the session scratchpad):**

| Wall | Panels (booth-local inches) |
|---|---|
| N | 46 WDO, 46 WDO, **22 (centre)**, 46 CBL |
| S | 46 CBL, 46 CBL, 22, 46 CBL |
| E | 46, 46 |
| W | 43, Wide Access door frame (49) |

**The "small side section" Benton caught (root cause):** my own `rm/s3-booth.rb` swapped N2/N3 to move a cable wall beside the window, and `rebalance_walls` then made the 22" an END section, which is not offered on this size. `scripts/booth-from-link.rb` / `build-booth-components.rb` are not at fault. Fixed by `s3b-rebuild.rb`, which rebuilds straight from the link. The wrong booth is hidden on tag `Walsh RM swapped N 21 Oct`, not deleted. The v2 Corner Platform export did NOT have this mistake (its 2' stayed a centre section).

**Sarah's cable-wall request is NOT met as she worded it:** the link's N3 CBL sits beside the 22", not beside the window. A 46 CBL can only sit beside the window by making the 22" an end section. The builder layout was kept; the open question is for Sarah/sales.

**Placement (corner frame s along the exterior wall from the corner, d off it):** booth s 47-145, d 1-171 (hardware to 172.27). Back 1" off the diagonal exterior wall; door end faces the host doors. s0 = 47 because the host Door 2 swing reaches s 45.3. Booth door: frame s 94-143, leaf 35.37 wide, hinge on the S side, outswing; arc reaches d 205.87 against room depth 226.37 there. The ceiling must give 93.31" (catalog Std 6'-11" install figure applies); the room height is still the 8'-0" house default, **assumed**.

**Dims (`RM Dims 21 Oct`, now on tag `Walsh RM Dims 21 Oct`, hidden only on the 01-angled hero):** 17 dims + the booth door swing. Room 32'-0" (reported), corner wall 11'-11 15/16", south 25'-10 7/16", west 18'-11", NW 13'-8 7/8"; exterior chain 3'-11 / 8'-2 / 19'-11; booth 1" gap, 14'-2" length; door chain 3'-11 / 4'-1 / 2". Host Door 2 figures are **estimated**.

**Scenes:** AUTO-SET, 9 stamped pages (01-angled r/02-front r/03-high r are render plates, not rendered). Fixed by hand after the first export, and marked here: 01-angled camera moved inside the room (AUTO-SET's eye sat outside and a host door leaf filled the frame); 06-plan reframed on the whole room. All old v1/v2 pages are set to Skip.

**Images (SketchUp exports, NOT V-Ray, 1920x1080 opaque RGB)** in `Z:\Sketchup\Proposals\Walsh Construction Tech Lab MDL 96168 S - Corner RM\`. `manifest.json` only lists 11 and 18 (the last run).

**Still to do:** the acoustic package (5x 2x4, 2x 1x4, 14x 1x2 for 96168), Onyx Audimute material not found on P:; V-Ray renders; the real ceiling height.

**Scripts:** `.forge/builder/walsh/rm/` s0-s10b, all run over the bridge.

**Decided 21 Oct (Benton):** no ADA; elevated floor + wide door is all it needs, and the link is accurate as-is. The cable wall stays where the link puts it. Proposal PDF paused, not started; see the DEVLOG entry for 2026-10-21.
