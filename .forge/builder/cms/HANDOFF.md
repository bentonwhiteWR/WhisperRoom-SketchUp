# HANDOFF — Community Music School builder (desktop, 22 Sep 2026, 20:15; model saved 20:15:05)

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

- **Saving:** save with `m.save(m.path)` and `--write-root "Z:/Sketchup/ClientDrawings"`. Never use `file_new`.
- **Second-press kill (V-Ray light plugins):** removing lights and creating new ones in ONE job kills the new ones. The freed plugin names get reused, and V-Ray's deferred purge-by-name runs after the job.
  - Observed today: an in-job audit passed, then all 20 plugins were gone in the next job.
  - `place!` now places first and reaps last. **Always verify with `WR_CMS_Lights.audit` in a LATER job.**
- **Never hide the `WR Lights` tag in a job that can raise.** Always use `ensure`. It happened once today (dim-images); the tag was restored.
- **V-Ray framing:** AUTO-SET's 35 deg lens is applied across the SketchUp window's width (2169 x 859 here). V-Ray keeps the vertical fov, so a 4:3 frame is a 2x crop. `render.rb match_width!` fixes this at render time. The package's own render lane may still crop: unverified.
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
