# Fixer handoff — WR-Dims tag ownership, proposal plate tags, rename dots

## Produced
- `scripts/auto-dimension.rb` — ownership is now exact membership of a new
  `OWN_TAGS` constant (`WR-Dims`, `WR-Dims-Doors`), not a `start_with?('WR-Dims')`
  prefix test. New `own_tag?` predicate and `other_wr_dims` counter. The one
  remaining `start_with?` is the counter, which never erases anything.
- `scripts/proposal-scenes.rb` — `DIM_TAGS` now lists all four WhisperRoom
  dimension tags; a new `SHOWN_ON_DIMENSIONED` says which of them plate
  `02-dimensioned` actually shows (room dims and door dims only).
- `scripts/wr_tools/main.rb` — `rename` reads `meta_of(path)[4]`, the dialog
  flag, instead of testing the already-stripped title for `...`.
- `.forge/fixer/repro-tag-ownership.py` — runnable proof of the tag defect.
- `.forge/fixer/repro-rename-dots.py` — runnable proof of the rename defect.

## Read-first
- `.forge/auditor/script-audit.md` and `.forge/auditor-panel/panel-audit.md` —
  the findings these fixes come from.
- `scripts/dimension-booth.rb` header (around line 64) — it states the
  separate-tags intent that the prefix test was violating.

## Assumptions
- No Ruby interpreter exists outside SketchUp on this machine, so **nothing here
  was run in SketchUp**. Both defects are pure predicate logic and were proved in
  Python against the real tag names; `scripts/rbcheck.py` is a balance check, not
  a parser, so a Ruby syntax slip is still theoretically possible.
- Hiding `WR-Dims-Booth` on all five proposal plates is a deliberate
  conservative call, not a settled decision. See below.

## Open questions
- **For Benton:** should booth catalogue dimensions (`WR-Dims-Booth`) appear on
  proposal plate `02-dimensioned`? They are currently hidden on all five plates.
  Showing them is a one-word change to `SHOWN_ON_DIMENSIONED` in
  `scripts/proposal-scenes.rb`.
- No `DEVLOG.md` entry was written: other agents were editing the tree
  concurrently and the assignment scoped this fixer to three files.
