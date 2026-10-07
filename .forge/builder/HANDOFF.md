# Builder handoff: People's Space accessories (6 Oct 2026)

The previous handoff (CCU Sands Hall 113) is now `.forge/builder/HANDOFF-ccu-sands-113.md`.

## Produced
- I saved this file in place at 15:56 over the bridge with `--write-root Z:/Sketchup/ClientDrawings`. After the save, `modified?` read false:
  `Z:/Sketchup/ClientDrawings/PeoplesSpace MDL 96120 E ADA RM VSS WDO RAISED FLOOR AP MJP HEPA REVISED.skp`
- I changed only the visible booth group `MDL 96120 E (components)R` (definition `Group#27`). Its transform puts the origin at (100, 4.75, 1.31), with local +x pointing along world +y. All coordinates below are booth-local inches.
  - **Studio lights:** 3 `Standard Light` instances came out and 2 `SL52` went in. They are named `Studio Light SL52 (1 of 2)` and `(2 of 2)` and sit on the `WR Lights` tag, which is hidden in TopDown, as before.
    - Each fixture is 10.75 wide and 53.88 long. Its length runs across the booth, along y from 22.06 to 75.94.
    - Centres are at x 33 and x 89, y 49. Fixture 1 spans x 27.63–38.38 and fixture 2 spans x 83.63–94.38.
    - The top of each fixture is at z 80.25, flush with the ceiling face that the ray tests found.
  - **Foam:** I added 1 sheet, `Foam  S1i`, on the `WR-Booth-Foam` tag. It is the same `Foam` definition and the same standing orientation as the other sheets (local x up, local z into the room).
    - It covers x 45.91–69.91 and z 18.25–66.25, the same band height as the other walls. Its back is at y 4.3125.
    - Clearances: 3.34 to the window trim, 3.47 to the door jamb, 15.5 above the floor and 14.0 below the ceiling.
  - **Bass traps:** none placed. The `Bass Trap` definition was loaded for measuring, then removed while it had no instances.
- Scripts and screenshots are in `.forge/builder/peoplesspace-accessories/`:
  - `add.rb` places the parts, `shift.rb` moves the lights, `verify.rb` reads back and runs the clash check, `grid.rb` checks the ceiling faces, and `shots.rb` takes the screenshots.
  - The probes are `p1`–`p8.rb`, `rmclash*.rb` and `c69.rb`.
  - The PNG files are `front-wall.png`, `ceiling-lights.png`, `interior-overview.png`, `back-corners.png`, `topdown-before.png` and `topdown-after.png`.

## Read-first
- `.forge/builder/peoplesspace-ap/HANDOFF.md` describes the original AP layout. The visible booth is now the R (right-door) copy. The L copy is hidden, and `L INTERIOR` sits far off at x≈1145.
- `back-corners.png` shows why no bass trap fits without overlapping something.

## Assumptions
- I took "front" to be the door wall. In the model that is the S wall: slots S0 (the window panel), S1 (a 19 in panel) and the WA door frame. The model has no wall named "front".
- I read "the same orientation" as standing, 24 wide by 48 tall, so I did not place a sheet laid flat.
- I placed the light tops at the ceiling face found by ray test (z 80.25). The importer's rule uses the bounds of the ceiling parts, which give z 78.89 because plastic hinges hang below the tile edges. The old Standard Lights hung at 78.89.

## Open-questions
1. **Bass traps (the quantity is still TBD with the rep).** Every upper corner overlaps something:
   - **NW and NE (back):** blocked by the back top-row 1x2, the back band 1x4 and the side foam (W1i / E1i).
   - **SW:** blocked by the window trim, which runs x 7.5–42.56 and z 37.25–76.25, and by the W0i foam.
   - **SE:** the door opening is there.

   Placing traps needs Benton to decide which AP or foam pieces to move.
