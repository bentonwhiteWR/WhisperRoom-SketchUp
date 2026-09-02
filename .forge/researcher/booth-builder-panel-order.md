# Booth builder — where the wide side-wall panel sits (6060 / 6084 / 7272 / 7296)

Researcher, 2026-09-02. Read-only against `WhisperRoomQuote`. Everything below is labelled
**observed / derived / reported / assumed**.

## Question

For the four split-run models, does the builder put the wide E/W panel (46" on the 72-series,
40" on the 60-series — the one carrying the vent duct) at the **door end** or the **far end**
of the side wall, and how does that relate to the floor and ceiling panel layout?

## Answer

**Door end, on all four models, on both side walls, in all three builder views.** The
builder does not distinguish the two families. (observed — `wallPanelRun()` output and the
angled view's plan geometry read out of the live page; the screenshots agree.)

**The floor and ceiling layout in the builder cannot be the thing that decides this.** The
floor/ceiling seam runs **front-to-back, parallel to the side walls**, at the N/S wall joint
(x = 49" on 7272/7296, x = 43" on 6060/6084 from the W exterior face). It never crosses the
E/W walls, so its position says nothing about which end of the side wall holds the 46/40.
(observed from the manifest `fc` table and the captures.) The only floor/ceiling evidence that
*could* decide it is the hinge-bracket pattern along each SIDE section's long edge
(`reference/floor-ceiling-geometry.md:204-260`, reported), and the builder does not model
that as data — its sprites are placed by a position rule (far tile rotated 180°) and were
checked by eye. So the builder's side-wall order is not derived from its floor/ceiling
layout; it comes from two hard-coded sources described under "Where the builder gets it".

**There is a live contradiction the orchestrator must take to Benton before any Fixer work.**
`wr-booth-data.rb` was *deliberately* set opposite to the builder on the 6060/6084 on
2026-08-28 (commit `a886105`, plugin 1.7.10) because Benton inspected a built 40/16 booth and
said the 16 sits at the door end — the commit says outright: "portal 2D, portal angled view
and the builder all had the 40 at the door end. Benton is looking at a built booth. A drawing
loses to a part." Benton's 2 Sep steer ("the booth builder renders all three accurately")
points the other way for that family. One of the two rulings is wrong, and this file cannot
say which; it can only say what each source holds.

## Where the numbers came from

Page: `C:\Users\bento\Documents\Claude\WhisperRoomQuote\booth-builder.html`, served read-only
by `.forge/researcher/tools/serve.js` (a stub that answers `/api/booth-layouts` and
`/api/booth-iso-geometry` from `lib/pl-data/*.json` and turns on the same three flags
`quote-server.js` sets: top-down art, angled view scripts, BB2). Driven by
`.forge/researcher/tools/capture.js` (Puppeteer 21.11 + Chrome) with `?product=MDL 7272 S`
etc. Model switch verified from `state.model` and from the page text before every capture
(`tools/capture-run.log`). Raw state dump: `builder-captures/builder-state.json`.

Numbers were taken from the page's own state, not from pixels:

- side/front/back wall runs: `wallPanelRun(resolveLayout(), state.assign, side)` in
  `assets/layout-render.js` — the same call every flat view draws from;
- floor / ceiling / caster-plate tiles: `wrIso.manifest.fc[key]` rotated into plan inches
  with the family polygons (`local`) from the same manifest;
- angled-view wall polygons: `/api/booth-iso-geometry` (`lib/pl-data/booth-iso-geometry.json`).

Coordinate frame: plan inches, origin at the SW exterior corner, S (door) wall at low y.
`wallPanelRun` reports E/W runs with `aIn` growing downward from the N exterior line
(`layout-render.js:271`), so "from the door wall" below is `exterior.h − aIn`.

## Seam positions per model — inches from the door (S) exterior face unless noted

| model | E wall (door end → far end) | E joint centre | W wall | floor / ceiling / cp seam | seam lines up with |
|---|---|---|---|---|---|
| MDL 7272 S | **46 VNT** 2–48, seal, 22 at 50–72 | **49** | 46 at 2–48, 22 at 50–72 | one seam, runs y 1→73 at **x = 49** from W face | S and N wall joint (49) |
| MDL 6060 S | **40 VNT** 2–42, seal, 16 at 44–60 | **43** | 40 at 2–42, 16 at 44–60 | one seam, y 1→61 at **x = 43** | S and N wall joint (43) |
| MDL 7296 S | 46 at 2–48, 22 at 50–72 (no vent on E; vents on N) | 49 | same | one seam at x = 49 (two 7248 tiles) | S/N joint (49) |
| MDL 6084 S | 40 at 2–42, 16 at 44–60 | 43 | same | one seam at x = 43 (two 6042 tiles) | S/N joint (43) |

All four walls report `exact: true`, `source: sku` (observed). Floor tiles (observed, manifest):
7272 `floor-7248` x 1–49 + `floor-7224` x 49–73, both full depth y 1–73; 6060 `floor-6042-l`
x 1–43 + `floor-6018` x 43–61, y 1–61. Ceilings identical footprints; caster plates likewise.
Floor seam seal `flseal-72` centred x 49 (7272), `flseal-60` centred x 43 (6060).

The angled view's own wall polygons (`booth-iso-geometry.json`, observed): 7272 `E0` VNT
y 2–48, `E1` y 50–72; 6060 `E0` VNT y 2–42, `E1` y 44–60 — wide at the door end on both.

## What the captures show (all in `builder-captures/`, `<model>-angled-<corner>-<rung>.png`,
`<model>-floorplan-top.png`, `<model>-elevation-<face>.png`)

- **Floor plan** (`*-floorplan-top.png`, observed): the builder labels the E wall
  "46″ Ventilation" / "40″ Ventilation" on the door-end half and "22″ Wall" / "16″ Wall" on
  the far half, on 7272, 6060, 6084; 7296 shows 46 at the door end and 22 far. One black
  floor seam runs door-to-back at the S/N joint.
- **Angled, roof on** (`*-angled-FR-roof-on.png`): the vent duct sits on the side-wall panel
  adjoining the door-wall corner; the roof seam runs front-to-back at the S/N joint.
- **Angled, walls open** (`*-angled-FR-walls-open.png`): the floor seam seal runs front-to-back;
  the wider floor section is on the W side, the narrow one on the E side. Hinge brackets are
  drawn on the section edges at roughly 0.1 / 0.5 / 0.85 of each long edge on both sides
  (derived from a 3x crop, `*-FLOORZOOM.png`) — near-symmetric, so the sprites do **not**
  visibly encode the 46/22 or 40/16 slot pattern the reference describes. That is a limit of
  the art at this resolution, not evidence either way.
- **Walk-around** (`*-elevation-E.png`): the duct panel is the wide one; consistent with the
  above. Handedness of the elevation was not independently verified (assumed to match the plan).

## Where the builder gets its side-wall order (observed in code)

1. **Flat views** — `assets/layout-render.js:222-283`, `wallPanelRun()`: a structural rule
   ("2-panel E/W wall whose two real parts differ" → big run at the model's own door end),
   citing `reference/seam-seal-attachment.md:316-322` and Benton's v2.315.0 screenshot
   confirmation on a 7272 S ("22″ panel at the TOP of the left wall and the 46″ below it, by
   the door"). It picks out exactly these four models.
2. **Angled view** — `lib/pl-data/booth-iso-geometry.json`, whose header says it was
   **generated from `wr-booth-data.rb` on 2026-08-07** (observed: `source`, `generated`). It
   is a snapshot of the Ruby file from before the Aug 11 / Aug 27 / Aug 28 changes, not an
   independent witness (already noted in `.forge/fixer/ROOTCAUSE-side-wall-order-2026-08-26.md`).
3. **Floor/ceiling sprites** — `scripts/gen-iso-placeholders.js:3897-3960`: orientation by a
   position rule + handed-twin rule; Benton verified the hinge pose in renders (reported in
   the code comments). Not tied to wall joints.

So "the builder renders floor, ceiling and walls" is true, but the three are not
cross-derived; the wall order is asserted, twice, from the same 2026-08 convention.

## Builder vs `scripts/wr-booth-data.rb` (HEAD `a886105`, 2026-08-28)

| model | builder (all views) | `wr-booth-data.rb` | agree? |
|---|---|---|---|
| 7272 S / E | 46 (E0/W0) at door end, y 2–48 | E0 46 y 2–48, E1 22 y 50–72 | **yes** |
| 7296 S / E | 46 at door end, y 2–48 | E0 46 y 2–48, E1 22 y 50–72 | **yes** |
| 6060 S / E | **40 (E0/W0) at door end, y 2–42** | **E1 16 y 2–18 (door end), E0 40 y 20–60** | **no** |
| 6084 S / E | 40 at door end, y 2–42 | E1 16 y 2–18, E0 40 y 20–60 | **no** |

Slot ids: the builder's `E0` is the door-end slot on both families. The Ruby's `E0` is the
door-end slot on the 72-series and the far-end slot on the 60-series — the id/position split
the GOAL already records. It was introduced by `gen-booth.py` `SWAP_TWO_PANEL_SIDE_WALL =
{40,16}` in `a886105` (observed in the diff); the previous commit `941fb3d` (Aug 27) had all
four models matching the builder and said so.

## Confidence and gaps

- The builder's order and seam numbers: **observed**, from live page state, four models,
  screenshots inspected (roof-on, walls-open, floor plan for all four; elevations for 6060).
- The floor/ceiling seam being perpendicular to the side walls: **observed** (manifest + BOM
  "SIDE LEFT / SIDE RIGHT" parts + captures).
- Whether the real 6060 has the 16 at the door end: **reported**, twice and in conflict
  (Benton Aug 28 via `a886105` vs Benton Sep 2 via the GOAL). Not resolvable here.
- Not captured: Enhanced (E) variants — `wallPanelRun` and the geometry are the same for S/E
  so the order cannot differ, but no E screenshot was taken. Walk-around handedness assumed.
- Page errors during capture: only `/api/engage` 404s from the stub (observed, harmless).

## Files

- `C:\Users\bento\Documents\Claude\Sketchup\.forge\researcher\tools\serve.js` — read-only stub server
- `C:\Users\bento\Documents\Claude\Sketchup\.forge\researcher\tools\capture.js` — Puppeteer driver
- `C:\Users\bento\Documents\Claude\Sketchup\.forge\researcher\tools\capture-run.log` — model-switch log
- `C:\Users\bento\Documents\Claude\Sketchup\.forge\researcher\builder-captures\builder-state.json` — raw numbers
- `C:\Users\bento\Documents\Claude\Sketchup\.forge\researcher\builder-captures\*.png` — 56 captures
