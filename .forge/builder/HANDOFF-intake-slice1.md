# Builder HANDOFF — per-scene whole-wall hiding (2026-08-31)

Benton's ask, verbatim in the assignment: hide an ENTIRE wall per scene in
the proposal package, walls "grouped in 'walls - Shown' / 'walls - hidden'",
picked per scene, restored on the next scene. Built as approved. Plugin at
**1.12.0**. Prior handoff preserved at
`.forge/builder/HANDOFF-floorplan-intake.md`.

## Produced

| file | what |
|---|---|
| `scripts/wr-scene-walls.rb` | The picker. Two columns per Benton — Shown / Hidden in the CURRENT scene — one chip per whole wall (all pieces of a run: bands, header, opening, leaf, swing). Apply sets entity hidden flags and saves ONLY hidden state into the scene (`page.update(PAGE_USE_HIDDEN_OBJECTS \| PAGE_USE_HIDDEN_GEOMETRY)` — camera untouched, verified). Frame-change observer reloads the lists when a scene tab is clicked. Selection fallback buttons for unnamed geometry. Names scenes that don't save hidden objects, with a one-click fix. |
| `scripts/wr-name-walls.rb` | Retrofit: names unnamed wall solids "Wall 1..N" so the picker lists hand-built rooms. Recognition copied from wr-lower-walls (leaf, vertical extrusion, tag rules) plus a proportion rule (taller than its thinnest plan dimension) so an untagged floor slab is never named a wall. Names only — no geometry, no re-parenting. Dry run by default, per wr-split-walls precedent. |
| `scripts/proposal-package.rb` | Manifest image rows now carry `groups_hidden`: group paths hidden when that row's scene exported, read live right after the scene switch, in both lanes. Field-note added; `null` = not recorded, `[]` = nothing hidden. |
| `scripts/rbtest-proposal.py` | mr5: groups_hidden pass-through. Suite 100% green. |
| `scripts/wr_tools/VERSION` | 1.11.0 -> **1.12.0**. |
| `DEVLOG.md` | 1.12.0 entry. |

## Read-first

1. `scripts/wr-scene-walls.rb` header — the mechanism (scenes save
   per-entity hidden state, nested included) and why the two groups are
   dialog columns, not container groups (scenes do not save parentage).
2. `DEVLOG.md` 1.12.0 — what was proven live vs not.

## Assumptions

- **observed (live, SketchUp 2026 via bridge, this session):** nested wall
  groups' hidden flags round-trip through scene selection both directions;
  `page.update(384)` leaves the page camera alone; a real headless
  proposal batch exported scene 01 with two walls of 3190J hidden and
  wrote their 10 piece paths into that row's `groups_hidden` while scene
  02 wrote `[]`; the control batch after unhiding differed only in that
  room's pixels (diff bbox confined to the room cluster) and wrote `[]`;
  picker inventory/apply, retrofit scan+name, dialog HTML boot
  (`sketchup.ready` fired), observer teardown on close.
- **assumed:** SketchUp versions older than 2020 fall back to
  `PAGE_USE_HIDDEN` (16) — the constant guard is written but only 2026 was
  exercised.
- **derived:** existing scenes save hidden objects by default
  (`use_hidden_objects?` true on both eval scenes); the warning banner +
  fix path for scenes with it off is written but was never triggered by a
  real off scene.

## Open-questions / not live-proven

1. **Nobody has clicked the picker.** The dialog loads and its JS runs
   (verified), but chip-moving, Apply from the mouse, and the fix-pages
   button need one human pass.
2. **Render lane with hidden walls.** The image lane is pixel-proven; the
   render lane records `groups_hidden` from the same scene switch, but no
   V-Ray render with hidden walls has been run.
3. **The headless-batch modal.** Driving proposal-package.rb via the bridge
   leaves finish's summary `UI.messagebox` open on screen (its timer runs
   after the bridge job's modal muzzle is gone). I dismissed two by
   WM_CLOSE via PowerShell. A human-driven batch is unaffected. If a
   future agent drives a batch headless, keep a messagebox stub alive for
   the batch's whole life, not just the submitting job.
4. Scratch model left clean: nothing hidden on either scene, marks back to
   skip, probe geometry erased, stray rename reverted. The eval scorer was
   rebuilding rooms concurrently throughout; entity counts are its.
