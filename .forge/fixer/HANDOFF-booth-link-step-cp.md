# HANDOFF — Fixer → Benton: the step loads, and a CP booth is no longer 4 3/4 low

2026-09-11. Benton: *"The Step is not loading at all. Also, booths with a CP
need to start up higher when loaded. They need to load up 4 3/4" higher than
they are"*. **One cause, both symptoms. Unrun in SketchUp.** VERSION not
bumped here (orchestrator's).

## Produced
- `scripts/wr-overlays.rb` — `place_step`'s console line no longer names
  `fl_bottom` (a `place_all` local → `NameError` on every CP + step build
  since 1.45.0, raised after the plates went in and before `add()`); it
  prints the threshold as `-ground`. `place_all` fences the step in its own
  `rescue StandardError`, so a step failure is a named warn and can never
  again discard `casters_in`.
- `scripts/build-booth-components.rb` — the `OVERLAYS FAILED` warning says
  the booth is grounded without the caster datum (that is what the lost
  `casters_in` did: `booth_lift(false, …)` = 1.3125 instead of 6.0625,
  plates hanging 4.75 under the floor — Benton's exact figure).
- `scripts/rbtest-overlays.py` — group 8 runs `place_step` end to end (36
  checks, was 33) against real `Geom` stubs; fence scan; both mutants killed.
- `.forge/fixer/repro-step-nameerror.py` — the standalone reproduction (FAIL
  on the old line, PASS now, in the CRuby 3.2 DLL).
- `.forge/fixer/ROOTCAUSE-booth-link-step-cp-2026-09-11.md` — the gate table.
- `.forge/builder/verify-booth-link-step.rb` — **the live check, Benton's to
  run** (Untitled model; builds 7296 E with plate + step, then step only;
  ~20 checks; erases both).
- DEVLOG entry at the top (new `2026-09-11` section).

## Read-first
1. `.forge/fixer/ROOTCAUSE-booth-link-step-cp-2026-09-11.md` — the sentence
   and the gates ruled out.
2. `scripts/wr-overlays.rb` `place_step`'s print comment and `place_all`'s
   `FENCED` comment — the two places that must never regress.
3. **Do not add 4.75 anywhere.** `CP_BOOTH_LIFT` was right and was applied on
   every step-less CP build (live 10 Sep, 14/14). It was LOST on the step
   path, not under-sized. Adding it would put a step-less CP booth at 9.5.

## Assumptions (not observed)
- `Step.skp` measures like `StepFront.skp` (44 × 12 × 5, tread on top) — the
  harness uses that box; the builder measures the real part and warns if the
  depth is not within 1 in of 12. Not probed here.
- `Geom::Transformation.axes(origin, x, y, z)` maps the standard axes onto
  the given ones (columns) and `a * b` applies `b` first — the stubs are
  written to the API docs; if SketchUp's convention differs the step lands
  turned, and the live script's "near face on the door face" check says so.
- Instance naming `"<id>  <part>"` (outer walls) and `"Step  <door id>"` — read
  from `build-booth-components.rb:2751` and `place_step`; the live script
  finds both by those names.

## Open-questions
- **Benton runs `verify-booth-link-step.rb`** and pastes the whole console —
  the `STEP  Step.skp …` line and the absence of `OVERLAYS FAILED` above the
  checks are half the evidence.
- Tread facing (`STEP_FRONT_AWAY`) and leaf-vs-frame (`STEP_ALONG_OFFSET`):
  still the 1.45.0 unconfirmed rulings, one constant each.
- The ramp + step case (`…WADoorWithRamp`) is proven only offline (refused by
  name); no live build with a ramp door is in the script.
