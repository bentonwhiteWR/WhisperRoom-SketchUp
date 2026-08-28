# HANDOFF — Proposal scene generation research

2026-08-27, Researcher.

## Produced

- `.forge/researcher/proposal-scene-generation.md` — the full findings: diagnosis of
  `scripts/proposal-scenes.rb` (four named defects, including a coordinate-frame bug in
  its door-heading code), the per-plate camera arithmetic for the mandated five-plate
  list, the camera-standoff method with its escalation ladder, the reusable-code
  inventory, the four-booth analysis, and the recommendation: **fix
  proposal-scenes.rb, do not build a second generator.**
- `.forge/researcher/HANDOFF-scene-generation.md` — this file.

## Read-first

1. `.forge/researcher/proposal-scene-generation.md` (the deliverable).
2. `scripts/proposal-scenes.rb` — the file to fix; keep its plate names, tag
   discipline, and ability wiring verbatim.
3. `.forge/scoper/scene-wall-lowering.md` — the already-validated wall-lowering
   mechanism the ventilation plate rides.
4. `scripts/booth-from-link.rb:1558,1583` — the transform-accumulating walk pattern
   that fixes the heading bug (file under active Builder edit; copy the pattern).
5. `reference/proposal-playbook.md` §4-5, §12 — the mandated render order and what the
   shipped plates actually looked like.

## Assumptions

- Benton moves the booth group into the host room by hand after building; no placement
  code exists in the repo. This is what activates the D3 coordinate-frame bug.
- Eye height 66", hero FOV 50°, ±35°/±25° azimuth offsets, 10% margin are **invented
  defaults** (the offsets and elevations echo the current script's constants); no
  eye-height/FOV standard exists anywhere in `reference/`. Benton nudges, scene
  re-saves — keep that philosophy.
- `Sketchup::Model#raytest`, `Camera#fov_is_height?`, `Page#use_hidden_objects` are
  reported API, never run from this repo — Builder verifies each live before relying
  on it.
- V-Ray's treatment of hidden tags/objects is assumed until `probe-vray.rb` runs
  (GOAL.md, Benton's item 3).
- PeoplesSpace plate descriptions are reported from the playbook, not from the PNGs.

## Open-questions

1. **Do technical plates 02/03 show the host room?** Evidence leans booth-only for the
   dimensioned and side plates (shipped pack) and room-with-lowered-walls for the
   ventilation plate. Proposed: a three-way dialog choice defaulting to booth-only.
   Benton's call.
2. **Three-quarter side preference** when both sides have standing room: proposed
   tie-break is "show the vent wall as the receding face" — taste, cheap to overrule.
3. **Multi-booth dimension tags**: with four rooms, plate 02 shows every room's dims
   (one global `WR-Dims` tag). Per-room dim tags in `build-room.rb` vs per-scene hidden
   objects — needs a decision before the four-room proposal, not before a one-room one.
4. **Hero when the room is too small even at FOV 60°**: refuse the plate by name, or
   allow the over-the-lowered-wall shot for the hero too? Brief says "in the finished
   room", so refusal is the lean; a lowered-wall hero may still read fine in V-Ray.
