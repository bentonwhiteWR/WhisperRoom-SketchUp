# Community Music School — scene plan (proposal for Benton, 22 Sep 2026)

**UPDATE 20:30, scene-camera fix.** The AUTO-SET plates had stored a 14.24 deg lens (a close-up in the viewport). They were re-aimed by AUTO-SET itself and now store its intended 35 deg (07-interior 70).
- The contact-sheet tests below were rendered with a render-time compensation. They show roughly the framing the fixed scenes now give in a 4:3 frame, but not exactly: the fixed scenes are somewhat wider.
- Viewport check at Benton's window size: `compare/viewport-scenes-contact.png`.
- The fixed scenes need a fresh test before finals; the hero re-test is pending.

**UPDATE 22:10, Benton: "01b-angled room r" is the COVER HERO.**
- 01b: package mode render, ev 14.73. It is a camera inside the room, all walls shown, no void. Test: `tests/t01b-angled-room-v3-final.png`.
- "01-angled r": package mode skip (Benton had already set it; the scene is kept). It is logged in the revert record.
- No image pair was made for 01b: the dimensioned lane is 03-high (image), and the hero lane is a render.

Nothing below has been applied. The scene set, the scene names and every stored mark are exactly what AUTO-SET and the proposal package created. Benton decides.

**Sources:**
- Contact sheet: `.forge/builder/cms/compare/scene-contact-sheet.png` (gitignored folder, because the window backdrops are photo-derived). It holds one 800 px V-Ray test per distinct camera; an image plate and its `r` render plate share a camera.
- Tests: `Z:/Sketchup/ClientDrawings/Community Music School - renders/tests/c-*-final.png`.
- Lighting tuned on the hero scene: `compare/hero-light-tuning.png` and `progress.txt`.

## What per-scene text the export actually supports

Read from `scripts/proposal-package.rb` and `scripts/wr-autoset.rb` (read-only).

**Stored on the SketchUp scene:**
- The **scene name**, which becomes the file name. Render plates are written as `… render.png`.
- `WR_ProposalPackage` / **`mode`**: `render`, `image` or `skip`. If the key is absent, the scene is skipped.
- `WR_ProposalPackage` / **`ev`**: a float, EV 2–20.
  - Without it the package uses **EV 12** for rooms, and **EV 9** for any scene whose name matches `interior|inside|in-booth`.
  - This rig was tuned at **EV 14.73**. At EV 12 every frame would be about 2.7 stops too bright.
- `WR_AutoSet` / `token`, `plate`, `version`, `centre`: machine stamps, not text.
- Per-scene walls-hidden and annotation-hidden state. This is recorded in `manifest.json` (`groups_hidden`, `annotation_tags_shown` / `_hidden`), but it is not text.

**There is no caption, title or description field in the export.** It writes `manifest.json` plus `claude-prompt.txt`, which list file, scene, lane, size, status and the two-point state.

**All client-facing text lives in the proposal generator's `proposal-v2.json`:**
- `cover`: `eyebrow`, `headlineLead`, `sub`, `image`, `captionLead`, `caption`, `cards[] {label, value, sub}`, `calloutLead`, `callout`.
- `sections[]`: `num`, `model`, `boothOf`, `extra`, `lead`, `plates[] {image, view, caption}`.

The proposed text below is for `view` and `caption`, plus `captionLead` for the cover.

## Before any final render (applies to every `render` row)

1. **Set the V-Ray sun off.** It is off in the saved model now, and `rt.py --sunmult 0` sets it on every frame. The package never touches it.
   - With AUTO-SET's hidden walls it throws a sun wedge onto Wall D. The real room cannot get one, because the windows are backed by the photo backdrops.
2. **Render at EV 14.73**: either the package's `ev` on each render row, or `rt.py --ev 14.73`.
3. **Framing:** FIXED at the source (the scenes now store a 35 deg height lens). Viewport, package and V-Ray keep the same vertical fov. A 4:3 output shows less width than the very wide 2169 x 859 window, and nothing is cropped vertically.

## Plan, one row per scene

Types: **beauty** (V-Ray, perspective), **dimensioned** (plain SketchUp image with booth dimensions), **plan** (top-down), **photo-match**.