2. **2nd foam sheet.** Only one standing sheet fits on the front wall. A sheet laid flat (48×24) would fit under the window at x 7.6–55.6, z 3.25–27.25, but only if the standing sheet is raised to z 27.75–75.75 and moved to x 48.75–72.75 (0.5 in gaps).
3. **Foam count.** The rep says 7 sheets are quoted. The booth had 6 before this change and has 7 now.
4. **Defect in the importer (not fixed; `scripts/` was left untouched):** `place_studio_lights` uses `cl.min.z` for the top of the fixtures. On a booth with ceiling hinges that leaves the fixture hanging 1.36 below the ceiling. Its `sl_layout` even spacing also ignores the roof-unit rods (`RM96120VSS` > `Component#69` > `Component#68`, about 2 in in diameter, reaching down to z 77.15). At x 91 the rod pierced light 2.
5. The R booth has no MJP or HEPA, although the file name says it should (noted 23 Sep for Option 2). Not part of this task.

## Round 2 (6 Oct, later): 3 bass traps per back corner, plus an IEP beam. Both stopped; the model is unchanged
At the start of this round the file was saved (`modified?` false). Benton had since moved the lights to the
`WR Studio Lights` tag and switched the view to the InteriorAcousticRender scene. I left the view as I found it.
I loaded some part definitions to measure them and removed them again. The model is therefore marked as
modified, but its content is the same as the saved file. **I did not save.**

**Bass traps** (stopped, because the back wall does not fit with 1/2 in gaps):
- **The trap shape.** `Bass Trap.skp` is a 12 x 12 x 24 triangular prism, with its right angle at local
  (0, 12). The importer puts the part's (0, 0) corner into the room corner, which is a hypotenuse end, so for
  this part the importer is wrong. Either way, the trap's leg runs 12 in along each wall at the wall face.
- **Faces found by ray test:** W 4.25, N 93.75, E 117.75, floor 2.75, ceiling 80.25. A stack of 3 x 24 = 72
  fits in the 77.5 between floor and ceiling. The roof-unit rods are at x≈23 and x≈96, y≈49, nowhere near
  the corners.
- **The back wall's run between the two trap columns:** x 16.75 to 105.25, which is 88.5 in.
  - The band needs 12 + 24 + 24 + 24 + 12 = 96 in, plus 4 gaps of 1/2 in = 98.0 in. It is **9.5 in short**.
  - The top and bottom rows each need 4 x 24 = 96 in, plus 3 gaps of 1/2 in = 97.5 in. Each is **9.0 in short**.
  - Every trap tier crosses the band, so a shorter stack does not help.
- **The side walls are feasible.** Each side band, with 1/2 in gaps, can slide toward the front so that it
  spans y≈8.2 to 81.2.
- **Options for Benton:**
  - (a) Move the two back 1x4s, plus one 1x2 from each back row, to other walls. The back wall then fits:
    the band is 73.0 in and each row is 73.0 in.
  - (b) Use fewer traps, or put them somewhere else. The front corners are blocked by the window and the door.
- Screenshots: `back-wall-straight.png` and `back-corners.png`.

**IEP beam** (stopped, for two reasons):
- **There are two ceiling seams, not one.** Two `STDSS CL8` seals run along the seams at x 45.75–52.25 and
  x 69.75–76.25. They span y 2–96, with their bottoms at z 79.25. The booth holds no other ceiling seam seal.
  Screenshot: `ceiling-seams.png`.
- **The beam is longer than the room.** `IEP BEAM 8` measures 3 x 1.5 x 94.0, with its length along local z.
  The seal is 94.0 long, the same as the beam, but the interior runs only from y 4.25 to 93.75, which is 89.5.
  Hung under a seal, the beam would run 2.25 in into each of the front and back walls.
- **Other lengths:** `IEP BEAM 7` is 82.0 long and `IEP BEAM 8.5` is 100.0.
- **The bracket:** `IEP Beam Bracket` measures 1.5 x 0.84 x 4.53. Its 1.5 in width matches the beam's
  thickness, so it is probably an end hanger. That is assumed: how it mounts is not obvious from its geometry.
  No brackets were placed.
