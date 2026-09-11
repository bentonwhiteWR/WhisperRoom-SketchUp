# HANDOFF — the high (and plan) plate hides the room ceiling (11 Sep 2026)

## Produced

- `scripts/wr-scene-walls.rb` — `scan` now returns `:ceilings` alongside `:walls` and
  `:objects`, registered in `@units` under `"c:<entityID>"` so `write_scene`, the snapshot
  and UNDO LAST APPLY carry them unchanged. New: `CEIL_MAX_T` (12), `CEIL_HINT_MAX_T` (24),
  `CEIL_MIN_SPAN` (48), `CEIL_NAME_RE`, `CEIL_TAG`; `model_box` (model-space box through
  the container transforms); `ceiling_shape?`, `ceiling_hint?` (pure); `booth_container?`,
  `each_container`, `ceiling_units`. `unit_label` reads a ceiling unit's label.
- `scripts/wr-autoset.rb` — `CEILING_PLATES = %w[03-high 06-plan]`, `CEIL_ABOVE_TOL`;
  `ceiling_over?`, `ceiling_picks`, `ceilings_line`, `ceiling_line` (pure);
  `ceiling_geometry` (live; drops anything inside the booth being shot). `apply` reads the
  ceilings once, prints a run-level `ceiling:` line after `walls:`, merges `ceiling_picks`
  into the wall picks per plate (so the same `write_scene` call and the same undo record
  cover them), and `plate_log` prints `hides ceiling ...` / `ceiling: none hidden` under
  03-high and 06-plan. The 06-plan wall line now reads "the walls are context from above,
  not occluders" instead of "nothing occludes from above", which was no longer true.
- `scripts/rbtest-autoset.py` — 243 -> 258, green (RUN). `cl1-cl15`. A `WR_SceneWalls`
  stub carries the recogniser's two pure methods and five constants lifted verbatim from
  `wr-scene-walls.rb`. Four mutants run and fail by name — list in the docstring.
- `.forge/builder/verify-autoset.rb` — UNRUN. Parses. `make_room_moved(..., ceiling = true)`
  adds a take-off-shaped `Ceiling` slab (z 96..100, full footprint, `WR-Ceiling`) to the
  room at (600, 400); section 16 reads booth 4's already-made set:
  `ceil.slab_is_recognised`, `ceil.box_is_in_MODEL_space`, `ceil.hint_read_from_name_and_tag`,
  `ceil.booths_are_never_ceilings`, `ceil.is_over_booth_4`,
  `ceil.none_over_booth_1_and_says_so`, `ceil.high_plate_hides_the_ceiling`,
  `ceil.plan_plate_hides_the_ceiling`, `ceil.plan_plate_walls_still_shown`,
  `ceil.angled_plate_leaves_the_ceiling`, `ceil.run_log_names_it`,
  `ceil.high_plate_log_says_hidden`. `WR-Ceiling` added to the cleanup.
- `DEVLOG.md` entry. NOT done, per the coordinator: no `VERSION` bump, no push;
  `proposal-package.rb` untouched.

## Read-first

- **Nothing Ruby here has run.** `rbparse.py` parses all 75 scripts and the harness;
  `rbtest-autoset.py` runs the pure half. `ceiling_units`, `model_box`, the merge into
  `write_scene` and the hidden slab on a real page are proven only by section 16.
- **What builds a ceiling in this repo (observed from source):** `build-room.rb` — the
  everyday builder — builds NONE (its "ceiling" is the wall height). `build-takeoff.rb`
  builds a `Ceiling` group on `WR-Ceiling`, 4 in thick, inside the room group.
  `wr-drop-lights.rb` builds a `WR Lights Ceiling` face group with
  `WR_DropLights/kind = "ceiling"`. Anything else in Benton's model is hand-made and can be
  called anything, so the recogniser is SHAPE-first: a flat, broad container (<= 12 in
  thick, >= 48 in each way; 24 in thick if its name/tag/attribute says ceiling), not a
  named wall piece, not on a `WR-Booth-*` tag, not inside a booth container. Which flat
  thing is THE ceiling for a given booth is decided per booth: box bottom at or above the
  booth's top (1 in tolerance), footprint covering the booth centre. A floor is flat and
  broad and below; a neighbouring room's ceiling does not cover the centre; both are named
  in the log as seen and passed over.
- **06-plan hides the ceiling too**, as directed. Its walls are untouched (`wall_picks`
  and `NO_WALL_PLATES` unchanged; `walls.plan_hides_nothing` counts wall units only and
  still holds; `ceil.plan_plate_walls_still_shown` pins it live). Reversal is one edit:
  drop `'06-plan'` from `CEILING_PLATES`; `cl4`, `cl9`, `cl12` and `cl15` then fail by name (observed). Reading the
  code showed nothing on the plan plate that a hidden lid would break: the plate is
  parallel, straight down, and its annotation allowlist is separate.
- Checks to watch, in order: `ceil.slab_is_recognised` and `ceil.box_is_in_MODEL_space`
  (the recogniser and the transform); `ceil.high_plate_hides_the_ceiling`;
  `ceil.plan_plate_walls_still_shown` (if this fails the plan plate lost its context);
  `ceil.none_over_booth_1_and_says_so` and the whole earlier `walls.*` block (a room with
  no ceiling must be unchanged).
- On Benton's model the AUTO-SET log should carry, after `walls:`, either
  `ceiling: 1 over the booth -- Room Ceiling (z 96 to 100 in); hidden on 03-high and
  06-plan` or `ceiling: none over the booth -- looked for ... ; N flat, broad group(s)
  seen but none qualifies: ...`, and `hides ceiling ...` under 03-high and 06-plan.

## Assumptions

- A ceiling is at most 12 in thick as a bare shape, 24 in with a hint. A hung ceiling
  deeper than that with no name is not recognised — and the log lists nothing for it,
  since it is not flat by the rule. Tunable in one place each (`CEIL_MAX_T`,
  `CEIL_HINT_MAX_T`).
- A booth is told by `WR_ProposalPackage.booth_name?` when loaded (it always is under
  AUTO-SET), else `/\bMDL\b/`, plus any `WR-Booth-*` tag. A hand-named booth container
  with neither is walked, and its tray, if flat and broad, would be listed and — being
  exactly over its own centre and at its own top — hidden on 03-high. `ceiling_geometry`
  additionally drops anything whose top-level container IS the booth being shot, so this
  only bites a booth nested one level down inside something else.
- The WALLS column in the proposal-package dialog counts wall units and does not show
  ceilings; the log and the saved page do. Not changed — that file is off-limits.
- A top-level hand-made ceiling group is also an OBJECT row in the pickers (key
  `o:n:<name>`); the two keys flag the same entity and cannot disagree after an apply.
- `Sketchup::Group#bounds` is in the parent's space and `parent * child` composes
  outward — the same two assumptions as the 1.58.0 wall fix; `ceil.box_is_in_MODEL_space`
  fails if either is wrong.

## Open-questions

1. Should `01-angled` / `03-high` hide a ceiling that is LOWER than the high eye but the
   camera is still under? Left alone as instructed — only 03-high and 06-plan.
2. A room ceiling that is a bare face at top level (no group) is not a container and is
   not found; the log will say "nothing flat and broad in the model at all". Grouping it
   is the fix; nothing here does it.
3. `06-plan` hiding the ceiling was the coordinator's call, made so I was not blocked;
   Benton has not said it. One edit to reverse.
