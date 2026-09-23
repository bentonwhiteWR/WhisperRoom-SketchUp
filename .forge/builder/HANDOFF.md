# HANDOFF — Builder: PeoplesSpace proposal Revision 4, final build (23 Sep 2026)

The previous handoff (Draw floor plan redesign 1.72.0) is in git history for this file;
that work stays parked (see `.forge/builder/HANDOFF-build-room.md` and GOAL history).

## Produced
- FINAL: `C:\Users\bento\AppData\Local\Temp\claude\C--Users-bento-Documents-Claude-Sketchup\5407c711-ae55-4f08-8dcd-036379b44b84\scratchpad\ps-rev4\PeoplesSpace-Booth-Renderings-Rev4.pdf`
  (13 pages, US Letter portrait, 3,777,003 bytes, built 17:11 from the 17:07-17:09 re-export).
  The orchestrator still has to move the 16:59 draft at
  `C:/Users/bento/Desktop/ProposalFiles/PeoplesSpace/PeoplesSpace-Booth-Renderings-Rev4.pdf` aside and put
  this file in its place. The builder did not touch the Desktop copy in the final pass.
- `proposals/examples/peoplesspace/proposal-v2.json`: final Rev4 content. NOT committed.
  The JPEGs it names (`renders-web/*.jpg`) exist only in the scratchpad `ps-rev4/renders-web/`,
  because client renders stay out of this public repo.
- Scratchpad `ps-rev4/`: `flat/` holds all 13 plates re-flattened from the re-export; the first build's
  plates are in `flat-v1/` and `renders-web-v1/`. Also `mkcfg.py`, which generates the config, `ps-rev4.html`,
  and the final check rasters in `check2/`.

## Read-first
- The builder's final report for this task, covering invented lines, dimensions and plate problems.
- `Z:/Sketchup/Proposals/PeoplesSpace MDL 96120 E ADA RM VSS WDO RAISED FLOOR AP MJP HEPA/manifest.json`
  (rewritten 17:09). It has image rows only for the 10 re-exported plates; 01, 06 and 11 have no row.

## Assumptions
- The four light tan pads on the vent boxes in plates 05 and 13 are the HEPA filters. This is derived, not
  labelled on the drawing. The cover's statement that they fit within the height of the existing roof units
  is reported by the orchestrator, not measured from a render.
- In the re-export only 08 and 09 changed visibly. 02, 05, 07 and 13 differ by less than 40/255 per pixel
  (encoder noise). 01, 03, 04, 06, 10, 11 and 12 are pixel-identical to the first build's plates.

## Open-questions
1. Per the orchestrator, the Option 2 booth has no MJP and no HEPA. The cover callout lists the MJP and HEPA as
   revision additions without saying they belong to Option 1 only. It is unchanged, as instructed, but a
   reader could take them to apply to both options.
2. The screen-anchored note on plates 02 and 12 reads "Interior Dimensions: 7'5".5" x 11'5.5" x 6'5.5"". That
   interior is impossible inside a 10' 2" exterior, and its "8'1 15/16"" disagrees with the 8' 1 5/16" callout,
   whose geometry measures ~8' 2 13/16". Rev3 shipped the same note. The fix belongs in the model.
3. On plate 04 the Cable Passage Plugs leader ends on an Audimute panel. Does a panel cover the plug?
4. Plate 13 has a stray leader stub in the middle of the plan. On plate 03 the cable-passage note is half hidden.
