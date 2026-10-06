# Coastal Carolina University — Sands Hall, Room 113 (6 Oct 2026)

**Room:** Sands Hall 113, "New Music Room", open room, 1,337 SF per the sheet.
The client wants modular music practice rooms in it.

**Quote:** W-1110062608. It lists 3 × MDL 7296 E, 5 × MDL 7272 E and 1 × MDL 192192 E.
The 192192 E is Benton's to draw and is not in this job.

**Booths:** Benton changed both models to ADA + roof-mounted (RM) ventilation. His links:

- MDL 7272 E — `test-sales-portal-production.up.railway.app/booth-builder#3=AQkFw-IgAAIABAoCAAAA`
- MDL 7296 E — `test-sales-portal-production.up.railway.app/booth-builder#3=AQoFw-IgAAICAAAECgAA`

**Plan:** CCU Facilities sheet **A1 of 2**, "PRELIMINARY", dated 9-29-2026. Scale 1/2" = 1'-0" on a 24×36 sheet.

- The sheet arrived as two PDFs: `plans/A1-prelim.pdf` and `plans/A1-workorder.pdf`. Both are gitignored.
- Their geometry is **identical**: all 22,762 path items match to 0.01 pt. Only the metadata differs (Distiller vs a PDFium re-save).
- **Sheet 2 (A2, the practice-room arrangement) arrived later in the session.** It is `plans/A2-prelim.pdf`, a 612×792 pt re-scaled page, so it was **not** scaled from. The layout below follows its arrangement.

Take-off: `takeoff.json`. The checker is clean: 1 room, 10 runs, 1 door, closure 0.00". Two values are flagged DEFAULT: the ceiling and the door height.

## Scale anchor

The plan is vector, so walls were read from PyMuPDF `get_drawings()`. The page has `/Rotate 270`, so every point is mapped through `page.rotation_matrix`.

The nominal scale is 1 pt = 1/3". **Both** dimension strings on the sheet confirm it (observed):

| String | Vector faces | Stated | Diff |
|---|---|---|---|
| 38'-2 1/8" E-W | 1374.42 pt = 458.14" | 458.125" | 0.015" |
| 35'-1 1/8" N-S | 1263.42 pt = 421.14" | 421.125" | 0.015" |

Each wall face is drawn as two lines 0.62" apart. The **light-grey line on the room side** is the finished face. It is the only reading that reproduces both strings.

## Runs (clockwise from the NW corner; plan-up taken as north, no north arrow on the sheet)

| # | Dir | Value | What | Provenance |
|---|---|---|---|---|
| 0 | E | 38'-2 1/8" | north wall | **reported**: plan dimension string (vector reads 458.14") |
| 1 | S | 35'-1 1/8" | east wall, to 112 / 113A / 113B | **reported**: plan dimension string (vector 421.14") |
| 2 | W | 14'-10" | south wall, SE corner → free pilaster | **derived**: vector at verified scale, 178.00" |
| 3 | N | 1'-6" | pilaster east face | **derived**: 18.00" |
| 4 | W | 1'-0" | pilaster north face | **derived**: 12.00" |
| 5 | S | 1'-6" | pilaster west face | **derived**: 18.00" |
| 6 | W | 21'-9" | south wall between pilasters | **derived**: 261.02" |
| 7 | N | 1'-6" | SW corner pilaster, east face | **derived**: 18.00" |
| 8 | W | 7 1/8" | SW corner pilaster, north face | **derived**: 7.12" |
| 9 | N | 33'-7 1/8" | west wall | **derived**: 403.14" |

- Every scaled run was rounded to the nearest 1/8".
- The rounded south runs sum **exactly** to the stated 38'-2 1/8".
- The west runs sum **exactly** to the stated 35'-1 1/8".
- No run is closure-forced.

**Door:** north wall, run 0. Every value below is **derived** from the vector at the verified scale.

- **6 1/8"** from the NW corner to the west jamb of a **36"** frame opening.
- The leaf is drawn 36" × 1 3/4", hinged at the west jamb (`near`), and swings **into** room 113.
- The drawn wall break is 40" (4 1/8" from the corner), which allows a 2" frame each side.
- The clear passage through the frame is **not** on the plan. Measure it before delivery: it is narrower than 36".
- Door height is not on the plan: built at 6'-8", **assumed** (house default).

**Not modelled:**
- The north wall's hatch, which looks like a rated wall.
- A corridor stub wall outside the north wall.
- Room 113's east wall has no opening on this sheet. The nearby door belongs to the 113A/113B partition.

**Ceiling:** **8'-0", assumed** (house default, `src: default`). It is not on the sheet, and **this is the number that decides the job** — see the booth heights below.

**Wall thickness:** built at the 4" house default. The plan reads 4 7/8". Thickness is cosmetic and moves no interior dimension.

