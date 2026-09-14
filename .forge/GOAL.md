# GOAL

## Mission
Take off the client's target rooms from two real-estate floor plans (suites 128 and
114) and build them in the live SketchUp 2026 model through the bridge, so Benton can
place the quoted booth in them.

## Done means
- `clients/suites-128-114/takeoff.json` passes `takeoff-check.py`; lock + review sheet generated.
- Built via `WR_BuildTakeoff.build_from` into the open Untitled model: 128's 13'3" x 9'3"
  room, and 114's two adjacent rooms (10'10" x 9'10" and 10'11" x 9'10"), dimensioned,
  every assumed value noted in the model.
- A viewport screenshot confirms the build; notes.md records the read; committed and pushed.

## Now
Built and pushed (e0056ce, 9d5e7a1): three rooms plus the quoted MDL 4872 S placed in each,
live model unsaved. Waiting on Benton: ceiling heights, which way the 114 east booth faces,
review-sheet answers, and whether he deleted a pre-existing "Room" group between 10:06 and 10:14.

## Out of scope
- Choosing or placing a booth. No quote yet; the model comes off the quote.
- The fallback "far back" rooms in either suite, unless Benton asks.
- Proposal renders.

## History
- Company A proposal delivered 12 Sep at 6.8/8; three Benton decisions still open
  (see DEVLOG 2026-09-12 handoff). Floor pick i02/i04 open; Benton is testing floors.
