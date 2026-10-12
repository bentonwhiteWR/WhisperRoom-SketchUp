# Builder handoff: Walsh AP + 9-foam layout (Phase A done 12 Oct 2026 evening, desktop; Phase B waits on Benton)

## Model state: UNCHANGED
- `Z:\Sketchup\ClientDrawings\Walsh Construction Tech Lab MDL 96168 E.skp` is still the v7 layout from `HANDOFF-walsh.md`.
- Re-checked read-only over the bridge (12 Oct, ~19:00, observed): front doc path matches, `modified? false`, 16 scenes,
  booth transform +61.89/+11.63/+1.3125. All 33 survey pieces and covers match `ap9-survey.json` within 0.01. Nothing hidden.
- **Foam in the model (observed):** 6 `Foam` instances (S0i, S3i, E0i, W0i placed; E1i, W1i staged as NOT PLACED) plus the two
  2x2 squares cut from S1i (`Foam (2x2) back left` / `back right`, 1 instance each). That is 6 full sheets, not 7.
  **A no-cut layout therefore needs 3 new copies of `Foam`, not 2**, and the two S1i squares retire (see Phase B).
- AP: 5 x `Audimute2x4`, 2 x `Audimute1x4`, 14 x `Audimute1x2` (observed). Traps: 6.

## Produced (Phase A, offline, all in `.forge/builder/walsh/ap9/`)
- `v8model.py`: wall model built from the survey's exact rects (not `walls.py`'s rounded ones) + `check()`
  (2D gaps per wall, 3D gaps across corners, counts). `v8solve.py`: CP-SAT (OR-Tools 9.15) capacity / symmetry / row-line search.
  `v8cut.py`: "no piece crosses z = L" feasibility. `layout8.py`: builds the candidates, runs `check()`, writes the JSON.
  `render8.py`: review page + PNGs.
- `layout-v8.json` (recommended), `layout-v8-alt1.json`, `layout-v8-alt2.json`: wall-local rects, face plane per wall,
  nearest-fixed gap per piece, checker result. All three: check PASSED, min gap 0.50 piece-piece and piece-fixed,
  0.625 across the NW corner in 3D, counts 9 foam / AP 5-2-14.
- `review-v8.html` (unpublished; orchestrator publishes) and `elev/S.png, E.png, W.png, N.png, S-opt2.png, E-opt2.png`.

