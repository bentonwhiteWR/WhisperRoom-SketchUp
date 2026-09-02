# HANDOFF — mirrored side walls on the split-run booths (plugin 1.19.10)

Fixer, 2026-09-02. Audit finding 1 / C-1.

## Produced

- `scripts/gen-booth.py` — the 28 Aug positional swap (`SWAP_TWO_PANEL_SIDE_WALL`,
  `swap_side_wall`, the `outer_lengths` plumbing) removed; header comment records the
  2 Sep ruling and names this file the only owner of panel order.
- `scripts/wr-booth-data.rb` — regenerated (`gen-booth.py --all`), 72 lines in the four
  60-series blocks; content-identical to the pre-`a886105` file.
- `scripts/build-booth-components.rb` — `ASSIGN` rewritten: 6060 / 6084 / 7296 E/W entries
  deleted, 7272 S/E E/W entries re-keyed to the slot of their own width. Comment states the
  rule: ASSIGN names parts, never moves them.
- `scripts/rbtest-side-wall-order.py` — NEW pinned test, 437 checks, both paths, all 50
  keys. Fails 125/473 on the unfixed tree; mutation-checked both ways.
- `scripts/rbtest-part-orientation.py` — section 2 rewritten (35 checks, was 45).
- `scripts/rbtest-overlays.py` — fixture comment only.
- `.forge/builder/booth-matrix/STALE-1.19.10-side-wall-order.md` — which baseline keys hold
  the defect and what the next live run should show.
- `.forge/fixer/side-wall-order-BEFORE.txt` / `-AFTER.txt` — the reproduction and the pass.
- `DEVLOG.md` entry; `scripts/wr_tools/VERSION` 1.19.10.
- The previous handoff here (roof-vent CBL, 1.12.11) moved to `HANDOFF-roof-vent-cbl.md`.

## Read-first

1. `scripts/rbtest-side-wall-order.py` docstring — what runs, what is stood in for, what
   is asserted. Run it: `python scripts/rbtest-side-wall-order.py`.
2. `.forge/builder/booth-matrix/STALE-1.19.10-side-wall-order.md` — the golden baseline was
   NOT regenerated (no SketchUp here). Eight keys will diff CHANGED on the next live run;
   that is expected. Do not silence it and do not treat it as a regression.
3. The `ASSIGN` header in `scripts/build-booth-components.rb` (search "ASSIGN NAMES PARTS").

## Assumptions

- **Nominal width = measured width.** The harness stands `classify()`/`wall_slab` in with the
  width the part name declares. On Standard parts that is what the slab measures; on ENH
  parts it is `rebalance_walls`'s own fallback. A real 46VNT_VSS or 46Panel3236WDO that
  measured more than 1 in off 46 would rebalance live and the harness would not see it.
- The link path is modelled as the catalogue-default `#3=` slot map (every slot its own
  snapped width, right hinge, no packages). A customer link that assigns a WA door or a
  different-width pack still goes through `rebalance_walls` exactly as before; that path
  is unchanged by this work and untested here beyond `rbtest.py`'s existing WA case.
- Standalone 6060 / 6084 / 7296 builds now GUESS every side-wall name (`40VNT`,
  `40PanelSolid`, `16PanelSolid`, `46PanelSolid`, `22PanelSolid`). Those are the same
  strings the old table carried, so the library lookups are unchanged — assumed, not run.
- Benton's 2 Sep ruling is taken as settled for both families, as the brief instructs.

## Open-questions

- **Live close-out needed:** one 6060 S and one 7272 S from the panel button AND from a
  share link, top-down — 40/46 at the door end, window and vent on the door half, no
  `rebalanced` line in the console. Then re-capture the eight stale booth-matrix keys and
  delete the STALE note.
- `WhisperRoomQuote/lib/pl-data/booth-iso-geometry.json` was generated from
  `wr-booth-data.rb` on 2026-08-07 and already has the 40 at the door end on the 6060, so it
  now agrees with this repo again. Nothing to do there; noted so nobody "fixes" it.
- `rbtest-overlays.py`'s 7272 E fixture still uses the old swapped E/W polygons (labelled
  synthetic). Re-pinning it on the real arrangement is a small separate job; the geometry it
  tests does not depend on the order, so it was left alone.
- Not mine, left uncommitted: the orchestrator's edits to `.forge/GOAL.md` and
  `.forge/researcher/HANDOFF.md`, and the untracked `.forge/researcher/` tree (178 MB of
  builder captures + a node tool). Someone should decide what of that belongs in git.
