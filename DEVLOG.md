# DEVLOG

## 2026-08-06 (late) — orbit exporter, and what the manual actually is

Benton's target for the assembly manual is now clear and it is bigger than a
generic manual: **a manual generated from a customer's own Booth Planner
configuration.** Press a button, pull that design into SketchUp exactly as the
customer specified it, and produce step-by-step assembly for that booth.

**Most of the front half already exists and nobody wrote it down.**
`booth-builder.html` encodes a design as base64 JSON in a `#d=` URL fragment,
and `gen-booth.py --design "<link>"` already decodes it and solves the panel
geometry. So the path is:

```
booth-builder #d= link
  -> gen-booth.py --design      EXISTS
  -> wr-booth-data.rb           EXISTS
  -> build-booth.rb             EXISTS  (25 Standard booths build today)
  -> orbit-export.rb            NEW, below
  -> manifest.json              NEW, written by the exporter
  -> the manual                 not built
```

**`scripts/orbit-export.rb`** is the new piece. It photographs a part — or every
part of an assembly, isolated one at a time — from every angle in one run, and
writes a `manifest.json` describing what came out.

The design decision that matters is **constant scale**. `zoom_extents` reframes
every shot, so a part would change size as it turns and two parts on facing
pages would not match. The camera instead uses parallel projection with a view
height computed once for the whole run from the largest part's bounding
diagonal — the diagonal rather than the width, because a part's widest
silhouette as it turns is its diagonal. "Each part fills the frame" is offered
as an alternative, and the console says plainly that it is wrong for any step
showing two parts together.

Style is deliberately left alone. Set edges, shading and hidden-line in
SketchUp before running; the script only forces ground, horizon and fog off so
transparency works, and restores them. Guessing at rendering-option keys was
not worth the risk.

The manifest is the contract: part, slug, size, and every frame with its
azimuth and elevation, plus a null `step` to fill in for assembly order.
Nothing downstream needs to know SketchUp exists.

### Also fixed: the generators were laptop-only

`gen-booth.py` and `gen-booth-models.py` hard-coded
`C:\Users\bento\Documents\Claude\...`, which does not exist on the desktop —
the same redirection problem the plugin had. Both now resolve the workspace
root, with `WR_CLAUDE_ROOT` as an override, and write relative to their own
location. Verified: all four paths land on real files here. Without this,
`gen-booth.py --design` — the front half of the button — could not run on this
machine at all.

## 2026-08-06 (late) — the plugin gets a panel

**The menu could never have worked the way it was meant to.** SketchUp has no
API for removing or rebuilding a menu item once added, so "Reload Scripts" was
only ever able to pop a message box explaining that a restart was needed. For a
folder we add scripts to constantly, that is backwards.

`wr_tools` now opens a **`UI::HtmlDialog` panel** instead. It rescans `scripts/`
every time it opens or you hit Rescan, so a new file is one click away with no
restart and no reinstall.

- **Newest first.** Sorted on file mtime, with a NEW pill on anything touched in
  the last 24 hours. The script being worked on is nearly always the one to run.
- **Type to filter**, arrow keys to move, Enter to run. Matches on title, file
  name and blurb.
- **Recent chips** across the top, five deep, persisted in `Sketchup.write_default`.
- Each row shows the script's `@title`, the comment paragraph under it as a
  blurb, the file name and how long ago it changed — all parsed from the header,
  so a script documents itself in the launcher by being commented normally.
- Toolbar cut from seven buttons to three (Panel, Folder, Console) with **SVG
  icons**, which stay crisp at any toolbar size. The old PNGs remain as a
  fallback so a partial install shows buttons rather than blanks.
- The menu is kept, still frozen at load time, as a fallback.

**`scripts/rbcheck.py` is new.** There is no Ruby interpreter on either machine
outside SketchUp, so nothing in `scripts/` gets syntax-checked before it reaches
the Ruby Console. It is not a parser — it strips strings, heredocs and comments
and matches block openers against `end`, which catches the one error that
actually happens when hand-editing a long file. Run `python rbcheck.py` in
`scripts/`. All 9 files currently balance.

Worth knowing about it: the first version flagged `build-booth.rb` and
`tube-drying-stand.rb`, and both were **false positives** — it did not know that
`dir = case axis` opens a block. Fixed. A checker that cries wolf is worse than
no checker.

### Next, for the dynamic assembly manual

Benton's direction for this workspace is mass component photography at many
angles, feeding a rebuilt assembly manual. Nothing below is built yet:

1. **Orbit exporter.** `export-scenes.rb` only exports scenes that already
   exist. The manual needs N angles per component without hand-making N scenes:
   drive `Sketchup::Camera` round a component's bounding box at a set azimuth
   and elevation step, `write_image` each stop, name them predictably.