| # | Scene | Type | Recommend | Why (one line) | `view` | `caption` |
|---|---|---|---|---|---|---|
| 1 | Photo A - long view | photo-match | **skip** | Its camera now stands inside the booth; the test frame is black. | — | — |
| 2 | Photo B - corner view | photo-match | **skip** | Its camera is in the 17 in gap behind the booth; the frame is foam at arm's length. | — | — |
| 3 | 01-exterior (legacy) | beauty | **skip** | Booth small in a cut-away room floating in a black void; AUTO-SET 01-angled does this job better. | — | — |
| 4 | 02-dimensioned (legacy) | dimensioned | **skip** | Legacy plates hide the booth dims, so it shows no dimensions; the lens emitters' black backs show; black void. | — | — |
| 5 | 03-side (legacy) | beauty (parallel) | **skip** | Tiny in V-Ray (parallel framing does not carry over); duplicates 04-side. | — | — |
| 6 | 04-ventilation (legacy) | beauty (parallel) | **skip** | Shows the door side, not the vents; tiny; black slabs. | — | — |
| 7 | 05-plan (legacy) | plan | **skip** | Same framing, room dims and note as AUTO-SET 06-plan; keep one. | — | — |
| 8a | 01b-angled room r (new) | beauty | **render — COVER HERO** (Benton, 22:10), `ev` 14.73 | Inside the room, every wall shown, no void; the booth's door and window side, the daylit window wall and a fixture. | *(cover)* `captionLead`: "MDL 96144 E." | "The booth in the Community Music School classroom: the door with its window and a second window facing the room, with the classroom's windows beyond." |
| 8 | MDL 96144 E (components) 01-angled r | beauty | **skip** (was the hero; replaced by 01b; kept) | The camera stands outside the room and sees a black void past the hidden walls. | Door, window and entry step face the camera; foam and Audimute visible through the glass; neutral light, no blooms (tuned frame). | *(cover)* `captionLead`: "MDL 96144 E." | "Exterior render in the Community Music School classroom: the door with its window, a second window and the entry step, with the interior foam and panels visible through the glass." |
| 9 | MDL 96144 E (components) 01-angled | dimensioned | **skip** | Its height string is clipped at the frame edge; 03-high shows all three strings in full. | — | — |
| 10 | MDL 96144 E (components) 02-front r | beauty | **render**, `ev` 14.73 | Square-on to the door wall; everything on that wall reads; test clip 1.9 %, acceptable. | "Front View" | "Front view of the door wall: door with window, a second window, and the entry step. Acoustic foam and Audimute panels are visible inside." |
| 11 | MDL 96144 E (components) 02-front | dimensioned | **skip** | Shows only the width string; 03-high carries all three. | — | — |
| 12 | MDL 96144 E (components) 03-high r | beauty (high) | **skip, or render only after fix A** | The lens emitters show black backs from above with the ceiling hidden; black void past the cut-away walls. | "High View" | "High view of the booth in the classroom, showing the roof, the door wall and the ventilation ducting on the end wall." |
| 13 | MDL 96144 E (components) 03-high | dimensioned | **image** | All three booth dimension strings are fully legible. | "Dimensioned View" | "Dimensioned exterior: 12' 7 1/2" x 8' 7 1/2" footprint, 7' 5 1/16" overall height." |
| 14 | MDL 96144 E (components) 04-side r | beauty | **render**, `ev` 14.73 | End wall with its ventilation duct and fan; the classroom's window wall behind gives the daylight. | "Side View" | "Side view: the ventilation duct and fan on the end wall, with the classroom's windows beyond." |
| 15 | MDL 96144 E (components) 04-side | dimensioned | **skip** | Duplicate camera; 03-high is the dimensioned plate. | — | — |
| 16 | MDL 96144 E (components) 05-ventilation r | beauty (rear) | **render after fix B**, `ev` 14.73 | The rear plate the pack needs, but the back face reads near-black (dark fraction 0.32): Wall D is hidden and nothing bounces into the gap. | "Rear View & Ventilation" | "Rear view: ventilation ducting on the back wall and on the end wall." |
| 17 | MDL 96144 E (components) 05-ventilation | dimensioned | **skip** | Duplicate camera. | — | — |
| 18 | MDL 96144 E (components) 06-plan r | plan | **skip** | V-Ray draws no dimensions or notes, and its parallel framing renders the room tiny in a black void. | — | — |
| 19 | MDL 96144 E (components) 06-plan | plan | **image — CLOSES THE PACK** | Every room dimension is shown, each marked EST., with the note. | "Top-Down Floor Plan" | "Top-down plan of the booth in the classroom. Host room dimensions were not provided: all room dimensions are estimated from client photos (±1 ft) and must be confirmed on site." |
| 21 | 08-interior corner (new, Benton) | beauty (interior) | **render**, `ev` 14.73 | Photo B's angle from the booth's back corner. Door and window with the classroom readable through both; the Audimute panel and foam read. Watch-out: Benton's studio lights glow lavender and clip the ceiling near them (6.2% clipped at EV 14.73). Not a package row yet (no `mode` set). | "Interior" | "Interior from a back corner of the booth, looking toward the door and window, with the classroom visible through the glass." |
| 20 | MDL 96144 E (components) 07-interior | beauty (interior) | **render**, `ev` 14.73 | Back wall flat-on: acoustic foam with two Audimute panels between the sheets. The test reads well at 14.73; the package default for this name would be EV 9, which would blow it out. | "Interior" | "Interior back wall: acoustic foam with Audimute panels between the sheets." |

