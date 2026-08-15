# Panel integration audit — before the SketchUp restart

Auditor (panel-integration lens), 2026-08-15. Scope: the seam between the 28 tool scripts
in `scripts/` and `scripts/wr_tools/main.rb` + `scripts/wr_tools/panel.html`, plus the
installed copy under `%APPDATA%\SketchUp\SketchUp 2024\SketchUp\Plugins\`. Script-internal
logic is the other auditor's lane and is not covered here.

Method: both files of the matched pair read in full (observed). The 28-script × 6-directive
matrix, the icon map, the sprite symbol set, and the `@on`/`@off` traces were checked
mechanically with a Python script
(`C:\Users\bento\AppData\Local\Temp\claude\...\scratchpad\audit_headers.py`), not by eye.
The panel's JS was extracted and passed `node --check` (observed). No Ruby was executed —
everything about `main.rb`'s runtime behaviour is **derived** from source.

**Bottom line: the integration is sound.** Nothing found here will blank the panel, kill a
switch, or dead-end a button on restart. Two real defects (both minor, both in the
dots-convention corner) and two cosmetic notes, ranked below.

---

## Findings, most severe first

### 1. `rename` silently strips the trailing "..." from every dialog script — the round-trip is broken

- **Where:** `scripts/wr_tools/main.rb:876-877`, against `main.rb:133-134`.
- **What:** `rename` decides whether to re-append the dots with
  `old = meta_of(path)[0]; want += '...' if old.to_s.end_with?('...')`. But `meta_of`
  *strips* `...`/`…` from the title before returning it (line 134:
  `title = raw.sub(/(\.\.\.|…)\z/, '').strip`), so `old` never ends with dots and the
  append never fires. The comment at `main.rb:130-132` — "rename() still round-trips the
  dots in the file itself" — was true before the strip was added and is false now.
- **Failure scenario:** Benton renames any of the ~24 dialog-opening scripts from the
  pencil sheet. The rewritten `@title` line loses its dots on disk, the script's `dialog`
  flag flips to false on the next scan, and the window glyph disappears from its row.
  Silent, cumulative, and it also erodes the header convention in git-tracked files.
- **Verified:** derived — traced through both methods; not executed (no Ruby outside
  SketchUp).
- **Fix direction:** `rename` already locates the raw `@title` line (`at`); read the raw
  line for the dots test instead of `meta_of`'s stripped title — or have it use the
  `dialog` flag `meta_of` now returns (`meta_of(path)[4]`).
- **Note for tonight:** this only bites when a rename is performed. The panel renders
  correctly until then.

### 2. Two workshop scripts wear the dialog glyph but open no dialog

- **Where:** `scripts/pendant-jig.rb:1` (`# @title Pendant Curing Jig...`) and
  `scripts/tube-drying-stand.rb:1` (`# @title Tube Drying Stand...`).
- **What:** the trailing `...` means "opens a dialog first" and the panel now draws a
  window glyph for it. `pendant-jig.rb`'s only `UI.*` call is the failure messagebox at
  line 446; `tube-drying-stand.rb`'s messageboxes (lines 287, 297, 355) are mid-run
  validation aborts and a rescue. Neither has an inputbox or any pre-run dialog — both
  build immediately on run. (Checked every script the same way: the other 22 dotted
  scripts all carry a genuine pre-run inputbox/dialog, including both probes; the four
  undotted scripts — `booth-4260-s.rb`, `booth-96168-s.rb`, `csusb-rooms.rb`,
  `diag-favourites.rb` — genuinely open nothing. These two are the only mislabels.)
- **Failure scenario:** the glyph promises a chance to cancel or configure; clicking the
  row builds geometry into the model immediately instead.
- **Verified:** observed (grep of every `UI.inputbox`/`UI.messagebox`/`HtmlDialog` call
  per script) + derived for the run path.
- **Fix direction:** delete the three dots from those two `@title` lines.

### 3. Cosmetic — `icon-map.json` maps the five SKIP libraries

- **Where:** `scripts/wr_tools/icon-map.json` — 33 entries for 28 scanned scripts; the
  extra five are `wr-booth-data.rb`, `wr-deck.rb`, `wr-folder.rb`, `wr-shading.rb`,
  `wr_tools.rb`.
- **What/failure:** none — `script_files` rejects SKIP before the map is ever consulted
  (`main.rb:70-76`), so these entries are dead. Worth pruning only so the map stays a
  truthful list of tools. Observed.

### 4. Cosmetic — payload ships a `faces` key the panel never reads

