# HANDOFF — Builder: PeoplesSpace proposal Revision 4 (23 Sep 2026)

The previous handoff (Draw floor plan redesign 1.72.0) is in git history for this file;
that work stays parked (see `.forge/builder/HANDOFF-build-room.md` and GOAL history).

## Produced
- `C:/Users/bento/Desktop/ProposalFiles/PeoplesSpace/PeoplesSpace-Booth-Renderings-Rev4.pdf`:
  13 pages, US Letter portrait, 3.79 MB. Nothing else in that folder was touched.
- `proposals/examples/peoplesspace/proposal-v2.json`: updated to the Rev4 content. It is NOT committed.
  Its `renders-web/*.jpg` names are the Rev4 ones. The JPEGs themselves are only in the scratchpad
  (`...\scratchpad\ps-rev4\renders-web\`), because client renders stay out of this public repo. The repo's
  untracked `renders-web/` folder still holds the older Rev2 images.
- Scratchpad `ps-rev4/`: flattened plates (`flat/`), JPEG q84 (`renders-web/`), `proposal-v2.json`,
  `mkcfg.py` (generates the config), `ps-rev4.html`/`.pdf`, check rasters (`check/`).

## Read-first
- The builder's final report for this task. It lists the invented caption lines, every transcribed
  dimension, and the plate problems.
- `Z:/Sketchup/Proposals/PeoplesSpace MDL 96120 E ADA RM VSS WDO RAISED FLOOR AP MJP HEPA/manifest.json`

## Assumptions
- In plates 05 and 13, the four light tan pads on the vent boxes are the HEPA filters. This is derived:
  they are absent from the Rev3 plate and there are four of them. It is not a label on the drawing.
- The cover callout says the HEPA filters fit within the height of the existing roof units. That comes
  from the orchestrator's report of the live model and is not measured from a render.
- "Acoustic Package" and "Audimute" come from the orchestrator. "Audimute" is not printed on any render.

## Open-questions
1. The Option 2 booth copy (plates 08/09, group "MDL 96120 E (components)R") shows no MJP below its
   window and no white Audimute panels inside, only the blue foam. It looks like that copy was not
   updated. Should it be updated and re-rendered, or is it fine to ship as is? The Option 2 captions
   do not claim the upgrades.
2. The screen-anchored note on plates 02 and 12 reads "Interior Dimensions: 7'5".5" x 11'5.5" x 6'5.5"".
   An 11'5.5" interior is impossible inside a 10' 2" exterior. Its exterior height "8'1 15/16"" also
   disagrees with the 8' 1 5/16" callout, and the geometry of that callout measures ~8' 2 13/16". Rev3
   shipped the same note. The text belongs in the model.
3. On plate 04, the "Cable Passage Plugs" leader now ends on an Audimute panel. Does a panel cover
   the plug?
