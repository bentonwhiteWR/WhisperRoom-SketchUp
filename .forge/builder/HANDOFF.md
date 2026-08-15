# Builder A handoff — panel redesign, spec steps 1-5

## Produced

- `scripts/wr_tools/panel.html` — rewritten. Token sheet (light + dark), one row
  per script, action/ability row renderers, state strip, collapsible categories
  with persisted state, Pinned group, dev/workshop/archive shelves behind a
  footer switch, toolbar mirror moved to the bottom, slot editor and rename as
  bottom sheets. Every existing callback name kept; two new ones added
  (`collapse`, `devtools`).
- `scripts/wr_tools/main.rb` — `@icon` and `@shelf` parsing, per-script `icon` /
  `shelf` / `dialog` in the payload, the icon sprite and icon map seam, the
  `wr-ico-*.svg` glob beside `ico-*.svg`, `ui_collapsed` / `ui_dev` prefs, and
  the autorun guard fix in `toggle` (`load_quietly`).
- `scripts/*.rb` header lines only — the 14 approved `@title` renames, the new
  six-category `@cat` tree, `@shelf` on the eight shelved scripts, and a first
  header for `csusb-rooms.rb` and `diag-favourites.rb`.
- `scripts/explode-view.rb`, `scripts/proposal-scenes.rb` — one line each: the
  missing `unless $wr_no_autorun` guard on their top-level autorun.

## Read first

1. `.forge/scoper/panel-redesign.md` — the spec. Steps 1-5 are done; 6 and 7 are
   out of scope this round and untouched.
2. The **icon seam** section below — it is the contract Builder B's files have to
   meet, and nothing in this repo enforces it.
3. `main.rb`'s comment above `load_quietly` — it records why both autorun globals
   are set and why they are restored.

## The icon seam, as implemented (Builder A's side)

| File | Shape | Consumed by |
|---|---|---|
| `scripts/wr_tools/wr-icons.svg` | one `<svg>` containing `<symbol id="wr-…" viewBox="0 0 24 24">` blocks | read raw by `main.rb#sprite`, shipped as `payload['sprite']`, injected into `#sprite` in the panel; rows draw `<use href="#wr-…">` |
| `scripts/wr_tools/icon-map.json` | flat object, `{"build-room.rb": "wr-room", …}` — script filename to symbol id | `main.rb#icon_map`; ids may be written with or without the `wr-` prefix, `wr_id` normalises |
| `scripts/wr_tools/wr-ico-<id>.svg` | standalone face for a toolbar slot, `<id>` **without** the `wr-` prefix (symbol `wr-room` ⇒ file `wr-ico-room.svg`) | `icon_library` (offered in the picker, id `wr-room`) and `icon_file` |

Resolution per script: its own `# @icon` line → `icon-map.json` → `wr-default`.
`wr-default` is defined inside `panel.html` itself and is the safety net: a
missing or unreadable sprite degrades every row to that glyph and **never**
blanks the list (verified headlessly). The map is re-read on every render, so
dropping the file in and hitting Rescan is enough — no SketchUp restart.

## Assumptions

- **`prefers-color-scheme` inside SketchUp's Chromium is assumed, not verified.**
  It works in desktop Chrome (observed). The tokens are also driven by
  `:root[data-theme="dark"|"light"]`, so if the OS query turns out to do nothing
  in the HtmlDialog, a manual theme pref is one line of JS and no restyling.
- The sprite symbols hard-code `#ee6216` for the orange subject element (that is
  the icon system's own rule). On the dark theme the surrounding tokens lift to
  `#f47b35` but the icon orange does not. Assumed acceptable; the mockup does the
  same.
- `# @shelf archive` is used for the three files GOAL.md said to shelve rather
  than delete (`booth-4260-s.rb`, `booth-96168-s.rb`, `csusb-rooms.rb`). The
  Researcher's grammar allowed `dev|workshop|archive`; the mockup only drew two
  shelves. Third shelf reads "One-off & superseded".

## Open questions

1. **Intra-category order contradicts the Researcher on one category.** The spec
   says "category order, then alphabetical", which is what shipped. In *Build the
   booth* that sorts the ladder backwards — Block-out (least capable) first,
   share-link (the right answer on a real job) last — which is exactly what
   `proposed-structure.md` warned against. Fixing it needs either an additive
   `# @rank` header or a per-category rung table. Neither is in this round's
   scope. Flagged, not silently resolved.
2. Six scripts have a proposed title in the Researcher's category tree but are
   **not** in the approved 14 renames (`list-scenes.rb`, `orbit-export.rb`,
   `explode-view.rb`, `save-scene-components.rb`, `find-replace-names.rb`,
   `merge-materials.rb`). Their old titles are untouched. Benton's call.
3. `diag-favourites.rb` — the Researcher asked whether it is now dead. It is
   shelved under `dev` with a real title; still unanswered.
4. Ability rows are not reachable by the arrow-key/Enter navigation, which walks
   runnable rows only. Deliberate, but worth a second opinion.