Resulting pack, in the house order:
1. hero, 01b-angled room r
2. dimensioned, 03-high image
3. front, 02-front r
4. side, 04-side r
5. rear and ventilation, 05-ventilation r (after fix B)
6. interior, 07-interior
7. plan, 06-plan image

## Fixes found by the one-off tests (listed, not chased)

- **A. Black emitter backs in top-down and high scenes** (03-high, both plans, legacy 02/04).
  - Cause: the four *visible* lens emitters are one-sided, so from above, with the ceiling hidden, the camera sees their unlit backs.
  - Fix: in those scenes, also hide the four `lens (visible)` instances in the scene's hidden objects. The invisible 92% emitters stay and keep lighting the room.
- **B. Dark rear face in 05-ventilation.**
  - Cause: Wall D is hidden, so the 17 in gap behind the booth gets no bounce.
  - Fix: a Wall D bounce stand-in, the same device as the tuned Wall C one (an invisible panel inside Wall D's thickness, facing the room).
- **C. (NOW THE TOP BLOCKER FOR THE HERO) Black void where a camera sees past the room's floor edge.** After the camera fix the hero is framed correctly and wider, so the void is about 29% of `hero-after-camfix` (left and bottom). Options for Benton:
  - a hand-set hero camera INSIDE the room, so no walls need hiding (it would not be an AUTO-SET plate);
  - the sun back on, which brings a light-gray sky background but also the sun wedge;
  - crop in post.
- Original note on C: (bottom-left of the hero; around the high, plan and legacy views).
  - Cause: with the sun off, V-Ray's sun-linked sky background is black.
  - A background override was tried in tuning and REVERTED: V-Ray propagated it into the GI and reflection environments.
  - Options: accept it, crop it in post, or tighten the framing.
- **D. Studio lights (Benton's):** they glow in the tests, visible through both booth windows. Their LED sphere plugin `/Sphere Light#8` reads intensity 243,200, invisible = true; worth a look in the Asset Editor. Not edited.

## Caption discipline check

- Captions say only what the frames show.
- No left/right claims ("a second window", "on the end wall", "beyond").
- No prices, no "soundproof", no STC.
- The only numbers are the booth dimension callouts, transcribed exactly as drawn: `12' 7 1/2"`, `8' 7 1/2"`, `7' 5 1/16"`.
- Room dimensions appear only on the plan, and are called estimated.
- **Invented or assumed, flagged:**
  - "Community Music School classroom" as the room's name.
  - "Audimute panels" is the component Benton added; whether the four modelled panels are the full AP 96144 package is not known.
  - "entry step" is the part name `Step.skp`.
