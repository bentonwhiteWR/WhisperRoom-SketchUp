# Script inventory — `scripts/`

Every file in `C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\scripts\`,
as of 2026-08-15.

**How this was produced (provenance).** `scripts/wr_tools/main.rb` and
`scripts/wr_tools/panel.html` were read **in full** (observed). Every other `.rb` and `.py`
was read as its **header block — the first 20 to 60 lines** — plus targeted greps into the
body for entry points, autorun guards, tag constants and category directives (observed for
those spans, and the "what it does" lines below are taken from that text, not from the
filename). No file was read end to end apart from the two plugin files. **Nothing was
executed** — there is no Ruby interpreter on this machine outside SketchUp, per `CLAUDE.md`
— so every behavioural statement here is derived from source, not observed at runtime.

The headers in this repo are unusually explicit and argue their own design, so a header
claim is strong evidence of intent; it is still not evidence that the code does what the
header says.

---

## Legend

- **Audience**: DAILY / OCCASIONAL / DEV-ONLY / LIBRARY / ONE-OFF
- **Shape**: ability (on–off toggle) or action (one shot)
- **Acts on**: whole model / selection / files on disk / preferences / nothing

---

## Visible in the panel today (28 `.rb` files)

### Category: Build a booth

| | |
|---|---|
| **Path** | `scripts/booth-from-link.rb` |
| **Headers** | `@title Build Booth from Link...` · `@cat Build a booth` |
| **Does** | Takes a `sales.whisperroom.com/booth-builder` share link, fetches or decodes the customer's own design payload, and builds that exact booth — model, door hand, windows, vents, VSS/EFS, height extension — by loading `build-booth-components.rb`. |
| **Audience** | DAILY |
| **Shape** | action (dialog) |
| **Acts on** | network + whole model |
| **Icon** | none in the list; `FAV_ICONS` maps it to `icon-boothlink.svg` only if it is put in a toolbar slot (`main.rb:294-300`) |

| | |
|---|---|
| **Path** | `scripts/build-booth-components.rb` |
| **Headers** | `@title Build Booth (real components)...` · `@cat Build a booth` |
| **Does** | Builds a booth from the real component `.skp` files rather than extruded slabs, so doors swing, windows have glass and vents have ducts; layout comes from `wr-booth-data.rb`, orientation is measured per part from its own bounding box because the 182 components share no authoring convention. |
| **Audience** | DAILY |
| **Shape** | action (dialog) |
| **Acts on** | whole model + component library on disk |
| **Icon** | `icon-boothbuild.svg`, toolbar slots only |

| | |
|---|---|
| **Path** | `scripts/build-booth.rb` |
| **Headers** | `@title Build Booth...` · `@cat Build a booth` |
| **Does** | Pick one of the 25 Standard booths from a dropdown and build it as extruded slabs from `wr-booth-data.rb`. Good for a plan check; `build-booth-components.rb`'s own header calls the result "useless for a render". |
| **Audience** | OCCASIONAL |
| **Shape** | action (dialog) |
| **Acts on** | whole model |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/booth-4260-s.rb` |
| **Headers** | `@title Build Booth MDL 4260 S` · **no `@cat`** → sinks to "More scripts" |
| **Does** | Hard-coded, machine-generated builder for exactly one booth (MDL 4260 S), written by `gen-booth.py`. Builds nothing else. |
| **Audience** | ONE-OFF (retired scheme — `build-booth.rb`'s header says it "replaces the one-script-per-booth arrangement") |
| **Shape** | action (no dialog; builds on load) |
| **Acts on** | whole model |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/booth-96168-s.rb` |
| **Headers** | `@title Build Booth MDL 96168 S` · **no `@cat`** |
| **Does** | Same as above for MDL 96168 S. |
| **Audience** | ONE-OFF (retired scheme) |
| **Shape** | action |
| **Acts on** | whole model |
| **Icon** | none |

### Category: Room tools

| | |
|---|---|
| **Path** | `scripts/build-room.rb` |
| **Headers** | `@title Build Room...` · `@cat Room tools` |
| **Does** | Type a take-off as direction-and-length runs; the dialog previews the polygon and says whether it closes before anything is built. Walls go outward from the interior face and mitre at the corners, doors are real openings with a swing, and it finishes by calling `auto-dimension.rb`. |
| **Audience** | DAILY |
| **Shape** | action (dialog) |
| **Acts on** | whole model |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/auto-dimension.rb` |
| **Headers** | `@title Auto Dimension...` · `@cat Room tools` · `@ability Dimensioned` |
| **Does** | Chain-dimensions a room from the interior floor face's outer loop: a segment chain per side, an overall outside it, doors off their wall corners; winding computed, closure checked and reported per axis. Tags `WR-Dims` / `WR-Dims-Doors`. Also the engine `build-room.rb` finishes with. |
| **Audience** | DAILY |
| **Shape** | **both** — ability *and* a row that runs it |
| **Acts on** | whole model (finds the largest horizontal face — **ignores the selection**) |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/dimension-booth.rb` |
| **Headers** | `@title Dimension WhisperRoom...` · `@cat Room tools` · `@ability Dimensioned booth` · 3 `@setting`s (height / vents / gap) |
| **Does** | Works out **which** booth model the selection is — by group name, else by deck part names — then dimensions it to the catalogue figures plus a per-vented-face 5.5 in projection rule, and labels the drawing with the model name. Tags `WR-Dims-Booth`. Warns when `WR-Dims-Selection` dimensions are also present, because the two disagree. |
| **Audience** | DAILY |
| **Shape** | both |
| **Acts on** | selection |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/dimension-selection.rb` |
| **Headers** | `@title Dimension Selection...` · `@cat Room tools` · `@ability Dimensioned selection` · 2 `@setting`s (where / gap) |
| **Does** | Length, width and height of whatever is selected, taken from the instance's **world** bounding box and drawn in model space. Tags `WR-Dims-Selection`. |
| **Audience** | DAILY |
| **Shape** | both |
| **Acts on** | selection |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/explode-view.rb` |
| **Headers** | `@title Exploded View...` · `@cat Room tools` ← **wrong category** · `@ability Exploded` · 2 `@setting`s (mode / spread) |
| **Does** | Pulls a selected assembly apart, one axis per part, for an assembly-manual illustration; every part stores its home position as an attribute so Reset is exact and re-exploding never compounds. Nothing to do with rooms. |
| **Audience** | OCCASIONAL |
| **Shape** | both |
| **Acts on** | selection |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/proposal-scenes.rb` |
| **Headers** | `@title Proposal Scenes...` · `@cat Room tools` ← **wrong category** · `@ability Proposal scenes` |
| **Does** | Creates the five proposal plates as scenes in order (exterior, dimensioned, side, ventilation, plan), each carrying its own camera, tag visibility and style; reads the real door and vent side off the `WR-Booth-Door` / `WR-Booth-Vent` tags rather than guessing. |
| **Audience** | DAILY |
| **Shape** | both |
| **Acts on** | whole model |
| **Icon** | none |

### Category: Model tools

| | |
|---|---|
| **Path** | `scripts/list-scenes.rb` |
| **Headers** | `@title List Scenes...` · `@cat Model tools` |
| **Does** | Every scene with its `model.pages` number in a searchable, sortable, tickable window; ticking rows builds the `1-3,5,9-10` range string the exporters' Scenes field wants, and each row resolves which component that scene is aimed at. Read-only except that a row's arrow activates the scene. |
| **Audience** | DAILY (companion to the exporters) |
| **Shape** | action |
| **Acts on** | whole model (read) |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/save-scene-components.rb` |
| **Headers** | `@title Save Scene Components...` · `@cat Model tools` |
| **Does** | One `.skp` per scene: walks the scene list, resolves which component each scene is looking at (same camera-target rule as `angled-component-art.rb`), and saves that definition to its own file named after the scene. Reports every time two scenes resolve to the same definition. |
| **Audience** | OCCASIONAL |
| **Shape** | action (dialog) |
| **Acts on** | whole model → files on disk |
| **Icon** | `icon-scenecomps.svg`, toolbar slots only |

| | |
|---|---|
| **Path** | `scripts/find-replace-names.rb` |
| **Headers** | `@title Find and Replace Names...` · `@cat Model tools` |
| **Does** | Find-and-replace across scene names, component definition names, tag names or material names. Previews by default, is one undo step, and refuses to run when a rename would collide. |
| **Audience** | OCCASIONAL |
| **Shape** | action (dialog) |
| **Acts on** | whole model (**writes**) |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/merge-materials.rb` |
| **Headers** | `@title Merge Materials...` · `@cat Model tools` |
| **Does** | Repoints every face, edge, group and instance using material A at material B and deletes A; both picked from dropdowns carrying live use counts, with an option to sweep up the `Name 1` / `Name (2)` copies SketchUp creates on import. Dry run first. |
| **Audience** | OCCASIONAL |
| **Shape** | action (dialog) |
| **Acts on** | whole model (**writes**) |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/merge-scenes.rb` |
| **Headers** | `@title Merge Scenes...` · `@cat Model tools` |
| **Does** | Brings one `.skp` into another **and carries the incoming file's scenes across**, which File > Import cannot do. Two passes: export scenes from the incoming file to JSON, then import + rebuild in the host, moving every camera by the derived placement vector. |
| **Audience** | OCCASIONAL |
| **Shape** | action (dialog, run twice) |
| **Acts on** | whole model + files on disk |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/probe-components.rb` |
| **Headers** | `@title Probe Component Files...` · `@cat Model tools` |
| **Does** | Loads every `.skp` in a folder, measures its bounding box and where its origin sits inside it, and writes a table — the measurement step that had to happen before booths could be assembled from real components. **Its own header says to run it on an empty model**: it loads ~180 definitions into whatever is open and cannot fully purge them back out. |
| **Audience** | DEV-ONLY |
| **Shape** | action (dialog) |
| **Acts on** | a folder of files on disk → console table (and pollutes the open model) |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/probe-levels.rb` |
| **Headers** | `@title Probe Face Levels...` · `@cat Model tools` |
| **Does** | Per part, the heights of its horizontal faces and how much area sits at each — the only way to measure a floor panel's raised perimeter strip, which a bounding box cannot see. Feeds `wr-deck.rb`. Same empty-model warning. |
| **Audience** | DEV-ONLY |
| **Shape** | action (dialog) |
| **Acts on** | a folder of files on disk → console table |
| **Icon** | none |

### Category: Export art

| | |
|---|---|
| **Path** | `scripts/export-scenes.rb` |
| **Headers** | `@title Export Scenes...` · `@cat Export art` |
| **Does** | Batch-exports scenes to PNG with opaque backgrounds into `ProposalFiles`, named verbatim after the scene so a file can be matched back to its scene by eye. The proposal-plate exporter. |
| **Audience** | DAILY |
| **Shape** | action (dialog) |
| **Acts on** | whole model → files on disk |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/export-this-view.rb` |
| **Headers** | `@title Export This View...` · `@cat Export art` |
| **Does** | Writes exactly one PNG of what is on screen, named after the current scene, seeded from whatever `export-component-art.rb` last used so a one-off drops back into the batch; warns on a pixel-size mismatch against the folder's `manifest.json`. |
| **Audience** | DAILY |
| **Shape** | action (dialog) |
| **Acts on** | viewport → one file on disk |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/export-component-art.rb` |
| **Headers** | `@title Export Component Art...` · `@cat Export art` |
| **Does** | One **transparent** PNG per scene for the whole model, plus a manifest — the flat walk-around set for the web booth builder. Shading contract comes from `wr-shading.rb` and must match `angled-component-art.rb`. Opens on "Dry run = Yes". |
| **Audience** | OCCASIONAL (web-catalog pipeline, not the proposal pipeline) |
| **Shape** | action (dialog) |
| **Acts on** | whole model → files on disk |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/angled-component-art.rb` |
| **Headers** | `@title Angled Component Art...` · `@cat Export art` |
| **Does** | The Iso30 set: every part shot at four fixed angled cameras on one shared canvas with the part's insertion point at the centre pixel, so a web page can composite a whole booth by translation alone. Subject resolved from the scene's camera target, not the scene name. |
| **Audience** | OCCASIONAL (web-catalog pipeline) |
| **Shape** | action (dialog) |
| **Acts on** | whole model → files on disk |
| **Icon** | `icon-angled.svg`, toolbar slots only |

| | |
|---|---|
| **Path** | `scripts/elevation-export.rb` |
| **Headers** | `@title Elevation Export...` · `@cat Export art` |
| **Does** | Straight-on orthographic front/back/left/right/top/bottom of every scene's component at **one shared scale** across the whole run, using its own camera rather than the scene's, so the parts composite side by side. |
| **Audience** | OCCASIONAL (web-catalog pipeline) |
| **Shape** | action (dialog) |
| **Acts on** | whole model → files on disk |
| **Icon** | `icon-elevation.svg`, toolbar slots only |

| | |
|---|---|
| **Path** | `scripts/orbit-export.rb` |
| **Headers** | `@title Orbit Export...` · `@cat Export art` |
| **Does** | Walks the camera around a part or every part of an assembly and writes every angle at constant scale plus a `manifest.json` — the base of the assembly manual. Uses parallel projection with a fixed view height so parts don't resize as they turn. |
| **Audience** | OCCASIONAL (assembly manual) |
| **Shape** | action (dialog) |
| **Acts on** | whole model → files on disk |
| **Icon** | none |

### No `@cat` — falls into "More scripts"

| | |
|---|---|
| **Path** | `scripts/csusb-rooms.rb` |
| **Headers** | **none at all** — the panel shows the prettified filename "Csusb Rooms" |
| **Does** | Builds two specific rooms for one specific customer (CSUSB Chaparral 117 and University Hall 056) from dimensions read off that client's PDFs. |
| **Audience** | ONE-OFF (a single customer, already delivered) |
| **Shape** | action (builds on load, no dialog) |
| **Acts on** | whole model |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/diag-favourites.rb` |
| **Headers** | **none at all** — shows as "Diag Favourites" |
| **Does** | Diagnostic that round-trips strings through `Sketchup.write_default` / `read_default` to explain why starring a script did not stick. Touches no geometry. The bug it was written for is documented as understood and fixed in `main.rb:206-224`. |
| **Audience** | DEV-ONLY |
| **Shape** | action (console output) |
| **Acts on** | preferences |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/pendant-jig.rb` |
| **Headers** | `@title Pendant Curing Jig...` · **no `@cat`** |
| **Does** | Builds a 3D-printable lathed jig that holds a pendant's metal housing square and centres the polycarbonate tube while adhesive cures. |
| **Audience** | ONE-OFF (3D-print side project — see `reference/3d-printing.md`) |
| **Shape** | action |
| **Acts on** | whole model |
| **Icon** | none |

| | |
|---|---|
| **Path** | `scripts/tube-drying-stand.rb` |
| **Headers** | `@title Tube Drying Stand...` · **no `@cat`** |
| **Does** | Builds a 3D-printable diamond-lattice rack that stands 30 polycarbonate tubes upright while epoxy cures, sized so two of them drop into a 92×135 mm silicone tray. |
| **Audience** | ONE-OFF (3D-print side project) |
| **Shape** | action |
| **Acts on** | whole model |
| **Icon** | none |

---

## Libraries — correctly hidden by `SKIP` (5 files)

`SKIP` is defined at `scripts/wr_tools/main.rb:61-62` as
`['wr_tools.rb', 'wr-booth-data.rb', 'wr-shading.rb', 'wr-folder.rb', 'wr-deck.rb']`.

| Path | What it is |
|---|---|
| `scripts/wr_tools.rb` | The extension loader SketchUp registers; points at `wr_tools/main.rb`. |
| `scripts/wr-booth-data.rb` | Generated layout data for all 25 provable Standard booths, read by `build-booth.rb` and `build-booth-components.rb`. Lists the 25 Enhanced variants it had to skip. |
| `scripts/wr-deck.rb` | Floors and ceilings for the component builder; every number measured with `probe-levels.rb`. |
| `scripts/wr-folder.rb` | The shared folder-picker dropdown used by every script with an output folder. |
| `scripts/wr-shading.rb` | The single shading contract both component-art exporters push and read back. |

**Verified: `SKIP` is complete and correct.** I checked every `.rb` in `scripts/`; these five
are the only files whose own header declares them a library rather than a command, and each
of the other 28 ends in a top-level call that does something. No library leaks into the
panel, and nothing in `SKIP` is a tool that should be visible.

---

## Python and other files — invisible to the panel

`main.rb:73` selects `/\.rb\z/i` only, so **no `.py` file has ever appeared in the panel**.
These are shell tools, and the README documents three of them as things to run by hand.

| Path | What it does | Audience |
|---|---|---|
| `scripts/install-plugin.py` | Copies `wr_tools.rb`, `wr_tools/` and every script into each SketchUp Plugins folder on the machine. | OCCASIONAL (setup) |
| `scripts/rbcheck.py` | Crude Ruby block-balance check — matches block openers against `end` — because no machine here has Ruby outside SketchUp. | DEV-ONLY (pre-handoff gate) |
| `scripts/make-icons.py` | Generates the whole `wr_tools/ico-*.svg` library from one table, so every icon shares a viewBox, stroke width and cap style. **This is the file an icon redesign edits.** | DEV-ONLY |
| `scripts/gen-booth.py` | Generates a Ruby booth builder from real part geometry; `--all` writes `wr-booth-data.rb`, `--design <link>` handles a share link. | DEV-ONLY |
| `scripts/gen-booth-models.py` | Regenerates `reference/booth-models.md` from the catalog's `models.json`. | OCCASIONAL |
| `scripts/fix-angled-alpha.py` | Inverts SketchUp 2024's uniform 75% black composite on exported PNGs (the transform was measured exactly, so it is invertible). | DEV-ONLY (art pipeline) |
| `scripts/combine-ao.py` | Marries the two-pass AO exports — colour from the opaque shot, alpha from the transparent one. | DEV-ONLY (art pipeline) |
| `scripts/pendant-jig-stl.py` | Second implementation of the pendant jig geometry, writing binary STL without opening SketchUp; `--check` diffs its constants against the `.rb`. | ONE-OFF |
| `scripts/backup-sketchup-settings.py` | Copies SketchUp preferences, keyboard shortcuts and templates into the repo; deliberately excludes `login_session.dat`. | OCCASIONAL |
| `scripts/quicksnip/` | AutoHotkey screen-region grabber. Not a SketchUp script; has its own README. | OCCASIONAL |

---

## Counts

- 28 `.rb` visible in the panel; 5 libraries correctly hidden; 9 `.py` + 1 AHK tool invisible by design.
- Of the 28 visible: **11 DAILY**, **11 OCCASIONAL**, **3 DEV-ONLY**, **5 ONE-OFF**
  (`booth-4260-s`, `booth-96168-s`, `csusb-rooms`, `pendant-jig`, `tube-drying-stand`).
- 5 are abilities as well as actions; 23 are actions only.
- **Not one script row in the panel carries an icon.** Icons exist only on the eight
  customisable SketchUp toolbar slots, and only 5 of the 28 scripts have a per-script face
  at all (`FAV_ICONS`, `main.rb:294-300`) — everything else falls back to a numbered star.
