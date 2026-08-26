# GOAL

## Mission
Make the booth-building scripts build **Enhanced (IEP)** booths correctly — a Standard outer
shell plus an inner shell placed inside it — model by model, each one closed by a measured
probe rather than a screenshot.

## Done means
- `booth-from-link.rb` builds an Enhanced booth from a real Enhanced share link, verified by
  diffing the script's RAW PACK / placement printout against the portal's "YOUR BOOTH" panel.
- **No silent Standard fallback.** A missing or unrecognised `ENH` part aborts by name.
  `ENH_MISSING_ABORTS = true` stays.
- Every part placed from a **measured** number. `probe-placement.rb` is the instrument;
  a screenshot is not evidence.
- No regression on the Standard path.

## Now
**Both probes are done. Nothing is waiting on a measurement.** Plugin **1.6.30** — VERSION is
under `wr_tools/`, so this needs `git pull` → `install-plugin.py` → **restart SketchUp**, not a
rescan. New constants shipped, and a Ruby module keeps its constants until restart.

1. **Build `MDL 84126 E`, Shell = Both** — this is the tray-orientation test and it comes first.
   Its deck is `ENH 8442CL SIDE` / `8442CL CTR` / `8442CL SIDE`, and only the two ends were
   authored upside down, so **before 1.6.30 that one ceiling had two trays opening up and one
   opening down.** Look at the inner ceiling from below: all three plates face down onto the
   standard ceiling, no tile an open box. Console: three `tray mouth reads …` lines, `UP …
   FLIPPED` on the SIDEs and `DOWN` on the CTR. Then **`MDL 102144 E`**, where all four tiles
   flip and you already have console history to diff. Full write-up:
   `.forge/fixer/TRAY-ORIENTATION-2026-08-26.md`.
2. **Then finish `MDL 6060 E`, Shell = Both** — unchanged by 1.6.30 (it tiles none of the four
   flipped parts). Check the inner floor mat and ceiling tray seat as the standard deck's do,
   then select the inner deck → **Probe placement of what's selected** → hand back the TSV.
   That closes the end-for-end turn question, which no harness can answer.
3. **Re-open the 4872 E and check its inner shell vertical at 0.6875** — see the open question
   below. This is the observation that decides the wall-lift default, and it is now the only
   number in the mission still resting on a guess. The 4872 E's deck does not move in 1.6.30.

### THE WALL LIFT IS A PER-BOOTH TABLE (v1.6.28), and its default is a guess
`IEP_WALL_LIFT` is no longer one constant. Three measurements exist and they disagree:

| booth | lift | provenance |
|---|---|---|
| MDL 4872 E | 0.7500 | Benton's eye 2026-08-25, then a full-booth probe agreeing to 0.0001 |
| MDL 6060 E | 0.6875 | Benton's eye 2026-08-26, **no probe** |
| MDL 102144 E | 0.7500 | Benton's eye 2026-08-26, **no probe** |
| **default** | **0.7500** | a GUESS covering the other 22 layouts, and the build names each one |

**No rule was derived** — Benton's words were *"Im not sure about any others."* The lift reaches
`part_top_z` as a required third argument resolved once per build, never module state, so it
cannot go stale between builds in one SketchUp session.

**What falsifies the default:** any Enhanced booth outside those three. A fourth reading of
**0.6875** means the 4872 E's probe measured a hand placement that was itself 1/16 out — that
probe measured Benton's *corrected* model, so it only proved the code matched his hand, not that
his hand was right — and the default belongs at 0.6875. A fourth reading of **0.7500** leaves
the 6060 E as the lone outlier, and it is the one row that has never been probed.
**`MDL 84126 E` in step 1 is a fourth reading — take it while you are in there.**

### Residual on the 6060, expected and not a defect
The room-proud figures for the **11.5** and **35.5** widths are still unmeasured and fall
through to `IEP_ROOM_PROUD_DEFAULT`; the build warns by name. Expect ~1/8" on `N0i`/`E1i`.
That residual **is** the next measurement Benton owes.

## Settled — do not re-derive
- Two-shell model; inner run rule 6.5; `IEP_TRAY_DROP = 0.75`;
  `IEP_DOOR_IN = 0.5`; room-proud per family/width in `IEP_ROOM_PROUD`.
- All 25 `E` layouts exist in `wr-booth-data.rb` (generated, do not hand-edit).
- Deck contact is the true face, not its 1/64 bucket (v1.6.18).
- **The tray orientation is MEASURED and the abstention is gone (v1.6.30).** Four of the 23 `ENH`
  ceiling parts are authored upside down — `10218CL CTR`, `10242CL CTR`, `10242CL SIDE`,
  `8442CL SIDE` — and nine `E` layouts tile one: 8484, 10284, 84102, 84126, 102102, 102126,
  102144, 102168, 102186. `ENH 8442CL CTR` is right way up while `8442CL SIDE` is not, so there
  is **no name-level rule** and none should be sought. The floor mat has no orientation to
  measure: every `ENH FL` part is a plain 0.3125 sheet, two equal levels.
- **`SEAL_FL_DATUM_LIFT` is MEASURED at `-1.1250` (v1.6.27).** It is not nil and never needs
  hand-measuring again. `_face-levels.tsv` cannot settle it — it describes the seal, not the
  slot — and does not contradict it.
- Not to be authored: ramp doors on Enhanced, the 2.5" panel (`STDWL7` skipped
  deliberately), vent option variants (`_VSS`/`_EFS`/`_CP` are Standard-only), side vents
  (front-view art only).
- **The `ENH` deck library is COMPLETE. Nothing needs authoring.** 44 Standard deck codes,
  44 Enhanced, identical sets. **All 25 `E` layouts resolve a full inner deck; none refuse.**
- **The lip is Enhanced-only.** Every `ENH` ceiling part is nominal **+1 in per OUTER edge**;
  `ENH` floor parts are nominal. All 21 **Standard** ceiling parts measure their nominal name.
  Tray tiles therefore seat outward-edge-first, not centred (v1.6.23).
- **Deck seam seals are Standard-only.** The only `ENH` seals are `ENH MidWallSeamSeal` and
  `ENH CornerSeamSeal`, both wall seals. Whether the inner deck should have any is Benton's call.
- **The floor seal family is NOT the ceiling family's twin.** Ceiling seals are cross − 2;
  floor seals are the full cross. A shared length rule calls every floor seal wrong by 2 in.
- Rebalance an `ENH` wall from its **module width off the name**, never its packaged bounding
  box (v1.6.21).

## Out of scope
- Furniture, accessories, roof-mounted vent. Component art / image exports.
- Authoring new `.skp` components — I report what is missing; Benton authors it.
- `WhisperRoomQuote` repo: read only. No prices in any artifact.
- Changing how Standard booths resolve or place.

## History
2026-08-26 — **Tray orientation closed (1.6.30).** Full-folder `probe-levels.rb` run gave
`_face-levels.tsv` its first 1,761 `ENH` rows; the abstention was a 5% share filter deleting the
tray rim, not a missing measurement. `wr-deck.rb` untouched.
2026-08-25 — **MDL 4872 E complete.** Both shells, both decks, door; every part from a
measured number, agreeing with Benton's corrected full-booth probe to 0.0001.
2026-08-25 — Bulk scene naming (`bulk-name-after-scenes.rb`) and the list-scenes search fix
(v1.6.20) both built and **unrun in SketchUp**. Separate from this mission.
2026-08-24 — `ENH` component library verified clean: 112/112 single-shell, 0 failed.
2026-08-24 — Ceiling seam seals done.