**Notes on the sheet:** "Manufacturer shall field verify all dimensions." Every number above is a plan reading, not a site measurement.

## Model (built live in SketchUp 2026 over the bridge, 6 Oct 2026)

- **Room:** `scripts/build-takeoff.rb` `build_from` on the lock. It built 10 runs, 12 wall solids, 1 door and an 8'-0" ceiling slab. The interior is 0..458.125 × 0..−421.125 in model inches (observed).
- **Dimensions:** the room was dimensioned with `dimension-room-now.rb`.
  - `build-takeoff.rb` lays no door dimensions. This is a known defect (DEVLOG: nested `WR-Doors` openings are invisible to `doors_on`).
  - So its 12 wall dimensions were replaced by `WR_RoomDimsNow`'s set. That set has every run, both overalls and the door: 34'-8" from the NE corner, plus 3'-0" for the opening.
  - One 6 1/8" NW-corner → near-jamb dimension was added by hand on `WR-Dims-Doors`, stamped so a rerun clears it.
  - Its console says "CHAINS DO NOT CLOSE … y +18"". That is a **false alarm** from the free-standing pilaster: its two N/S faces get counted into the vertical chain. The geometry closes to 0.00".
- **Booths:** one MDL 7272 E and one MDL 7296 E were built with `booth-from-link.rb` from Benton's links. The other six are copies of those two groups, and every booth was placed by translation and rotation only, so each keeps its link's door hand. The layout is below.
- **Display:** `WR-Ceiling` is hidden.
- **Saved:** `Z:/Sketchup/ClientDrawings/Coastal Carolina University Sands Hall 113.skp`.

### Decoded links (observed)

Both links decode to the same configuration apart from the wall layout:

- Enhanced, door hand R, foam Gray.
- `rp` 1 (ramp), `ad` 1 (ADA), `ep` 1 (elevated floor), `rv` 1 (roof-mounted).
- `sl` 1, `bt` 1, `ac` 1.
- Off: `vs`, `ef`, `cs`, `hx`, `dk`, `jp`, `hp`, `sp`.

| | MDL 7272 E | MDL 7296 E |
|---|---|---|
| Door (WA STDDRFRM R + ramp) | S0, front | E0, right (short end) |
| Cable walls (RM swap) | E0, N0 | N0, N1 |
| Studio lights | 1 × SL52 | 2 × SL29 |
| Bass traps | 2 (NW, NE) | 2 (NW, SW) |
| Shell as built | 74" × 74" × 84 5/16" | 98" × 74" × 84 5/16" |
| Roof unit | RM7272, 65.5 × 64 × 10 5/16", top 94 5/8" | RM7296, 89.5 × 64 × 10 5/16", top 94 5/8" |
| Ramp projects | 45.6" past the door wall | 45.6" past the door wall |
| Ceiling the room must give (importer) | **95.31" (7'-11 5/16")** | **95.31" (7'-11 5/16")** |

**Not built: Audimute (`ac`) on both.** The importer refuses it by name. The `whisperroom-acoustic-package` skill has not been run; that waits on Benton.

**Flagged by the builder on both booths:**
- No WAJMBAD.
- IEP wall lift and vent-lift figures are defaults, not measured.
- IEP panels are +0.12 to +0.25" against their slots.
- The bass traps' bounding boxes overlap the corner seals.
- No roof-vent blocker.

## Open questions — ask before quoting

1. **Ceiling height of room 113.** This is the one that matters.
   - Each RM booth needs 95.31" by the importer's rule: 85" install clearance + 10.31" roof unit.
   - Against the assumed 8'-0" (96") that leaves **0.69"**.
   - As built, the RM top sits at 94 5/8", 1 3/8" under 96".
   - Any soffit, sprinkler head, light fixture or duct below 8'-0" kills it. Field-verify it.
2. **The two ramp landings below.** B5's and B6's landings are short of 60" × 60".
3. **North door clear width and height.** It is the only opening into 113 on this sheet, so it is the delivery path for every panel. Its frame opening is drawn at 36"; the clear passage and the height are not on the plan.
4. **North arrow.** None is on the sheet; plan-up is assumed to be north.

## Layout — 8 booths + the reserved zone (placed 6 Oct 2026)

**Provenance.** This is Claude's adaptation of the client's sheet A2, which Benton approved as "best as possible". It is **not** the client's own layout.
- It follows A2's arrangement with WhisperRoom sizes:
  - a row of 5 rooms on the south wall, doors facing north;
  - the big room against the north wall, east of centre;
  - a north-west cluster: one long room on the north wall with its door at its west end, and two small rooms below it with doors facing south.
