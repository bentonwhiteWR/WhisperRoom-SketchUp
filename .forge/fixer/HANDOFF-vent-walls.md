# HANDOFF — the ventilation plate: walls not hidden, wrong vent wall (11 Sep 2026)

## Produced

- `scripts/wr-scene-walls.rb` — `each_piece(ents, depth, tr, &blk)` composes the room's
  and each container's transformation and yields it as a fourth block argument
  (existing three-argument blocks unaffected); new `compose`, `model_centre`; every wall
  unit carries `:centre` — the wall BANDS' bounding centre in MODEL space.
- `scripts/wr-autoset.rb` — `wall_geometry` reads `:centre` (old local read only as a nil
  fallback) and adds `'room'`/`'wall'`; new `walls_line`, `top_level_names`; `plate_log`
  gains a `vpick` argument and an explicit "NO wall units" branch; Apply summary WARNING
  when no wall units exist. Vent rule: `VENT_PLATE`, `vent_rank`, `wall_word`,
  `pick_vent`, `vent_line` (pure), `vent_parts`, `local_bearing`, `vent_choice` (live);
  `az_for(plate, door, vent, side = 1, vshift = 1)`,
  `aim_plate(..., side = 1, vshift = 1)`; `apply` decides `vpick` once per run, passes
  `vshift` to both aim calls, prints `walls:` once and `vent:` under the vent plate;
  `autoset_payload` reports the chosen vent bearing.
- `scripts/rbtest-autoset.py` — 217 -> 243, green (RUN). New checks `vt1-vt21` (the vent
  rule, the swing hand through the real `aim()`, the log line), `wl1-wl3` (`walls_line`),
  `wp10-wp11` (the swing does not move the occluder). `cam`/`shot` take `vshift`. Five
  mutants run and fail by name — list in the docstring.
- `.forge/builder/verify-autoset.rb` — UNRUN. Parses. `make_room_moved` (Room > Walls >
  Wall N, translated to (600, 400)), `make_booth(..., split_vents = true)` (E0 first, then
  N0/N1/N2), constants `B4`, `ROOM2`, and section 15:
  - `roomx.four_walls_found_under_Room_Walls`, `roomx.wall_centre_is_in_MODEL_space`,
    `roomx.local_bounds_would_have_been_wrong`, `roomx.wall_geometry_carries_the_model_centre`,
    `roomx.set_made`, `roomx.ventilation_plate_exists`,
    `roomx.ventilation_hides_the_wall_behind_the_vents`,
    `roomx.ventilation_leaves_the_far_wall_standing`, `roomx.log_counts_the_wall_units`,
    `roomx.log_hides_wall_2_by_name`, `roomx.no_units_is_said_out_loud`
  - `vent.parts_read_off_the_real_booth`, `vent.primary_is_the_wall_with_three`,
    `vent.shift_is_toward_the_single_vent`, `vent.single_vent_booth_is_unchanged`,
    `vent.camera_anchors_on_the_three_vent_wall`, `vent.camera_swings_toward_the_single_vent`,
    `vent.wall_behind_the_single_vent_stays_up`, `vent.log_names_the_walls_and_the_swing`,
    `vent.log_line_sits_under_the_vent_plate`, `vent.same_choice_on_a_re_run`
- `.forge/fixer/vent-walls/ROOTCAUSE-vent-walls-2026-09-11.md`, `DEVLOG.md` entry.
- NOT done, per the coordinator: no `VERSION` bump, no push. Committed locally, my paths only.

## Read-first

- **Nothing Ruby here has run.** `rbparse.py` is a real parse; `rbtest-autoset.py` runs the
  pure half. `model_centre`, `vent_parts`, `vent_choice`, the log lines inside a real `apply`
  and the hidden wall on a real page are proven only by section 15, which Benton runs
  from **File > New**.
- The wall fix rests on `Sketchup::Group#bounds` being in the PARENT's space (reported —
  the `side_of` comment records it observed live 31 Aug 2026) and on `parent.transformation
  * child.transformation` being the child's model transformation (assumed — the standard
  idiom; the fixture is a pure translation, for which the order does not matter, so a
  wrong order would only show on a rotated container).
