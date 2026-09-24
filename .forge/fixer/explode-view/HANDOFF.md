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

---

# Round 2 — Benton's decisions (24 Sep 2026, after e480576). Uncommitted, VERSION not bumped.

## Produced
- `scripts/explode-view.rb`
  - **Ceiling layer.** booth_plan step 8 (new `subs` argument, `:sub` result, `BP_LAYER` 0.25, `BP_LAYER_GAP` 0.5).
    A ceiling part holding at least 2 panel-sized children is treated as a layer. It lifts above every
    other ceiling part (plus 0.25 x travel), and its children open out at half the Std ceiling gap.
    The children move inside the component by translation only. The vector goes through the parent's
    inverse transform, because the IEP ceiling sits turned 90 degrees in the booth.
  - New helpers: `kid_box`, `kids_home` and `placed_copies`. Kids with a home go back to it at the start of
    every plan (all modes) and on Reset. Measuring a kid writes no attribute; only kids that move get one.
  - The report names the layer and warns when its definition has more than one placed copy.
  - **Default Fan 150 -> 200**, in three places: the `@setting` header, `DEFAULTS` and the perform fallback.
  - Header comment updated: Radial and Vertical are kept as the scatter option.
- `scripts/rbtest-explode.py`: 8 runs, two new checks.
  - Check 11: the IEP layer is above the Std ceiling and its pieces open evenly.
  - Check 12: at the panel's own defaults (read from the `@setting` header), every mid-wall seal is
    clear of its panels.
  - IEP piece fixture added.
- `.forge/fixer/explode-view/dump-iep.rb` and `.forge/fixer/explode-view/iep-ceiling-kids.json`.
- `.forge/fixer/explode-view/live-check.rb` and `.forge/fixer/explode-view/live-toggle.rb` extended. The toggle
  test deletes any home attributes it created.

## Verified (observed, live, Benton's model left as found)
- **144 E at defaults:** 0 new overlaps and 0 overlaps involving the six IEP pieces. The IEP layer's
  underside is 10.95 in above the Std ceiling's top. Pieces return home exactly.
- **7272 S at defaults:** 0 new overlaps, and no mid-wall seal is left on its panels.
- **Toggle path:** the 60 -> 90 -> 60 re-explode is exact, including pieces. Reset with nothing selected
  returns all parts and pieces home. Radial and Vertical run and reset.
- **Offline and parse:** `rbtest-explode.py` passes; `rbparse.py` parses all 78 files.
- **Mutations caught:** Fan 150 fails check 12 on both booths; disabling the layer or its extra lift fails 11.
- **Shots:** `ev3-144-iso.png`, `ev3-144-high.png` and `ev3-7272-iso.png` in the bridge art folder.
- **Panel settings:** the live `abilities` data shows mode (choice: Axis/Radial/Vertical), spread (number, 60)
  and fan (number, 200 after reload). `panel.html` draws number settings as editable text fields. No per-user
  or shop-default value is stored for this ability on this machine, so the header default is what Benton
  gets.

## Shared definition
- `GoPro Iep ceiling (192192) assembled` has 2 instances in this model. The second sits inside
  `GoPro Ceiling (192192) std/iep/vnt sys#1` -> `12ftx14ftCustom#1` -> `12ftx12ftCustomBoothAssemblyStandardCompleteskp`,
  which has **0 placed instances**, so nothing visible changes.
- In general, every placed copy of that definition (e.g. two Enhanced booths sharing it) shows its IEP
  pieces opened out while one booth is exploded, until Reset. Reset (or re-explode) puts them back for all.
- The home attributes live on the piece instances inside the definition, so they are shared too.
