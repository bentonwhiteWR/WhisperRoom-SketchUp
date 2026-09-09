# Spec — PeoplesSpace alcove room script (Builder)

## Goal

One SketchUp Ruby script under `scripts/` that builds the PeoplesSpace alcove to the
architect's measured interior faces, with the overhead constraints massed in, ready for
the MDL 96120 E + ADA booth to be dropped in twice (door at the south end, door at the
north end) and rendered. Everything not measured is flagged in the model and printed to
the console. No production Ruby exists yet; this spec is the whole brief.

## Read first

- `clients/peoplesspace/takeoff.json` — the transcription, validated; `takeoff.lock.json`
  is regenerated from it. `clients/peoplesspace/NOTES.md` — the fit arithmetic, the
  reconciled callouts, the open questions. Both are current.
- `.forge/scoper/peoplesspace-alcove.mockup.html` — the approved drawing (same as the
  published artifact). Match its geometry: coordinates below are the same numbers.
- `reference/sketchup-drawing.md`, `CLAUDE.md` "Benton's drawing conventions", and
  `scripts/csusb-rooms.rb` for the house pattern.
- `scripts/build-takeoff.rb` and `scripts/wr-roof-vent.rb` (header) — do not reinvent
  what they already do.

## Approach

`build-takeoff.rb` cannot build this room: it walls all four runs, and run 1 here is the
alcove's open east side; it has no glass wall, cloud ceiling or pipe cylinders. So this
is a **client script** (`# @tab client` under `@title`), written in the csusb-rooms.rb
style, that reads its numbers from constants at the top of the file with the source
quoted beside each one. It builds the room only; the booth comes from the booth pipeline
(booth-from-link.rb with a roof-mount link from sales) and is placed by the script's
published anchor points. If sales has no link yet, build a placeholder booth box at the
catalogue exterior and say so in the console.

Coordinates: model origin at the alcove's **south-west interior corner**, x east,
y north, z up; z = 0 is the architect's LEVEL 01 FF (the raised floor's top as drawn —
ASSUMED, note it). Inches throughout, Architectural units set by the script.

## Geometry to build (inches)

Interior polygon, clockwise from NW: (0,128.75) → (114.75,128.75) → (114.75,0) → (0,0).

| Element | Build | Tag | Material |
|---|---|---|---|
| Floor | face on the polygon, reversed if normal.z < 0 | WR-Floor | 0128_White |
| South wall (concrete) | outward from y=0, 8" thick (cosmetic), x from −4 to 114.75, mitred at the SW corner with the west wall | WR-Room | 0099_LightSteelBlue |
| West wall (partition) | outward from x=0, 4" thick, y from −8 to 130.75, mitred | WR-Room | 0099_LightSteelBlue |
| North wall (glass storefront) | 2" thick from y=128.75 outward, x 0→114.75, full height to 113"; translucent material (alpha ~0.35); mullions optional, if drawn space them ≥34" and label as not dimensioned | WR-Glass | translucent light blue, fallback RGB 200,225,245 |
| East side | **no wall.** A thin dashed-style edge or a 0.25" tall floor strip along x=114.75 marking "OPEN — limit of fragment" | WR-Notes | — |
| Ceiling: acoustic cloud | slab 2.5" thick, underside z=113, spanning y=22→128.75 and x 0→114.75 (the 22" start is a pixel read — flag it) | WR-Ceiling | 0128_White, alpha 0.6 |
| Concrete structure | optional slab underside at z=122 spanning the room | WR-Ceiling | grey |
| Pipes | three cylinders Ø5.5" running E–W, x from −4 to 114.75, centres at y=3.5, 10.5, 17.5, bottom at z=99.25 (centre z=102) | WR-Obstruction | grey |
| Wall grille | box on the west wall face: x 0→12, y 41→89, z 103.7→115.7 | WR-Obstruction | grey |
| Raised floor | do NOT model a thickness; put a text note at the SW corner: "RAISED FLOOR — thickness not dimensioned; z=0 = its top as drawn (ASSUMED)" | WR-Notes | — |

Wall heights: 113" (to the cloud) for the west and north walls; 122" for the concrete
wall (it reaches the structure on the elevation).

## Booth placement anchors (publish these as constants and print them)