- Checks to watch, in order: `roomx.wall_centre_is_in_MODEL_space` (if this fails the
  composition or the bounds-space claim is wrong and the walls half is unproven);
  `roomx.ventilation_hides_the_wall_behind_the_vents`; `vent.primary_is_the_wall_with_three`
  and `vent.camera_anchors_on_the_three_vent_wall`; `vent.single_vent_booth_is_unchanged`
  (if this fails, every one-vent booth moved).
- **Benton's ten-second diagnosis**, in the Ruby Console, BEFORE installing anything —
  it prints whether `Room` is moved and what its walls are called:
  ```
  Sketchup.active_model.entities.grep(Sketchup::Group).each { |g| puts "#{g.name.inspect} moved=#{!g.transformation.identity?} origin=#{g.transformation.origin}"; g.entities.grep(Sketchup::Group).each { |c| puts "   #{c.name.inspect} -> #{c.entities.grep(Sketchup::Group).map(&:name).first(6).inspect}" } }
  ```
  `moved=true` on `"Room"` with `"Walls" -> ["Wall 1", ...]` under it confirms the
  transform diagnosis. `moved=false` with those names means something I have not seen;
  no `Wall N` names means the room needs "Name walls for the scene picker" first — and
  the new `walls:` log line will say exactly that.
- After installing, the AUTO-SET log for his booth should open with
  `walls: 4 wall unit(s) the cone rule can hide -- Room: Wall 1, 2, 3, 4`, and under
  `05-ventilation`: `vent: anchored on the wall at bearing N deg, camera swung -25 deg --
  the wall opposite the door carries the most vents, 3 (N0 ..., N1 ..., N2 ...), against 1
  on the door +90 wall (E0 ...); the camera swings toward the door +90 wall ...`, then
  `hides Room Wall N (dot 0.9x)`.

## Assumptions

- The vent bearing on a booth with every vent on one wall is unchanged: the primary wall
  is that wall, `sec` is nil, `shift` is +1, `az_for` gives `vent_az + 25` as before
  (`vt6`, `vt15`, `vent.single_vent_booth_is_unchanged`).
- The swing MAGNITUDE stays the plate's `:swing => 25.0` in `PLATES` — one place, tunable.
  Benton said "slightly"; 25 is what every ventilation plate has carried, so the only
  change on his booth is the SIGN. On his MDL 96144 E: primary = back wall (3), the camera
  stands 25 degrees off the back wall's normal, leaning toward the right wall (1), which
  shows foreshortened in the same frame; the room wall behind the back is hidden (dot
  0.91), the wall behind the right vent stays up (dot 0.42).
- Vents on the wall OPPOSITE the primary: primary kept, +swing, log says "no single
  bearing shows both" (`vt7`).
- Ties: opposite the door, then a side wall, then the door wall; within a class +Y, -Y,
  +X, -X in booth-local space. Printed as a tie (`vt8-vt11`).
- A vent part whose shape names no wall (a squarish housing) is not counted and is named
  in the log (`vt12`, `vt14`).
- `walls_line` lists up to 8 top-level names, components marked `[component]`. A room that
  is a ComponentInstance is still NOT a wall room (unchanged: hiding inside a definition
  is model-wide) — but it is now named in the log as what was seen.
- The concurrent agent's files (`proposal-package.rb`, the two jstest files) untouched.
  The WALLS column in the dialog still reads "all shown" for the empty case — that column
  is proposal-package.rb's; the log and the Apply summary now carry the warning.

## Open-questions

1. Is his `Room` actually moved? The console line above settles it. If `moved=false` and
   the walls are named, the walls half of this is a correct fix for a bug he did not hit,
   and something else is wrong — bring the `walls:` log line.
2. `roomx.local_bounds_would_have_been_wrong` asserts the piece's own bounds read the
   local y (188..192, centre 190) after the room is moved. If SketchUp reports nested
   bounds in model space after all, that check fails AND `roomx.wall_centre_is_in_MODEL_space`
   passes only if `model_centre` happens to double-apply nothing — read both together.
3. Should the vent plate's swing magnitude differ from 25 when it turns toward a
   secondary wall? Left at 25 as instructed ("a direction plus one magnitude").
4. The angled/high plates still keep their own hand; they were out of scope for 1.57.0
   and remain so.