## Read first
1. `review-v8.html` (or the PNGs): the four elevations as seen from inside the booth.
2. `layout-v8.json`: `walls.<W>.pieces[]` = id, part, material, orient, s0/s1, z0/z1 (wall-local: S/N s = booth x, E/W s = booth y;
   s0 is the MIN booth coordinate, which is the viewer's RIGHT on S and E).
3. This file's Phase B steps.

## Result (derived)
- **Proved exact (CP-SAT, OPTIMAL/INFEASIBLE, 0.01 in, keep-outs rounded outward):** max sheets E 4, W 3, N 3, S 4 = 14 =
  9 foam + 5 AP 2x4, so every wall must carry its maximum. With that, S takes at most 9 1x2 (or 1x4 + 7 1x2); 10 and 1x4+8
  are infeasible. Only two no-cut compositions exist:
  A: E 4+0+2, W 3+1+2, N 3+1+1, S 4+0+9 (sheets + 1x4 + 1x2); B: E 4+0+2, W 3+0+4, N 3+1+1, S 4+1+7.
  Agrees with the earlier depth-3 grid search (`gcaps3.json`).
- Only A lets S keep a clean two-tier scheme (no piece crosses z 27.5); W follows no clean scheme in A or B. **v8 uses A.**
- Minimum standing 1x2s at full count: S 3, W 1, N 1, E 0 (2 if E is kept symmetric). v8 has 7 (= minimum + E's 2).
- **v8 per wall (wall-local inches):**
  - S back: bottom row z 3.25-27.25 = 1x2 pair (standing) between the S0/S1 low covers + foam 2x4 lying flat between the
    S1/S3 low covers. Band from z 27.75 (sheet tops 75.75, 0.50 under the IEP beams): stack of 3 flat 1x2 under the S0 high
    cover | foam | stack of 3 under S1 | AP 2x4 | foam | standing 1x2 under S3 (top 64.75). One 0.759 clearance everywhere in
    the band, traps included. Not mirror-symmetric (vent columns aren't).
  - E left: symmetric about y 54.6875. Band z 30.625-78.625 = AP 2x4 | foam | AP 2x4; row z 3.25-27.25 = 1x2 | foam flat | 1x2.
  - W right: back cluster (flat 1x2 z 18.125-30.125 over the W0 low cover; standing 1x2 + 1x4 from z 30.625), then foam | AP 2x4
    on the same column grid as E, foam flat in the bottom row. Band can't start below 30.571.
  - N front: row = foam flat | standing 1x2 | foam flat (z 3.25-27.25); 1x4 between the windows and AP 2x4 by the door, both
    z 27.75-75.75.
- **Options on the page (any combination passes the checker):** S1 (recommended, AP 2x4 in the band) vs S2 (foam band, AP 2x4
  flat in the bottom row); E1 (recommended, band level with W) vs E2 (band 27.75-75.75, level with S and N).
  v8 = S1+E1, alt1 = S2+E1, alt2 = S1+E2; S2+E2 = S from alt1 + E from alt2 (checked: PASSED).
- Exactly-0.50 spots (no margin): sheet tops under the beams on S and N, the 1x2 stacks, every bottom-row/band boundary on S
  and N, N03 to the door frame. Floor clearance is the rule's 3.25 exactly.

## Phase B steps (only after Benton's copy-back block approves the walls)
1. Read Benton's block; pick the JSON per wall (table above). If anything is edited, change `layout8.py` and re-run it; it
   must print `ok=True`.
2. Read-only first: assert `Sketchup.active_model.path` ends with `Walsh Construction Tech Lab MDL 96168 E.skp`, booth group
   `Booth - MDL 96168 E`, counts as above. **Save before the first edit** (`m.save`), then after every wall.
3. Load helpers from THIS machine's checkout: `C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/`
   (`build-booth-components.rb`, `wr-overlays.rb` with `$wr_no_autorun = true`). `ap9-dump.rb` still points at the laptop paths.
   The v7 job scripts (`v7.rb`, `press.rb`, `boxes.rb`, `verify.py`) are laptop-only and untracked; use
   `.forge/builder/peoplesspace-ap/ap-v2.rb` (place), `ap-press.rb` (seat), `clash.rb` as the method.
4. One job per wall, one undo operation each, inside the booth group's entities (never a whole-model `add_group`, never a
   blind `abort_operation`):
   - Fill each JSON slot with an instance of its part. Reuse existing instances; suggested foam reuse: S0i -> S04, S3i -> S09,
     E0i -> E02, W0i -> W04, E1i -> E05 (spin flat), W1i -> W06 (spin flat). Add **3** copies of the `Foam` definition
     (same definition, tag `WR-Booth-Foam`, copied from an existing Foam instance) for S13, N01, N03.
     With option S2 the S foam slots are S04, S08, S09 and S13 is the AP 2x4; the copy then goes to S08.
   - **Erase the two S1i squares** (`Foam (2x2) back left/right`): S1i is restored as a full sheet. Report it as a foam move.
   - Orientation: fabric = local -y into the room. Into-room normals: S +y, N -y, E -x, W +x. Rotation as in the skill
     (`ya = n.reverse`; standing: `za = up, xa = ya*za`; lying flat: `xa = up, za = xa*ya`); foam takes the same half-turn.
   - Position from `WR_Overlays.geom_extents(defn)` corners pushed through the rotation, then translate so the extents hit
     (s0, z0) and the back meets the face (S/W face 4.25, E 165.75, N 93.75).
   - Seat by multi-ray on the most proud face under the footprint (hide pieces first): S/W H-strip 4.313 at z ~40-41.5,
     E 165.688 at z ~40-41, N window-panel strip 93.688 at z ~22.5-23 (N01 and N03 cross it).
   - Names `<part> <wall>` (back/left/right/front); AP on `WR-Booth-Acoustic`, foam stays on `WR-Booth-Foam`.
5. Verify measured, not by eye: world boxes from geom extents, min gap >= 0.50 to pieces and to the survey's fixed items
   (feed wall-local rects to `v8model.check()`), counts 9 full `Foam` + 0 squares + AP 5/2/14 + 6 traps, fabric normals into
   the room, seat re-check 0.000.
6. Screenshots of the 4 walls, re-check the 16 scenes (InteriorAcousticRender / InteriorBackRender especially), update
   `clients/walsh-construction/notes.md` (AP section, foam moves), this file and the DEVLOG.

## Assumptions
- Standing 1x2s (12 x 24) and sheets lying flat are acceptable: v7 used both, and the DEVLOG allows horizontal sheets (reported).
- Piece sizes 24x48 / 12x48 / 24x12 and depth 2.125 (observed on v7 bodies). Wall centre = middle of the usable run.
- The foam/Audimute assignment (Audimute at the ends and vent columns, foam between) is my design call; Benton can swap it.

## Open questions (for Benton, via the page)
1. S1 or S2; E1 or E2.
2. 7 of 14 1x2s stand on end (minimum 5). OK?
3. OK to erase the two S1i squares in favour of a full sheet?
4. The orchestrator brief said "add 2 foam copies"; it is 3 (see Model state).