- The quote mapping is **derived** from the sizes: the client's three ~55/56 isf rooms are the 3 × MDL 7296 E, and the five 44/38 isf rooms are the 5 × MDL 7272 E.
- The coordinates came from the coordinator. The booths are numbered B1–B8. **The client's A–I letters are not used**, because the mapping between the two is unknown.

**Frame.** x is measured from the west interior face and y from the south interior face. Both faces were read back off the model's floor polygon: 458 1/8" × 421 1/8", with the pilasters at x 0–7 1/8 and x 268 1/8–280 1/8, each 18" deep. Positions are exterior shells, not ramps. Every value in the table is **observed** from the model after placement.

| Booth | Model | Door faces | Shell x | Shell y | Ramp end |
|---|---|---|---|---|---|
| B1 | MDL 7296 E, long axis N-S | N | 8 1/8–82 1/8 | 1–99 | y 144.6 |
| B2 | MDL 7272 E | N | 84 1/8–158 1/8 | 1–75 | y 120.6 |
| B3 | MDL 7272 E | N | 160 1/8–234 1/8 | 1–75 | y 120.6 |
| B4 | MDL 7272 E | N | 307 1/8–381 1/8 | 1–75 | y 120.6 |
| B5 | MDL 7296 E, long axis N-S | N | 383 1/8–457 1/8 | 1–99 | y 144.6 |
| B6 | MDL 7296 E, long axis E-W | W | 95–193 | 346 1/8–420 1/8 | x 49.4 |
| B7 | MDL 7272 E | S | 80–154 | 270 1/8–344 1/8 | y 224.5 |
| B8 | MDL 7272 E | S | 156–230 | 270 1/8–344 1/8 | y 224.5 |

**Reserved zone,** tag `WR-Reserved`, drawn as outlines with a label. Benton is to draw it.
- It is for the 16'×16' booth: MDL 192192 E on the quote, which Benton called "MDL 96192 E". **It is not built.**
- The inner footprint is x 248 1/8–440 1/8, y 211 1/8–403 1/8, 18" off the north and east walls.
- The outer 18" clearance boundary is x 230 1/8–458 1/8, y 193 1/8–421 1/8.

**Clearances, read back from the model:**
- **Aisle from the south ramps to the north-west ramps:** 103.9" (8'-7 15/16"). This is the B2 → B7 and B3 → B8 ramp ends. B1's ramp end to B7's shell is 125.5".
- **B5's ramp end:** 48.5" (4'-0 1/2") to the reserved outer boundary, and 66.5" (5'-6 1/2") to the inner footprint.
- **B6's ramp end:** 7 3/8" from the room-door swing arc, and 49.4" (4'-1 3/8") to the west wall.
- **West aisle at the bottom of B6's ramp:** 80" (6'-8") from the west wall to B7's west face.
- **Booth to booth, shell to shell:** 2" for B1-B2, B2-B3, B4-B5, B6-B7, B6-B8 and B7-B8. B3 to B4 is 73".
  - Next to each other, the ramps run 27" apart.
  - A ramp's side edge sits 4" from the neighbouring shell.
- **Booth to wall:** the south row is 1" off the south wall. B5 is 1" off the east wall and B6 1" off the north wall. B1 is 8 1/8" off the west wall above the corner pilaster.
- **Booth to pilaster:** B1 is 1" from the south-west corner pilaster. B3 is 34" (2'-10") from the free pilaster, and the free pilaster is 27" (2'-3") from B4.
- **Booth to the reserved zone:** B6's east end is 37 1/8" from the outer boundary. B8's east face is **1/8"** from it, so B8 effectively touches it.
- **Pilasters:** both sit outside the reserved zone, which is now in the north-east corner.

**Flags:**
- No named aisle is under 36".
- **B5's ramp landing is short.** A 60"×60" landing centred on the ramp would cross the east wall by 2.5" and run 11.5" into the reserved outer zone. The depth available is 48.5" to the outer boundary and 66.5" to the inner footprint.
- **B6's ramp landing is short.** Only 49.4" lies between the ramp end and the west wall, and the landing area overlaps the room-door swing. The ramp itself clears the swing by 7 3/8".
- The other six landings are clear at 60"×60".

**Heights:** every roof unit tops out at 94 5/8", which is 1 3/8" under the **assumed** 8'-0" ceiling. The importer's ceiling requirement is 95.31", which leaves 0.69". Field-verify the ceiling.

**Model:**
- Groups are named `Booth 1 – MDL 7296 E` … `Booth 8 – MDL 7272 E`, with a text label each on `WR-Notes`.
- Placement dimensions are on `WR-Dims-Booth`, drawn at z 96 so they read over the booth roofs in plan.
- The staged labels were removed.
- Audimute is **not** laid out (pending Benton).
- Saved over `Z:/Sketchup/ClientDrawings/Coastal Carolina University Sands Hall 113.skp`.
