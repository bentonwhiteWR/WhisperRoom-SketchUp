# Proposal brand — quick reference

**Source of truth:** `C:\Users\bento\Documents\Claude\WhisperRoom Proposals\docs\PROPOSAL-GUIDELINES.md`
Read it before every build. This page is a reminder so I don't have to open it to sanity-check
a color or a footer; it is not a replacement.

## Page

- US Letter **landscape**, 11 × 8.5 in. White. No print margins — the layout handles padding.
- One render per page, one topic per page. 1 cover + N content pages.
- Output is a PDF emailed to the client. Renders come from SketchUp + V-Ray.

## Color

| Role | Hex |
|---|---|
| Brand orange (titles, footer, logo) | `#ee6216` |
| Orange dark accent (optional, screen only) | `#d4540e` |
| Running-header gray | `#6b6b6b` |
| Body ink | `#222` |

No second accent color without a branding decision.

## Type

Arial / Helvetica. (Web brand font is **Satoshi** with **DM Mono**; swap `--wr-sans` in
`assets/proposal.css` only if the format is deliberately moved to it.)

- Proposal title: bold, ~27 pt, brand orange, centered
- Footer contact line: bold, ~11 pt, brand orange
- Running header: ~7.5 pt, gray

## Layout

**Cover:** running header (top-left, tiny gray) → centered logo ~0.86 in tall → centered
orange title `Proposal for {Client}` → hero render → footer.

**Content pages:** running header → centered orange title → one render sized to fit → footer.

**Footer, verbatim:**

```
Phone: (865) 558-5364 - Email: info@whisperroom.com — www.whisperroom.com
```

## Render sequence

1. Cover / hero — booth open, three-quarter view
2. Booth in the room, door open
3. Booth closed, in context
4. Dimensioned view (room + booth footprint)
5. Alternate dimensioned angle — door-swing clearance
6. Opposite corner
7. Ventilation / detail
8. Top-down floor plan

Not every proposal needs all eight. Lead with the hero, include at least one dimensioned
view, close with the floor plan.

## Don't

- Don't stretch, crop, or recolor the logo, or set it on a colored background.
- Don't change the footer wording.
- Don't ship full-resolution PNGs in the emailed proposal — target 2.5–3.6 MB total.
- Don't put "V2" in a client-facing filename unless it really is a revision (the `-v2` in
  `build-v2.js` / `proposal-v2.json` is the *generator format* version).

## Machine facts

- No poppler / `pdftoppm`. Rasterize PDFs for checking with **PyMuPDF (`fitz`)**.
- Puppeteer isn't installed locally. Print with **headless Chrome**.
- Python stdout is cp1252 — `sys.stdout.reconfigure(encoding='utf-8', errors='replace')`
  before printing extracted PDF text, or dimension marks (′ ″) crash the script.
