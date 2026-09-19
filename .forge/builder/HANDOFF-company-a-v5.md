# HANDOFF — Company A Booth-Renderings v5

## Produced
- `C:\Users\bento\Desktop\ProposalFiles\Company A\Company A-Booth-Renderings-v5.pdf`
  — 7 pages, 612x792 pt (US Letter portrait), 3.04 MB. v0-v4 in that folder untouched.
- `C:\Users\bento\Desktop\ProposalFiles\Company A\.work\v5\proposal-v2.json` — the config,
  copied in shape from `.work\v4\proposal-v2.json` but rewritten line by line for the new
  booth (MDL 96144 S, 10-plate reshoot) rather than edited in place.
- `C:\Users\bento\Desktop\ProposalFiles\Company A\.work\v5\company-a-v5.html` — the built
  HTML (source of the PDF).
- `C:\Users\bento\Desktop\ProposalFiles\Company A\.work\v5\renders-web\` — the 7 prepared
  JPEGs (quality 96, subsampling 0): 01-hero-angled, 02-dimensioned-angled,
  03-front-render, 04-side-dimensioned, 05-rear-ventilation, 06-interior-render,
  07-top-down-plan. Four of these (02, 04, 05, 07) are trimmed to their content bounding
  box + 2% padding from the source PNGs; 01, 03, 06 (the V-Ray renders) are untrimmed.
- `C:\Users\bento\Desktop\ProposalFiles\Company A\.work\v5\pages\page-01.png` … `page-07.png`
  — full-page rasters at 150 dpi, kept for Benton to publish.
- `C:\Users\bento\Desktop\ProposalFiles\Company A\.work\v5\check\bottom-01.png` …
  `bottom-07.png` — bottom-edge crops used for footer verification.

## Read-first
- `.forge/GOAL.md` (this mission) and `reference/proposal-playbook.md` in this repo —
  the full procedure this build followed.
- `Z:\Sketchup\Proposals\Company A\reshoot-03-high-d\manifest.json` and
  `claude-prompt.txt` — the export tool's own record of scene, lane (render vs plain
  image), hidden walls/annotations, and the preflight warning about the white floor.
- `C:\Users\bento\Desktop\ProposalFiles\Company A\.work\v4\proposal-v2.json` — the prior
  pack's config, read for client-level copy conventions (card layout, callout phrasing),
  but built on the OLD booth (MDL 4872 S) and superseded per GOAL.md history.

## Assumptions
- Selected 7 of the 10 available plates for content pages (cover + 6): dropped 04
  (front-dimensioned — its depth callout is truncated mid-frame, confirmed by a zoomed
  crop, so it carries no dimension value a plain image elsewhere states cleanly) and 05/06
  (the high-angle render/drawing pair — same silhouette and same three overall dimensions
  already shown on plates 01/02, its only new content being two illuminated ceiling
  fixtures that aren't a sourceable product feature to caption). This was a curation call,
  not a mandate from the task — the task named the 10-plate pool as the source, not a
  requirement that all 10 become pages.
- Read the dark, faceted trapezoidal shape on the top-down plan (Image 06) as the same
  ramp seen at the door threshold in every elevation — same dark ridged texture, same
  corner position relative to the booth. Not 100% certain against a labeled legend (there
  isn't one), but corroborated across 6 independent images.
- Treated the small illegible placard below the door window (visible on plates 01/03) as
  unreadable rather than a contradiction of "MDL 96144 S" — could not resolve model-number
  text at any zoom level tried.

## Open questions
- Confirm the 3-page reduction from a hypothetically "use all 10 plates" pack down to 7 is
  the outcome Benton wants — if he'd rather see plates 04/05/06 included anyway (e.g. for
  completeness against the reshoot batch), that's a fast re-add: they're already exported,
  just need trim/JPEG prep and two more `sections[0].plates` entries.
- The floor is on drafting white in the SketchUp model (preflight failure per Benton) but
  is not visible in any selected plate at print resolution (grey/tan flooring materials
  cover it in every shot used) — no caption was written about floor finish either way, per
  instruction, but flagging that the defect exists in the source model regardless.
