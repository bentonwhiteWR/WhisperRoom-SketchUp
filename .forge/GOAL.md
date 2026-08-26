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
**MDL 6060 E.** Benton: *"still pretty botched."* Steps 1–4 of `HANDOFF.md` are his to run —
I cannot drive SketchUp.

1. Build **MDL 6060 E, Shell = Inner (IEP) only**; read the warning block naming the two
   unmeasured widths (11.5, 35.5).
2. Correct the inner shell by hand, select it, run **Probe placement of what's selected**
   → `P:/Sketchup/NewMasterComponentList/_placement-probe.tsv`.
3. Hand the probe back, plus "X needs to go Y" for anything the probe cannot express.

Where to expect trouble, and why the 6060 is harder than the 4872:
- **Two unmeasured room-prouds** (11.5, 35.5); both default to the 41.5's 1/16.
- **Split runs on all four walls** — E/W mid-wall seals run at yaws never exercised.
- **`ASSIGN['MDL 6060 E']`** carries an untested E/W reversal (16/40 outer, 11.5/35.5 inner).
- **`ENH 11.5PanelSolid` is a thin-box part** (1.125 vs the family's 2.0625).
- **The IEP deck is refused by name.** `ENH 6060FL/CL` do not exist; the library ships
  6042 + 6018 SIDE L/R. **Only open question with no rule at all: how do those tile against
  the standard 6060 deck?** Benton's answer, not mine to invent.

## Settled — do not re-derive
- Two-shell model; inner run rule 6.5; `IEP_WALL_LIFT = 0.75`; `IEP_TRAY_DROP = 0.75`;
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

## History
2026-08-25 — **MDL 4872 E complete.** Both shells, both decks, door; every part from a
measured number, agreeing with Benton's corrected full-booth probe to 0.0001. Plugin 1.6.18.
2026-08-25 — Bulk scene naming (`bulk-name-after-scenes.rb`) and the list-scenes search fix
(v1.6.20) both built and **unrun in SketchUp**. Separate from this mission.
2026-08-24 — `ENH` component library verified clean: 112/112 single-shell, 0 failed.
2026-08-24 — Ceiling seam seals done.
