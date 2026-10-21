STATUS: BLOCKED SketchUp bridge never answered (polled 09:47-10:35, 21 Oct). Geometry, wall table, scripts and an offline to-scale plan are done; nothing has been built in the .skp.

# Builder handoff: Walsh Construction Tech Lab, corner platform layout (21 Oct 2026)

Brief rev 2 (Benton: "Idk just draw the room as close to their drawing as possible. The black walls can move."). Only the platform + ramp option is drawn. Sarah's Zoom is at 1:30 pm.

**Disclosure.** I overwrote the previous working-tree HANDOFF.md before reading it. It had uncommitted changes, so git cannot restore that version. HEAD still holds the CCU Sands 113 handoff. The ISL handoffs are untouched in `.forge/builder/HANDOFF-isl-*.md`.

## Produced
- **Offline plan:** `Z:\Sketchup\Proposals\Walsh Construction Tech Lab MDL 96168 E - Corner Platform\Corner Platform plan (offline, not SketchUp).png`.
  - Drawn to scale, top-down, from the same geometry the SketchUp scripts use.
  - Every black-wall run is dimensioned, plus doors, booth, platform and ramp.
  - It also has the one note, a scale bar and a legend.
  - Regenerate with `python .forge/builder/walsh/corner/plan_svg.py out.svg`, then screenshot it with Chrome headless.
- **Scripts:** `.forge/builder/walsh/corner/`. All of them pass `scripts/rbparse.py`, and none has been run.
  - `geom.rb`: the geometry, mirroring `arch_geom.py`. Override with `$walsh_cfg`, e.g. `{'RAMP_DIR'=>'corner'}`.
  - `survey.rb`: read-only survey.
  - `s0-saveas.rb`: saves as the new file. It refuses to overwrite.
  - `s2-retag.rb`:
    - finds the Platform copy using the scene tags;
    - hides the Ramp copy's tag;
    - parks the old room and dims on hidden `Walsh Old Room 12 Oct` / `Walsh Old Dims 12 Oct`.
    - `$walsh_dry = true` previews without changing anything.
  - `s3-room.rb`:
    - builds the new room `Tech Lab 13 - Corner 21 Oct` at the old room's origin;
    - black walls go on `WR-Room-New`;
    - includes the pocket stub, south run and approximate pocket door.
  - `s4-booth.rb`:
    - one rigid move of the Platform copy's booth, platform, ramp and lights;
    - with `RAMP_DIR 'open'`, mirrors everything in front of the N face about booth x = 144;
    - prints the s/d extents for verification.
  - `s6-dims.rb`:
    - one `Corner Dims 21 Oct` group, laid out to the same placement as the offline plan;
    - the door and platform chains sit on the platform top, because z-0 dims are hidden under it.
  - `s7-scenes.rb`:
    - re-aims `Platform 06 TopDown` and `Platform 01 HeroRender`;
    - exports SketchUp PNGs (not V-Ray);
    - lists the stale scenes.
  - `flatten.py`: flattens the PNGs onto white and trims them.
- **Notes:** "21 Oct revision: corner platform layout" appended to `clients/walsh-construction/notes.md`, with the wall table, assumptions and run order.

## Wall table (interior faces) — ours vs architect

| Run | Ours | Architect |
|---|---|---|
| Exterior wall, apex to corner wall | 32'-0" | 32'-0" stated |
| NEW corner wall, exterior to front wall | 9'-2 5/8" | 9'-1" MIN CLR |
| NEW corner wall, front wall to south wall | 2'-9 1/4" | not dimensioned |
| NEW front wall | 7'-0" | ~7'-0" |
| NEW step wall | 3'-10" | ~3'-3" |
| NEW zone wall | 4'-7 5/8" | ~4'-8" scaled |
| NEW angled wall, zone wall to south wall | 8'-5 1/2" | not dimensioned |
| South wall, SW corner to angled wall | 10'-10" | not dimensioned |
| South wall, angled wall to corner wall (pocket) | 15'-0 3/8" | not dimensioned |
| West wall | 18'-11" | 18'-11" stated |
| NW angled wall | 13'-8 7/8" | take-off |

The booth runs 11 5/8" to 15'-1 5/8" along the exterior wall. The architect's booth zone is 14'-8".

## Read-first
- `clients/walsh-construction/notes.md`, both the 21 Oct section and the 12 Oct "Shell" facts. s4 relies on the shell being at room-local (61.89, 11.63).
- Run order:
  1. `python scripts/sketchup-bridge.py run .forge/builder/walsh/corner/survey.rb`. Read it and confirm two `Tech Lab` rooms and the Platform copy's members.
  2. `s0-saveas.rb` with `--write-root "Z:/Sketchup/ClientDrawings"`.
  3. `s2-retag.rb`, after a `$walsh_dry = true` preview.
  4. `s3-room.rb`, then `s4-booth.rb`, then `s6-dims.rb`.
  5. `s7-scenes.rb` with `--write-root "Z:/Sketchup"`.
  6. `flatten.py` on the PNGs.
  7. Look at every image.
- Never call `add_group` on the whole model. Every step saves.

## Assumptions
- **Ramp direction: open end, NOT the corner.**
  - The coordinator's "drop the flip, ramp toward the corner" rests on my earlier misread of the markup.
  - Zoomed, the markup has the platform at a door near the step, with the ramp descending toward the open (NW) end.
  - A ramp toward the corner would also dead-end into the step wall.
  - So the default stays `RAMP_DIR 'open'`, which is architect-faithful and usable. `'corner'` is a one-line switch, but the dim offsets are only tuned for `'open'`.
- **Architect's stated figures:** 32'-0" is apex to the corner-wall interior face, and 18'-11" is between interior faces. The south wall moves about 22" south of our take-off.
- **Scaled positions:** the step wall (7'-0") and angled wall (11'-7 5/8" along the exterior wall) are scaled from a 239 px capture, ±6".
- **Pocket door:** 3'-0", 1'-0" off the corner wall, swinging into the pocket. Estimated.
- **Platform and ramp:** platform 44" × 46", ramp 48" × 46", scaled from the 12 Oct TopDown. s4 and s6 measure the live extents.
- **Front hardware:** FP = 0. If the live FP is more than 0, the front wall moves out by FP.
- **Door 24:** stays at x 4-40 on the moved south wall.
- **Ceiling:** 8'-0", the house default.
- **Rounding:** the plan shows 1/8" fractions, not the house round-to-inch. It is a build sheet, and rounding would show the 11 5/8" gaps as 1'-0".

## Open-questions
- **Platform exposure.** With the minimum moves, the platform and ramp sit mostly outside the alcove, in the open Tech Lab, and the alcove is mostly empty.
  - Option T moves the zigzag with our door: step about 11'-0 5/8", angled wall about 15'-6 5/8", foot about 5'-9" from SW, still clear of door 24.
  - Benton or the client to choose.
- **V-Ray hero:** not attempted, because there was no bridge. s7 makes a SketchUp PNG labelled "not V-Ray".
- **Ceiling and pocket door:** both need real figures from the client.
