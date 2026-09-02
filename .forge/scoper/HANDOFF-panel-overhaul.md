# HANDOFF — panel overhaul (design step only)

Scoper, 1 Sep 2026, plugin 1.19.3 at `636f4fd`. No code changed, no VERSION bump, nothing
committed.

## Produced

- `.forge/scoper/panel-overhaul.md` — the spec: inventory of the current panel, what is wrong
  with it as a working surface, the direction, hard constraints, the audit fixes it absorbs, the
  design piece by piece, 22 icon briefs + the monogram rule, the copy-pass list, five build slices
  with acceptance checks, open questions.
- `.forge/scoper/panel-overhaul.mockup.html` — the review surface: the proposed panel at real
  HtmlDialog size (330 / 430 / 520 wide × 640) with the real 55 tools, three switchable variants
  (A Workbench, B Dense list, C Palette first), live search / tabs / switches / ⋯ menu, an
  Approve / Needs changes + note per section, and a copy-back JSON box.
- `.forge/scoper/panel-overhaul-mockup-look.png` — the one headless-Chrome look at the mockup
  (before the tile-label fix; the fix is in the file).
- `.forge/scoper/panel-current-430x640.png`, `-430x640-light.png`, `-330.png`, `-full-list.png`,
  `-search-csusb.png`, `-search-wall.png` — the CURRENT `panel.html` rendered in headless Chrome
  with a payload built from the real script headers.
- `.forge/scoper/panel-harness/` — `scan.py` (Python port of `main.rb`'s header parsing → the
  `scripts` payload array), `harness.py` (wraps the real `panel.html` with a stubbed
  `window.sketchup` and a `payload`-shaped object, screenshots it), `README.md`. This is how a
  Builder verifies each slice without SketchUp.

## Read first

1. `.forge/scoper/panel-overhaul.md` §3 (direction) and §7 (slices) — the rest is reference.
2. The mockup, with the variant Benton picked and his pasted JSON beside it.
3. `scripts/wr_tools/panel.html` — the whole file; it is one script block and the slices edit it
   in place. `scripts/wr_tools/main.rb:1399-1476` for the dialog options and the 15 callbacks.
4. `.forge/scoper/panel-redesign.md` — the 15 Aug pass. It shipped; do not redo it.
5. `.forge/auditor/full-audit-A-plugin-core.md` A6 and A11 for the findings the slices close.

## Assumptions

- Headless desktop Chrome stands in for SketchUp's CEF 88. Every CSS feature used in the panel
  part of the mockup is CEF-88-safe by version tables (observed in the 15 Aug audit's table plus
  `position: sticky` 56, grid 57); `:has()` appears only in the review page, never in the panel
  CSS. Not verified in the dialog itself.
- The tool list, categories, tabs, shelves, ranks, abilities and settings in the mockup are the
  real headers as of `636f4fd` (observed via `scan.py`). The pinned set is `defaults.json`'s
  (observed). The Recent list, the pending 1.19.4 and which abilities are on are invented working
  state and are labelled so in the page.
- 55 scripts + the built-in Reference-geometry ability = the audit's "56 panel scripts". The 24
  default-icon scripts match the audit's count exactly (observed).
- The footer clipping at 430 and 330 is real in Chrome; I assume the dialog shows the same, since
  the CSS is a fixed-width flex row with no wrap.
- Slices 1-3 need no Ruby because every proposed control maps to an existing callback
  (derived from reading both files' contract; listed in the spec §4).

## Open questions (for Benton, via the mockup)

1. Which variant: A Workbench (recommended), B Dense list, C Palette first.
2. Does moving Rescan / Folder / Console / dev-tools / shop-default into a ⋯ menu hide anything
   he reaches for daily? Rescan is the likeliest to deserve its own button.
3. Tile labels: three-line titles as drawn, an additive `@short` header, or truncation.
4. Keep the Recent strip (free — `recent` is already in the payload — but one more band).
5. Monograms for the five client one-offs, or real glyphs.
6. The §6.10 copy-pass wording — his words; the list is what needs a decision.
7. Ship the toolbars section collapsed in the shop default (his to save).

Blocked on: Benton's reaction. Nothing else.
