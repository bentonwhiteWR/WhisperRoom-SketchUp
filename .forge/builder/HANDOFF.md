# HANDOFF — v1.6.23, the IEP tray lip and the floor seam seals

**UNRUN IN SKETCHUP.** There is no `ruby.exe` on this machine. Everything below was verified by
a real CRuby 3.2 syntax parse and by a Python replay against the real component folder, the real
probes and the real generated layouts. **Nothing has been built.**

## Produced

| File | What changed |
|---|---|
| `scripts/build-booth-components.rb` | `flat_placement` takes a per-axis seat (`:centre` / `:min` / `:max`); new `WR_BuildBoothComponents.seat`; `iep_deck` seats each tile's OUTER edge on its slot's outer edge, with a >2.5 in overhang tripwire and a `lip … pushed … out onto it` console note; the deck-seal caller now runs `%w[CL FL]` |
| `scripts/wr-deck.rb` | `SEAL_FL_NAME`, `SEAL_LEN_INSET`, `SEAL_FL_DATUM_LIFT` (nil = unmeasured); `seal_catalogue(dir, kind)`; `seals(..., kind)` places the floor family too |
| `scripts/wr_tools/VERSION` | 1.6.22 → 1.6.23 |
| `DEVLOG.md` | 2026-08-26 entry |
| `.forge/builder/replay-iep-deck.py` | 8 assertions → **25**; new sections 6 (the lip, measured, before/after) and 7 (seal selection) |

Not committed, not pushed — the tree is deliberately dirty for review.

## Read first

- `scripts/build-booth-components.rb`, the `iep_deck` tile loop — the whole lip derivation is in
  the comment block there.
- `scripts/wr-deck.rb`, `SEAL_FL_DATUM_LIFT` — the one unmeasured number, and why the ceiling's
  `-1.75` must not be borrowed.
- `python .forge/builder/replay-iep-deck.py` — section 6c prints the 6060 E's real edges before
  and after.

## Assumptions

- **The +1-per-outer-edge overhang IS the tray lip.** The measurement is unambiguous across all
  44 ENH deck parts; that it is the *engulfing* overhang rather than something else is read off
  Benton's own sentence about the tray, not off the geometry. *(derived / reported)*
- **The floor seal's seating height.** Placed with its top face flush to the floor deck's
  contact plane — the ceiling rule's own sentence applied to the floor. **Assumed**, warned by
  name on every build, one constant to correct.
- **`STDSS FL5` and `STDSS 8.5FL` follow the FL length rule** (full cross). Measured on FL6, FL7
  and FL8 only; those two are absent from `_face-levels.tsv`. *(assumed, tripwired)*
- **`_face-levels.tsv` is dated 2026-08-14** and its CL rows are provably stale (they show the
  pre-re-cut 2.000-tall seals). The FL rows carry the same date with no known event against them.
  *(reported)*
- ENH deck parts still yield no answer on the end-for-end turn — `bracket_edge` needs SketchUp.
  Unchanged from v1.6.22.

## Open questions — for Benton

1. **What height does the floor seam seal actually want?** Build any booth with a jointed deck
   (the 6060 is the smallest: one joint, `STDSS FL5`), find the placed seal, move it by hand
   until it seats, and report the delta. Then `WR_Deck::SEAL_FL_DATUM_LIFT` gets that number and
   the warning stops. The three candidates are written out at the constant.
2. **Should the Enhanced inner deck have seam seals at all?** There is no `ENH` deck seam seal in
   the library — only the two `ENH` *wall* seals. Parts question, not a code one.
3. **`ENH 8418 FL` measures 17.9375, 1/16 under its name** (as does `STD8418 FL`). It is a middle
   tile on the 10284 and 84102, so it leaves 1/32 at each side. Intentional joint allowance or a
   part to re-cut?
4. Still open from v1.6.22, untouched here: `IEP_WALL_LIFT` global vs per-booth (the 4872 E
   re-check), and the 11.5 / 35.5 room-prouds.

## What to build and probe to close this

1. `git pull` → `install-plugin.py` → **restart SketchUp** (VERSION lives under `wr_tools/`).
2. Build **MDL 6060 E, Shell = Both**. The two tray tiles should now meet flush at booth station
   43.000 and the tray should run 0.000 → 62.000 along the run, 1 in proud of the standard
   ceiling on all four sides. The mat should be exactly where it was.
3. Watch the console for `DECK SEAL FL:` — it will name `STDSS FL5` and say its datum is
   unmeasured. Look at where that seal landed against the floor joint and report the correction.
4. Select the inner deck → **Probe placement of what's selected** → hand back the TSV. That is
   what closes the lip claim with a measurement rather than a screenshot.
5. Re-open the **4872 E** and check its inner shell vertical at 0.6875 — still the observation
   that settles `IEP_WALL_LIFT`.
