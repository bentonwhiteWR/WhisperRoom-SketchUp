# HANDOFF — Community Music School builder (paused 22 Sep 2026, 17:21)

The orchestrator wrote this: the laptop Builder was stopped before it could leave its own
handoff. Facts and decisions live in `clients/community-music-school/notes.md`; read that
first. This file is how to continue.

## Files

- `room.rb` — `WR_CMS.run!` rebuilds the room from `fit.json` (+ `features.json` when it
  exists). `WR_CMS.match!(:A|:B)` sets the viewport to a photo's matched camera. `DIR` now
  resolves from the file itself, so the file works in either checkout.
- `fit.json` — the fit the model was built from (17:07). `fit/final_fit.json` (17:19) is a
  newer bundle adjustment. To convert it to inches, multiply by `fit/scale.json` → `h` (57.18 in
  per unit). It is **not applied**. Decide whether to adopt it, then rebuild.
- `fit/` — the Builder's camera-fit tools (`cam.py lm.py refine.py joint*.py rc.py
  compare.py overlay.py bundle.py ...`) and their JSON, copied from the laptop session's
  temp folder. The comparison PNGs (~190 MB) were not kept, because they can be regenerated.
  **Several `fit/*.py` hard-code `C:/Users/bento/Documents/Claude/Sketchup`**; on the desktop,
  point them at `C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp`.
- `progress.txt` — the Builder's scratch log.

## Continue in this order (placement-dependent work last)

1. Open the `.skp` and run `WR_CMS.match!(:A)`. Check the shell against photo A (compare a
   viewport shot with `clients/.../plans` or the pCloud photo copy).
2. Fidelity: model every feature in the notes' "Features to reproduce" list. Use the camera
   match as the test: a side-by-side of a shot against each photo, fixed until it lines up.
3. Room dimensions:
   - Chain every wall run and close each chain.
   - Dimension each door and window off a named corner.
   - Override the text to `EST.`
   - Add the plan note "HOST ROOM DIMENSIONS ESTIMATED FROM CLIENT PHOTOS — NOT FIELD MEASURED (±1 ft)".
   - `scripts/dimension-selection.rb` (Dimension selected room) may do the chains.
   - Room dims vanished mid-build on two earlier bridge jobs, so re-check they exist after every save.
4. Booth: `scripts/booth-from-link.rb` headless with link `?d=b31cfb67e46d`.
   - Example call: `.forge/builder/concept-art/booth-build.rb`; cfg dir `P:/Sketchup/NewMasterComponentList`.
   - Inspect `BoothLighting.skp` for the 52 in studio light (×3, on the ceiling panels).
     WhisperRoomQuote's booth-builder shows where `sl` goes; that repo is read-only. If you
     can't confirm the part or its position, leave it off. Never hand-model it.
   - Give the foam a neutral gray, because the stock foam renders as pure blue.
5. Placement:
   - Vent (north) face **18 in** off Wall D, centred, door and window into the room.
   - Keep the door-swing clearance and the 12 in step clearance from CLAUDE.md.
6. Lights: `scripts/wr-drop-lights.rb` headless. Working calls: `.forge/builder/concept-art/drop-lights.rb` and `remove-rig.rb`.
   - Read `.forge/builder/HANDOFF-lights-api.md` and `HANDOFF-lights-run.md` first.
   - The visible fixtures must stay the room's surface fluorescents; no extra drums.
   - Add daylight through the windows.
   - The key light needs 42–96 in of floor in front of the booth door.
7. Scenes: AUTO-SET, which is Benton's "auto fit". Working calls: `.forge/builder/concept-art/autoset-*.rb`.
8. Booth dimension images: `scripts/dimension-whisperroom.rb`, then
   `scripts/rotate-whisperroom-dimensions.rb`, so the set sits on the camera side of each
   dimensioned view. Both are click tools, so find their headless entry points.
9. Renders: every scene in V-Ray, through the proposal package export or the concept-art
   pipeline (`rt.py` / `render.rb` / `finish.py`).
   - At least 2000 px wide. Never overwrite existing files.
   - Test at ~800 px; Benton's CPU is shared.
   - Read every frame.
10. Update `clients/community-music-school/notes.md` (estimate table, what built and what didn't, omissions).

## Hazards (all paid for already)

- **Saving:** the bridge refuses a bare save. Pass `--write-root "Z:/Sketchup/ClientDrawings"`
  (or the `P:` form on the desktop). Never `file_new`, which hangs the bridge on its save prompt.
- **Modals:** a modal wedges the bridge's `@busy` flag. Load tools with `$wr_no_autorun = true`,
  pass settings in, and wrap builds in `start_operation` / `abort_operation`.
- **V-Ray renderer calls:**
  - Never call `in_process?` or `dr_enabled?`; both raise.
  - Only `:idleDone` means a frame exists.
  - Start the render, then poll it in short jobs.
- **Rolled-back lights:** a rolled-back light drop orphans V-Ray lights, and the next render goes dark.
- **SketchUp camera FOV:** once `aspect_ratio` is set, `fov` is HORIZONTAL (the Builder found this; `room.rb` passes `fov_h`).
- **Stopping an agent mid-render:** its queued bridge jobs still run later. Check the bridge's
  `in/` folder (`%LOCALAPPDATA%\WhisperRoom\bridge\SketchUp 2026\in`) after stopping one.