- **Needs from Benton:** which seam to use; whether the beam should sit above the interior walls (on the IEP
  tray, not under the seal) or be a shorter beam; and confirmation that the 94 in length is correct.

## Round 3 (6 Oct, 16:26 save): Benton's go-ahead. Beams placed; traps stopped again
**IEP beams: placed and saved.**
- Two `IEP BEAM 8` instances sit on `WR-Booth-Options`, a tag that none of the 9 scenes hides. They are named
  `IEP BEAM 8 (seam 1, x 49.0)` and `(seam 2, x 73.0)`.
- Each beam spans x ±1.5 about its seal's centre, y 2.0–96.0 and z 77.75–79.25. The 3 in width runs across
  the seal and the 1.5 in depth hangs down.
- The top of each beam is at 79.25. Upward rays at 15 points per beam hit `STDSS CL8` at exactly 79.25.
- **The part really is 94.000 in long** (observed): every edge vertex sits at z 0 or z 94. The 8 hidden
  entities are edges and add no geometry. The catalogue gives U101 as 82 in, which is what
  `IEP BEAM 7.skp` measures.
- **Clashes found by the face-crossing test** (`beamclash2.rb`):
  - Each beam runs 2.0 in into the ENH mid-wall seam seals, front and back (y 2.25–4.25 / 93.75–95.75).
    Beam 2's front end runs the full 2.25 to y 2.0.
  - Each beam passes through a back top-row Audimute 1x2, 2.0 deep x 1.5 tall.
  - Beam 2 cuts 1.23 in into the `WA IEP jamb` (x 73.27–74.50).
  - Nothing touches the lights, the roof-unit rods or the roof unit.
  - An 82 in beam centred on the room (y 8–90) would clear all of these, including the Audimute front at
    y 91.75, by 1.75 in or more (derived).
- Scripts: `beams.rb`, `beamclash.rb`, `beamclash2.rb` (this one is slow, about 70 s, on the roof unit),
  `beam-measure.rb`, `shots3.rb`, `shots4.rb`.
- Screenshots: `r3-*.png`.

**Bass traps: stopped, nothing moved.** The two back 1x4s have no valid spot on either side wall.
- Per side, the usable run is at most 77 in (y 4.25–81.25, wall face to trap tip).
- The band would become 72 + 12 = 84 in.
- The rows would have to hold 96 + 72 = 168 in, against about 152 of capacity.
- The two moved 1x2s would fit: 3 in a side wall's top row is 73 in, out of 73.6.
- Options:
  - stage the two 1x4s as `NOT PLACED` leftovers beside the booth;
  - or put 3 traps in ONE back corner. The back band (98.0 in) then fits the 98.4 in run without anything
    leaving the back wall, and only the side band on that side slides forward.

## Round 4 (6 Oct, 16:48 save): full acoustic re-layout and 6 bass traps. DONE and saved
- **Scripts** (in `peoplesspace-accessories/`):
  - `r4-layout.rb` is the plan, with a dry run (`$r4_mode = :dry`) and an apply (`:apply`).
  - `r4b-fix.rb` clears the beams and seats the traps and the back 2x4.
  - `r4-verify.rb` is the full check: geometry clashes in both directions, gaps, seating rays, fabric
    direction, traps, and scene visibility.
  - `r4-shots.rb` takes the screenshots.
  - The apply log is `r4-apply-log.txt`, and the screenshots are `r4-*.png`.
- **Counts:**
  - back: 2x4 ×1, foam ×2, 1x2 ×5;
  - left and right, each: 2x4 ×1, foam ×2, 1x4 ×2 (laid flat), 1x2 ×2;
  - front: foam ×1, 1x2 ×3;
  - 6 traps, 3 in each back corner.
  - Total: 12/4/3 Audimute and 7 foam. Nothing was left unplaced.
