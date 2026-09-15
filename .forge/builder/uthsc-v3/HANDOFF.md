# Builder handoff — UT Health Sciences V3 (mini revision)

## Produced
- `C:\Users\bento\Desktop\ProposalFiles\UTHealthSciences\UTHealthSciences-Booth-RenderingsV3.pdf` — 8 pages, ~1.54 MB (cover card reads "8 renderings"), US Letter portrait.
- `C:\Users\bento\Desktop\ProposalFiles\UTHealthSciences\source-v3\proposal-v2.json` + `renders-web\` (8 flattened/trimmed JPEGs). Client material, not in git.
- Nothing in `ProposalFiles\UTHealthSciences\` was overwritten; V2 pack and `source\` untouched.

## Read-first
- Renders + manifest: `Z:/Sketchup/Proposals/UTHealthSciencesAudiology Premium Enhanced Proposal x5 SMALL BOOTH` (plates 18–26).
- Page order: cover = plate 18 (V-Ray angled); 02 = 20 (V-Ray front); 03 = 21 (front dimensioned); 04 = 22 (high); 05 = 23 (ventilation); 06 = 24 (plan); 07 = 25 (Room 1 two booths); 08 = 26 (Room 1 plan, closing band).
- Plate 19 (plain angled) dropped: same view as the hero, every callout it carries is on 21/22, and its left edge shows stray geometry from another room with garbled dimension text.
- Plate 25 pre-cropped to x<1300 and plate 26 to x>42 to remove neighbouring rooms / another room's door at the frame edges. Other plates trimmed to content bbox + 2 %; the two V-Ray renders untrimmed.

## Assumptions
- Room 1 "lost 4 ft": plates 25/26 draw Room 1 at 19' 11 1/4" × 18' 4 1/4"; V2 drew 22' 4 1/4". The pack says only "Room 1 is now drawn 19' 11 1/4" by 18' 4 1/4"" and never says "4 ft" or which wall moved.
- The smaller room is not named (not "Room 5"); called "the smaller room" throughout.
- Cover sub-line (title/department) and Multi Jack Panel / acoustic-foam wording carried from V2 unchanged.
- Closing body drops V2's sentence about attached assembly instructions (none attached here).

## Open-questions
- Export preflight warnings (white floor on plain plates, 13 items outside walls) are model issues, reported not fixed.
- Source plates are 1600 px wide; trimmed technical plates land at 110–180 dpi on the page. Callouts read fine at 300 dpi rasterisation but a 2400 px export would print sharper.
