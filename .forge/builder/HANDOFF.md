STATUS: READY

# v2 update (afternoon, 21 Oct): sections reordered, door one section in
Benton: "the 2' section needs to be closer on the other side. The door needs to be shifted one section in." The 2' section stays a centre section, next to the corner-end side section.

## Produced (v2)
- **Model:** the same Corner Platform `.skp`, saved after every step. The original is still untouched.
- **Images:** both re-exported, flattened and viewed. The top-down has 28 dims, and the NEW walls are near-black on `WR-Room-New`. The hero is still a SketchUp export, labelled as not V-Ray.
- **New scripts:** `s8-sections.rb` (the reorder) and `s9-retire-v1.rb` (moves the v1 room and dims to the hidden tag `Walsh Corner v1 21 Oct`).
- **Edited scripts:**
  - `geom.rb`: PLAT is now 72.37-118.37.
  - `s3-room.rb`: applies the dark material.
  - `s6-dims.rb`: the door chain now reads live from N3i, and two dims were relocated.
- **Notes:** `clients/walsh-construction/notes.md` gains the section "v2: section reorder". It has the survey table, the moves, the hidden pieces, wall table v2 and the run order.

## Sections (observed)
- **Front:** N0 window / N1 window / N2 19 / N3 door became N0 window / N2 19 / N3 door / N1 window.
- **Back:** S0 / S1+EFS / S2 22 / S3 became S0 / S2 22 / S1+EFS / S3.
- **Vent walls:** unchanged. S1's EFS moved +24". The W0 EFS did not move.
- **BOM:** unchanged.

## Wall table v2
| Run | Ours | Architect |
|---|---|---|
| Exterior | 32'-0" | 32'-0" |
| NEW corner wall | 9'-2 5/8" + 2'-9 5/16" = 11'-11 15/16" | 9'-1" MIN CLR |
| NEW front wall | 6'-11" | ~7'-0" |
| NEW step wall | 3'-10" | ~3'-3" |
| NEW zone wall | 4'-8 5/8" | ~4'-8" |
| NEW angled wall | 8'-5 9/16" | not dimensioned |
| South wall | 10'-10" + 15'-0 3/8" | not dimensioned |
| West wall | 18'-11" | 18'-11" |
| NW angled wall | 13'-8 7/8" | not dimensioned |

- **Fit:** the platform (s 84-130) is now inside the alcove. The ramp (s 130-175.6) runs toward the open end and clears the start of the angled wall by 1".
- **Option T:** moot.

## Open-questions (v2)
- **Interior AP/foam:** needs a re-layout. Audimute2x4 front, Audimute2x4 back and Foam S1i are HIDDEN, not deleted, and carry the attribute `WalshCorner/hidden_by`.
- **EFS proximity:** the S1 and S3 silencer boxes are about 1/2" apart, with about 2" of x overlap. I saw no intersection visually, but did not measure it.
- **Wide-panel memory rule:** the door is now in a centre module, not at an end. Confirm whether this matters for a 96168.
- **Still needed from the client:** the ceiling height and the pocket door.

---
# v1 handoff (morning, 21 Oct). Superseded where v2 differs.

# Builder handoff: Walsh Construction Tech Lab, corner platform layout (21 Oct 2026)

Brief rev 2 (Benton: "Idk just draw the room as close to their drawing as possible. The black walls can move."). Only the platform + ramp option is drawn. Sarah's Zoom is at 1:30 pm. Built live over the bridge, saved as a new file, and surveyed. Nothing is committed.

