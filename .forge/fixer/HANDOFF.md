# HANDOFF — Fixer, AUTO-SET live failures on 1.54.0 — 11 Sep 2026

## Produced
- `scripts/wr-autoset.rb`: `aim_interior` sets projection/fov BEFORE `set()`
  (the parallel→perspective flip was re-deriving the eye 295.59 in from the
  target); new `door_run`; `interior_eye_dist(half, radius, az, frame_run)`
  takes the door-wall plane from the frame anchor, union box only as fallback;
  `aim_plate` hands the anchor to `aim_interior`.
- `scripts/proposal-scenes.rb`: `aim` perspective branch — projection/fov
  before `set()`. Parallel branch unchanged.
- `scripts/rbtest-autoset.py`: `FakeCamera` models the flip, `FakeView.new(true)`
  is the post-plan parallel view, `cam()` takes an anchor; checks `in11 cm19
  in12 in12b in13 in14 in14b`; 164 → 171, all green; 5 mutants killed by name
  (`.forge/fixer/autoset-1.55/mutants.py` re-runs them).
- `.forge/builder/verify-autoset.rb`: `door.anchor_is_on_the_door_wall` and
  the two `cam.interior_eye_*` checks measure the fixture's `shell` group, not
  the union bbox; `cam.front_is_square_to_the_door` measures the bearing from
  the frame, not the booth centre. Parsed clean with `rbparse.py`.
- `DEVLOG.md` entry (top). `.forge/fixer/autoset-1.55/ROOTCAUSE.md`.
- **VERSION NOT bumped, NOTHING pushed** — GOAL.md (orchestrator, 11 Sep):
  two Fixers concurrent, the orchestrator bumps once and pushes after both
  land. Committed locally, only my files staged; `wr-overlays.rb`,
  `build-booth-components.rb`, `rbtest-overlays.py`, `GOAL.md` and the other
  Fixer's `.forge` files were left untouched and unstaged.

## Read-first
1. `.forge/fixer/autoset-1.55/ROOTCAUSE.md` — the arithmetic that decided it.
2. DEVLOG top entry.
3. `scripts/wr-autoset.rb` `aim_interior` / `interior_eye_dist` / `door_run`.

## Assumptions
- **A1 (load-bearing, unrun):** SketchUp `Camera#perspective = true` on a
  parallel camera keeps the target and re-derives the eye from `height` and
  the current `fov`. Reproduces the live number to 2 dp on the 1.53.0 and
  1.54.0 runs. Everything else follows from it.
- A2: the fixture's `shell` group bounds are model-space (b1 has an identity
  transform — boxes drawn at absolute coords inside `add_group`). If not, the
  three shell-based checks fall back to `bbx` and read as the union again.
- A3: a real booth's DRFRM part lies in the door wall plane, so `door_run`
  names that plane on real booths too (observed on the fixture only).
- A4: production `apply` was not shipping the slid eye (double aim + select
  first). Derived, not observed — see ROOTCAUSE §3a.

## Open-questions
- **Benton must re-run `verify-autoset.rb` from File > New.** Expect 125
  checks. Watch: `door.anchor_is_on_the_door_wall` (frame y 23.0 vs shell
  face 24.0), `cam.front_is_square_to_the_door` (−90.0 from the frame),
  `cam.interior_eye_is_inside_the_shell` (eye ≈ [72.0, 36.0, 42.0]),
  `cam.interior_eye_clears_the_interior_face` (11.00, clamped, wants 11.00).
  `cam.interior_looks_dead_level` should still read a pure +Y direction of
  ~72.5 in (36.47 + 36.0), not 295.59.
- If the interior eye still stands 295.59 in from its target, A1 is wrong:
  the next thing to try is re-issuing `cam.set` AFTER the flip as well.
- Should the never-past-the-centre clamp use something better than the union
  centre? On a booth with an open leaf it bites early (fixture: 11 in instead
  of 22). Not changed here — a taste call for Benton, and the 22 is his.
