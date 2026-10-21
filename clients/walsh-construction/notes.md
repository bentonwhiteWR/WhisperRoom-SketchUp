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

**Status:** the geometry, the wall table and the SketchUp scripts are done. An offline to-scale plan has been drawn from the same geometry. SketchUp was not reachable over the bridge, so **nothing has been built in the .skp yet**. Every script below is unrun; each one passes `scripts/rbparse.py`.

### Layout
- Booth MDL 96168 E. The back (S face, EFS) is on the exterior wall, the W0 end faces the new corner wall, and door N3 is at the open end. The shell is 11 5/8" off both walls (same rule as 12 Oct: EFS 1" off each wall).
- The new walls are all square to the exterior wall.
- The ramp runs toward the open end (`RAMP_DIR 'open'`, a one-line switch in `geom.rb`). The zoomed architect markup shows their ramp descending toward the open end. The coordinator's "toward the corner" came from my own earlier misread. A ramp toward the corner would dead-end into the step wall.

### Wall table (interior faces)

| Run | Ours | Architect | Provenance |
|---|---|---|---|
| Exterior wall, apex to corner wall | 32'-0" | 32'-0" | reported (architect) |
| NEW corner wall, exterior to front wall | 9'-2 5/8" | 9'-1" MIN CLR | derived (booth 11 5/8 + 98 + 1) |
| NEW corner wall, front wall to south wall | 2'-9 1/4" | not dimensioned | derived |
| NEW front wall, corner to step | 7'-0" | ~7'-0" | derived (14'-8" - 7'-8") |
| NEW step wall | 3'-10" | ~3'-3" | derived (platform 46 deep + 1) |
| NEW zone wall, step to angled wall | 4'-7 5/8" | ~4'-8" | assumed (scaled from markup) |
| NEW angled wall, zone wall to south wall | 8'-5 1/2" | not dimensioned | derived from the scaled position |
| South wall, SW corner to angled wall | 10'-10" | not dimensioned | derived |
| South wall, angled wall to corner wall (pocket) | 15'-0 3/8" | not dimensioned | derived |
| West wall | 18'-11" | 18'-11" | reported (architect); our take-off read 17'-1 1/8" |
| NW angled wall | 13'-8 7/8" | not dimensioned | observed (take-off) |

### Moves away from the architect's drawing
- The front wall moves from 9'-1" to 9'-2 5/8", +1 5/8". The shell face sits at 9'-1 5/8", so 9'-1" would cut it.
- The step/zone wall moves from about 12'-4" to 13'-0 5/8", +8 5/8". The platform is 46" deep and passes under the zone wall by 6".
- The step and angled walls stay where the architect drew them.
- The angled wall's foot lands 10'-10" from the SW corner, so door 24 (4" to 3'-4") is clear.

### Assumed or estimated values
- The 32'-0" is taken as apex to corner-wall interior face, and the 18'-11" as interior faces. Both are assumed.
- The step wall at 7'-0" and the angled wall at 11'-7 5/8" along the exterior wall are scaled from a 239 px capture (~6 px/ft), ±6".
- The pocket door is 3'-0", 1'-0" off the corner wall, hinged at the east jamb and swinging into the pocket. Estimated.
- The platform is 44" wide (booth x 122-166) and the ramp is 48" long; both are 46" deep. Scaled from the 12 Oct Platform TopDown. s4 measures the real extents live.
- FP (front hardware beyond the N face) is taken as 0; s4 measures it live. If FP is more than 0, the front wall moves out by FP.
- The ceiling is 8'-0", the house default. Assumed.

### Open questions
- **Platform exposure.** With the minimum moves, most of the platform and all of the ramp sit outside the alcove, in the open Tech Lab, and the alcove between the step and the angled wall is mostly empty. **Option T** shifts the whole zigzag with our door: step about 11'-0 5/8" and angled wall about 15'-6 5/8" along the exterior wall, foot about 5'-9" from the SW corner, still clear of door 24. Benton to choose.

### Run order (bridge)
Run `survey.rb` first. Then:
1. `s0-saveas.rb`
2. `s2-retag.rb` (set `$walsh_dry = true` first to preview)
3. `s3-room.rb`
4. `s4-booth.rb`
5. `s6-dims.rb`
6. `s7-scenes.rb`, with `--write-root Z:/Sketchup`
7. `flatten.py` on the PNGs

Every step saves.

### Paths
- **New model (not yet created):** `Z:\Sketchup\ClientDrawings\Walsh Construction Tech Lab MDL 96168 E - Corner Platform.skp`
- **Images:** `Z:\Sketchup\Proposals\Walsh Construction Tech Lab MDL 96168 E - Corner Platform\`. Holds `Corner Platform plan (offline, not SketchUp).png` so far.
- **Scripts:** `.forge/builder/walsh/corner/`
  - Geometry: `geom.rb` and `arch_geom.py`
  - SketchUp steps: `s0`-`s7`
  - Offline plan: `plan_svg.py`
