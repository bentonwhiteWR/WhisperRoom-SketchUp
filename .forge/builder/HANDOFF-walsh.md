# Builder handoff: Walsh Construction, PHAME Tech Lab (12 Oct 2026)

## State
- **Model:** `Z:\Sketchup\ClientDrawings\Walsh Construction Tech Lab MDL 96168 E.skp`. New file, saved after the final step, open in SketchUp 2026.
- **Contents:**
  - the Tech Lab room, with its take-off dimensions;
  - MDL 96168 E from the corrected link, with the link's ADA ramp (that ramp is Option 2);
  - 6 bass traps, the full AP, studio lights and IEP beams;
  - 8 V-Ray room lights;
  - 16 scenes: `Opt2 01..08` and an identical `Opt1 01..08` series.
- **SUPERSEDED (12 Oct evening): the AP/foam layout is now v8** (9 foam + AP 5/2/14, applied and verified). See `.forge/builder/HANDOFF-walsh-ap.md` and `.forge/builder/walsh/ap9/layout-v8.json`. The v7 notes below are history.
- **Full notes, constraints table and per-wall layout:** `clients/walsh-construction/notes.md` (read it first).
- **Take-off:** `clients/walsh-construction/takeoff-vector.json`, built by `clients/walsh-construction/build-techlab.rb`.
- **Job scripts:** `.forge/builder/walsh/` (untracked).
  - `v7.rb` + `plan7.py`/`plan7.json`: the current layout.
  - `press.rb`: seats pieces by ray.
  - `boxes.rb` + `verify.py`: measured gap and clash check.
  - `scenes.rb`: rebuilds both scene series.
  - `lights.rb`, `bdims.rb`, `redim.rb`, `covers.rb`, `raise.rb`, `locovers.rb`, `traps3.rb`.
- **Screenshots:** `.forge/builder/walsh/shots/` (untracked; client imagery).

## Current layout (v7), booth-local inches
- **Traps, 3 per back corner:** 56.25-80.25 / 29.50-53.50 / 2.75-26.75. Gaps are 2.75 each. The top trap is flush to the tile (80.25, measured) and the bottom trap sits on the EFP (2.75).
- **Back (S), symmetric about x 85:**
  - end columns: vertical 1x2 at x 21.36 and 136.64, z 29.5-53.5;
  - full foam S0i at x 38.29-62.29 and S3i at 107.71-131.71, z 18.57-66.57;
  - centre: 2x4 at x 73-97, z 15.75-63.75, over a 1x2 at z 3.25-15.25.
- **Left (E) and right (W), identical:**
  - foam at y 29.26-53.26 (E0i / W0i);
  - 2x4 at y 53.76-77.76;
  - 1x4 at y 78.26-90.26;
  - all three on the band z 18.57-66.57;
  - 1x2 high at y 33.63 and 62.0, z 67.07-79.07;
  - 1x2 low at y 39.67 and 65.0, z 3.25-15.25.
- **Front (N):**
  - horizontal 2x4 at x 12.2-60.2, z 12.7-36.7;
  - 1x2 at x 64.8-88.8, z 24.7-36.7 and 12.2-24.2;
  - vertical 1x2 between the windows at x 43-55, z 51.75-75.75;
  - 2x4 beside the door at x 93.88-117.88, z 18.57-66.57.
- **Staged outside the room's west wall, named NOT PLACED:** foam E1i and W1i, and the two 24 x 24 squares cut from S1i (cut across the length, the r5-cut.rb way).
- **Checks:** every gap is at least 0.50, every piece is seated at 0.000 (fabric normal into the room), and there are no clashes.

## Measured constraints (the ones that decide the layout)
- **Covers:** high covers z 65.43-80.25, low covers z 2.75-17.57, so the clear height between them is **47.86**. A 48 in piece can't sit over a vent panel.
- **IEP beams:** z 76.25-79.25 at x 48.25-49.75, 96.25-97.75 and 120.25-121.75. Anything crossing one tops out at **75.75**.
- **Ceiling seals:** z >= 79.25.
- **Front wall:** the window trims leave 13.0 in clear between the windows.
- **Trap legs:** SW <= 16.38, SE >= 153.69.

## Assumptions
- **Ceiling:** 8'-0", assumed (Benton: "assume 8' ceiling but we don't know"). A note in the model says so.
- **Plan-up = model +y.** Not true north.
- **Trap count:** from Sarah's "Recording Studio" package (3 packs = 6), reported. The link has no `pk`.
- **Booth position:**
  - Placed so its outermost EFS hardware is 1 in off the south and east walls. That puts the shell 11 5/8 in off each wall.
  - It differs from the plan's dashed rectangle (about 3 in) because the link's EFS reaches out 10 in and the S3 and W0 EFS overhang the booth's corners by 10.6 in.
- **Duct covers:**
  - Three were moved off their ports at Benton's request, for the renders only (from/to values are in notes.md).
  - All 4 high covers were raised flush to the tile, and all 4 low covers were dropped onto the EFP.
- **Landing:** the 60 x 60 landing figure used for the ramp check is the general ADA number, my assumption.

## Open questions
1. What is the real ceiling height?
2. **Foam count: the importer placed 7 sheets where the BOM gives 9** (3 x FOAM3, reported by the coordinator, not re-checked). This is likely an importer bug in `wr-overlays.rb`'s foam pass. The build log (observed) puts one sheet on each 46 in solid or vent panel (S0, S1, S3, E0, E1, W0, W1 = 7). The window panels (N0, N1), the door (N3) and the narrow panels (N2, S2) got none.
3. Where do the staged foam pieces go (E1i, W1i, the two S1i squares)? That is the layout pass's job.
4. Benton should confirm the booth position (11 5/8 in shell offsets) against the client's dashed rectangle.
5. Door 1 belongs to Storage 17, not the Tech Lab. Did Sarah mean door 24 for anything?

## Gotchas learned
- **A whole-model `add_group(m.entities.to_a)` hung SketchUp 2026.** It went Not Responding, the bridge was lost and the app restarted into a recovered "Untitled_1". Room dimensions, booth dimensions and lights were lost and had to be rebuilt. Never group the whole model. Tag-based grouping is what the model uses now.
- **Never call `abort_operation` blind.** A stray one after a failed job (bdims with zero offset vectors) wiped 9 room dimensions.
- **`add_dimension_linear` raises ArgumentError on a zero offset vector.**
- **The bridge sets `$wr_no_autorun = true`.** Scripts that autorun on load don't run; call the entry method instead.
- **V-Ray's "Upgrading V-Ray components" modal blocks the bridge.** Run with `--modal allow` and the s4-vray-activate pattern.
- **`WR_DropLights.create_light(ctx, w, h)` takes HALF sizes.** Use (12, 24) for a 2x4 fixture. CCU's (24, 48) made 4 x 8 lights.
- **The take-off pipeline is rectilinear only.** For angled rooms, use the `build-techlab.rb` pattern: WR_BuildRoom's polygon/mitre/wall_run/door plus `dimension_face`. The auto-dimension closure can't prove angled runs; check the vector sum yourself.