- Booth exterior 98 × 122, SW exterior corner at (1, 1) for both options; front (door)
  face at x = 99, facing east.
- Option 1: door frame (49") from y=3 to y=52, centreline y=27.5; hinge on the south jamb
  (ASSUMED); leaf 32" opening outward; swing clearance line at x = 133.5.
- Option 2: frame y=72 to 121, centreline y=96.5; hinge on the north jamb (ASSUMED).
- Ramp both options: trapezoid from the booth face, 46" wide at the door centred on the
  centreline, 36" at the foot, toe at x = 144.625. Rise/slope: unknown — build a flat
  plate 2" thick and flag it, unless Benton answers question 5 first.
- Roof unit RM96120: 88 (x) × 113.5 (y) × 10.3125 (z), centred on the nominal footprint
  → x 6→94, y 5.25→118.75, z 84.3125→94.625. Use `WR_RoofVent.seat` if the booth comes
  from the pipeline; otherwise a box with the same numbers, tagged WR-RoofVent.
- Two option groups on tags WR-Booth-Opt1 / WR-Booth-Opt2 (each holding booth + ramp +
  door + roof unit) so scenes toggle them; never both visible in one scene.

## Dimensions (SketchUp dimension entities, tag WR-Dims)

All four sides, chain closest to the building and overall outside it:
- South, below the concrete wall: 1 | 98 | 15.75, overall 114.75; plus ramp 45.625 off
  the booth face and the 29.875 overrun past x=114.75.
- West: 1 | 122 | 5.75, overall 128.75.
- East (door wall), beyond the ramp: opt 1 → 1 | 2 | 49 | 71 | 5.75; opt 2 → 1 | 71 | 49
  | 2 | 5.75. Door centreline as a separate ordinate from the SW corner.
- North: overall 114.75 labelled derived.
- Section/elevation scene: 84.3125 booth, +10.3125 unit, 99.25 pipe, 113 cloud, 122
  structure, and the 4.625 margin called out.
- Clear interior 89.5 × 113.5 (wr-booth-data eiw/eih) — the client asked for this; put
  it on the plan scene.

## Scenes

`1-01-exterior`, `1-02-dimensioned`, `1-03-side`, `1-04-ventilation`, `1-05-plan` and the
same five with `2-` for option 2, so the scene exporter names them in proposal order.
Plan scenes top-down parallel projection, north up.

## Console output (mandatory)

`FAILED:` on any exception inside one `start_operation`/`commit_operation`. On success,
print the list of everything not measured: derived north/east runs, the 22" cloud start,
the pipe band, the grille box, the raised floor datum, the hinge sides, the ramp rise,
the wall thicknesses. Same list as text notes in the model at each feature.

## Steps

1. `scripts/peoplesspace-alcove.rb` — header (`@title`, `# @tab client`), constants
   block with sources, units, tags, materials loader (real .skm with RGB fallback).
2. Room: floor, three walls mitred, open-edge marker, cloud, structure, pipes, grille,
   notes.
3. Booth anchors + placeholder/pipeline booth for both options on their tags; ramp; roof
   unit.
4. Dimensions and scenes.
5. `python scripts/rbparse.py` clean on every .rb; bump `scripts/wr_tools/VERSION`;
   commit and push (notes only — nothing from `clients/peoplesspace/plans/`).

## Acceptance criteria

- `rbparse.py` reports the new file valid; `rbcheck.py` alone is not evidence.
- Loading the script in an Untitled model builds without `FAILED:`; Ctrl+Z reverses all.
- Interior faces measure 114.75 × 128.75 with the tape; no wall solid on x=114.75.
- Booth SW corner at (1,1); door centreline at y=27.5 (opt 1) / 96.5 (opt 2); ramp toe
  at x=144.625; roof unit top at z=94.625; pipe underside at z=99.25.
- Every chain sums to its overall; the console list matches the notes in the model.
- VERSION bumped and the push is on `main`.

## Risks / out of scope

- The booth model and the roof-mount change are sales' calls; the script draws what the
  quote says. If no roof-mount link exists, the roof unit is a flagged box.
- The raised floor could eat the entire pipe margin; the script cannot resolve that.
- Do not touch WhisperRoomQuote. Do not fix the "FORT VANCOUVER" subtitle in the old PDF.
- Proposal PDF and renders are a later step.
