# WhisperRoom SketchUp Assistant

Rules and reference data for the Claude assistant Benton uses for **WhisperRoom SketchUp
work**: reading client floor plans, estimating dimensions off scaled drawings, recommending
booth models and layouts, and building the branded client proposal.

**No application code lives here.** The generators and the product catalog live in sibling
repos; this repo is the operating rules that point at them, so the same assistant behaves
identically on the laptop and the desktop.

## Contents

| File | What it is |
|---|---|
| `CLAUDE.md` | The rules the assistant loads every session. Start here. |
| `reference/scale-estimation.md` | Getting defensible dimensions out of an unlabeled client floor plan. |
| `reference/sketchup-drawing.md` | Model standards, default materials, geometry and dimensioning rules for SketchUp. |
| `reference/proposal-brand.md` | The proposal format as it actually ships — portrait, layout, render order. |
| `reference/booth-models.md` | All 26 booth models — exterior dims, weights, prices. Generated from `models.json`. |
| `reference/3d-printing.md` | The printer, the sourced overhang and bridging limits, and the design rules the pendant fixtures follow. |
| `scripts/` | The `wr_tools` plugin and every SketchUp Ruby tool — see the table below. |
| `docs/` | Self-contained pages with working demos. Open them in a browser; no build step. |
| `clients/` | Per-client working notes. Client-supplied plans and renders are gitignored. |

## The scripts

All of these appear in the **WhisperRoom panel** automatically. Newest first,
type to filter, star one to pin it to the toolbar.

| Script | What it does |
|---|---|
| `build-room.rb` | Type a take-off as direction-and-length runs, see it close or fail live, then build it — walls mitred, doors as real openings — and it finishes dimensioned. |
| `auto-dimension.rb` | Chain-dimensions a room off its interior floor face. Winding computed, closure checked per axis and reported, doors off their corners. Also the engine `build-room` finishes with. |
| `proposal-scenes.rb` | The five proposal plates as scenes, in order, each holding its own camera, tag visibility and style. Reads the door side off `WR-Booth-Door`. |
| `export-scenes.rb` | Every scene in the model to a PNG named after the scene. |
| `orbit-export.rb` | Every angle of every part, at constant scale, plus a `manifest.json`. The base of the assembly manual. |
| `explode-view.rb` | Pulls an assembly apart along one axis per part, and puts it back exactly — every part records its home. |
| `build-booth.rb` | Builds a booth from `wr-booth-data.rb`. 25 Standard variants today; Enhanced are unresolved. |
| `pendant-jig.rb`, `tube-drying-stand.rb` | The pendant-side 3D-printed fixtures. See `reference/3d-printing.md`. |
| `rbcheck.py` | Block-balance check. There is no Ruby outside SketchUp on either machine — run this before handing a script over. |

### Desktop helper

`scripts/quicksnip/` is not a SketchUp script and does not appear in the panel.
It is an AutoHotkey tool that grabs a fixed screen region — set once over the
SketchUp viewport — straight to the clipboard on a single keypress, for pasting
the same view into proposals and messages without re-cropping every time. See
its own README for hotkeys and setup.

## The pipeline

```
client floor plan (PDF) → take-off → SketchUp model → renders → proposal PDF
```

The dimensioned view in a proposal is a SketchUp export carrying SketchUp dimension
entities, so the model and the proposal are one pipeline.

## Related repos and folders

- `WhisperRoomQuote` — product catalog (`whisperroom-catalog/data/models.json`), top-down and
  elevation art. **Read-only from here.**
- `WhisperRoom Proposals` — the proposal generator (`build-v2.js`) and the authoritative
  brand spec (`docs/PROPOSAL-GUIDELINES.md`).
- `Desktop\ProposalFiles\<Client>\` — finished client proposal PDFs.

## Keeping it in sync across machines

This repo exists so both machines run the same rules. Pull at the start of a session, push
at the end. The `cross-machine-handoff` skill does both.

## The plugin

`scripts/wr_tools` puts a **WhisperRoom** panel on the toolbar. Install once per
machine:

```
python scripts/install-plugin.py
```

Restart SketchUp, then use the panel rather than the menu — it rescans
`scripts/` every time it opens, so a new script needs no restart and no
reinstall. Newest first, type to filter, Enter to run. The menu is a fallback
and is frozen at whatever existed when SketchUp launched, because SketchUp has
no API for rebuilding one.

Re-run the installer only after changing `wr_tools` itself; everything else in
`scripts/` is read live.

Before handing over a script, check its blocks balance — there is no Ruby
outside SketchUp on either machine:

```
python scripts/rbcheck.py
```

Regenerate the model table after a catalog change:

```
python scripts/gen-booth-models.py
```
