# GOAL

## Mission
Re-light the booth renders as a REAL ROOM, not a product shoot. Benton's
direction, 11 Sep: office-building ceiling panel lighting on a regular grid as
the primary source, supported by INVISIBLE sphere lights scattered at assorted
positions and heights, roughly 4-5 ft out from the booth, some low some high.
Then run improve-and-re-score cycles against
`Z:\Sketchup\Proposals\test2\.rank\booth-render.rubric.md` to target 9.0.

## Done means
- The rig's primary source is a believable office ceiling: panels/troffers on a
  grid the way a real commercial ceiling is laid out, VISIBLE in frame, at
  ceiling height, not protruding through it.
- Fill comes from invisible spheres in an ASYMMETRIC scatter, not a symmetric
  photographic arrangement.
- No blown patches on plain wall. Hard fail per Benton's ruling R2.
- Overall 9.0+ with no dimension more than 2 below, confirmed by a cold
  re-score from a fresh agent that never saw the cycle history.

## Now
The photographic key/fill/rim approach is BEING REPLACED, not tuned. It stalled
at 5.7 over three cycles (c00-c02) and the diagnosis is in
`Z:\Sketchup\Proposals\test2\.rank\booth-render.scores.md`.

Two defects the old rig leaves behind, both must be cleared by the new one:
1. **The key light protrudes through the ceiling.** 24 in panel, tilted 58 deg,
   centre z 89.6, top edge ~99.8 in, in a 96 in room. Any fixture the new rig
   places needs a real ceiling clamp.
2. **`audit_scene` classes <= 30 lm as dead**, so a light cannot be turned fully
   off without voiding the frame. That blocked a legitimate test in c01. Fix
   the rule so an intentional zero is distinguishable from V-Ray's factory 30.

Benton also asked to go back to **opus** for the loop.

## Out of scope
- The foam material. Confirmed out, R4.
- Simply adding more ceiling fixtures and raising them — he tried it, it does
  not work, do not re-propose it.

## History
- 1.66.0 fixed the key light's aim (door-face normal, fan fallback) and proved
  the render pipeline linear and deterministic.
- 1.65.1 killed the end-of-batch modal on the interactive path.
- Benton's four rulings are at the bottom of the rubric file and override the
  anchors above them.
