# Builder handoff: CCU Sands Hall 113, proposal scenes (7 Oct 2026)

The previous handoff (People's Space accessories) is now `.forge/builder/HANDOFF-peoplesspace-accessories.md`.
The layout handoff for this job is `.forge/builder/HANDOFF-ccu-sands-113.md`.

## Produced
The model was saved in place at 13:53 over the bridge (`m.save(m.path)`, `--write-root Z:/Sketchup/ClientDrawings`):
`Z:/Sketchup/ClientDrawings/Coastal Carolina University Sands Hall 113 192192 E MDL 7296 E  MDL 7272 E.skp`.

- **Walls:**
  - All 12 wall solids inside `Sands Hall 113 > Walls` were push-pulled from z 0–96 to z 0–120. The header
    over the door is now z 80–120, and the pilaster solids (Walls 4–6 and 8–9) rose with the walls.
  - Each solid is still a 6-face manifold, and no plan coordinate moved.
  - The ceiling slab moved from z 96–100 to z 120–124 and is still on `WR-Ceiling`, which is hidden.
  - No dimension measured the wall height, so none was changed.
- **Lights:** 20 V-Ray rectangle lights in a 5 x 4 grid, each 24 x 48, at z 119.5, on `WR Lights`.
  - Each is 4,000 lm at 5000 K, written as 1,280,000, camera-invisible and out of reflections.
  - They are top-level instances named `CCU ceiling light N` (attribute dictionary `wr_ccu_lights`).
  - The module is `scenes/ccu-lights.rb`, with `place!` and `audit`.
  - An audit in a separate job found all 20 alive; so did a second audit after the scenes were built and
    again at the save.
- **V-Ray data:** the model's V-Ray components were upgraded when the context was created. V-Ray asked
  "Upgrading V-Ray components… will not work with previous versions"; the job answered OK.
- **Annotations:** the 3 type labels were retagged from Layer0 to `WR-Notes`, and the 16' booth's 3 dims plus
  2 extension edges were retagged to `WR-Dims-Booth`. Nothing was moved.
- **Scenes:** 10 new scenes, in export order, with lanes marked by `WR_ProposalPackage/mode`:
  EntranceRender, AisleEastRender, AisleWestRender, 16x16Render, FloorOverviewRender (render);
  FloorOverview, 7272Dims, 7296Dims, 16x16Dims, TopDown (image). `Scene 1` (Benton's top-down) is kept
  last and left unmarked (skip).
- **Scripts:** `.forge/builder/ccu-sands-113/scenes/`:
  - `s1`–`s7` (survey, raise, V-Ray activation, light placement, annotation retag);
  - `ccu-lights.rb` (the light module);
  - `ccu-scenes.rb` (table-driven and idempotent: it rebuilds only its own scenes);
  - `ccu-shots.rb` (screenshots).
- **Screenshots:** `.forge/builder/ccu-sands-113/scenes/shot-<scene>.png`, at 1600x900.

## Read-first
- `scenes/ccu-scenes.rb`'s SCENES table holds every camera, lane, hidden tag and hidden wall. Edit a row and
  re-run it to re-aim a scene.
- The proposal package (`scripts/proposal-package.rb`) reads the lane marks directly. Render rows take
  EV_ROOM 12, because no scene name matches INTERIOR_RE.

## Assumptions
- The coordinator's brief said the walls were 100 in, but they measured 96 in; the 100 is the top of the
  ceiling slab. "Up at least another 2 ft" was applied as +24 in, giving 120 in (10'-0").
- The light output copies the CMS rig (4,000 lm per 2x4, x320). Exposure is untested, because no render was
  run; Benton renders.

## Open-questions
- The real ceiling height of room 113 is still unconfirmed. 120 in follows Benton's "+2 ft", not a measurement.
- Saving with the upgraded V-Ray data means older V-Ray versions cannot open the file. Check whether any
  machine that renders it runs an older V-Ray.
- The brief listed a `RESERVED` group and its label, but nothing was on `WR-Reserved`; the 16' booth stands
  in that zone now. There was no outline to switch off.
- Exposure and light level need a test render of AisleEastRender before the full batch.
