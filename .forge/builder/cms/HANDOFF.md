# HANDOFF — Community Music School builder (desktop, 22 Sep 2026, 21:15; model saved 21:14:48)

**State:** hold lifted. The V-Ray "rendering" was Benton's INTERACTIVE render; it read `idleStopped` when checked.
- **Saved (21:14:48, check! all green):** the scene-camera fix, the halved backdrop lights, the restored photo scenes, floor-text labels and plan note, and the new scene **"08-interior corner"** (21 scenes now).
- **Tests:** `tests/t08-interior-corner-final.png` and `tests/hero-after-camfix-final.png`.
- **Next:** Benton's decisions (scene-plan.md). The top one is the hero's black void (issue C, now about 29% of the frame).
- **STEP 9 finals remain PENDING his go-ahead.**

**SCENE-CAMERA ROOT CAUSE (20:30)**
- **Observed:** all 12 AUTO-SET exterior plates stored a 14.24 deg height-fov with aspect 0. That is AUTO-SET's 35 deg lens re-expressed as a height-fov at the 2.525:1 window (2169x859 device px, about 1694x671 at 128% scaling). 07-interior stored 31.0 = 70 deg at 2.525.
- **Consequences:**
  - The viewport showed about 74 in of height at 296 in, less than the 89 in booth: Benton's close-up.
  - The package's image lane, which captures at the window's shape, would show the same close-up.
  - Its V-Ray lane (4:3, keeps the vertical fov) gave the 2x crop of my first test.
  - My tests after that only looked right because render.rb compensated. That compensation is now REMOVED.
- **Derived mechanism:** `WR_ProposalScenes.aim` mutates the current view camera. If that camera carries an aspect_ratio (the photo-match scenes do: 0.75 / 1.333), `fov = 35` is stored as HORIZONTAL (probe: fov_is_height false). Later, in-session, SketchUp re-expresses such an aspect-carrying camera as a height-fov at the window aspect.
  - Observed again today on Photo A/B (85.93 -> 40.49, 102.31 -> 52.38) after a select-and-export pass.
  - The exact trigger was not reproduced in 7 isolated probes.
  - Aspect-0 height-fov cameras never converted.
- **FIX:** `jobs/autoset-reaim.rb`, which is AUTO-SET's own apply (mode update, reaim) from a clean aspect-0 view camera. All plates now store 35 deg height (07-interior 70), and they survived the full viewport-shot pass. Then `jobs/plan-scenes.rb` restores the plan dims and frame.
- **RULE:** before ANY AUTO-SET or aim, give the view a fresh aspect-0 camera. Never leave a photo-match camera in the view.
- **Not verified by an actual reopen:** Benton's live model can't be closed. The derived claim is that aspect-0 height cameras have nothing to convert.
- **Duplicates, not deleted (Benton decides):** the 13 "MDL 96144 E (components) ..." scenes were all created by AUTO-SET apply (create mode, renders = MAX 6, interior on) in jobs/scenes.rb at about 19:21.
  - They are 6 render/image pairs sharing one camera each (by design, since 1.56.0: "a render is an extra scene"), plus 07-interior.
  - The legacy five (WR_ProposalScenes) overlap them.
