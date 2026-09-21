# HANDOFF — WAJMBAD orientation (round 2), 2026-09-21

Fixer. Plugin 1.74.0 → **1.75.0**. File: `C:\Users\bento\Documents\Claude\Sketchup\scripts\build-booth-components.rb`.

## Outcome

A cleared-model rebuild of the 102102 E test link, with no manual intervention, now places
`S1i` (`ENH WAJMBAD`) with exactly Benton's hand-fitted matrix — **observed** over the bridge,
twice in a row:

```
[1.0, 0.0, 0.0, 0.0,  0.0, -1.0, 0.0, 0.0,  0.0, 0.0, 1.0, 0.0,  48.25, 2.0, 0.0, 1.0]
box x 45.875..57.75  y 2.25..4.25  z 0.75..80.25
```

## Determinism — the placement was never non-deterministic

Three back-to-back 1.74.0 rebuilds (cleared model each time, same session) gave the identical
matrix `[-1,0,0,0, 0,-1,0,0, 0,0,1,0, 58.25,2,0,1]`, box x 48.75..60.625 (**observed**). `load DATA`
reassigns `WR_BOOTH_DATA::BOOTHS` on every build, and re-`load`ing the module re-evaluates its
constants (that is what the "already initialized constant" warnings are), so nothing survives
between builds to drift. `rotation()` uses `Transformation.axes` with a right-handed frame and
nothing else scales, so **1.74.0 had no code path that could produce a det −1 matrix** (**derived**
from the source). The record of an untouched first build producing the target was an artefact —
most likely read after the hand fix.

## What the target actually is (measured, not inferred)

- `place()` centres the *slab* it finds in the part on the slot. On `ENH WAJMBAD` that slab is a
  9.000 in face at authored x 0.5..9.5 (**observed**, `wall_slab` on the loaded definition) — the
  same 9 as `WAJMBAD_RUN_W`. Centred on the re-walked slot 48.75..57.75 that puts the box at
  45.875..57.75 *before any turn* — already the target box.
- The 2.875 overhang (11.875 box − 9 run, **observed**) is entirely at the authored low-run end
  (def x −2.375..0.5), which on this build is the door end. So the offset is the **full cap width
  at one end**, and it is not applied as a shift at all — `place()` already lands it.
- Target = `place()` output ∘ reflection across the wall plane through the slot centre
  (y → 6.5 − y). Benton's "flip red, move 2 7/8 toward the door" from the yawed state is the same
  thing arithmetically: 2·54.6875 − (58.25 − x) − 2.875 = x + 48.25.

## Code change

- `WAJMBAD_YAW` and `WAJMBAD_FLIP_SIDE` removed. New `WAJMBAD_LAP_MIN = 1.0` (lap-resolution floor).
- `wajmbad_plan` now records `:door_at` (`:low`/`:high` along the run axis).
- Pass 2: reflect across the wall plane (always); measure lap low/high; if the bigger lap is not
  at `:door_at`, also reflect across the plane square to the run (net = 180° yaw, proper rotation).
  Explicit 16-element matrices, no `Transformation.scaling`.
- Console prints `FIT-TESTED (Benton, 21 Sep 2026, 102102 E S wall R)` only for S wall + R side +
  no turn; everything else gets a `NOT FIT-TESTED` warning naming wall / side / door end.
- `rbparse.py`: 77 files parse, no failures.

## Unproven

- **L case** (S-wall L, N-wall R: door at the slot's high end). Step 2 fires and the part goes in
  end for end. Reasoned, never seen. Not assumed to be a mirror of R.
- **N wall R** takes the same path as the tested case but `place()` hands it the part a half turn
  round; flagged NOT FIT-TESTED.
- **E/W walls**: `place()` rotates the part a quarter turn; the lap end is measured there. Unseen.
- Whether `WAJMBAD_LAP_MIN = 1.0` is the right floor is a judgement (trim ≈ 0.25, leg = 2.875).

## Scratch model

Untitled scratch model in SketchUp 2026 has the 102102 E booth built by 1.75.0, zoom-extents,
nothing hidden.
