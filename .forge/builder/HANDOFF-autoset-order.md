# HANDOFF — AUTO-SET plate order + render ladder (1.56.0)

## Produced

- `scripts/wr-autoset.rb` — plates reordered/renumbered (`01-angled`, `02-front`,
  `03-high`, `04-side`, `05-ventilation`, `06-plan`, `07-interior`); a render is an
  extra `"<id> r"` scene inserted immediately before its image, walked down
  `RENDER_LADDER` (= the plate order); zero renders = six images, nothing else;
  interior unchanged (opt-in, last, always a render, never counted). New:
  `base_id`, `render_ids`, `run_ids`, `live_plate?`, `extra_pages`, `auto_named?`,
  `insert_index`, `add_page`, `RENUMBERED`. Gone: `forced_renders`, `renders_for`,
  `:dual`. Summary string, door-nil warning, stale/extra/out-of-order notes reworded.
- `scripts/proposal-package.rb` — popover ladder sentence replaced; render input and
  interior box re-plan the preview through `autosetpick` (now accepts JSON
  `{booth, renders, interior}` or a bare name); rows found via `RENUMBERED` say
  "will be renumbered", not "renamed by hand"; JS default fallback 2 → 1.
- `scripts/rbtest-autoset.py` — 171 → 197 checks, green. Nine mutants killed by name
  (see DEVLOG). Checks changed to the spec: `ld1-ld11`, `fr1-fr7`, `du1-du11`
  (`du2` is render-first now), `cm11/cm11b`, every old id in `ts6 sm* az* an* wp* cm* fm*`.
  New: `or1-or5`, `ld12-ld16`, `fr8`, `du5b du6b du12`, `sm9`, `mg1-mg10`.
- `.forge/builder/verify-autoset.rb` — UNRUN (no SketchUp here). Parses.
- `scripts/wr_tools/VERSION` 1.55.0 → 1.56.0. `DEVLOG.md` entry.

## Read-first

- **Nothing Ruby here has been executed.** `rbparse.py` says all 75 scripts plus the
  harness parse; `rbtest-autoset.py` runs the pure half for real (197 checks). The live
  half — page creation order, `Pages#add(name, flags, index)`, restamping, renaming —
  is proven only by `verify-autoset.rb`, which Benton runs from **File > New**.
- Checks to watch on that run, in order of what they would tell us:
  1. `create.scenes_land_in_plate_order`, `create.the_default_render_is_the_angled_pair`,
     `create.a_default_run_is_DEFAULT_RENDERS_renders` — the new order and pairing on
     real pages.
  2. `zero.six_image_plates_and_nothing_else`, `zero.ZERO_render_rows`,
     `zero.summary_says_0_render` — item 1 of the spec, the defect.
  3. `dual.adjacent_and_render_first`, `dual.set_reads_angled_r_angled_front_r_front_high_side_vent_plan`,
     `dual.front_pair_exists_at_two_renders`, `dual.front_pair_render_first_and_identical_camera`.
  4. `forced.the_interior_is_the_ONLY_render_at_zero`, `forced.interior_is_extra_and_last`,
     `forced.summary_breaks_out_the_interior_as_not_counted`.
  5. `migrate.NO_duplicate_scenes`, `migrate.stamps_now_carry_the_new_ids`,
     `migrate.the_tools_own_names_are_renumbered`, `migrate.a_hand_typed_name_is_kept`,
     `migrate.nothing_called_stale`, `migrate.plan_flags_the_renumber_not_a_hand_rename`
     — the update-over-an-existing-set path. If any of these fails, do not run Update on
     a real model until it is understood.
  6. `update.added_render_sits_before_its_image` — this one alone is allowed to FAIL:
     it tells us whether `Pages#add` honours an index on this build. If it fails,
     `update.out_of_order_is_SAID_when_it_happens` must PASS (the fallback appended and
     the summary said so). Both failing is a bug.
  7. `update.the_left_over_render_is_NAMED_in_the_summary`, `remove.only_this_booths_pages`
     (Remove takes the left-over render too).
  8. Everything else should be unchanged from the 1.55.0 run; `second.*` now expects
     eight pages at 2 renders.
- Real models with 1.53–1.55 sets: **Update** is now meant to renumber in place. It
  cannot reorder the tab bar; the summary says so and names Remove-then-Apply.

## Assumptions

- `Sketchup::Pages#add(name, flags, index)` exists on Benton's build (documented; not
  observed). Guarded by rescue → append + out-of-order note.
- `DEFAULT_RENDERS` stays 1. Under the old ladder that was two renders (forced angled +
  ventilation); now it is one (angled). Nobody asked for a new default.
- Paired render scenes share the image's number (`01-angled r` / `01-angled`) — same
  plate, same shot; the export prefix (table position) keeps the files distinct.
  `dual.no_doubled_render_marker` still holds (`plan_names` unchanged).
- `opts['plates']` override kept in `run_ids` though nothing in the dialog sends it.

## Open-questions

1. Should the interior also get a paired image scene? Spec silent; left as a single render.
2. Is a default of ONE render (angled only) what Benton wants, or should the default
   knob move to 2 (angled + front) so a default run still costs two renders?
3. At a render count lower than the set was made with, the higher render scene is
   left in place and named. Should Update instead offer to erase it?
4. When a migrated 1.55 set is out of tab order, is "reorder in the Scenes tray or
   Remove then Apply" acceptable, or should Update erase-and-recreate the three
   renumbered pages (losing any hand nudge on them) to guarantee order?
