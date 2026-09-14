# HANDOFF — Builder: Suites 128 & 114 take-off, built live (14 Sep 2026)

The previous builder handoff (AUTO-SET, 1.48.0) is preserved verbatim as
`.forge/builder/HANDOFF-autoset.md`.

## Produced
- `clients/suites-128-114/takeoff.json` — three rooms:
  - "Suite 128 — 13'3 x 9'3 room": 6 runs, with the powder-room jog.
  - "Suite 114 — 10'10 x 9'10 room" and "Suite 114 — 10'11 x 9'10 room": side by side
    with the true scaled 7" partition offset.
- `clients/suites-128-114/notes.md` — the read, px/in per room axis, provenance per
  dimension, open questions.
- Plans copied to `clients/suites-128-114/plans/` (gitignored, verified with
  `git check-ignore`). The lock and review sheet are generated and gitignored.
- Screenshots (not committed): `.forge/builder/suites-128-114/suite-128-top.png`,
  `.forge/builder/suites-128-114/suite-114-top.png`.
- No script under `scripts/` was changed, so there is no VERSION bump.

## Verified
- **observed:** `takeoff-check.py --html` exit 0 on the first run. 18 flagged values and
  3 assumed hinges. The door words line matches the intended corner for all three doors.
- **observed:** built via the bridge with `WR_BuildTakeoff.build_from(lock)` into SketchUp
  2026 Untitled.
  - The job refuses if `model.path` is non-empty; it was empty.
  - Report: 128 = 6 runs, 8 wall solids, 1 door; each 114 room = 4 runs, 6 solids, 1 door;
    ceilings 8'-0". 20 dimension entities at model level.
  - Model left unsaved.
- **observed (screenshots):**
  - 128: closed, jog present, door on the east wall at the north end, hinge at the north
    jamb, swinging in.
  - 114: both rooms closed and meeting in the partition (walls touch at x=833.5"); the
    west door is hinged west, the east door hinged east, both swinging in.
  - Every wall is dimensioned.

## Not done / gaps
- The model also contains a group named "Room" at x -184..304" that predates this job;
  it was not touched and the new rooms are placed clear of it.
- `WR-Ceiling` tag hidden for the shots (a model-state change, unsaved).
- **No door corner → jamb dimensions** are drawn: `build-takeoff.rb` doesn't make them.
- 114's dimensioner puts some 9'10" strings inside the neighbouring room, and 128's
  1'8 3/4" jog label overlaps the wall. Both are cosmetic, and both come from the
  dimensioner, which was not changed.
- "Every assumed value noted in the model" (GOAL) is **not** how the builder works:
  `NOTES_IN_MODEL = false` by Benton's 1 Sep rule. The assumptions are in the build
  report, the lock and the review sheet.
- Review sheet not published (orchestrator publishes).

## Open questions
Ceiling heights (both suites); the 128 jog; door hinges, widths and positions; the 114
labels vs the drawing (the "10'11"" room draws narrower); which room is "far back".
Full list in `clients/suites-128-114/notes.md`.

## Follow-on in progress
Coordinator asked for the quoted booth (MDL 4872 S, link `#3=AQUkM4VkAQUHBAoBAAYA`) to be
placed in each target room. See the section appended below when done.