- **Where:** `main.rb:994` (`'faces' => faces(slots, slot_icons)`) vs `panel.html`, where
  `slotsHTML` draws only `DATA.bound_faces` and signals divergence via `pending`.
- **What/failure:** none at runtime; it is dead weight in every render and a small trap
  for the next builder who assumes it is displayed somewhere. Observed (grepped the JS
  for `faces`).

---

## The engine question, settled as far as documentation allows

**SketchUp 2024's HtmlDialog runs Chromium/CEF 88, and everything the panel uses clears
it.** The official Ruby API release notes list every CEF upgrade — 2018 → 56, 2019 → 64,
2021.1 → 88, 2025.0 → 128, 2026.0 → 137 — with nothing between 2021.1 and 2025.0, so
2022–2024 sit on CEF 88 (reported: ruby.sketchup.com release notes; a 2023-era SketchUp
forum thread independently states the shipping build as 88.0.4324.150). One web search
digest claimed "CEF 112 for 2024.0" with no citable source; the release notes contradict
it by omission, and I have gone with the notes. Either way 88 is the floor to check
against, and the panel passes:

| Feature used in `panel.html` | Needs Chromium | On 88 |
|---|---|---|
| CSS custom properties | 49 | yes |
| flexbox `gap` | 84 | yes |
| `inset: 0` (`.sheetovl`) | **87** — the tightest | yes |
| `:focus-visible` | 86 | yes |
| `prefers-color-scheme` (query itself) | 76 | yes |
| `prefers-reduced-motion` | 74 | yes |
| grid `auto-fill`/`minmax` | 57 | yes |
| `scrollIntoView({block})` | 61 | yes |
| `Element.closest`, `dataset` | 41 | yes |
| JS syntax: ES5 only, `"use strict"`, no arrows/templates/optional chaining | — | yes (`node --check` clean, and the source was read for post-88 syntax: none) |

The `<use href>` + `xlink:href` double-spelling in `useSvg` is exactly the right insurance
for this engine and costs nothing.

