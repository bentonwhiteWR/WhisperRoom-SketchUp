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

## Status 12:58 — paused for re-exports
- Benton confirmed the three clipped plans are clipped in the source PNGs (case b). He is
  re-exporting `Room2Overview.png`, `Room3Overview.png`, `Room4Overview.png`; on disk they still
  carry 12:12 timestamps. Nothing in the trim/fit logic was changed.
- `Room1.1R render.png` was re-rendered (12:53); plate `02-room1-1-render.jpg` regenerated from
  it. Same composition as before (door + window + desk on one face) — the contradiction with the
  hero / plans / BoothDimensions1.2 for the second Room 1 booth is NOT resolved by it.
- A rebuilt PDF exists ONLY in the scratchpad (`uths-final.pdf`); it still carries the old clipped
  plans. The Desktop PDF (12:38 build) is locked by an open viewer and was not replaced.
- Rebuild is one command once the plans land: regenerate plates 10/13/16 with the flatten+trim
  script, `node build-v2.js source/proposal-v2.json`, print with headless Chrome, append rev 1
  pp.13-17, verify.

## Status 13:12 — FINAL pack shipped
- Benton re-exported all four RoomNOverview.png (13:08). Edge check: every room's own wall now has
  both faces inside the frame; what touches the frame is the neighbouring room's shared wall lines
  (and on Room 4's left, a sliver of Room 3's booth). Plates 06/10/13/16 regenerated.
- Final PDF written to the Desktop (13:10, 6,499,897 bytes, 22 pages), md5-identical to
  scratchpad `uths-final.pdf`. Full PyMuPDF pass: all pages, all bottom edges, four plan pages.
- Still unresolved / unruled: second Room 1 booth face contradiction; 7272 manifest groups;
  Backside clipped top-edge text; cover client name; assembly pages retained.

## Status 13:45 — desk-removal rebuild shipped
- Benton removed the fold-down desk from the product and re-exported 15 of 17 renders. All 17
  plates regenerated from current sources; five captions rewritten desk-free; MJP still on the
  wall in every new render so the MJP assembly pages stay.
- Desktop PDF rewritten 13:43 (6,471,306 bytes, 22 pages), md5 = scratchpad uths-final.pdf.
- STALE / INCONSISTENT for Benton: `Room1.1R render.png` (12:53) still shows a desk;
  `TopDownOverview.png` (12:12) still draws desks on all five booths; the new
  `BoothDimensionsBackside.png` (13:24) still carries a desk on the Room 2 booth.
- Dimension callouts unchanged from the previous transcription on all five BoothDimensions plates.

## Status 14:02 — final build on the full re-exported set
- `BoothDimensionsBackside.png` renamed to `BacksideDimensions.png` (13:53); config + plate 09 follow.
- Desk sweep: gone from `Room1.1R render.png` (13:58), `TopDownOverview.png` (13:56) and
  `BacksideDimensions.png` (13:53). MJP present on every booth render → MJP assembly pages stay.
- Room 1.1 face contradiction PERSISTS: hero (13:28) + both plans (13:56) show the first Room 1
  booth's window/MJP on the face adjoining the door; `Room1.1R` (13:58) and `BoothDimensions1.1`
  (13:27) show door + window + MJP on one face. Captions make no face claim.
- Plan edge profiles identical to 13:08/13:27 sets (own walls inside frame). Callouts unchanged.
- Desktop PDF rewritten 14:01 (6,468,694 bytes, 22 pages), md5 = scratchpad uths-final.pdf.
