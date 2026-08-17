# Scoper handoff — ceiling seam seals

## Produced

- `C:\Users\bento\Documents\Claude\Sketchup\scripts\probe-seam-seal.rb`
  Cross-sections a ceiling seam seal and a ceiling panel edge on the same Z
  scale, and prints the vertical faces that form any slot. Read-only; loads
  definitions and purges them. **Unrun** — there is no Ruby on this machine
  outside SketchUp. It parses clean under `python scripts\rbparse.py`, which is
  a genuine CRuby 3.2 parse, not a bracket count.
- `C:\Users\bento\Documents\Claude\Sketchup\.forge\scoper\ceiling-seam-seals.md`
  The spec: goal, approach, seven implementation steps, ten acceptance criteria,
  risks, and the one named fork.

## Read first

1. `C:\Users\bento\Documents\Claude\Sketchup\.forge\GOAL.md` — the mission and
   the out-of-scope fence.
2. `C:\Users\bento\Documents\Claude\Sketchup\.forge\scoper\ceiling-seam-seals.md`
   — start at "What is already measured, and what is not".
3. `C:\Users\bento\Documents\Claude\Sketchup\reference\floor-ceiling-geometry.md`
   — the level tables, the two ceiling conventions, and the existing "Seam
   seals" paragraph the spec extends.
4. `C:\Users\bento\Documents\Claude\Sketchup\scripts\wr-deck.rb` — the header
   comments at lines 30 and 56–99 are the standing warning about per-part
   constants, and `deck_extent` at 556 and `contact_z` at 572 are the two
   measured rules the seal path borrows.
5. `P:\Sketchup\NewMasterComponentList\_face-levels.tsv` — the raw probe table
   from 2026-08-14, still present. The seal rows are the observed basis for
   everything derived in the spec.

## Assumptions

- **derived, from five parts:** ceiling seal length is `feet × 12 − 2`, where
  `feet` is the digit in the name and `feet × 12` is the booth's cross dimension.
  Exact on `CL5/6/7/8` and `8.5CL`. The build re-checks it per part and warns.
- **derived:** all five ceiling seals are the same way up, differing only by a
  0.75 in translation — the gap sequence upward from each part's largest-area
  level is identical. Therefore no flip logic in the seal path. The probe's
  cross-check 1 re-tests it.
- **derived:** the crosses with no seal (42, 48) are exactly the crosses whose
  ceilings are a single part, so no joint exists there. Acceptance criterion 6
  tests it on `MDL 4872 S` and `MDL 4230 S`.
- **assumed, not checked:** the seal is centred along the joint on the deck's
  cross span, leaving 1 in clear at each end. Nothing measured says whether the
  reveal is symmetric.
- **assumed, not checked:** the seal is symmetric across the joint and so has no
  handing. The probe measures this directly (cross-check 4).
- **reported, from the 2026-08-14 table rather than re-measured today:** every
  seal dimension and level quoted in the spec.

## Open questions

1. **`SEAL_Z` — blocking, and only the probe can answer it.** Which Z in the
   seal's own coordinates lands on which Z in the ceiling panel's. The spec
   leaves the constant `nil` and the pass refuses to place while it is nil, so
   the Builder can implement and test everything else first. The probe prints the
   question in the form the answer is needed in.
2. **The Yes/No fork, for Benton.** Do seals ride on the existing "Floor and
   ceiling: Yes/No" control, or get their own? The spec recommends riding on it
   and argues the cost of changing later is one inputbox row and one boolean.
   Not blocking — the Builder can proceed on the recommendation.
3. **Not blocking, worth asking:** floor seals map `feet × 12` while ceiling
   seals map `feet × 12 − 2`. That two-inch difference is real and unexplained.
   It is out of scope here but it is the kind of asymmetry that gets assumed away
   later.
