# GOAL

## Mission
The Proposal Package panel's Draft <-> Render material swap must never be silent.
When a toggle moves zero surfaces, the panel log has to say why, in the window,
naming each slot, the source material it looked for, and what it found instead.

## Done means
- A DRAFT or RENDER toggle that matches nothing prints a loud, specific line per
  slot in the Proposal Package log (and in wr-mode's console report), not nothing.
- The line names the slot, its configured SOURCE material, its configured FILL,
  and how many surfaces in the model carry that source.
- scripts/rbparse.py passes; the pure logic has a test in the rbtest family.
- scripts/wr_tools/VERSION bumped; committed and pushed to main.

## Now
Fixer: implement the loud no-op in scripts/wr-materials-swap.rb + the two log
sites in scripts/proposal-package.rb (unit_mode ~line 1371, togglemode ~line 2878).

## Out of scope
- Changing which materials build-room.rb paints. VERIFIED CORRECT this session:
  build-room.rb:403/411/415 and build-takeoff.rb:259/273/277 paint floor
  0128_White, walls 0099_LightSteelBlue, doors 0043_SaddleBrown. Do not touch.
- The lighting rig (wr-drop-lights.rb).
- Any redesign of the slot/fill model.
