# GOAL

## Mission
Confirm plugin **1.54.0** is correct in the real application. 1.54.0 re-derived
`wall_axis` from the booth's wall shell instead of its union bounding box, which
anything protruding (the swung leaf at y -14, the vent housing at y 86) was
skewing. Every offline proof is green; nothing has been checked against SketchUp.

## Done means
- `verify-autoset.rb` run from **File > New** against 1.54.0, ~126 checks.
- `door.bearing_is_the_minus_Y_wall` PASSES. That single check confirms or
  refutes the 1.54.0 diagnosis; if the bearing is still 0.0 the root cause is
  wrong and everything downstream of it is suspect again.
- Any failures root-caused, fixed, VERSION bumped, committed and pushed.

## Now
All three Fixers landed and pushed as 1.55.0. Waiting on Benton to install and
run the three live checks. Every Ruby change in 1.55.0 is UNRUN.

One open question he alone can settle: how far the EFS silencer actually stands
past the seals. The measured part thickness derives 10 1/8, but the 1.42.0
DEVLOG entry was built to his own 8'-7 1/2" on a booth carrying the same parts,
which implies 6 7/16. 1.55.0 draws the newer instruction and prints an ACROSS
mismatch if the placed part disagrees.

## Out of scope
- WhisperRoomQuote (booth-builder.html) — read-only from here.
- The 53 open audit findings in `.forge/auditor/full-audit-2026-09-01.md`.

## History
- CP caster-plate datum reconciled 1.49.0; Enhanced-on-CP reads 7'-5 1/16".
- AUTO-SET shipped 1.48.0, verified live 10 Sep 2026 at 88/95.
- 1.50.1 → 1.54.0 fixed camera bearing, angled-shot pairing, and the wall plane.
- Codebase audit 10 Sep 2026: `.forge/auditor/*.md`.
