# HANDOFF — WAJMBAD re-pointed to the 2.5 in void, 2026-09-21 (plugin 1.74.0)

Amends `.forge/builder/HANDOFF-wajmbad.md` (1.73.0). Nothing has been run in SketchUp — no
`ruby.exe`, no SketchUp on this machine. Every claim is labelled observed / derived / reported /
assumed.

## Produced

| file | change |
|---|---|
| `C:\Users\bento\Documents\Claude\Sketchup\scripts\build-booth-components.rb` | WAJMBAD constants block rewritten (`WAJMBAD_VOID_W`, `WAJMBAD_ABSORBS_SEAL`, `WAJMBAD_RUN_W` after `IEP_SEAL_W`, `WAJMBAD_YAW` after `WAJMBAD_FLIP_SIDE`); `wajmbad_void?`; `wajmbad_plan` now returns `[plan, absorbed, notes]` keyed on the **panel** slot; pass 1 skips absorbed seals and names the void slot; rows carry `:wajmbad`; `rebalance_walls` `pw_of` declares `WAJMBAD_RUN_W`; pass 2 places the adapter like a seal (centred, `SEAL_PROUD`, no flush), applies `WAJMBAD_YAW` then the flip; FIT warning reworded for that row. |
| `C:\Users\bento\Documents\Claude\Sketchup\scripts\booth-from-link.rb` | comments only — `ENH 2.5Panel` is a void the WAJMBAD fills, not an unauthored file. |
| `C:\Users\bento\Documents\Claude\Sketchup\scripts\wr_tools\VERSION` | 1.73.0 → **1.74.0** |
| `C:\Users\bento\Documents\Claude\Sketchup\DEVLOG.md` | 1.74.0 entry recording that 1.73.0's premise was wrong |

Untouched: `wr-booth-data.rb`, `wr-deck.rb`, `wr-overlays.rb`, the `WhisperRoomQuote` repo,
the `P:` share (read only: listed for `2.5`, `WAJMBAD`, seals).

## Read first

1. The `WAJMBAD_COMP` comment block — the 1.73.0 correction and the 102102 E walk-through that
   makes "replaces a seal" and "IS the 2.5 wall" the same statement.
2. `wajmbad_plan` — void-by-assignment, the straddle test for the seal between, and why a
   mid-wall door is no longer ambiguous.
3. `WAJMBAD_ABSORBS_SEAL`, `WAJMBAD_YAW`, `WAJMBAD_FLIP_SIDE` — the three one-line switches a
   built booth may flip.

## What a build prints (derived from the code, not seen)

- Header: `WAJMBAD  S1i -> ENH WAJMBAD  (R of S0i, read from outside) - FILLS the 2.5 in void
  the arithmetic left as ENH 2.5Panel`, then the note `S1i -> ENH WAJMBAD ABSORBS S-seal0i (the
  seal between it and S0i), which is NOT placed, and takes 9 in of run. That is the reading of
  the layout data, NOT a fit check: ... set WAJMBAD_ABSORBS_SEAL = false.`
- Pass 1: `S-seal0i  ENH MidWallSeamSeal  absorbed by the WAJMBAD - not placed`.
- Rebalance: `rebalanced S0i ENH RightWADoor 4.250..48.750`, `rebalanced S1i ENH WAJMBAD
  48.750..57.750 (slot was 46.250..57.750)`; S-seal1i and S2i unchanged.
- Pass 2: `S1i ENH WAJMBAD  WAJMBAD R of the door, yaw 180, no flip`.
- Flagged list: the ABSORBS note; `S1i ENH WAJMBAD: WAJMBAD orientation is NOT FIT-TESTED.
  Centred on a 9 in run in the 2.5 in void slot over the absorbed S-seal0i, turned 180.0 deg like
  a seal (WAJMBAD_YAW, assumed), no flip; WAJMBAD_FLIP_SIDE = nil ...`; and, if the part's box
  differs from 9 by more than 0.02 (it will), `box N.NNN against a 9 in declared run
  (WAJMBAD_RUN_W) - the overhang is expected to be seal caps`.

## Assumptions

- **DERIVED (layout data + Benton's two statements): the Z absorbs the seal beside the door.**
  Void is one seal away from the jamb in every layout (S0i | S-seal0i | S1i); the only single
  part touching both jamb and "the next seal" spans both. `WAJMBAD_ABSORBS_SEAL = false` is the
  alternative and is one line.
- **DERIVED: run width 9.0 = 2.5 + 6.5.** Closes every replayed wall to 0.000. Not measured off
  the part; the FIT line reports the box.
- **ASSUMED: `WAJMBAD_YAW = IEP_SEAL_YAW` (180).** The part is "a modified enhanced seam seal";
  authored frame not opened.
- **ASSUMED: the part's caps are symmetric about its run**, so centring its box on the slot
  lands it. A Z with an asymmetric jamb leg would sit off by half the asymmetry.
- **REPORTED (Benton) + REPORTED (P: probe table): height = ENH seal height = 79.5 / 89.5**,
  equal to `ENH_WALL_H`, so `part_height` is unchanged. If `classify` refuses ("no axis of its
  box measures 79.5 in"), the part is not that height and needs its own rule.
- **DERIVED: mid-wall side = the side the 2.5 void is on.** From booth-from-link's arithmetic
  (11.5 − 9 = 2.5 on the side the door grew into). Matches Benton's "whichever side the door is
  leaning more into" by construction, not by observation.
- **OBSERVED:** three `.skp` names on the share; no `ENH 2.5Panel.skp`; polygon extents in
  `wr-booth-data.rb`; the absent-file path was never silent (ABSENT list, YES/NO, orange
  placeholder, INCOMPLETE group name).

## Open questions — each one needs a built booth or Benton

1. **Seal absorbed or not** — look between the jamb and the adapter on a built booth.
2. **Yaw** — are the caps on the face the seals' caps are on? Else `WAJMBAD_YAW = 0.0`.
3. **Flip side** — jamb leg toward the door on each side? Set `WAJMBAD_FLIP_SIDE` to the side
   (L/R from outside) that came out wrong. Benton: "lets pull in a booth and i can tell you."
4. **HX handedness** — R_HX file's holes on the R side of a built HX booth?
5. **A WA door with no 2.5 in void** (a 84-series 44 in module, if one exists) gets a flagged
   note and no adapter. Whether such a booth takes a WAJMBAD at all is not known.
6. **Standalone (non-link) builds cannot pull it** — `ASSIGN` never names a WA door or a 2.5 in
   panel; only `booth-from-link` reaches this path. Pre-existing.
