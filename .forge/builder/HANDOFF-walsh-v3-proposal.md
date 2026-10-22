STATUS: READY

# Walsh Construction Tech Lab, Rev 3: booth-renderings proposal (v2 build, Package 2 images)

## Produced
- PDF: `C:\Users\bento\Desktop\ProposalFiles\Walsh Construction\Walsh Construction-Booth-Renderings-v2.pdf`. 6 pages, US Letter portrait, 1.98 MB.
- The first PDF, `Walsh Construction-Booth-Renderings.pdf`, is obsolete because it was built from washed-out exports. It is still in the folder, untouched.
- Config, updated in place: `C:\Users\bento\Documents\Claude\WhisperRoom Proposals\examples\walsh-construction-rev3\proposal-v2.json`. Not committed. A copy of the first-build config is in the scratchpad as `proposal-v2.first-build.json`.
- Images: `...\walsh-construction-rev3\renders-web-v2\` (01–06). The old `renders-web\` folder is kept.
- Source: `Z:\Sketchup\Proposals\Walsh Construction Tech Lab MDL 96168 S - Corner RM - Package 2\`. The images were used as they are. The plates are opaque, so no flattening was needed. The technical plates were trimmed to content plus a 2% pad, and the two V-Ray renders were not trimmed.
- Page list:
  1. Cover: hero, `1_… 01-angled r.png` (V-Ray)
  2. Image 01, Door End: `3_… 02-front r.png` (V-Ray, extra page)
  3. Image 02, Dimensioned View: `6_… 03-high.png`
  4. Image 03, Side Elevation: `7_… 04-side.png`
  5. Image 04, Rear View & Ventilation: `8_… 05-ventilation.png`
  6. Image 05, Top-Down Plan: `9_… 06-plan.png`, plus the closing band
- Verified: every page was rasterized with PyMuPDF and inspected, plus stacked bottom-edge crops and a 300 dpi crop of page 6's address.
  - The hero appears only on the cover.
  - Footers are intact on pages 1–5.
  - Page 6 ends in the closing band with both address lines visible. It is tight: the plate has 1 px free.
  - No headline wraps and nothing overflows.

## Read-first
- The package's `manifest.json` and `claude-prompt.txt`.
  - The preflight says **4 items sit outside the room**. I have not raised these with Benton and nothing in the captions describes them.
  - The manifest's annotation list only covers the old `Walsh Old Dims 12 Oct` tag. The WR-Dims callouts are not listed, so every caption figure was transcribed from 2–4× zoomed crops of the plates.
- Walls hidden by design, per the manifest's `groups_hidden` for the RM room:
  - Side view: RM walls 1 and 5.
  - Ventilation view: RM wall 1.
  - Hero, front render, high view and plan: none (the plan hides only the ceiling).
  - The captions follow this.

## Assumptions
- Booth facts are as reported by Benton: MDL 96168 S, Roof Mount ventilation, Wide Access door, elevated floor, no ADA.
  - These are stated only in the cover callout and the booth card.
  - The Wide Access door and the elevated floor are not identifiable on the renders, so no image caption describes them.
  - S versus E cannot be checked, because no plate has a height callout. The 14' 2" × 8' 2" callouts match the catalog 96168 exterior.
- Room dimensions are estimated and the ceiling is assumed at 8' 0". The pack says both must be confirmed on site.
  - The plan's 32' chain closes: 19' 11" + 8' 2" + 3' 11".
- Per the coordinator, the captions do not mention the ceiling or wall colour, the foam colour, or the acoustic package.

## Open-questions
1. Ceiling height and room dimensions need confirming on site.
2. The preflight found 4 items outside the room. Confirm none of them is visible in a plate.
3. The renders show a pinkish ceiling and blue foam, while the client ordered gray foam and onyx Audimute. Benton said to build with these images as they are. Re-render later?
4. The Door End page (front render) is optional and the composition is close to the hero's. Drop it if Benton wants the standard 5 pages; set "In this pack" back to 5 images.
5. The booth card sub-line reads only "Roof Mount ventilation". Add "Wide Access door"?
6. The hidden wrong booth on tag `Walsh RM swapped N 21 Oct` should still be cleaned out of the model.
