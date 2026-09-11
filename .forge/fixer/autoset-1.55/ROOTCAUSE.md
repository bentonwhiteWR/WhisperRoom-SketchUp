# Root cause: the four verify-autoset.rb failures on 1.54.0 — 11 Sep 2026

Live run: SketchUp 26.2.243, plugin 1.54.0, 121/125. Full log in
`../LIVE-autoset-1.54.0-2026-09-11.md`. Fixture: booth b1 at (24, 24); shell
x 24..120, y 24..84, z 0..84; door frame x 78..114, y 22..24 (centre 96, 23);
leaf x 114..117, y -14..24; vent y 84..86. Union bbox y -14..86, centre
(72, 36, 42), half-diagonal radius 81.043.

## 1. door.anchor_is_on_the_door_wall — HARNESS wrong (observed)
Assertion: `|frame y − b1.bounds.min.y| < 6` → `|23 − (−14)| = 37`. The −14 is
the leaf (observed in the fixture source). The door wall is the shell's −Y
face at 24; the frame centre at 23 is 1 in proud. Production is right.
Fix: measure against the `shell` group's bounds.

## 2. cam.front_is_square_to_the_door — HARNESS wrong (observed + derived)
Assertion took atan2(eye − booth centre). Eye `[96.0, −223.7, 72.3]`,
frame `(96, 23)` → from the frame the bearing is exactly −90.0 (observed x
equality); from the centre (72, 36) it is atan2(−259.7, 24) = −84.7 (derived,
matches the log). Aiming at the frame is by design (`:aim_at => :door`) and
`cam.front_is_NOT_aimed_at_the_booth_centre` asserts it. Fix: bearing from
the frame.

## 3 + 4. cam.interior_eye_* — PRODUCTION wrong, two defects

### 3a. The projection flip moved the eye (derived; closes to 3 dp)
`aim_interior`: eye = centre + dir·27 = (72, 9); target = centre − dir·0.45·81.043
= (72, 72.469). Observed eye y −223.12218; observed |target − eye| = 295.59;
72.469 − (−223.122) = 295.59 ✓ — the target is exactly where the code put it,
only the eye moved, along the view axis.

06-plan is aimed immediately before and leaves the view parallel with
`height = radius·2.3 = 186.399`. `aim_interior` did `set` then
`perspective = true`. Flipping parallel→perspective keeps the target and
sets eye distance = height / (2·tan(fov/2)) with the inherited 35° lens:
186.399 / (2·0.31530) = **295.59** ✓. 1.53.0's eye x 331.1 = 35.53 + 295.59 ✓
(same defect along +X, misread then as a bearing symptom).

Fix: `perspective`/`fov` before `set` in `aim_interior` and in
`WR_ProposalScenes.aim` (perspective branch).

Production `apply` is probably not affected (derived): the fresh path aims
twice (second aim onto an already-perspective camera), the re-aim path
selects the page first (restores its perspective camera). The harness's one
direct call is what hit it. No live evidence either way about a real
07-interior page since the plan went parallel at 1.53.0.

### 3b. The interior plane came off the union box (derived)
With the slide gone, eye y = 36 − (50 − 1 − 22) = 9, i.e. 22 in inside the
LEAF's outer edge (−14) and 15 in outside the shell face (24). `half` in
`apply` is the union box. Fix: `door_run` — the frame anchor's run from the
centre along the normal — names the plane; union box only when no door tag.
On the fixture the run is 13 < 23 so the centre clamp bites: eye (72, 36),
11 in clear of the interior face. The harness now wants min(22, 11) and
says so.

## Assumption that carries the fix
SketchUp `Camera#perspective=` true on a parallel camera keeps the target and
re-derives the eye from `height` and the current `fov`. Modelled in
`FakeCamera`; the model reproduces the live number to 2 dp on two
independent runs, which is the evidence. If the next live run still shows
295.59 in from the target, the model is wrong and so is the fix.
