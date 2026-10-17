STATUS: READY a970dd2

# Handoff: ISL MDL 7296 E booth-renderings proposal (Builder, 16 Oct 2026)

Not committed. The brief said "no commits there", and this repo is public. The file names the client;
if `.forge/` is ever committed, check this file first.

## Produced
- PDF: `C:\Users\bento\Desktop\ProposalFiles\Intelligence Security Laboratories\Intelligence Security Laboratories-Booth-Renderings.pdf`
  - 1,896,356 bytes (1.81 MiB), 6 pages, all US Letter 612x792 pt.
  - sha256 167479ac6a49140469a58cea46a9e599de60fdd0d32223aec5ab1e56f91457d6.
  - The folder did not exist before this run. It was created and nothing was overwritten. (observed)
- Private repo `bentonwhiteWR/whisperroom-proposals`, branch master:
  - Commit a970dd2 contains `examples/intelligence-security-laboratories-7296/proposal-v2.json` and `renders-web/01..06`.
  - Pushed 35e00ad..a970dd2, no force. (observed)
- Scratch files: HTML `isl-7296-b.html`, check rasters in `proposal-build\check\`, and the first build's rasters in `check-v1-band-clipped\`. They sit under
  `C:\Users\bento\AppData\Local\Temp\claude\C--Users-bento-OneDrive-Documents-Claude-Sketchup\47b4fc77-8497-4d66-a33e-21f7b4f51148\scratchpad\proposal-build\`.

## GOAL "Done means": evidence
1. **Built with build-v2.js, at the agreed path, nothing overwritten.** Done, apart from the size. The PDF is 1.81 MiB, under the 2.5-3.6 MB band. The playbook says "Under is fine" and nothing was inflated.
2. **Hero and slot order.** The hero is plate 01 (01-angled r). The order is hero → dimensioned view (plate 06, the 03-high image) → front view (plate 04) → ventilation side (plate 07) → second door (plate 08) → plan (plate 09).
   - The front view is an added slot between the dimensioned view and the side. It is the only straight-on view of the main door, and the earlier ISL pack had the same slot. Drop it for a 5-page pack if that is wanted.
3. **Room-unknown statement.** It appears on the cover (card 2 and the callout), in "ROOM NOT MEASURED" on every content-page header, in the section lead, in the side caption (the assumed entry door), in the plan caption and in the closing band.
4. **Caption rules.** Text was extracted and searched for left, right, STC, soundproof, $, price, lead time, freight, ship, approximate, V2 and deliver. Every term had 0 hits. Acoustics are left out because the boilerplate has no ASTM E336 figure. Every callout was checked at 300-400 dpi.
5. **Every page checked.** All 6 pages were viewed. Footers on p1-p5 sit at an identical 36.0 pt from the page bottom. The p6 closing band ends at 790.5 pt, which is the designed 0.02 in sheet gap.
   - The first build clipped the closing band by 19.5 pt: its 4-line body overflowed `H_BAND`. Shortening the body fixed it.
6. **Client files in the private repo only.** The JSON and renders-web are only in the private repo. Nothing was written to the public repo apart from this file.
7. **Not done; left for the caller.** Publish the review artifact and email it to Benton. That step is outside the Builder's brief.

## Read-first
- The final client-facing wording is in the private JSON (a970dd2).
- The plan of record is `.forge/GOAL.md`.
- The export warnings are in `Z:/Sketchup/Proposals/Intelligence Security Laboratories MDL 7296 E EXP 2ft/claude-prompt.txt`.

## Assumptions
- **Slug (assumed).** The new slug is `intelligence-security-laboratories-7296`. `examples/intelligence-security-laboratories/` already holds the 6060 E pack.
- **Hero camera drift (derived).** The 01-angled r preflight reported drift (eye 276.0 in, target 101.5 in, up 82.5 deg). Plates 01 and 02 frame identically, so the render used the saved scene. I treated the drift as harmless.
- **Date.** "October 2026".
- **Addressee.** The pack is addressed to the organisation, with no individual named.

## Open-questions
- **8'-0" ceiling and ~85" clearance.** Both are left out of the PDF: neither figure is on any plate. Should either be added to the callout?
- **Plate 10 (interior).** Left out because its framing is cropped and it shows 4 of 7 foam sheets. Add it once the model is finished?
- **Model vs quote.** The model has 4 room fixtures + 2 booth lights, 4 of 7 foam sheets and no cable passages. The quote has 2 x 18in LED lights, 5 foam sheets and 4 cable passages. The PDF claims none of these, but the model differs from the quote.
- **Omitted callouts.** Three callouts are left out:
  - "7' 5/16" on plate 08: the label is clipped and has no closing inch mark.
  - "3'" on plate 04: illegible.
  - The tick-only lines on plate 06.
- **Peoplesspace config (observation only).** `proposals/examples/peoplesspace/proposal-v2.json` is in this public repo.
- **Generator limitation.** `build-v2.js` budgets a fixed `H_BAND` (126 px), which fits about a 2-line closing body. Longer bodies clip whenever the last plate is height-limited, and the peoplesspace (456 chars) and bohn (396) configs may have been affected. Not changed here.
