# GOAL

## Mission
Redesign the "Draw floor plan..." tool (`scripts/build-room.html` + `scripts/build-room.rb`)
so it is obvious to use. Benton's complaint: "it's not clear; adding a door isn't clear at
all (let me click the wall, for example)." Doors should be placed by interacting with the
drawn plan, not by typing a run index into a table.

## Done means
1. A Fable Scoper spec + clickable mockup in `.forge/scoper/` that Benton has approved.
2. A Builder implements it; `scripts/rbparse.py` passes; VERSION bumped; committed and pushed.

## Now
1.72.0 BUILT and pushed 18 Sep (mirror fix ON, placed-by-eye warns, 4-state Rotate door with
`swing` in the payload). Parsed + browser-tested; NOT yet run in SketchUp. Next: Benton's one
live build (see `.forge/builder/HANDOFF.md` → Open questions) — door on north wall must land on
north wall; "opens out" must draw outside.

## Out of scope
Changing the Ruby geometry/build path's output beyond Benton's two rulings (the mirror fix, and
outward swing — a door without `swing` builds identically), other tools, the take-off
pipeline, WhisperRoomQuote.

## History
- 15 Sep: UTHSC V3 revision pack delivered; awaiting Benton's caption review.
- 14 Sep: lights panel 1.70.0, Dimension selected room 1.71.0, no-vent wall fix 1.71.1.
