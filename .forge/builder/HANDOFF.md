# Builder HANDOFF — blind-transcription trial (2026-08-31)

Goal reconfirmed against `.forge/GOAL.md` before writing this: Done-means 2/4
(the eval loop exercised on the step that actually failed — transcription —
not just on fixtures). Prior handoff preserved at
`.forge/builder/HANDOFF-step8-adversarial.md`. Nothing under `scripts/`
changed; VERSION stays 1.12.7.

## Produced

| file | what |
|---|---|
| `eval/gen-plans.py` | `--blind <seed>` / `--blind2 <seed>`: randomised blind cases, truth-first from a seeded RNG, phone-photo plan derived (keystone, uneven light, JPEG loss), NO takeoff fixture emitted. `draw_blind` supports per-run label omission, chain labels, pen ticks, heater boxes, dashed removed-partition lines, corner→jamb door dims. |
| `eval/floorplans/blind-{a-office,b-annex,c-storage,d-workshop,e-studio}/` | Round 1, seed 831 — rectangle, L+neighbour (ceilings differ), clear-width chain, jog with a MISSING door position, removed-partition pair. |
| `eval/floorplans/blind-{f-mech,g-lounge}/` | Round 2, seed 407 — silent clear-width trap (no total anywhere) and a pen chain wrong by 2" on the plan (expects.refusal 'not close'). |
| each case's `takeoff.json` | Written by an ISOLATED transcriber (photo + the two protocol docs only). **Do not "fix" them** — what they got wrong is the trial's data. |
| `eval/RESULTS.md` | New clearly-labelled section: method, verdict, caveats, doc defects D1–D5, 7 rows. Not to be averaged with fixture rows. |
| `DEVLOG.md` | Trial entry. |
| `.forge/builder/blind-score.sh` | copy transcription into case dir + score `--record` (scratch). |

## Read-first
1. `eval/RESULTS.md` — the "Blind-transcription trial" section, especially D1–D5.
2. `eval/floorplans/blind-f-mech/README.md` and `blind-g-lounge/README.md`.

## Assumptions
- **observed:** all 7 rows scored live through the bridge (SketchUp 2026);
  model cleaned after — the seven trial groups erased by name, read-back
  showed no top-level groups left.
- **observed:** transcribers were genuinely isolated — fresh sub-agents,
  scratchpad copies of photo + docs, repo forbidden; their reports and the
  audited takeoffs show zero invented values, chains recorded with parts.
- **derived:** round 1 alone was not hard enough (closure cross-checks in
  4/5 plans); round 2's f/g are the real silent-risk cases. Stated in the
  ledger, not hidden.
- **assumed:** Fable-class agents on fully-legible synthetic plans are an
  upper bound on operator care; a smudged photo or rushed human can still
  reproduce 31 Aug. The trial measures the protocol, not human fallibility.

## Open-questions
1. D1–D5 doc defects → protocol-doc lane (spec step 9): define `at`'s
   corner + run winding in `reference/takeoff-format.md`, allow `parts` on
   assumed values (checker change), enum assumed-escape, closure-derived
   provenance ruling.
2. `synthetic-headroom` still records no ledger row (builder-side refusal
   scored as fatal bridge error). Orchestrator ruling: refusal-is-refusal =
   PASS. Not fixed here (didn't block; owned by scorer's lane).
3. A future FAIL on `blind-g-lounge` means silent client-arithmetic
   "fixing" crept in — treat as a 31 Aug regression.
