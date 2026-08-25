# How we build a WhisperRoom booth-renderings proposal

The complete procedure, end to end. Self-contained on purpose: an agent with this
file and the repo should be able to produce a pack that matches Benton's without
asking him anything except the client name and which render is the hero.

`reference/proposal-brand.md` is the one-page quick card for the same material.
This file is the long form. Where they ever disagree, **this file is wrong and the
newest shipped PDF is right** — see "The standard is a file, not a document" below.

---

## 0. What this is and who it goes to

A booth-renderings proposal is a print-ready PDF that a WhisperRoom rep forwards
to a real customer, often a commercial furniture dealer or an architect who
forwards it again. It is 1 cover page plus N content pages, one render per page.

It is **not** a quote. It carries no prices, no lead times and no freight. Sales
owns those and they live in the quote link.

Because it goes out under WhisperRoom's name, **accuracy beats speed and beats
polish**. A caption that contradicts the drawing is worse than no caption.

---

## 1. The standard is a file, not a document

> **The newest shipped pack is the standard. Open it before every build.**

**On Benton's machine** that is the newest PDF under
`C:\Users\bento\Desktop\ProposalFiles\<Client>\`. As of August 2026:
`ProposalFiles\PeoplesSpace\PeoplesSpace-Booth-Renderings.pdf` (6 pages),
superseding `ProposalFiles\David Smith\David-Smith-Booth-Renderings.pdf` (5 pages).

**On any other machine** that Desktop folder does not exist, and you do not need
it. Build the worked example in this repo and read the output — that IS the format:

```bash
cd <this repo>/proposals
node build-v2.js examples/example-client/proposal-v2.json ./reference-pack.html
# then print it (section 7) and look at every page
```

Verified: a clean clone of this repo builds that example with no other input.

Two documents describe the format. Only one is current:

| File | Status |
|---|---|
| `reference/proposal-brand.md` (this repo) | Current — quick card |
| `reference/proposal-playbook.md` (this file) | Current — full procedure |
| `WhisperRoom Proposals\docs\PROPOSAL-GUIDELINES.md` | **SUPERSEDED.** Describes the original landscape v1 format. Do not build from it. |

---

## 2. Never invent a layout

The pack is generated. There is one generator and one config shape.

- **Generator:** `proposals/build-v2.js` **in this repo**. Needs Node. No
  `npm install` — it only uses `fs` and `path`. It reads its CSS and wordmark
  from `proposals/assets/`, so keep the folder together.
- **Worked example:** `proposals/examples/example-client/` — a real two-booth,
  nine-plate pack with the client name replaced. Build it, print it, look at it.
  That output IS the format.
- **Shipped client packs** live in the PRIVATE `whisperroom-proposals` repo
  (branch `master`) under `examples/<client-slug>/`, because this repo is public
  and real customers' rooms, names and dimensions do not belong in it. You do not
  need them to build correctly — the example above is enough.

Copy the **newest** example and edit it. Do not hand-author HTML, do not restyle,
do not add a page type the generator doesn't have.

The `-v2` in the filenames is the **generator format version**, not a proposal
revision. Never put "V2" in a client-facing filename unless the pack really is a
second revision for that client.

---

## 3. The page design

### Everything, every page

- **US Letter portrait**, 612 × 792 pt (8.5 × 11 in). Not landscape.
- One render per page. Content box is 700 × 962 px — the generator prints the
  fitted size and remaining free space for every plate when it runs.
- **Brand orange `#ee6216`.** No second accent colour without a branding decision.
- Type: system grotesque (Arial/Helvetica). Bold tight-tracked headline; grey
  uppercase letter-spaced labels and meta.

### Footer — on every page, both sides

Left, orange bold labels with grey values:

```
Phone: (865) 558-5364 · Email: info@whisperroom.com · www.whisperroom.com
```

Right, bold `WhisperRoom, Inc.™` over
`322 Nancy Lynn Lane, Suite 14` / `Knoxville, TN 37919 USA`.

