# HANDOFF — 72-series standard deck hinges in the center (plugin 1.19.11)

Fixer, 2026-09-02. Benton's report off 1.19.10 builds: 7272 floor + ceiling and 7296
floor had hinges in the CENTER; 7296 ceiling, 6060, 6084 right.

## Produced

- `scripts/wr-deck.rb` — `MIRROR_DECK_KINDS = {}` (was 7272 FL+CL, 7296 FL). The comment
  above it carries the axis argument, the 08-31 / 09-01 / 09-02 history and the
  pre-registered alternative (a Y question wants `scaling(1, -1, 1)`, never the X mirror
  and never `YAW_180_FILES`). Table added to the reload list. Stale `0.218` for
  STD7224FL SIDE R corrected to the live 0.782 in the half-turn comment.
- `scripts/rbtest-part-orientation.py` — section 4 pins: table empty; mirror line still
  reflects X; 7272/7296 E0/W0 (46 in panel) at y 2..48. 46 checks pass.
- `.forge/fixer/ROOTCAUSE-deck-mirror-72-2026-09-02.md` — root cause, per-tile derivation
  with provenance, why "the other mirror" is not wanted, the residual.
- `scripts/wr_tools/VERSION` 1.19.11, `DEVLOG.md` entry.

## Read-first

1. `.forge/fixer/ROOTCAUSE-deck-mirror-72-2026-09-02.md` — the whole argument.
2. `scripts/wr-deck.rb`, the `MIRROR_DECK_KINDS` comment block.
3. Benton's SketchUp check list (per model, per kind). Build each from the panel after
   `git pull` + `install-plugin.py` + restart, then look at the deck from above:
   - **MDL 7272 S — FL**: the two floor tiles (STD7248FL SIDE L west, STD7224FL SIDE R
     east). You should see the hinge/bracket line of each tile against its OUTER side wall
     (west tile: west wall; east tile: east wall), nothing at the 48 in seam.
   - **MDL 7272 S — CL**: same look at the ceiling (STD7248CL SIDE L / STD7224CL SIDE R).
     Hinges against the outer walls, not at the seam.
   - **MDL 7296 S — FL**: STD7248FL SIDE L west, STD7248FL SIDE R east. Hinges against the
     outer walls. THEN also look along the long edge of the EAST tile: its wide hinge gap
     (2'-1/8", the 46 in wall's slot) should be at the SOUTH (door) end like the west
     tile's. If it is at the north end, that is the residual below, not this fix.
   - **MDL 7296 S — CL**: unchanged by this fix (was already unmirrored). Should still read
     exactly as it did on 1.19.10: right.
   - **MDL 6060 S and MDL 6084 S** (regression): decks untouched by this change (their
     footprints were never in the table). Should read exactly as on 1.19.10: right.
   - Any E model of the above shares the same table key, so one S build per model is
     enough; build the E if you want belt and braces.

## Assumptions

- **The ceiling bracket line sits in plan where its floor twin's does** (the standing
  "coplanar" assumption for convention-A ceilings, which measure nothing above the rim).
  Benton's 7296-CL-right / 7272-CL-wrong split is consistent with it but does not prove it.
- **The runtime `bracket_edge` equals the `_face-levels.tsv` column** (0.7823 for
  STD7224FL SIDE R). Reported by the harness fixture cross-check (18 agree), not observed
  in SketchUp this session.
- Removing the mirror puts every 72-series SIDE bracket at the outer wall — derived,
  unrun. No SketchUp and no ruby.exe here; `rbparse.py` (real CRuby parse) is the only
  execution.

## Open-questions

- **7296 high floor tile Y pattern.** STD7248FL SIDE R is indistinguishable from SIDE L by
  probe (same box, levels, 0.2612). The measured half-turn rule yaws it at the high end,
  which is right for the bracket line but reverses its long-edge gap pattern. If the file
  is a plain duplicate of SIDE L, the east tile's 46 in slot lands north while the E0 46 in
  panel is south. Out of scope here (yaw rule fenced). If Benton sees it, the fix is
  per-tile (mirror-X instead of yaw on that tile), which is what the dormant
  `big_wall_fraction` / `layout_big_on_low?` pair was written for — NOT a table entry.
- `.forge/builder/replay-iep-deck.py` fails before and after (wants ENH rows that
  `_face-levels.tsv` has never carried). Pre-existing, unrelated.
- `scripts/rbtest-live-booth.py` exits 2 without arguments — it drives a live SketchUp and
  is not an offline harness.
