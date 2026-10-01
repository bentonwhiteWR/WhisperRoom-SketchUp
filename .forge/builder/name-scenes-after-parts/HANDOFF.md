# HANDOFF — Name scenes after their parts (1.79.0)

**Status:** shipped to main, parse-checked and pure-logic tested. NOT run in SketchUp.

## Files
- `scripts/name-scenes-after-parts.rb`: the tool (TOOLS tab, `@cat Tidy up the model`, `@rank 3`, `@icon scene-parts`)
- `scripts/rbtest-name-scenes.py`: offline test of the pure block, plus a drift check on the resolver copy
- `scripts/wr_tools/VERSION` 1.78.0 -> 1.79.0, `README.md` row, `DEVLOG.md` entry

## Decisions
- **Unnamed scene** = `/\AScene \d+(?: \(\d+\))?\z/` on the stripped name (blank also counts). There was no
  existing rule in scripts/ to reuse. It is case-sensitive and English-only.
- **Positions** use export-scenes.rb's parsing rule (1-based, reversed ranges turned round, clamped, misses
  reported). Numbers only; no name search.
- **Resolver**: the verbatim copy from bulk-name-after-scenes.rb. The rbtest fails if it drifts.
- **Collisions**: numbered `Name`, `Name (2)`, `Name (3)` in position order, shown in the table. Names held by
  scenes that are not being renamed are skipped over. A scene already holding `Name`/`Name (k)` for its own
  part keeps it. Case-insensitive. At Apply, a ticked row blocked by an unticked or out-of-scope scene is
  skipped, never renumbered.
- **Apply**: temp names, then final names, then read back. Any mismatch aborts the batch and restores the
  names. One undo step.

## First run in SketchUp (to do)
1. Panel -> Name scenes after their parts, or
   `load "C:/Users/bento/Documents/Claude/Sketchup/scripts/name-scenes-after-parts.rb"`.
2. Try Positions `355-360` on Master Component List AM and check the RAY rows against the door-scene one-off's names.
3. Apply, then press Ctrl+Z once: every name should come back.
