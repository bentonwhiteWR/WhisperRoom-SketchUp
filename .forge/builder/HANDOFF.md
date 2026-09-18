# HANDOFF — Builder: Draw floor plan redesign, 1.72.0 (18 Sep 2026)

The previous handoff (ISL MDL 6060 ENV proposal pack) is in git history for this file.
Spec: `.forge/scoper/floorplan-redesign.md`. Approved mockup:
`.forge/scoper/floorplan-redesign.mockup.html`. Benton's rulings, 18 Sep: fix the mirror (Q1);
placed-by-eye doors warn, do not block (Q2); replace the Hinge dropdown with a 4-state
**Rotate door** button, adding `swing` to the payload.

## Produced
- `scripts/build-room.html` — the mockup, shipped. One screen: hover a wall for a ghost door,
  click to drop a 36" door, drag it (whole-inch snap, 1" corner clamp), arrows nudge, Delete
  removes, click a wall's dimension to edit/insert/delete it. **Rotate door** (and `R` when a
  door is selected and focus is not in a field) cycles near/in → far/in → far/out → near/out,
  labelled e.g. `hinge W jamb · opens in`. Outward doors draw the leaf and arc from the wall's
  exterior face (interior line + wall thickness). The payload has **no N/S flip**. Removed:
  the mockup's header note, the payload viewer, the `window.sketchup` stub, the `?test=1`
  harness, `FLIP_NS`. `setPointerCapture` is wrapped in try/catch.
- `scripts/build-room.rb` — `door(..., mat, swing = 'in')`: `'out'` moves the jambs out by
  `thick` along the outward normal and swings the leaf outward. The arc code is unchanged
  because it derives its sweep from the leaf tip. `build` passes `d['swing']`. `report`
  takes the doors array and prints `door N on run R: PLACED BY EYE, not measured` for each
  `placed` door. The header comment is rewritten for the one-screen dialog and the flip
  history.
- `scripts/rbtest-doorswing.py` — now runs {omitted, in, out} × {near, far} × {CW, CCW}, and
  checks the pivot is on the right jamb and face, the arc runs from the closed jamb to the leaf
  tip, and the arc midpoint and tip are on the interior side (or the exterior side for
  `out`).
- `.forge/builder/floorplan-uitest.py` — a headless-Chrome acceptance test of the shipped
  HTML with a stubbed `window.sketchup`. It has 29 checks. It replaces
  `build-room-uitest.py`, which tests the old two-mode dialog.
- `scripts/wr_tools/VERSION` 1.71.1 → **1.72.0**. DEVLOG entry at the top.

## Verification (what I saw)
- **observed** `python scripts/rbparse.py`: 77 files parse.
- **observed** `rbtest-doorswing.py`: 0 failures, 62 checks. `rbtest-takeoff.py`: 0
  failures. `takeoff-check.py --selftest`: 0 failures, and `dialog_grammar_js()` lifts
  `parseLen` and `arch` cleanly.
- **observed** `takeoff-vectors.html` served over HTTP in headless Chrome: "25 vectors, 0
  failed — parseLen extracted live from build-room.html". `parseLen` and `arch` are
  byte-identical to HEAD.
- **observed** `floorplan-uitest.py`: 29 PASS, no JS errors. The scenario is 12'-0" × 5'-6";
  the door is clicked onto the north wall at 3'-0", dragged to 4'-0", then set to width 36.
  Rotating four times returns to the start state, and so does `R`. `R` is ignored inside a
  field. Build stays enabled and the footer warns. The payload is
  `{"mode":"detail","name":"Room","runs":[{"d":"E","v":144},{"d":"S","v":66},{"d":"W","v":144},{"d":"N","v":66}],"doors":[{"run":0,"at":48,"w":36,"hinge":"near","swing":"in","placed":true}],"thick":4,"ceil":96,"door_h":80}`.
  Run 0 is E along the preview's top (north) edge, and the N run goes out as N.
- **observed** a screenshot with an outward door: the leaf and dashed arc sit outside the
  north wall, hinged on the E jamb.
- **NOT RUN IN SKETCHUP.** No Ruby executes outside SketchUp here.

## Read-first
1. `build-room.html`: the `NO N/S FLIP` comment, `payload()`, `doorGlyph`, and
   `ROT`/`rotate`/`rotLabel`.
2. `build-room.rb` `door`: the `out` branch sits just above `pivot`.
3. The parseLen comment in `build-room.html`. Never write the function's opening line
   anywhere else in the file. `takeoff-vectors.html` and `takeoff-check.py` regex-lift the
   first match, and the mockup's comment would have hijacked it.

## Mirror fix — what I checked (Q1)
- **derived** Preview VEC N=[0,-1] (screen-up) and Ruby DIR N=[0,1] (+y, up in plan view)
  show the same picture, so the old swap mirrored the room. Old payload E,N,W,S put run 0 on
  the model's SOUTH edge; the new E,S,W,N puts it on the north edge.
- **observed** `build-takeoff.rb` feeds `WR_BuildRoom::DIR` with no flip, clockwise from NW
  (`reference/takeoff-format.md` §Winding). The dialog now matches the take-off pipeline, and
  that pipeline is untouched.
- **observed** No other caller of the dialog payload or `WR_BuildRoom.build` exists
  (grep of scripts/, reference/, skills/). `panel.html` only launches the tool.
- **observed** The dialog never persisted runs or doors. Ruby remembers only `mode`
  (`last_mode`/`remember_mode`), so no saved state reopens mirrored.
- **observed** `takeoff-vectors.html` and `takeoff-check.py` take only the parse/format
  grammar from this file. No direction logic is involved.
- **derived** Rooms already built with ≤1.71.1 that have an asymmetric layout (a door) are
  mirrored in those models. The fix does not touch existing models.

## Assumptions
- **assumed** Rotation order near/in → far/in → far/out → near/out. Each click changes one
  thing.
- **assumed** An outward leaf hangs from the exterior face, meaning the interior jamb plus the
  full wall thickness. The leaf's 1.5" thickness still leans toward the opening, as for an
  inward door.
- **assumed** Door dimensions for an outward door sit just inside the room, with no
  leaf-width offset. An outward arc can cross the wall's orange dimension line in the
  preview. That is cosmetic.
- **assumed** The swing test's stubbed Geom is faithful enough, as it was for the original
  swing fix. The real Geom only runs live.

## Open questions (Benton, one live test in an Untitled model)
1. Run Draw floor plan with 12'-0" × 5'-6". Click the **north** wall near 3', drag to 4'-0",
   and Build. **The door must be on the north (top, +y) wall**, with the leaf opening into
   the room.
2. Reopen, add a door, and click **Rotate door** twice so it reads `… opens out`. Build. The
   leaf and swing arc must be **outside** the room, hung from the outer wall face. Auto
   Dimension must still find the jambs.
3. The console should print `door 1 on run 0: PLACED BY EYE, not measured` for a
   click-placed door.
4. Check that drag behaves in SketchUp's CEF dialog (pointer capture). If it does not, the
   spec §6 fallback applies.
5. Should rooms built with the old mirrored dialog be flagged anywhere? The fix cannot reach
   them.
