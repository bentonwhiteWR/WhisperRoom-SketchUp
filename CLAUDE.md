# CLAUDE.md — SketchUp / WhisperRoom drawing + proposal assistant

This is Benton's assistant workspace for **everything SketchUp at WhisperRoom**: reading
client floor plans, estimating dimensions from scaled drawings, recommending which booth
fits and where it goes, and driving the branded client proposal out the other end.

There is **no application code here**. This repo is rules, reference data, and per-client
working notes. The real generators and data live in the sibling repos listed below.

---

## What Benton uses me for

1. **Client sends a floor plan or a photo of one.** Often no dimensions, sometimes a scale
   bar or one known reference. Estimate the room, get the usable footprint, and say how
   confident I am.
2. **Recommend a booth + layout.** Which model fits, where it sits, which way the door
   swings, where ventilation exits.
3. **Build a visual to think with** — an Artifact showing the room to scale with the booth
   placed in it, so Benton can eyeball it before opening SketchUp.
4. **Produce the client-facing proposal PDF** from the SketchUp/V-Ray renders, on brand.

Default deliverable for a floor-plan message is **an estimate plus a to-scale Artifact**,
not a wall of prose.

---

## Where everything actually lives (do not rediscover this)

**Machine note — check this first.** The Claude workspace root differs per machine because
Documents is redirected into OneDrive on some of them. Resolve `<CLAUDE>` once at the start
of a session to whichever of these exists, then read every path below relative to it:

| Machine | `<CLAUDE>` |
|---|---|
| Laptop | `C:\Users\bento\Documents\Claude\` |
| Desktop | `C:\Users\bento\OneDrive\Documents\Claude\` |

On the desktop this repo is cloned at `<CLAUDE>\Sketchup\WhisperRoom-SketchUp\`; on the
laptop it sits directly at `<CLAUDE>\Sketchup\`. Never hard-code either — the SketchUp
plugin resolves its own path the same way (see `scripts/wr_tools/main.rb`).

| Thing | Path |
|---|---|
| Booth model catalog (dims, weights, prices, vents) | `<CLAUDE>\WhisperRoomQuote\whisperroom-catalog\data\models.json` |
| Options / packages / compatibility | same folder — `options.json`, `packages.json`, `compatibility.json` |
| Top-down wall + door + vent art (PNG) | `...\WhisperRoomQuote\assets\topdown\` |
| Booth elevation art | `...\WhisperRoomQuote\assets\booth-art\` |
| **Proposal brand + layout spec** | `<CLAUDE>\WhisperRoom Proposals\docs\PROPOSAL-GUIDELINES.md` |
| Proposal generator | `...\WhisperRoom Proposals\build-v2.js` |
| Prior proposal configs (copy the newest) | `...\WhisperRoom Proposals\examples\<client>\proposal-v2.json` |
| **Scene → PNG batch exporter** | `...\WhisperRoomQuote\tools\sketchup-scene-export\` |
| Historical proposals & drawings (Word/PDF) | `C:\Users\bento\Desktop\WhisperRoom\WR Proposals and Drawings\` |
| Corporate brand guideline | `C:\Users\bento\Desktop\WhisperRoom\WhisperRoom - Brand Guideline.pdf` |
| Finished client proposal packs | `C:\Users\bento\Desktop\ProposalFiles\<Client>\` |

A local copy of the model table is in `reference/booth-models.md` for fast lookup, but
**`models.json` is the source of truth** — re-read it before quoting a price or a weight.

---

## Estimating dimensions from a client floor plan

Full method: `reference/scale-estimation.md`. The short version, and it is not optional:

- **Establish scale from exactly one anchor, then state which one.** In priority order:
  a printed scale bar → a labeled dimension string → a stated drawing scale
  (`1/4" = 1'-0"`) → a known standard object. Never average two anchors silently.
- **Standard-object fallbacks are estimates, not measurements.** A residential interior
  door is typically 30–36 in and a commercial one 36 in; ceiling grid tile is 24×24 in or
  24×48 in. Use them only when nothing better exists, name the object you used, and give
  the result as a **range**, not a single number.
- **Report every derived dimension with a tolerance.** `Room reads ~12'-6" × 14'-0",
  ±3–4 in from a scale-bar measurement on a phone photo.` A bare number implies a survey.
- **Photos of drawings are distorted.** If the image is a photo rather than a PDF export,
  check whether the drawing's own rectangles stay square across the frame. If they don't,
  say the perspective is skewing the read and widen the tolerance.
- **Never let an estimate silently become a commitment.** Anything that ends up in a
  proposal, a quote, or a SketchUp model gets flagged as estimated until Benton or the
  client confirms it with a tape measure.

## The booth model is never mine to choose

**Do not recommend, suggest, or default to a booth model.** Sales quotes it; I draw what's on
the quote. Putting a model on a drawing that didn't come from the quote reads as a
recommendation — worse, drawing a small one implies it's the largest that fits, which is
usually false and has real consequences in front of a client.

- Ask Benton for the quote link (`sales.whisperroom.com/q/W-…`) and read the model off it.
- Then pull that model's exterior dimensions from `models.json`.
- If I don't have a quote yet, say what the room can take dimensionally and stop there.

### Footprint = booth + clearances (source: `WhisperRoomQuote\assets\layout-render.js`)

The quote tool's own renderer is the authority. Its per-side clearance rule, in inches:

| Side | Clearance |
|---|---|
| Nominal (any wall) | **1"** |
| Vented wall | **6"**, or **10"** with exterior fan silencers (EFS) |
| Door wall — swing | **23.5" / 29.5" / 34.5"** by frame width (<46 / 46 / ≥49) |
| Door wall — ADA ramp | **45.625"** (3'-9⅝"), replaces the swing figure |
| Step fitted | 12" |
| Desk mounted outside | 14" |

Wall panels come in 7 / 16 / 19 / 22 / 28 / 31 / 40 / 43 / 46" widths; the wide-access and
ADA door frame is **49"**. Those are the numbers that decide whether panels make it down a
corridor — use them for delivery-path questions instead of guessing.

## Recommending a layout

- Pull candidate models from `models.json`. Quote the **exterior** dimensions when checking
  fit — that's what `stdDims` / `enhDims` are.
- **The catalog height is the install clearance, not the booth.** `models.json` lists Std
  `6'-11"` and Enhanced `7'-1"`. Those are the figures WhisperRoom markets and the height a
  room has to give, because that is the space needed to lift the tray ceiling up and onto the
  booth during assembly. The **exact** exterior height is slightly less — a 96120 E measures
  `7'-0 5/16"` as drawn. Quote the catalog figure when asking "will it fit"; quote the drawn
  figure only when transcribing a render's own callout.
