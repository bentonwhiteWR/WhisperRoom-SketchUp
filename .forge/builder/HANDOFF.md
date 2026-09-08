# Builder handoff — UTHealthSciences proposal rev 2 (2026-09-08)

## Produced
- `C:\Users\bento\Desktop\ProposalFiles\UTHealthSciences\UTHealthSciences-Booth-Renderings.pdf`
  — 22 pages: cover + 16 plates (generated, `PAGE nn / 17`) + the same 5 assembly-instruction
  pages rev 1 carried (Multi Jack Panel x3, ADA Ramp x2), copied from rev 1's PDF pages 13–17.
  6.2 MB. Rev 1 folder untouched.
- `C:\Users\bento\Desktop\ProposalFiles\UTHealthSciences\source\proposal-v2.json` — the config.
- `C:\Users\bento\Desktop\ProposalFiles\UTHealthSciences\source\renders-web\00..16-*.jpg` —
  flattened / trimmed / q88 JPEGs, ordered as the pack.
- Nothing in this repo changed except this file (client material stays on the Desktop).

## Read-first
- `reference/proposal-playbook.md` is the procedure; `proposals/build-v2.js` the generator.
- Rev 1 config that this descends from:
  `C:\Users\bento\Desktop\ProposalFiles\Saravanan Elangovan\source\proposal-v2-4booth.json`.
- Page order is Benton's (render(s) → dimension views → room top-down LAST; Backside before
  the Room 2 top-down). 1.1 and 1.2 are BOTH Room 1.

## Assumptions
- All five booths captioned as MDL 7296 E, sourced from the top-down plan's own label
  ("All Audiology Premium Enhanced (MDL 7296 E - 6'x8')") and the 8' 2" callout on every booth.
  The manifest also lists an `MDL 7272 S` and an `MDL 7272 E` group; nothing 6'2"-square is
  visible on any render, so they were treated as unplaced model groups. Flagged to Benton.
- Booth footprint captioned as "8' 2" by 7' overall" — the 7' callout spans the ventilation
  boxes on the back of the booth (catalogue body is 6' 2"). Not "along the door wall" — the
  second Room 1 booth has its ramp on the 7' face.
- Assembly pages appended because the section-01 lead and the closing band (both reused
  from rev 1) promise them.

## Open-questions (for Benton)
1. `Room2Overview.png` is clipped at its right edge — the booth body, the 8' 2" chain end,
   the 5' 10 1/2" run and the room's east wall are cut off. Shipped as-is on page 11; a
   re-export from the same scene fixes it.
2. The second Room 1 booth is drawn two ways: `Room1.1R render.png` and `BoothDimensions1.1.png`
   show door + window + desk on one face; the hero, both plans and `BoothDimensions1.2.png`
   show that booth with the door on one face and the window/desk on the adjoining face.
   Captions avoid the claim; the images still disagree with each other.
3. `BoothDimensionsBackside.png` is a 1495x797 screenshot with clipped text at its top edge
   ("ed (MDL 72…", "5/16"", "1/4"). Shipped as Image 09.
4. Client name kept as rev 1's (the individual, with the UTHSC sub-line); folder is
   "UTHealthSciences". Say if the cover should carry the institution instead.
5. Pack is 6.2 MB (rev 1 was 5.3 MB); the plates alone are 4.8 MB, above the 3.6 MB target.
