# HANDOFF — Broadcaster General Store proposal v2 (built for Gabe)

## Produced
- `C:\Users\bento\Desktop\ProposalFiles\Broadcaster General Store\Broadcaster General Store-Proposal-v2.pdf`
  (9 pages, US Letter portrait, 3.51 MB). Gabe's `Broadcaster General Store-Proposal.pdf` untouched.
- `...\Broadcaster General Store\source\proposal-v2.json` — the generator config (edit + rebuild from here).
- `...\Broadcaster General Store\source\renders-web\00..08-*.jpg` — flattened/trimmed web plates.
- Working files (HTML, PDF, page rasters, zoom crops) in the session scratchpad `bgs\`.

Rebuild: `node proposals/build-v2.js "<source>/proposal-v2.json" <work>/bgs.html`, then headless Chrome
`--print-to-pdf`. Nothing in this repo changed except this file.

## Read-first
- Model names are DERIVED, not printed on any render. Measured off the plan at 2.44 px/in
  (20' and 25' walls agree): ADA booth 10' 2" × 8' 2" body → MDL 96120 E; two booths 8' 2" × 6' 2"
  → MDL 7296 E; one 4' 2" × 6' 2" → MDL 4872 E. Gabe's earlier PDF said 1× 9696 E + 3× 4872 E.
  The 8' 7 1/2" / 6' 7 1/2" callouts are body + 5 1/2" of fan hardware.
- No render carries a ceiling height; Gabe's "10' ceiling" was dropped.
- `topdown clearance for radiator.png`: 1' 5" wall-to-booth, 11 1/2" wall-to-vent hardware, 8' 7 1/2"
  along that wall, plus the drawing's note (typo "sideposition" in the render itself).

## Assumptions
- "Enhanced" / "double-wall" kept from Gabe's boilerplate; 7' 1" callout on the ADA booth matches the
  Enhanced catalog height.
- The 7' 6" callout at the room door is read as the door height (vertical dimension in the angled view).
- The drawing's note was quoted with "sideposition" normalised to "side position".

## Open-questions
1. Confirm the booth models against the quote — the renders disagree with Gabe's earlier pack.
2. Does the client want the ADA booth called out by model on the cover card, or only by footprint?
3. Should the render's own note typo be fixed in SketchUp before this ships?
