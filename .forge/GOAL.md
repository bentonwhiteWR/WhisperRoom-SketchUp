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
**Plugin 1.6.32.** VERSION is under `wr_tools/`, so this needs `git pull` -> `install-plugin.py`
-> **restart SketchUp**, not a rescan. A Ruby module keeps its constants until restart.

### MDL 84126 E IS CONFIRMED GOOD IN A BUILT MODEL — the first such confirmation in this mission
Benton, 2026-08-26: the 84126 E "now looks correct". That closes **three** things at once and
they are not to be revisited: the Standard ceiling hinge rotation and the far-tile floor seating
(both 1.6.31), and the **IEP tray orientation** (1.6.30), whose test was owed and is now paid.
Every one of those was measured rather than guessed, and every one held up in a real model.

1. **Build a booth on the 41.5 vent — `MDL 7272 E` or `MDL 96144 E`, Shell = Both — and look at
   the inner vent walls.** This is the 1.6.32 test and it is the one that matters, because those
   ten layouts have been **wrong since 10:04 this morning** and nobody had rebuilt one to see it.
   The console now prints, per inner vent, the width axis it measured and the turn it chose;
   expect `width runs Y -> vent yaw 0`. Then **rebuild the HX** you were looking at and confirm
   the vents came back. The 15 non-HX 35.5-vent layouts (84126 E, 102144 E, 6060 E among them)
   are untouched by 1.6.32 — if a vent moved on one of those, the fix is wrong.
2. **Then `MDL 7272 S`.** Its ceiling moved in 1.6.31 and has never been checked; its floor was
   signed off in August and does **not** move. It is the best falsifier of the convention-A
   mirror. ⚠ Its floor is separately broken by a **defective component file** — see open
   questions — so ignore the ~14 in error at its high end.
3. **Then finish `MDL 6060 E`, Shell = Both.** Probe the inner deck and hand back the TSV — that
   closes the end-for-end turn question, which no harness can answer. Take the **wall-lift
   reading** while in there; it is the fourth reading the table below needs.
4. **Re-open the 4872 E.** Two jobs now: its inner shell vertical at 0.6875, still the only
   number in the mission resting on a guess — and its **inner vents**, which 1.6.32 returns to
   the orientation it was signed off with on 08-25.

### THE WALL LIFT IS A PER-BOOTH TABLE (v1.6.28), and its default is a guess
`IEP_WALL_LIFT` is no longer one constant. Three measurements exist and they disagree:

| booth | lift | provenance |
|---|---|---|
| MDL 4872 E | 0.7500 | Benton's eye 2026-08-25, then a full-booth probe agreeing to 0.0001 |
| MDL 6060 E | 0.6875 | Benton's eye 2026-08-26, **no probe** |
| MDL 102144 E | 0.7500 | Benton's eye 2026-08-26, **no probe** |
| **default** | **0.7500** | a GUESS covering the other 22 layouts, and the build names each one |

**No rule was derived** - Benton's words were *"Im not sure about any others."* The lift reaches
`part_top_z` as a required third argument resolved once per build, never module state, so it
cannot go stale between builds in one SketchUp session. A fourth reading of **0.6875** means the
4872 E's probe measured a hand placement that was itself 1/16 out, and the default belongs at
0.6875; a fourth reading of **0.7500** leaves the 6060 E as the lone outlier.

### Residual on the 6060, expected and not a defect
The room-proud figures for the **11.5** and **35.5** widths are still unmeasured and fall through
to `IEP_ROOM_PROUD_DEFAULT`; the build warns by name. Expect ~1/8" on `N0i`/`E1i`.

## Settled — do not re-derive
- Two-shell model; inner run rule 6.5; `IEP_TRAY_DROP = 0.75`;
  `IEP_DOOR_IN = 0.5`; room-proud per family/width in `IEP_ROOM_PROUD`.
- All 25 `E` layouts exist in `wr-booth-data.rb` (generated, do not hand-edit).
- Deck contact is the true face, not its 1/64 bucket (v1.6.18).
- **The IEP tray orientation is MEASURED and the abstention is gone (v1.6.30).** Four of the 23
  `ENH` ceiling parts are authored upside down - `10218CL CTR`, `10242CL CTR`, `10242CL SIDE`,
  `8442CL SIDE` - and nine `E` layouts tile one. `ENH 8442CL CTR` is right way up while
  `8442CL SIDE` is not, so there is **no name-level rule** and none should be sought.
