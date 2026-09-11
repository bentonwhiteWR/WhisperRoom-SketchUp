# LIVE verify-autoset.rb against plugin 1.54.0 — 11 Sep 2026

SketchUp 26.2.243, plugin 1.54.0, mask=384. Run by Benton from File > New.
**121 of 125 PASS** (previous live run was 112/124 on 1.53.0).

## The check 1.54.0 existed to satisfy — PASSES
```
PASS door.anchor_found                    — [[96.0, 23.0, 42.0], -90.0]
PASS door.bearing_is_a_wall_normal        — -90.0
PASS door.bearing_is_the_minus_Y_wall     — -90.0
```
The wall-plane fix (wall_axis off the wall shell rather than the union bbox) is
confirmed live.

## The four failures, verbatim
```
FAIL door.anchor_is_on_the_door_wall      — frame y 23.0 vs booth min y -14.0
FAIL cam.front_is_square_to_the_door      — eye at -84.7 deg, door at -90.0 deg
FAIL cam.interior_eye_is_inside_the_shell — [72.0, -223.12217541803528, 42.0]
FAIL cam.interior_eye_clears_the_interior_face — 208.12 in clear, wants 22.00
```

## Supporting numbers from the same run (all observed)
- Booth union bbox min y = -14.0; the DEVLOG 1.54.0 entry records that y -14 is
  the swung door leaf and y 86 the vent housing, with the real wall shell at
  y 24..84. Booth centre (72, 36), roof z 84, floor z 0.
- `cam.plates_have_DIFFERENT_cameras` — 01-front eye `[96.0, -223.7, 72.3]`.
- `cam.front_targets_the_door_frame` PASSES — target x 96.0 vs frame x 96.0.
- `cam.front_is_NOT_aimed_at_the_booth_centre` PASSES — target x 96.0 vs
  booth centre x 72.0.
- `cam.front_stands_back` PASSES — 260.8 in.
- Interior plate came from the forced-interior run on booth `MDL 9902 E VERIFY-2`.
  `cam.interior_looks_dead_level` direction `[0.0, 295.59, 0.0]`,
  `cam.interior_up_is_world_vertical` `[0.0, 0.0, 1.0]`, perspective, fov 70.

## Coordinator's first read — treat as a HYPOTHESIS, not a finding
1. `door.anchor_is_on_the_door_wall` compares the frame's y against the booth's
   **union** min y (-14.0), which is the swung leaf, not a wall. That is the exact
   mistake 1.54.0 fixed in the production code; the assertion may still carry it.
   A frame at y 23.0 against a shell spanning y 24..84 reads as the frame sitting
   ~1 in proud of the wall face, which is what you would expect.
2. `cam.front_is_square_to_the_door` reports -84.7 deg. atan2 from the booth
   centre (72, 36) to the front eye (96, -223.7) is -84.7 deg; from the door
   frame (96, 23) to the same eye it is exactly -90. The assertion appears to
   measure the bearing from the booth centre while the camera is deliberately
   aimed at the frame — and the adjacent check
   `cam.front_is_NOT_aimed_at_the_booth_centre` asserts precisely that it must not
   use the centre. The two checks contradict each other.
3. The two interior failures look like a **real defect**: eye
   `[72.0, -223.12, 42.0]` is the booth centre in x and z but 223 in out on -y,
   i.e. standing well outside the booth looking in, rather than inside the shell.

Hypotheses 1 and 2 would mean the harness is wrong and the plugin is right.
**Do not act on that reading without opening the code.** The 1.53.0 triage in
DEVLOG.md was confidently wrong in exactly this shape and sent a session chasing
a bug that did not exist.
