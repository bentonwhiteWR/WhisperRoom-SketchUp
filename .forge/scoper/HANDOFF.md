# Handoff — Scoper, floor-plan intake pipeline + eval loop

2026-08-31. **No production code written; SketchUp not running, nothing executed live.**
Read-only outside `.forge/scoper/` except the archival rename noted below. Prior mission's
handoff preserved as `.forge/scoper/HANDOFF-light-rig.md`.

## Produced

| File | What |
|---|---|
| `.forge/scoper/floorplan-intake.md` | **The spec.** Take-off-file intake (every value `{v, src}`, chains carry their parts, closure + parts-sum enforced by a standalone checker, ASSUMED propagated into the model), the multi-room builder, the dialog-defect fixes, vector-PDF fast path, documented DWG path, and the two-tier inch-scored eval loop with the S609-3 job captured as the real fixture. Nine ordered steps, slice line after step 6, 17 acceptance criteria. |
| `.forge/scoper/takeoff-review.mockup.html` | **The UI, viewable.** The check sheet `takeoff-check.py --html` would emit, in `build-room.html`'s own style tokens, populated with the real 3190F/G+H/J job — including what a failure looks like (3190J blocked by name) and the ASSUMED inventory as the loudest block. Open it in a browser. |
| `.forge/scoper/HANDOFF.md` | this |

## Read-first

1. `.forge/scoper/floorplan-intake.md` — Approach first (the file-not-dialog decision and
   the honest time table), then Open Questions.
2. `.forge/scoper/takeoff-review.mockup.html` — what Gabe would actually look at.
3. `.forge/researcher/floorplan-pipeline-diagnosis.md` — the diagnosis this builds on.

## Assumptions

- **assumed:** Gabe will accept reviewing a generated check sheet instead of typing —
  nobody has asked him; Q1 is the gate.
- **observed:** `IMG_7594.jpeg` — I read the photo myself; the 17'3"-between-heaters
  chain, bulkhead note, 38" doors with no positions, and 8'8"/8'9" ceilings are as the
  Researcher reported. **reported:** the 3190J/3190F pen readings (IMG_7595/6 not
  re-read) and the PDF-vector numbers (probe not re-run) — so the mockup's J and F
  panels, including J's 8'10"-vs-8'1" validation-failure demo, are illustrative of the
  UI, not a verified transcription of those two photos.
- **reported:** bridge behavior (drove build-room end to end, `DEVLOG.md:1203`) and
  PyMuPDF 1.28.2 present — headers read, nothing executed. Pillow availability for the
  photo-warp nicety is **unverified** and the spec treats it as optional.
- **assumed:** the concurrent Builder's files (`scripts/proposal-package.rb`,
  `scripts/check-doc-paths.py`) stay disjoint from this spec's files — they do by
  design; nothing here touches them.

## Open-questions — approval gates for Benton (none pre-approved; full text in the spec)

- **Q1 — the decision.** Approve the take-off-file shape (agent transcribes → Gabe
  reviews the check sheet → one click builds all rooms), dialog demoted to quick
  rectangles? Recommend **yes** — the mockup is what he'd be approving.
- **Q2.** Unmeasured door position: build with a loud ASSUMED flag rather than refuse?
  Recommend **build flagged**; refuse only when `at` is absent with no explicit assumption.
- **Q3.** Pen beats print — model G+H as one room with the bulkhead? Recommend **yes**.
- **Q4.** Defer scripted DWG (ODA + ezdxf); standardize on the vector-PDF route?
  Recommend **defer**.
- **Q5.** Commit client truth/take-off *numbers* (never images) to this public repo,
  per the `notes.md` precedent? Recommend **yes**, but it is his confidentiality call.
