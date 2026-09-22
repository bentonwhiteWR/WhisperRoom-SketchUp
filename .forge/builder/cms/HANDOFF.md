# HANDOFF — Community Music School builder (desktop, 22 Sep 2026, 18:50)

Steps 1–3 (the room) are DONE and saved. Next run starts at step 4 (booth). Facts, the
estimate table and the built/omitted list are in `clients/community-music-school/notes.md`.

## Produced

- **Model:** `Z:/Sketchup/ClientDrawings/Community Music School CP SL MDL 96144 E.skp`, saved via
  the bridge at 18:47:41 (4.2 MB). Re-checked after the save: `CMS Classroom` present, 23 dims
  (all ending `EST.`), 9 labels and plan note, and both photo scenes.
- **Fit:** `fit/joint7.py` → `fit/joint7.json` + `fit/scale_joint7.json` (h = 58.25 in/unit) →
  `fit.json` (via `fit/export_fit.py joint7.json scale_joint7.json`). The old `fit.json` is kept
  as `fit/fit_joint6_as_built.json`. The decision table is in notes.md.
- **Room builder:**
  - `room.rb` (shell; now calls `features.rb` hooks).
  - `features.rb`: openings, every fitting, fixtures, materials. Its textures are in `tex/`, and
    the backdrops are made by `fit/textures.py`.
  - `dims.rb`: `WR_CMS.room_dims!`, `photo_scenes!` and `check!`.
- **Tools:**
  - `fit/crop.py` (gridded photo crops).
  - `fit/rc.py` (now joint7, plus `tri()`/`showtri()` two-photo triangulation).
  - `fit/sbs.py` (side-by-side + measured error).
  - `fit/evalfits.py`, `fit/distort_check.py`.
  - `jobs/shots.rb` (photo-match shots, dims tag hidden then restored).
  - `jobs/plan.rb` (top-down plan, fully rolled back).
