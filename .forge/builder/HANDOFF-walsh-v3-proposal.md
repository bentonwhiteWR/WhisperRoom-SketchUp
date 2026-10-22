STATUS: READY

# Walsh Construction Tech Lab, Rev 3: booth-renderings proposal

## Produced
- PDF: `C:\Users\bento\Desktop\ProposalFiles\Walsh Construction\Walsh Construction-Booth-Renderings.pdf`. 5 pages, US Letter portrait, 863 KB. The folder was new, so nothing was overwritten.
- Config: `C:\Users\bento\Documents\Claude\WhisperRoom Proposals\examples\walsh-construction-rev3\proposal-v2.json` (private proposals repo, not committed)
- Prepped images: `...\walsh-construction-rev3\renders-web\01-hero.jpg` through `05-top-down-plan.jpg`
- Page list:
  1. Cover: hero, plate 11 (01-angled)
  2. Image 01, Dimensioned View: plate 15 (03-high)
  3. Image 02, Side Elevation: plate 16 (04-side)
  4. Image 03, Rear View & Ventilation: plate 17 (05-ventilation)
  5. Image 04, Top-Down Plan: plate 18 (06-plan), plus the closing band
- Plate 13 (02-front) was left out. The hero and plate 15 already show the door end.
- Verified: every page was rasterized with PyMuPDF and inspected, along with crops of every bottom edge. The hero appears only on the cover. No headline wraps and nothing overflows. The footer is intact on pages 1–4, and page 5 ends in the closing band with the address visible.

## Read-first
- `clients/walsh-construction/notes.md` (v3 section)
- The render folder's `manifest.json`. It lists only plates 11 and 18. Its preflight found one floor surface still on 0128_White and 3 items outside the room.

## Assumptions
- MDL 96168 S with Roof Mount ventilation, taken from the brief and the quote link. The renders carry no model label. The 14' 2" × 8' 2" callouts match the catalog 96168 exterior. S versus E cannot be checked, because no plate has a height callout.
- The Wide Access door and the elevated floor are confirmed by Benton but cannot be seen on the renders, so neither is captioned. ADA is not mentioned anywhere. The cable wall is left as the link has it and is not captioned.
- Room dimensions are estimates: 32' and 18' 11" are reported by the architect, and the rest are derived from the take-off. The ceiling is assumed at 8' 0". The pack says both must be confirmed on site.
- Every caption figure is transcribed from a zoomed crop. Callouts that were overstruck or partly hidden are left out of the captions.

## Open-questions
1. Ceiling height and room dimensions need confirming on site.
2. Should the booth card sub-line read "Wide Access door · elevated floor"? Benton confirmed both, but neither is visible on the renders. It currently reads "Roof Mount ventilation".
3. The foam seen through the windows looks blue/purple. The client asked for gray studio foam and onyx Audimute, and the acoustic package is not modelled. The captions make no foam claim.
4. The hero is a plain SketchUp export, not V-Ray, and looks flat. Re-render it before sending?
5. A small stray white triangle sits at floor level by a booth corner in the hero. It may be one of the preflight's "3 items outside room". Fix it in the model and re-export?
6. The model still holds a hidden wrong booth on tag `Walsh RM swapped N 21 Oct`. Delete it before the next export.
