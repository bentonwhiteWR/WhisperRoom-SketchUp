# Builder HANDOFF — floor-plan intake step 8: adversarial eval set + the loop ran (2026-08-31)

Goal reconfirmed against `.forge/GOAL.md` before writing this: Done-means 2
and 4 (eval set materially enlarged, iteration measured and recorded).
Spec: `.forge/scoper/floorplan-intake.md` step 8 / §B4, AC-15/16. Prior
slice's handoff preserved at `.forge/builder/HANDOFF-intake-slice1.md`;
the proposal-manifest one at `HANDOFF-proposal-manifest.md`. Plugin at
**1.12.1**.

Everything here ran LIVE (SketchUp 2026, bridge listening): 35 dated rows
now in `eval/RESULTS.md` across four timestamps — the loop, not one batch.

## Produced

| file | what |
|---|---|
| `eval/gen-plans.py` | Case generator. Truth authored FIRST as exact inches; takeoff fixture, truth.json, vector `input/plan.pdf` + warped `input/photo.png` all derived from it. Deterministic (JSON + PNG byte-identical; PDF differs only in its clock-salted trailer /ID). `--list` for the roster. |
| `eval/floorplans/synthetic-{nonclosing,missing,cornerdoor}/` | Refusal cases — pass = checker refuses BY NAME; a FAIL row later means a refusal was silently un-fixed. |
| `eval/floorplans/synthetic-{nasty,jog,units,clearwidth,sliver}/` | Tier-1 exact-build cases (L-room + parts chain + heaters + bulkhead + two ceilings; jogged wall; unit-format torture incl. unicode primes and 8.833' dust; clear-width chain done right; door 0.03" off the corner — probe promoted after it survived). All 0.00". |
| `eval/floorplans/synthetic-clearwidth-trap/` | 31-Aug-shaped: clear width transcribed as wall width, no chain — validates CLEAN, builds 24.00" wrong; pass = the SCORER catches it. Do not "fix" its takeoff. |
| `eval/floorplans/synthetic-unflagged/` | Right number, fabricated `pen` src; 0.00" geometry, fails on provenance (missing ASSUMED note). Do not "fix". |
| `eval/floorplans/synthetic-{selfcross,headroom}/` | Probes that found defects F1–F3 (see below); READMEs carry the live verdicts and the flip-to-refusal instruction for when the checks land. |
| `eval/floorplans/synthetic-nasty-t2/` | Tier-2 harness: scores `../synthetic-nasty/takeoff-t2.json`, a BLIND transcription of the generated photo (see Assumptions). |
| `scripts/eval-floorplan.py` | Now understands `expects.refusal` (named-refusal = pass), `expects.score_fail` (planted defect must be detected), `probe`; records ledger rows for refusals too; `WR_TAKEOFF_CHECK` env pins a checker path; extra-feature check; worst-vertex default no longer 99". |
| `eval/RESULTS.md` | Verdict legend + Findings F1–F4 + 30 new dated rows. |
| `scripts/wr_tools/VERSION` | 1.12.0 -> **1.12.1** (eval-floorplan.py changed). |
| `DEVLOG.md` | 1.12.1 entry. |

## Read-first

1. `eval/RESULTS.md` — the findings block, then the rows: 18:45 (prior
   slice) → 19:59 (adversarial sweep, checker pinned) → 20:03–20:04
   (sliver promoted; tier-2 blind run) → 20:05 (full suite against the
   fixed working-tree checker).
2. `eval/floorplans/synthetic-clearwidth-trap/README.md` and
   `synthetic-selfcross/README.md` — why deliberately wrong fixtures are
   committed and what each verdict means.
3. `eval/gen-plans.py` header — the truth-first rule and the case taxonomy.

## Defects found, NOT fixed here (owned by concurrent lanes)

- **F1** `scripts/takeoff-check.py`: a closed-but-self-touching polygon
  (runs sum to zero, walk revisits a vertex) validates; SketchUp builds a
  pinched two-lobe floor face silently. Wants a self-intersection check.
  Repro: `python scripts/eval-floorplan.py synthetic-selfcross`.
- **F2** `scripts/build-takeoff.rb` ~317: bulkhead head ≥ ceiling →
  massing silently dropped (`return if z1 - z0 <= TOL`). Should refuse by
  name (checker is the right place).
- **F3** door h > ceiling builds the leaf through the ceiling plane,
  silently. Repro for both: `... synthetic-headroom`.
- **F4** (resolved mid-session): working-tree takeoff-check.py crashed on
  import for a while (unescaped `%` in its CSS, in-flight edit); scored
  against the committed checker via `WR_TAKEOFF_CHECK` until the fix
  landed, then re-ran the whole suite unpinned — identical behavior.
- When F1–F3 get fixed, flip `synthetic-selfcross` / `synthetic-headroom`
  from `probe` to `expects.refusal` in `eval/gen-plans.py` and regenerate.

## Assumptions

- **observed:** every ledger row 19:59 onward — I ran them through the
  live bridge; model cleaned after (only `3190G+H, 3190J, 3190F, clean`
  room groups remain, verified by read-back).
- **observed:** tier-2 was genuinely blind — a fresh subagent got ONLY
  `eval/floorplans/synthetic-nasty/input/photo.png` and
  `reference/takeoff-format.md`, with explicit instructions to read
  nothing else, start each room top-left walking E (clockwise), doors
  `at` = distance from the run's start corner, never invent (record
  `{"assumed":…}` instead). Result: 0.00" everywhere, zero assumptions.
  One run, one case — a sample, not a distribution.
- **derived:** the 24.00" trap error and 0.004" units-case dust match the
  authored arithmetic exactly.
- **assumed:** PDF plan drawings are legible enough for humans; verified
  by eye on `synthetic-nasty` only (label collisions were fixed there).

## Open-questions

1. F1–F3 fixes + flipping the two probe cases (checker/build-takeoff
   Builders' lanes).
2. Spec steps 7 (panel "Build from take-off…" button) and 9 (protocol
   docs, `reference/floorplan-intake.md`, scale-estimation pointer, skill
   update) remain unbuilt — unchanged from the prior handoff.
3. Tier-2 coverage is one case; s609-3190gh's fresh-transcription half of
   AC-16 (from the REAL photos by an agent that hasn't seen the fixture)
   is still open — the harness pattern (`case.json` pointing at a
   `takeoff-t2.json`) now exists to copy.
4. `scripts/takeoff-check.py` was still working-tree-modified by its
   owner when this shipped; my commit does not stage it.
