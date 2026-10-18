# GOAL

## Mission
Booth-from-link places the four STANDARD (outer-shell) corner seam seals turned 180 deg from
correct, since Benton edited `CornerSeamSeal.skp` and `CornerSeamSeal_HX.skp` on the share
(P:/Z: `Sketchup\NewMasterComponentList`, both saved 18 Oct 2026 12:07). Make every standard
corner seal load the right way round on every booth, robustly against future edits to the part.

## Done means
1. Root cause stated with evidence: why Benton's edit changed the placed orientation.
2. Standard corner seals (`CornerSeamSeal`, `CornerSeamSeal_HX`) land correctly on all four
   corners, Standard and Enhanced/IEP outer shells, HX and non-HX.
3. IEP inner corners (`ENH CornerSeamSeal`) and mid-wall seals unchanged.
4. `scripts/rbparse.py` clean, `scripts/wr_tools/VERSION` bumped, DEVLOG entry, committed and pushed.
5. Anything that only a live SketchUp build can confirm is listed for Benton as a short check.

## Now
Fixer root-causing and fixing the flip (18 Oct).

## Out of scope
Editing the .skp parts on the share. Other parts' orientation. Proposals, renders, client models.

## History
- 16 Oct: ISL 7296 E proposal PDF built, READY a970dd2, waiting on Benton's review (two calls on the map).
- 12 Oct: Walsh Construction Tech Lab MDL 96168 E DONE, proposal PDF on the Desktop. See DEVLOG.