### Cover page

1. **Header** — wordmark top-left with letter-spaced `SOUND ISOLATION ENCLOSURES`
   beneath; top-right a three-line grey letter-spaced block: doc type / client /
   month year. Rule under both.
2. **Eyebrow** — orange letter-spaced caps, e.g. `BOOTH RENDERINGS`.
3. **Headline** — large, bold, two-tone, left-aligned (never centred): lead line
   in near-black (`Sound isolation for`), client name in brand orange.
4. **Hero render**, full content width.
5. **Caption** — orange bold lead-in (`captionLead`) then grey body (`caption`).
6. **Three-card spec strip** in a bordered box. Each card is a letter-spaced grey
   label, a value, and a sub-line.
7. **Callout** — light grey panel with an orange left rule, bold lead-in
   (`About these renderings.`) then body.
8. Footer.

### Content pages

1. **Header** — same logo block left; top-right three lines: booth descriptor /
   booth name / `PAGE 0n / N` with the number in orange bold. Rule beneath.
2. **Section line** — short orange bar, orange section number (`01`), then the
   title in bold letter-spaced caps. Right-aligned grey letter-spaced descriptor
   on the same line. **Keep that right-hand descriptor short.** A long one wraps
   to two lines and collides with the title; `Fort Vancouver Regional Library`
   fits, `Fort Vancouver Regional Library · Podcast Booth` did not.
