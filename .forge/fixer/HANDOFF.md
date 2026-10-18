STATUS: READY 95ba408

# Fixer handoff: Standard corner seam seals loading flipped (18 Oct 2026, 1.84.4)

## Produced
- `scripts/build-booth-components.rb`
  - `corner_yaw` now reads the L's plan centre of mass from the new `plan_mass`: face loops projected to plan,
    area-weighted, holes subtracted. It keeps the turn that puts that mass FURTHEST from the booth's middle,
    which leaves the elbow at the outside corner.
  - It used to aim the edge-endpoint mean NEAREST the middle.
  - Comments are updated at the IEP orientation block and the corner block.
  - Inner `ENH CornerSeamSeal` placement, mid-wall seals and `place()` are untouched.
- `scripts/rbtest-corner-seal.py`: new regression test. It covers 128 cases on the real plain, chamfered, share
  and share-HX outlines and carries a built-in mutant check.
- `scripts/wr_tools/VERSION` goes from 1.84.3 to 1.84.4. `DEVLOG.md` has a 1.84.4 entry on top.
- `.forge/fixer/corner-seam-seal-flip-notes.md`: evidence, timeline, numbers and the before/after per corner.
- `.forge/fixer/corner-seam-seal-flip/`: the C-SDK probe tools and `replay-before-after.txt`. The part
  geometry JSON is not committed.
- `.forge/GOAL.md` (the orchestrator's mission file) is committed as it was given.

## Read-first
- `.forge/fixer/corner-seam-seal-flip-notes.md`
- `scripts/build-booth-components.rb`, `corner_yaw` / `plan_mass` (~l.2287–2379)
- `.forge/fixer/corner-seam-seal-flip/replay-before-after.txt`

## Assumptions
- place() hands `corner_yaw` a box centred on the corner polygon. This was observed in the 12:02 build and in
  the Walsh/ISL builds; place() itself was not re-run offline.
- `Face#loops`, `Loop#outer?` and `Loop#vertices` behave as documented in the SketchUp Ruby API. They are
  stubbed offline.
- Elbow-out is correct. Three sources agree: the reference doc, Benton's screenshot complaint, and the shipped
  Walsh/ISL models.

## Open-questions
- Not built live: there is no bridge and no SketchUp was driven. Benton's 1-minute check, in an Untitled
  model:
  1. Build a Standard booth from a link (e.g. 4872 S) and an Enhanced or HX one.
  2. On all four outer corners the chamfered elbow should be at the booth's outside corner, with the legs and
     the 1x1 block against the panels.
  3. The inner ENH corners should be unchanged.
- Optional for Benton:
  - His 12:07 re-axe of the two parts no longer matters; keep it or revert it.
  - The chamfer cuts left stray 0.07 sq in floor triangles on the bottom face: one on `CornerSeamSeal`, three
    on `_HX`. They are harmless, and he may want to delete them.
- The mid-wall seals were re-exported at 12:07 with their frame unchanged. They were not re-checked live and
  are out of scope.