- **Deliverables:** `compare/final-A-sidebyside.png`, `compare/final-B-sidebyside.png`,
  `compare/plan-top-EST.png`, and `final-*-errors.json`. Final measured error, room lines then
  features, in rms px: A 5.1 / 4.7, B 12.4 / 12.0 (B's rms is mostly the grazing B/C corner line).
- **Photo-match scenes:** **"Photo A - long view"** and **"Photo B - corner view"**. They are
  camera only (no tags, style or shadows stored) and are built from `WR_CMS.camera_for` with the
  fit's fov and aspect.
  - **The later AUTO-SET step (7) must keep them and must not overwrite them.**
  - Consider them for renders.
  - If the fit ever changes, rerun `WR_CMS.photo_scenes!`.

## Read-first

1. `clients/community-music-school/notes.md`: estimate table, fit decision, built/omitted list.
2. `features.rb` header (naming rules) and `dims.rb` header (tag choice).
3. Rebuild everything, room + dims + scenes, in one bridge eval:
   `$wr_no_autorun=true; load ".../cms/room.rb"; load ".../cms/dims.rb"; WR_CMS.run!; WR_CMS.room_dims!; WR_CMS.photo_scenes!`
   `run!` erases only `wr_cms` role groups, so the dims (stamp `wr_cms_dims`) and scenes survive it.

## Continue in this order (placement-dependent work last)

1–3. DONE (camera check + fit decision, fidelity, EST room dims). Re-verify with
   `WR_CMS.check!` after every save.
4. Booth: `scripts/booth-from-link.rb` headless with link `?d=b31cfb67e46d`.
   - Example call: `.forge/builder/concept-art/booth-build.rb`; cfg dir `P:/Sketchup/NewMasterComponentList`
     (on this desktop, check which of `P:`/`Z:` resolves).
   - Inspect `BoothLighting.skp` for the 52 in studio light (×3, on the ceiling panels).
     WhisperRoomQuote's booth-builder shows where `sl` goes; that repo is read-only. If you
     can't confirm the part or its position, leave it off. Never hand-model it.
   - Give the foam a neutral gray, because the stock foam renders as pure blue.
5. Placement:
   - Vent (north) face **18 in** off Wall D (Y = L = 270.7), centred on it (X = W/2 = 91.3),
     with the door and window into the room.
   - The tack strip on Wall D (X 60–167, Z ~59) ends up behind the booth, which is fine.
   - Keep the door-swing clearance and the 12 in step clearance from CLAUDE.md.
   - Check that run 2 of the ceiling fixtures (Y 202–212.5, Z 121) clears the booth top.
6. Lights: `scripts/wr-drop-lights.rb` headless. Working calls: `.forge/builder/concept-art/drop-lights.rb` and `remove-rig.rb`.
   - Read `.forge/builder/HANDOFF-lights-api.md` and `HANDOFF-lights-run.md` first.
   - The visible fixtures are the room's own surface fixtures, and there are TWO types. Run 1
     (Y 68.5–78.5) is a lensed wraparound; run 2 (Y 202–212.5) is a parabolic egg-crate louver.
     Their lens/lamp faces are `CMS Fixture Lens`. No extra drums.
   - Add daylight through the windows. The backdrops (`CMS Backdrop w1/w2`) sit 6 in outside
     Wall A's exterior face and are plain textured materials, not emitters.
   - The key light needs 42–96 in of floor in front of the booth door.
7. Scenes: AUTO-SET, which is Benton's "auto fit". Working calls: `.forge/builder/concept-art/autoset-*.rb`.
   **Keep "Photo A - long view" and "Photo B - corner view"; never overwrite them.**
8. Booth dimension images: `scripts/dimension-whisperroom.rb`, then
   `scripts/rotate-whisperroom-dimensions.rb`, so the set sits on the camera side of each
   dimensioned view. Both are click tools, so find their headless entry points.
9. Renders: every scene in V-Ray, through the proposal package export or the concept-art
   pipeline (`rt.py` / `render.rb` / `finish.py`).
   - At least 2000 px wide. Never overwrite existing files.
   - Test at ~800 px; Benton's CPU is shared.
   - Read every frame.
   - The room-dims tag `CMS Room Dims (EST)` is NOT a `WR-Dims*` tag, so scene tools that hide
     dimensions by that name will not hide it. Hide it explicitly in every render scene.
10. Update `clients/community-music-school/notes.md` with the booth, lights and renders.

## Hazards (all paid for already)

- **Saving:** the bridge refuses a bare save. Use `m.save(m.path)` with
  `--write-root "Z:/Sketchup/ClientDrawings"` (worked on the desktop 22 Sep). Never
  `file_new`, which hangs the bridge on its save prompt.
- **Modals:** a modal wedges the bridge's `@busy` flag. Load tools with `$wr_no_autorun = true`,
  pass settings in, and wrap builds in `start_operation` / `abort_operation`.
- **V-Ray renderer calls:**
  - Never call `in_process?` or `dr_enabled?`; both raise.
  - Only `:idleDone` means a frame exists.
  - Start the render, then poll it in short jobs.
- **Rolled-back lights:** a rolled-back light drop orphans V-Ray lights, and the next render goes dark.
- **SketchUp camera FOV:** once `aspect_ratio` is set, `fov` is HORIZONTAL (`room.rb` passes `fov_h`;
  re-confirmed on the desktop: `fov_is_height?` false for both photos).
- **Stopping an agent mid-render:** its queued bridge jobs still run later. Check
  `%LOCALAPPDATA%\WhisperRoom\bridge\SketchUp 2026\in` after stopping one.
- **Dims vanishing (probable cause, derived):**
  - The desktop's installed plugin is **1.67.7**, older than the auto-dimension exact-tag fix.
    Toggling "Dimension the room" there can erase every `WR-Dims*` tag's dimensions.
  - The room dims therefore live on `CMS Room Dims (EST)`. Keep them off `WR-Dims*` names.
  - Re-check with `WR_CMS.check!` after every save.
- **Public repo:**
  - `compare/` and `tex/backdrop-*` embed or crop the client photos. They are gitignored now; keep it that way.
  - The photos themselves are copied into the gitignored `clients/community-music-school/plans/`.
- **Photo A's frame edges carry ~100 px of lens distortion** (kA ≈ 0.075). Trust photo B for
  wall A, and don't place anything from photo A's outer 10%.
- **Desktop Python:** OpenCV was missing. `opencv-python-headless` 5.0 is installed with `--user`.

## Assumptions

- `joint7` was adopted, which deviates from "choose fit.json or final_fit". The task said to
  pick one of the two; joint7 beats fit.json on every measure and final_fit on room lines in both
  photos. The numbers are in notes.md.
- The closet depth (~26 in), the tack strip's west end, window 2's hidden third (assumed 6 × 6),
  and the corridor volume are assumptions.
- Wall A is modelled as one plane at the fitted W plus the pilaster and niches. Triangulation hints
  at 2–6 in offsets between sections that are not modelled.
- Dimension text shows the inch-rounded value + ` EST.`, which I read as the meaning of "override
  to EST." (a bare "EST." would drop the number). The model's global precision is left at 1/16 in.

## Open-questions

- Should the client be asked for tape figures (length, width, ceiling height)? These are still
  the biggest risk to anything dimensional in the proposal.
- `BoothLighting.skp` / 52 in studio light: still unchecked (step 4).