2. **Exploded views** driven off the tag structure the fixtures already use.
3. **A manifest** — a JSON sidecar naming every image with its component,
   azimuth and elevation, so the manual can be generated from data rather than
   by hand-placing pictures. This is the piece that makes it *dynamic*.

## 2026-08-06 (evening) — pendant fixtures

A side project, not WhisperRoom: 3D-printed fixtures for the pendant line.
Both are parametric, both print without supports, and both self-audit to the
Ruby Console on every run.

**`scripts/pendant-jig.rb`** — holds the metal housing square and centres the
polycarbonate tube in it while the adhesive cures. Ø15.29 socket × 18 deep,
Ø9.90 tube guide × 36, one lathed solid, 57.50 tall, ~18 g. Holds the tube to
0.40° / 0.375 mm over its length.

Two things went wrong on the way and are worth remembering:

- **`follow_me` left the rims cracked.** A revolve has to close back on itself
  and SketchUp does not reliably weld that seam. Rebuilt as an explicit
  `Geom::PolygonMesh` whose last column of quads wraps to column 0 by index, so
  there is no seam to fail. **Every solid now reports its naked-edge count** —
  that check is what should have caught it, and it costs nothing.
- **The first version printed the wrong way up.** Flange-down made the shoulder
  the housing registers against an unsupported ceiling over the socket, which
  is the one surface whose flatness decides whether the housing sits square.
  It prints socket-up. That drove the 45° flange underside, the lead-in, and
  the guide-mouth chamfer.

**`scripts/tube-drying-stand.rb`** — 60 tubes upright while epoxy cures. 10 × 6
pockets, 123.50 × 74.90 × 31.50, ~94 g. Rev B added 136 diamond openings and
dropped the seven under-ribs for four corner pads once it was clear the thing
prints inverted. Worst-case lean 1.62°, which is a ceiling rather than an
expectation — a 54 mm tube on a 9.65 mm base self-rights, and would need 10.1°
to topple. **Cut-end squareness is the likelier dominant error**; measure a
tube against a square before spending print time on a deeper pocket.

**`reference/3d-printing.md`** is new and carries the printer (Dremel 3D45),
the sourced overhang and bridging limits, the two slicer settings that are not
the defaults, and the design rules that follow. Read it before changing either
fixture's geometry.

**Nothing here has been printed yet, and no script has been run.** Clearances
are all built on the 0.25 mm allowance and are unconfirmed. Print the jig
first — an hour and 18 g calibrates that figure before the stand's 94 g.

## 2026-08-06 (later) — desktop brought online

