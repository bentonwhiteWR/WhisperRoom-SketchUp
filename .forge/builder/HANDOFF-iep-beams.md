# HANDOFF: IEP ceiling beams, bass-trap and studio-light orientation (1.83.0)

## Produced
- `scripts/wr-accessories.rb`: the beam table and rule.
  - `IEP_BEAM_SERIES`: series -> code, pack, part file, BOM L.
  - `IEP_BEAMS_BY_MODEL`: base-bom E-row counts. `IEP_BEAMS_84_DERIVED`: D11 counts.
  - `iep_series`, `iep_beam_plan(model, enh, rv)`.
  - `sl_tile_layout` replaces `sl_layout`.
- `scripts/wr-overlays.rb`:
  - Beams: the `IEP_BEAM_*` pose constants (confirmed by Benton, 12 Oct 2026), `place_iep_beams`, and
    `iep_beam_clashes` (a face-level clash report).
  - Traps: `trap_right_angle`, and `place_bass_traps` now seats the measured right angle in the corner.
  - Lights: `sl_tile_rects`, and `place_studio_lights` lays each fixture longwise inside one tile.
  - The beam pass is called from `place_all` after the accessories.
- `scripts/build-booth-components.rb`: `host['CL_seals']` and `host['CL_tiles']`.
- `scripts/booth-from-link.rb`: computes `beam_plan`, prints it, and passes `overlay['iep_beams']`.
- `scripts/rbtest-accessories.py`: beam-plan and tile-layout cases, and a `beam_drift` check against the quote
  repo.
- VERSION 1.83.0, DEVLOG entry.

## Read first
- DEVLOG 2026-10-12 entry (the tables, what was verified live, and the gotchas).
- `.forge/builder/HANDOFF-peoplesspace-accessories.md` Rounds 2-4: the beam and trap measurements this
  builds on.
- `WhisperRoomQuote/lib/packing-list.js`, around line 1027: the RM rule that adds beams to S booths.

## Assumptions
- One beam per ceiling seam seal (Benton's rule). The BOM agrees on every 96/102 model (U count = D101/D12
  count, observed).
- 84 series: Enhanced (RM or not) and RM Standard get IEP BEAM 7 (Benton, 12 Oct, reported). The count =
  D11 (one per ceiling seam seal); the BOM itself is silent. 72-series and smaller get none (Benton).
- Series = the model number's first figure (Benton): 10284 -> 102, 84102 -> 84.
- Part files by NAME (Benton): IEP BEAM 7 / 8 / 8.5, which measure 82 / 94 / 100 (= the seal lengths).
- Studio lights:
  - Which tiles get a fixture (widest first) and where across the tile (evenly spaced) are **assumed**.
  - Only the orientation (longwise on the tile, never across a seam) is Benton's.
- Interior rectangle centred on the booth plan (for clipping the light rectangles): **derived** from
  wr-booth-data. Checked on 96120 E only.

## Open questions
1. **Importer bug, MDL 10284 ceiling.** The BOM has A21 STD10242CL SIDE x2 + D12 FLCL8.5 x1, a 102 cross. The
   importer builds 8442 + 8418 + 8442 with 2 x CL7, an 84 cross: the 84102's ceiling. Until the deck is
   fixed, its 1 x IEP BEAM 8.5 is withheld with a loud KNOWN IMPORTER BUG message.
2. Live checks still owed, none of them built. They need a fresh model; under the bridge, `file_new`
   would not give a separate one while Benton was switching documents:
   - 102144 E;
   - 96120 S rv=1;
   - an 84 E;
   - 4872 E and 96120 S non-RM (no beams);
   - a drum booth (sl + bt) for the trap-leg ray check and the lights-inside-one-tile check.
3. On Benton's 96120 E the centre standard BoothLighting clears the two beams by only 0.05 in in plan.
   That's legal, but tight.
