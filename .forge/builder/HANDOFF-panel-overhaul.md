# HANDOFF — panel overhaul, built (variant A Workbench)

Builder, 2 Sep 2026. Spec `.forge/scoper/panel-overhaul.md`, approval
`.forge/scoper/panel-overhaul.approval.json` (all eleven sections, no notes). Five
slices, five versions, each committed, pushed to `origin/main` and installed locally
with `scripts/install-plugin.py` for SketchUp 2024 and 2026. **No SketchUp ran on this
machine; nothing below was seen inside the dialog.** Every "observed" claim is headless
desktop Chrome or SketchUp's Ruby DLL driven from Python.

## Produced

| version | commit | slice | files |
|---|---|---|---|
| 1.19.4 | `236eed8` | 1 · re-layout | `scripts/wr_tools/panel.html` |
| 1.19.5 | `9c2bd7e` | 2 · icons | `scripts/wr_tools/wr-icons.svg` (51 symbols), 22 new `scripts/wr_tools/wr-ico-*.svg`, `icon-map.json`, `ico-labels.txt`, `panel.html` (`icon(id, cat)`), `main.rb` (`wr_id` passes `mono:` through), `scripts/bulk-name-after-scenes.rb` (`@icon names-bulk`), five client scripts (`@icon mono:XX`), `.forge/builder-icons/gen-icons.py` (source of truth, 22 entries + coverage rule + label merge), `scripts/make-icons.py` (keeps the `wr-` label lines), `.forge/scoper/panel-harness/scan.py` (`mono:`) |
| 1.19.6 | `96961f0` | 3 · workbench | `panel.html` (`tiles()`, `recentStrip()`) |
| 1.19.7 | `e634e2a` | 4 · Ruby | `main.rb` (`refresh_fav_labels` one scan; `favourite_at(i, list = nil)`; `UI_PREFS`, `compact?`, `set_ui_pref`, `'uipref'` callback; `'compact'` in payload; `ui_compact` in `SHOP_KEYS`; `'faces'` dropped), `panel.html` (`.compact`, menu switch) |
| 1.19.8 | `5d62400` | 5 · copy | 12 `@title` lines, 13 blurb first-lines across `scripts/*.rb` (list in the commit) |

Under `.forge/builder/panel-overhaul/`:

