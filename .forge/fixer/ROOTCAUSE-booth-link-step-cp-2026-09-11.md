# ROOT CAUSE — "the Step is not loading" and "CP booths load 4 3/4 low", 11 Sep 2026

Benton: *"Take a look at the load booth link. The Step is not loading at all.
Also, booths with a CP need to start up higher when loaded. They need to load
up 4 3/4" higher than they are"*

## One sentence

`place_step`'s console line (`wr-overlays.rb`, the `puts format('  STEP …')`)
referenced `fl_bottom`, a local of `place_all` and not of `place_step`, so on
the first build that got the step past every gate it raised `NameError` after
the caster plates were placed and before `add()`; `place_all` had no fence, so
the exception reached `build_booth`'s `rescue Exception`, which discarded
`place_all`'s return value — `casters_in` included — and the ground pass then
lifted the booth by the no-caster 1.0 / 1.3125 instead of 5.75 / 6.0625:
**no step, and a plated booth exactly `CP_BOOTH_LIFT` = 4.75 low, plates
hanging under the floor.**

## Reproduced (observed, CRuby 3.2 DLL — `.forge/fixer/repro-step-nameerror.py`)

Unfixed file:

```
step S raised: undefined local variable or method `fl_bottom' for WR_Overlays:Module
caller: overlays FAILED casters_in false lift 1.0000 (plates in the model hang at -4.7500)
step E raised: undefined local variable or method `fl_bottom' for WR_Overlays:Module
STEP line: (none printed)
```

Fixed file:

```
step S placed 1 box 27.00..71.00 -12.00..0.00 -5.75..-0.75 warns 0
caller: overlays ok casters_in true lift 5.7500 (plates in the model hang at 0.0000)
step E placed 1 box 100.88..112.88 27.00..71.00 -6.06..-1.06
STEP line: STEP Step.skp 44.00 x 12.00 x 5.00 … threshold 5.75 …
```

## Gates ruled out, in series (each one alone would give the same symptom)

| gate | finding | how |
|---|---|---|
| `sp` in the link | `V3_FLAGS` bit 11 = `sp`; `overlay['step'] = payload['sp'] == 1` | read, `booth-from-link.rb:296, 1090` |
| door found | doors are `k == 'panel'` layout parts; `kind_of(/Door/) == :door`; `:inner` false on the outer shell | read, `booth-from-link.rb:368`, `wr-overlays.rb:947` |
| ramp beats step | `/WithRamp/` only; a plain `Right46Door` is clear | harness `step block 0/1/1/1` (observed) |
| `casters_in` | true when `place_casters` returned > 0 — verified live 10 Sep (14/14) on 7296 E | DEVLOG 1.49.1 (reported) |
| `Step.skp` present | on both `P:` and `Z:` `NewMasterComponentList`, 196 062 bytes, 10 Sep 22:34 | `ls` (observed) |
| `load_def` | case-insensitive glob fallback; returns nil only if the file is missing | read |
| `geom_extents` | faces walked through `collect_faces`; nil only on an empty part | read; unmeasured here (Step.skp not probed) |
| **the print line** | **`NameError` on `fl_bottom`** | **observed in the DLL** |
| placement position | with the line fixed the box lands where `step_seat` predicts on S and E walls | harness group 8 (observed) |
| swallowed? | not swallowed — surfaced as `OVERLAYS FAILED — NameError …` in the console, easy to miss under the build noise | read, `build-booth-components.rb` rescue |

Why nothing caught it: `rbparse.py` is a parser (an undefined local is a
runtime `NameError`, not a syntax error), `rbtest-overlays.py` lifted only the
pure step helpers and never ran `place_step`, and `verify-caster-lift.rb`'s
live build carries no step, so the line never executed anywhere before Benton.

## Why Benton's 4 3/4 is NOT a second lift

`CP_BOOTH_LIFT = 4.75` was applied correctly on every CP build **without** a
step (live 10 Sep: mat at 4.75, ceiling 89.0625). With a step in the link the
booth was lifted 1.3125 (Enhanced) instead of 6.0625 — short by exactly 4.75.
Adding 4.75 to the constant would have put a step-less CP booth at 9.5 and
left a step-with-CP booth still 4.75 low. The fix restores the one lift; no
number changed.

## Fix (minimal)

- `scripts/wr-overlays.rb` `place_step`: `fl_bottom - ground + 1.0` → `-ground`
  (the threshold is the floor top on the wall plane, booth-local 0 by
  `DECK_TOP_Z`; same number, no foreign local).
- `scripts/wr-overlays.rb` `place_all`: the step call is fenced in its own
  `rescue StandardError` → `STEP (sp) not placed: place_step raised …`, so a
  future step bug is a missing step, never a moved booth.
- `scripts/build-booth-components.rb`: the `OVERLAYS FAILED` warning now says
  the booth is grounded without the caster datum.

## Checks

- `rbtest-overlays.py`: group 8 lifts `place_step` verbatim and runs it against
  real `Geom` stubs — 36 checks + the fence scan. Mutants: the 1.45.0 line put
  back → whole transcript `FAIL undefined local variable … fl_bottom`; fence
  removed → `FAIL (lift leak) place_all's step block does not fence …`.
- Live: `.forge/builder/verify-booth-link-step.rb` (Benton).
