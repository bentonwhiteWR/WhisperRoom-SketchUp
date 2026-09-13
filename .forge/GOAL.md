# GOAL

## Mission
Company A client proposal, built from the saved SketchUp file and improved
through ranked iterations. **Delivered 12 Sep; awaiting Benton's decisions.**

## Result
- Images: 9 plates + 3 V-Ray renders in `Z:\Sketchup\Proposals\Company A\`,
  hand-off in `HANDOFF.md` there.
- PDFs: `C:\Users\bento\Desktop\ProposalFiles\Company A\Company A-Booth-Renderings-v0..v4.pdf`.
- Rank: baseline 5.6 -> v4 6.8. Independent cold grade on v4 **6.8**, per-dim
  gap <= 1 (no drift). Target 8 NOT met. Loop stopped after 4 of 5 iterations:
  every remaining gain needs SketchUp work, a new image, or a Benton decision.
- Review page: Company A Proposal Review artifact.

## Now — decisions only Benton can make
1. Allow the proposal to name WhisperRoom's own products (model, ventilation)
   from the quote/model, cross-checked against renders. The pinned rubric
   accepts only render-readable facts, which is stricter than CLAUDE.md.
2. Which way the booth door opens, so its swing can be drawn on the plan.
3. Approve SketchUp work: height/footprint callouts ending on the booth and
   labelled; back-wall and plan re-exported at 2400 px+.

## Known defects carried forward
- AUTO-SET should switch off rig emitters over the booth when it hides the
  ceiling (03-high r blowout); a per-export override was used instead.
- Company A.skp is modified in memory (tag hides, side/plan cameras), unsaved.
- Deferred: interior-plan scene (file-naming question open).

## History
- Plugin 1.69.0 pushed, remote == local. Door frame is the front reference.
- Lighting settled at 8.2 (i02 floor); holds at 8.0 on the 4872 layout.
- Sub-agents run on opus.
