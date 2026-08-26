# Builder HANDOFF — Bulk Name After Scenes

2026-08-25. Scope: one new script, `scripts/bulk-name-after-scenes.rb`, plus a VERSION bump.
The previous handoff (booth-from-link) is preserved at
`.forge/builder/HANDOFF-booth-from-link.md`.

**The script is UNRUN.** There is no `ruby.exe` on this machine and I cannot drive SketchUp.
Nothing in it has been observed executing against a real model. What HAS been executed is
listed under "Read-first".

---

## Produced

- `scripts/bulk-name-after-scenes.rb` — new. Resolves every gap scene to a proposed
  component, shows a `UI::HtmlDialog` review table, applies only ticked rows inside one
  `model.start_operation`. Panel header: `@title Bulk Name After Scenes...`,
  `@cat Tidy up the model`, `@rank 2` (directly under the single-item tool at rank 1),
  `@icon names-replace`.
- `scripts/wr_tools/VERSION` — `1.6.18` -> `1.6.19`. Required by CLAUDE.md for any change
  under `scripts/`; the update banner is the only signal Gabe gets.
- `.forge/builder/HANDOFF-booth-from-link.md` — copy of the handoff this file replaced.

Not modified: `scripts/save-scene-components.rb`, `scripts/name-selection-after-scene.rb`,
`scripts/wr_tools/main.rb`, `scripts/wr_tools/icon-map.json`. The panel discovers scripts by
scanning the folder, so no registration was needed; the icon is declared inline with `@icon`
rather than by editing the shared map.

Incidental and NOT mine to commit deliberately: `scripts/__pycache__/*.pyc` churn from
running `rbparse.py`. Those `.pyc` files are tracked in git and are not covered by
`.gitignore`. Worth a separate decision.

## Read-first

1. **The resolver is a VERBATIM COPY, not a reference.** `subject_for`,
   `geometry_subject_for`, `view_direction`, `fallback_for`, `ray_box_entry`, `ray_offsets`,
   `top_level_index`, `pick_instance`, `near_misses`, `scene_label`, `AUTONAME`,
   `definition_of`, `definition_name` are copied byte-for-byte out of
   `save-scene-components.rb`, between the two marker comments in the file. `rename_to` and
   `top_level_names` / `top_level?` / `gaps` are copied from
   `name-selection-after-scene.rb`. **Two files now hold one rule and they can drift.**
   The copy was taken because `save-scene-components.rb` ends by calling
   `WR_SaveSceneComponents.run` — `load`ing it to borrow a method would open its export
   dialog. If that ever stops being true, delete the copies and require the file.

2. **Collision policy deliberately differs from the single-item tool.**
   `name-selection-after-scene.rb` ABORTS the whole operation on a taken name. This one
   SKIPS the row, restores it, keeps the rest, and reports the skips. A uniquified `#2`
   name is still refused — only the blast radius changed. The one case that does abort the
   whole batch is a failure to restore a refused rename, because a definition left holding
   a name nobody asked for is worse than doing nothing.

3. **What was actually executed here, and what was not.**
   - `python scripts/rbcheck.py bulk-name-after-scenes.rb` -> `balanced`. (Heuristic only.
     It first reported an unclosed `module`; the cause was a real thing worth fixing — a
     trailing `unless` modifier on a backslash-continued line — and it was rewritten as an
     explicit block.)
   - `python scripts/rbparse.py` -> all 52 `.rb` files parse, mine included. This is a
     genuine parse by SketchUp's own CRuby 3.2.
   - **The pure-logic methods were RUN**, in the same embedded VM, via a harness modelled
     on `scripts/rbtest.py` that lifts the methods verbatim from the file:
     `scene_label`, `tier_of`, `flag_batch_collisions`, `problem?`, `approvable?`,
     `preticked?`, `defn_id`, `to_json_plan`, and the sort key `plan` uses. All behaved as
     designed on a six-row fixture with a duplicate name, a shared part and an unresolved
     row. Harness at
     `%LOCALAPPDATA%\Temp\claude\...\b089a409-...\scratchpad\bulktest.py` (scratch, not in
     the repo — recreate it rather than trusting the path).
   - **The dialog JavaScript was RUN**, headless in Node against a stub DOM: `render`,
     `tally`, the three tick buttons, the collision warning, HTML escaping, the Show link,
     and the Apply-disabled path. `node --check` passes on the extracted script.
   - **NOT executed, and unverified until SketchUp:** every SketchUp API call.
     `model.raytest`, `model.definitions[name]`, `page.camera`, `Pages#selected_page=`,
     `Selection#add`, `Entity#valid?`, `ComponentDefinition#name=`, `start_operation` /
     `commit_operation` / `abort_operation`, `UI::HtmlDialog` construction and callback
     wiring. These were verified by READING the API and by matching the patterns in
     `prefix-scenes.rb` and `name-selection-after-scene.rb`, not by observation.

4. **First run procedure — do it in this order.**
   1. Open the master model. Extensions -> Developer -> Ruby Console.
   2. `load "C:/.../scripts/bulk-name-after-scenes.rb"`.
   3. The table opens and the same table prints to the Console. **Approve nothing.** Press
      Close. Confirm the model is untouched and the Console says
      `NOTHING HAS CHANGED`. That proves the read-only path.
   4. Run it again. Use Show on two or three rows to check the proposed part is the right
      one. Untick everything, tick ONE row you are sure of, Apply. Check the name in the
      Outliner, then Ctrl+Z and check it went back.
   5. Then do the rest. Weak rows are at the top of the table on purpose — look at those
      before ticking them.

## Assumptions

- `Sketchup::DefinitionList#[]` accepts a String name and returns nil when absent. Used for
  the pre-flight collision check. Read from the API docs, not observed.
- `page.name` for a scene never contains a newline, so the console table's column widths
  hold. Untested against the real 25 scenes.
- Only RAY-tier rows arrive pre-ticked, and only when they carry no warning. On this model's
  parallel projections rays reported ~21,500 in lever arms in the exporter's own dry runs, so
  even RAY may deserve a look. If Benton disagrees, `preticked?` is one line.
- The panel picks the script up on Rescan without a reinstall, because this checkout sits at
  a path in `main.rb`'s `CANDIDATES`. Assumed from CLAUDE.md, not confirmed on this machine.

## Open questions

- Should a hand-made collision (two rows ticked that want one name) DISABLE Apply rather
  than being dropped as a group at Apply? Current behaviour warns in the window and drops
  the whole colliding group, keeping every other row. That reading of "do not abort the
  batch for one collision" is mine.
- The verbatim resolver copy is a standing drift risk. Worth a follow-up that splits the
  resolver into a `require`-able file both scripts use.
- `scripts/__pycache__/*.pyc` are tracked and get dirtied by any `rbparse.py` run. Add to
  `.gitignore` and `git rm --cached`?
- Not committed — per the assignment, the orchestrator handles that.
