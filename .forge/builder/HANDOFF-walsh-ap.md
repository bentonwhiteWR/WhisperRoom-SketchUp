# Builder handoff: Walsh AP + 9-foam layout pass (12 Oct 2026, paused mid-planning)

## Model state: UNCHANGED
- `Z:\Sketchup\ClientDrawings\Walsh Construction Tech Lab MDL 96168 E.skp` is still the v7 layout from `HANDOFF-walsh.md`. No wall was edited in this pass.
- SketchUp shows the file as modified (observed). The only cause is the ray survey: it hid the 29 foam and AP pieces (21 AP + 6 Foam + 2 squares) and then unhid them. No geometry moved. Closing without saving is safe. So is saving.
- Still 7 sheets' worth of foam: 4 placed (S0i, S3i, E0i, W0i), plus E1i, W1i and two 2x2 squares from S1i staged outside the west wall. **The 2 missing sheets are NOT added yet.** Add them by copying a `Foam` instance (same definition, tag `WR-Booth-Foam`).
- Scope (Benton, reported): touch ONLY the foam and the Audimute. **All 9 foam sheets must end up inside the booth.** A layout that leaves a sheet out is not acceptable. Use 2x2 squares or horizontal sheets if needed.

## Files (all in `.forge/builder/walsh/`)
- `ap9-survey.json`: per-wall survey in wall-local 2D: every foam, AP, trap, cover, beam, seal, window and door rect, plus the observed face planes and usable runs.
- `ap9-dump.rb`: read-only bounds dump. `ap9-rays.rb`: the 0.5 in ray grid over the 4 wall faces.
- `ap9/walls.py`: **the wall model used by the search** (keep-outs, s-limits, z-limits). Start here.
- `ap9/capacity.py`: column-block DP (2-stage). `ap9/guill.py`: 4-stage row/column (guillotine) DP, called as `python guill.py <depth> [walls]`. `ap9/combine.py`: matches the per-wall Pareto sets against the piece requirement.
- `ap9/gcaps3.json`: the depth-3 Pareto sets per wall (count vectors B, F4, H, Q). `ap9/caps.json`: same from the 2-stage DP.
- `ap9/mksurvey.py`, `raymap.py`, `edges.py`: survey tooling. The raw `rays.json` stayed in the scratchpad. Re-run `ap9-rays.rb` (60 s) if needed.

## Measured this pass (observed by ray, booth-local inches)
- **Face planes:**
  - S and W: 4.25, H-strip 4.313 at z ~40-41.5.
  - E: 165.75, H-strip 165.688.
  - N: 93.75.
  - Seat each piece on the most proud face under its footprint, not at its centre.
- **Usable runs** (larger than the corner-seal bounding boxes suggest):
  - E: y 16.38 (trap) to 93.0 (door frame).
  - W: y 16.38 to 92.5 (N0i panel edge).
  - S: x 16.38 to 153.69 (traps).
  - N: x 4.25 to 121.25 (door frame).
- Keep-outs matched the notes table: covers, beams (top 75.75 when crossing), seals at 79.25, window trims x 7.5-42.5 and 55.5-90.5 at z 37.2-76.1, tile at 80.25, EFP at 2.75.
- **Door:** the swing is outward (the quote tool puts the swing clearance outside the booth). Only the frame matters inside.

## Capacity finding (derived, the key result so far)
- **Unit:** 1 cell = 24x24. The requirement is 37 cells: 14 sheets x 2 (9 foam + 5 2x4), 2 x 1x4 at 1 cell, 14 x 1x2 at 0.5 cell.
- **Rules applied:** gaps >= 0.5 everywhere, z 3.25 to 79.75 (0.5 off the floor and tile), no piece cut except foam into 2x2 squares.
- **Column-only DP:** S 11.5, E 9.0, W 7.5, N 7.0 = **35.0** cells. Short.
- **3-stage row/column search:** S 13.0, E 9.0, W 8.0, N 7.5 = **37.5** cells. So a full fit is **possible on cell count**.
- **Next step:** the composition check, i.e. whether some combination of the Pareto vectors gives B >= 14-c, F4 >= 2, H >= 14, Q >= 2c, where c is the number of foam sheets cut into squares. I stopped it mid-run because it enumerates the full product and needs pruning (iterate walls with a dict of partial sums).
- S at depth 3 took 505 s. Depth 4 was not run.
- **Constraint lessons:**
  - S's covers allow at most 3 vertical 48-tall pieces there (proved by interval analysis). S gains through 24-tall rows (horizontal sheets and squares).
  - W's back column can't take a 48-tall piece between its covers (46.86 clear). Its 3rd column is a 12-wide one (a 1x4) at the front corner.
  - N holds about 7.5 cells: a 24-tall row under the windows, a 1x4 between the windows (z 27.75-75.75), and a big piece plus a 24-tall piece beside the door (z 3.25-75.75, exactly 72.5).

## To resume
1. Confirm the active document path (`python scripts/sketchup-bridge.py eval "Sketchup.active_model.path"`).
2. In `ap9/`, fix `combine.py`, either by pruning or by running a small ILP with scipy `milp` over the Pareto vectors. Find which cut count c works.
3. Extend `guill.py` to return the placements (not only counts) for the chosen per-wall vectors. Check them against Benton's rules:
   - each wall symmetric about its centre where features allow;
   - foam and AP interleaved on the back wall;
   - full sheets before squares;
   - small pieces high and low on the back.
4. If no symmetric version exists, draw 2-3 candidates as PIL elevations and apply the recommended one.
5. Apply in small per-wall jobs, saving after each:
   - add the 2 foam copies;
   - seat each piece by multi-ray;
   - fabric (local -y) faces the room;
   - no whole-model `add_group`.
6. Verify, using the `verify.py` method:
   - min gap >= 0.5;
   - covers, traps, beams, trims and door clear;
   - counts: 9 foam, AP 5/2/14, 6 traps.
7. Finish with screenshots of the 4 walls, a re-check of the 16 scenes, and updates to notes.md and this handoff.
