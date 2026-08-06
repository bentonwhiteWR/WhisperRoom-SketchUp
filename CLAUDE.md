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

| Thing | Path |
|---|---|
| Booth model catalog (dims, weights, prices, vents) | `C:\Users\bento\Documents\Claude\WhisperRoomQuote\whisperroom-catalog\data\models.json` |
| Options / packages / compatibility | same folder — `options.json`, `packages.json`, `compatibility.json` |
| Top-down wall + door + vent art (PNG) | `...\WhisperRoomQuote\assets\topdown\` |
| Booth elevation art | `...\WhisperRoomQuote\assets\booth-art\` |
| **Proposal brand + layout spec** | `C:\Users\bento\Documents\Claude\WhisperRoom Proposals\docs\PROPOSAL-GUIDELINES.md` |
| Proposal generator | `...\WhisperRoom Proposals\build-v2.js` |
| Prior proposal configs (copy the newest) | `...\WhisperRoom Proposals\examples\<client>\proposal-v2.json` |
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

## Recommending a layout

- Pull candidate models from `models.json`. Quote the **exterior** dimensions when checking
  fit — that's what `stdDims` / `enhDims` are.
- Std ceiling is `6'-11"`, Enhanced is `7'-1"`. **Check the room's ceiling height before
  anything else** — it disqualifies faster than floor area does, and it's the constraint
  clients forget.
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

Brand orange is `#ee6216`. Keep working drawings clean and legible over decorated; the
polished-brand treatment belongs in the proposal, not the scratch layout.

---

## Proposals — the brand rules

`WhisperRoom Proposals\docs\PROPOSAL-GUIDELINES.md` is the source of truth. Read it before
each build; the summary in `reference/proposal-brand.md` is a reminder, not a replacement.

Non-negotiables carried forward:

- **US Letter landscape, one render per page.** Cover = logo + centered orange title + hero.
  Content pages = running header, orange title, one render, footer.
- **Brand orange `#ee6216`.** No second accent color without a branding decision.
- **Footer contact line verbatim:**
  `Phone: (865) 558-5364 - Email: info@whisperroom.com — www.whisperroom.com`
- **Render order:** hero → booth in room, door open → closed → dimensioned view → alternate
  dimensioned angle → opposite corner → ventilation/detail → top-down plan. Lead with the
  hero, include at least one dimensioned view, close with the floor plan.
- Use the generator (`build-v2.js`) and copy the newest example config. **Never invent a
  layout.**

### Caption discipline — this is where the real risk is

These go out under WhisperRoom's name to real customers. A caption that contradicts the
drawing is worse than no caption.

- Write only what the image shows. **Avoid left/right spatial claims** — renders get
  mirrored, and a draft once told a client their work surface was on the wrong wall.
- **Transcribe dimension callouts exactly.** Never round, guess, or infer what an
  unreadable number measures.
- On acoustics the only defensible customer-facing figure is the website's
  **ASTM E336 dB range — never STC, never the word "soundproof."**
- Cross-check the product name against the renders; if the renders disagree with what
  Benton said, trust the renders and flag it.
- **Report every line I invented** — anything not readable from a render or lifted verbatim
  from the boilerplate goes in an explicit list before it ships, including what I chose
  *not* to caption because I couldn't identify it.

The `whisperroom-proposal` skill covers the generator mechanics and the verification pass
(rasterize every page back to PNG, check every bottom edge). Invoke it for actual builds.

---

## Working conventions

- **Prices in `models.json` are internal.** Never put a price in a client-facing artifact
  unless Benton explicitly asks for that pack.
- **Never touch the `WhisperRoomQuote` repo from here** — read it, don't write it.
- Per-client working notes go in `clients/<client-slug>/`. Keep client-supplied plans and
  renders out of git (see `.gitignore`); commit the notes and the estimate, not the assets.
- Finished proposal PDFs go to `C:\Users\bento\Desktop\ProposalFiles\<Client>\`, never here.
- Provenance labels (**observed / derived / reported / assumed**) apply to every dimension
  I report. On this work they are the whole point.
