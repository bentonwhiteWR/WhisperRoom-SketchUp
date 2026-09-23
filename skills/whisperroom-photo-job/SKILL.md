---
name: whisperroom-photo-job
description: Take a WhisperRoom client job from room PHOTOS to finished renders and a proposal. Invoke when the client sent photos of the host room, not a plan, and gave no dimensions, and the job is to build that room in SketchUp from the photos, place the quoted booth from its quote link, light it, set the scenes, render, export the proposal package and build the proposal. Not for dimensioned or hand-marked floor plans (use whisperroom-takeoff) or for building a PDF from renders that already exist (use whisperroom-proposal).
---

# WhisperRoom photo job: client photos to proposal

**Worked example: the first job (Community Music School, Sept 2026).** Its tools are in
`.forge/builder/cms/` (the jobs are in `jobs/`, the camera fit in `fit/`), its facts are in
`clients/<slug>/notes.md`, and its hazard list is in `.forge/builder/cms/HANDOFF.md`. Copy
those tools rather than rewriting them. They are one-offs written for that room, so read
each header before you reuse it.

This skill is the order of work and the traps. Two other skills own their parts:
- **whisperroom-takeoff** covers a room drawn from a dimensioned plan. If the client sends a
  plan later, switch to it.
- **whisperroom-proposal** covers the PDF. Step 13 hands off to it.

All model work runs over the bridge (`scripts/sketchup-bridge.py`) in Benton's open file.

## The stages, in order

1. **Resume and orient.** Run `git pull` first. Handoffs live on GitHub, and a machine that
   has sat idle can be many commits behind. Then read the top of `DEVLOG.md`,
   `.forge/GOAL.md`, `clients/<slug>/notes.md` and the builder's `HANDOFF.md`.
2. **Camera-fit the photos** (`fit/`: `joint7.py`, `overlay.py`, `compare.py`,
   `evalfits.py`, `export_fit.py`). Take the scale from one named anchor. In the first job
   that was a 97 in fluorescent run. **Judge a fit by the overlay error measured on BOTH
   photos, from a render made in SketchUp, never by eye.** In the first job a joint refit of
   both photos (`joint7`) beat both of the single-photo fits. The score table is in
   notes.md.
3. **Build the shell, then the features** (`room.rb`, then `features.rb`). The test for each
   piece is a side-by-side of photo, model and overlay (`fit/sbs.py`, kept in `compare/`).
   It is done when those line up.
4. **Dimension the room** (`dims.rb`). Dimensions are chained, the runs close, and every
   one is marked EST. with its tolerance. Add this plan note word for word:
   "HOST ROOM DIMENSIONS NOT PROVIDED. ALL ROOM DIMENSIONS ARE ESTIMATED FROM CLIENT PHOTOS
   (±1 FT) AND MUST BE CONFIRMED ON SITE."
   - Notes and labels are **3D floor text** (`WR_CMS.floor_text`), never screen text.
   - Do not add "CORNER A/B" labels.
5. **Save one photo-match scene per client photo** (`WR_CMS.photo_scenes!`). Run
   `WR_CMS.check!` after every save.
6. **Place the booth from the quote link, headless** (`scripts/booth-from-link.rb`; the
   example is `jobs/booth.rb`). Paste the payload into the job, because the `?d=` path
   fetches asynchronously. Use real components only, and set the foam to gray. **Benton
   places the studio lights himself.** Never search for or hand-model that part.
7. **Placement** (`jobs/place.rb`). The offset from a wall, such as 18 in, is measured from
   the booth STRUCTURE (the wall-panel faces). It is NOT measured from the vent hoods, seam
   seals or silencers. Measure the booth's parts, never the group origin, and report both
   numbers (panel face and hood) for each side.
8. **Add extras such as Audimute** (`jobs/audimute.rb`). Copy Benton's own component into
   the gaps between the foam panels. Report any contact with other parts, and let him
   accept it.
9. **Light it** (`lights.rb`, which provides `WR_CMS_Lights.place!` / `audit`; the renders
   come from `rt.py`). Follow his standing rules:
   - Light it like a real room: office-style fixtures and daylight through the windows.
     Do not set up a photo studio.
   - Nothing may compete with the booth, the fixtures included.
   - Tune on ONE hero scene, change one thing per test, and render at about 800 px. Log
     each test in `progress.txt`.
   - Then run one check render of each other scene. A contact sheet helps
     (`jobs/contact-sheet.py`).
10. **Scenes.** Use AUTO-SET (`scripts/wr-autoset.rb`) together with the proposal package.
    Set heroes by hand where AUTO-SET's camera looks past the room. In the first job, 01b,
    a camera inside the room, became the cover. Write a scene plan (`scene-plan.md`) giving
    render or skip, EV and caption for each scene, and let Benton decide.
11. **Booth interior-dimensions scene** (`jobs/scene-09.rb`, `jobs/interior-faces.rb`,
    `jobs/perimeter-09.rb`). It is a plain image, viewed top-down. Hide the ceilings, the
    studio lights and the seam seals. Show the interior clear dimensions, measured to the
    IEP faces, and an orange dashed clearance perimeter.
12. **Export the package at 16:9** (`scripts/proposal-package.rb` 1.76.0 or later) with a
    transparent background. Benton may run this step himself. While his export runs, do
    not run bridge jobs and do not stop V-Ray.
