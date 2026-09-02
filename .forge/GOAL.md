# GOAL

## Mission
**Fix audit finding 1 — the two booth build paths draw mirrored side walls on the
6060 / 6084 / 7272 / 7296.** Benton, 2 Sep 2026: "I would like to fix 1. the mirrored
walls bugs. Use fable." Silent, customer-facing: both builds close exactly and print
`exact`, so the window, vent and seam land at opposite ends of the side wall depending
on which panel button was pressed.

Benton's steer on how to settle the correct arrangement (2 Sep): panel order **depends on
the floor and ceiling layout**, and the **booth builder** (`booth-builder.html` in the
WhisperRoomQuote repo) renders all three accurately — drive it headlessly and read the
truth off it rather than asking him to adjudicate from a wall-only drawing.

## Done means
1. The correct wide-panel end is established **from the booth builder's own rendering**,
   for both families, with the floor panel seams and ceiling panel seams shown alongside
   the wall panels — not inferred from `wr-booth-data.rb` alone.
2. One owner for E/W panel order. Today `ASSIGN` (`scripts/build-booth-components.rb:1312-1400`)
   swaps slot ids while `gen-booth.py`'s `SWAP_TWO_PANEL_SIDE_WALL` swaps positions; they
   compose to a double swap on the standalone path and no swap on the share-link path.
   Either the E/W entries leave `ASSIGN`, or `ASSIGN` is keyed on position.
3. A pinned offline test, one case per catalogue key, asserting the standalone build and
   the share-link build put the wide panel at the same end. No such case exists today —
   that is why the 27 Aug regression never tripped anything.
4. The 50-key golden booth-matrix baseline is regenerated. It was captured through
   `ASSIGN` (`scripts/rbtest-live-booth.py:235`), so it currently records the defect as
   expected output.
5. `scripts/wr_tools/VERSION` bumped, committed and pushed.

## Now — 2 Sep 2026, DECIDED

**Benton's ruling, 2 Sep 2026 — the booth builder's layout is correct for all four models.**
Reviewing the headless captures at
https://claude.ai/code/artifact/52672c8d-40f9-445a-a592-d5712e44c217 he stated the invariant:

> Looking top-down, the larger floor component is on the left, the door is on the bottom
> (south) side, and on the left wall the lower piece — the one toward the door — is always
> the bigger wall. Same logic for the 6060.

So: **the wide floor section, the door frame, and the wide side-wall panel all sit at the
same end — the door end — on every split-run model.** One rule, both families, both side
walls. This supersedes the 28 Aug built-booth ruling that produced commit `a886105`.

Consequences:
- `MDL 6060 S/E` and `MDL 6084 S` in `scripts/wr-booth-data.rb` are **wrong** and must move
  to 40" at y 2–42, 16" at y 44–60. `gen-booth.py`'s `SWAP_TWO_PANEL_SIDE_WALL = {40,16}`
  (added in `a886105`) is reverted.
- `MDL 7272 S/E` and `MDL 7296 S` are already right in the data (46" at y 2–48); only the
  standalone `ASSIGN` path is wrong there.

Fixer on fable owns the change. The Researcher's evidence and seam figures are at
`.forge/researcher/booth-builder-panel-order.md`; its baton is `.forge/researcher/HANDOFF.md`.

## Facts established, 2 Sep 2026 (orchestrator, observed)
Read straight out of the part polygons in `scripts/wr-booth-data.rb`:

| model | door-end panel | far-end panel | vent slot |
|---|---|---|---|
| 7272 S/E, 7296 S | 46" (`E0`) | 22" (`E1`) | `E0` = door end |
| 6060 S/E, 6084 S | 16" (`E1`) | 40" (`E0`) | `E0` = far end |

Two things follow. **The data file already uses opposite wide-panel conventions between the
two families.** And **slot ids run in opposite directions** — `E0` is the door-end slot on
the 7272 and the far-end slot on the 6060 — which is the mechanism by which an id-keyed
`ASSIGN` and a position-keyed generator fight.

The door frame (`S0`, DRFRM) is always at the low-x end of the south wall: x 2..48 on the
7272, x 2..42 on the 6060 (observed).

## Rules that bind this work
- **Read `WhisperRoomQuote`, never write it.** Scratch scripts that drive its
  `booth-builder.html` live in the scratchpad or `.forge/<role>/`, never in that repo.
- No SketchUp, no V-Ray, no `ruby.exe` here. `scripts/rbparse.py` boots SketchUp's own
  CRuby DLL and gives a real syntax check plus pure-Ruby evaluation; run it before any
  commit touching `.rb`. `scripts/rbcheck.py` is a bracket counter, not a parser.
- Never invent a placement number. Never recommend a booth model.
- Push to `bentonwhiteWR/WhisperRoom-SketchUp` as part of finishing, not batched later.

## Out of scope
- The other 21 audit findings at `.forge/auditor/full-audit-2026-09-01.md`. Benton picks
  the next batch.
- The two owed batches, parked until finding 1 lands: the take-off docs slice
  (`skills/whisperroom-takeoff/SKILL.md`, `reference/takeoff-format.md`, DEVLOG for
  1.19.4–1.19.9, `.forge/builder/HANDOFF-takeoff-sheet.md`) and the six panel
  reuse/simplification cleanups on the 1.19.4–1.19.8 diff.
- The one-off client scripts and the 3D-print jigs.

## History
2026-09-01 — Full read-only audit of the plugin and skills shipped; 22 ranked findings at
`.forge/auditor/full-audit-2026-09-01.md`. Panel overhaul 1.19.4–1.19.8 and the take-off
review sheet 1.19.9 both shipped and installed.
2026-09-01 — Floor-plan intake mission parked at `.forge/GOAL-prev-floorplan-intake.md`.
2026-08-31 — Render look-development mission parked at `.forge/GOAL-prev-render-lookdev.md`.
2026-08-30 — Portal-parity / proposal-package mission parked at `.forge/GOAL-prev-portal-vray-mission.md`.
2026-08-27 — Enhanced/IEP two-shell mission parked at `.forge/GOAL-prev-iep-mission.md`.
