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
**MDL 6060 E — build Shell = Both and probe the inner deck.** Steps below are Benton's;
I cannot drive SketchUp. Plugin **1.6.23** — VERSION is under `wr_tools/`, so this needs
`git pull` → `install-plugin.py` → restart, not just a rescan.

1. Build **MDL 6060 E, Shell = Both**. The inner shell vertical should now read perfect
   (`IEP_WALL_LIFT` dropped 0.75 → 0.6875 on Benton's 2026-08-26 eye).
2. Look at the **inner floor mat and ceiling tray** — two tiles each on this booth
   (`ENH 6042* SIDE L` low, `ENH 6018* SIDE R` high). Check the seam sits where the standard
   deck's seam sits, that neither tile is turned end for end wrongly, and that the tray still
   caps the standard ceiling while the mat tucks under the standard floor.
3. Select the inner deck → **Probe placement of what's selected** → hand back the TSV.
   That closes the end-for-end turn question, which no harness can answer.
3b. **Watch the console for `DECK SEAL FL:`** naming `STDSS FL5` as unmeasured. Move that
   seal by hand until it seats and report the delta — that number becomes
   `WR_Deck::SEAL_FL_DATUM_LIFT`, which is `nil` today.
4. **Re-open the 4872 E and check its inner shell vertical at 0.6875.** See the open
   question below — this is the observation that decides it.

### THE ONE OPEN QUESTION — is the wall lift global or per-booth?
`IEP_WALL_LIFT` is a single global constant. **0.7500** was measured on the corrected
**4872 E** (2026-08-25, Benton's eye then a probe agreeing to 0.0001). **0.6875** was measured
on the **6060 E** (2026-08-26, Benton's eye, no probe yet). Both cannot be right for one
constant. Three readings fit the facts and nobody has ruled any out:

- the lift is global and the 4872 was 1/16 high all along (the v1.6.17 probe measured Benton's
  *corrected* model, so it proved the code matched his hand placement — not that his hand
  placement was right);
- the lift is per-booth;
- something is 6060-specific that nobody has found.

**No per-booth table was invented.** One constant, one word to revert. Step 4 above settles it.
Consequence already banked: the even 0.75/0.75 split of the 1.5 between the deck lips is dead,
and `IEP_TRAY_DROP` was not moved, so the wall-top-to-tray gap widened by the same 1/16.

### Residual on the 6060, expected and not a defect
The room-proud figures for the **11.5** and **35.5** widths are still unmeasured and fall
through to `IEP_ROOM_PROUD_DEFAULT`; the build warns by name. Expect ~1/8" on `N0i`/`E1i`.
That residual **is** the next measurement Benton owes.


## Settled — do not re-derive
- Two-shell model; inner run rule 6.5; `IEP_TRAY_DROP = 0.75`;
  `IEP_DOOR_IN = 0.5`; room-proud per family/width in `IEP_ROOM_PROUD`.
- All 25 `E` layouts exist in `wr-booth-data.rb` (generated, do not hand-edit).
- Deck contact is the true face, not its 1/64 bucket (v1.6.18).
- Not to be authored: ramp doors on Enhanced, the 2.5" panel (`STDWL7` skipped
  deliberately), vent option variants (`_VSS`/`_EFS`/`_CP` are Standard-only), side vents
  (front-view art only).

## Out of scope
- Furniture, accessories, roof-mounted vent. Component art / image exports.
- Authoring new `.skp` components — I report what is missing; Benton authors it.
- `WhisperRoomQuote` repo: read only. No prices in any artifact.
- Changing how Standard booths resolve or place.

- **The `ENH` deck library is COMPLETE. Nothing needs authoring.** 44 Standard deck codes,
  44 Enhanced, identical sets, nothing missing either direction (observed off the real folder).
  **All 25 `E` layouts resolve a full inner deck; none refuse.** The earlier "the IEP deck is
  refused by name and the tiling has no rule" entry was wrong — `wr-deck.rb` already solved
  the tiling and it is fit-tested; `iep_deck` simply was not reaching it. It now reuses
  `WR_Deck.plan` with an `ENH ` catalogue.
- **The lip is Enhanced-only.** Every `ENH` ceiling part is nominal **+1 in per OUTER edge**
  (SIDE +1 along the run, CTR +0, single-piece +2, every CL +2 across); `ENH` floor parts are
  nominal. All 21 **Standard** ceiling parts measure their nominal name, so `WR_Deck.build`
  never had a lip to handle and there is none of its handling to reuse. Tray tiles therefore
  seat outward-edge-first, not centred (v1.6.23).
- **Deck seam seals are Standard-only.** The only `ENH` seals are `ENH MidWallSeamSeal` and
  `ENH CornerSeamSeal`, both wall seals. Whether the inner deck should have any is Benton's call.
- **The floor seal family is NOT the ceiling family's twin.** Ceiling seals are cross − 2;
  floor seals are the full cross. A shared length rule calls every floor seal wrong by 2 in.
- Rebalance an `ENH` wall from its **module width off the name**, never its packaged bounding
  box — the box is part + trim + void, and re-walking a wall from it pushed the 6060 E's
  E inner wall 0.250 past the 0.15 closure tolerance (v1.6.21).

## History
2026-08-25 — **MDL 4872 E complete.** Both shells, both decks, door; every part from a
measured number, agreeing with Benton's corrected full-booth probe to 0.0001. Plugin 1.6.18.
2026-08-25 — Bulk scene naming (`bulk-name-after-scenes.rb`) and the list-scenes search fix
(v1.6.20) both built and **unrun in SketchUp**. Separate from this mission.
2026-08-24 — `ENH` component library verified clean: 112/112 single-shell, 0 failed.
2026-08-24 — Ceiling seam seals done.
