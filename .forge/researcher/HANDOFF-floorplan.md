# HANDOFF — floor-plan pipeline diagnosis (researcher, 2026-08-31)

## Produced

- `.forge/researcher/floorplan-pipeline-diagnosis.md` — full findings: what the 31 Aug
  artifacts are, proof the S609-3 vector PDF is proportionally exact (~1–2" recoverable
  with one pen anchor), the complete trace of the two existing photo→SketchUp paths,
  five ranked failure points, and eval-set feasibility.
- Scratchpad probes (not in repo): PDF vector extraction + renders in the session
  scratchpad (`pdfprobe.py`, `S609-3-p0.png`, `S609-3-3190block.png`). Nothing in
  `Downloads` or repo source was modified.

## Read-first

1. `.forge/researcher/floorplan-pipeline-diagnosis.md` §3 — the ranked failure points.
   Headline: #1 no intake automation at all (abandonment driver); #2 pen-chain
   interpretation, not pixel scaling (wrong-numbers driver — the 17'3"-between-heaters
   trap is the worked example); #3 the door rows' silently invented `at:36"` / hardcoded
   `door_h:80` placements, plus the corner-door leaf-without-opening inconsistency
   (`build-room.rb:254–257` vs `:405–410`).
2. §1.3–1.4 — the DWG/PDF answer: AC1032 DWG, pure-vector PDF, SketchUp 2024/2026 both
   have `dwgimporter.dll`, PyMuPDF present, nothing headless converts DWG, and none of
   it was reachable from the pipeline.
3. §4 — the eval loop is buildable today: PyMuPDF authors synthetic truth plans;
   `scripts/sketchup-bridge.py` + `scripts/wr_tools/wr_bridge.rb` already drove
   build-room end to end and can read back floor-face vertices, door jambs, ceiling.

## Assumptions

- assumed: Gabe used the `Draw floor plan` dialog path (Path A) on 31 Aug — nothing
  records his session (no `clients/` folder, no DEVLOG entry, no model file seen).
  The #2 vs #3 split for that job is a hypothesis; the mechanisms are observed in code.
- assumed: the DWG's model-space geometry matches the plotted PDF (the PDF is its plot);
  verified only via the PDF vectors.
- reported: SketchUp not running / bridge stale — taken from the orchestrator; no
  bridge job was attempted.

## Open-questions

- What did Gabe actually type / does his abandoned model file exist? Ten minutes of his
  recollection settles the #2/#3 split.
- Door placement rule: the photos give door widths but no positions — should the intake
  protocol require "door off its wall corner" as a mandatory field measurement, and
  should the dialog refuse (or loudly flag) a defaulted `at`?
- Scoper: whether the eval set's mainline case is "photo of marked-up printout with
  stated dimensions" (per Benton's steer it must be) with the vector-PDF/DWG fast path
  as a secondary case.
- Whether to install ODA File Converter + `ezdxf` for a scripted DWG path, or standardize
  on the vector-PDF (PyMuPDF) route that needs no install.
