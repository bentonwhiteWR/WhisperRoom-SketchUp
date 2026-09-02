# HANDOFF — take-off review sheet redesign (Scoper, 2026-09-01, plugin 1.19.3)

## Produced

- `.forge/scoper/takeoff-sheet-review.md` — review of today's sheet (W1–W10), the proposed
  direction, changes C1–C21 each marked presentation or data, what stays untouched, a
  six-slice build plan for `scripts/takeoff-check.py`, and questions Q1–Q5 for Benton.
- `.forge/scoper/takeoff-sheet.mockup.html` — the proposed sheet, self-contained (no external
  resources), populated with the real lock data of `eval/floorplans/blind-f-mech` and its
  synthetic photo as a data URI. Working: value edits on list and plan, unit toggle, closure
  warning (under Walls and red on the plan), notes, verdict, patch box with the unchanged
  contract, ticks, "answer these first" jump links, zoom, lightbox, phone photo strip, 3D
  toggle (placeholder, marked ILLUSTRATIVE). Review layer: orange dashed strips §1–§11 with
  Approve / Needs changes + note, and a copy-back box emitting JSON at the bottom.
- `.forge/scoper/takeoff-sheet/` — today's sheet generated two ways (`case/` by the book,
  photo silently missing; `case-img/` with the photo renamed `IMG_photo.png` so it embeds),
  screenshots of today's sheet and the mockup at 1280 px and a true 390 px, and the two
  iframe harnesses used to get a real 390-px layout out of headless Chrome.

## Read-first

1. `.forge/scoper/takeoff-sheet-review.md` §2 (what is wrong) and §4 (the change table).
2. Open `.forge/scoper/takeoff-sheet.mockup.html` in a browser; narrow it under 860 px for
   the phone layout. Edit the north wall to `17'5"` to see the closure behaviour.
3. `scripts/takeoff-check.py` `html_report` (2392–2607), `CSS` (967–1230), `JS` (1230–2105),
   `_svg_room` (859–967), `load_photos` / `room_ledger` (2155–2246) — the pieces the slices
   replace.
4. Audit lane D findings D-4, D-6, D-10 (`.forge/auditor/full-audit-D-takeoff-skills-docs.md`)
   — three of the changes close them.

## Assumptions

- The reviewer is Gabe on a laptop or phone, checking a transcription against a photo; the
  sheet is a working surface, not a report (Benton's framing, reported).
- Headless Chrome's 390-px screenshots of BOTH sheets were taken inside a 390-px iframe
  because desktop Chrome will not lay out a window narrower than ~500 px (derived from the
  first, wider-than-390 renders; the iframe renders are the ones kept).
- The mockup's plan renderer is a JS port of `_svg_room` plus the door dimension, leaf,
  arc, north arrow and wall names; the Builder ports the additions back into Python. The 3D
  viewer is not reimplemented — the generator's own goes behind the toggle unchanged.
- Ticks are page-local and not in the patch (Q2). The patch contract is unchanged.
- `generated`, `checker_version`, `transcribed_by` in the masthead are proposed lock/file
  fields; the mockup shows plausible values (the date is the generation time of the
  screenshots; "agent (blind trial)" is the README's description of who transcribed).
- No git commit and no artifact publish were done (orchestrator's job). `*.review.html`
  and `*.lock.json` under `.forge/scoper/takeoff-sheet/` are gitignored and will not
  travel; the screenshots and mockup will.

## Open-questions

Q1 3D collapsed / open / conditional · Q2 tick count in the patch or page-local · Q3
interpretations per job or per room · Q4 photo-embed decision recorded in takeoff.json or
asked each time · Q5 add `transcribed_by`. Full text in the review §7. Approval gate: the
mockup's review layer — no section is approved until Benton's copy-back says so.