## Produced
- **Model (new file):** `Z:\Sketchup\ClientDrawings\Walsh Construction Tech Lab MDL 96168 E - Corner Platform.skp`. It was saved after every step.
- **Original:** `Z:\Sketchup\ClientDrawings\Walsh Construction Tech Lab MDL 96168 E.skp` is untouched (12 Oct 22:13, 9,291,234 bytes).
- **Images** in `Z:\Sketchup\Proposals\Walsh Construction Tech Lab MDL 96168 E - Corner Platform\`. I flattened both onto white and viewed both.
  - `6_Platform 06 TopDown.png` (1899x1898): the dimensioned SketchUp top-down, with 27 dims. It is legible. There is minor crowding at the top "11 5/8"" and at "2' 9 5/16"".
  - `1_Platform 01 HeroRender (SketchUp, not V-Ray).png` (1920x1080): a plain SketchUp export, not a V-Ray render. It shows the open end of the booth with the platform and ramp.
  - `Corner Platform plan (offline, not SketchUp).png`: SUPERSEDED. Its walls are the same, but it draws a 48" ramp and a 44" platform. The measured values are 45 5/8" and 46".
- **Notes:** the "21 Oct revision" section of `clients/walsh-construction/notes.md` was rewritten with the as-found structure, measured values, wall table, moves, assumptions, open questions, scenes and run order.
- **Scripts** in `.forge/builder/walsh/corner/`.
  - Steps that ran: `survey.rb`, `s0-saveas.rb`, `s2b-retag.rb`, `s4b-booth.rb`, `s3-room.rb`, `s6-dims.rb`, `s7-scenes.rb` and `flatten.py`.
  - `s2-retag.rb` and `s4-booth.rb` assumed the wrong structure and were NOT run.

### Wall table (interior faces, as built)
| Run | Ours | Architect |
|---|---|---|
| Exterior, apex to corner wall | 32'-0" | 32'-0" |
| NEW corner wall | 9'-2 5/8" + 2'-9 5/16" = 11'-11 15/16" | 9'-1" MIN CLR (first run) |
| NEW front wall | 7'-0" | ~7'-0" |
| NEW step wall | 3'-10" | ~3'-3" |
| NEW zone wall | 4'-7 5/8" | ~4'-8" |
| NEW angled wall | 8'-5 9/16" | not dimensioned |
| South wall | 10'-10" + 15'-0 3/8" = 25'-10 7/16" | not dimensioned |
| West wall | 18'-11" | 18'-11" |
| NW angled wall | 13'-8 7/8" | not dimensioned |

**Moves away from the architect:**
- The front wall moves +1 5/8", from 9'-1" to 9'-2 5/8". The shell face is at 9'-1 5/8".
- The zone wall moves +8 5/8". This makes the step wall 3'-10" instead of about 3'-3", so it clears the 46"-deep platform by 1".

The measured values moved no black wall.

## Read-first
- `clients/walsh-construction/notes.md`, section "21 Oct revision".
- **Live structure:** ONE room at the origin, and TWO booths at the same spot. The scenes switched between the booths with entity-hidden flags.
  - Old room and lights: hidden tag `Walsh Old Room 12 Oct`.
  - Old dims: hidden tag `Walsh Old Dims 12 Oct`.
  - Door-ramp booth: hidden tag `Walsh Ramp Option 12 Oct`.
  - Nothing was deleted.
- **Ramp direction:** the ramp runs toward the booth's open end. `Component#17` was mirrored about booth-local x 143.37. The coordinator confirmed this direction on 21 Oct.
- **Bridge traps:**
  - `run` copies the script, so load each step through a one-line `load "<abs path>"` wrapper.
  - A bare `m.save` is refused. Every step saves through `WalshCorner.save`, which writes only to the Corner Platform path.
  - Pass `--write-root Z:/Sketchup/ClientDrawings`, and `Z:/Sketchup` for s7.
- **Disclosure:** earlier this session I overwrote the previous working-tree `HANDOFF.md` without reading it. Its contents cannot be recovered.
- **Disclosure:** while splicing the notes, a failed `cat` truncated `notes.md`. Lines 1-212 were restored from `HEAD`, which matched the pre-edit file (275 lines with the 21 Oct section at line 213). The diff touches only the 21 Oct section.

## Assumptions
| Value | Provenance |
|---|---|
| Platform 3'-10" x 46", top 3.73" above the floor | observed (live model) |
| Ramp 45.61" (3'-9 5/8") x 46" | observed |
| Door N3: 3'-8 1/2" opening, 4 1/4" off the open-end corner | observed |
| Front hardware FP = 0 (N0/N1 end at y 97.75) | observed |
| EFS 10" proud on the S face and the W0 end, 1 5/8" to each wall | observed |
| Shell 11 5/8" off both walls | derived (layout choice) |
| 32'-0" is the apex to the corner wall's interior face; 18'-11" is interior to interior | assumed (architect figures) |
| Step wall at 7'-0" and angled wall at 11'-7 5/8" along the exterior wall | derived (scaled from a 239 px capture, +/-6") |
| Zone wall 4'-7 5/8" | assumed (scaled) |
| Pocket door 3'-0", 1'-0" off the corner wall, swinging into the pocket | estimated |
| Door 24 at 4" to 3'-4" from the SW corner | assumed |
| Ceiling 8'-0" | assumed (house default) |

## Open-questions
- **Platform exposure.** Door N3 is at the open end of the booth. As a result, most of the platform and all of the ramp sit in the open Tech Lab. The architect's alcove holds only the first 7 5/8" of the platform.
  - **Option T** shifts the zigzag to follow our door: step wall at about 11'-0 5/8", angled wall at about 15'-6 5/8", and the angled wall's foot about 5'-9" from the SW corner. Door 24 is still clear.
  - Benton to choose.
- **Stale scenes:** `Platform 03 BoothDims` and every `Ramp ...` scene are still aimed at the 12 Oct layout.
- **Client figures still needed:** the real ceiling height and the pocket door's size and position.
