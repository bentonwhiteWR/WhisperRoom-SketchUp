# HANDOFF: studio-light height and rods, take-off door dims and closure (1.84.0)

## Produced
- `scripts/wr-overlays.rb`
  - `sl_tile_rects_with_tiles` pairs each usable tile rectangle with its CL tile. `sl_tile_rects` now wraps it.
  - `ceiling_underside(tile)`: the tile's underside z, read off its horizontal faces.
    - Normal direction is ignored, area is summed per height, and the lowest big level wins. Never the bounding
      box.
    - Returns nil when the tile has no horizontal face.
  - `underside_at(faces, x, y)`: a ray test limited to one tile.
  - `sl_keepouts(booth, rect, z_under, depth, skip)`: faces hanging into the fixture band inside a tile
    rectangle (roof-unit rods, hinges, anything).
  - `place_studio_lights`: the top goes flush with its tile's underside face, and the fixture is moved off the
    keep-outs.
    - It is re-measured afterwards (9-point ray check, 1/32). Blocked, overhang and off-underside cases each get
      a named warning.
    - A tile with no face is refused before the old fixtures come out.
  - `place_iep_beams`:
    - after the beams go in, each studio light's bottom is checked against the lowest beam bottom (warned,
      never moved);
    - the 10284 "KNOWN IMPORTER BUG" text is reworded to an unconfirmed theory.
- `scripts/wr-accessories.rb`: `SL_KEEP_CLEAR` = 0.5 (assumed) and `sl_clear_keepouts`, which is pure.
- `scripts/build-takeoff.rb`
  - `door_jambs` (pure) computes the jambs from the lock, and they are passed to `dimension_face` as `:doors`.
  - The per-room dimension report is printed, with a missing-door line.
- `scripts/auto-dimension.rb`
  - `door_corner` (pure): doors are dimensioned off the NEAR corner.
  - `closure` now subtracts the measured doubled-back length (`coverage`, `:jog_x/:jog_y`).
  - The report names the jog.
- Tests:
  - `scripts/rbtest-takeoff.py`: dj1-3, dc1-3, cl1-6, nc1-5.
  - `scripts/rbtest-accessories.py`: block 4b, the rods.
  - New `scripts/rbtest-sl-mount.py`: the stubbed SketchUp half.
- `scripts/wr_tools/VERSION` 1.84.0, DEVLOG entry, `.forge/GOAL.md` Now.

## Read first
- DEVLOG `2026-10-12 -- 1.84.0` (root causes, evidence, test list, what is unverified).
- `.forge/builder/HANDOFF-peoplesspace-accessories.md`: the 80.25 / 78.89 measurements and the rod positions.
- `clients/ccu-sands-hall-113/notes.md` and `takeoff.json`: the pilaster and the 6 1/8" door.

## Assumptions
- `SL_KEEP_CLEAR` = 0.5 in from any keep-out. It's the acoustic package's gap; no drawing gives one.
- The tile's lowest big horizontal level is its mounting face. Confirmed live on STD9648CL SIDE: 80.25 against a box
  of 78.892.
- Anything hanging into the fixture band inside the tile rectangle should be avoided, including hinges, not
  just rods.
- Near corner is the right corner for door dimensions. It's the drafting norm, CLAUDE.md says "corner -> near
  jamb", and it's what Benton drew by hand on CCU.
- The CL tiles are direct children of the booth group, so their `transformation` is booth-local. That follows
  from how `build_booth` captures `deck_added['CL']`, and the live 96120 builds confirmed it.

## Open questions
1. **Live checks: DONE, all passed** (12 Oct, blank scratch doc, not saved; numbers in the DEVLOG 1.84.0
   "Verified live" block). The current RM96120 / RM96120VSS parts have no rods below the roof, so rod
   avoidance was proven with stand-in rods only. A roof unit that really has rods has not been built.
2. `place_booth_lighting` (standard BoothLighting) still mounts off the tile bounding box, so the same 1.36 in
   low. Does Benton want it moved to `ceiling_underside` too?
3. The near-corner rule changes the door dimension on every room `dimension-room-now.rb` dimensions. Re-press
   it on any delivered drawing only if wanted; nothing existing is touched.
