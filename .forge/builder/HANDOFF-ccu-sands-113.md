# Builder handoff — CCU Sands Hall 113 (6 Oct 2026)

## Produced
- `clients/ccu-sands-hall-113/takeoff.json` holds the room take-off. The checker is clean, with 2 DEFAULT flags: the ceiling and the door height.
- `clients/ccu-sands-hall-113/notes.md` holds the take-off, the decoded links, the layout table, the clearances and the flags.
- Commits on origin/main:
  - `a4192d4` — take-off and notes.
  - `4cb9a6d` — layout.
  - `beb3334` — swap of Booths 1/5 with 7/8, giving a uniform MDL 7272 E south row.
- The live SketchUp 2026 model is saved over `Z:/Sketchup/ClientDrawings/Coastal Carolina University Sands Hall 113.skp`. It contains:
  - the room group `Sands Hall 113`, with its dimensions;
  - 8 booth groups, `Booth 1 – MDL 7272 E` … `Booth 8 – MDL 7296 E`, numbered by position. These are 2 link builds plus 6 copies, placed by rotation and translation only. The south row (B1–B5) is all MDL 7272 E; B6–B8 are MDL 7296 E;
  - the reserved 16'×16' zone, as outlines and a label on `WR-Reserved`;
  - 37 placement dimensions on `WR-Dims-Booth`, drawn at z 96.
- `WR-Ceiling` is hidden in the model.
- Screenshots:
  - `.forge/builder/ccu-sands-113/layout-top.png`
  - `.forge/builder/ccu-sands-113/layout-iso.png`
  - earlier: `room-top.png`, `overall-top.png` and `booths-staged-iso.png`, all in `.forge/builder/ccu-sands-113/`
- Placement scripts:
  - `.forge/builder/ccu-sands-113/place2.rb` — the first placement. Outputs: `place2-dry.json`, `place2-apply.json`.
  - `.forge/builder/ccu-sands-113/place3.rb` — the swap. Output: `place3-dry.json`, which holds the applied run (see the gotcha below).
- **Gotcha:** `ENV['CCU_APPLY']` persists inside SketchUp between bridge jobs. Clear it with `ENV.delete('CCU_APPLY')` before any dry run.

## Read-first
- `clients/ccu-sands-hall-113/notes.md`, the "Layout" section.

## Assumptions
- The ceiling is 8'-0" (house default). The roof units top out at 94 5/8"; the importer requires 95.31".
- Plan-up is north.
- The placement is Claude's adaptation of client sheet A2, approved by Benton as "best as possible". It is not the client's layout.
- The quote mapping is derived from the room sizes:
  - the ~55/56 isf rooms are the MDL 7296 E;
  - the 44/38 isf rooms are the MDL 7272 E.

## Open-questions
- What is the real ceiling height of room 113?
- B5's ramp landing is fine for depth after the swap (72.5" to the reserve). A centred 60×60 landing crosses the east wall by 2.5"; it fits if shifted west. Is that acceptable?
- B6's ramp landing has 49.4" to the west wall and overlaps the room-door swing. Should it be fixed?
- B8 sits 1/8" from the reserved outer boundary. Is that acceptable?
- Audimute (`ac`=1 on every booth) is not laid out yet. It is pending Benton.
- Two pre-existing script defects are reported and not fixed:
  - `build-takeoff.rb` lays no door dimensions.
  - The dimension engine gives a false chain warning when a room has a free-standing pilaster.
