# Floor-plan eval ledger

One dated row per scored run, appended by `python scripts/eval-floorplan.py
<case> --record`. This is the measured before/after the mission asks for: a
change to the intake pipeline ships with its row, or it does not ship.

The first row is the baseline — the 31 Aug 2026 failure reproduced
(`s609-3190gh-baseline`: 17'3" misread as the room width, invented door
positions, house-default ceiling) and scored against the same PDF-derived
truth as the fixed case. Worst vertex error is the width misread.

Row verdicts: `PASS` on a refusal case means the checker refused BY NAME —
that row is regression protection for a refusal, and it going FAIL means the
refusal was silently un-fixed. `PASS` on a planted-defect case
(`*-trap`, `*-unflagged`) means the SCORER caught a defect the checker
validated clean. `PROBE` is a case run before anyone knew the right answer;
its README carries the verdict.

## Findings — adversarial batch, 31 Aug 2026 (synthetic case sweep)

The `synthetic-*` cases from `eval/gen-plans.py` surfaced these. **None are
fixed here** — F1–F3 live in files owned by other in-flight Builders and are
recorded so they cannot be lost; the reproducing case pins each one.

- **F1 — pinched polygon builds silently** (`synthetic-selfcross`). Seven
  runs that sum to zero but revisit a vertex validate, build, and produce a
  single 7-vertex two-lobe floor face with no message. Fix belongs in
  `scripts/takeoff-check.py` (self-intersection check on the walked
  polygon). The exact silent-wrong-geometry class of 31 Aug.
  **FIXED, 1.12.4** — `polygon_self_touch` in `takeoff-check.py` refuses
  revisited corners, doubling-back runs and crossing non-adjacent runs by
  name after closure; the case is flipped to
  `expects: {"refusal": [...]}` and the ledger row above records the PASS.
- **F2 — impossible bulkhead silently dropped** (`synthetic-headroom`).
  Bulkhead head 9'0" above an 8'0" ceiling: `scripts/build-takeoff.rb`
  `build_feature` hits `return if ... z1 - z0 <= TOL` (~line 317) and the
  massing never exists — no refusal, no note. Only the scorer's
  feature-missing check catches it.
- **F3 — door taller than its ceiling builds through it**
  (`synthetic-headroom`). An 8'6" leaf in an 8'0" room builds 6" through
  the ceiling plane, silently. Should refuse by name in the checker.
- **F4 — working-tree `scripts/takeoff-check.py` crashed on every
  invocation** during this sweep (module-level `TypeError: not enough
  arguments for format string` in its CSS block — an unescaped `%` in an
  uncommitted edit by the concurrent Builder). The 19:59 rows were scored
  against the last committed checker (cc12b62), pinned via the scorer's new
  `WR_TAKEOFF_CHECK` override. **RESOLVED mid-session**: the concurrent
  Builder's fix landed in the working tree and the 20:04–20:05 rows —
  the whole suite re-run unpinned — behave identically against it.
- Measured residual risk, by design: `synthetic-clearwidth-trap` proves a
  clear-width mis-transcription WITHOUT a recorded chain validates clean and
  builds a room 24.00" wrong — only the scorer sees it. The parts invariant
  protects exactly those who record the chain; the protocol doc must keep
  saying so.

