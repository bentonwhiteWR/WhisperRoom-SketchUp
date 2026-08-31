# Floor-plan pipeline diagnosis — the 31 Aug 2026 job (S609-3, UIC Daley Library)

Researcher report, 2026-08-31. Read-only diagnosis; nothing was fixed. Provenance labels
(observed / derived / reported / assumed) per the operating manual.

## Question

Gabe ran a client floor plan (rooms 3190F/G/H/J, UIC Richard J. Daley Library, third
floor) through this repo's tooling on 31 Aug 2026. Per Benton relaying Gabe: the
dimensions came out wrong AND the workflow needed so much hand-holding that drawing by
hand was faster. Where does the accuracy actually go wrong, and what is the workflow cost?

## Answer, short

There is **no floor-plan intake pipeline in this repo** — the only path from "photo of a
plan" to "room in SketchUp" is a human reading the plan and typing wall runs into the
`Draw floor plan` dialog (or an agent hand-authoring a one-off Ruby script over hours).
The accuracy failure on this job is almost certainly **interpretation/transcription of
the hand-written dimension chains**, not pixel-scale estimation: the pen callouts are
ambiguous in exactly the way that produces feet-sized errors (worked example below), and
the dialog cannot represent half of what the photos state (heaters, bulkheads, door
heights, per-room notes), while its door rows ship **invented placement defaults** that
read as measurements. Meanwhile the exact answer was sitting in the job folder: the
vector PDF (and the DWG behind it) carries proportionally exact geometry — one pen
anchor recovers every dimension to ~1–2 inches (verified numerically below).

---

## 1. The artifacts: what they are and what they carry

### 1.1 The five files (all observed)

| File | What it is |
|---|---|
| `C:\Users\bento\Downloads\S609-3.dwg` | 690 KB, header bytes `AC1032` = AutoCAD R2018+ binary format; embedded XML names AutoCAD build `U.61.0.0(x64)` registry 24.3 (= AutoCAD 2024). Real CAD, not a renamed export. |
| `C:\Users\bento\Downloads\S609-3.pdf` | 1 page, 792×1224 pt (11×17"), PDF 1.6. **Pure vector: 18,337 drawing paths, 0 raster images, 0 extractable text characters** (all text is stroked as curves — an AutoCAD SHX plot). |
| `C:\Users\bento\Downloads\IMG_7594.jpeg` | Phone photo of a laser-printed excerpt of this same plan: rooms 3190G+3190H, pen field measurements. |
| `C:\Users\bento\Downloads\IMG_7595.jpeg` | Same, room 3190J. |
| `C:\Users\bento\Downloads\IMG_7596.jpeg` | Same, room 3190F. |

The rendered PDF (observed at 150/300 dpi via PyMuPDF) is a **UIC Planning,
Sustainability and Project Management space plan**: "S609-3, highlight by department,
12/8/2025", building 0609 = Richard J. Daley Library, third floor, 801 South Morgan
Street, Chicago. Rooms 3190C–3190L are highlighted as department 699000 "Computer
Science". Title block states **"NOT TO SCALE"** and remarks the plan "should not be used
for design without first being field measured and verified" (observed).

### 1.2 The three photos are excerpts of this exact drawing

Observed: the photos show the same room tags (3190F, 3190G, 3190H, 3190J, dept 699000),
the same furniture symbols, the same wall/window/door linework as the 3190 block in the
PDF. All three sources describe the same rooms. Pen field measurements on the photos:

- **3190G/H** (`IMG_7594`): ceilings 8'8" (G) and 8'9" (H); chains 17'3" and 18'11";
  9'5" near the G/H partition; 14'4" vertical (depth); two "10" heater" callouts with
  hatched zones along the window walls; "9'1" from back wall"; 38" doors both rooms; note
  "Wall removed by contractor a bulkhead will be in its place 8'3" above the floor",
  arrow pointing at the G/H partition at the door wall.
- **3190J** (`IMG_7595`): 8'10" wall run, 38" door, 8'1" bottom run.
- **3190F** (`IMG_7596`): 9'3" and 9'6" runs, 10" callout, 38" door, 14'4" depth,
  "9'1" heater", ceiling 8'7".

### 1.3 The vector PDF is proportionally exact — verified, not assumed

Probe (observed; script run in the researcher scratchpad, PyMuPDF 1.28.2):
`page.get_drawings()` line segments around the 3190 block cluster into clean wall
positions. Inner wall faces of the G/H pair sit at x = 245.46 pt and 289.14 pt with the
partition at 266.82–267.78 pt; office band interior depth spans 33.06 pt.

Taking **one** anchor from the pen notes — combined G+H interior width 18'11" = 227 in
across 43.68 pt → 5.197 in/pt — and predicting everything else (derived):

| Dimension | PDF-derived | Field pen note | Error |
|---|---|---|---|
| Room depth | 33.06 pt → 171.8 in | 14'4" = 172 in | ~0.2 in |
| Room J width | 18.42 pt → 95.7 in | 8'1" = 97 in | ~1.3 in |
| G alone (interior) | 21.36 pt → 111 in | 9'3" (3190F, same size class) = 111 in | ~0 |
| Chain closure | — | 17'3" + 10" + 10" = 18'11" | exact |

So despite the "NOT TO SCALE" stamp (which is about the plotted paper scale — 72 ×
5.197 ≈ 374 in of building per paper inch, a fit-to-sheet plot), the underlying geometry
is drawn true. **Every dimension of these rooms was recoverable to ~1–2 inches from the
PDF plus any single pen anchor.** The same is true a fortiori of the DWG, which is the
model-space source of this plot (derived).

### 1.4 What on this machine can read the DWG

Observed by direct inspection:

- **SketchUp's native DWG importer is installed twice**:
  `C:\Program Files\SketchUp\SketchUp 2024\Importers\dwgimporter.dll` and
  `C:\Program Files\SketchUp\SketchUp 2026\SketchUp\Importers\dwgimporter.dll`.
  File → Import inside SketchUp reads this DWG directly; scale is set at import. This is
  the zero-install path.
- **PyMuPDF 1.28.2** is installed (Python 3.13) and reads the vector PDF's exact path
  coordinates — demonstrated above.
- **Not present**: ODA File Converter, LibreDWG/`dwg2dxf`, AutoCAD, BricsCAD,
  DraftSight, `ezdxf` (ModuleNotFoundError). Nothing headless on this machine converts
  DWG→DXF today. If a scripted DWG path is ever wanted, install ODA File Converter
  (free, closed) + `ezdxf` (pip); but for this repo's purposes the vector PDF + PyMuPDF
  already gives the same geometry with tools that exist.
- The DWG's text/room tags are not grep-able from the raw file (R2018 sections are
  encoded); reading them programmatically requires a converter (observed — probe found
  only the AutoCAD product-info block).