- **The STANDARD ceilings split into two authoring conventions, and it is MEASURED (v1.6.31).**
  Six carry hardware above a 1.7500 rim and are flipped by the code; **17 are authored already
  inverted**, have nothing above their 3.1094 rim, and carry their bracket line at the OPPOSITE
  end of the tiling axis from their floor twin. `STD9648CL SIDE` is the only Standard ceiling
  part with a cue of its own (0.7366, matching its twin exactly) and it must not move.
  **Also no name rule.** `.forge/fixer/ROOTCAUSE-std-deck-84126-2026-08-26.md`.
- **Deck tile stations are NOMINAL; seating is MEASURED (v1.6.31).** `catalogue` reads widths off
  the name digits. The last tile of a multi-tile run therefore seats against the FAR perimeter,
  not its nominal station. Interior butt-joint slack is left open deliberately.
- **`SEAL_FL_DATUM_LIFT` is MEASURED at `-1.1250` (v1.6.27).** Not nil, never needs re-measuring.
- **The lip is Enhanced-only.** Every `ENH` ceiling part is nominal **+1 in per OUTER edge**;
  `ENH` floor parts are nominal. All 21 **Standard** ceiling parts measure their nominal name.
- **Deck seam seals are Standard-only.** The only `ENH` seals are wall seals.
- **The floor seal family is NOT the ceiling family's twin.** Ceiling seals are cross - 2;
  floor seals are the full cross.
- **The `ENH` deck library is COMPLETE. Nothing needs authoring.** All 25 `E` layouts resolve.
- Rebalance an `ENH` wall from its **module width off the name**, never its bounding box (v1.6.21).
- **The INNER VENT'S half turn is MEASURED, per part, and the constant is gone (v1.6.32).**
  `rotation()` derives the along-wall direction from the parity of the part's own axis
  permutation, so parts of opposite parity land end for end from each other. `ENH 35.5VNT` is the
  ONLY one of the eight `ENH` vent parts whose width runs X; the blanket `IEP_VENT_YAW = 180` was
  fitted to it. `iep_vent_yaw(cls)` now derives the turn. **The turn is a per-family convention
  and MUST NOT be generalised** - the mid-wall seal (runs X, 180) agrees with the vents, but the
  inner DOOR family is all Y-running and wants 180, the opposite convention.
  `.forge/fixer/ROOTCAUSE-iep-vent-yaw-2026-08-26.md`.
- Not to be authored: ramp doors on Enhanced, the 2.5" panel, vent option variants, side vents.

## Out of scope
- Furniture, accessories, roof-mounted vent. Component art / image exports.
- Authoring new `.skp` components — I report what is missing; Benton authors it.
- `WhisperRoomQuote` repo: read only. No prices in any artifact.
- Changing how Standard booths resolve or place - **EXCEPT the two defects Benton
  reported on 2026-08-26 and asked to have fixed** (the Standard ceiling SIDE plan
  rotation, and the last floor tile's seat against the far perimeter), both shipped in
  1.6.31. That is a narrowing for those two only, not a general licence to rework
  Standard placement.

## History
2026-08-26 — **MDL 84126 E CONFIRMED GOOD in a built model.** First in-SketchUp confirmation the
mission has had: 1.6.31's two Standard-deck fixes and 1.6.30's tray orientation all held.
2026-08-26 — **The IEP vent yaw was never one number (1.6.32).** `IEP_VENT_YAW = 180` was fitted
to `ENH 35.5VNT`, the only one of eight `ENH` vent parts whose width runs X, and applied to all
eight. Ten non-HX 41.5-vent layouts had been silently wrong since 1.6.21 shipped that morning.
The 96144 E report that v1.6.25 dismissed as an unrestarted SketchUp was real evidence about a
different part.
2026-08-26 — **Two Standard-deck defects fixed (1.6.31).** Benton's MDL 84126 report. The 1/32 is
nominal stations vs measured seating, surfacing once at the far wall; the ceiling hinges are an
unmeasured "coplanar" invariant applied to 17 pre-inverted parts. No Standard ceiling's plan
rotation had ever been checked by anyone.
2026-08-26 — **Tray orientation closed (1.6.30).** Full-folder `probe-levels.rb` run gave
`_face-levels.tsv` its first 1,761 `ENH` rows; the abstention was a 5% share filter deleting the
tray rim, not a missing measurement. `wr-deck.rb` untouched.
2026-08-25 — **MDL 4872 E complete.** Both shells, both decks, door; every part from a
measured number, agreeing with Benton's corrected full-booth probe to 0.0001.
2026-08-25 — Bulk scene naming (`bulk-name-after-scenes.rb`) and the list-scenes search fix
(v1.6.20) both built and **unrun in SketchUp**. Separate from this mission.
2026-08-24 — `ENH` component library verified clean: 112/112 single-shell, 0 failed.
2026-08-24 — Ceiling seam seals done.