- `harness.py` — my runner for the Scoper's harness: renders the real `panel.html` at
  330 / 430 / 520 with a `payload`-shaped object, forces the document width (headless
  Chrome will not open a window under ~500 px, so `--window-size` alone lies at 330 and
  430 — the Scoper's "footer clips at 430" screenshots were partly that artefact), crops
  the capture, forces the light theme, records every stubbed `sketchup.*` call and dumps
  DOM measurements. `python .forge/scoper/panel-harness/scan.py && python
  .forge/builder/panel-overhaul/harness.py <tag> [state…]`.
- `gate.py` — `node --check` on the extracted script, an ES2015-syntax grep, and the
  callback contract (`sketchup.*` calls in JS ↔ `add_action_callback` in Ruby).
- `rbtest-refresh.py` — lifts `favourite_at` + `refresh_fav_labels` out of `main.rb`,
  runs them under SketchUp's Ruby DLL (via `scripts/rbparse.py`) against 18 stub commands,
  counts `scan` calls for a git revision and the working tree.
- `patch-s2-gen.py`, `patch-s2-rest.py`, `patch-s4-ruby.py`, `patch-s5-copy.py` — the
  edits, reviewable; each asserts on a second run.
- `s1-*.png` … `s5-*.png` — the renders per slice (430/330/520 with the update line,
  full list, search `csusb`, `#3=` link, CLIENT tab, menu at 430 and 330, no-git notice at
  330, dev shelves, compact, dark, slot editor). `s2-contact-sheet-*.png` is the regenerated
  icon contact sheet.

## Read first

1. The five commit messages (`git log 001005f..HEAD`) — each states what it changed and
   what the harness proved.
2. `scripts/wr_tools/panel.html` — the menu block (`drawMenu` / `menuAction`), `icon(id,
   cat)` and `CAT_ICON`, `tiles()` / `recentStrip()`, the workbench block in `draw()`.
3. `scripts/wr_tools/main.rb` around `favourite_at`, `refresh_fav_labels`, `UI_PREFS`,
   `set_ui_pref`, and the `'uipref'` callback.
4. `.forge/builder-icons/gen-icons.py` — edit an icon there and re-run it; hand-editing
   `wr-icons.svg` or the map will drift on the next run (as two hand-added map entries
   had, before this pass).

## What the harness proved (observed, headless Chrome)

- First tool row at **173.7 px** with the update line at 430 and 520 (spec ≤ 175; was
  ~258). At 330 it is 195.6 because the two state chips wrap to a second line.
- Rows 44 px comfortable (spec ≈ 42), 28 px compact (spec ≈ 30).
- No horizontal overflow at 330 / 430 / 520 (`scrollWidth == clientWidth` in every state);
  no clipped control — the update line and the shop-default menu item ellipsize or wrap.
- `csusb` on TOOLS: both hits carry a CLIENT tag. `…booth-builder#3=abcdefghijk` shows
  the link bar and the click calls `buildlink(url)`.
- Slot-editor optgroups: Draw the room · Build the booth · Add dimensions · Scenes and
  images · **V-Ray renders** · Component art · Tidy up · shelves.
- Menu: each item reaches `rescan` / `folder` / `console` / `devtools("true")` /
  `shopdefaults`; the dev switch reveals 9 DEV rows with the menu still open; outside click
  and Escape close it. Update line: ✕ hides it, the pill stays orange and re-shows it,
  Update now disables itself, reads "Updating…" and calls `update`.
- Workbench: 11 tiles in 3 / 4 / 2 rows at 430 / 330 / 520; ✕ → `pin(name)`; a tile and a
  Recent chip → `run(file)`; the header → `collapse("Pinned")`; zero tiles and chips during
  a search and on CLIENT.
- Compact: `uipref("compact","true")` then `"false"`; blurb hidden and leading the tooltip.
- `gate.py` clean after every slice; 16 ↔ 16 callbacks at the end.
- `scan.py`: `default-icon: []`, `shared icons: {}` (were 24 and 3); 51 WR icons in the
  picker. `gen-icons.py` verify: every path inside the 2..22 live area, one orange group
  per icon, XML-valid.
- `rbtest-refresh.py` under SketchUp's Ruby: HEAD 9 scans for 9 filled stub slots, now 1;
  identical tooltips. `rbparse.py`: 66 files parse after every Ruby change.
- Installed `wr_tools/` for 2024 and 2026 is byte-identical to the repo at 1.19.8.

## What only a SketchUp session can prove (Benton's restart-and-look)

- CEF 88 rendering of the popover (`position: absolute` + `z-index: 20` over the
  scrolling list), the tile grid (`grid-template-columns: repeat(auto-fill, minmax())`),
  and the dark theme via `prefers-color-scheme` — all standard by Chromium 57 (assumed,
  the Scoper's table), none seen in the dialog.
- The live round-trips: ⋯ menu items, the ✕ / pill, tile click → script runs, Recent chip,
  `uipref` storing `ui_compact` and the switch surviving a panel reopen, and the star feeling
  faster (one scan instead of eleven).
- `@icon mono:CS` through the real `meta_of` → `icon_of` → payload path (the harness uses
  `scan.py`'s port of it).
- The NEW pill: every script whose header this pass touched (six for icons, 25 for copy)
  shows NEW for 24 h after install, because `fresh` is file mtime. Expected, not a bug.

## Assumptions

- Icon ids are `wr-takeoff`, `wr-mode`, … not the spec table's `wr-x-…`: the spec's ids
  read as the mockup's placeholder namespace, nothing references them, and the existing 29
  carry no such prefix. If the `wr-x-` form was wanted, it is a rename in `gen-icons.py`.
- The category fallback map (`CAT_ICON` in `panel.html`) picks one existing symbol per
  category; only an uncategorised script with no icon ever draws `wr-default` now.
- Tile labels: option (a), three lines, as the mockup showed. The longest title, "Build the
  customer's booth (share link)", clips at "(share" on a tile — visible in `s5-430-update.png`.
- Abilities are left out of the Recent strip (they are switches, already on the state
  strip); a pinned ability's tile flips it rather than "running" it.
- The `.forge/GOAL.md` working-copy change and `.forge/auditor/eval-run/`,
  `proposal-run/` were not mine and were not committed.
- Nothing was written to `DEVLOG.md`; that is the Documenter's.

## Open questions

1. "Find and Replace Names" (`find-replace-names.rb`) is the last Title Case title outside
   the shelves; it was not on the approved list. One line.
2. `@short` header for tile labels, or accept three lines.
3. Ship the toolbars section collapsed: only Benton's next SAVE AS SHOP DEFAULT does it
   (spec §6.9); nothing in `defaults.json` changed here.
4. `probe-enhanced.rb`'s blurb is a `load "C:/…"` line (its header has no prose before the
   usage line) — pre-existing, dev shelf, not touched.
5. The Scoper's harness screenshots in `.forge/scoper/panel-current-*.png` were taken at
   the 500 px Chrome minimum and cropped, so the "SAVE AS DEFA" clipping they show at 430 is
   partly the harness; the footer is gone regardless.
