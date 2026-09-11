# HANDOFF — the light rig's borrowed walls follow the real wall (11 Sep 2026)

## Produced

- `scripts/wr-scene-walls.rb` — `model_box_of` (a wall's model-space box; `model_centre`
  now derives from it); every named wall unit carries `:mbox` and `:rig`. New `RIG_DICT`,
  `RIG_BIND_TOL` (2 in), `rig_bound?` (pure), `rig_walls`, `bind_rig_walls`. A borrowed
  face whose box sits inside a named wall's box becomes one of that wall's `:pieces`; one
  that matches no wall becomes a wall-like unit of its own (`:kind => 'rig'`, key
  `r:<id>`, room label "Light rig (open run)"). Every rig face is marked in `@wall_rooms`
  so `object_units` no longer lists it as an object row. `unit_label` reads a rig unit.
- `scripts/wr-autoset.rb` — `wall_geometry` carries `'kind'` and `'rig'` (bound count)
  and labels an open-run face "(light rig, open run)"; new pure `hides_line` (a hidden
  wall says how many rig faces went with it) and `rig_counts`; `walls_line` adds a light
  rig clause — bound / open counts and the render consequence; `plate_log` uses
  `hides_line`. `wall_picks` and the cone are untouched: an open-run face is just another
  unit to them.
- `scripts/rbtest-autoset.py` — 258 -> 266, green (RUN). `rg1-rg8`; `rig_bound?` and
  `RIG_BIND_TOL` lifted verbatim into the `WR_SceneWalls` stub. Three mutants run and fail
  by name (never binding -> `rg1 rg3`; the hides line silent -> `rg4`; the run line silent
  -> `rg6`).
- `.forge/builder/verify-autoset.rb` — UNRUN. Parses. `make_rig_wall` builds a face group
  exactly the way `add_walls` does (top level, "WR Lights Wall N", tag "WR Lights",
  `WR_DropLights` kind/role/run/uuid). The moved room at (600, 400) gets one face 1/16 in
  inside Wall 2's solid and one on an open run 60 in beyond it. Section 17:
  `rig.bound_face_is_a_piece_of_Wall_2`, `rig.open_run_face_is_a_wall_unit_of_its_own`,
  `rig.neither_face_is_an_object_row`, `rig.ventilation_hides_the_bound_face_with_Wall_2`,
  `rig.ventilation_hides_the_open_run_face_in_the_cone`,
  `rig.angled_shows_the_bound_face_with_Wall_2`, `rig.log_says_the_face_went_with_Wall_2`,
  `rig.run_line_counts_the_rig`. "WR Lights" added to the cleanup.
- `DEVLOG.md` entry. NOT done, per the coordinator: no `VERSION` bump, no push.
  `scripts/wr-drop-lights.rb` and `scripts/proposal-package.rb` untouched.

## Read-first

- **Benton's question, answered from the source.** The borrowed faces are not junk: "Add
  walls" exists so V-Ray lights an ENCLOSED room — the interior rig is exposed for a
  capped, four-walled room, and `.forge/researcher/interior-lighting-design.md` puts an open
  side at -1.5 to -2 stops with sky leaking in (`.forge/scoper/layered-light-rig.md` §
  "A 3-sided room is brighter ... because the missing wall is another sky opening",
  observed). Two things put a face behind a hidden wall: (1) `WALLS_DEFAULT = 'all'` —
  the tool's default is "every run", which buries a face 1/16 in inside EVERY real wall's
  solid; (2) on "open runs only", `run_report` counts a real wall that is HIDDEN on the
  scene you press from as OPEN — by design, pinned in `rbtest-lights.py`, DEVLOG 1.28.x:
  *"the borrowed wall is what closes the room on the scenes where the real one is
  hidden."* The face is a top-level group; the wall picker knew it only as an OBJECT row,
  and AUTO-SET never auto-hides objects. So AUTO-SET hid the real wall (correctly, 1.58.0)
  and the rig's twin stayed in the shot.
- **The rig is not changed.** Its "hidden reads OPEN" rule is a deliberate, tested design
  and its purpose (enclosure for the render) is real. The fix is on the scene side: bound by
  POSITION at scan time, so **the rig already in Benton's open model binds without
  re-dropping the lights** — no attribute is needed and none was added.
- **The render trade-off, surfaced not chosen.** V-Ray does not render hidden geometry. A
  scene that hides a wall for the camera now also hides the rig's face there, so that
  side renders OPEN to the sky and the rig's enclosure trims no longer describe that
  frame. That is what hiding the real wall already meant; the borrowed face was fighting
  the camera, not fixing the light. A camera cannot see through a wall that seals the room
  for its light — there is no third option, and the run-level log line says it in words.
  If Benton wants the enclosed light AND the shot, the answer is a render taken from
  INSIDE the enclosure, which is not what these plates are.
- **Nothing Ruby here has run.** `rbparse.py` parses all 75 scripts and the harness;
  `rbtest-autoset.py` runs the pure half. `rig_walls`, `bind_rig_walls`, the pieces on a
  real page and the object-row exclusion are proven only by section 17.
- Checks to watch, in order: `rig.bound_face_is_a_piece_of_Wall_2` (the binding);
  `rig.ventilation_hides_the_bound_face_with_Wall_2` (the fix Benton asked for);
  `rig.neither_face_is_an_object_row` (no double rows in the pickers);
  `rig.angled_shows_the_bound_face_with_Wall_2` (it comes back).
- On his model the AUTO-SET log's `walls:` line should end `; light rig: N borrowed wall
  face(s) -- N bound to the real wall each stands inside (they hide and show with it) ...`
  and the vent plate `hides Room Wall N (dot 0.9x) + 1 light-rig wall face bound to it`.

## Assumptions

- A borrowed face binds when its model box lies within the wall's box grown by 2 in on
  every axis. The face stands 1/16 in inside the solid (`WALL_OUT`), so a 4 in (or 5 in
  historical) wall binds with room to spare; a face 10 in off the plane does not (`rg2`).
  A rig face on a run whose real wall is a bare face at top level (not a `Wall N` group)
  is not bound — there is no unit to bind to — and becomes an open-run unit.
- An open-run face is treated by the cone exactly as a wall (`rg8`): hidden when it
  stands between the camera and the booth. The rig's own header says sealing a 3-sided
  room "walls the camera out and the frame goes black", and that the object row exists so
  Benton "can hide again for one camera" — the cone now does that for him on the plates.
- A model with no rig writes nothing new: `rig_walls` is empty, `walls_line` is the
  1.58.0 line (`rg7`), the units are as before.
- The dialogs' wall chips show a bound face nowhere (it is a piece of the wall) and an
  open-run face as a chip under "Light rig (open run)" labelled `Wall <run>`. The
  proposal-package WALLS column counts units and now counts open-run faces among them.
- `Sketchup::Group#bounds` in the parent's space; `parent * child` composes outward —
  as in 1.58.0.

## Open-questions

1. Should the rig stop borrowing a face on a run whose real wall is merely hidden, now
   that the scene side hides the twin anyway? Left alone: it is a pinned design and the
   coordinator asked for the answer first. It would become a one-line change to
   `run_report` (`:walled => vis + hid > 0`) plus the `rbtest-lights.py` mutation that
   guards the opposite.
2. `WALLS_DEFAULT = 'all'` contradicts the header comment's "opt-in, default off" and the
   DEVLOG 1.28.x recommendation ("Default stays No"). Not touched; worth a decision.
3. The rig's `run` numbering and build-room's `Wall N` numbering are two walks of the
   polygon and need not agree; the label carries the run for information only.
