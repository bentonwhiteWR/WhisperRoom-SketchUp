# HANDOFF — Elangovan 4-booth proposal pack (2026-08-28)

## Produced
- `C:\Users\bento\Desktop\ProposalFiles\Saravanan Elangovan\Saravanan-Elangovan-Booth-Renderings-4-Booth.pdf`
  17 pages: cover + 11 content + 3 MJP + 2 ADA ramp. 5.2 MB. US Letter portrait, rot 0 on every page.
- `...\Saravanan Elangovan\source\proposal-v2-4booth.json` (config; images point at `renders-web-4booth/`)
- `...\Saravanan Elangovan\source\renders-web-4booth\*.jpg` (12 web-ready plates)
- The August 25 pack and its `source/proposal-v2.json` / `source/renders-web` were NOT touched.

## Read-first
- `reference/proposal-playbook.md` is the procedure. `proposals/build-v2.js` is the only generator.
- Page order was specified by Benton and is a deliberate departure from the playbook default
  (render -> dimensioned -> plan, per room). Do not "fix" it.

## Assumptions / judgement calls
- V-Ray RGBA renders: alpha DROPPED (kept the rendered RGB backdrop) rather than composited
  onto white. V-Ray wrote the grey/blue backdrop into RGB with alpha 0; compositing on white
  would have blown the backdrop out. No transparency survives into the pack.
- The two `BoothDimensions*` plates are room-agnostic in their captions even though they sit
  inside the Room 1 / Room 3 sections — nothing in those images identifies a room.
- "ADA ramp", "Multi Jack Panel" are named on Benton's authority + the appended manuals;
  the panel's 4 XLR + 6 round jacks were verified by zooming Room3Render.
- Blue behind the glazing = interior acoustic foam (Benton, mid-task correction). Captioned as
  such; no colour name, product name, thickness or acoustic figure stated.

## Open questions
- No LIVE DESIGN / booth-builder links exist for this job — the previous pack's small-grey link
  styling was carried over in spirit but no URLs were invented. Add them if Benton has them.
- Pages 3, 4, 6, 8, 9, 10, 11 have 170-320 px of white below the caption. That is the
  generator's fixed top-aligned layout meeting 16:9 renders; not a defect, not fixed.
