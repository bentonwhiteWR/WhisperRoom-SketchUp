# HANDOFF — booth-builder side-wall panel order (2026-09-02)

## Produced
- `.forge/researcher/booth-builder-panel-order.md` — findings, numbers, comparison table.
- `.forge/researcher/builder-captures/` — 56 PNGs (4 models × 4 corners × roof-on/roof-off/walls-open, floor plan, 4 elevations), `builder-state.json` (raw page state), `page-errors.txt`.
- `.forge/researcher/tools/serve.js` + `capture.js` — rerunnable: `node serve.js &` then `node capture.js "MDL 7272 S"`. Nothing in `WhisperRoomQuote` was written.

## Read-first
1. The builder puts the **wide panel at the door end on all four models, both side walls, all three views**; both families identical. Numbers from `wallPanelRun()` and the iso manifest, not pixels.
2. The floor/ceiling seam runs **front-to-back at the N/S wall joint** (x = 49 / 43). It is perpendicular to the side walls and cannot decide E/W order; the builder's wall order is hard-coded (`layout-render.js:222-283`) plus a 2026-08-07 snapshot of `wr-booth-data.rb` (`booth-iso-geometry.json`).
3. **Conflict to raise with Benton**: `wr-booth-data.rb` `a886105` (Aug 28) deliberately set 6060/6084 to 16-at-door because Benton inspected a built booth. His Sep 2 steer says the builder is accurate. These disagree for the 60-series only; the 72-series already agrees everywhere.

## Assumptions
- Elevation-view handedness matches the plan (not independently verified).
- Enhanced variants not captured; same code paths, so assumed identical order.
- Hinge-bracket fractions (~0.1/0.5/0.85) read off a 3x crop by eye.

## Open-questions
- Which Benton ruling stands for the 6060/6084: built-booth (16 at door) or builder (40 at door)?
- Does the real 7272/7296 side wall match the builder (46 at door)? `a886105` left it unchanged and said it was never inspected.
- If the builder is wrong on the 60-series, that is a `WhisperRoomQuote` fix (`wallPanelRun` + regenerating `booth-iso-geometry.json`), out of this repo's reach.
