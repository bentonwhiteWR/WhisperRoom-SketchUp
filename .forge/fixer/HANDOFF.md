# HANDOFF — silent Draft/Render toggle (1.19.12)

## Produced
- `scripts/wr-materials-swap.rb` — `diagnosis(model)`, pure `diagnose_lines(rows)`,
  `diagnose(model)`; `report_lines` now takes an optional `model`.
- `scripts/proposal-package.rb` — `unit_mode` and the `togglemode` callback log the
  diagnosis when the counts hash is empty.
- `scripts/wr-mode.rb` — passes `Sketchup.active_model` into `report_lines`.
- `scripts/rbtest-materials-diagnosis.py` — NEW, 35 checks, passes.
- `scripts/wr_tools/VERSION` 1.19.11 -> 1.19.12; DEVLOG entry.

## Read-first
- `scripts/wr-materials-swap.rb` header "diagnosing a no-op" — why each branch exists.
- `.forge/GOAL.md` — the out-of-scope fence (build-room's materials were verified
  correct and not touched).

## Assumptions
- Benton's zero-match is the "source matches nothing" case, not a swap defect. The
  fix makes the model TELL you which it is rather than asserting one.
- `Sketchup.active_model` is safe to call inside `WR_Mode.report`; it is already
  called a few lines below.

## Open questions
- UNRUN in SketchUp. `diagnosis` needs a real model; only `diagnose_lines` executed.
- Next time Benton toggles, the per-slot line will name the material his walls are
  really on (count 0 tells him the SOURCE is wrong). If a count is NON-zero and the
  fill is present and it still does not move, that is a different bug and worth a look.
