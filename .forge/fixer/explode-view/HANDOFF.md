# Fixer handoff — Exploded view scrambles a booth (24 Sep 2026)

## Produced
- `scripts/explode-view.rb` (uncommitted, VERSION **not** bumped, no DEVLOG — orchestrator sequences those).
  - New pure planner `booth_plan` + `bp_shift` + `BP_*` / `OUTWARD` constants. Axis mode uses it
    whenever the parts read as a booth (floor/ceiling/tall parts on at least two sides of a footprint).
    Otherwise it falls back to the old per-part rule, unchanged.
  - Reset now moves every part straight to its stored home with no planning.
  - `homed_parts` now descends into ComponentInstances (`entities_of`). Before this, switching
    Exploded off with nothing selected never found the parts of a component booth.
  - `report` prints a per-group summary for a booth.
  - Header comment rewritten. The `@setting` lines are unchanged (mode / spread / fan).
- `scripts/rbtest-explode.py`: offline test. It lifts `booth_plan` / `bp_shift` / constants verbatim
  and runs them on two real booths (144144 E as one component, 100 parts; 7272 S as a group, 28 parts).
  It checks 10 assertions at 5 spread/fan settings.
- Repro and verify jobs in this folder, all run over the bridge:
  - `live-check.rb` runs the planner inside an ABORTED operation, measures overlaps and can take shots.
  - `live-toggle.rb` drives the real ability_on / ability_off path, ends at home and restores the camera.
  - `probe.rb`, `dump.rb`, `dump2.rb` read the part lists; `booth144144e.json` and `booth7272s.json` are the dumps.

## Root cause (observed, old code, spread 60 / fan 150, live 144144 E)
Every part was planned alone. Direction came from its own thinnest axis. Distance grew with its
distance from the centre (`reach`). A fan then scaled it about whatever co-planar run it fell into.
- The E-wall panels went out 127, 144 and 134 in and slid +20, +64 and -23 in along the wall.
- The open door leaf (thinnest in X) went +X like an E-wall panel, while its frame went -Y.
- The ceiling panels lifted anywhere from 103 to 133 in.
- The floor dropped 105 to 131 in and fanned 30 to 41 in sideways.

## Verified
- Live, 144144 E component (observed): 0 new overlaps and 0 cross-group overlaps. Explode at 60,
  re-explode at 90, back at 60 gives identical positions (6e-14). Reset with nothing selected puts all
  100 parts home (2e-13). Radial and Vertical still run and reset exactly.
- Live, 7272 S group (observed): 0 new overlaps, 0 cross-group overlaps.
- Shots (bridge art folder): `ev-before-iso.png`, `ev-after-iso.png`, `ev-after-top.png`, `ev-7272-iso.png`.
  Folder: `%LOCALAPPDATA%\WhisperRoom\bridge\SketchUp 2026\art\`.
- `python scripts/rbtest-explode.py` passes. `python scripts/rbparse.py` parses all 78 files.
- Mutation-checked. Each of these breaks made the test FAIL:
  1. taking the wall side from the thin axis;
  2. dropping the corner class;
  3. letting the floor drop;
  4. leaving followers at home;
  5. removing the gap cap (caught by the fan-1000 case).

## Assumptions
- Parts are axis-aligned in the booth's own frame (true for both booths checked). A booth whose walls
  are rotated inside its container would be misclassified. Not seen, not handled.
- The constants (BP_REACH 0.5, BP_GAP 0.15, BP_FLOOR_GAP 0.35) are my taste, not Benton's.
  At defaults the 144 E walls go out 43.8 in with a 9.9 in joint gap; the 7272 S goes 25.0 / 5.6.

## Open questions for Benton
- On the 7272 S at defaults the mid-wall seals still lap their panels by about 0.1 in (fan 150).
  Raise Fan, or BP_GAP, if the seals should read fully clear.
- Enhanced ceiling: `GoPro Iep ceiling (192192) assembled` is ONE sub-assembly covering all six Std
  ceiling panels. It lifts with them but is not opened out, and it hides the Std layer from above.
  The fix would be to stack the ceiling layers vertically, or explode into that sub-assembly (which
  edits a shared definition). Needs his call.
- Enhanced walls keep both skins together (his target). If a manual wants the IEP skin pulled off the
  Std skin, that is a new layer offset, not in this change.
- Radial / Vertical: kept and working, but per-part by design. On a booth they scatter. No booth use
  is known; candidates to hide from the panel.