| date | case | verdict | worst vertex err | detail |
|---|---|---|---|---|
| 2026-08-31 18:45 | s609-3190gh-baseline | FAIL | 20.00" | max vertex error 20.00" > 2.00"; ceiling off by 9.00"; door 0 position is assumed in truth but the model carries no "door 0 at ASSUMED" note — an unflagged assumption scores as a failure even when the number is right; door 1 position is assumed in truth but the model carries no "door 1 at ASSUMED" note — an unflagged assumption scores as a failure even when the number is right; feature missing: 2 x heater in truth, 0 built; feature missing: 1 x bulkhead in truth, 0 built |
| 2026-08-31 18:45 | s609-3190gh | PASS | 0.00" | clean |
| 2026-08-31 18:45 | s609-3190j | PASS | 0.00" | clean |
| 2026-08-31 18:45 | s609-3190f | PASS | 0.00" | clean |
| 2026-08-31 18:45 | synthetic-clean | PASS | 0.00" | clean |
| 2026-08-31 19:59 | synthetic-clean | PASS | 0.00" | clean |
| 2026-08-31 19:59 | synthetic-nonclosing | PASS | — | refused by name as designed: runs do not close |
| 2026-08-31 19:59 | synthetic-missing | PASS | — | refused by name as designed: no position on run 0; noceil ceiling |
| 2026-08-31 19:59 | synthetic-cornerdoor | PASS | — | refused by name as designed: touches the corner; overlap |
| 2026-08-31 19:59 | synthetic-nasty | PASS | 0.00" | clean |
| 2026-08-31 19:59 | synthetic-jog | PASS | 0.00" | clean |
| 2026-08-31 19:59 | synthetic-units | PASS | 0.00" | clean |
| 2026-08-31 19:59 | synthetic-clearwidth | PASS | 0.00" | clean |
| 2026-08-31 19:59 | synthetic-clearwidth-trap | PASS | 24.00" | planted defect detected (checker-silent by design): max vertex error 24.00" > 0.10"; feature missing: 2 x heater in truth, 0 built |
| 2026-08-31 19:59 | synthetic-unflagged | PASS | 0.00" | planted defect detected (checker-silent by design): door 0 position is assumed in truth but the model carries no "door 0 at ASSUMED" note — an unflagged assumption scores as a failure even when the number is right |
| 2026-08-31 19:59 | synthetic-selfcross | PROBE | 0.00" | built (probe): clean |
| 2026-08-31 19:59 | synthetic-headroom | PROBE | 0.00" | built (probe): feature missing: 1 x bulkhead in truth, 0 built |
| 2026-08-31 19:59 | synthetic-sliver | PROBE | 0.00" | built (probe): clean |
| 2026-08-31 20:03 | synthetic-sliver | PASS | 0.00" | clean |
| 2026-08-31 20:04 | synthetic-nasty-t2 | PASS | 0.00" | clean |
| 2026-08-31 20:05 | synthetic-clean | PASS | 0.00" | clean |
| 2026-08-31 20:05 | synthetic-nonclosing | PASS | — | refused by name as designed: runs do not close |
| 2026-08-31 20:05 | synthetic-missing | PASS | — | refused by name as designed: no position on run 0; noceil ceiling |
| 2026-08-31 20:05 | synthetic-cornerdoor | PASS | — | refused by name as designed: touches the corner; overlap |
| 2026-08-31 20:05 | synthetic-nasty | PASS | 0.00" | clean |
| 2026-08-31 20:05 | synthetic-jog | PASS | 0.00" | clean |
| 2026-08-31 20:05 | synthetic-units | PASS | 0.00" | clean |
| 2026-08-31 20:05 | synthetic-clearwidth | PASS | 0.00" | clean |
| 2026-08-31 20:05 | synthetic-clearwidth-trap | PASS | 24.00" | planted defect detected (checker-silent by design): max vertex error 24.00" > 0.10"; feature missing: 2 x heater in truth, 0 built |
| 2026-08-31 20:05 | synthetic-unflagged | PASS | 0.00" | planted defect detected (checker-silent by design): door 0 position is assumed in truth but the model carries no "door 0 at ASSUMED" note — an unflagged assumption scores as a failure even when the number is right |
| 2026-08-31 20:05 | synthetic-selfcross | PROBE | 0.00" | built (probe): clean |
| 2026-08-31 20:05 | synthetic-headroom | PROBE | 0.00" | built (probe): feature missing: 1 x bulkhead in truth, 0 built |
| 2026-08-31 20:05 | synthetic-sliver | PASS | 0.00" | clean |
| 2026-08-31 20:13 | synthetic-selfcross | PASS | — | refused by name as designed: revisits the corner; self-touches |