Per Benton's steer: a real DWG is the rare bonus, not the mainline. Finding stands
anyway: **on this particular job the exact geometry was available and nothing in the
pipeline could, or did, use it.**

---

## 2. The existing floor-plan → SketchUp path, traced

There are exactly two paths in the repo, both fully manual at the intake step.

### 2.1 Path A — the `Draw floor plan` dialog (Gabe's path)

- `scripts/build-room.rb` (531 lines) + `scripts/build-room.html` (508 lines), reached
  from the wr_tools panel. **Input format: keystrokes.** Simple mode = length, width,
  ceiling, sill. Detail mode = a take-off table of `{direction, length}` runs plus a
  doors table of `{run #, at (from run's start corner), width, hinge}`
  (`build-room.html:114–152`, payload at `:481–499`).
- The dialog is genuinely good at what it covers (observed by code read):
  - Robust dimension parser, every field, both modes (`parseLen`,
    `build-room.html:194–215`); unparseable input goes red and blocks Build instead of
    becoming zero (`lenField`, `:347–363`).
  - Live polygon preview with a closure check; **Build is disabled until the chain
    closes** (`:334`), and Ruby re-checks (`build-room.rb:359–364`).
  - Walls build outward from the interior polygon and mitre (`mitre`,
    `build-room.rb:172–187`); interior dimensions cannot move.
  - Ceiling defaults to 96" but loudly: a model text note "HOUSE DEFAULT, not measured"
    is placed when 96" is used (`build-room.rb:414–423`).
  - Finishes by auto-dimensioning (`build-room.rb:429–443`).