- **Check the room's ceiling height before anything else** — it disqualifies faster than
  floor area does, and it's the constraint clients forget.
- Prior WhisperRoom drawings place the booth **spaced 1" off the wall** and call out
  **door-swing clearance** on the plan. Follow that convention.
- Delivery path is a real constraint: doorways, elevators, corners, and stairs. Booth
  panels ship flat and assemble in place — if the room is up a flight or through a 30"
  door, raise it rather than discovering it later.
- Offer **two options with the tradeoff named** (e.g. "the 4872 fits with room to walk
  around; the 6084 fills the alcove but leaves only door swing"), not a single verdict —
  the room-feel call is Benton's.
- **Clearance, ventilation routing, and electrical are not things I get to invent.** If a
  recommendation depends on a spacing or airflow number I can't source from the catalog,
  a prior drawing, or `VentilationTechnicalSpecs.pdf`, say so and ask.

## Building the visual

Use the **Artifact** tool. A layout Artifact should be:

- Drawn to a stated scale with a visible scale bar, top-down, north/door orientation marked.
- Room outline, booth footprint, door swing arc, and the 1" wall gap all shown.
- Labeled with the model name and the exterior dims it's drawn at.
- Explicit about what's estimated — put the tolerance **on the drawing**, not just in chat.

### Dimension the top-down properly — this is the default, not an upgrade

Benton reads the plan, not the prose. Overall dimensions alone are not enough; **every in-line
wall run gets its own dimension string on the drawing.**

- **Chain-dimension each side.** One row of segment dimensions closest to the building, one row
  outside it carrying the overall. Every notch, return, and jog gets called out — an L-shaped
  room needs all its runs, not just the bounding box.
- **Close every chain and say so.** The segments must sum to the overall; state the closure.
  A chain that doesn't close means a wall face was misread — find it before publishing.
- **A chain line means segment lengths, never running totals.** If you want distance from a
  datum, use a separate ordinate dimension. Mixing the two on one line is a real drafting error
  and will be read as fact.
- **Round to the nearest inch on the drawing, keep a tenth in the table.** Give a per-run table
  under the plan with the precise decimal so nothing is lost to rounding.
- **Dimension door centerlines** from a named corner, plus door-to-door spacing. That's what
  placement actually turns on.
- **Curved or angled walls have no single in-line dimension.** Run a depth datum down one side
  and give the clear width at each depth; say how the curve was traced and how faithful it is.
- Keep wall dimensions and secondary dimensions (doors, datums, clear rectangles) visually
  distinct, and put a legend on the drawing.

Brand orange is `#ee6216`. Keep working drawings clean and legible over decorated; the
polished-brand treatment belongs in the proposal, not the scratch layout.

---

## Proposals — how we build them

**Everything needed is in this repo. Read `reference/proposal-playbook.md` before
building — it is the full procedure and it is self-contained.** This section is the
summary; `reference/proposal-brand.md` is the one-page brand card.

The operator gives me **a folder of renders and a client name**. I read the renders
from whatever folder they name. The deliverable is a print-ready PDF they forward to a
real customer, so accuracy beats speed: a caption that contradicts the drawing is worse
than no caption. No prices, lead times or freight — sales owns those.

Needs on the machine: **Node, Google Chrome, and Python with PyMuPDF**. The generator
needs no `npm install`.

### The generator — never invent a layout

- `proposals/build-v2.js` in this repo. It reads its CSS and wordmark from
  `proposals/assets/`, so keep that folder together.
- Copy `proposals/examples/example-client/proposal-v2.json` and edit it. Build and print
  that example once and look at every page — **that output IS the format.**
- `WhisperRoom Proposals\docs\PROPOSAL-GUIDELINES.md` is **superseded** (original landscape
  v1). Do not build from it.

Non-negotiables:

- **US Letter portrait**, one render per page. Cover = logo top-left + meta top-right +
  orange eyebrow + two-tone left-aligned headline + hero + caption + three-card spec
  strip + callout. Content pages = same header with `PAGE 0n / N`, orange section number
  + title, one render in a bordered box, `Image 0n` caption. Last page ends in the dark
  closing band.
- **Brand orange `#ee6216`.** No second accent color without a branding decision.
- **Footer both sides, every page:** orange `Phone:`/`Email:` labels left —
  `Phone: (865) 558-5364 · Email: info@whisperroom.com · www.whisperroom.com` —
  and `WhisperRoom, Inc.™` plus the Knoxville address right.
- **Render order:** hero exterior in the finished room → dimensioned view → side
  elevation → rear/ventilation → top-down plan with the door swing. Lead with the
  exterior, always include a dimensioned view, always close with the plan, and
  **never repeat the hero on page 2.**
- **SketchUp exports are transparent PNGs.** Flatten onto white and trim dead margins
  before use — playbook §5. Never drop a transparent PNG into the pack.
- **Print with headless Chrome** (Puppeteer is not installed). Chrome sometimes does not
  exit after writing the PDF; check whether the file appeared before assuming failure.

### Caption discipline — this is where the real risk is

These go out under WhisperRoom's name to real customers.

- Write only what the image shows. **Avoid left/right spatial claims** — renders get
  mirrored, and a draft once told a client their work surface was on the wrong wall.
- **Transcribe dimension callouts exactly.** Crop and zoom to 300–700 dpi to read them.
  Never round, guess, or infer what an unreadable number measures.
- On acoustics the only defensible customer-facing figure is the website's
  **ASTM E336 dB range — never STC, never the word "soundproof."**
- Cross-check the product name against the renders; if the renders disagree with what
  the operator said, trust the renders and flag it.
- **Report every line I invented** — anything not readable from a render or lifted
  verbatim from the boilerplate goes in an explicit list before it ships, including what
  I chose *not* to caption because I couldn't identify it.

### Verify before saying done

Rasterize the finished PDF back to PNG with **PyMuPDF** (no poppler here) and look at
**every page**, plus a separate crop of **every bottom edge** — a headline that wraps
silently pushes the footer off the page. Confirm the page count, the hero, and that
nothing overflows.

Output: on Benton's machine the PDF goes to
`C:\Users\bento\Desktop\ProposalFiles\<Client>\<Client>-Booth-Renderings.pdf`; on any other
machine, a `ProposalFiles/<Client>/` folder wherever the operator says. Never overwrite
anything already in that folder unless told to. Working files stay in the scratchpad.

The `whisperroom-proposal` skill (`skills/whisperroom-proposal/SKILL.md` in this repo,
copy it into `~/.claude/skills/`) is the same material in short form.

---

## Benton's drawing conventions — apply these without being asked

- **Imperial throughout**, unless a drawing or a client says otherwise. Feet and inches on
  every dimension; set SketchUp to Architectural units.
- **8'-0" ceilings by default** unless the client states a height. Draw it, label it as the
  house default, and keep asking for the real number — it is still the thing that disqualifies
  a booth fastest.
- **Dimension the doors off their wall corners.** Corner → near jamb, then the opening width.
  This is how a booth actually gets placed against a wall, so it is not optional.
- **Square the wall corners.** Mitre the outside face where two walls meet — never let wall
  solids cross and overshoot each other into an X.
- Wall thickness is cosmetic: build outward from the measured interior face so it never moves
  a dimension. **Default to 4"** (Benton, Aug 2026). Historical drawings read ~5"; that is
  fine on existing work and does not need correcting, because the thickness never moved a
  dimension in the first place.

## SketchUp itself

**Full standard: `reference/sketchup-drawing.md`.** Read it before writing or changing a
script — it carries the model standards, the default materials, the geometry rules, and the
traps that have already cost time.

I cannot drive the SketchUp window — no live bridge, and I can't see the viewport or click
anything. What I *can* do is write Ruby against the SketchUp API and hand it over: rooms built
to the measured interior dimensions, doors as real openings with swings, booth shells and ADA
ramps to the clearance rules above, tags, materials, and dimension entities.

- Scripts live in `scripts/`. `scripts/csusb-rooms.rb` is the working example.
- **The panel has two tabs.** TOOLS is the everyday kit. CLIENT DRAWINGS is for a job
  drawn once for one customer. A one-off gets `# @tab client` in its header, right
  under `@title`; no header means TOOLS. Search looks in both tabs, so filing a
  script away never makes it harder to find by name.
- **Bump `scripts/wr_tools/VERSION` when you change the plugin.** It is the only
  place the version lives; the panel compares it against the same file on GitHub
  and shows an update banner to anyone running an older copy.
- Run via **Extensions → Developer → Ruby Console** (not Window), then
  `load "C:/.../scripts/<name>.rb"` — forward slashes, and Ctrl+Z before re-running.
- Imperial / Architectural units, 8'-0" default ceilings, walls built outward and mitred at
  the corners, floor `0128_White`, walls `0099_LightSteelBlue`, doors `0043_SaddleBrown`.
- Dimension **all four sides** plus every door off its wall corner.
- **I can't RUN a script here, but I can now PARSE one.** There is still no `ruby.exe` on
  this machine, so nothing gets executed outside SketchUp — say plainly that a script is
  unrun, wrap the build so it fails loudly, and list everything in the model that isn't
  measured. But `scripts/rbparse.py` drives the CRuby 3.2 library SketchUp ships
  (`x64-ucrt-ruby320.dll`) and gives a **real syntax check** of every `.rb` in `scripts/`.
  Run it before committing any Ruby change. `scripts/rbcheck.py` is a bracket-and-`end`
  counter, not a parser — a clean run there is not evidence a file is valid, and reporting
  it as such is how a syntax error once shipped and made a tool silently do nothing.

## Working conventions

- **Prices in `models.json` are internal.** Never put a price in a client-facing artifact
  unless Benton explicitly asks for that pack.
- **Never touch the `WhisperRoomQuote` repo from here** — read it, don't write it.
- Per-client working notes go in `clients/<client-slug>/`. Keep client-supplied plans and
  renders out of git (see `.gitignore`); commit the notes and the estimate, not the assets.
- Finished proposal PDFs go to `C:\Users\bento\Desktop\ProposalFiles\<Client>\`, never here.
- Provenance labels (**observed / derived / reported / assumed**) apply to every dimension
  I report. On this work they are the whole point.
