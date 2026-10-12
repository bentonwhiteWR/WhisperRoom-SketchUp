# Walsh Construction: PHAME Tech Lab (room 13), 12 Oct 2026

The request came from Sarah (sales), relayed by Benton. The client wants the Recording Studio package in an 8' x 14' Enhanced, rendered in two ramp configurations with the ADA door in the same place.

Model: `Z:\Sketchup\ClientDrawings\Walsh Construction Tech Lab MDL 96168 E.skp` (new file, saved after every step).

Provenance labels used below: **observed** (I read or measured it myself), **derived** (computed from observed values), **reported** (someone told me), **assumed** (needed to proceed, not checked).

## Open items, in order

1. **Ceiling height is ASSUMED at 8'-0".** It is not on the plan. Benton (reported): "assume 8' ceiling but we don't know". A note on `WR-Notes` in the model says the same. The Enhanced install clearance is 7'-1" (85 in, from the catalog), so the booth fits under 96 in with 11 in to spare (derived). A ceiling under 85 in disqualifies it.
2. **Door 1 is not in the Tech Lab.** Its swing arc is centred 14.4 in east of the Tech Lab's east wall (observed, vector), so it opens into STORAGE 17. The Tech Lab's only door is **door 24** at the SW corner. The plan's dashed booth and Sarah's ramp/PL sketch both sit at the east end, against the east wall. Nothing else depends on door 1.
3. **Booth position differs from the dashed rectangle.** The plan draws the booth 2.9 in off the south wall and 3.0 in off the east wall (observed). The link puts EFS vents on the booth's south wall and on W0. The quote tool's rule (`layout-render.js`) is that EFS reaches out 10 in. The S3 EFS box also overhangs the booth's SE corner by 10.6 in, and the W0 EFS overhangs the SW corner by 10.6 in (observed, model geometry). I placed the booth so its outermost hardware sits 1 in off the south and east walls. That puts the shell **11 5/8 in** off both walls (derived). If the room must match the dashed rectangle, the EFS boxes go through the walls.
4. **Foam not placed (4 pieces, staged outside the room's west wall, named NOT PLACED):** E1i and W1i (full sheets) and the two 2x2 squares cut from S1i. Every slot that fits a full sheet is taken by a 2x4 or a sheet (Benton: full sheets come first). Each square would cost a 1x2 its place. Benton's call: drop an AP piece, cut E1i/W1i, or leave them out.
5. **Three duct covers moved off their ports, at Benton's request, for the renders only.** This is NOT a real duct layout. Each one is tagged `wr_walsh/moved_off_port`:
   - Duct Cover hi W0i: y 12.21-24.09 -> 16.88-28.76 (+4.67 along the wall)
   - Duct Cover hi S3i: x 145.91-157.79 -> 141.31-153.19 (-4.60)
   - Duct Cover lo S0i: x 12.16-24.04 -> 16.88-28.76 (+4.72)

   All 4 high covers were then raised flush to the tile underside: top 78.86 -> 80.25. All 4 low covers were dropped onto the elevated floor: z 2.04-16.86 -> 2.75-17.57. All values booth-local, observed by ray.
6. **Bass trap count comes from the package name, not the link.** The link carries `bt` as on/off with no package (`pk`). I used Sarah's "Recording Studio" (reported), which the quote presets give as 3 packs = **6 traps**. If the quote line says otherwise, the count changes.
7. **The take-off is not on the review-sheet pipeline.** `takeoff-check.py` and `build-takeoff.rb` handle only rectilinear E/S/W/N runs, and this room has three angled walls. The take-off lives in `takeoff-vector.json` and was built by `build-techlab.rb`, which uses WR_BuildRoom's own polygon, mitre, wall and door code plus the shared dimension engine. No review sheet exists for this job, and the auto-dimension "chain closure" check can't prove angled runs. Closure was checked separately (below).

8. **Foam count: the importer placed 7 sheets where the BOM gives 9** (MDL 96168 E: 3 x FOAM3 = 9 sheets; reported by the coordinator, not re-checked here). This is likely an importer bug. A separate layout pass is to place all 9 sheets plus the full AP. **The layout above is frozen at v7 until then.**

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
- **In the model:** the 6 runs are dimensioned in place, with overall extents 24'-4 15/16" x 27'-8 11/16".
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
- **Placement dimensions:** 13 of them, on `WR-Dims-Booth` at z 90.

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

## Acoustic package, AP 96168 (5 x 2x4, 2 x 1x4, 14 x 1x2): all placed

Counts are from `ap-packages.js`, read with node (observed).
- Every gap is at least 0.50 in, piece to piece.
- Every piece is seated by ray: 0.000 on re-check, pieces crossing an H-strip rest on it.
- Every piece's fabric normal points into the room.
- Nothing clashes with the traps, duct covers, beams, seals, studio lights, window trim or door.
- The 1x4/2x4 near the S1 covers clear them by 0.28-1.68 in.

**Back (S), mirror-symmetric about x 85, left to right:**
- end column: 1x2 vertical, mid height (z 29.5-53.5);
- full foam sheet (18.57-66.57);
- centre: 2x4 (15.75-63.75) over a 1x2 (3.25-15.25);
- full foam sheet;
- end column: 1x2 vertical.
- The vent columns' covers and the IEP beam leave no clean spot for high or low side 1x2s while full sheets flank the centre.
- Totals: 1 x 2x4, 3 x 1x2, 2 foam.

**Left (E) and right (W), identical:**
- band foam | 2x4 | 1x4 (18.57-66.57);
- 2 x 1x2 high (67.07-79.07);
- 2 x 1x2 low (3.25-15.25).
- Totals per wall: 1 x 2x4, 1 x 1x4, 4 x 1x2, 1 foam.

**Front (N, door wall):**
- under the windows: a horizontal 2x4 (12.7-36.7) and two stacked 1x2s;
- between the windows: one vertical 1x2 (51.75-75.75);
- beside the door: a 2x4 (18.57-66.57).
- Totals: 2 x 2x4, 3 x 1x2.

**Foam moves (from the importer's positions), all on WR-Booth-Foam:**
- E0i y 13-37 -> 29.26-53.26.
- W0i y 13-37 -> 29.26-53.26.
- S0i and S3i moved off their vent panels to x 38.29-62.29 and 107.71-131.71.
- All bands z 18.57-66.57, no spins.
- S1i was cut across its length into two 24 x 24 squares (r5-cut.rb method), not placed.
- E1i and W1i not placed (item 4).

## Studio lights, IEP beams, lighting

- **Studio lights:** 3 x SL52 from the importer, flush to the tile (+0.0000 at 9/9 points, from the importer log).
- **IEP beams:** 3 x IEP BEAM 8, one under each ceiling seal, top 79.25.
- **Room lights:** 8 V-Ray 2x4 rectangle lights on `WR Lights` at z 95.5, 4000 lm product, 5000 K, invisible to camera. That is about 67 lm/SF, the CCU density.
- The file was upgraded to the current V-Ray, so older V-Ray versions can't open it.

## Scenes

There are two identical series, `Opt2 ..` and `Opt1 ..`, with lanes marked for the proposal package (`WR_ProposalPackage/mode`).

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
