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
**Diagnosis is done. Both Researchers reported 31 Aug; findings are in
`.forge/researcher/floorplan-pipeline-diagnosis.md` and
`.forge/researcher/proposal-image-step-timing.md`.** The two root causes:

- **Floor plans.** There is no intake pipeline — only a hand-typed take-off dialog or a
  bespoke Ruby script per client. The accuracy failure is **pen-chain interpretation**, not
  scaling: the stated field measurements form chains that close arithmetically
  (`17'3" + 10" + 10" = 18'11"`, exactly) but nothing checks that they close, and reading
  `17'3"` as the room width rather than the clear width between the heaters is ~8 ft wrong.
  Separately the dialog **silently invents door placements** (`at:36"`, `door_h:80"`),
  violating the never-invent rule exactly where it matters. And `S609-3.pdf` is a **pure
  vector PDF** that reproduces the field measurements to ~1–2 in from one anchor — the exact
  geometry was in the job folder and nothing pointed at it.
- **Proposal speed.** The ~45 min went into procedure-mandated work, chiefly the agent
  reading off pixels what the model already holds as text: `scripts/proposal-package.rb`
  exports bare PNGs and discards scene names, order, and callout strings.

**In flight (three lanes, all on Fable):**
1. Builder — manifest + dimension sidecar at export time, and `scripts/check-doc-paths.py`.
2. Scoper — the intake pipeline and the eval loop, spec to `.forge/scoper/floorplan-intake.md`.
3. (Folded into 2, not a separate lane) the invented-placement and corner-door defects in
   `scripts/build-room.rb` / `.html` — specced now, built after Benton approves.

**Blocked on Benton:** SketchUp is not running (bridge heartbeat ~18 h stale, no process —
observed 31 Aug). Nothing can be verified live until it is open with the bridge enabled.
**Open question for Gabe:** what he actually typed on 31 Aug is recorded nowhere, so the
split between misread-chain and invented-placement for that specific job is a hypothesis.

## The review sheet — requirements Benton set, 31 Aug 2026
The take-off review sheet is published as an Artifact and reviewed before anything runs.
Benton: *"the mockups are very good for review before we just send them to scripts."*

1. **Reviewable, not just viewable.** Approve / needs-changes per room, editable values, and
   a **copy box emitting a structured patch** — room, field, old, new, source — that
   `takeoff-check.py` consumes directly. Not prose: re-interpreting prose is the
   transcription step that caused this mission.
2. **Every edit carries measured-vs-assumed.** Changing a number is a measurement claim. An
   edit with no source is the same defect as the dialog's `at:36"`.
3. **Booth overlay.** The sheet takes a booth **three ways — a pasted booth-builder link, a
   typed model number, or a catalog picker** — and draws the top-down inside the room outline
   at the take-off's own scale, with door-swing arc and the 1" wall gap. Reuse
   `WhisperRoomQuote\assets\layout-render.js` (`renderLayoutSvg`); do not reinvent it, and do
   not embed the PNG top-down art.
   - **The artifact sandbox blocks all outbound requests.** `#d=<base64>` links decode
     in-page with no network (as `scripts/booth-from-link.rb` documents); `?d=<short id>`
     needs `GET /api/booth-design/<id>` resolved at publish time and the payload embedded.
   - **Benton or Gabe names the model; the tool never does.** A typed model or a picked one
     is the model being specified and is fine. What is forbidden is pre-selecting, defaulting,
     or ranking a "best fit" — drawing a small booth implies it is the largest that fits.
   - **No prices on the page** (`models.json` prices are internal and the link gets
     forwarded). The embedded catalog is a snapshot — stamp the version it was built from.
4. Mark plainly on the page which data is verified and which is illustrative.

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