- **Rows:**
  - top row z 65.25–77.25, band z 16.25–64.25, bottom row z 3.25–15.25, with 1 in gaps;
  - back top row: 1x2s at x 23.5–47.5 and 74.5–98.5, straddling the beams;
  - front: foam at x 45.91–69.91 with a 1x2 below it, and two 1x2s under the window at x 13.03–37.03
    (z 3.25–15.25 and 16.25–28.25).
- **Traps:** the right angle measured in the part is at its local (0,12), and that corner goes into the room
  corner. The NE trap is turned -90°. Each trap rests on the 0.0625 wall strips, so the corners are at
  (4.3125, 93.6875) and (117.6875, 93.6875). The tiers run z 8.25–80.25, top against the ceiling, which
  leaves a 5.5 in gap at the floor. All traps are on `WR-Booth-Acoustic`, which no scene hides.
- **The IEP beam was edited after my 16:26 save, and I did not touch it.** The model now holds ONE
  `IEP BEAM 8` instance inside the shared `STDSS CL8` definition. It shows under all 4 seals (R ×2, hidden
  L ×2), stands on edge at 1.5 x 3, and spans z 76.25–79.25 and y 4.25–98.25, which runs 4.5 into the back
  wall. The r4 layout keeps clear of this real geometry.
- **Verify:**
  - geometry clashes: none;
  - smallest gap between pieces: 1.000;
  - 260 seating rays at 0–0.094;
  - every Audimute fabric face points into the room;
  - none of the 9 scenes hides a tag or an entity.
- **Importer defect (still open):** `place_bass_traps` puts the part's (0,0) corner into the room corner.
  For `Bass Trap.skp` that is the end of the hypotenuse, not the right angle.

## Round 5 (7 Oct, 09:22 save): one new foam sheet cut in two
- **Pieces** (both on `WR-Booth-Foam`; each is its own definition, cut from a copy of `Foam`):
  - `Foam (cut) back`: 21.49 wide x 14.0 tall x 2. It sits on the back wall at x 50.51–72.00, z 64.75–78.75,
    between the beams. It is 0.50 from beam 1 (x 50.001), beam 2 (x 72.501), the 2x4 band top (64.25) and the
    seal bottoms (79.25).
  - `Foam (cut) front`: 29.69 long x 11.0 tall x 2, laid landscape. It sits on the front wall at
    x 43.06–72.75, z 64.75–75.75, above the S1i column and under the beams. It is 0.50 from the window trim
    (42.5625), the door jamb (73.25), the beam bottoms (76.25) and the S1i top (64.25).
- **Use of the sheet:** the back piece is cut from x 0–14, y 0–21.49 of the 48x24 sheet, and the front piece
  from x 14–43.69, y 0–11. Together they use 627.4 of 1152 sq in. The offcut of 524.6 sq in is NOT placed.
- **Why "between the beams" on the back wall:** it gives 301 sq in, against 286 for spanning under the beams
  (26 x 11).
- **How it was cut:** the foam is not a solid, so Solid Tools could not be used. Instead, a box was intersected
  with a copy of the geometry, everything outside the box was deleted, and the box's inner side faces were
  kept as end caps. A few slab-side caps then had to be closed by hand (`find_faces` and polygons through the
  existing vertices). Both pieces end with 0 open edges. The pyramids keep their real size; nothing was scaled.
- **Checks:**
  - geometry clashes: none;
  - seating: 167 rays, all 0.000;
  - the pyramids face into the room;
  - none of the 9 scenes hides either piece.
- **Scripts:** `r5-cut.rb`, `r5-caps.rb`, `r5-close.rb`, `r5-close3.rb`, `r5-verify.rb`, `r5-seat.rb`.
- **Screenshots:** `r5-wall-back.png`, `r5-wall-front.png`.
