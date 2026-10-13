# Builder handoff: Walsh AP + 9-foam layout (12 Oct 2026, desktop): v8 APPLIED AND VERIFIED

## Model state
- `Z:\Sketchup\ClientDrawings\Walsh Construction Tech Lab MDL 96168 E.skp` now carries **layout v8** (`.forge/builder/walsh/ap9/layout-v8.json`,
  options S1 + E1, Benton-approved as drawn, reported). It was saved before the first edit, after each wall, and once more at the end
  (20:02, `modified? false`).
- **Live counts (observed, final verify after the last save):** Foam 9 full sheets (no 2x2 squares left), Audimute 5 x 2x4 / 2 x 1x4 / 14 x 1x2,
  traps 6. 0 hidden entities in the booth before and after. 16 scenes unchanged; the active scene is still `Opt2 07 InteriorAcousticRender`.
- Per-wall notes and coordinates: `clients/walsh-construction/notes.md`, section "Acoustic package + 9 foam sheets, layout v8".

## Produced
- **Phase A (design, offline):**
  - `v8model.py`, `v8solve.py` (CP-SAT), `v8cut.py`, `layout8.py`, `render8.py`;
  - `layout-v8*.json`, `review-v8.html`, `elev/{S,E,W,N,S-opt2,E-opt2}.png`.
  - Result: proved per-wall maxima E 4 / W 3 / N 3 / S 4 sheets, so every wall is full. Composition A was chosen because only it keeps the
    back wall regular.
- **Phase B (live), all in `.forge/builder/walsh/ap9/`:**
  - `b-probe.rb`: read-only probe of the transforms and conventions.
  - `b-plan.py` -> `b-plan.json`: which instance (persistent id) fills each slot.
  - `b-lib.rb`: helpers.
  - `b-wall.rb` with the wrappers `b-job-<W>.rb` (commit) and `b-dry-<W>.rb` (the same job, aborted at the end).
  - `b-verify.rb` + `b-verify-job.rb` + `b-verify.py`: independent verify; the final result is kept in `b-verify-final.json`.
  - `b-erase-squares.rb` + `b-erase-job.rb`, `b-save.rb`, `b-shots.rb` (+ `-job`), `b-scenes.rb` (+ `-job`).
- **Screenshots:** `elev/live-S.png`, `live-E.png`, `live-W.png`, `live-N.png` (temporary camera, restored) and `elev/scene-01.png` ... `scene-16.png`.
  All of them were looked at.

## How it was applied (so it can be repeated)
- **Order: S, then the squares, then E, W, N.** Each wall was one `start_operation(..., true)` (one Ctrl+Z), with `abort_operation` on any
  exception. Each ran as a dry run first.
- **Sources were chosen to avoid any temporary staging.** The S job borrowed 6 1x2s (2 from E, 2 from W, 2 from N). The E job also put E's 1x4
  straight into the free N04 slot, which breaks a circular dependency (E03 -> N04 -> N02 -> E03).
- **Transforms copy the v7 conventions (observed):**
  - Audimute: body back at local y 1.5, fabric local -y. It stands with local z up; a lying 2x4 or a standing 1x2 has local x up.
  - Foam: 48 x 24 x 2 in local x/y/z; profile local +z to the room, back z = 0 on the wall.
- **Seating:** a ray grid every ~3 in along the wall and 0.5 in up, cast with all foam/Audimute hidden INSIDE the operation and unhidden before
  commit. The piece's back goes on the most proud hit.
- **New foam:** `add_instance` of the `Foam` definition into the booth group, tagged like `Foam  S0i`.
  - Names: `Foam  S1i`, `Foam  N0i`, `Foam  N1i`.
  - Staged sheets renamed `Foam  E1i` / `Foam  W1i`.
  - Audimute that changed wall renamed `<part> <wall>`, with `wr_walsh/wall` updated.
  - Every piece has `wr_walsh/v8_slot`.
- **The S1i squares were erased** only after S verified with the full `Foam  S1i` in place.

## Verify results (observed, per wall, each run straight after that wall's commit; tolerance 0.02 on position)
| Wall | Pieces | Max position error | Seat air (min/max) | Min gap piece / fixed | Fabric into room | Result |
|---|---|---|---|---|---|---|
| S | 13 | 0.0000 | 0.0000 / 0.0000 | 0.50 / 0.50 (beam 1) | all | PASS |
| E (+ N04) | 6 (+1) | 0.0000 | 0.0000 / 0.0000 | 1.00 / 1.31 (E); N04 0.50 to beam 1 | all | PASS |
| W | 6 | 0.0000 | 0.0000 / 0.0000 | 0.50 / 0.55 | all | PASS |
| N | 5 | 0.0000 | 0.0000 / 0.0000 | 0.50 / 0.50 | all | PASS |
| Whole booth (final) | 30 | 0.0000 | 0.0000 | 0.50 / 0.50; 3D to live fixed 0.50; NW corner 0.625 | all | PASS |

Nothing deviated from the JSON. Seats: S/W 4.25 or the H-strip at 4.3125, E 165.75 / 165.6875, N 93.75 / 93.6875.

## Gotchas learned (this session)
- **SketchUp `Length` compares with model tolerance.** `x.length < 1e-9` is false even for 0, so compare `.to_f`. A right-handedness guard
  tripped on this.
- **A flush piece's back is coplanar with the wall face.** Rays that step through pieces then also step past the wall and read
  0.06-1.0 in "air". Measure seats with the pieces hidden inside an operation instead (the verify aborts its operation, so there is no net change).
- **A bridge job that `load`s a file returns `true`.** Store the result in a global (`$b8_result`) and end the wrapper with it.
- **Setting `camera.aspect_ratio` against a different viewport aspect makes `write_image` crop.** Render at the viewport aspect instead.
  Scene shots set `PageOptions['TransitionTime']` to 0 and restore it (the scene-export tool's method).
- Saving needs `--write-root Z:/Sketchup/ClientDrawings` and `m.save(m.path)`; a bare `m.save` is refused by the bridge.

## Assumptions
- Ray-measured faces are the truth for seating (S/W 4.25 with the H-strip at 4.3125, E 165.75, N 93.75).
- Benton's approval and the S1i square removal are as relayed by the coordinator (reported).

## Open questions
- None blocking. `.forge/builder/HANDOFF-walsh.md` still says the AP/foam layout is "frozen at v7"; that line is now stale.
- Renders are Benton's.
- The importer bug (7 foam where the BOM gives 9) is still open in `wr-overlays.rb`.