13. **Build the proposal with the `whisperroom-proposal` skill.** Include EVERY exported
    plate by default; only Benton drops plates. Flatten each plate onto white, and check
    that dimensions drawn over transparent areas are still visible.

## Traps we already paid for

The first job's `HANDOFF.md` records each of these unless the item says otherwise.

- **Photo depth along a wall seen at a grazing angle is unreliable.** *Symptom:* the fit
  said the radiator matched, but Benton saw it about 1 ft off. *Cause:* position along a
  wall viewed edge-on is weakly constrained. *Fix:* measure each feature RELATIVE to its
  window or niche. Benton's ruling overrides the fit; record it in notes.md as a ruling.
- **Scenes opened super zoomed in.** *Cause:* AUTO-SET aimed from a view camera that
  carried an aspect ratio, so its 35° lens was stored as a horizontal fov. SketchUp then
  re-expressed it as a 14.24° height fov at the 2.5:1 window. Cameras stored with an
  aspect ratio convert like this within a session. *Fix:* before any AUTO-SET or aim, give
  the view a fresh camera with aspect 0 and a height fov (`jobs/autoset-reaim.rb`). The
  photo-match scenes still convert, so run `WR_CMS.photo_scenes!` before saving and after
  reopening.
- **All the lights "vanished".** *Cause:* a scene hid the light OBJECTS, and object hidden
  flags are global in SketchUp. *Fix:* hide the WR Lights TAG in the scene instead. Always
  wrap a tag hide in `ensure`.
- **Gray balls with shadows in the renders.** *Cause:* re-placing the rig can silently
  reset V-Ray parameters to their defaults (visible, intensity 30). *Fix:*
  `jobs/fill-rewrite.rb`. A short light count after a re-place is REAL, not a glitch.
  Verify with `WR_CMS_Lights.audit` in a separate, later job and again after saving.
  Removing and creating lights in one job kills the new ones, so place first and remove
  last.
- **Discs in the window glass and rectangles on the ceiling.** *Cause:* rig lights were
  visible or reflected. *Fix:* set every rig light to invisible AND affect-reflections
  off (`jobs/invisible-and-niches.rb`, checked by `jobs/lights-verify.rb`). The visible
  fixture is the fixture's own geometry.
- **V-Ray sits in "rendering" and blocks work.** *Cause:* it is an interactive render.
  *Fix:* stop it with `VRay::Command.stop_current_render`, confirm it is idle in a later
  job, and carry on without asking. The one exception is while Benton's package export
  is running.
- **Holes under the radiators.** *Cause:* the floor face stopped at the wall line and did
  not reach into the window niches. *Fix:* extend the carpet into the niches
  (`niche_floors!` in `features.rb`).
- **Renders looked cropped.** *Cause:* V-Ray's output size (4:3) and the plain-image size
  (the window's shape) differed. *Fix:* package 1.76.0 forces one 16:9 size on every
  plate after each scene switch (DEVLOG 1.76.0).
- **Dark, uncorrected extra PNGs.** *Cause:* the `.denoiser.png` and `.effectsResult.png`
  sidecars are V-Ray's raw channels. *Fix:* 1.76.0 deletes them.
- **Black areas in renders with the walls hidden.** *Cause:* this is UNLIT geometry
  (outside wall faces, the corridor block, the back of the booth), not background. The
  transparent background handles only the true background. *Fix:* where possible, use a
  hand-set camera inside the room (01b) instead of hiding walls. (Per the session
  coordinator, not recorded in the HANDOFF: the dark high and ventilation renders were
  dropped from the final pack.)
- **Plan dimension text ran together** at Benton's wide window. *Fix:* space the rows
  about 55 in apart, and put the text for short segments outside them.
- **The interior-dims tag or perimeter showed in other scenes.** *Fix:* make both visible
  only in their own scene. The photo scenes store no tag state, so `photo_scenes!` can
  turn them back on globally. Turn them off before saving.
- **The inside-booth scene looks stretched at the edges.** *Cause:* it borrows the photo's
  wide lens (about 86° height fov). (Per the session coordinator; the HANDOFF records the
  lens but not the stretch.)
- **The bridge wedged or the file was lost.** *Fix:* save with `m.save(m.path)` and
  `--write-root`. Never call `file_new`, and never trigger a modal dialog. The package's
  non-modal dialog is fine. Never call `WR_CMS.run!` on a built room: a rebuild orphans
  every scene's hidden walls. Edit fittings in place instead, as `jobs/radiator2.rb`
  does.
- **No way back.** *Fix:* back up before any round that changes scenes. Keep a scene
  record JSON (`jobs/scene-backup.rb`, restored with `jobs/scene-restore.rb`) and a dated
  `.skp` copy. Benton likes being able to revert.
- **Client material in a public repo.** Photos, anything derived from them (`compare/`,
  window backdrops), renders and PDFs never enter this repo. Check `.gitignore` and
  `git status` before every commit.

## How Benton works on these jobs

- He gives rulings mid-run, and his ruling beats the fit. Record each ruling in notes.md.
- He edits the model by hand in parallel. He added the studio lights, the Audimute panel,
  scene deletions and light intensities during the first job. Re-read the model state
  before each step, and never undo his changes.
- Send open questions in batches, not one at a time.
- Keep revert paths for everything.
- "Email me" means publish an Artifact and send him the link.
