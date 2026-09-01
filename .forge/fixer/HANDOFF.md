# Fixer HANDOFF — review-lane defects routed 31 Aug 2026 (1.12.6)

## Produced
- `scripts/takeoff-check.py` — (P1) patch staleness now judged at
  `DISPLAY_TOL` (0.05"+eps, half of arch()'s 0.1" display quantum) instead
  of `TOL`; every value the sheet ever showed is patchable, a real change of
  one sixteenth still refuses. New selftest case pins it. (P2) the review
  sheet's page script no longer carries a third grammar copy —
  `dialog_grammar_js()` extracts `parseLen`/`arch` verbatim from
  `scripts/build-room.html` at generation time, refusing by name if the
  dialog changes shape.
- `scripts/eval-floorplan.py` — (P3) checker subprocess decoded as UTF-8;
  unmeasured rooms record worst "—" (never 0.00") plus a loud UNMEASURED
  line; `WR_TAKEOFF_CHECK` pin printed and stamped into every ledger row;
  `--json` emits a blob on refusal/score-fail/probe verdicts too;
  `summarize_refusal` survives an empty log.
- `scripts/wr_tools/VERSION` 1.12.5 -> 1.12.6; `DEVLOG.md` entry;
  `reference/takeoff-format.md` + `.forge/scoper/floorplan-intake.md`
  wording updated (grammar-in-two-places is true again; staleness precision
  documented).
- Repros with READMEs: `.forge/fixer/repro-quarter-inch/`,
  `.forge/fixer/repro-unmeasured/`.
- `eval/RESULTS.md`: 17 new rows, full suite re-run live post-change; all
  verdicts match the 20:05 sweep.

## Read-first
- `DEVLOG.md` 1.12.6 entry — the full account.
- `.forge/fixer/repro-quarter-inch/README.md` — the P1 mechanism in two
  commands.

## Assumptions
- observed: every fix reproduced failing first, then passing (P1 end-to-end
  with a generated sheet's own `data-old`; P3's unmeasured-room case through
  the live bridge with the committed pre-fix scorer, then the fixed one).
- observed: generated sheet's embedded grammar passes all 25 parity vectors
  under Node; page script `node --check` clean; `--selftest` 0 failures.
- observed: model restored — groups after cleanup exactly the pre-work set
  ('', 3190F, 3190G+H, 3190J, adjacent, clean, ell, sliver, units); nothing
  saved. Client images verified gitignored (`git check-ignore` on
  clients/uic-daley-library/plans/*).
- derived: 10 of 15 non-zero sixteenths failed the old TOL check (¼" and ¾"
  included) — recomputed, matches the reviewer's report.
- assumed: no consumer depends on `--json`'s old shape (keys were only
  added, never removed/renamed).

## Open-questions
- `synthetic-headroom` records NO ledger row: still `probe: true`, but
  1.12.3 moved its refusal into `build-takeoff.rb`, and the scorer treats a
  builder-side refusal as a fatal bridge error (exit 1, nothing recorded).
  Pre-existing, not mine to half-land: needs a decision whether
  `expects.refusal` should match builder refusals, then the case flipped
  per its README. Until then the suite silently drops one case from the
  ledger.
- Review-sheet 3D viewer reallocates its WebGL backing store on every
  pointermove — flagged by review, deliberately NOT touched: a performance
  smell in behaviour nobody has ever observed as slow.
- Existing generated sheets (e.g. the UIC review html) predate 1.12.6; they
  work unchanged — the fix is checker-side — so no regeneration was done.
