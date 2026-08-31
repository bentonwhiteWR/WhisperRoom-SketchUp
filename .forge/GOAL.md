# GOAL

## Mission
Make the **floor-plan intake pipeline** trustworthy and fast. Two failures, reported by
Benton on 31 Aug 2026, drive this:

1. **Accuracy.** Client floor plans (phone photos of marked-up printouts, PDFs, and
   sometimes a real DWG) turn into inaccurate SketchUp rooms. On the 31 Aug job Gabe ran
   the drawing through the pipeline, it "just didn't turn out well," and he built all of
   it by hand instead. A pipeline a draftsman abandons mid-job is worse than no pipeline.
2. **Speed.** Assembling the images into a proposal took ~45 minutes of agent time for
   what Gabe describes as "just grab all the images and put it in the proposal."

The fix is not a guess at either. It is a **measurable loop**: sample floor plans with
known ground-truth dimensions, run the builder, check the built room against truth inside
SketchUp, score it, fix the largest error, repeat.

## Done means
1. **A named root cause for the 31 Aug failure**, sourced from the actual artifacts
   (`C:\Users\bento\Downloads\IMG_7594-6.jpeg`, `S609-3.dwg`, `S609-3.pdf`) — not a
   plausible story. If the DWG carries exact geometry, then "scale off a photo" was never
   the right path for this job and that is the finding.
2. **A floor-plan eval set**: sample plans whose true dimensions are known exactly, so a
   built room can be scored rather than eyeballed. Ground truth comes from synthesised
   plans (we set the numbers) and from `S609-3.dwg`/`.pdf` if it proves readable.
3. **An automated scorer** that reports per-room error in inches against ground truth,
   driven through the existing bridge (`scripts/sketchup-bridge.py`), so a change can be
   shown to help or not.
4. **A measured before/after** on both accuracy and the proposal image step. "It feels
   better" is not a result.
5. **Written protocol** — the intake procedure a human or agent follows — updated to match
   what the loop actually proved, in `reference/` and the `whisperroom-proposal` skill.

## What Benton confirmed, 31 Aug 2026
- **The 31 Aug failure was two things, not one:** the dimensions came out **wrong**, *and*
  the process was **too manual / too slow** — "needed so much hand-holding and setup that
  drawing it by hand was simply faster." It did not crash and the geometry was not
  malformed. Both defects are real and need separate fixes.
- **Typical client input is "usually just photos/PDF."** A real DWG like `S609-3.dwg` is
  the rare bonus, not the norm. The mainline that must get accurate is **phone photo of a
  marked-up printout → correct dimensions**. Any eval set exercises that path first; a
  DWG/vector-PDF fast path is worth having but is not the mainline.
- Note the accuracy-critical step on these particular photos is **transcribing and applying
  stated hand-written measurements**, not estimating scale from pixels. Those are different
  problems with opposite fixes; do not conflate them.

## Now
**Diagnosis, in parallel, before any building.** Two Researchers are out:
- one on the floor-plan pipeline and the 31 Aug artifacts (what exists, where error enters,
  is the DWG readable);
- one on the proposal image-assembly step (where the 45 minutes actually went).

No Scoper or Builder starts until both report. The eval-harness design is a Scoper's job
after that, not a thing to start now.

**Blocked on Benton:** SketchUp is not running (bridge heartbeat ~18 h stale, no process —
observed 31 Aug). Nothing can be verified live until it is open with the bridge enabled.

## Rules that still bind this work
- Plugin edits land under `scripts/wr_tools/`; bump `VERSION`; a restart reloads.
- `WhisperRoomQuote` and the `P:` share are **read only**.
- No silent fallback: a job that cannot run fails **by name**.
- **Never invent a placement number.** Every derived dimension carries number, tolerance,
  and named anchor — the rule already written in `reference/scale-estimation.md`.
- Never run bridge jobs against live client work — scratch models only. Do not write into
  `C:\Users\bento\Desktop\ProposalFiles\`.
- Commit and push every change.

## Out of scope
- Render look development, V-Ray settings, lighting balance. That mission is parked in
  full at `.forge/GOAL-prev-render-lookdev.md` and resumes after this one.
- Booth geometry and the proposal PDF's visual design. This is about getting the room
  right and the images placed quickly, not about restyling the deliverable.

## History
2026-08-31 — Render look-development mission parked to fix floor-plan intake. Full text at
`.forge/GOAL-prev-render-lookdev.md`.
2026-08-30 — Portal-parity / proposal-package mission parked, `.forge/GOAL-prev-portal-vray-mission.md`.
2026-08-27 — Enhanced/IEP two-shell mission parked at 1.6.32, `.forge/GOAL-prev-iep-mission.md`.