**`prefers-color-scheme` inside the HtmlDialog: still unverifiable from documentation.**
The engine evaluates the query (76+), but whether SketchUp's CEF host forwards the
Windows app-theme preference into it is documented nowhere I could find; CEF historically
required host-side plumbing for it (reported: cefsharp issue #2741 and SketchUp forum
threads, none conclusive for SketchUp's build). What I **can** say from the stylesheet
(observed): the failure is benign in both directions. The base `:root` tokens are the
complete light palette, the dark block only overrides — so if the query never matches, the
panel is simply light, which is also what SketchUp itself ships. And the
`:root[data-theme="dark"]` escape hatch is already in the file. Verify by eye at restart
with Windows set to dark apps; no pre-restart change needed.

**Ruby:** SketchUp 2024 ships Ruby 3.2.2 (reported: release notes — note the task brief
said 3.1; either way it is a floor, not a ceiling, here). `main.rb` uses nothing newer
than Ruby 2.x idioms — no pattern matching, no endless methods, no hash shorthand
(observed, full read). All 34 `.rb` files pass `rbcheck.py` block balance (observed).
`UI::HtmlDialog` options and methods used (`set_file`, `add_action_callback`,
`execute_script`, `set_on_closed`, `bring_to_front`, `STYLE_DIALOG`) are all 2017+ API —
nothing version-gated beyond that (derived from the API docs).

---

## Coverage — checked and found clean

**1. The 28-script header matrix** (mechanical, `audit_headers.py`; observed):

- **`@cat`:** every non-shelved script's category is one of the six in the panel's
  `ORDER` list — nothing lands in "More scripts", nothing in a wrong bucket. The eight
  shelved scripts (`probe-components`, `probe-levels`, `diag-favourites` → dev;
  `pendant-jig`, `tube-drying-stand` → workshop; `booth-4260-s`, `booth-96168-s`,
  `csusb-rooms` → archive) all carry a valid `@shelf` value from `SHELVES`.
- **Icons:** all 28 resolve through `icon-map.json` to a symbol that exists in
  `scripts/wr_tools/wr-icons.svg` (29 symbols; the 29th, `wr-ghost`, serves the built-in
  Reference-geometry ability, whose declared `cat`/`icon` in `builtin_abilities` are both
  valid). No script falls to `wr-default`; **no two scripts share an icon**; every symbol
  has its standalone `wr-ico-<id>.svg` face for the toolbar picker (29 of 29). All
  headers are strict UTF-8, so `meta_of`'s rescue path (which would drop a title) cannot
  fire on encoding.
- **`@rank`:** exactly the seven the handoff claims — Build the booth 1/2/3
  (`booth-from-link`, `build-booth-components`, `build-booth`) and Scenes and images
  1/2/3/4 (`proposal-scenes`, `list-scenes`, `export-scenes`, `export-this-view`).
- **`@ability` traces:** all five `@on`/`@off` expressions name modules and methods that
  exist — `WR_AutoDimension` (auto-dimension.rb:306/326), `WR_DimensionBooth` (407/533),
  `WR_DimensionSelection` (177/208), `WR_ExplodeView` (285/289), `WR_ProposalScenes`
  (145/127). No dead switches.
- **`@setting` keys are all read:** `dimension-booth.rb:397-399` reads
  `opts['height'/'vents'/'gap']`; `dimension-selection.rb:169-170` reads
  `opts['where'/'gap']`; `explode-view.rb` reads `mode`/`spread` through
  `stored_cfg(opts)` (line 294+, consumed at 337/341). No orphan `@setting` on any
  non-ability script (which `meta_of` would silently drop).
- **Autorun guards:** all five ability scripts end in a guarded autorun
  (`$wr_suppress_autorun` for auto-dimension, `$wr_no_autorun` for the other four —
  dimension-booth's sits inside a begin/rescue at the file tail), and `load_quietly`
  (`main.rb:810-820`) sets **both** globals and restores them. The autorun defect fix is
  in place on both sides of the seam (derived; runtime confirmation in SketchUp is the
  acceptance criterion that still needs the restart).

**2. SKIP list:** the five libraries (`wr_tools.rb`, `wr-booth-data.rb`, `wr-shading.rb`,
`wr-folder.rb`, `wr-deck.rb`) are still skipped and are the only skips; everything else in
the folder is a genuine tool. No reference anywhere in `*.rb/*.py/*.html/*.json/*.txt` to
the old "Build Room" title survives the rename to "Draw floor plan..." (grepped; observed).

**3. Ruby/JS contract, enumerated both ways (observed):** the panel calls exactly
`ready, rescan, run, pin, rename, setslot, buildlink, ability, setting, collapse,
devtools, folder, console` — 13 callbacks; `main.rb:1035-1083` registers exactly those 13,
none extra, arities matching (setslot's index goes over as a string, Ruby `to_i`s it; the
booleans go over as "true"/"false" strings, Ruby compares strings — consistent on both
ends). Payload keys the JS reads (`dir, bundled, sprite, collapsed, dev, scripts,
abilities, pinned, note, slots, slot_icons, icons, pin_n, bound_faces, bound, pending`)
are all shipped by `payload` (`main.rb:974-998`); per-script keys (`file, name, title,
cat, shelf, icon, dialog, rank, blurb, ago, fresh`) and per-ability keys (`id, label,
blurb, settings, values, on_now, cat, icon, file, builtin`) all line up, including the
orphan-ability path for the built-in ghost (`!a.file` → drawn in "Add dimensions"). The
only asymmetries are shipped-but-unread (`faces`, `recent`) — finding 4, cosmetic.

**4. The install (observed):** `%APPDATA%\SketchUp\SketchUp 2024\SketchUp\Plugins\`
contains `wr_tools.rb` and `wr_tools\` with 109 files: `main.rb`, `panel.html`,
`wr-icons.svg`, `icon-map.json`, `ico-labels.txt` all **byte-identical to the repo**, all
29 `wr-ico-*.svg` faces, the legacy `ico-*`/`icon-*` sets, and a bundled `scripts\` copy
of all 33 `.rb` files (spot-diffed `build-room.rb`, `explode-view.rb`,
`proposal-scenes.rb`, `booth-from-link.rb` — identical). The resolution order holds on
this machine: of `main.rb`'s five candidates only
`C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\scripts` exists,
`WR_SCRIPTS_DIR` is unset, so the repo wins and the bundled-copy notice will not show.
Nothing the panel needs is missing from the installed copy.

**5. Sprite injection:** `wr-icons.svg` is a full `<svg>` root injected via `innerHTML`
into the inline `<svg id="sprite">`; nested `<svg><defs><symbol>` ids still resolve
document-wide for `<use>`, and `icon()` checks `document.getElementById` first, so even a
parse failure degrades every row to `wr-default`, never a blank list (derived; the
builder's headless verification of the degrade path is reported).

**Not checked / needs the restart itself:** anything that requires the live SketchUp
process — the autorun-guard behaviour of an actual switch flip, `prefers-color-scheme`
propagation, toolbar repaint-at-launch, and the docked dialog at 330 px. Those are the
acceptance criteria that were always going to need eyes on the restart.
