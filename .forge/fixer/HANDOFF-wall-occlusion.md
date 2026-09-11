# HANDOFF — a wall hides only when it stands between the camera and the booth (11 Sep 2026)

## Produced

- `scripts/wr-autoset.rb` — the angular cone is gone from the hide decision. New pure
  half: `WALL_PAD` (0.5 in), `SIGHT_MIN` (1), `booth_targets` (the booth centre plus its
  eight box corners), `segment_box_t` (slab test: where the eye-to-point segment enters
  a padded box, nil if it does not cross it before the point or the point is inside it),
  `sight_lines_crossed`, `unit_box` (a unit's model box, or a 2 in cube around its centre
  for a unit with none). `wall_picks(plate, units, centre, eye, bbox = nil)` and
  `wall_log(..., bbox = nil)` take the booth's box; `wall_geometry` carries each unit's
  model-space `'box'` (`:mbox` from 1.60.0); `hides_line(label, crossed, rig, of = 9)`
  says WHY; `plate_log` takes `bbox` and prints `hides Room Wall 1 -- it stands between
  the camera and the booth: 9 of 9 sight lines to the booth cross it` or `walls: none
  hidden -- no wall stands between the camera and the booth (none of the 9 sight lines to
  the booth crosses one)`; `apply` builds `bb6` once from the booth bounds and passes it
  to both. `cone_dot`/`unit_vec` remain as functions (the suite reads the old number to
  document the regression) but nothing hides on them. `COS_CONE` is gone.
- `scripts/rbtest-autoset.py` — 266 -> 278, green (RUN). `wp1-wp9` rewritten against
  boxes (`wp9` now pins `SIGHT_MIN`/`WALL_PAD`; `wp10`/`wp11`, `cm14`, `rg8` given real
  wall boxes); `bt1-bt12` pin the four situations; `rg4` pins the new hides wording. Two
  mutants run and fail by name: back to the angular cone -> `bt3 bt4 bt7`; the
  point-inside-the-box guard dropped -> `wp1 wp5 wp8 bt8` (both observed).
- `.forge/builder/verify-autoset.rb` — UNRUN. Parses. Section 18 on the moved room
  (booth 4, door -Y, mid-room in x): `sight.front_hides_only_the_wall_in_front`,
  `sight.side_hides_only_the_wall_on_the_camera_side`,
  `sight.angled_leaves_the_far_and_off_side_walls_up`,
  `sight.ventilation_hides_only_the_wall_behind_the_vents`, `sight.log_says_why_by_name`,
  `sight.log_says_none_when_none_is_between`, `sight.wall_geometry_carries_the_model_box`.
  Section 5's `walls.angled_hides_some_but_not_all` and `walls.ventilation_hides_at_least_one`
  are unchanged and still hold under the new test (the angled eye outside the origin room
  looks in through the near corner).
- `.forge/fixer/wall-cone/` (Benton's two screenshots) committed as evidence. `DEVLOG.md`
  entry. NOT done, per the coordinator: no `VERSION` bump, no push;
  `proposal-package.rb` untouched. The "only ventilation hides" work from the withdrawn
  brief was backed out before any of it was committed; nothing of it remains.

## Read-first

- **The test, in one sentence:** a wall is hidden when a straight line from the camera eye
  to any of nine points on the booth — its centre and the eight corners of its box —
  passes through the wall's model-space box before it reaches that point.
- **Why the cone was wrong (derived from the screenshots and the code).** It compared the
  direction from the booth to the wall's CENTRE against the eye direction. A long wall's
  centre sits well along its length: a side wall running past the booth toward the camera
  reads 0.73 "toward the camera" (`bt3`), a far wall whose middle lies off to the camera's
  side reads 0.58 (`bt4`) — both inside the 60-degree cone, neither in front of the booth.
  His front shot lost a wall beyond the booth and his side shot a wall beside it.
- **The four situations, all pinned:** between -> hidden (`bt1`, `wp1`, `wp8`, `cm14`);
  beyond -> up (`bt2`, `bt4`); beside, inside the old cone -> up (`bt3`); camera outside
  looking in through the near corner -> both near walls hidden, far two up (`bt5`, `bt6`);
  plus camera inside the room -> the wall behind it is not between (`bt7`).
- **Unchanged, confirmed:** `CEILING_PLATES`/`ceiling_picks` untouched (`cl*` green,
  `ceil.*` untouched); `06-plan` still shows its walls (`wp3`, `walls.plan_hides_nothing`);
  `07-interior` untouched (`wp4`); the light-rig binding keys off which units are hidden
  and inherits the corrected test with no change — a bound face is a piece of its wall,
  an open-run face is a unit with its own (zero-thick, padded) box (`bt9`, `rg8`,
  `rig.*` untouched).
- **Nothing Ruby here has run.** `rbparse.py` parses all 75 scripts and the harness;
  `rbtest-autoset.py` runs the pure half. The pages and the log text on real walls are
  proven only by section 18.
- On his model the AUTO-SET log should now carry, under 02-front, one `hides ... it stands
  between the camera and the booth: N of 9 sight lines ...` line for the wall in front
  and nothing else; under 04-side the same for the wall on the camera side; and `walls:
  none hidden -- no wall stands between the camera and the booth` wherever nothing is.

## Assumptions

- A wall's box is its axis-aligned model-space box. On a rotated room that box is loose
  (it can include air at the wall's ends), which errs toward hiding — a sight line that
  clips the loose corner hides a wall that a tighter test would not. Acceptable and said;
  a tight test would need the wall's own plane.
- Nine sight lines. A wall that covers only a sliver of the booth between two corners and
  not the centre is missed; a wall clipped by one corner line is hidden. `SIGHT_MIN` is
  the single knob.
- `WALL_PAD` 0.5 in grows every wall box so a zero-thick rig face is a box; it also means
  a booth standing within 0.5 in of a wall has that wall's padded box touching its
  corner targets — those targets are then "inside" and ignored, never counted as behind.
- The booth's box is the union bounds (leaf swung open, vent housings) — the same box the
  vent and side rules already use; a swung leaf adds corner targets slightly outside the
  shell, which only widens what counts as "in front".

## Open-questions

1. Should the near-corner walls on `01-angled` be hidden at all, or would Benton rather
   see the corner and accept the booth partly covered? Today: hidden when any sight line
   crosses (his own hand practice, per the 1.48.0 note). One constant to raise.
2. A rotated room's loose boxes — worth a plane test if a real job shows a wall hidden
   that a sight line only clipped at the box corner.
