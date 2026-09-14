# HANDOFF — Builder: Wyatt Shepherd booth-renderings proposal (14 Sep 2026)

History: earlier today the Suites 128 & 114 take-off was built live and the quoted MDL 4872 S
was placed in all three rooms (commits e0056ce, 9d5e7a1). The detail is in
`clients/suites-128-114/notes.md` and in git history for this file. The AUTO-SET handoff is
still at `.forge/builder/HANDOFF-autoset.md`.

## Produced
- **PDF:** `C:\Users\bento\Desktop\ProposalFiles\Wyatt Shepherd\Wyatt Shepherd-Booth-Renderings.pdf`.
  New folder, nothing overwritten. 10 pages, 2,961,480 bytes (2.96 MB).
- **Config:** `WhisperRoom Proposals\examples\wyatt-shepherd\proposal-v2.json`.
- **Web plates:** `WhisperRoom Proposals\examples\wyatt-shepherd\renders-web\` (10 JPEGs).
- **The private repo was not committed** (as briefed). Its `assembly/` and `warranty/` folders
  were not touched.
- **Scratch:** HTML, image-prep script and check rasters are in
  `scratchpad\wyatt\` and `scratchpad\wyatt\check\` (p01–p10.png, bottoms.png, callout-zoom.png).
- No change to anything under `scripts/` or `proposals/`, so no VERSION bump and no public-repo commit.

## Structure
- Cover: hero is plate 01 (the RM 114 V-Ray render), not trimmed.
- Section 01, "Option 1 · RM 114", marked "Recommended layout": plates 03, 04, 05, 06.
- Section 02, "Option 2 · RM 128", marked "Alternate layout": plates 07, 09, 10, 11, 12.
- The generator carries two options without new CSS:
  - `model` = "Option N · RM nnn", which becomes the section title and header line 2;
  - `boothOf` = "MDL 4872 S", so header line 1 reads "BOOTH MDL 4872 S".
  - The header's hard-coded "Booth" prefix can't be removed from config, which is why
    `boothOf` holds the model rather than "1 of 2".
- **Dropped plates:**
  - Plate 02 uses the same camera as the hero and would have sat on page 2.
  - Plate 08 uses the same camera as plate 07, which is on the page just before it.
  - Each option still has three or more dimensioned views without them.

## Verified (observed)
- The generator's fit table has no overflow; page 10 is `free 0px`.
- PyMuPDF check:
  - 10 pages, all 612×792.
  - I looked at every page and at a stacked crop of all ten bottom edges.
  - The footer is present on pages 1–9, and page 10 ends in the closing band.
  - No wrapped headline pushes the footer.
  - The generator sizes every plate from its real pixel ratio, so nothing is stretched.
- Callouts were read at native 1600 px, and the small RM 128 ones were zoomed 4×. The RM 128
  room runs match manifest `measured` values (9' 3", 4' 8 1/2", 8' 6 1/2", 7' 6 1/4", 13' 3").

## Open for Benton
- **Wording of the RM 128 note, which is invented:**
  "Layout note: RM 128 is a tight room for this booth, and in this position the booth
  window would not be easily accessible."
- **Section labels, which are invented:** "Recommended layout" / "Alternate layout".
- **Cut-off callouts left in the plates as exported and left out of the captions:** a
  partial "10…" at the edge of plate 05, a partial "…/2"" on plate 09, "…8 1/2"" behind
  the room door leaf on plate 08 (plate not used), and "4' 8 1/2" with no inch mark on
  plate 12. The last one is transcribed, because plates 09 and 10 and the manifest all
  show 4' 8 1/2".
- **Preflight "11 items outside the room":** no stray or unidentified geometry is visible
  in any of the 12 plates. The cause was not found from the images.
- **Hero dead space:** the hero has a lot of grey render background. It was left
  untrimmed per playbook §5.
- **Grey box at the booth base, window side, with a round opening:** not captioned. It
  may be part of the ventilation or EFS, but I can't identify it from the images.
