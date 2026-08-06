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
| `reference/booth-models.md` | All 26 booth models — exterior dims, weights, prices, standard counts. Generated from `models.json`. |
| `reference/scale-estimation.md` | Method for getting defensible dimensions out of an unlabeled client floor plan. |
| `reference/proposal-brand.md` | Proposal color, type, layout, and render order at a glance. |
| `clients/` | Per-client working notes. Client-supplied plans and renders are gitignored. |

## Related repos and folders

- `WhisperRoomQuote` — product catalog (`whisperroom-catalog/data/models.json`), top-down and
  elevation art. **Read-only from here.**
- `WhisperRoom Proposals` — the proposal generator (`build-v2.js`) and the authoritative
  brand spec (`docs/PROPOSAL-GUIDELINES.md`).
- `Desktop\ProposalFiles\<Client>\` — finished client proposal PDFs.

## Keeping it in sync across machines

This repo exists so both machines run the same rules. Pull at the start of a session, push
at the end. The `cross-machine-handoff` skill does both.

Regenerate the model table after a catalog change:

```
python scripts/gen-booth-models.py
```
