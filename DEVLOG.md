# DEVLOG

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