- **What it cannot represent** (observed absence): obstructions (heaters, columns,
  bulkheads), windows, per-wall notes, ceiling slabs (`DEVLOG.md:833` — "build-room.rb
  building no ceiling slab", open), soffits/bulkheads at a height, more than one room
  per run. Everything the pen notes say about heaters and the 8'3" bulkhead has nowhere
  to go.

### 2.2 Path B — a hand-authored one-off Ruby script per client (the agent path)

`scripts/uthsc-audiology-rooms.rb` and `scripts/csusb-rooms.rb` (both observed) are the
worked examples: an agent reads the client plan image/PDF, does a full take-off with
chain-closure and area cross-checks, and writes a bespoke script with the coordinates
inlined. The uthsc header is ~200 lines of provenance analysis for four rooms;
csusb-rooms read interior polygons "from the vector layer of the client's PDFs and
scaled off each sheet's printed scale bar" (`csusb-rooms.rb:11–13`) — proof the vector
route works, done entirely by hand. This path produces excellent provenance and costs
hours. `clients/README.md` prescribes a `notes.md` per client with anchor + tolerance;
**no `clients/` folder exists for this UIC job** (observed — only `bohn-music-academy`
and `uthsc-audiology`), i.e. the job never entered the repo's own protocol.

### 2.3 The written protocol does not cover this job's input type

`reference/scale-estimation.md` (86 lines, observed) is entirely about **deriving scale
from pixels** — scale bars, stated scales, standard objects, keystone. It has no section
for the actual 31 Aug input: **a printout hand-annotated with stated field
measurements**, where nothing needs scaling and the whole game is reading, closing, and
applying the pen chains correctly. The one rule that would have caught the error below —
"close every chain and say so" — lives in `CLAUDE.md` (dimension-the-top-down section)
for *output* drawings, not as an intake step for *reading* marked-up plans.

---

## 3. Where the error enters — ranked

Benton's steer: both defects are real — (a) dimensions wrong, (b) too manual/slow. The
ranking reflects that.

### #1 — Process cost: there is no intake automation at all (the abandonment driver)

For this job the workflow was: interpret three photos' pen chains; per room, open the
dialog, type 4+ runs, a door with a position nobody measured, ceiling, sill; repeat four
times; then accept that heaters, the bulkhead, and windows — the things the client
actually annotated — cannot be drawn by the tool and must be added by hand anyway. The
alternative path is an hours-long bespoke script. A draftsman who can draw four small
rectangles by hand in minutes is making the rational choice by abandoning the tool.
Evidence: the two worked examples are hand-authored one-offs (observed); grep of the
repo finds no DWG/PDF/photo importer of any kind (observed); Gabe's own words via
Benton — "needed so much hand-holding and setup" (reported).

### #2 — Dimension interpretation/transcription of the pen chains (the wrong-numbers driver)

The field notes are stated numbers, so pixel-scale error is off the table — but the
chains are ambiguous to anyone who was not standing in the room:

- On `IMG_7594`, **17'3" is the width *between the two 10" heaters*, not the room width**
  — 17'3" + 10" + 10" = 18'11" closes exactly against the wall-to-wall chain (derived,
  verified against the PDF vectors §1.3). Read 17'3" as the wall-to-wall width of the
  combined room and the model is 20 inches short. Read it as room G's width alone
  (it is drawn across G's half of the image) and G is built ~8 feet too wide — G's true
  interior is ~9'3" (derived, §1.3).
- The G/H partition **no longer exists** ("wall removed by contractor…"), so the room
  count itself is an interpretation call: two rooms per the print, one room per the pen.
- 14'4" depth, "9'1" from back wall", "9'5"" near the partition: none says which face
  to which face. The dialog's closure check cannot catch any of this — a consistently
  wrong width still closes.

This is the exact shape of "the dimensions came out wrong": every number was written
down by the client, and the pipeline step that failed is *reading and applying* them.
The written protocol has no procedure for it (§2.3). (Derived from the artifacts; the
specific numbers Gabe typed are not recorded anywhere — see gaps.)

### #3 — Silent placement defaults on doors (the never-invent rule is not enforced in code)

- "+ door" seeds `{run:0, at:36", w:36", hinge:near}` (`build-room.html:477–478`) —
  plausible-looking values indistinguishable from measurements once built. The photos
  give door *widths* (38") but **no door positions**; `at` must be invented, and
  nothing in the dialog, the build report, or the model flags it the way the 96"
  ceiling is flagged. This violates the repo's own hard rule ("never invent a placement
  number", GOAL.md / scale-estimation.md §7) in the one field where placement matters
  most for booth fit.
- `door_h` is hardcoded to 80" in the payload (`build-room.html:497`) with no input
  field and no flag in the model (only a line in the console report,
  `build-room.rb:353–354`).
- **Silent geometry inconsistency**: `wall_run` drops any door cut that touches a corner
  or overruns the wall (`s > TOL && e < len - TOL`, `build-room.rb:254–257`), but
  `build` still calls `door()` for it unguarded (`build-room.rb:405–410`) — the leaf,
  swing, and opening marker are drawn while the wall stays solid. A door typed at a
  corner (`at:0`, common in real rooms) produces a wall with a door leaf embedded in
  solid wall, no message. Observed in code; not executed (no SketchUp running).

### #4 — The exact-geometry source was ignored

The vector PDF/DWG carried every dimension to ~1–2" (§1.3), the machine has both a
native SketchUp DWG importer and PyMuPDF (§1.4), and csusb-rooms proves the vector read
works — yet no tool, protocol line, or checklist says "if a PDF/DWG exists, take
geometry from it and use the field notes as the anchor + heights + changes". Per the
steer this is a fast-path finding, not the mainline fix; but on *this* job it was the
cheapest correct path and it was invisible.

### #5 — Geometry-construction gaps (real, but not this job's likely killer)

The core build math is sound and has been exercised live: polygon/mitre/wall/door built
a 12'×15' room end-to-end through the bridge in 0.271 s (`DEVLOG.md:1203–1207`,
observed log of a live run). Known open defects that erode trust in the output:

- No ceiling slab (`DEVLOG.md:833`) — with per-room measured ceilings 8'7"–8'9" being
  the client's headline data, the model can't show them.
- `auto-dimension.rb`'s `doors_on` scans only top-level entities, so **doors built by
  build-room (inside the room group) have never been dimensioned**
  (`DEVLOG.md:3985–3988`, named a "separate pre-existing defect", still open) — the
  drawing can't be checked against the plan at exactly the placement-critical feature.
- `build-room.rb` runs its dialog unconditionally on load (no autorun guard,
  `DEVLOG.md:1221–1227`) — a bridge/automation annoyance, worked around in `WRB.tool`.

### Explicitly demoted: scale-estimation error

Nothing on this job needed a pixel-to-feet ratio — the dimensions were stated in pen.
`reference/scale-estimation.md`'s method is fine for what it covers; it simply covers a
different input than the one that arrived (derived).

---

## 4. Ground truth for an eval set — feasibility

Benton's loop (synthetic plans with known dimensions → build → score in SketchUp →
improve) is buildable with what exists:

- **Synthetic plans**: PyMuPDF (present) can author vector PDFs — and rasterize them at
  any dpi, with optional perspective warp via an image lib, to mimic phone photos of
  printouts. Truth is set at authoring time, so error is measurable in inches. The 31
  Aug artifacts themselves are a second, real, eval case: S609-3's vector geometry plus
  the pen anchors give per-room truth to ~1–2" (§1.3), including deliberately nasty
  features (annotation chains that need interpretation, a removed wall, obstructions).
- **The scorer's read-back channel exists**: `scripts/sketchup-bridge.py` submits
  arbitrary Ruby to a live SketchUp and returns stdout, the JSON-safe return value, and
  exceptions with backtraces (header, observed), with specific exit codes; it exports
  `submit()` for exactly this assert-against-results use. The resident half
  (`scripts/wr_tools/wr_bridge.rb`) JSON-encodes values, fences writes, and captures
  output. It has already driven `build-room.rb` end to end and counted the resulting
  entities (`DEVLOG.md:1203`).
- **What the scorer would measure** (proposal, for the Scoper): per room — interior
  polygon vertices (floor-face vertex coordinates vs truth, max error in inches);
  wall-run lengths and closure; door opening jamb positions and widths (from the
  `WR-Doors` opening markers, which sit exactly in the wall plane —
  `build-room.rb:281–299`); ceiling height; presence/absence of every truth feature
  (a missing heater or bulkhead scores as a miss, not a pass).
- **Not verifiable now**: SketchUp is not running (bridge heartbeat ~18 h stale,
  reported by orchestrator; not re-probed — no bridge job was attempted per the brief).
  If it were up, the first assertions I would run: (1) build a known 12'×10' cfg via
  the bridge and read back floor-face vertices — expect exact; (2) the corner-door case
  from §3.#3 — expect leaf-without-opening, confirming the silent inconsistency live;
  (3) `dimension_face` on the result — expect zero door dimensions, confirming the
  `doors_on` defect.

## Confidence & gaps

- Solid (observed/derived): everything in §1 (files, probes, the scale verification),
  the code trace in §2–3 (files and line numbers cited), the tool inventory.
- **Gap**: what Gabe actually typed on 31 Aug is recorded nowhere — no `clients/`
  folder, no DEVLOG entry, no model file available. That the wrong numbers came from
  chain misinterpretation (#2) is the best-supported hypothesis given the artifacts'
  ambiguities and the code's inability to err on closed chains, but it is a
  **hypothesis**; #3's invented door placements are a proven mechanism but their
  contribution to *this* job is likewise unrecorded. Ten minutes of Gabe's recollection
  (or his abandoned model file, if it exists) would settle the split between #2 and #3.
- Nothing was executed in SketchUp (not running); all behavioral claims about the build
  path are code-reads except where a DEVLOG live-run log is cited.