**Repo cloned to the home desktop** at
`C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\`. Documents is
redirected into OneDrive on this machine, so the laptop's `C:\Users\bento\Documents\Claude\`
does not exist here.

**Plugin made machine-independent.** `wr_tools/main.rb` hard-coded
`C:/Users/bento/Documents/Claude/Sketchup/scripts`, which resolves to nothing on the desktop.
It now walks a `CANDIDATES` list (both Documents roots × both repo layouts) and takes the first
that exists, with a `WR_SCRIPTS_DIR` environment-variable override for a new machine.
`install-plugin.py` likewise no longer requires `%APPDATA%\SketchUp` to already exist — a
SketchUp that has never been launched has no profile folder, so the installer now detects
installed versions from Program Files and creates the Plugins folder itself.

**Installed and verified on the desktop.** SketchUp 2024, `wr_tools.rb` + `wr_tools\` in
`%APPDATA%\SketchUp\SketchUp 2024\SketchUp\Plugins\`. The resolver was run against this
machine's filesystem and picks the OneDrive clone; 4 scripts will appear on the menu
(`booth-4260-s`, `build-booth`, `csusb-rooms`, `export-scenes`). The menu itself is unverified
until SketchUp is launched.

**Sibling repos on the desktop.** `WhisperRoomQuote` was already present. `whisperroom-proposals`
cloned to `<CLAUDE>\WhisperRoom Proposals\`.

### Still missing on the desktop — needs a push from the laptop

These are referenced by `CLAUDE.md` but are not in any branch of any repo on GitHub, so they
exist only on the laptop:

- `WhisperRoom Proposals\build-v2.js` and `examples\<client>\proposal-v2.json` — the
  `whisperroom-proposals` repo on GitHub is still the single-commit **v1** system (`build.js`).
- `WhisperRoomQuote\tools\sketchup-scene-export\` — never committed on any branch.
- `Desktop\ProposalFiles\` and `Desktop\WhisperRoom\` (brand guideline, historical drawings) —
  local-only by design; copy them across manually.

## 2026-08-06

### Done

**Workspace set up.** Repo created and pushed — `bentonwhiteWR/WhisperRoom-SketchUp`,
private (it carries internal pricing). `CLAUDE.md` plus `reference/` hold the rules;
`scripts/` holds the working tools.

**CSUSB job, start to finish.**

- Took off both rooms from the client's PDFs: Chaparral **117 = 51'-4" × 48'-3"** (2,013 sq ft
  net) and University Hall **056 = 25'-3" × 13'-4"** (274 sq ft), every in-line wall run
  dimensioned, all chains closing within ¼".
- Found **Room 117's printed scale is wrong** — the sheet says 1" = 30'-0" but the scale bar
  works out to 1" = 30'-10½". The bar is right; the sheet was reduced on export.
- Read the site photos: 117 is an **active dance studio on a raised sprung floor** (weight
  question for a 1,798–3,100 lb booth) and 056 has a **suspended lay-in ceiling in a basement**,
  which is the likeliest dealbreaker on that room.
- Delivered **`Desktop\ProposalFiles\CSUSB\CSUSB-Booth-Renderings.pdf`** — 23 pages, four
  configurations, 3.09 MB, verified page by page.

**Proposal rules corrected.** The shipped format is **US Letter portrait**, not the landscape
layout `PROPOSAL-GUIDELINES.md` describes. That doc is superseded; `reference/proposal-brand.md`
now matches the David Smith pack, which is the standard.

**SketchUp automation built.**

- `wr_tools` plugin — **Extensions > WhisperRoom** menu and toolbar, auto-discovering every
  script in `scripts/`.
- `csusb-rooms.rb` — both rooms to the measured interiors, mitred corners, doors with swings,
  dimensions on all four sides.
- `export-scenes.rb` — batch scene → PNG into `Desktop\ProposalFiles\ImageExports`.
- `build-booth.rb` + `gen-booth.py` — **all 25 Standard booths** from a dropdown. Panels 1"×81",
  mid-wall seam seals as single T solids, corner seals as single L-with-notch solids including
  the 1"×1" inside block, finished in Carpet Plush Charcoal.

**The assembly rule, confirmed and implemented:**

```
interior wall run = sum(panel lengths) + 2" per joint
```

The 2" is the mid-wall seam-seal stem. It also explains both errors in
`booth-layouts.json` — the 4872's "24" is a 22 with its seal absorbed, the 96120's "47+47" is
really 46+seal+46. `components-master.json` holds **shipping** sizes, never finished geometry.

### Next steps

1. **Settle instance-vs-model.** Open `BoothBuilderV2.skp`, run in the Ruby Console:
   ```ruby
   Sketchup.active_model.definitions.map { |d| "#{d.name}  (#{d.count_instances} used)" }.sort.each { |s| puts s }
   ```
   If real component definitions exist, we instance them instead of modelling doors, vents and
   windows — and the booth-builder share link goes live immediately. If not, we model those
   three features ourselves. **This decides the next chunk of work; do it first.**
2. **Ceiling panels** — need finished dimensions from Benton, same as the wall panels.
3. **Booth-in-room placement** — put a built booth inside a built room against the clearance
   rules (1" nominal, 10" vented with silencers, 45.625" ADA ramp). Produces the dimensioned
   top-down plate.
4. **Scenes and cameras** — five standard views named in plate order, feeding `export-scenes.rb`
   and then `proposal-v2.json`.
5. **Enhanced variants** — 25 more booths. Booth-inside-a-booth with a gap; only needs the gap
   dimension.

### Open decisions

- **"Inside dimension" — clear or panel-face?** Benton's 4260 note says the 40" side has a 38"
  inside dimension. The data says 40. The corner seals' 1"×1" blocks intrude 1" at each end,
  which is exactly the 2". If clear-between-corners is the number that matters, say so and both
  figures get reported.
- **`models.json` 4260 depth** lists 5'-8" (68") where `booth-layouts.json` says 62", and 62 is
  what the model number implies. One of them is wrong, and `models.json` is what the quote tool
  prices from.
- **CSUSB, with the client:** ceiling height in both rooms, the ADA raised-floor height (adds on
  top of the 7'-1"), and which wall in 117 the booth goes on — Maxine named it by photo, not
  compass.
- Two Enhanced renders disagree on the vertical callout — 7' 5/16" vs 7' 1". Resolved as
  exact-vs-marketed, but worth knowing the pack shows the exact figure.

### On another machine

```
git pull
python scripts/install-plugin.py     # then restart SketchUp
```

Only `wr_tools` needs installing. Everything else in `scripts/` is read live from the repo, so
edits take effect on the next click with no restart.