- **08-interior corner (BUILT 21:12 by `jobs/scene-08.rb`):**
  - Eye about (31, 240, 64.5): NW back corner, 57.7 in above the booth floor at z about 6.8.
  - Photo B's heading 133.9, pitch -11.07, roll -0.34.
  - Height-fov 85.93 (= photo B's 102.31 horizontal at 4:3), aspect 0.
  - The window is on the line of sight.
  - Not stamped by AUTO-SET, so apply never touches it.
- **Backdrop lights (Benton):** Rectangle Light#9 and #11 (daylight on backdrop, w1/w2) 1,920,000 -> 960,000 each. Read back in a later job; lights.rb DAY_OUT_LM 6000 -> 3000.

Steps 1–8 are DONE and saved, and the hero lighting is tuned on 800 px tests.
- **STEP 9 (final renders) IS PENDING BENTON'S GO-AHEAD.** He decides from `scene-plan.md`.
- **The 3 x 52 in studio lights are Benton's.** He loaded them himself; never search for or hand-model the part.

Facts, estimates and the built/omitted list are in `clients/community-music-school/notes.md`.

## Produced

- **Model:** `Z:/Sketchup/ClientDrawings/Community Music School CP SL MDL 96144 E.skp`, saved via the bridge. After every save `WR_CMS.check!` reads 23 dims (all EST.), 5 labels, the plan note, and both photo scenes.
- **Booth:** MDL 96144 E from `?d=b31cfb67e46d`.
  - Build: `jobs/booth.rb`, with the payload pasted in, because the tool's `?d=` path fetches asynchronously.
  - Foam: `[Color_I06]` set to RGB 96,96,98.
  - Placement: `jobs/place.rb`. It measures the booth's parts, never the group origin. The north panel face is 18.0 in off Wall D; the panel faces are 19.3 in off Walls A and C.
- **Audimute:** 4 copies of Benton's "Component#11" inside the booth (`jobs/audimute.rb`).
- **Radiator 2:** Y 43.5–80.5 by Benton's ruling (`features.rb`; re-seat in place with `jobs/radiator2.rb`). Close-up comparison: `compare/radiator2-closeup.png`, showing the 55.5–92.5 seat, before the ruling.
- **Lights:** `lights.rb` (`WR_CMS_Lights.place!` / `remove!` / `audit`), run by `jobs/lights.rb`. 21 lights, listed in notes.md. Hero-tuned values are in the constants; the log is in `progress.txt`.
- **Scenes:** 20 in total.
  - Photo A/B (kept).
  - The legacy five (`WR_ProposalScenes`, occluding walls hidden per plate by `jobs/legacy-walls.rb`).
  - AUTO-SET's 13.
  - `jobs/plan-scenes.rb` redraws the room dims, shows `CMS Room Dims (EST)` in the 3 plan scenes, hides it in the rest, and reframes the plan cameras.
- **Room dims:** `dims.rb`. New note text (Benton, verbatim), corner labels removed, wall labels moved onto clear floor.
- **Dimension images:** `Z:/Sketchup/ClientDrawings/Community Music School - renders/dimension-images/` (6 viewport PNGs, 2400 x 1800).
- **Render pipeline:** `render.rb` (WR_CMSRender) and `rt.py`.
  - `rt.py` renders one frame: `python rt.py OUT.png --page "NAME" --w 800 --h 600 --min 1 --thr 0.05 --ev 14.73 --sunmult 0`.
  - It never overwrites (it appends -2, -3 ...) and hands the frame to `../concept-art/finish.py`.
  - Tests are in `Z:/.../Community Music School - renders/tests/`.
- **Hero tuning:** `compare/hero-light-tuning.png` (before vs best), plus the log in `progress.txt`.
- **Scene plan:** `scene-plan.md`. Contact sheet: `compare/scene-contact-sheet.png` (gitignored; the window backdrops are photo-derived). Builder: `jobs/contact-sheet.py`; batch: `jobs/contact-tests.sh`.

## Read-first

1. `progress.txt` (the hero tuning log), then `scene-plan.md`, then notes.md "Booth, lights, scenes".
2. `lights.rb` header and `render.rb` (`match_width!` and the reverted-background note).

## Continue in this order

1. Benton reads `scene-plan.md` and the contact sheet, then decides render/skip, EV, and the caption text.
2. If he approves the fixes proposed there, apply them. The main one: `03-high` shows the lens emitters' black backs.
3. **Step 9, finals:** render the approved scenes at 2000 px or wider, one at a time. Use `rt.py` (EV 14.73, sun off) or the package with a per-row EV of 14.73 and the sun set off first. Read every frame. Never overwrite.
4. Step 10: update notes.md with the finals.

## Hazards (all paid for)

- **V-Ray INTERACTIVE blocks work (Benton's standing rule):** if V-Ray sits in "rendering" well beyond the expected time (1-minute tests finish in about 65 s), it is probably an interactive render. Stop it with `VRay::Command.stop_current_render`, confirm `renderer.state` is idle in a later job, and carry on without asking. Never call `in_process?` / `dr_enabled?`.
- **Photo-match scenes keep converting in-session:** their aspect-carrying cameras get re-expressed at the window aspect after scene selection or export passes (observed 3 times today). They are "skip" scenes; run `WR_CMS.photo_scenes!` before any save. Aspect-0 height cameras never convert.
- **First light audit right after a save or render can read short** (19 of 21, twice); a later job reads all 21. Always re-read in a separate job.
- **Plan labels and note are FLOOR TEXT** (3D, sized in inches, `dims.rb floor_text`). Screen text is a fixed pixel size and ran over the dims in Benton's wide window. The dimension strings are still screen text, so the two parallel Wall A rows touch at about 2 px/in (viewport); they are clean at 2400 x 1800.
- **Saving:** save with `m.save(m.path)` and `--write-root "Z:/Sketchup/ClientDrawings"`. Never use `file_new`.
- **Second-press kill (V-Ray light plugins):** removing lights and creating new ones in ONE job kills the new ones. The freed plugin names get reused, and V-Ray's deferred purge-by-name runs after the job.
  - Observed today: an in-job audit passed, then all 20 plugins were gone in the next job.
  - `place!` now places first and reaps last. **Always verify with `WR_CMS_Lights.audit` in a LATER job.**
- **Never hide the `WR Lights` tag in a job that can raise.** Always use `ensure`. It happened once today (dim-images); the tag was restored.
- **V-Ray framing:** superseded by the scene-camera fix above. `render.rb match_width!` now only reports; V-Ray renders exactly what the scene stores.
- **Environment:** do NOT override the V-Ray background. `override_gi/reflect/refract` are false, so a background write propagates into GI, reflection and refraction (observed, reverted). `bg_tex_color` is left at 0.7: inert, original value not recorded.
- **Global hidden state:** selecting any AUTO-SET or legacy scene leaves its walls hidden globally, and the photo scenes store no hidden state. `jobs/shots-nobooth.rb` shows every room piece before a photo-match shot.
- **Never `WR_CMS.run!` now:** a room rebuild makes new wall groups, and every scene's stored hidden walls would point at erased ones. Edit fittings in place, as `jobs/radiator2.rb` does.
- **Photo scenes after a render test of them, or after reopen:** their cameras come back with aspect 0 and a converted fov, so `check!` flags them. `WR_CMS.photo_scenes!` restores them. Both photo cameras are now inside or behind the booth.
- **Benton edits live:** re-read the model before each step. He loaded the studio lights and the Audimute panel mid-run.
- From the earlier run, still true: modals wedge the bridge; never call `in_process?` / `dr_enabled?`; only `:idleDone` means a frame; the desktop plugin is 1.67.7 (`CMS Room Dims (EST)` is kept off `WR-Dims*`); `compare/` and `tex/backdrop-*` are gitignored because they contain photo-derived imagery.

## Assumptions

- **Hero scene = `01-angled r`.** No existing scene shows the door side, the daylit window wall and a fixture together.
- **Sun off is correct for this room.** The windows are backed by the photo backdrops, so no sun can enter.
- The fill, daylight and bounce outputs are by eye at 800 px, not measured.
- Audimute placement is installer judgement; the N-wall contact is accepted by Benton.
- `Component#11` is taken to be the 2 x 4 Audimute panel.

## Open-questions

- **EV and sun for finals:** EV 14.73 with the sun off (this run), versus the package defaults (EV 12, sun untouched).
- **"Sphere Light#8"** (Benton's studio light LEDs) reads 243,200 / invisible = true. His lights do glow in the tests; he should check the value in the Asset Editor.
- **Tape figures** for the room: still the biggest dimensional risk.
