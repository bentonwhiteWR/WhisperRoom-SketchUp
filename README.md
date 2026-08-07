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
| `scripts/` | SketchUp Ruby (`csusb-rooms.rb`), the `wr_tools` plugin, and the catalog table generator. |
| `clients/` | Per-client working notes. Client-supplied plans and renders are gitignored. |

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
