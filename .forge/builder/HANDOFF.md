# HANDOFF — Builder → Benton: create an annotation set from the dialog, 1.20.1

2026-09-10. Follow-up to 1.20.0. Benton: *"We added the dims annotations being
able to be hidden. I'd like for there to be a way to add an annotation set from
here."* Shipped, **unrun in SketchUp** — see Open questions.

## Produced

**Changed — `scripts/wr-scene-annotations.rb` only**
- `WR_SceneAnnotations.create_set(model, user_name)` — new class method,
  directly above the `apply` section and next to `move_selection_to_set`.
  Same `[ok, message]` convention, same `start_operation` /
  `commit_operation` / `abort_operation`-on-exception wrapper. Reads NO
  selection. Names via `WR_ProposalScenes.annot_set_name` (the one existing
  rule); empty/unnormalisable name refused by name; an existing tag is a
  `[true, …]` no-op saying so; otherwise `model.layers.add(name)` and the
  message names the REAL tag, which is usually `WR-Notes-<slug>` and not what
  was typed.
- `newset` action callback in `self.open`, wired exactly like `move`:
  `create_set` → `push_state` → `status`, unconditionally.
- `self.html` — a second full-width block inside the existing `#move` strip:
  label *"Create an empty set — no selection needed"*, the `WR-Notes-` prefix
  hint, `#cnew` (always visible, via the strip's existing `input.show` rule)
  and a `CREATE SET` button `#cgo`. Enter in the field clicks the button.
  One new CSS rule, `#move .lbl.two { margin-top: 10px; }` — spacing only, no
  new colour value.

**Changed — housekeeping**
- `scripts/wr_tools/VERSION` → **1.20.1**. Patch, not minor: this is one
  additive control inside an existing tool, no new tool, no change to the
  hide/show mechanism or to anything `proposal-package.rb` calls.
- `DEVLOG.md` — entry for 1.20.1 at the top.

## Read first
- `scripts/wr-scene-annotations.rb` header (lines 1–56) — why the tool is a
  hybrid, and why sets must stay inside the `WR-Dims*` / `WR-Notes*` family.
- `WR_ProposalScenes.annot_set_name` in `scripts/proposal-scenes.rb` (~line 92)
  — the single naming rule. Do not add a second one.

## Assumptions
- **assumed**: a freshly `model.layers.add`-ed tag is `visible?` → true, so
  `inventory` reports `hidden: false` and the row lands unticked. Derived from
  the code path, not observed in SketchUp.
- **derived**: the new set appears as a row on the next `push_state` because
  `inventory` builds a set row for every family tag present in
  `model.layers`, members or not (read at lines 219–251).
- **observed**: `python scripts/rbparse.py` → 68/68 files parse. That is a
  CRuby 3.2 syntax check and nothing more; it proves no behaviour.

## Open questions
- **Not run in SketchUp.** No `ruby.exe` here and no bridge to the SketchUp
  window. To verify, in Extensions → Developer → Ruby Console:
  `load "<repo>/scripts/wr-scene-annotations.rb"`, then
  1. type `Plan` in **Create an empty set** → **CREATE SET**. Expect status
     `Created WR-Notes-Plan — empty for now…`, a `WR-Notes-Plan` row under
     **Annotation sets** reading `empty`, unticked, and present in the move
     dropdown.
  2. **CREATE SET** on the same name again → "already exists … nothing was
     changed", list unchanged.
  3. Empty field → **CREATE SET** → "Type a name for the set first."
  4. Regression: the old **New set… + MOVE SELECTION INTO SET** path still
     moves a selection and still refuses an empty one.
- Should a just-created set be pre-selected in the move dropdown? Left alone
  deliberately — `push_state` rebuilds the strip, and guessing the next action
  was not part of the ask.