3. **Lead paragraph** with a bold lead-in (first plate's page only).
4. **Render** inside a thin bordered box.
5. **Caption** — `Image 0n` in orange bold, then grey body.
6. Footer.

### Closing band

The last page ends in a dark band: heading with an orange `?`, body text,
the footer contact line, and the wordmark with the address.

---

## 3b. The pricing page — new, and normally OFF

`proposals/build-v2.js` grew an optional **pricing sheet** in August 2026. A config
with no `pricing` block builds exactly as it always did: verified by rebuilding
the worked example before and after and diffing the HTML — the only difference in
the whole 10-page pack is the appended CSS block, zero markup changes.

**A pack carries no prices unless Benton explicitly asks for that pack.** That rule
has not moved. Sales owns pricing, and a stale figure in a forwarded PDF is worse
than no figure. When he does ask, this is the page type to use rather than
inventing one.

When present it is the **last page** and it carries the closing band, so the last
plate reverts to an ordinary footer. Shape:

```json
"pricing": {
  "num": "04", "title": "Pricing", "extra": "Quoted 25 August 2026",
  "model": "Three configurations", "boothOf": "Pricing",
  "itemHead": "Line item", "lead": "<b>…</b> …", "note": "… <a href=…>…</a>",
  "columns": [{ "name": "…", "sub": "…", "quote": "Quote W-…" }],
  "rows":    [{ "item": "…", "desc": "…", "values": ["$1.00", "$2.00"] }],
  "summary": [{ "label": "Subtotal", "values": [...] },
              { "label": "Total", "total": true, "values": [...] }]
}
```

**The generator does no arithmetic, on purpose.** Every figure comes from the
config, which comes from a real quote. A subtotal this file computed itself would
be a number nobody had checked against the quote it claims to reproduce. Check the
columns yourself before building — line items must sum to the subtotal, and
subtotal + discount + delivery must equal the total — and say in your report that
you did.

**Quote pages are readable without auth.** `https://sales.whisperroom.com/q/W-…?t=…`
is server-rendered, so `curl` plus a tag strip gives the full line-item table,
totals and the prepared-for block. The `/api/quote/…` endpoints are 401. Read the
quote rather than retyping figures from a screenshot, and let the line items
identify which quote goes with which configuration.

---

## 4. Render order

The established slot order, and the reason for it — the pack should read as a walk
around the booth that ends on the plan:

```
hero exterior in the finished room
  → dimensioned three-quarter or elevation
  → side elevation
  → rear / ventilation package
  → top-down plan with the door swing
```

Rules that don't bend:

- **Lead with the exterior.** The first thing the customer sees is the booth as it
  will look in their space, not a technical drawing.
- **Always include at least one dimensioned view.**
- **Always close with the plan.**
- **Do not repeat the hero on page 2.** The cover already showed it. Benton has
  asked for this explicitly; it reads as padding otherwise.

Benton usually names the hero and sometimes the second image. The rest is your
call — and **say why you ordered them as you did** in your report back.

---

## 5. Preparing the images

SketchUp exports arrive as **transparent PNGs**, typically 2400 × 1366. They are
authored for a light background even though they look like light-grey line work on
a dark viewer — the callout text measures around luminance 62, i.e. near-black.

For each render:

1. **Flatten onto white.** `Image.new('RGB', size, (255,255,255))` then paste with
   the alpha channel as the mask. Never ship a transparent PNG into the pack —
   the generator has no backdrop and the result is unpredictable.
2. **Trim dead margins** on technical plates. A SketchUp export often has 30-40%
   empty canvas around the drawing; trimming to the content bounding box plus ~2%
   padding makes the plate substantially larger on the page. Threshold the
   luminance a little below pure white so faint dimension lines are kept.
   *Do not trim the hero* — its background is part of the picture.
3. **Resize** to about 1900 px wide (1600 for the hero if it is already smaller)
   and save as JPEG, quality 88, `subsampling=0`. At ~7.3 in on the page that is
   roughly 260 dpi, which is proper print resolution.
4. Save into `examples/<client-slug>/renders-web/` with ordered names:
   `01-main-render.jpg`, `02-front-dimensioned.jpg`, and so on.

Target pack size **2.5–3.6 MB**. Under is fine. Downsample only if well past, and
never at visible cost to print quality.

---

## 6. Caption discipline — this is where the real risk is

These sentences go to a customer under WhisperRoom's name.

- **Read each render. Write only what that image shows.**
- **Avoid left/right spatial claims entirely.** Renders get mirrored. A draft once
  told a client their work surface was on the wrong wall. Use "alongside", "the
  adjoining wall", "beyond", "at the far end".
- **Transcribe dimension callouts exactly.** Crop and zoom the render to 300–700 dpi
  and read them; do not work from a thumbnail. Never round, never guess, never infer
  what an unreadable number measures. If a figure is legible but unlabelled, cite it
  "as drawn" without saying what it measures.
- **Never state a model number, dimension, price or acoustic claim you cannot source
  from the renders or the boilerplate.** The catalogue is a legitimate source for
  Benton, but if a figure isn't on the drawing, leave it out rather than importing it.
- **Acoustics:** the only defensible customer-facing figure is the website's
  **ASTM E336 dB range**. Never STC. Never the word "soundproof".
- **Cross-check the product name.** The renders usually carry a legible label. If
  the label and what Benton said disagree, **trust the renders and flag it**.
- **Individual vs organisation.** Copy written for a clinic reads wrong for a
  person. Check who the client actually is before reusing an example's boilerplate.
- **Client name spelling is Benton's call, not the company's.** PeopleSpace spell
  themselves without the second `s`; Benton wanted `PeoplesSpace`. Ask or match his
  folder — don't correct him silently.

---

## 7. Build and print

```bash
cd <this repo>/proposals
node build-v2.js examples/<slug>/proposal-v2.json <work-dir>/<slug>.html
```

The generator prints a plate-fit table — image, aspect ratio, fitted size and free
pixels. **Read it.** A plate with `free 0px` is filling the box; a negative number
would mean an overflow.

Then print. **Puppeteer is not installed locally** (no `node_modules` in the repo
clone), so use headless Chrome:

```bash
"/c/Program Files/Google/Chrome/Application/chrome.exe" \
  --headless --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="<work-dir>\<slug>.pdf" \
  "file:///<work-dir>/<slug>.html"
```

`--print-to-pdf` wants a Windows path; the `file:///` URL wants forward slashes.
Chrome must be installed — Edge (`msedge.exe`) takes the same flags if it isn't.

Chrome defaults to US Letter portrait with backgrounds on, which is what the CSS
expects. `--no-pdf-header-footer` suppresses the browser's own page furniture.

---

## 8. Verify before declaring done

Not optional, and not a spot check.

- **No poppler / `pdftoppm` on this machine.** Rasterize with **PyMuPDF (`fitz`)**.
- Confirm the page count matches the comparable prior pack and every page is
  612 × 792.
- **Look at every page.** Confirm the hero is the right image, nothing is stretched
  or cropped wrong, no text overflows.
- **Crop and check every bottom edge separately.** A headline that wraps to three
  lines against a two-line budget silently pushes the footer off the page, and a
  pass that only looks at the middle of each page will miss it. Stack the six
  footer crops into one image and look at them together.
- **Check callout legibility at 300–400 dpi**, not at the 110 dpi you used for the
  page overview. Small dimension text looks illegible at preview resolution and is
  usually fine in print — confirm which.

Python stdout here is cp1252. Call
`sys.stdout.reconfigure(encoding='utf-8', errors='replace')` before printing any
text extracted from a PDF, or the dimension marks (′ ″) crash the script.

---

## 9. Output and housekeeping

- **PDF** → `C:\Users\bento\Desktop\ProposalFiles\<Client>\<Client>-Booth-Renderings.pdf`.
  Do **not** overwrite or delete anything already in that folder unless Benton says
  to override in place.
- **Config and web renders** → `WhisperRoom Proposals\examples\<client-slug>\`,
  so the next job starts from a warm example.
- **Working files** (HTML, check rasters) stay in the scratchpad. Never on the Desktop.
- **Do not touch the `WhisperRoomQuote` git repo.** This is filesystem-only work.

---

## 10. Always report, and always list what you invented

You have images and a client name. No quote, no spec sheet. So **every line not
readable from a render or lifted verbatim from the boilerplate goes in an explicit
list** for Benton to check before it ships. Include:

- Names, spellings and anything about who the client is
- Any descriptive word you chose (`acoustic-foam-lined`, `silencer box`)
- The whole closing paragraph if it is adapted boilerplate
- **What you chose NOT to caption because you couldn't identify it**

Also report what you verified and how, and any caption where you had to make a
judgement call.

---

## 11. `proposal-v2.json` shape

```
client, docType, date, contact { phone, email, web }

cover {
  eyebrow, headlineLead, headlineLines, sub, image,
  captionLead, caption,
  cards [ { label, value, sub } ],      // exactly three
  calloutLead, callout
}

sections [ {
  num, model, boothOf, extra, lead,
  plates [ { image, view, caption } ]
} ]

closing { heading, body }
```

`extra` is the right-hand descriptor on the section line — keep it short (§3).
`view` becomes the plate title. `num` is the section number shown in orange.

---

## 12. Worked example — the PeoplesSpace pack, August 2026

Six pages for a dealer (PeopleSpace Portland) presenting to their end client,
Fort Vancouver Regional Library, for one MDL 96120 E with the ADA package.

| Page | Image | Slot |
|---|---|---|
| 1 | `FrontMainRender.png` | Cover hero — appears **only** here |
| 2 | `Front.png` | Dimensioned Elevation |
| 3 | `Scene 1.png` | Dimensioned Three-Quarter View |
| 4 | `Side.png` | Ventilation Package |
| 5 | `Back.png` | Rear View |
| 6 | `TopDown.png` | Top-Down Plan |

Cards: `Booth / MDL 96120 E / With ADA package`,
`Height / 7' 5/16" / As drawn on the renderings`,
`In this pack / 5 renderings / Exterior, dimensioned, plan`.

The height card is transcribed from the drawing, not from the catalogue — the
renders carried `7' 5/16"` and that is what shipped. The catalogue footprint
(8'-2" × 10'-2") was deliberately **left out**, because it appears on no render.

Config: `WhisperRoom Proposals\examples\peoplespace\proposal-v2.json`.
That is the newest example — copy it.
