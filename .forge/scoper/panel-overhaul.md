# WhisperRoom panel overhaul — spec

Scoper, 1 Sep 2026, against plugin **1.19.3** (commit `636f4fd`). Mockup:
`.forge/scoper/panel-overhaul.mockup.html` (open in any browser; three switchable variants,
approve/needs-changes per section, copy-back JSON at the bottom). Nothing in this spec is
built. Nothing in it is approved until Benton reacts to the mockup.

Provenance. Everything about the current panel is **observed**: I read all 1660 lines of
`scripts/wr_tools/panel.html` and all 1640 of `scripts/wr_tools/main.rb`, scanned the headers of
every `.rb` in `scripts/` with a Python port of `meta_of` (`.forge/scoper/panel-harness/scan.py`),
and rendered the real `panel.html` in headless Chrome with a payload shaped like `main.rb#payload`
(`.forge/scoper/panel-harness/harness.py`). The screenshots beside this file are that render, not
SketchUp: CEF 88 inside SketchUp may differ in small ways, and the theme it picked (dark, from this
machine's OS setting) is **assumed** not to be what SketchUp shows — `panel-current-430x640-light.png`
is the light render for comparison. Claims about what the audit found are **reported** from
`.forge/auditor/full-audit-A-plugin-core.md` (A6, A11) and `.forge/auditor/full-audit-2026-09-01.md`
(finding 22); the ones I re-checked are marked.

What already shipped and is NOT redone here: the 15 Aug redesign
(`.forge/scoper/panel-redesign.md`, commit `ec6e79b`, landed in `14a31c4`/`3cbe143`/`15e52af` the same
day — observed in `git log`). Its one-row-per-script, state strip, shelves, `@rank`, `@icon`,
`icon-map.json`, the 29-symbol WR sprite, the bottom-sheet editors and the toolbar mirror as the last
section are all in the current file. Everything that came after — the two tabs, the update banner and
version pill, the three toolbars, shop defaults — was added between 19 Aug and 1 Sep without a design
pass, and that is where the seams are.

---

## 1. What the panel is today

Screenshots (headless Chrome, real `panel.html`, fake payload from real script headers):

| file | what it shows |
|---|---|
| `.forge/scoper/panel-current-430x640.png` | the default HtmlDialog size, update pending, two abilities on |
| `.forge/scoper/panel-current-430x640-light.png` | the same, forced light |
| `.forge/scoper/panel-current-full-list.png` | the whole TOOLS tab scrolled out (2600 px tall) |
| `.forge/scoper/panel-current-330.png` | at the 330 px minimum width |
| `.forge/scoper/panel-current-search-csusb.png` | a search that hits the other tab |

**Dialog.** `UI::HtmlDialog`, 430×640 default, 330×300 minimum, resizable, `STYLE_DIALOG`, always
re-homed to (60,120) on open (`main.rb:1399-1408`, `1493-1498`).

**Bands, top to bottom** (measured on the 430×640 render): top bar 44 px (brand dot, name, version
pill, Rescan / Folder / Console icon buttons) · search box 44 · tabs 40 · update banner 60 when an
update is pending · state strip 30 (`IN THIS MODEL` chips) · the scrolling list · footer 42 (dev-tools
switch, "search finds them anyway", SAVE AS SHOP DEFAULT). The first tool row starts at **~258 px**
with the banner, ~198 without. Rows are 50 px, so **six to eight rows are visible** at 640 tall.

**Tabs.** TOOLS (38 visible; 47 scripts including 9 shelved) and CLIENT DRAWINGS (5 visible; 8
including 3 archived). `@tab client` in a header files a script on the second tab; no header means
TOOLS (`main.rb:426-438`).

**Tools: 55 scripts + 1 built-in ability = 56 rows** (64 `.rb` files minus the 9 `SKIP`
libraries — the audit's "56" counts the Reference-geometry ghost, which has no file).

| category (`@cat`) | TOOLS tab | CLIENT tab | notes |
|---|---|---|---|
| Draw the room | 3 | 5 | build-room, build-takeoff, reorient-model · the five client one-offs |
| Build the booth | 4 | — | ranked 1-3: booth-from-link, build-booth-components, build-booth; probe-placement rank 9 |
| Add dimensions | 3 + ghost | — | three abilities (auto-dimension, dimension-booth, dimension-selection) + Reference geometry |
| Scenes and images | 6 | — | ranked 1-6; proposal-scenes is an ability |
| V-Ray renders | 12 | — | 10 visible; lookdev-matrix and probe-vray are `@shelf dev` |
| Component art (web catalog) | 6 | — | explode-view is an ability |
| Tidy up the model | 6 | — | ranked 1-2 then alphabetical |
| *(no category, shelved)* | 7 | 3 | dev 5 + workshop 2 on TOOLS; archive 3 on CLIENT |

Shelves (`@shelf dev|workshop|archive`) hide behind the footer switch; search still finds them with a
DEV badge. 49 of 55 titles end in `...` and draw the dialog glyph.

**Abilities.** Five scripts declare `@ability`/`@on`/`@off` and draw as switch rows in their own
category; state lives on the model (`WR_Tools_Abilities` attribute dictionary). Settings rows
(gear) exist on three: dimension-booth (4: panel height, vented faces, standoff, label rise),
dimension-selection (2), explode-view (3). Values are per-user prefs `set_<script>_<key>`.

**Pinned / stars / slots.** A star puts a script in the first free of 18 toolbar slots across three
real `UI::Toolbar`s (WhisperRoom / V-Ray / Tech, 6 each). The **Pinned** group at the top of TOOLS
draws the starred tools as full rows in slot order — today 11 of them, from
`scripts/wr_tools/defaults.json`. The **SketchUp toolbars** section (last) is a picture of the three
bars: faces resolved in Ruby, pending-until-restart shown as amber dashed tiles, click opens the
slot editor sheet (script dropdown + icon grid of 29 WR + 47 legacy icons).

**Search.** One box over both tabs; matches title, filename, blurb, ability label. Enter runs a
single hit; arrows move a selection. A pasted `booth-builder?d=` / `#d=` link becomes a **Build this
booth design** command (`buildlink` → `booth-from-link.rb`).

**Update banner.** `check_update` asks the GitHub API once per session after the first render; if
newer, the version pill turns orange and a three-line banner appears with **Update now** (runs
`git pull` + `install-plugin.py` via a batch file) or, with no checkout, the command to type.

**Shop defaults.** Footer button writes this user's `slots`, `slot_icons`, `pinned`, `ui_collapsed`,
`ui_dev` into `defaults.json` in the repo; a key falls back to it only when the user never set one.

**Callback contract** (`main.rb:1409-1476`, 15 callbacks): `ready`, `rescan`, `update`, `run(file)`,
`pin(name)`, `rename(name,title)`, `setslot(i,name,icon)`, `buildlink(url)`, `ability(id,on)`,
`setting(id,key,value)`, `collapse(list)`, `devtools(on)`, `shopdefaults`, `folder`, `console`.
Payload keys: `dir bundled version update can_update sprite collapsed dev scripts abilities recent
pinned note slots slot_icons icons pin_n bars slot_n faces bound_faces bound pending`. Per script:
`file name title cat shelf tab icon dialog rank blurb ago fresh stamp ability`. `recent` and `faces`
are shipped and never drawn (observed, grep).

**Icons.** 29 WR symbols in `wr-icons.svg`; `icon-map.json` maps 30 scripts (5 of them SKIP
libraries, dead entries). **24 of 55 scripts resolve to `wr-default`**; three tools share
`wr-names-replace`, two share `wr-scenes-proposal` (observed via `scan.py`).

---

## 2. What is wrong with it as a working surface

Ranked by how often a draftsman meets it. "Daily" means the proposal loop: paste a link, build the
booth, draw the room, dimension, set up plates, render, export the pack — about ten tools. The other
forty-five are monthly: catalogue art, tidy-up, probes, client one-offs, toolbar plumbing.

1. **The daily tools are not on one screen.** Pinned repeats 11 full rows above the same 11 rows in
   their categories (38 tools → 49 rows), the header eats 200-260 px, and the update banner —
   which is up whenever the shop is a version behind — pushes the first tool below the fold at 640.
   Every day starts with a scroll (observed, full-list screenshot).
2. **The icon column carries no information for 44% of rows.** All ten visible V-Ray tools wear
   the same glyph, so the section that a proposal spends most of its clicks in is a wall of identical
   tiles read by title only (observed; audit A11 / finding 22).
3. **V-Ray renders sorts last**, after Tidy up the model, because the category is missing from
   `ORDER` (`panel.html:804-806`). The pipeline reads room → booth → dimensions → scenes → *tidy* →
   *render*, which is backwards for the daily loop (observed; A11).
4. **The footer clips at the default width.** SAVE AS SHOP DEFAULT reads "SAVE AS DEFA" at 430 px
   and 330 px; at 330 the update banner's button clips too (observed, both screenshots). Three
   monthly-use controls (Rescan, Folder, Console) hold permanent top-bar space while the footer
   overflows.
5. **A search that hits the other tab does not say so.** Typing `csusb` on TOOLS shows two rows
   under DRAW THE ROOM as if they lived there; the comment at `panel.html:1388-1392` promises a
   label that is never drawn (observed; A11). And a `#3=` share link — the format
   `booth-from-link.rb` has read since 1.18.0 — is treated as a search term and finds nothing
   (A6, re-checked: `boothLink()` at `panel.html:887` matches only `?d=` and `#d=`).
6. **Titles and blurbs read unevenly** because they were written across a month: twelve Title Case
   titles beside twenty-five sentence-case ones (`List Scenes`, `Merge Materials`, `Light It From
   Here` next to `Export just this view`), a typo (`Scene PIctures`), and thirteen blurbs that open
   with their own filename (`wr-sun-aim.rb — snap the SUN…`) although the filename is already in
   the tooltip (observed, `scan.py`).
7. **Each star click rescans the folder 18 times.** `toggle_pin` → `write_slots` →
   `refresh_fav_labels` → `favourite_at(i)` × 18, each a full `scan` of 64 files with four header
   passes (observed in `main.rb:810-822`, `833-837`, `986-1007`; A11). Not visible in the UI but it is the
   only reason a star feels slow, and a slot editor save pays it too.
8. Smaller: `recent` is shipped and never drawn (the cheapest "what did I run last" there is); the
   tab count says 38 while the list shows 49 rows; the update banner repeats the git command that
   the button already runs.

What is **not** wrong and stays: the one-row-per-script model, ability switches with model-held
state, the state chips, shelves with search-finds-them, `@rank` ladders, the toolbar mirror's
honesty about pending faces, the bottom-sheet editors, the rename-keeps-the-filename rule, and the
whole `sketchup.*` contract. The 15 Aug audit called the integration sound and the 1 Sep audit
called the JS clean (ES5, escaped sinks, double-quoted attributes); nothing here reopens that.

---

## 3. Proposed direction

**Keep the shop-drawing look, the two tabs and every callback; change the shape of the TOOLS tab
so the daily ten sit in one screen and the monthly forty-five sit under them in the order a job
happens.** Concretely: collapse the header from five bands to three by moving Rescan / Folder /
Console / dev-tools / shop-default into one ⋯ menu and deleting the footer; turn the update banner
into a single dismissible line; draw the pinned tools as an icon-tile grid with a Recent strip
under it instead of eleven duplicate rows; trim rows from 50 to ~42 px with an optional compact
mode; put V-Ray renders where the pipeline reaches it; tag off-tab search hits; give the 24
generic-icon tools real glyphs (and the five client one-offs a two-letter monogram, which beats
any picture); and fix the 18-rescan star. The reasoning is that the panel's problems are not the
row design — that was settled on 15 Aug and it works — but the accretion since: three features
were bolted on above and below the list, and the list itself never got the density or the icon
coverage the new categories needed. This is a re-layout of the same parts plus the audit's
structural fixes, not a second redesign, which is why slice 1 needs no Ruby at all.

Three variants in the mockup differ only in how hard they lean on the daily/monthly split.
**A · Workbench** (recommended): tile grid + Recent strip, then categories at ~42 px rows.
**B · Dense list**: no grid; 30 px single-line rows, sticky category headers, stars inline — the
most tools per screen, the least help for a new user. **C · Palette first**: Recent + grid are the
whole front page and the categorised list is a disclosure — fewest things on screen, most reliance
on search and memory. A and C share every component; B drops one. Pick one; the rest of the spec
holds for all three.

---

## 4. Hard constraints

- **SketchUp's embedded Chromium is CEF 88** (2021.1 through 2024; reported from the API release
  notes via the 15 Aug panel audit). ES5 only — no arrows, template strings, `let`/`const`,
  optional chaining, `Array.prototype.includes` is fine (47+) but keep to `indexOf`. No external
  fonts, scripts, stylesheets or `fetch`; the sprite keeps arriving inside the payload. CSS used by
  the mockup and needed by the build: flex `gap` (84), grid `auto-fill`/`minmax` (57), `position:
  sticky` (56), `:has()` is **not** available (105) — the mockup uses it for the review page only,
  the panel CSS in the mockup does not. `prefers-color-scheme` propagation is still unverified in
  the dialog; keep the light base + dark override structure exactly as today.
- **No Ruby change is needed for slices 1-3.** Every control in the mockup maps to an existing
  callback: menu items → `rescan` / `folder` / `console` / `devtools` / `shopdefaults`; tiles and
  Recent chips → `run(file)`; un-star → `pin(name)`; update line → `update`; link bar →
  `buildlink`; category collapse → `collapse`. Slice 4 adds exactly two Ruby changes, named there.
- **Two tabs stay** as built: `tab_of`, the `@tab client` header, the Pinned-and-toolbars-are-TOOLS-
  furniture rule, search across both.
- **Data shapes stay.** `slots` / `slot_icons` / `pinned` pipe-joined lists of 18, `ui_collapsed`,
  `ui_dev`, `set_<script>_<key>`, `defaults.json` keys, the ability attribute dictionary — none
  change. The tile grid reads `pinned` (slot order) exactly as the Pinned group does.
- **The header grammar stays.** `@title @cat @tab @shelf @icon @rank @ability @setting @on @off`
  unchanged. One optional additive line is *proposed*, not required: `@short <label>` for a tile
  label (§6.4, open question 3).
- 330 px minimum width must show no clipped control (today's footer fails this).

---

## 5. Structural fixes the overhaul absorbs

| finding | fix | slice |
|---|---|---|
| 24 tools draw `wr-default`; 3 + 2 share an icon (A11 / 22) | 22 new symbols + monogram rule + category fallback, `icon-map.json` entries; prune the 5 SKIP entries | 2 |
| "V-Ray renders" missing from `ORDER` (A11) | `ORDER` gains it after "Scenes and images" | 1 |
| off-tab hits unlabelled (A11) | `CLIENT` / `TOOLS` tag on any hit whose `tab` is not the current tab, search only | 1 |
| `#3=` links unrecognised (A6) | `boothLink()` regex gains `#3=[A-Za-z0-9_-]{10,}`; or `main.rb` ships the regex in the payload so the two files cannot drift | 1 |
| 18 rescans per star click / slot save (A11) | `refresh_fav_labels` takes one `scan` and indexes it; `favourite_at` accepts an optional list | 4 |
| footer clipped at 430 / 330 (this pass, observed) | footer removed; controls into the ⋯ menu | 1 |
| update banner 60 px, button clips at 330 (this pass) | one-line notice | 1 |
| `recent` shipped, never drawn (A11) | Recent strip | 3 |
| `faces` shipped, never read (A11) | drop from payload | 4 (optional) |

Not absorbed, out of scope, but worth knowing while in `main.rb`: A3 (`save_shop_defaults` reads
`sc['settings']`/`sc['id']` that `scan` never emits, so per-script settings never ship), A5 (the
NUL sentinel in `read_default` is unverified) — both shop-defaults bugs, both Ruby, both separate.

---

## 6. The design, piece by piece (matches the mockup's § numbers)

**6.1 Direction and variant** — above.

**6.2 Header.** Top bar 34 px: brand dot + WhisperRoom, version pill, one ⋯ button. The ⋯ menu
(an in-page popover, closed on outside click and Escape) holds: Rescan the scripts folder · Open
the scripts folder · Ruby Console · — · Show developer & workshop tools [switch] with the
"search finds them either way" hint under it · Compact rows [switch] (slice 4) · — · Save this
layout as the shop default… (with the "writes defaults.json" hint; the confirm messagebox stays).
Search box 30 px in 8 px margins. Tabs 30 px. No footer. The bundled-copy notice, when it applies,
stays at the bottom of the list as today.

**6.3 Update line.** 26 px: **v1.19.4 available** · muted `git pull && install-plugin.py` · **Update
now** · ✕. ✕ hides it until the next panel open (page state, no pref). The pill stays orange with
the tooltip "v1.19.4 is available — click for details"; clicking the pill re-shows the line. No
checkout: the line reads "v1.19.4 available — no git checkout here; update where the repo is
cloned" and the button is absent, as today's banner does. The `Updating…` disabled state is kept.

**6.4 Pinned as a workbench grid + Recent.** Section header `PINNED · ON THE TOOLBARS 11`,
collapsible like any section. Grid `repeat(auto-fill, minmax(74px, 1fr))`, 4 px gap: five tiles a
row at 430, four at 330, six at 520. Tile: 28 px icon well (dotted outline only in the mockup, for
placeholders), title at 10 px up to three lines, the dialog glyph top-left when the tool opens a
dialog, ✕ top-right on hover to un-star (`pin`). Click runs (`run`). Tiles are the tools
themselves, not toolbar faces — the same distinction the Pinned group makes today, so the
"rival favourites row" mistake from 14 Aug does not come back. Recent strip under the grid: `RECENT`
+ up to five chips from `payload.recent`, titles clipped at 20 characters, click runs. Recent
appears only on TOOLS with no search term; it is per-user (`remember` in `main.rb`) and is not a shop
default. Long titles are the weak point: `Build the customer's booth (share link)` needs three lines.
Options in order of preference: (a) accept three lines; (b) an additive `@short` header the way
`@rank` is additive, falling back to the title; (c) truncate. The mockup shows (a).

**6.5 Rows.** Comfortable: 5 px vertical padding, 26 px well, 12.5 px title, 11 px one-line blurb,
≈42 px. Compact: 3 px padding, 22 px well, title only at 12 px, blurb in the tooltip, ≈30 px.
Variant B is compact throughout; in A and C compact is a switch in the ⋯ menu stored in a new
`ui_compact` pref (slice 4). Everything else on a row — NEW pill, DEV badge, dialog glyph, hover
RUN, pencil, star, ability switch/gear/stat, inline settings — is unchanged.

**6.6 Category order.** `ORDER = ["Draw the room", "Build the booth", "Add dimensions", "Scenes and
images", "V-Ray renders", "Component art (web catalog)", "Tidy up the model"]`. The slot editor's
optgroups follow automatically (same `cmpSection`).

**6.7 Search.** Off-tab hits get `<span class="tag tab">CLIENT</span>` (or `TOOLS` when on CLIENT)
after the title, only while a term is present. `boothLink()` accepts `#3=`. Everything else — the
link bar, Enter-runs-single-hit, arrows, Escape, search-opens-collapsed-sections — unchanged.

**6.8 Icons.** Rules as the existing sprite: 24 grid, 20 live, 1.8 stroke, round caps, graphite +
one orange subject. Briefs for the 22 new symbols (the mockup's `sprite2` draws each as a rough
placeholder; a Graphics Designer pass finalises):

| script | id | brief (orange = the subject) |
|---|---|---|
| build-takeoff.rb | wr-x-takeoff | sheet with folded corner; orange room-with-door inside |
| reorient-model.rb | wr-x-reorient | room outline; orange curved arrow onto the axis |
| prefix-scenes.rb | wr-x-prefix | three list lines; orange "A" at the front |
| probe-placement.rb | wr-x-probe-place | booth; orange crosshair |
| wr-mode.rb | wr-x-mode | booth split down the middle: line-draft left, orange-filled render right |
| wr-sun-aim.rb | wr-x-sun | room; orange sun with rays at top-right |
| wr-drop-lights.rb | wr-x-lights | booth; orange pendant bulb dropping from the ceiling |
| wr-materials-swap.rb | wr-x-materials | two overlapping swatches, the front one orange |
| wr-preflight.rb | wr-x-preflight | checklist sheet; orange ticks |
| wr-pack-export.rb | wr-x-pack | box; orange arrow out of the top-right |
| wr-scene-walls.rb | wr-x-scene-walls | room; one wall dashed orange (hidden) |
| wr-name-walls.rb | wr-x-name-walls | room; orange name tag on the top wall |
| wr-lower-walls.rb | wr-x-lower-walls | wall dropped to a curb; orange down-arrow and curb line |
| wr-split-walls.rb | wr-x-split-walls | wall; orange dashed cut at sill height |
| lookdev-matrix.rb | wr-x-lookdev | 3×3 grid; one orange cell |
| probe-vray-color.rb | wr-x-probe-color | probe stem; orange droplet |
| probe-vray.rb | wr-x-probe-vray | probe stem; orange lens with a V |
| probe-enhanced.rb | wr-x-probe-enh | booth; orange E beside it |
| probe-seam-seal.rb | wr-x-probe-seal | ceiling outline; orange seam line + tick |
| bulk-name-after-scenes.rb | wr-x-names-bulk | three lines each with an orange tag (was sharing wr-names-replace) |
| name-selection-after-scene.rb | wr-x-name-one | dashed selection; one orange tag (was sharing wr-names-replace) |
| proposal-package.rb | wr-x-package | four small plates; orange box with an arrow in (was sharing wr-scenes-proposal) |

Client one-offs draw a **monogram** in the icon well instead of a symbol: `csusb-106.rb` CS,
`uthsc-audiology-rooms.rb` UT, `dowaly-kuwait-tv.rb` DK, `fvrl-podcast-alcove.rb` FV,
`smith-studio.rb` DS. Mechanism: `@icon mono:CS` in the header (one line each, additive; `icon_of`
passes the string through, the panel renders `mono:` ids as text). Interim fallback rule: a script
with no icon draws its **category's** glyph (`wr-room-takeoff` for Draw the room, `wr-booth-blockout`
for Build the booth, …) rather than `wr-default`, so the generic glyph only ever appears for an
uncategorised script. Each symbol also needs a standalone `wr-ico-<id>.svg` for the slot picker,
as the 29 existing ones have.

**6.9 Toolbars section.** Unchanged. Ships collapsed: add `SketchUp toolbars` to `ui_collapsed` in
`defaults.json` when Benton next saves the shop default (a user who has set `ui_collapsed` keeps
theirs).

**6.10 Copy pass** (label-only header edits, filenames untouched, no grammar change). Titles to
sentence case, verb first, to match the majority: `List Scenes` → `List the scenes…`, `Merge
Materials` → `Merge duplicate materials…`, `Orbit Export` → `Orbit export (turntable frames)…`,
`Exploded View` → `Exploded view…`, `Save Scene Components` → `Save each scene's component…`,
`Prefix Every Scene` → `Prefix every scene name…`, `Bulk Name After Scenes` → `Name parts after
their scenes (bulk)…`, `Name Selection After Scene` → `Name the selection after its scene`, `Drop
Interior Lights` → `Drop the interior lights`, `Light It From Here` → `Light it from here
(sun to camera)…`, `Toggle Draft / Render mode` → `Toggle draft / render mode…`, `Scene PIctures` →
`Scene pictures (flat art)…`. Thirteen blurbs that open with their filename (`wr-drop-lights.rb`,
`lookdev-matrix.rb`, `wr-sun-aim.rb`, `uthsc-audiology-rooms.rb`, `csusb-106.rb`, `csusb-rooms.rb`,
`dowaly-kuwait-tv.rb`, `fvrl-podcast-alcove.rb`, `prefix-scenes.rb`, `probe-vray.rb`,
`smith-studio.rb`, `reorient-model.rb`, `diag-favourites.rb`) lose the `name.rb — ` prefix. The
exact wording is Benton's call; the list is the deliverable.

---

## 7. Build plan — slices a Builder ships one version at a time

Each slice bumps `scripts/wr_tools/VERSION`, passes `python scripts/rbparse.py` where Ruby is
touched, and is verified with the harness: `python .forge/scoper/panel-harness/scan.py && python
.forge/scoper/panel-harness/harness.py` renders the real `panel.html` at 430×640, 330 and full
height into `.forge/scoper/`. Add states to its `shots` list as needed. `node --check` on the
extracted script block is the ES5 gate the audit used.

**Slice 1 — re-layout, `panel.html` only.** Files: `scripts/wr_tools/panel.html`.
Changes: `ORDER` gains V-Ray renders; off-tab tag in `tagsFor`/`actionRow`/`abilityRow`; `boothLink`
accepts `#3=`; `.upd` becomes the one-line notice with ✕ (page state) and pill click re-shows it;
`.top` loses the three icon buttons, gains ⋯ and the popover menu wired to `rescan` / `folder` /
`console` / `devtools` / `shopdefaults`; `.foot` removed; row padding/well trimmed to the
comfortable size. Acceptance: (a) harness at 430 and 330 shows no clipped control and no horizontal
scroll; (b) `csusb` typed on TOOLS shows both hits with a CLIENT tag, and `#3=abcdefghijk` shows the
link bar; (c) V-Ray renders sits between Scenes and images and Component art in the list and in the
slot editor's dropdown; (d) every one of the 15 callbacks is still called from somewhere
(`grep -o "sketchup\.[a-z]*" panel.html | sort -u` lists all 15); (e) `node --check` clean; (f)
first tool row at ≤ 175 px with the update line showing (measure on the harness screenshot).

**Slice 2 — icons.** Files: `scripts/wr_tools/wr-icons.svg`, 22 new `scripts/wr_tools/wr-ico-*.svg`,
`scripts/wr_tools/icon-map.json`, `scripts/wr_tools/ico-labels.txt`, `panel.html` (`icon()` learns
`mono:` and the category fallback), five client scripts (`@icon mono:XX`), `main.rb` only if
`wr_id` rejects `mono:` (it prefixes `wr-` to anything — so either strip the prefix in JS or teach
`wr_id` to pass `mono:` through; one line). Acceptance: `scan.py` reports `default-icon: []` and
`shared icons: {}`; the harness full-list screenshot shows no two adjacent identical glyphs in
V-Ray renders; the slot editor lists 51 WR icons.

**Slice 3 — workbench.** Files: `panel.html`. The Pinned group renders `tiles()` + `recentStrip()`
(variant A or C per Benton's pick; variant B skips this slice). Acceptance: 11 pinned → 3 tile rows
at 430; ✕ on a tile calls `pin`; a Recent chip calls `run` with the script's `file`; Pinned and
Recent absent on CLIENT and during a search; collapse state of `Pinned` persists via `collapse`.

**Slice 4 — Ruby, two changes.** Files: `scripts/wr_tools/main.rb`, `panel.html`. (1)
`refresh_fav_labels` calls `scan` once (`list = scan; s = list.find { … }`), or `favourite_at(i,
list = nil)`; verify by counting `scan` calls per `toggle_pin` in `rbparse.py` evaluation or by a
`puts` breadcrumb. (2) `ui_compact` pref: `add_action_callback('uipref') { |_c, k, v| … }` restricted
to a whitelist (`compact`), `'compact' => compact?` in `payload`, `ui_compact` added to `SHOP_KEYS`;
panel toggles `.compact` on the frame. Optional: drop `faces` from the payload. Acceptance:
`rbparse.py` clean; harness with `compact: true` shows 30 px rows; star click in SketchUp is
visibly faster (Benton's desk check — the only item needing a running SketchUp).

**Slice 5 — copy pass.** Files: the ~12 scripts' `@title` lines and 13 blurb first lines listed in
§6.10. Label-only; `rbparse.py` clean; `scan.py` shows no Title Case titles outside shelves and no
blurb starting with `.rb`.

Order matters only in that 3 wants 2 (tiles with generic glyphs are worse than rows) and 4's
compact switch wants 1's menu. Slices 1, 2 and 5 are independent.

---

## 8. Risks and what is out of scope

- **Assumed, unverified:** CEF 88 renders `position: sticky` inside the scrolling list (variant B's
  headers) and the popover menu's `z-index` over the `.p-scroll` — both standard by 56, but the
  harness is desktop Chrome, not the dialog. Slice 1's desk check covers it.
- **Risk:** removing the footer removes the only always-visible "developer tools" affordance; a new
  user who does not open ⋯ never learns the shelves exist. Mitigation: the tab count shows `38`
  while 47 exist — the menu line could read "Show 9 developer & workshop tools".
- **Risk:** tile labels. Three-line 10 px titles are readable on the mockup at 430; at 330 with four
  tiles a row they are tight. `@short` (open question 3) is the clean fix and costs one header line
  per pinned tool.
- **Out of scope:** the shop-defaults Ruby bugs (A3, A5), the update-check retry logic (A1), the
  bridge, any script's own dialog, the toolbar section's behaviour, retiring the 47 legacy icons.
- **The mockup's icons are briefs**, drawn to check the coverage rule and the monogram idea, not
  final art. Do not extract them into the sprite as-is without a Graphics Designer pass.

---

## 9. Approval gate and open questions

No human has seen this. The gate is: Benton opens the mockup, picks a variant, marks each section,
pastes the JSON back. Then slice 1 starts. The questions the mockup cannot answer for him:

1. **Which variant** — A Workbench, B Dense list, or C Palette first? (A recommended.)
2. **Does the ⋯ menu lose anything he reaches for daily?** Rescan is the likeliest — if he hits it
   often, it stays as a bare button beside ⋯.
3. **Tile labels:** three-line titles as drawn, an additive `@short` header per pinned tool, or
   truncation?
4. **Recent strip: keep it?** It is free (payload already carries `recent`) but it is one more band.
5. **Monograms for client one-offs** — CS / UT / DK / FV / DS — or real glyphs?
6. **The copy pass wording** in §6.10 — his words, not mine; the list is what needs a decision.
7. **Toolbars section collapsed by default** — it only takes effect when he next saves the shop
   default, so it is his to do or skip.
